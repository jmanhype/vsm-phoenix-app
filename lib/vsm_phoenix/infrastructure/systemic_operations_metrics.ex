defmodule VsmPhoenix.Infrastructure.SystemicOperationsMetrics do
  @moduledoc """
  Agnostic System 1 Operations Metrics
  
  Tracks pure systemic patterns without domain-specific concerns:
  - Activity Rate: Operations per second
  - Success Ratio: Successful vs failed operations
  - Processing Latency: Time per operation
  - Throughput: Operations per time unit
  - Error Rate: Exceptions and failures
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @table_name :systemic_operations_metrics
  @history_table :systemic_operations_history
  @time_buckets_table :systemic_time_buckets
  
  # Time windows for rate calculations (milliseconds)
  @second 1_000
  @minute 60_000
  @hour 3_600_000
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc "Record an operation with its outcome and timing"
  def record_operation(operation_id, outcome, latency_ms, metadata \\ %{}) do
    GenServer.cast(@name, {:record_operation, operation_id, outcome, latency_ms, metadata})
  end
  
  @doc "Get current systemic metrics"
  def get_metrics do
    GenServer.call(@name, :get_metrics)
  end
  
  @doc "Get metrics for a specific time window"
  def get_windowed_metrics(window \\ :last_minute) do
    GenServer.call(@name, {:get_windowed_metrics, window})
  end
  
  @doc "Get real-time activity rate"
  def get_activity_rate do
    GenServer.call(@name, :get_activity_rate)
  end
  
  @doc "Get current throughput"
  def get_throughput(time_unit \\ :second) do
    GenServer.call(@name, {:get_throughput, time_unit})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("📊 Starting Systemic Operations Metrics...")
    
    # Create ETS tables
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@history_table, [:ordered_set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@time_buckets_table, [:ordered_set, :public, :named_table, {:read_concurrency, true}])
    
    # Initialize base metrics
    init_metrics()
    
    # Schedule periodic tasks
    schedule_bucket_rotation()
    schedule_metric_calculation()
    
    {:ok, %{
      started_at: :erlang.system_time(:millisecond),
      last_bucket_rotation: :erlang.system_time(:millisecond),
      last_calculation: :erlang.system_time(:millisecond)
    }}
  end
  
  @impl true
  def handle_cast({:record_operation, operation_id, outcome, latency_ms, metadata}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Determine outcome category
    outcome_category = categorize_outcome(outcome)
    
    # Record in history
    operation_record = %{
      id: operation_id,
      outcome: outcome,
      category: outcome_category,
      latency_ms: latency_ms,
      metadata: metadata,
      timestamp: timestamp
    }
    
    :ets.insert(@history_table, {timestamp, operation_record})
    
    # Update time bucket for rate calculations
    update_time_bucket(timestamp, outcome_category)
    
    # Update running metrics
    update_running_metrics(outcome_category, latency_ms)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = calculate_current_metrics()
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call({:get_windowed_metrics, window}, _from, state) do
    metrics = calculate_windowed_metrics(window)
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call(:get_activity_rate, _from, state) do
    rate = calculate_activity_rate()
    {:reply, rate, state}
  end
  
  @impl true
  def handle_call({:get_throughput, time_unit}, _from, state) do
    throughput = calculate_throughput(time_unit)
    {:reply, throughput, state}
  end
  
  @impl true
  def handle_info(:rotate_buckets, state) do
    rotate_time_buckets()
    schedule_bucket_rotation()
    {:noreply, %{state | last_bucket_rotation: :erlang.system_time(:millisecond)}}
  end
  
  @impl true
  def handle_info(:calculate_metrics, state) do
    # Calculate and store derived metrics
    calculate_and_store_metrics()
    schedule_metric_calculation()
    {:noreply, %{state | last_calculation: :erlang.system_time(:millisecond)}}
  end
  
  # Private Functions
  
  defp init_metrics do
    initial_metrics = %{
      # Counters
      total_operations: 0,
      successful_operations: 0,
      failed_operations: 0,
      error_operations: 0,
      
      # Rates (per second)
      activity_rate: 0.0,
      success_rate: 0.0,
      failure_rate: 0.0,
      error_rate: 0.0,
      
      # Latency statistics
      min_latency_ms: nil,
      max_latency_ms: nil,
      avg_latency_ms: 0.0,
      p50_latency_ms: 0.0,
      p95_latency_ms: 0.0,
      p99_latency_ms: 0.0,
      
      # Throughput
      throughput_per_second: 0.0,
      throughput_per_minute: 0.0,
      
      # Ratios
      success_ratio: 1.0,
      failure_ratio: 0.0,
      error_ratio: 0.0,
      
      # Metadata
      last_updated: :erlang.system_time(:millisecond),
      measurement_window_ms: @minute
    }
    
    :ets.insert(@table_name, {:current, initial_metrics})
  end
  
  defp categorize_outcome(outcome) do
    case outcome do
      :success -> :success
      :ok -> :success
      {:ok, _} -> :success
      :failure -> :failure
      :failed -> :failure
      {:error, _} -> :error
      :error -> :error
      :timeout -> :error
      :exception -> :error
      _ -> :unknown
    end
  end
  
  defp update_time_bucket(timestamp, outcome_category) do
    # Round to nearest second for bucketing
    bucket_key = div(timestamp, @second) * @second
    
    # Get or create bucket
    bucket = case :ets.lookup(@time_buckets_table, bucket_key) do
      [{^bucket_key, existing}] -> existing
      [] -> %{
        total: 0,
        success: 0,
        failure: 0,
        error: 0,
        unknown: 0
      }
    end
    
    # Update bucket
    updated_bucket = Map.update(bucket, :total, 1, &(&1 + 1))
    |> Map.update(outcome_category, 1, &(&1 + 1))
    
    :ets.insert(@time_buckets_table, {bucket_key, updated_bucket})
  end
  
  defp update_running_metrics(outcome_category, latency_ms) do
    [{:current, metrics}] = :ets.lookup(@table_name, :current)
    
    updated_metrics = metrics
    |> Map.update(:total_operations, 1, &(&1 + 1))
    |> update_outcome_counts(outcome_category)
    |> update_latency_stats(latency_ms)
    |> Map.put(:last_updated, :erlang.system_time(:millisecond))
    
    :ets.insert(@table_name, {:current, updated_metrics})
  end
  
  defp update_outcome_counts(metrics, :success) do
    Map.update(metrics, :successful_operations, 1, &(&1 + 1))
  end
  defp update_outcome_counts(metrics, :failure) do
    Map.update(metrics, :failed_operations, 1, &(&1 + 1))
  end
  defp update_outcome_counts(metrics, :error) do
    Map.update(metrics, :error_operations, 1, &(&1 + 1))
  end
  defp update_outcome_counts(metrics, _), do: metrics
  
  defp update_latency_stats(metrics, latency_ms) when is_number(latency_ms) do
    # Update min/max
    new_min = case metrics.min_latency_ms do
      nil -> latency_ms
      current -> min(current, latency_ms)
    end
    
    new_max = case metrics.max_latency_ms do
      nil -> latency_ms
      current -> max(current, latency_ms)
    end
    
    # Update average (simplified - in production would use more sophisticated approach)
    total_ops = metrics.total_operations
    new_avg = if total_ops > 1 do
      ((metrics.avg_latency_ms * (total_ops - 1)) + latency_ms) / total_ops
    else
      latency_ms
    end
    
    %{metrics |
      min_latency_ms: new_min,
      max_latency_ms: new_max,
      avg_latency_ms: new_avg
    }
  end
  defp update_latency_stats(metrics, _), do: metrics
  
  defp calculate_current_metrics do
    [{:current, base_metrics}] = :ets.lookup(@table_name, :current)
    
    # Calculate rates from time buckets
    now = :erlang.system_time(:millisecond)
    one_minute_ago = now - @minute
    
    # Get all buckets from last minute
    recent_buckets = :ets.select(@time_buckets_table, [
      {{'$1', '$2'}, [{:'>=', '$1', one_minute_ago}], ['$2']}
    ])
    
    # Aggregate bucket data
    {total, success, failure, error} = Enum.reduce(recent_buckets, {0, 0, 0, 0}, 
      fn bucket, {t, s, f, e} ->
        {t + bucket.total, s + bucket.success, f + bucket.failure, e + bucket.error}
      end)
    
    # Calculate rates (per second)
    time_span_seconds = 60.0  # Using full minute for stable rates
    activity_rate = total / time_span_seconds
    success_rate = success / time_span_seconds
    failure_rate = failure / time_span_seconds
    error_rate = error / time_span_seconds
    
    # Calculate ratios
    success_ratio = if total > 0, do: success / total, else: 1.0
    failure_ratio = if total > 0, do: failure / total, else: 0.0
    error_ratio = if total > 0, do: error / total, else: 0.0
    
    # Calculate latency percentiles from recent operations
    latencies = get_recent_latencies(one_minute_ago)
    percentiles = calculate_percentiles(latencies)
    
    %{base_metrics |
      activity_rate: Float.round(activity_rate, 3),
      success_rate: Float.round(success_rate, 3),
      failure_rate: Float.round(failure_rate, 3),
      error_rate: Float.round(error_rate, 3),
      throughput_per_second: Float.round(activity_rate, 3),
      throughput_per_minute: Float.round(total * 1.0, 3),
      success_ratio: Float.round(success_ratio, 3),
      failure_ratio: Float.round(failure_ratio, 3),
      error_ratio: Float.round(error_ratio, 3),
      p50_latency_ms: percentiles.p50,
      p95_latency_ms: percentiles.p95,
      p99_latency_ms: percentiles.p99
    }
  end
  
  defp calculate_windowed_metrics(window) do
    now = :erlang.system_time(:millisecond)
    start_time = case window do
      :last_second -> now - @second
      :last_minute -> now - @minute
      :last_hour -> now - @hour
      :last_5_minutes -> now - (5 * @minute)
      :last_15_minutes -> now - (15 * @minute)
      _ -> now - @minute
    end
    
    # Get operations in window
    operations = get_operations_in_window(start_time, now)
    
    if length(operations) == 0 do
      %{
        window: window,
        start_time: start_time,
        end_time: now,
        total_operations: 0,
        activity_rate: 0.0,
        success_ratio: 1.0,
        avg_latency_ms: 0.0,
        throughput: 0.0,
        error_rate: 0.0
      }
    else
      # Calculate metrics for window
      total = length(operations)
      successful = Enum.count(operations, fn op -> op.category == :success end)
      errors = Enum.count(operations, fn op -> op.category == :error end)
      
      latencies = operations
      |> Enum.map(fn op -> op.latency_ms end)
      |> Enum.filter(&is_number/1)
      
      avg_latency = if length(latencies) > 0 do
        Enum.sum(latencies) / length(latencies)
      else
        0.0
      end
      
      time_span_seconds = (now - start_time) / @second
      
      %{
        window: window,
        start_time: start_time,
        end_time: now,
        total_operations: total,
        activity_rate: Float.round(total / time_span_seconds, 3),
        success_ratio: Float.round(successful / total, 3),
        avg_latency_ms: Float.round(avg_latency, 2),
        throughput: Float.round(total / time_span_seconds, 3),
        error_rate: Float.round(errors / time_span_seconds, 3)
      }
    end
  end
  
  defp calculate_activity_rate do
    now = :erlang.system_time(:millisecond)
    one_second_ago = now - @second
    
    # Count operations in last second
    count = :ets.select_count(@history_table, [
      {{'$1', '_'}, [{:'>=', '$1', one_second_ago}], [true]}
    ])
    
    Float.round(count * 1.0, 2)
  end
  
  defp calculate_throughput(time_unit) do
    now = :erlang.system_time(:millisecond)
    
    {window_ms, divisor} = case time_unit do
      :second -> {@second, 1.0}
      :minute -> {@minute, 1.0}
      :hour -> {@hour, 1.0}
      _ -> {@second, 1.0}
    end
    
    start_time = now - window_ms
    
    count = :ets.select_count(@history_table, [
      {{'$1', '_'}, [{:'>=', '$1', start_time}], [true]}
    ])
    
    Float.round(count / divisor, 2)
  end
  
  defp get_recent_latencies(since_timestamp) do
    # Get all operations since timestamp
    operations = :ets.tab2list(@history_table)
    |> Enum.filter(fn {timestamp, _} -> timestamp >= since_timestamp end)
    |> Enum.map(fn {_, operation} -> operation.latency_ms end)
    |> Enum.filter(&is_number/1)
    |> Enum.sort()
    
    operations
  end
  
  defp get_operations_in_window(start_time, end_time) do
    :ets.tab2list(@history_table)
    |> Enum.filter(fn {timestamp, _} -> 
      timestamp >= start_time and timestamp <= end_time 
    end)
    |> Enum.map(fn {_, operation} -> operation end)
  end
  
  defp calculate_percentiles([]), do: %{p50: 0, p95: 0, p99: 0}
  defp calculate_percentiles(sorted_latencies) do
    count = length(sorted_latencies)
    p50_idx = round(count * 0.50) - 1
    p95_idx = round(count * 0.95) - 1  
    p99_idx = round(count * 0.99) - 1
    
    %{
      p50: Enum.at(sorted_latencies, max(0, p50_idx)) || 0,
      p95: Enum.at(sorted_latencies, max(0, p95_idx)) || 0,
      p99: Enum.at(sorted_latencies, max(0, p99_idx)) || 0
    }
  end
  
  defp rotate_time_buckets do
    # Remove buckets older than 5 minutes
    cutoff = :erlang.system_time(:millisecond) - (5 * @minute)
    
    old_buckets = :ets.select(@time_buckets_table, [
      {{'$1', '_'}, [{:'<', '$1', cutoff}], ['$1']}
    ])
    
    Enum.each(old_buckets, fn key ->
      :ets.delete(@time_buckets_table, key)
    end)
  end
  
  defp calculate_and_store_metrics do
    # This is where we could calculate more complex derived metrics
    # For now, just ensure current metrics are up to date
    metrics = calculate_current_metrics()
    
    # Publish to telemetry
    :telemetry.execute(
      [:vsm, :system1, :systemic_metrics],
      %{
        activity_rate: metrics.activity_rate,
        success_ratio: metrics.success_ratio,
        avg_latency_ms: metrics.avg_latency_ms,
        throughput_per_second: metrics.throughput_per_second,
        error_rate: metrics.error_rate
      },
      %{}
    )
  end
  
  defp schedule_bucket_rotation do
    Process.send_after(self(), :rotate_buckets, @second * 10)  # Every 10 seconds
  end
  
  defp schedule_metric_calculation do
    Process.send_after(self(), :calculate_metrics, @second * 5)  # Every 5 seconds
  end
end