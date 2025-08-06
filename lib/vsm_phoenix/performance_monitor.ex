defmodule VsmPhoenix.PerformanceMonitor do
  @moduledoc """
  Performance monitoring for the VSM system
  
  Collects and analyzes performance metrics across all VSM systems
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def collect_metrics do
    GenServer.call(@name, :collect_metrics)
  end
  
  def get_performance_report do
    GenServer.call(@name, :get_performance_report)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Performance Monitor initializing...")
    
    state = %{
      metrics_history: [],
      current_metrics: %{},
      alerts: [],
      trends: %{
        cpu: %{direction: :stable, rate: 0.0},
        memory: %{direction: :stable, rate: 0.0},
        processes: %{direction: :stable, rate: 0.0},
        messages: %{direction: :stable, rate: 0.0}
      },
      baselines: %{
        cpu_utilization: nil,
        memory_usage: nil,
        process_count: nil,
        message_throughput: nil
      },
      anomalies: [],
      performance_score: 1.0,
      metrics_cache: %{}
    }
    
    # Subscribe to system metrics
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:variety_metrics")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:telemetry:metrics")
    
    # Schedule periodic collection
    Process.send_after(self(), :collect_metrics, 5_000)
    
    # Schedule trend analysis
    Process.send_after(self(), :analyze_trends, 30_000)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:collect_metrics, _from, state) do
    metrics = collect_system_metrics()
    
    new_history = [metrics | state.metrics_history] |> Enum.take(100)
    new_state = %{state | 
      metrics_history: new_history,
      current_metrics: metrics
    }
    
    {:reply, metrics, new_state}
  end
  
  @impl true
  def handle_call(:get_performance_report, _from, state) do
    report = generate_performance_report(state)
    {:reply, report, state}
  end
  
  @impl true
  def handle_call(:get_current_metrics, _from, state) do
    current_metrics = %{
      performance_score: state.performance_score,
      trends: state.trends,
      current_metrics: state.current_metrics,
      alerts: state.alerts,
      anomalies: state.anomalies
    }
    {:reply, current_metrics, state}
  end
  
  @impl true
  def handle_info(:collect_metrics, state) do
    # Collect metrics directly without calling handle_call
    metrics = collect_system_metrics()
    
    # Update state with new metrics
    new_state = %{state | 
      current_metrics: metrics,
      metrics_history: [metrics | Enum.take(state.metrics_history, 100)]
    }
    
    # Check for alerts
    new_state = %{new_state | alerts: check_alerts(metrics, state)}
    
    # Schedule next collection
    schedule_collection()
    
    # Return updated state
    {:noreply, new_state}
  end
  
  defp collect_system_metrics do
    # Collect comprehensive metrics
    memory = :erlang.memory()
    processes = Process.list()
    
    # Get scheduler utilization safely
    scheduler_util = get_scheduler_utilization()
    
    # Get run queue lengths
    run_queue = :erlang.statistics(:run_queue)
    
    # Get IO statistics safely
    {input, output} = try do
      {{i, o}, _} = :erlang.statistics(:io)
      {i, o}
    rescue
      _ -> {0, 0}
    end
    
    # Get reduction counts safely
    reductions = try do
      {_, r} = :erlang.statistics(:reductions)
      r
    rescue
      _ -> 0
    end
    
    # Calculate derived metrics
    memory_mb = memory[:total] / 1_048_576
    process_memory_avg = if length(processes) > 0 do
      memory[:processes] / length(processes) / 1024  # KB per process
    else
      0.0
    end
    
    # Get message queue stats
    queue_stats = get_message_queue_stats(processes)
    
    %{
      timestamp: DateTime.utc_now(),
      monotonic_time: System.monotonic_time(:millisecond),
      memory: %{
        total_mb: Float.round(memory_mb, 1),
        processes_mb: Float.round(memory[:processes] / 1_048_576, 1),
        system_mb: Float.round(memory[:system] / 1_048_576, 1),
        atom_mb: Float.round(memory[:atom] / 1_048_576, 1),
        binary_mb: Float.round(memory[:binary] / 1_048_576, 1),
        ets_mb: Float.round(memory[:ets] / 1_048_576, 1)
      },
      processes: %{
        count: length(processes),
        memory_avg_kb: Float.round(process_memory_avg, 1),
        message_queues: queue_stats
      },
      system: %{
        uptime_seconds: :erlang.statistics(:wall_clock) |> elem(0) |> div(1000),
        scheduler_utilization: scheduler_util,
        run_queue_length: run_queue,
        reductions: reductions,
        io_input_kb: if(is_number(input), do: Float.round(input / 1024, 1), else: 0.0),
        io_output_kb: if(is_number(output), do: Float.round(output / 1024, 1), else: 0.0)
      },
      vsm_specific: collect_vsm_metrics()
    }
  end
  
  defp get_message_queue_stats(processes) do
    stats = processes
    |> Enum.map(fn pid ->
      case Process.info(pid, [:message_queue_len, :registered_name]) do
        nil -> nil
        info -> info
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reduce(%{total: 0, max: 0, processes_with_queues: 0, named_queues: %{}}, fn info, acc ->
      queue_len = info[:message_queue_len]
      name = info[:registered_name]
      
      new_acc = %{acc |
        total: acc.total + queue_len,
        max: max(acc.max, queue_len),
        processes_with_queues: if(queue_len > 0, do: acc.processes_with_queues + 1, else: acc.processes_with_queues)
      }
      
      # Track named processes with significant queues
      if name && queue_len > 10 do
        put_in(new_acc, [:named_queues, name], queue_len)
      else
        new_acc
      end
    end)
    
    avg = if length(processes) > 0 do
      Float.round(stats.total / length(processes), 2)
    else
      0.0
    end
    
    Map.put(stats, :average, avg)
  end
  
  defp collect_vsm_metrics do
    # Collect VSM-specific metrics
    %{
      s1_agents: count_s1_agents(),
      active_amplifiers: count_active_components("amplifier"),
      active_filters: count_active_components("filter"),
      variety_balance: get_variety_balance_summary()
    }
  end
  
  defp count_s1_agents do
    try do
      VsmPhoenix.System1.Registry.count()
    rescue
      _ -> 0
    end
  end
  
  defp count_active_components(type) do
    # Count processes with names matching pattern
    try do
      Process.list()
      |> Enum.count(fn pid ->
        try do
          case Process.info(pid, :registered_name) do
            nil -> false
            {:registered_name, name} when is_atom(name) -> 
              name_str = Atom.to_string(name)
              String.contains?(name_str, type)
            _ -> false
          end
        rescue
          _ -> false
        end
      end)
    rescue
      _ -> 0
    end
  end
  
  defp get_variety_balance_summary do
    # Try to get cached variety metrics
    try do
      metrics = VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.get_all_metrics()
      
      %{
        average_ratio: metrics.summary[:average_ratio] || 0.0,
        balance_score: metrics.summary[:balance_score] || 0.0,
        information_efficiency: metrics.summary[:information_efficiency] || 0.0
      }
    rescue
      _ -> %{average_ratio: 0.0, balance_score: 0.0, information_efficiency: 0.0}
    end
  end

  defp get_scheduler_utilization do
    # Safer scheduler utilization check
    try do
      case :scheduler.utilization(1) do
        [utilization | _] when is_tuple(utilization) -> elem(utilization, 1)
        _ -> 0.0
      end
    rescue
      _ -> 0.0
    catch
      _, _ -> 0.0
    end
  end
  
  defp schedule_collection do
    Process.send_after(self(), :collect_metrics, 30_000)  # Every 30 seconds
  end
  
  @impl true
  def handle_info({:variety_update, metrics}, state) do
    # Cache variety metrics for performance analysis
    new_cache = Map.put(state.metrics_cache || %{}, :variety_metrics, metrics)
    new_state = Map.put(state, :metrics_cache, new_cache)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:analyze_trends, state) do
    # Analyze performance trends
    new_trends = calculate_trends(state.metrics_history)
    
    # Update baselines if needed
    new_baselines = update_baselines(state.baselines, state.metrics_history)
    
    # Detect anomalies
    anomalies = detect_anomalies(state.current_metrics, new_baselines, new_trends)
    
    # Calculate performance score
    performance_score = calculate_performance_score(state.current_metrics, new_trends, anomalies)
    
    # Generate alerts for significant changes
    new_alerts = generate_trend_alerts(new_trends, anomalies, state.alerts)
    
    new_state = %{state |
      trends: new_trends,
      baselines: new_baselines,
      anomalies: anomalies ++ state.anomalies |> Enum.take(50),
      performance_score: performance_score,
      alerts: new_alerts
    }
    
    # Log significant changes
    log_trend_changes(state.trends, new_trends)
    
    # Schedule next analysis
    Process.send_after(self(), :analyze_trends, 30_000)
    
    {:noreply, new_state}
  end
  
  defp generate_performance_report(state) do
    %{
      current: state.current_metrics,
      trends: state.trends,
      alerts: state.alerts,
      performance_score: state.performance_score,
      baselines: state.baselines,
      recent_anomalies: Enum.take(state.anomalies, 10),
      history_summary: summarize_history(state.metrics_history),
      recommendations: generate_recommendations(state)
    }
  end
  
  defp calculate_trends(history) do
    if length(history) < 5 do
      # Not enough data for trend analysis
      %{
        cpu: %{direction: :unknown, rate: 0.0},
        memory: %{direction: :unknown, rate: 0.0},
        processes: %{direction: :unknown, rate: 0.0},
        messages: %{direction: :unknown, rate: 0.0}
      }
    else
      # Take last 10 measurements for trend calculation
      recent = Enum.take(history, 10)
      
      %{
        cpu: calculate_metric_trend(recent, [:system, :scheduler_utilization]),
        memory: calculate_metric_trend(recent, [:memory, :total_mb]),
        processes: calculate_metric_trend(recent, [:processes, :count]),
        messages: calculate_metric_trend(recent, [:processes, :message_queues, :total])
      }
    end
  end
  
  defp calculate_metric_trend(history, path) do
    values = history
    |> Enum.map(fn metrics -> get_in(metrics, path) || 0 end)
    |> Enum.reject(&is_nil/1)
    
    if length(values) < 2 do
      %{direction: :unknown, rate: 0.0}
    else
      # Calculate linear regression slope
      {slope, _intercept} = linear_regression(values)
      
      # Determine direction based on slope
      direction = cond do
        slope > 0.05 -> :increasing
        slope < -0.05 -> :decreasing
        true -> :stable
      end
      
      %{
        direction: direction,
        rate: Float.round(slope, 3),
        last_value: List.first(values),
        avg_value: Enum.sum(values) / length(values)
      }
    end
  end
  
  defp linear_regression(values) do
    n = length(values)
    xs = Enum.to_list(1..n)
    
    x_mean = Enum.sum(xs) / n
    y_mean = Enum.sum(values) / n
    
    xy_sum = xs
    |> Enum.zip(values)
    |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
    |> Enum.sum()
    
    xx_sum = xs
    |> Enum.map(fn x -> (x - x_mean) * (x - x_mean) end)
    |> Enum.sum()
    
    slope = if xx_sum == 0, do: 0, else: xy_sum / xx_sum
    intercept = y_mean - slope * x_mean
    
    {slope, intercept}
  end
  
  defp update_baselines(baselines, history) do
    if length(history) < 20 do
      baselines  # Keep existing baselines
    else
      # Calculate new baselines from stable periods
      stable_metrics = history
      |> Enum.take(20)
      |> Enum.drop(5)  # Skip most recent to avoid temporary spikes
      
      %{
        cpu_utilization: calculate_baseline(stable_metrics, [:system, :scheduler_utilization]),
        memory_usage: calculate_baseline(stable_metrics, [:memory, :total_mb]),
        process_count: calculate_baseline(stable_metrics, [:processes, :count]),
        message_throughput: calculate_baseline(stable_metrics, [:processes, :message_queues, :total])
      }
    end
  end
  
  defp calculate_baseline(metrics, path) do
    values = metrics
    |> Enum.map(fn m -> get_in(m, path) end)
    |> Enum.reject(&is_nil/1)
    
    if Enum.empty?(values) do
      nil
    else
      # Use median as baseline (more robust to outliers)
      sorted = Enum.sort(values)
      mid = div(length(sorted), 2)
      
      if rem(length(sorted), 2) == 0 do
        (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
      else
        Enum.at(sorted, mid)
      end
    end
  end
  
  defp detect_anomalies(current_metrics, baselines, trends) do
    anomalies = []
    
    # Memory anomaly detection
    if baselines.memory_usage && current_metrics[:memory] do
      current_memory = current_metrics.memory.total_mb
      baseline_memory = baselines.memory_usage
      
      if current_memory > baseline_memory * 1.5 do
        anomalies = [%{
          type: :memory_spike,
          severity: :high,
          value: current_memory,
          baseline: baseline_memory,
          timestamp: current_metrics.timestamp
        } | anomalies]
      end
    end
    
    # Process count anomaly
    if baselines.process_count && current_metrics[:processes] do
      current_count = current_metrics.processes.count
      baseline_count = baselines.process_count
      
      if current_count > baseline_count * 1.3 do
        anomalies = [%{
          type: :process_explosion,
          severity: :medium,
          value: current_count,
          baseline: baseline_count,
          timestamp: current_metrics.timestamp
        } | anomalies]
      end
    end
    
    # Message queue anomaly
    if current_metrics[:processes] && current_metrics.processes.message_queues.max > 1000 do
      anomalies = [%{
        type: :message_queue_buildup,
        severity: :high,
        value: current_metrics.processes.message_queues.max,
        timestamp: current_metrics.timestamp
      } | anomalies]
    end
    
    anomalies
  end
  
  defp calculate_performance_score(metrics, trends, anomalies) do
    # Start with perfect score
    score = 1.0
    
    # Deduct for high memory usage
    if metrics[:memory] && metrics.memory.total_mb > 500 do
      score = score - 0.2
    end
    
    # Deduct for concerning trends
    if trends.memory.direction == :increasing && trends.memory.rate > 1.0 do
      score = score - 0.1
    end
    
    # Deduct for anomalies
    score = score - (length(anomalies) * 0.1)
    
    # Ensure score stays in valid range
    max(0.0, min(1.0, score))
    |> Float.round(2)
  end
  
  defp generate_trend_alerts(trends, anomalies, existing_alerts) do
    new_alerts = []
    
    # Memory trend alert
    if trends.memory.direction == :increasing && trends.memory.rate > 5.0 do
      new_alerts = [%{
        type: :memory_growth,
        message: "Memory usage increasing at #{trends.memory.rate} MB/measurement",
        severity: :warning,
        timestamp: DateTime.utc_now()
      } | new_alerts]
    end
    
    # Process trend alert
    if trends.processes.direction == :increasing && trends.processes.rate > 10 do
      new_alerts = [%{
        type: :process_growth,
        message: "Process count increasing rapidly",
        severity: :warning,
        timestamp: DateTime.utc_now()
      } | new_alerts]
    end
    
    # Anomaly alerts
    critical_anomalies = Enum.filter(anomalies, & &1.severity == :high)
    anomaly_alerts = Enum.map(critical_anomalies, fn anomaly ->
      %{
        type: anomaly.type,
        message: "Anomaly detected: #{anomaly.type}",
        severity: :high,
        timestamp: anomaly.timestamp
      }
    end)
    
    (new_alerts ++ anomaly_alerts ++ existing_alerts)
    |> Enum.uniq_by(& {&1.type, &1.message})
    |> Enum.take(20)
  end
  
  defp log_trend_changes(old_trends, new_trends) do
    [:cpu, :memory, :processes, :messages]
    |> Enum.each(fn metric ->
      old_dir = get_in(old_trends, [metric, :direction])
      new_dir = get_in(new_trends, [metric, :direction])
      
      if old_dir != new_dir && new_dir != :unknown do
        Logger.info("📈 Performance trend change: #{metric} now #{new_dir}")
      end
    end)
  end
  
  defp summarize_history(history) do
    if Enum.empty?(history) do
      %{samples: 0}
    else
      %{
        samples: length(history),
        duration_minutes: calculate_duration(history),
        memory_range: calculate_range(history, [:memory, :total_mb]),
        process_range: calculate_range(history, [:processes, :count])
      }
    end
  end
  
  defp calculate_duration(history) do
    if length(history) < 2 do
      0
    else
      first = List.last(history)
      last = List.first(history)
      
      if first[:monotonic_time] && last[:monotonic_time] do
        (last.monotonic_time - first.monotonic_time) / 60_000
        |> Float.round(1)
      else
        0
      end
    end
  end
  
  defp calculate_range(history, path) do
    values = history
    |> Enum.map(fn m -> get_in(m, path) end)
    |> Enum.reject(&is_nil/1)
    
    if Enum.empty?(values) do
      %{min: 0, max: 0}
    else
      %{
        min: Enum.min(values) |> Float.round(1),
        max: Enum.max(values) |> Float.round(1),
        avg: (Enum.sum(values) / length(values)) |> Float.round(1)
      }
    end
  end
  
  defp generate_recommendations(state) do
    recommendations = []
    
    # Memory recommendations
    if state.trends.memory.direction == :increasing do
      recommendations = ["Consider investigating memory leaks or increasing memory limits" | recommendations]
    end
    
    # Process recommendations
    if state.current_metrics[:processes] && state.current_metrics.processes.count > 10000 do
      recommendations = ["High process count detected - review process spawning patterns" | recommendations]
    end
    
    # Message queue recommendations
    if state.current_metrics[:processes] && state.current_metrics.processes.message_queues.max > 500 do
      recommendations = ["Message queues building up - check processing bottlenecks" | recommendations]
    end
    
    # Performance score recommendations
    if state.performance_score < 0.5 do
      recommendations = ["System performance degraded - immediate attention recommended" | recommendations]
    end
    
    Enum.take(recommendations, 5)
  end

  defp check_alerts(metrics, _state) do
    # Check for performance alerts based on metrics
    alerts = []
    
    # Check memory usage
    if metrics[:memory_usage] do
      total_memory = metrics.memory_usage[:total] || 0
      if total_memory > 1_000_000_000 do  # 1GB threshold
        alerts = [%{type: :memory_high, message: "Memory usage exceeds 1GB", value: total_memory} | alerts]
      end
    end
    
    # Check process count
    if metrics[:process_count] && metrics.process_count > 10000 do
      alerts = [%{type: :process_high, message: "Process count exceeds 10000", value: metrics.process_count} | alerts]
    end
    
    alerts
  end
end