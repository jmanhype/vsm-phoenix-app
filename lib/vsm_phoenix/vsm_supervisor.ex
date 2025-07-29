defmodule VsmPhoenix.VsmSupervisor do
  @moduledoc """
  VSM-specific supervisor for additional processes and workers
  
  Manages VSM-specific processes that support the main hierarchy:
  - Performance monitoring
  - System health checks
  - Telemetry collection
  - External integrations
  """
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      # VSM Performance Monitor
      {VsmPhoenix.PerformanceMonitor, []},
      
      # VSM Health Checker
      {VsmPhoenix.HealthChecker, []},
      
      # VSM Telemetry Collector
      {VsmPhoenix.TelemetryCollector, []},
      
      # Tidewave Integration (if available)
      {VsmPhoenix.TidewaveIntegration, []},
      
      # VSM Configuration Manager
      {VsmPhoenix.ConfigManager, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end