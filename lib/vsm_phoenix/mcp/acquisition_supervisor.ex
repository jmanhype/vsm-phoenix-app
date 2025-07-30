defmodule VsmPhoenix.MCP.AcquisitionSupervisor do
  @moduledoc """
  Supervisor for the autonomous acquisition system.
  Ensures the acquisition loop runs continuously and handles failures gracefully.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Autonomous Acquisition Engine
      {VsmPhoenix.MCP.AutonomousAcquisition, []},
      
      # Capability Analyzer (for identifying gaps)
      {VsmPhoenix.MCP.CapabilityAnalyzer, []},
      
      # MCP Registry is started in the main application supervision tree
      # Don't start it here to avoid duplicate startup
      
      # Integration Engine (for safe integration)
      {VsmPhoenix.MCP.IntegrationEngine, []},
      
      # Acquisition Monitor (telemetry and health checks)
      {VsmPhoenix.MCP.AcquisitionMonitor, []}
    ]

    # Restart strategy: if one component fails, restart all
    # This ensures consistency in the acquisition system
    opts = [strategy: :one_for_all, max_restarts: 5, max_seconds: 60]
    
    Supervisor.init(children, opts)
  end

  @doc """
  Start the autonomous acquisition loop after system initialization.
  """
  def start_acquisition_loop do
    # Wait for all children to be ready
    Process.sleep(1000)
    
    # Start the autonomous loop
    VsmPhoenix.MCP.AutonomousAcquisition.start_acquisition_loop()
    
    Logger.info("Autonomous acquisition system activated")
  end

  @doc """
  Get the current status of the acquisition system.
  """
  def status do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {id, pid, type, _modules} ->
      %{
        component: id,
        pid: pid,
        type: type,
        alive?: Process.alive?(pid)
      }
    end)
  end

  @doc """
  Pause the acquisition loop (for maintenance, debugging, etc.)
  """
  def pause_acquisition do
    GenServer.call(VsmPhoenix.MCP.AutonomousAcquisition, :pause_loop)
  end

  @doc """
  Resume the acquisition loop.
  """
  def resume_acquisition do
    GenServer.call(VsmPhoenix.MCP.AutonomousAcquisition, :resume_loop)
  end

  @doc """
  Force an immediate variety gap scan.
  """
  def force_scan do
    send(VsmPhoenix.MCP.AutonomousAcquisition, :scan_variety_gaps)
  end

  @doc """
  Get acquisition statistics.
  """
  def get_stats do
    %{
      acquisition: GenServer.call(VsmPhoenix.MCP.AutonomousAcquisition, :get_stats),
      registry: GenServer.call(VsmPhoenix.MCP.MCPRegistry, :get_stats),
      integration: GenServer.call(VsmPhoenix.MCP.IntegrationEngine, :get_stats),
      monitor: GenServer.call(VsmPhoenix.MCP.AcquisitionMonitor, :get_metrics)
    }
  end
end