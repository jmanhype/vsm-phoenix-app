defmodule VsmPhoenix.AMQP.ChannelPool do
  @moduledoc """
  Manages a pool of AMQP channels to prevent channel conflicts.
  Each consumer gets its own dedicated channel from the pool.
  """
  
  use GenServer
  require Logger
  
  @pool_size 10
  @checkout_timeout 5000
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Checkout a channel from the pool
  """
  def checkout(purpose \\ :default) do
    GenServer.call(__MODULE__, {:checkout, purpose}, @checkout_timeout)
  end
  
  @doc """
  Return a channel to the pool
  """
  def checkin(channel) do
    GenServer.cast(__MODULE__, {:checkin, channel})
  end
  
  @doc """
  Execute a function with a channel from the pool
  """
  def with_channel(purpose \\ :default, fun) do
    case checkout(purpose) do
      {:ok, channel} ->
        try do
          result = fun.(channel)
          checkin(channel)
          result
        rescue
          error ->
            # Don't return broken channels to the pool
            Logger.error("Channel error during operation: #{inspect(error)}")
            {:error, error}
        end
        
      error ->
        error
    end
  end
  
  @impl true
  def init(_opts) do
    # We'll initialize channels lazily as needed
    state = %{
      connection: nil,
      available_channels: [],
      checked_out: %{},
      channel_count: 0
    }
    
    # Try to get connection from ConnectionManager
    send(self(), :init_connection)
    
    {:ok, state}
  end
  
  @impl true
  def handle_info(:init_connection, state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_connection() do
      nil ->
        # Retry in a bit
        Process.send_after(self(), :init_connection, 1000)
        {:noreply, state}
        
      conn ->
        Logger.info("📦 Channel pool connected to AMQP")
        # Pre-create some channels
        new_state = create_initial_channels(%{state | connection: conn})
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_call({:checkout, purpose}, {from_pid, _}, state) do
    case get_available_channel(state) do
      {:ok, channel, new_state} ->
        # Track who has the channel
        ref = Process.monitor(from_pid)
        checked_out = Map.put(new_state.checked_out, ref, {channel, from_pid})
        
        Logger.debug("✅ Channel checked out for #{purpose} by #{inspect(from_pid)}")
        {:reply, {:ok, channel}, %{new_state | checked_out: checked_out}}
        
      {:error, reason} ->
        Logger.error("❌ Failed to checkout channel: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_cast({:checkin, channel}, state) do
    # Find and remove from checked_out
    {ref, new_checked_out} = Enum.find_value(state.checked_out, {nil, state.checked_out}, fn {ref, {ch, _pid}} ->
      if ch == channel do
        Process.demonitor(ref, [:flush])
        {ref, Map.delete(state.checked_out, ref)}
      else
        nil
      end
    end)
    
    if ref do
      # Return to available pool if channel is still alive
      if Process.alive?(channel.pid) do
        Logger.debug("♻️  Channel returned to pool")
        {:noreply, %{state | 
          available_channels: [channel | state.available_channels],
          checked_out: new_checked_out
        }}
      else
        Logger.warning("☠️  Returned channel is dead, not adding to pool")
        {:noreply, %{state | checked_out: new_checked_out}}
      end
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # Process that checked out a channel died - reclaim the channel
    case Map.get(state.checked_out, ref) do
      {channel, pid} ->
        Logger.warning("⚠️  Process #{inspect(pid)} died with checked out channel")
        new_checked_out = Map.delete(state.checked_out, ref)
        
        # Check if channel is still alive
        if Process.alive?(channel.pid) do
          {:noreply, %{state | 
            available_channels: [channel | state.available_channels],
            checked_out: new_checked_out
          }}
        else
          {:noreply, %{state | checked_out: new_checked_out}}
        end
        
      nil ->
        {:noreply, state}
    end
  end
  
  # Private functions
  
  defp create_initial_channels(state) do
    channels = Enum.reduce(1..@pool_size, [], fn _, acc ->
      case create_new_channel(state.connection) do
        {:ok, channel} -> [channel | acc]
        {:error, _} -> acc
      end
    end)
    
    Logger.info("📦 Created #{length(channels)} initial channels in pool")
    %{state | available_channels: channels, channel_count: length(channels)}
  end
  
  defp get_available_channel(state) do
    case state.available_channels do
      [channel | rest] ->
        # Check if channel is still alive
        if Process.alive?(channel.pid) do
          {:ok, channel, %{state | available_channels: rest}}
        else
          # Dead channel, try next
          get_available_channel(%{state | available_channels: rest})
        end
        
      [] ->
        # No channels available, try to create one
        if state.channel_count < @pool_size * 2 do
          create_channel_for_checkout(state)
        else
          {:error, :pool_exhausted}
        end
    end
  end
  
  defp create_channel_for_checkout(state) do
    case create_new_channel(state.connection) do
      {:ok, channel} ->
        Logger.info("📦 Created new channel on demand")
        {:ok, channel, %{state | channel_count: state.channel_count + 1}}
        
      error ->
        error
    end
  end
  
  defp create_new_channel(nil), do: {:error, :no_connection}
  defp create_new_channel(connection) do
    # Add a small delay to prevent rapid channel creation
    Process.sleep(100)
    
    case AMQP.Channel.open(connection) do
      {:ok, channel} = success ->
        Logger.debug("✅ Created new AMQP channel: #{inspect(channel.pid)}")
        success
        
      {:error, reason} = error ->
        Logger.error("❌ Failed to create channel: #{inspect(reason)}")
        error
    end
  end
end