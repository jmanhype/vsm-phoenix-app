defmodule VsmPhoenix.Infrastructure.OperationsMetrics do
  @moduledoc """
  Dynamic Operations Metrics for System 1
  
  Tracks real operational data and provides accurate metrics for:
  - Success rates based on actual operations
  - Orders processed in real-time
  - Customer satisfaction from actual interactions
  - Performance metrics from operation timing
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @table_name :operations_metrics
  @history_table :operations_history
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def record_operation(context, operation_type, status, duration \\ nil, metadata \\ %{}) do
    GenServer.cast(@name, {:record_operation, context, operation_type, status, duration, metadata})
  end
  
  def record_customer_interaction(context, interaction_type, satisfaction_score) do
    GenServer.cast(@name, {:record_customer_interaction, context, interaction_type, satisfaction_score})
  end
  
  def get_context_metrics(context) do
    GenServer.call(@name, {:get_context_metrics, context})
  end
  
  def get_all_metrics do
    GenServer.call(@name, :get_all_metrics)
  end
  
  def get_performance_trends(context, time_window \\ :last_hour) do
    GenServer.call(@name, {:get_performance_trends, context, time_window})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🏭 Starting Operations Metrics tracking...")
    
    # Create ETS tables for metrics storage
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@history_table, [:bag, :public, :named_table, {:read_concurrency, true}])
    
    # Schedule periodic cleanup and aggregation
    schedule_cleanup()
    schedule_aggregation()
    
    {:ok, %{
      started_at: DateTime.utc_now(),
      last_cleanup: DateTime.utc_now(),
      last_aggregation: DateTime.utc_now()
    }}
  end
  
  @impl true
  def handle_cast({:record_operation, context, operation_type, status, duration, metadata}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Record operation in history
    operation_record = %{
      context: context,
      type: operation_type,
      status: status,
      duration: duration,
      metadata: metadata,
      timestamp: timestamp
    }
    
    :ets.insert(@history_table, {timestamp, operation_record})
    
    # Update context metrics
    update_context_metrics(context, operation_type, status, duration)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:record_customer_interaction, context, interaction_type, satisfaction_score}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Record interaction
    interaction_record = %{
      context: context,
      type: interaction_type,
      satisfaction: satisfaction_score,
      timestamp: timestamp
    }
    
    :ets.insert(@history_table, {timestamp, interaction_record})
    
    # Update customer satisfaction metrics
    update_customer_satisfaction(context, satisfaction_score)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call({:get_context_metrics, context}, _from, state) do
    metrics = case :ets.lookup(@table_name, context) do
      [{^context, stored_metrics}] -> stored_metrics
      [] -> default_metrics(context)
    end
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call(:get_all_metrics, _from, state) do
    all_metrics = :ets.tab2list(@table_name)
    |> Enum.into(%{})
    
    {:reply, all_metrics, state}
  end
  
  @impl true
  def handle_call({:get_performance_trends, context, time_window}, _from, state) do
    trends = calculate_performance_trends(context, time_window)
    {:reply, trends, state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Clean up old history entries (keep last 24 hours)
    cutoff = :erlang.system_time(:millisecond) - (24 * 60 * 60 * 1000)
    
    # Delete old entries using simpler approach
    all_entries = :ets.tab2list(@history_table)
    old_entries = Enum.filter(all_entries, fn {timestamp, _record} -> timestamp < cutoff end)
    Enum.each(old_entries, fn {timestamp, record} -> 
      :ets.delete_object(@history_table, {timestamp, record})
    end)
    
    schedule_cleanup()
    {:noreply, %{state | last_cleanup: DateTime.utc_now()}}
  end
  
  @impl true
  def handle_info(:aggregate, state) do
    # Perform periodic aggregation of metrics
    aggregate_all_metrics()
    
    schedule_aggregation()
    {:noreply, %{state | last_aggregation: DateTime.utc_now()}}
  end
  
  # Private Functions
  
  defp update_context_metrics(context, operation_type, status, duration) do
    # Get current metrics or create default
    current_metrics = case :ets.lookup(@table_name, context) do
      [{^context, metrics}] -> metrics
      [] -> default_metrics(context)
    end
    
    # Update metrics based on operation
    updated_metrics = current_metrics
    |> update_operation_counts(operation_type, status)
    |> update_success_rate(status)
    |> update_processing_time(duration)
    |> Map.put(:last_updated, DateTime.utc_now())
    
    # Store updated metrics
    :ets.insert(@table_name, {context, updated_metrics})
  end
  
  defp update_operation_counts(metrics, operation_type, status) do
    # Update total operations
    new_total = metrics.operations_total + 1
    
    # Update operation type counts
    type_counts = Map.get(metrics, :operation_types, %{})
    new_type_counts = Map.update(type_counts, operation_type, 1, &(&1 + 1))
    
    # Update status counts
    status_counts = Map.get(metrics, :status_counts, %{success: 0, failure: 0, error: 0})
    status_key = case status do
      :ok -> :success
      :success -> :success
      {:ok, _} -> :success
      {:error, _} -> :error
      :error -> :error
      _ -> :failure
    end
    new_status_counts = Map.update(status_counts, status_key, 1, &(&1 + 1))
    
    %{metrics |
      operations_total: new_total,
      operation_types: new_type_counts,
      status_counts: new_status_counts
    }
  end
  
  defp update_success_rate(metrics, status) do
    success = case status do
      :ok -> true
      :success -> true
      {:ok, _} -> true
      _ -> false
    end
    
    total_ops = metrics.operations_total + 1
    current_successes = metrics.success_count || 0
    new_successes = if success, do: current_successes + 1, else: current_successes
    
    new_success_rate = if total_ops > 0, do: new_successes / total_ops, else: 1.0
    
    %{metrics |
      success_rate: new_success_rate,
      success_count: new_successes
    }
  end
  
  defp update_processing_time(metrics, nil), do: metrics
  defp update_processing_time(metrics, duration) when is_number(duration) do
    current_avg = metrics.average_processing_time || 0
    total_ops = metrics.operations_total
    
    # Calculate new rolling average
    new_avg = if total_ops > 0 do
      (current_avg * (total_ops - 1) + duration) / total_ops
    else
      duration
    end
    
    %{metrics | average_processing_time: new_avg}
  end
  
  defp update_customer_satisfaction(context, satisfaction_score) do
    current_metrics = case :ets.lookup(@table_name, context) do
      [{^context, metrics}] -> metrics
      [] -> default_metrics(context)
    end
    
    # Calculate rolling customer satisfaction
    current_satisfaction = current_metrics.customer_satisfaction || 0.95
    interaction_count = Map.get(current_metrics, :customer_interactions, 0) + 1
    
    # Weighted average with more weight to recent interactions
    weight = min(interaction_count, 100) / 100  # Weight approaches 1 as interactions increase
    new_satisfaction = current_satisfaction * (1 - weight * 0.1) + satisfaction_score * (weight * 0.1)
    
    updated_metrics = %{current_metrics |
      customer_satisfaction: new_satisfaction,
      customer_interactions: interaction_count,
      last_updated: DateTime.utc_now()
    }
    
    :ets.insert(@table_name, {context, updated_metrics})
  end
  
  defp default_metrics(context) do
    %{
      context: context,
      operations_total: 0,
      success_count: 0,
      success_rate: 1.0,
      average_processing_time: 0,
      customer_satisfaction: 0.95,
      customer_interactions: 0,
      operation_types: %{},
      status_counts: %{success: 0, failure: 0, error: 0},
      created_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp calculate_performance_trends(context, time_window) do
    # Calculate time range
    now = :erlang.system_time(:millisecond)
    start_time = case time_window do
      :last_hour -> now - (60 * 60 * 1000)
      :last_day -> now - (24 * 60 * 60 * 1000)
      :last_week -> now - (7 * 24 * 60 * 60 * 1000)
      _ -> now - (60 * 60 * 1000)  # Default to last hour
    end
    
    # Get all operations and filter in Elixir to avoid complex ETS patterns
    all_operations = :ets.tab2list(@history_table)
    operations = all_operations
    |> Enum.filter(fn {timestamp, record} ->
      timestamp >= start_time and record.context == context
    end)
    |> Enum.map(fn {_timestamp, record} -> record end)
    
    if length(operations) == 0 do
      %{
        context: context,
        time_window: time_window,
        operations_count: 0,
        success_rate: 1.0,
        average_duration: 0,
        throughput: 0.0,
        error_rate: 0.0
      }
    else
      # Calculate trends
      successes = Enum.count(operations, fn op ->
        op.status in [:ok, :success] or match?({:ok, _}, op.status)
      end)
      
      total_duration = operations
      |> Enum.filter(fn op -> is_number(op.duration) end)
      |> Enum.sum_by(fn op -> op.duration end)
      
      operations_with_duration = Enum.count(operations, fn op -> is_number(op.duration) end)
      
      time_span_hours = (now - start_time) / (1000 * 60 * 60)
      
      %{
        context: context,
        time_window: time_window,
        operations_count: length(operations),
        success_rate: successes / length(operations),
        average_duration: if(operations_with_duration > 0, do: total_duration / operations_with_duration, else: 0),
        throughput: length(operations) / time_span_hours,
        error_rate: (length(operations) - successes) / length(operations),
        period_start: DateTime.from_unix!(div(start_time, 1000)),
        period_end: DateTime.from_unix!(div(now, 1000))
      }
    end
  end
  
  defp aggregate_all_metrics do
    # Get all contexts that have metrics
    contexts = :ets.tab2list(@table_name)
    |> Enum.map(fn {context, _metrics} -> context end)
    
    # Publish aggregated metrics
    Enum.each(contexts, fn context ->
      metrics = case :ets.lookup(@table_name, context) do
        [{^context, stored_metrics}] -> stored_metrics
        [] -> default_metrics(context)
      end
      
      # Publish to telemetry
      :telemetry.execute(
        [:vsm, :operations, :metrics],
        %{
          operations_total: metrics.operations_total,
          success_rate: metrics.success_rate,
          average_processing_time: metrics.average_processing_time,
          customer_satisfaction: metrics.customer_satisfaction
        },
        %{context: context}
      )
    end)
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60 * 60 * 1000)  # Every hour
  end
  
  defp schedule_aggregation do
    Process.send_after(self(), :aggregate, 5 * 60 * 1000)  # Every 5 minutes
  end
end