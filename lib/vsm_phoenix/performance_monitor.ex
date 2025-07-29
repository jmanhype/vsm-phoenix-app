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
    # Direct collection instead of self-call
    {_reply, new_state} = handle_call(:collect_metrics, nil, state)
    
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
        scheduler_utilization: :scheduler.utilization(1) |> List.first() |> elem(1)
      }
    }
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
end