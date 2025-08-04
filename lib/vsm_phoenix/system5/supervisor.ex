defmodule VsmPhoenix.System5.Supervisor do
  @moduledoc """
  Supervisor for System 5 (Queen) components
  
  Manages:
  - Queen (main governance)
  - EmergentPolicy (emergent policy synthesis)
  - PolicySynthesizer is stateless and doesn't need supervision
  """
  
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Logger.info("🏛️ Starting System 5 Supervisor")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Queen - Main governance system
      {VsmPhoenix.System5.Queen, name: VsmPhoenix.System5.Queen},
      
      # EmergentPolicy - Evolutionary policy engine
      {VsmPhoenix.System5.EmergentPolicy, name: VsmPhoenix.System5.EmergentPolicy}
    ]
    
    # Restart strategy: one_for_one
    # If one child crashes, only that child is restarted
    opts = [strategy: :one_for_one, max_restarts: 3, max_seconds: 5]
    
    Supervisor.init(children, opts)
  end
  
  @doc """
  Check if all System 5 components are running
  """
  def health_check do
    children = Supervisor.which_children(__MODULE__)
    
    all_running = Enum.all?(children, fn {_id, pid, _type, _modules} ->
      is_pid(pid) and Process.alive?(pid)
    end)
    
    if all_running do
      {:ok, "All System 5 components operational"}
    else
      {:error, "Some System 5 components are not running"}
    end
  end
  
  @doc """
  Restart the EmergentPolicy engine
  """
  def restart_emergent_policy do
    Logger.info("Restarting EmergentPolicy engine")
    Supervisor.terminate_child(__MODULE__, VsmPhoenix.System5.EmergentPolicy)
    Supervisor.restart_child(__MODULE__, VsmPhoenix.System5.EmergentPolicy)
  end
  
  @doc """
  Get status of all System 5 components
  """
  def status do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {id, pid, type, modules} ->
      %{
        component: id,
        pid: pid,
        type: type,
        modules: modules,
        alive: is_pid(pid) and Process.alive?(pid)
      }
    end)
  end
end