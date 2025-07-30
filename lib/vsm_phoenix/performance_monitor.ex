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
      alerts: []
    }
    
    # Schedule periodic collection
    :timer.send_interval(30_000, self(), :collect_metrics)
    
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
    %{
      timestamp: DateTime.utc_now(),
      memory_usage: :erlang.memory(),
      process_count: length(Process.list()),
      system_info: %{
        uptime: :erlang.statistics(:wall_clock) |> elem(0),
        scheduler_utilization: get_scheduler_utilization()
      }
    }
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
  
  defp generate_performance_report(state) do
    %{
      current: state.current_metrics,
      trends: analyze_trends(state.metrics_history),
      alerts: state.alerts
    }
  end
  
  defp analyze_trends(history) do
    if length(history) < 2 do
      %{trend: :insufficient_data}
    else
      %{trend: :stable}  # Simplified
    end
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