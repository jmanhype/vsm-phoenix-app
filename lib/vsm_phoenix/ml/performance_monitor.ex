defmodule VsmPhoenix.ML.PerformanceMonitor do
  @moduledoc """
  ML Performance Monitoring System.
  Tracks model performance, resource usage, and training metrics.
  """

  use GenServer
  require Logger

  defstruct [
    metrics: %{},
    resource_usage: %{},
    model_performance: %{},
    alert_thresholds: %{},
    monitoring_enabled: true
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      monitoring_enabled: Keyword.get(opts, :monitoring_enabled, true),
      alert_thresholds: default_alert_thresholds()
    }

    # Start periodic monitoring
    if state.monitoring_enabled do
      schedule_monitoring()
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:record_training_metrics, model_name, metrics}, _from, state) do
    timestamp = DateTime.utc_now()
    
    training_record = %{
      timestamp: timestamp,
      metrics: metrics,
      model_name: model_name
    }
    
    new_metrics = 
      state.metrics
      |> Map.put_new(model_name, [])
      |> Map.update!(model_name, fn existing -> [training_record | existing] end)
    
    new_state = %{state | metrics: new_metrics}
    
    # Check for alerts
    check_training_alerts(model_name, metrics, state.alert_thresholds)
    
    {:reply, {:ok, "Metrics recorded"}, new_state}
  end

  @impl true
  def handle_call({:record_inference_metrics, model_name, metrics}, _from, state) do
    timestamp = DateTime.utc_now()
    
    inference_record = %{
      timestamp: timestamp,
      inference_time: metrics[:inference_time],
      throughput: metrics[:throughput],
      accuracy: metrics[:accuracy],
      model_name: model_name
    }
    
    new_performance = 
      state.model_performance
      |> Map.put_new(model_name, [])
      |> Map.update!(model_name, fn existing -> [inference_record | existing] end)
    
    new_state = %{state | model_performance: new_performance}
    
    {:reply, {:ok, "Inference metrics recorded"}, new_state}
  end

  @impl true
  def handle_call({:get_model_metrics, model_name}, _from, state) do
    training_metrics = Map.get(state.metrics, model_name, [])
    performance_metrics = Map.get(state.model_performance, model_name, [])
    
    result = %{
      training_metrics: training_metrics,
      performance_metrics: performance_metrics,
      summary: generate_metrics_summary(training_metrics, performance_metrics)
    }
    
    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call(:get_system_metrics, _from, state) do
    system_metrics = %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      gpu_usage: get_gpu_usage(),
      disk_usage: get_disk_usage(),
      timestamp: DateTime.utc_now()
    }
    
    new_resource_usage = [system_metrics | state.resource_usage]
    |> Enum.take(100)  # Keep last 100 measurements
    
    new_state = %{state | resource_usage: new_resource_usage}
    
    {:reply, {:ok, system_metrics}, new_state}
  end

  @impl true
  def handle_call({:set_alert_threshold, metric, threshold}, _from, state) do
    new_thresholds = Map.put(state.alert_thresholds, metric, threshold)
    new_state = %{state | alert_thresholds: new_thresholds}
    
    {:reply, {:ok, "Alert threshold set"}, new_state}
  end

  @impl true
  def handle_call(:get_performance_report, _from, state) do
    report = generate_performance_report(state)
    {:reply, {:ok, report}, state}
  end

  @impl true
  def handle_info(:monitor_system, state) do
    if state.monitoring_enabled do
      # Record system metrics
      GenServer.cast(self(), :record_system_metrics)
      
      # Schedule next monitoring
      schedule_monitoring()
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_cast(:record_system_metrics, state) do
    system_metrics = %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      gpu_usage: get_gpu_usage(),
      disk_usage: get_disk_usage(),
      network_io: get_network_io(),
      timestamp: DateTime.utc_now()
    }
    
    new_resource_usage = [system_metrics | state.resource_usage]
    |> Enum.take(1000)  # Keep last 1000 measurements
    
    # Check for resource alerts
    check_resource_alerts(system_metrics, state.alert_thresholds)
    
    {:noreply, %{state | resource_usage: new_resource_usage}}
  end

  # Public API
  def record_training_metrics(model_name, metrics) do
    GenServer.call(__MODULE__, {:record_training_metrics, model_name, metrics})
  end

  def record_inference_metrics(model_name, metrics) do
    GenServer.call(__MODULE__, {:record_inference_metrics, model_name, metrics})
  end

  def get_model_metrics(model_name) do
    GenServer.call(__MODULE__, {:get_model_metrics, model_name})
  end

  def get_system_metrics do
    GenServer.call(__MODULE__, :get_system_metrics)
  end

  def set_alert_threshold(metric, threshold) do
    GenServer.call(__MODULE__, {:set_alert_threshold, metric, threshold})
  end

  def get_performance_report do
    GenServer.call(__MODULE__, :get_performance_report)
  end

  # Private functions
  
  defp default_alert_thresholds do
    %{
      cpu_usage: 90.0,
      memory_usage: 85.0,
      gpu_usage: 95.0,
      disk_usage: 90.0,
      training_loss_increase: 0.1,
      inference_time_increase: 2.0
    }
  end

  defp schedule_monitoring do
    Process.send_after(self(), :monitor_system, 30_000)  # Every 30 seconds
  end

  defp check_training_alerts(model_name, metrics, thresholds) do
    # Check for training anomalies
    if Map.has_key?(metrics, :loss_increase) do
      threshold = Map.get(thresholds, :training_loss_increase, 0.1)
      if metrics.loss_increase > threshold do
        Logger.warn("Training alert: Loss increase detected for model #{model_name}: #{metrics.loss_increase}")
        send_alert(:training_degradation, model_name, metrics)
      end
    end
  end

  defp check_resource_alerts(system_metrics, thresholds) do
    Enum.each([:cpu_usage, :memory_usage, :gpu_usage, :disk_usage], fn metric ->
      value = Map.get(system_metrics, metric, 0)
      threshold = Map.get(thresholds, metric, 100)
      
      if value > threshold do
        Logger.warn("Resource alert: #{metric} is #{value}% (threshold: #{threshold}%)")
        send_alert(:resource_exhaustion, metric, %{value: value, threshold: threshold})
      end
    end)
  end

  defp send_alert(alert_type, context, data) do
    # In a production system, this would send alerts via email, Slack, etc.
    Logger.warn("ALERT [#{alert_type}]: #{context} - #{inspect(data)}")
  end

  defp generate_metrics_summary(training_metrics, performance_metrics) do
    %{
      training_summary: summarize_training_metrics(training_metrics),
      performance_summary: summarize_performance_metrics(performance_metrics),
      total_training_sessions: length(training_metrics),
      total_inferences: length(performance_metrics)
    }
  end

  defp summarize_training_metrics([]), do: %{}
  defp summarize_training_metrics(training_metrics) do
    latest = hd(training_metrics)
    
    %{
      latest_loss: get_nested_value(latest, [:metrics, :loss]),
      latest_accuracy: get_nested_value(latest, [:metrics, :accuracy]),
      latest_timestamp: latest.timestamp,
      avg_training_time: calculate_avg_training_time(training_metrics)
    }
  end

  defp summarize_performance_metrics([]), do: %{}
  defp summarize_performance_metrics(performance_metrics) do
    inference_times = Enum.map(performance_metrics, fn m -> m.inference_time || 0 end)
    throughputs = Enum.map(performance_metrics, fn m -> m.throughput || 0 end)
    
    %{
      avg_inference_time: safe_average(inference_times),
      max_inference_time: safe_max(inference_times),
      min_inference_time: safe_min(inference_times),
      avg_throughput: safe_average(throughputs),
      total_inferences: length(performance_metrics)
    }
  end

  defp calculate_avg_training_time(training_metrics) do
    times = 
      training_metrics
      |> Enum.map(fn m -> get_nested_value(m, [:metrics, :training_time]) end)
      |> Enum.filter(&(&1 != nil))
    
    safe_average(times)
  end

  defp generate_performance_report(state) do
    %{
      timestamp: DateTime.utc_now(),
      system_health: %{
        current_cpu: get_cpu_usage(),
        current_memory: get_memory_usage(),
        current_gpu: get_gpu_usage(),
        current_disk: get_disk_usage()
      },
      ml_models: %{
        total_models: map_size(state.metrics),
        active_models: count_active_models(state.model_performance),
        total_training_sessions: count_total_training_sessions(state.metrics),
        total_inferences: count_total_inferences(state.model_performance)
      },
      resource_trends: calculate_resource_trends(state.resource_usage),
      alerts: %{
        active_alerts: get_active_alerts(state),
        alert_history: get_recent_alerts()
      }
    }
  end

  defp count_active_models(model_performance) do
    # Models with recent inference activity (last hour)
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)
    
    model_performance
    |> Enum.count(fn {_model, metrics} ->
      Enum.any?(metrics, fn m -> 
        DateTime.compare(m.timestamp, one_hour_ago) == :gt
      end)
    end)
  end

  defp count_total_training_sessions(metrics) do
    metrics |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end

  defp count_total_inferences(model_performance) do
    model_performance |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end

  defp calculate_resource_trends(resource_usage) do
    case resource_usage do
      [] -> %{}
      [current | rest] ->
        if length(rest) > 0 do
          previous = hd(rest)
          %{
            cpu_trend: trend_direction(current.cpu_usage, previous.cpu_usage),
            memory_trend: trend_direction(current.memory_usage, previous.memory_usage),
            gpu_trend: trend_direction(current.gpu_usage, previous.gpu_usage)
          }
        else
          %{cpu_trend: :stable, memory_trend: :stable, gpu_trend: :stable}
        end
    end
  end

  defp trend_direction(current, previous) do
    diff = current - previous
    cond do
      diff > 5 -> :increasing
      diff < -5 -> :decreasing
      true -> :stable
    end
  end

  defp get_active_alerts(_state) do
    # In a real system, this would track active alerts
    []
  end

  defp get_recent_alerts do
    # In a real system, this would return recent alert history
    []
  end

  # System metrics collection functions
  
  defp get_cpu_usage do
    try do
      case :cpu_sup.avg1() do
        {_, _, _} = load -> elem(load, 0)
        load when is_integer(load) -> load
        _ -> 0.0
      end
    rescue
      _ -> 0.0
    end
  end

  defp get_memory_usage do
    try do
      {total, allocated, _} = :memsup.get_memory_data()
      if total > 0, do: (allocated / total) * 100, else: 0.0
    rescue
      _ -> 0.0
    end
  end

  defp get_gpu_usage do
    # Placeholder for GPU usage - would integrate with nvidia-ml-py or similar
    try do
      # This would use CUDA/OpenCL bindings to get actual GPU usage
      0.0
    rescue
      _ -> 0.0
    end
  end

  defp get_disk_usage do
    try do
      {total, used, _} = :disksup.get_disk_data() |> hd()
      if total > 0, do: (used / total) * 100, else: 0.0
    rescue
      _ -> 0.0
    end
  end

  defp get_network_io do
    try do
      # Simplified network I/O monitoring
      %{bytes_in: 0, bytes_out: 0, packets_in: 0, packets_out: 0}
    rescue
      _ -> %{bytes_in: 0, bytes_out: 0, packets_in: 0, packets_out: 0}
    end
  end

  # Utility functions
  
  defp get_nested_value(map, keys) do
    Enum.reduce(keys, map, fn key, acc ->
      case acc do
        nil -> nil
        acc when is_map(acc) -> Map.get(acc, key)
        _ -> nil
      end
    end)
  end

  defp safe_average([]), do: 0.0
  defp safe_average(list) do
    Enum.sum(list) / length(list)
  end

  defp safe_max([]), do: 0.0
  defp safe_max(list), do: Enum.max(list)

  defp safe_min([]), do: 0.0
  defp safe_min(list), do: Enum.min(list)
end