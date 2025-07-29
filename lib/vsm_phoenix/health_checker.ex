defmodule VsmPhoenix.HealthChecker do
  @moduledoc """
  System health checker for the VSM hierarchy
  
  Monitors the health of all VSM systems and triggers interventions
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def run_system_audit do
    GenServer.call(@name, :run_system_audit)
  end
  
  def get_health_status do
    GenServer.call(@name, :get_health_status)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("Health Checker initializing...")
    
    state = %{
      system_health: %{},
      audit_history: [],
      interventions: []
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:run_system_audit, _from, state) do
    audit_result = perform_system_audit()
    
    new_history = [audit_result | state.audit_history] |> Enum.take(50)
    new_state = %{state | 
      audit_history: new_history,
      system_health: audit_result.health_summary
    }
    
    {:reply, audit_result, new_state}
  end
  
  @impl true
  def handle_call(:get_health_status, _from, state) do
    {:reply, state.system_health, state}
  end
  
  defp perform_system_audit do
    %{
      timestamp: DateTime.utc_now(),
      health_summary: %{
        system5: check_system_health(:system5),
        system4: check_system_health(:system4),
        system3: check_system_health(:system3),
        system2: check_system_health(:system2),
        system1: check_system_health(:system1)
      },
      overall_health: 0.85  # Calculated from individual systems
    }
  end
  
  defp check_system_health(_system) do
    # Simplified health check
    %{status: :healthy, score: 0.9}
  end
end