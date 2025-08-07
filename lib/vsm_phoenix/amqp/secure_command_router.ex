defmodule VsmPhoenix.AMQP.SecureCommandRouter do
  @moduledoc """
  Secure AMQP Command Router with cryptographic security layer integration.
  
  Provides:
  - Secure command wrapping with HMAC SHA256 signatures
  - Nonce-based replay attack protection
  - Timestamp validation
  - Automatic security metric tracking
  - Backward compatibility with unsigned messages
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Infrastructure.Security
  alias VsmPhoenix.AMQP.ConnectionManager
  alias AMQP
  
  @name __MODULE__
  @exchange "vsm.secure.commands"
  @queue "vsm.secure.command.queue"
  @routing_key "secure.command"
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Send a secure command through AMQP
  """
  def send_secure_command(command, opts \\ []) do
    GenServer.call(@name, {:send_secure_command, command, opts})
  end
  
  @doc """
  Process a received secure command
  """
  def process_secure_command(wrapped_command) do
    GenServer.call(@name, {:process_secure_command, wrapped_command})
  end
  
  @doc """
  Get router metrics including security statistics
  """
  def get_metrics do
    GenServer.call(@name, :get_metrics)
  end
  
  @doc """
  Update the secret key (for key rotation)
  """
  def rotate_key(new_key) do
    GenServer.call(@name, {:rotate_key, new_key})
  end
  
  # Server Implementation
  
  @impl true
  def init(opts) do
    Logger.info("🔐 Starting Secure AMQP Command Router...")
    
    # Get or generate secret key
    secret_key = get_secret_key(opts)
    
    state = %{
      channel: nil,
      secret_key: secret_key,
      consumer_tag: nil,
      metrics: %{
        commands_sent: 0,
        commands_received: 0,
        commands_verified: 0,
        commands_rejected: 0,
        security_failures: 0
      },
      security_enabled: Keyword.get(opts, :security_enabled, true),
      allow_unsigned: Keyword.get(opts, :allow_unsigned, false)
    }
    
    # Set up AMQP connection
    state = setup_amqp(state)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:send_secure_command, command, opts}, _from, state) do
    result = if state.security_enabled do
      send_secured_command(command, state, opts)
    else
      send_unsecured_command(command, state)
    end
    
    case result do
      :ok ->
        new_metrics = Map.update(state.metrics, :commands_sent, 1, &(&1 + 1))
        {:reply, :ok, %{state | metrics: new_metrics}}
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:process_secure_command, wrapped_command}, _from, state) do
    result = process_command(wrapped_command, state)
    
    {new_metrics, reply} = case result do
      {:ok, command} ->
        metrics = state.metrics
        |> Map.update(:commands_received, 1, &(&1 + 1))
        |> Map.update(:commands_verified, 1, &(&1 + 1))
        {metrics, {:ok, command}}
        
      {:error, :unsigned_command} when state.allow_unsigned ->
        metrics = Map.update(state.metrics, :commands_received, 1, &(&1 + 1))
        # Allow unsigned command through
        {metrics, {:ok, wrapped_command}}
        
      {:error, reason} ->
        Logger.warning("Security validation failed: #{reason}")
        metrics = state.metrics
        |> Map.update(:commands_received, 1, &(&1 + 1))
        |> Map.update(:commands_rejected, 1, &(&1 + 1))
        |> Map.update(:security_failures, 1, &(&1 + 1))
        {metrics, {:error, reason}}
    end
    
    {:reply, reply, %{state | metrics: new_metrics}}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = Map.merge(state.metrics, %{
      security_enabled: state.security_enabled,
      allow_unsigned: state.allow_unsigned,
      channel_status: if(state.channel, do: :connected, else: :disconnected)
    })
    
    # Also get security infrastructure metrics
    security_metrics = Security.get_metrics()
    
    combined_metrics = %{
      router: metrics,
      security: security_metrics
    }
    
    {:reply, combined_metrics, state}
  end
  
  @impl true
  def handle_call({:rotate_key, new_key}, _from, state) do
    Logger.info("🔑 Rotating security key...")
    {:reply, :ok, %{state | secret_key: new_key}}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Process incoming AMQP message
    case Jason.decode(payload) do
      {:ok, wrapped_command} ->
        # Process the command asynchronously
        Task.start(fn ->
          case process_command(wrapped_command, state) do
            {:ok, command} ->
              route_verified_command(command, state)
            {:error, reason} ->
              Logger.error("Failed to verify command: #{reason}")
          end
        end)
        
        # Acknowledge the message
        if state[:channel] do
          AMQP.Basic.ack(state.channel, meta.delivery_tag)
        end
        
      {:error, error} ->
        Logger.error("Failed to decode AMQP message: #{inspect(error)}")
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("🔐 Secure command router consumer registered")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("Secure command router consumer cancelled")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("Secure command router consumer cancel confirmed")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Retrying AMQP setup for secure router...")
    new_state = setup_amqp(state)
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp get_secret_key(opts) do
    case Keyword.get(opts, :secret_key) do
      nil ->
        # Try environment variable
        case System.get_env("VSM_SECRET_KEY") do
          nil ->
            # Generate a key and log warning
            key = Security.generate_secret_key()
            Logger.warning("No secret key provided! Generated temporary key: #{key}")
            Logger.warning("Set VSM_SECRET_KEY environment variable for production!")
            key
          key ->
            key
        end
      key ->
        key
    end
  end
  
  defp send_secured_command(command, state, opts) do
    if state[:channel] do
      # Wrap command with security
      wrapped = Security.wrap_amqp_command(command, state.secret_key, opts)
      
      payload = Jason.encode!(wrapped)
      
      # Publish to secure exchange
      :ok = AMQP.Basic.publish(
        state.channel,
        @exchange,
        @routing_key,
        payload,
        content_type: "application/json",
        headers: [
          {"x-security-enabled", :longstr, "true"},
          {"x-algorithm", :longstr, "HMAC-SHA256"}
        ]
      )
      
      Logger.debug("📤 Sent secure command: #{command[:type] || "unknown"}")
      :ok
    else
      {:error, :no_channel}
    end
  end
  
  defp send_unsecured_command(command, state) do
    if state[:channel] do
      payload = Jason.encode!(command)
      
      :ok = AMQP.Basic.publish(
        state.channel,
        @exchange,
        @routing_key,
        payload,
        content_type: "application/json"
      )
      
      Logger.debug("📤 Sent command (unsecured): #{command[:type] || "unknown"}")
      :ok
    else
      {:error, :no_channel}
    end
  end
  
  defp process_command(wrapped_command, state) do
    cond do
      # Check if it's a secure message
      Map.has_key?(wrapped_command, "security") ->
        Security.unwrap_amqp_command(
          string_keys_to_atoms(wrapped_command),
          state.secret_key
        )
        
      # Unsigned message
      state.allow_unsigned ->
        {:error, :unsigned_command}
        
      true ->
        {:error, :security_required}
    end
  end
  
  defp route_verified_command(command, _state) do
    # Route the verified command to appropriate handler
    Logger.info("✅ Verified secure command: #{command[:type] || inspect(command)}")
    
    # Publish to internal routing topic for processing
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:secure_commands",
      {:secure_command, command}
    )
  end
  
  defp setup_amqp(state) do
    case ConnectionManager.get_channel(:secure_commands) do
      {:ok, channel} ->
        try do
          # Declare secure exchange
          :ok = AMQP.Exchange.declare(channel, @exchange, :topic, durable: true)
          
          # Declare secure queue
          {:ok, _queue} = AMQP.Queue.declare(channel, @queue, durable: true)
          
          # Bind queue to exchange
          :ok = AMQP.Queue.bind(channel, @queue, @exchange, routing_key: "#")
          
          # Start consuming
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, @queue)
          
          Logger.info("🔐 Secure AMQP router connected")
          
          %{state | channel: channel, consumer_tag: consumer_tag}
        rescue
          error ->
            Logger.error("Failed to setup secure AMQP: #{inspect(error)}")
            schedule_retry()
            state
        end
        
      {:error, reason} ->
        Logger.error("Could not get AMQP channel for secure router: #{inspect(reason)}")
        schedule_retry()
        state
    end
  end
  
  defp schedule_retry do
    Process.send_after(self(), :retry_amqp_setup, 5000)
  end
  
  defp string_keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), string_keys_to_atoms(v)}
      {k, v} -> {k, string_keys_to_atoms(v)}
    end)
  rescue
    ArgumentError ->
      # If atom doesn't exist, keep as string
      map
  end
  defp string_keys_to_atoms(list) when is_list(list) do
    Enum.map(list, &string_keys_to_atoms/1)
  end
  defp string_keys_to_atoms(value), do: value
end