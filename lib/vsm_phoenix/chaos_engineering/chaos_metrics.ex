defmodule VsmPhoenix.ChaosEngineering.ChaosMetrics do
  @moduledoc """
  Collects and tracks metrics for chaos engineering experiments.
  Provides insights into system behavior under failure conditions.
  """

  use GenServer
  require Logger

  defmodule MetricPoint do
    @enforce_keys [:timestamp, :metric, :value]
    defstruct [
      :timestamp,
      :metric,
      :value,
      :tags,
      :metadata
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_fault_injection(fault) do
    GenServer.cast(__MODULE__, {:record_fault, fault})
  end

  def record_recovery(component, recovery_time) do
    GenServer.cast(__MODULE__, {:record_recovery, component, recovery_time})
  end

  def record_cascade(cascade) do
    GenServer.cast(__MODULE__, {:record_cascade, cascade})
  end

  def record_experiment(experiment, results) do
    GenServer.cast(__MODULE__, {:record_experiment, experiment, results})
  end

  def record_metric(metric_name, value, tags \\ %{}) do
    GenServer.cast(__MODULE__, {:record_metric, metric_name, value, tags})
  end

  def get_metrics(metric_name, time_range \\ :last_hour) do
    GenServer.call(__MODULE__, {:get_metrics, metric_name, time_range})
  end

  def get_statistics(metric_name) do
    GenServer.call(__MODULE__, {:get_statistics, metric_name})
  end

  def get_dashboard_data do
    GenServer.call(__MODULE__, :get_dashboard_data)
  end

  def export_metrics(format \\ :json) do
    GenServer.call(__MODULE__, {:export_metrics, format})
  end

  # Server Callbacks

  def init(opts) do
    state = %{
      metrics: %{},
      aggregations: %{},
      retention_period: Keyword.get(opts, :retention_period, 7 * 24 * 3600 * 1000),  # 7 days
      aggregation_interval: Keyword.get(opts, :aggregation_interval, 60_000),  # 1 minute
      max_points_per_metric: Keyword.get(opts, :max_points, 10_000)
    }

    schedule_aggregation()
    schedule_cleanup()
    
    {:ok, state}
  end

  def handle_cast({:record_fault, fault}, state) do
    metrics = [
      {"fault.injected", 1, %{type: to_string(fault.type), severity: to_string(fault.severity)}},
      {"fault.duration", fault.duration, %{type: to_string(fault.type)}},
      {"fault.impact_score", calculate_impact_score(fault), %{component: to_string(fault.target)}}
    ]
    
    new_state = Enum.reduce(metrics, state, fn {name, value, tags}, acc ->
      store_metric(acc, name, value, tags)
    end)
    
    {:noreply, new_state}
  end

  def handle_cast({:record_recovery, component, recovery_time}, state) do
    new_state = store_metric(state, "recovery.time", recovery_time, %{component: to_string(component)})
    
    {:noreply, new_state}
  end

  def handle_cast({:record_cascade, cascade}, state) do
    metrics = [
      {"cascade.blast_radius", cascade.blast_radius, %{initial: to_string(cascade.initial_failure.component)}},
      {"cascade.affected_components", length(cascade.affected_components), %{}},
      {"cascade.max_depth", calculate_max_depth(cascade.failure_sequence), %{}},
      {"cascade.duration", calculate_cascade_duration(cascade), %{}}
    ]
    
    new_state = Enum.reduce(metrics, state, fn {name, value, tags}, acc ->
      store_metric(acc, name, value, tags)
    end)
    
    {:noreply, new_state}
  end

  def handle_cast({:record_experiment, experiment, results}, state) do
    metrics = [
      {"experiment.executed", 1, %{type: to_string(experiment.type), name: experiment.name}},
      {"experiment.duration", calculate_duration(experiment), %{name: experiment.name}},
      {"experiment.success", if(results.success, do: 1, else: 0), %{name: experiment.name}},
      {"experiment.resilience_score", results[:resilience_score] || 0, %{name: experiment.name}}
    ]
    
    new_state = Enum.reduce(metrics, state, fn {name, value, tags}, acc ->
      store_metric(acc, name, value, tags)
    end)
    
    {:noreply, new_state}
  end

  def handle_cast({:record_metric, metric_name, value, tags}, state) do
    new_state = store_metric(state, metric_name, value, tags)
    
    {:noreply, new_state}
  end

  def handle_call({:get_metrics, metric_name, time_range}, _from, state) do
    metrics = get_metrics_in_range(state.metrics, metric_name, time_range)
    
    {:reply, {:ok, metrics}, state}
  end

  def handle_call({:get_statistics, metric_name}, _from, state) do
    stats = calculate_statistics(state.metrics, metric_name)
    
    {:reply, {:ok, stats}, state}
  end

  def handle_call(:get_dashboard_data, _from, state) do
    dashboard_data = compile_dashboard_data(state)
    
    {:reply, {:ok, dashboard_data}, state}
  end

  def handle_call({:export_metrics, format}, _from, state) do
    exported_data = export_metrics_impl(state.metrics, format)
    
    {:reply, {:ok, exported_data}, state}
  end

  def handle_info(:aggregate_metrics, state) do
    new_state = aggregate_metrics(state)
    
    schedule_aggregation()
    
    {:noreply, new_state}
  end

  def handle_info(:cleanup_old_metrics, state) do
    new_state = cleanup_old_metrics(state)
    
    schedule_cleanup()
    
    {:noreply, new_state}
  end

  # Private Functions

  defp store_metric(state, metric_name, value, tags) do
    point = %MetricPoint{
      timestamp: System.monotonic_time(:millisecond),
      metric: metric_name,
      value: value,
      tags: tags
    }
    
    metric_list = Map.get(state.metrics, metric_name, [])
    
    # Add new point and trim to max size
    updated_list = [point | metric_list]
      |> Enum.take(state.max_points_per_metric)
    
    %{state | metrics: Map.put(state.metrics, metric_name, updated_list)}
  end

  defp get_metrics_in_range(metrics, metric_name, time_range) do
    case Map.get(metrics, metric_name) do
      nil -> []
      metric_list ->
        cutoff_time = calculate_cutoff_time(time_range)
        Enum.filter(metric_list, fn point ->
          point.timestamp >= cutoff_time
        end)
    end
  end

  defp calculate_cutoff_time(:last_minute) do
    System.monotonic_time(:millisecond) - 60_000
  end

  defp calculate_cutoff_time(:last_hour) do
    System.monotonic_time(:millisecond) - 3_600_000
  end

  defp calculate_cutoff_time(:last_day) do
    System.monotonic_time(:millisecond) - 86_400_000
  end

  defp calculate_cutoff_time(:last_week) do
    System.monotonic_time(:millisecond) - 7 * 86_400_000
  end

  defp calculate_statistics(metrics, metric_name) do
    case Map.get(metrics, metric_name) do
      nil -> 
        %{count: 0, min: nil, max: nil, avg: nil, p50: nil, p95: nil, p99: nil}
      
      metric_list ->
        values = Enum.map(metric_list, & &1.value)
        sorted_values = Enum.sort(values)
        count = length(values)
        
        if count > 0 do
          %{
            count: count,
            min: Enum.min(values),
            max: Enum.max(values),
            avg: Enum.sum(values) / count,
            p50: percentile(sorted_values, 0.5),
            p95: percentile(sorted_values, 0.95),
            p99: percentile(sorted_values, 0.99),
            std_dev: standard_deviation(values)
          }
        else
          %{count: 0, min: nil, max: nil, avg: nil, p50: nil, p95: nil, p99: nil}
        end
    end
  end

  defp percentile(sorted_list, p) do
    index = round(p * (length(sorted_list) - 1))
    Enum.at(sorted_list, index)
  end

  defp standard_deviation(values) do
    count = length(values)
    
    if count > 1 do
      avg = Enum.sum(values) / count
      
      variance = Enum.reduce(values, 0, fn value, acc ->
        acc + :math.pow(value - avg, 2)
      end) / count
      
      :math.sqrt(variance)
    else
      0
    end
  end

  defp compile_dashboard_data(state) do
    %{
      fault_metrics: %{
        total_faults: count_metric_occurrences(state.metrics, "fault.injected"),
        avg_fault_duration: average_metric_value(state.metrics, "fault.duration"),
        fault_types: count_by_tag(state.metrics, "fault.injected", :type),
        fault_severities: count_by_tag(state.metrics, "fault.injected", :severity)
      },
      cascade_metrics: %{
        total_cascades: count_metric_occurrences(state.metrics, "cascade.blast_radius"),
        avg_blast_radius: average_metric_value(state.metrics, "cascade.blast_radius"),
        avg_cascade_depth: average_metric_value(state.metrics, "cascade.max_depth"),
        avg_affected_components: average_metric_value(state.metrics, "cascade.affected_components")
      },
      recovery_metrics: %{
        avg_recovery_time: average_metric_value(state.metrics, "recovery.time"),
        recovery_by_component: average_by_tag(state.metrics, "recovery.time", :component)
      },
      experiment_metrics: %{
        total_experiments: count_metric_occurrences(state.metrics, "experiment.executed"),
        success_rate: calculate_success_rate(state.metrics),
        avg_resilience_score: average_metric_value(state.metrics, "experiment.resilience_score"),
        experiments_by_type: count_by_tag(state.metrics, "experiment.executed", :type)
      },
      time_series: %{
        fault_injection_rate: time_series_data(state.metrics, "fault.injected", :last_hour),
        recovery_times: time_series_data(state.metrics, "recovery.time", :last_hour),
        resilience_scores: time_series_data(state.metrics, "experiment.resilience_score", :last_day)
      }
    }
  end

  defp count_metric_occurrences(metrics, metric_name) do
    case Map.get(metrics, metric_name) do
      nil -> 0
      metric_list -> length(metric_list)
    end
  end

  defp average_metric_value(metrics, metric_name) do
    case Map.get(metrics, metric_name) do
      nil -> 0
      [] -> 0
      metric_list ->
        values = Enum.map(metric_list, & &1.value)
        Enum.sum(values) / length(values)
    end
  end

  defp count_by_tag(metrics, metric_name, tag_name) do
    case Map.get(metrics, metric_name) do
      nil -> %{}
      metric_list ->
        metric_list
        |> Enum.group_by(fn point -> Map.get(point.tags, tag_name, "unknown") end)
        |> Enum.map(fn {tag_value, points} -> {tag_value, length(points)} end)
        |> Map.new()
    end
  end

  defp average_by_tag(metrics, metric_name, tag_name) do
    case Map.get(metrics, metric_name) do
      nil -> %{}
      metric_list ->
        metric_list
        |> Enum.group_by(fn point -> Map.get(point.tags, tag_name, "unknown") end)
        |> Enum.map(fn {tag_value, points} ->
          avg = Enum.sum(Enum.map(points, & &1.value)) / length(points)
          {tag_value, avg}
        end)
        |> Map.new()
    end
  end

  defp calculate_success_rate(metrics) do
    case Map.get(metrics, "experiment.success") do
      nil -> 0
      [] -> 0
      metric_list ->
        successes = Enum.count(metric_list, fn point -> point.value == 1 end)
        successes / length(metric_list)
    end
  end

  defp time_series_data(metrics, metric_name, time_range) do
    points = get_metrics_in_range(metrics, metric_name, time_range)
    
    points
    |> Enum.map(fn point ->
      %{
        timestamp: point.timestamp,
        value: point.value
      }
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  defp aggregate_metrics(state) do
    # Aggregate metrics over time intervals
    current_time = System.monotonic_time(:millisecond)
    interval = state.aggregation_interval
    
    aggregated = Enum.map(state.metrics, fn {metric_name, points} ->
      # Group points by interval
      grouped = Enum.group_by(points, fn point ->
        div(point.timestamp, interval)
      end)
      
      # Calculate aggregations for each interval
      aggregated_points = Enum.map(grouped, fn {interval_key, interval_points} ->
        values = Enum.map(interval_points, & &1.value)
        
        %MetricPoint{
          timestamp: interval_key * interval,
          metric: "#{metric_name}.aggregated",
          value: %{
            count: length(values),
            sum: Enum.sum(values),
            avg: Enum.sum(values) / length(values),
            min: Enum.min(values),
            max: Enum.max(values)
          },
          tags: %{aggregation: "1m"}
        }
      end)
      
      {metric_name, aggregated_points}
    end)
    |> Map.new()
    
    %{state | aggregations: aggregated}
  end

  defp cleanup_old_metrics(state) do
    cutoff_time = System.monotonic_time(:millisecond) - state.retention_period
    
    cleaned_metrics = Enum.map(state.metrics, fn {metric_name, points} ->
      retained_points = Enum.filter(points, fn point ->
        point.timestamp >= cutoff_time
      end)
      
      {metric_name, retained_points}
    end)
    |> Enum.filter(fn {_name, points} -> not Enum.empty?(points) end)
    |> Map.new()
    
    %{state | metrics: cleaned_metrics}
  end

  defp export_metrics_impl(metrics, :json) do
    metrics
    |> Enum.map(fn {metric_name, points} ->
      %{
        metric: metric_name,
        points: Enum.map(points, fn point ->
          %{
            timestamp: point.timestamp,
            value: point.value,
            tags: point.tags
          }
        end)
      }
    end)
    |> Jason.encode!()
  end

  defp export_metrics_impl(metrics, :csv) do
    header = "metric,timestamp,value,tags\n"
    
    rows = metrics
    |> Enum.flat_map(fn {metric_name, points} ->
      Enum.map(points, fn point ->
        tags_str = Jason.encode!(point.tags)
        "#{metric_name},#{point.timestamp},#{point.value},\"#{tags_str}\""
      end)
    end)
    |> Enum.join("\n")
    
    header <> rows
  end

  defp calculate_impact_score(fault) do
    base_score = case fault.severity do
      :low -> 25
      :medium -> 50
      :high -> 75
      :critical -> 100
    end
    
    # Adjust based on fault type
    type_multiplier = case fault.type do
      :network_partition -> 1.5
      :data_corruption -> 1.8
      :byzantine_fault -> 2.0
      _ -> 1.0
    end
    
    base_score * type_multiplier
  end

  defp calculate_max_depth(failure_sequence) when is_list(failure_sequence) do
    failure_sequence
    |> Enum.map(& &1.depth)
    |> Enum.max(fn -> 0 end)
  end

  defp calculate_max_depth(_), do: 0

  defp calculate_cascade_duration(cascade) do
    if cascade.started_at && cascade.ended_at do
      DateTime.diff(cascade.ended_at, cascade.started_at, :millisecond)
    else
      0
    end
  end

  defp calculate_duration(experiment) do
    if experiment.started_at && experiment.ended_at do
      DateTime.diff(experiment.ended_at, experiment.started_at, :millisecond)
    else
      0
    end
  end

  defp schedule_aggregation do
    Process.send_after(self(), :aggregate_metrics, 60_000)  # Every minute
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_old_metrics, 3_600_000)  # Every hour
  end
end