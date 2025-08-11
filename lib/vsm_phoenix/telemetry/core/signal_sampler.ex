defmodule VsmPhoenix.Telemetry.Core.SignalSampler do
  @moduledoc """
  Signal Sampler - Single Responsibility for Signal Data Collection
  
  Handles ONLY signal sampling, buffering, and rate management.
  Extracted from AnalogArchitect god object to follow Single Responsibility Principle.
  
  Responsibilities:
  - Signal value sampling and validation
  - Circular buffer management
  - Sampling rate enforcement
  - Buffer overflow handling
  - Sample metadata tracking
  """

  use GenServer
  use VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior
  use VsmPhoenix.Telemetry.Behaviors.AnalogSignalBehavior
  
  # Override conflicting imports
  import VsmPhoenix.Telemetry.Behaviors.SharedLogging, only: [log_telemetry_event: 4, log_init_event: 3]
  
  # Define missing helpers
  defp log_info(event, metadata \\ %{}) do
    log_telemetry_event(:info, __MODULE__, event, metadata)
  end
  
  defp log_init_event(module, event) do
    log_init_event(module, event, %{})
  end

  alias VsmPhoenix.Telemetry.Core.SignalRegistry
  alias VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore

  @sampling_intervals %{
    high_frequency: 10,     # 10ms (100Hz)
    standard: 100,          # 100ms (10Hz)
    low_frequency: 1000     # 1000ms (1Hz)
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl VsmPhoenix.Telemetry.Behaviors.AnalogSignalBehavior
  def sample_signal(signal_id, value, metadata) do
    GenServer.cast(__MODULE__, {:sample, signal_id, value, metadata})
  end

  @doc """
  Get recent samples for a signal
  """
  def get_samples(signal_id, count \\ 100) do
    GenServer.call(__MODULE__, {:get_samples, signal_id, count})
  end

  @doc """
  Get sampling statistics for a signal
  """
  def get_sampling_stats(signal_id) do
    GenServer.call(__MODULE__, {:get_sampling_stats, signal_id})
  end

  @doc """
  Clear buffer for a signal
  """
  def clear_buffer(signal_id) do
    GenServer.call(__MODULE__, {:clear_buffer, signal_id})
  end

  @doc """
  Get buffer status for all signals or a specific signal
  """
  def get_buffer_status(signal_id \\ :all) do
    GenServer.call(__MODULE__, {:get_buffer_status, signal_id})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    log_init_event(__MODULE__, :starting)
    
    data_store_type = Keyword.get(opts, :data_store_type, :ets)
    data_store = VsmPhoenix.Telemetry.Factories.TelemetryFactory.create_data_store(data_store_type)
    
    # Initialize ETS table for signal buffers
    :ets.new(:signal_buffers, [:set, :public, :named_table, {:write_concurrency, true}])
    :ets.new(:sampling_stats, [:set, :public, :named_table, {:write_concurrency, true}])
    
    state = %{
      data_store: data_store,
      sampling_timers: %{},
      buffer_stats: %{},
      last_cleanup: DateTime.utc_now()
    }
    
    # Start periodic cleanup
    schedule_buffer_cleanup()
    
    log_init_event(__MODULE__, :initialized)
    {:ok, state}
  end

  @impl true
  def handle_cast({:sample, signal_id, value, metadata}, state) do
    safe_operation("sample_signal", fn ->
      process_signal_sample(signal_id, value, metadata, state)
    end)
    |> case do
      {:ok, new_state} -> {:noreply, new_state}
      {:error, _reason} -> {:noreply, state}  # Log already handled by safe_operation
    end
  end

  @impl true
  def handle_call({:get_samples, signal_id, count}, _from, state) do
    samples = get_signal_samples_from_buffer(signal_id, count)
    {:reply, {:ok, samples}, state}
  end

  @impl true
  def handle_call({:get_sampling_stats, signal_id}, _from, state) do
    stats = get_signal_sampling_stats(signal_id)
    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_call({:clear_buffer, signal_id}, _from, state) do
    safe_operation("clear_buffer", fn ->
      clear_signal_buffer(signal_id)
    end)
    |> case do
      {:ok, _} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_buffer_status, signal_id}, _from, state) do
    status = get_buffer_status_internal(signal_id)
    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_info(:cleanup_buffers, state) do
    new_state = safe_operation("cleanup_buffers", fn ->
      perform_buffer_cleanup(state)
    end)
    |> case do
      {:ok, cleaned_state} -> cleaned_state
      {:error, _reason} -> state
    end
    
    schedule_buffer_cleanup()
    {:noreply, new_state}
  end

  # Private Implementation

  defp process_signal_sample(signal_id, value, metadata, state) do
    with :ok <- validate_signal_value(value),
         {:ok, config} <- get_signal_config(signal_id),
         :ok <- check_sampling_rate(signal_id, config) do
      
      # Create sample entry
      sample = create_sample_entry(signal_id, value, metadata)
      
      # Add to buffer
      add_sample_to_buffer(signal_id, sample, config)
      
      # Update statistics
      update_sampling_statistics(signal_id, sample, state)
      
      # Store in data store if configured
      if should_persist_sample?(config, sample) do
        state.data_store.store_signal_data(signal_id, %{
          type: :sample,
          sample: sample
        })
      end
      
      log_signal_event(:debug, signal_id, "Sample processed", %{
        value: value,
        buffer_size: get_current_buffer_size(signal_id)
      })
      
      state
      
    else
      {:error, reason} ->
        log_signal_event(:warning, signal_id, "Sample rejected", %{
          reason: reason,
          value: value
        })
        {:error, reason}
    end
  end

  defp get_signal_config(signal_id) do
    case SignalRegistry.get_signal_config(signal_id) do
      {:ok, config} -> {:ok, config}
      {:error, :signal_not_found} -> 
        log_signal_event(:warning, signal_id, "Signal not registered")
        {:error, :signal_not_registered}
      error -> error
    end
  end

  defp check_sampling_rate(signal_id, config) do
    last_sample_time = get_last_sample_time(signal_id)
    current_time = System.monotonic_time(:microsecond)
    
    case last_sample_time do
      nil -> :ok  # First sample
      last_time ->
        interval_us = get_sampling_interval_us(config.sampling_rate)
        time_since_last = current_time - last_time
        
        if time_since_last >= interval_us do
          :ok
        else
          {:error, :sampling_rate_exceeded}
        end
    end
  end

  defp create_sample_entry(signal_id, value, metadata) do
    %{
      signal_id: signal_id,
      value: value,
      timestamp: System.monotonic_time(:microsecond),
      wall_clock: DateTime.utc_now(),
      metadata: metadata,
      sample_id: generate_sample_id(signal_id)
    }
  end

  defp add_sample_to_buffer(signal_id, sample, config) do
    # Get current buffer or create new one
    buffer = case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, existing_buffer}] -> existing_buffer
      [] -> :queue.new()
    end
    
    # Add sample to buffer with size limit
    new_buffer = add_to_buffer(buffer, sample, config.buffer_size)
    
    # Store updated buffer
    :ets.insert(:signal_buffers, {signal_id, new_buffer})
    
    # Update buffer timestamp
    :ets.insert(:signal_buffers, {:"#{signal_id}_last_sample", sample.timestamp})
  end

  defp update_sampling_statistics(signal_id, sample, _state) do
    current_stats = case :ets.lookup(:sampling_stats, signal_id) do
      [{^signal_id, stats}] -> stats
      [] -> create_initial_sampling_stats(signal_id)
    end
    
    updated_stats = %{
      current_stats |
      samples_count: current_stats.samples_count + 1,
      last_sample_at: sample.timestamp,
      last_sample_value: sample.value,
      total_data_points: current_stats.total_data_points + 1,
      average_value: calculate_running_average(current_stats, sample.value)
    }
    
    :ets.insert(:sampling_stats, {signal_id, updated_stats})
  end

  defp should_persist_sample?(config, _sample) do
    # Only persist based on configuration
    Map.get(config, :persist_samples, false) or
    Map.get(config, :retention_policy) != :memory_only
  end

  defp get_signal_samples_from_buffer(signal_id, count) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] ->
        buffer
        |> :queue.to_list()
        |> Enum.reverse()  # Most recent first
        |> Enum.take(count)
      [] -> []
    end
  end

  defp get_signal_sampling_stats(signal_id) do
    case :ets.lookup(:sampling_stats, signal_id) do
      [{^signal_id, stats}] -> stats
      [] -> %{error: :signal_not_found}
    end
  end

  defp clear_signal_buffer(signal_id) do
    :ets.delete(:signal_buffers, signal_id)
    :ets.delete(:signal_buffers, :"#{signal_id}_last_sample")
    
    log_signal_event(:info, signal_id, "Buffer cleared")
    :ok
  end

  defp get_buffer_status_internal(:all) do
    :ets.tab2list(:signal_buffers)
    |> Enum.filter(fn {key, _} -> is_binary(key) end)  # Filter out timestamp entries
    |> Enum.map(fn {signal_id, buffer} ->
      %{
        signal_id: signal_id,
        buffer_size: :queue.len(buffer),
        last_sample: get_last_sample_time(signal_id),
        memory_usage: estimate_buffer_memory(buffer)
      }
    end)
  end

  defp get_buffer_status_internal(signal_id) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] ->
        %{
          signal_id: signal_id,
          buffer_size: :queue.len(buffer),
          last_sample: get_last_sample_time(signal_id),
          memory_usage: estimate_buffer_memory(buffer),
          oldest_sample: get_oldest_sample_time(buffer),
          newest_sample: get_newest_sample_time(buffer)
        }
      [] ->
        %{error: :signal_not_found}
    end
  end

  defp perform_buffer_cleanup(state) do
    # Get all signals and their configurations
    {:ok, signals} = SignalRegistry.list_signals()
    
    cleanup_results = signals
    |> Enum.map(fn {signal_id, config} ->
      cleanup_signal_buffer(signal_id, config)
    end)
    
    successful_cleanups = Enum.count(cleanup_results, &(&1 == :ok))
    
    log_info("Buffer cleanup completed", %{
      signals_processed: length(cleanup_results),
      successful_cleanups: successful_cleanups
    })
    
    %{state | last_cleanup: DateTime.utc_now()}
  end

  defp cleanup_signal_buffer(signal_id, config) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] ->
        # Check if buffer needs cleanup based on retention policy
        if buffer_needs_cleanup?(buffer, config) do
          cleaned_buffer = apply_retention_policy(buffer, config)
          :ets.insert(:signal_buffers, {signal_id, cleaned_buffer})
          
          log_signal_event(:debug, signal_id, "Buffer cleaned up", %{
            original_size: :queue.len(buffer),
            new_size: :queue.len(cleaned_buffer)
          })
        end
        :ok
      [] -> :ok
    end
  end

  # Helper Functions

  defp get_sampling_interval_us(sampling_rate) do
    interval_ms = case sampling_rate do
      rate when is_atom(rate) -> Map.get(@sampling_intervals, rate, 100)
      rate when is_integer(rate) -> 1000 / rate  # Convert Hz to ms
    end
    
    round(interval_ms * 1000)  # Convert to microseconds
  end

  defp get_last_sample_time(signal_id) do
    case :ets.lookup(:signal_buffers, :"#{signal_id}_last_sample") do
      [{_, timestamp}] -> timestamp
      [] -> nil
    end
  end

  defp get_current_buffer_size(signal_id) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] -> :queue.len(buffer)
      [] -> 0
    end
  end

  defp generate_sample_id(signal_id) do
    "#{signal_id}_#{System.unique_integer([:positive, :monotonic])}"
  end

  defp create_initial_sampling_stats(signal_id) do
    %{
      signal_id: signal_id,
      samples_count: 0,
      first_sample_at: System.monotonic_time(:microsecond),
      last_sample_at: nil,
      last_sample_value: nil,
      total_data_points: 0,
      average_value: 0.0,
      created_at: DateTime.utc_now()
    }
  end

  defp calculate_running_average(current_stats, new_value) do
    if current_stats.samples_count == 0 do
      new_value
    else
      old_average = current_stats.average_value
      count = current_stats.samples_count
      (old_average * count + new_value) / (count + 1)
    end
  end

  defp estimate_buffer_memory(buffer) do
    # Rough estimate of memory usage
    sample_count = :queue.len(buffer)
    estimated_sample_size = 200  # bytes per sample (rough estimate)
    sample_count * estimated_sample_size
  end

  defp get_oldest_sample_time(buffer) do
    case :queue.peek(buffer) do
      {:value, sample} -> sample.timestamp
      :empty -> nil
    end
  end

  defp get_newest_sample_time(buffer) do
    case :queue.peek_r(buffer) do
      {:value, sample} -> sample.timestamp
      :empty -> nil
    end
  end

  defp buffer_needs_cleanup?(buffer, config) do
    buffer_size = :queue.len(buffer)
    max_size = Map.get(config, :buffer_size, 1000)
    
    # Cleanup if buffer is over 80% of max size
    buffer_size > (max_size * 0.8)
  end

  defp apply_retention_policy(buffer, config) do
    retention_policy = Map.get(config, :retention_policy, :default)
    buffer_size = Map.get(config, :buffer_size, 1000)
    
    case retention_policy do
      :keep_recent ->
        # Keep most recent samples
        samples = :queue.to_list(buffer)
        recent_samples = Enum.take(samples, -buffer_size)
        :queue.from_list(recent_samples)
        
      :time_based ->
        # Keep samples from last N minutes
        cutoff_time = System.monotonic_time(:microsecond) - (60 * 60 * 1_000_000)  # 1 hour
        samples = :queue.to_list(buffer)
        recent_samples = Enum.filter(samples, &(&1.timestamp > cutoff_time))
        :queue.from_list(recent_samples)
        
      :default ->
        # Simple size-based cleanup
        if :queue.len(buffer) > buffer_size do
          {_, trimmed_buffer} = :queue.out(buffer)
          trimmed_buffer
        else
          buffer
        end
    end
  end

  defp schedule_buffer_cleanup do
    # Cleanup every 5 minutes
    Process.send_after(self(), :cleanup_buffers, 5 * 60 * 1000)
  end
end