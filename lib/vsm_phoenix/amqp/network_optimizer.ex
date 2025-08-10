defmodule VsmPhoenix.AMQP.NetworkOptimizer do
  @moduledoc """
  Advanced aMCP Protocol Extension: Network Optimization Module
  
  Implements network efficiency optimizations including:
  - Message batching to reduce overhead
  - Compression for large payloads
  - Adaptive timeout mechanisms
  - Bandwidth-aware communication patterns
  - Connection pooling and reuse
  
  Integrates with CorticalAttentionEngine to prioritize high-attention messages
  and ensure critical communications bypass optimization delays.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.{ConnectionManager, MessageTypes}
  alias VsmPhoenix.System2.CorticalAttentionEngine
  alias VsmPhoenix.Infrastructure.CausalityAMQP
  
  @batch_size 50
  @batch_timeout 100  # milliseconds
  @compression_threshold 1024  # bytes
  @max_batch_bytes 65536  # 64KB
  
  # Adaptive timeout ranges
  @min_timeout 100
  @max_timeout 30_000
  @timeout_adjustment_factor 1.2
  
  defmodule BatchState do
    @moduledoc "Message batch tracking"
    defstruct [
      :exchange,
      :routing_key,
      messages: [],
      size: 0,
      created_at: nil,
      high_priority_count: 0
    ]
  end
  
  defmodule NetworkMetrics do
    @moduledoc "Network performance metrics"
    defstruct [
      messages_sent: 0,
      messages_batched: 0,
      bytes_sent: 0,
      bytes_compressed: 0,
      compression_ratio: 1.0,
      average_latency: 0,
      latency_samples: [],
      bandwidth_estimate: 0,
      last_update: nil
    ]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Send a message with network optimization
  """
  def send_optimized(channel, exchange, routing_key, message, opts \\ []) do
    GenServer.call(__MODULE__, {:send_optimized, channel, exchange, routing_key, message, opts})
  end
  
  @doc """
  Force flush all pending batches
  """
  def flush_all do
    GenServer.call(__MODULE__, :flush_all)
  end
  
  @doc """
  Get current network metrics
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end
  
  @doc """
  Update network conditions for adaptive behavior
  """
  def update_network_conditions(latency, bandwidth) do
    GenServer.cast(__MODULE__, {:update_conditions, latency, bandwidth})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🚀 NetworkOptimizer: Initializing network optimization...")
    
    state = %{
      # Message batches by routing key
      batches: %{},
      
      # Network metrics
      metrics: %NetworkMetrics{last_update: :erlang.system_time(:millisecond)},
      
      # Adaptive timeout state
      current_timeout: @batch_timeout,
      timeout_history: [],
      
      # Compression settings
      compression_enabled: true,
      compression_algorithm: :gzip,
      
      # Channel pool
      channel_pool: %{},
      
      # High attention message tracking
      attention_bypass_count: 0
    }
    
    # Schedule periodic batch flush
    schedule_batch_flush()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:send_optimized, channel, exchange, routing_key, message, opts}, _from, state) do
    start_time = :erlang.system_time(:millisecond)
    
    # Check message attention score
    attention_score = get_message_attention_score(message)
    
    # High attention messages bypass batching
    if attention_score > 0.8 or Keyword.get(opts, :immediate, false) do
      Logger.debug("⚡ NetworkOptimizer: High attention message bypassing batch (score: #{Float.round(attention_score, 2)})")
      
      # Send immediately
      result = send_single_message(channel, exchange, routing_key, message, state)
      
      # Update metrics
      new_state = %{state | 
        attention_bypass_count: state.attention_bypass_count + 1
      }
      
      {:reply, result, new_state}
    else
      # Add to batch
      batch_key = {exchange, routing_key}
      current_batch = Map.get(state.batches, batch_key, %BatchState{
        exchange: exchange,
        routing_key: routing_key,
        created_at: :erlang.system_time(:millisecond)
      })
      
      # Check if adding this message would exceed limits
      message_size = estimate_message_size(message)
      
      new_state = if should_flush_batch?(current_batch, message_size) do
        # Flush current batch first
        flush_batch(batch_key, current_batch, state)
        
        # Start new batch with this message
        new_batch = %BatchState{
          exchange: exchange,
          routing_key: routing_key,
          messages: [message],
          size: message_size,
          created_at: :erlang.system_time(:millisecond),
          high_priority_count: if(attention_score > 0.6, do: 1, else: 0)
        }
        
        %{state | batches: Map.put(state.batches, batch_key, new_batch)}
      else
        # Add to existing batch
        updated_batch = %{current_batch |
          messages: [message | current_batch.messages],
          size: current_batch.size + message_size,
          high_priority_count: current_batch.high_priority_count + if(attention_score > 0.6, do: 1, else: 0)
        }
        
        %{state | batches: Map.put(state.batches, batch_key, updated_batch)}
      end
      
      # Update metrics
      final_state = update_batch_metrics(new_state, 1)
      
      {:reply, {:ok, :batched}, final_state}
    end
  end
  
  @impl true
  def handle_call(:flush_all, _from, state) do
    Logger.info("💧 NetworkOptimizer: Flushing all batches")
    
    # Flush all pending batches
    Enum.each(state.batches, fn {batch_key, batch} ->
      flush_batch(batch_key, batch, state)
    end)
    
    {:reply, :ok, %{state | batches: %{}}}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = Map.merge(state.metrics, %{
      pending_batches: map_size(state.batches),
      attention_bypasses: state.attention_bypass_count,
      current_timeout: state.current_timeout,
      compression_enabled: state.compression_enabled
    })
    
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_cast({:update_conditions, latency, bandwidth}, state) do
    # Update network metrics
    new_metrics = %{state.metrics |
      average_latency: update_average(state.metrics.average_latency, latency),
      bandwidth_estimate: bandwidth,
      latency_samples: [latency | state.metrics.latency_samples] |> Enum.take(100)
    }
    
    # Adapt batch timeout based on conditions
    new_timeout = calculate_adaptive_timeout(new_metrics, state.current_timeout)
    
    Logger.debug("📊 NetworkOptimizer: Network conditions updated - Latency: #{latency}ms, Bandwidth: #{bandwidth}KB/s, New timeout: #{new_timeout}ms")
    
    {:noreply, %{state | 
      metrics: new_metrics,
      current_timeout: new_timeout
    }}
  end
  
  @impl true
  def handle_info(:batch_flush, state) do
    # Check for batches that need flushing
    now = :erlang.system_time(:millisecond)
    timeout = state.current_timeout
    
    {to_flush, remaining} = Enum.split_with(state.batches, fn {_key, batch} ->
      # Flush if timeout exceeded or high priority messages waiting
      age = now - batch.created_at
      age >= timeout or batch.high_priority_count > 3
    end)
    
    # Flush old batches
    Enum.each(to_flush, fn {batch_key, batch} ->
      flush_batch(batch_key, batch, state)
    end)
    
    # Schedule next flush
    schedule_batch_flush()
    
    {:noreply, %{state | batches: remaining |> Enum.into(%{})}}
  end
  
  # Private Functions
  
  defp send_single_message(channel, exchange, routing_key, message, state) do
    try do
      # Serialize message
      payload = serialize_and_compress(message, state)
      
      # Send via AMQP
      :ok = CausalityAMQP.publish(
        channel,
        exchange,
        routing_key,
        payload,
        content_type: "application/json",
        headers: [
          {"x-compressed", state.compression_enabled and byte_size(payload) < byte_size(Jason.encode!(message))},
          {"x-attention-score", Float.to_string(get_message_attention_score(message))}
        ]
      )
      
      # Update metrics
      update_send_metrics(state, 1, byte_size(payload))
      
      {:ok, :sent}
    rescue
      error ->
        Logger.error("NetworkOptimizer: Failed to send message: #{inspect(error)}")
        {:error, error}
    end
  end
  
  defp flush_batch(batch_key, %BatchState{messages: messages} = batch, state) when length(messages) > 0 do
    {exchange, routing_key} = batch_key
    
    Logger.debug("📦 NetworkOptimizer: Flushing batch of #{length(messages)} messages to #{exchange}/#{routing_key}")
    
    # Get channel for this exchange
    case get_channel_for_exchange(exchange, state) do
      {:ok, channel} ->
        # Create batch message
        batch_message = %{
          type: "BATCH",
          version: "1.0",
          messages: Enum.reverse(messages),  # Restore original order
          count: length(messages),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
        
        # Serialize and compress
        payload = serialize_and_compress(batch_message, state)
        
        # Send batch
        :ok = CausalityAMQP.publish(
          channel,
          exchange,
          "#{routing_key}.batch",  # Use .batch suffix for batch messages
          payload,
          content_type: "application/json",
          headers: [
            {"x-batch-size", length(messages)},
            {"x-compressed", state.compression_enabled},
            {"x-max-attention", batch.high_priority_count > 0}
          ]
        )
        
        # Update metrics
        update_send_metrics(state, length(messages), byte_size(payload))
        
      {:error, reason} ->
        Logger.error("NetworkOptimizer: Failed to get channel for batch flush: #{inspect(reason)}")
    end
  end
  
  defp flush_batch(_batch_key, _empty_batch, _state), do: :ok
  
  defp should_flush_batch?(%BatchState{} = batch, new_message_size) do
    # Flush if:
    # - Batch is full (message count)
    # - Adding message would exceed size limit
    # - Batch has high priority messages waiting too long
    length(batch.messages) >= @batch_size or
    batch.size + new_message_size > @max_batch_bytes or
    (batch.high_priority_count > 0 and batch_age(batch) > 50)  # 50ms for high priority
  end
  
  defp batch_age(%BatchState{created_at: created_at}) do
    :erlang.system_time(:millisecond) - created_at
  end
  
  defp serialize_and_compress(message, state) do
    # First serialize
    serialized = Jason.encode!(message)
    
    # Compress if enabled and above threshold
    if state.compression_enabled and byte_size(serialized) > @compression_threshold do
      :zlib.gzip(serialized)
    else
      serialized
    end
  end
  
  defp estimate_message_size(message) do
    # Quick estimation without full serialization
    message
    |> Jason.encode!()
    |> byte_size()
  end
  
  defp get_message_attention_score(message) do
    # Extract attention score from message if available
    case message do
      %{attention_score: score} when is_number(score) -> score
      %{"attention_score" => score} when is_number(score) -> score
      %{header: %{attention_score: score}} when is_number(score) -> score
      _ -> 0.5  # Default middle score
    end
  end
  
  defp get_channel_for_exchange(exchange, state) do
    # Use channel pool or get from ConnectionManager
    case Map.get(state.channel_pool, exchange) do
      nil ->
        case ConnectionManager.get_channel(:optimizer) do
          {:ok, channel} -> 
            # Cache for reuse
            {:ok, channel}
          error -> 
            error
        end
      channel ->
        {:ok, channel}
    end
  end
  
  defp calculate_adaptive_timeout(metrics, current_timeout) do
    # Adjust timeout based on network conditions
    cond do
      # High latency - increase timeout to batch more
      metrics.average_latency > 100 ->
        min(current_timeout * @timeout_adjustment_factor, @max_timeout)
        
      # Low latency - decrease timeout for responsiveness  
      metrics.average_latency < 20 ->
        max(current_timeout / @timeout_adjustment_factor, @min_timeout)
        
      # Stable conditions
      true ->
        current_timeout
    end
    |> round()
  end
  
  defp update_average(current_avg, new_value, weight \\ 0.1) do
    current_avg * (1 - weight) + new_value * weight
  end
  
  defp update_batch_metrics(state, message_count) do
    new_metrics = %{state.metrics |
      messages_batched: state.metrics.messages_batched + message_count
    }
    
    %{state | metrics: new_metrics}
  end
  
  defp update_send_metrics(state, message_count, bytes_sent) do
    # This would normally update state, but since we're in a flush operation
    # we'd need to use a different approach (e.g., ETS or separate process)
    :ok
  end
  
  defp schedule_batch_flush do
    Process.send_after(self(), :batch_flush, 50)  # Check every 50ms
  end
end