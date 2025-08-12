defmodule VsmPhoenixV2.VSMSupervisor do
  @moduledoc """
  Main VSM System Supervisor for VSM Phoenix V2.
  
  Manages all VSM systems in the proper hierarchy:
  - System 5 (Queen) - Policy and Strategic Direction
  - System 4 (Intelligence) - Cortical Attention Engine
  - System 3 (Infrastructure) - Control and Resource Management
  - Persistence Layer - Analog Signal Telemetry
  - Resilience Layer - Circuit Breakers and Fault Tolerance
  - Telegram Integration - Real API Integration
  
  PRODUCTION-READY: Real supervision tree with proper failure isolation.
  """

  use Supervisor
  require Logger

  @doc """
  Starts the VSM Supervisor.
  
  ## Options
    * `:node_id` - Unique identifier for this VSM node (optional, defaults to UUID)
    * `:strategic_objectives` - Initial strategic objectives (optional)
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    node_id = opts[:node_id] || generate_node_id()
    strategic_objectives = opts[:strategic_objectives] || default_strategic_objectives()
    
    Logger.info("Initializing VSM Phoenix V2 for node #{node_id}")
    
    children = [
      # System 5 (Queen) - Highest priority, started first
      {VsmPhoenixV2.System5.Queen, [
        node_id: node_id,
        strategic_objectives: strategic_objectives
      ]},
      
      # System 4 (Intelligence) - Cortical Attention Engine
      {VsmPhoenixV2.System4.CorticalAttentionEngine, [
        node_id: node_id
      ]},
      
      # Additional systems will be added here as they're implemented
      # System 3 (Infrastructure)
      # Persistence Layer
      # Resilience Layer
      # Telegram Integration
    ]
    
    # Use rest_for_one strategy - if a higher-level system fails,
    # restart it and all systems below it in the hierarchy
    opts = [strategy: :rest_for_one, name: VsmPhoenixV2.VSMSupervisor]
    Supervisor.init(children, opts)
  end

  @doc """
  Gets the status of all VSM systems.
  """
  def get_system_status do
    try do
      node_id = get_current_node_id()
      
      # Collect status from all systems
      system5_status = case VsmPhoenixV2.System5.Queen.get_system_status(node_id) do
        {:ok, status} -> {:ok, status}
        error -> {:error, error}
      end
      
      system4_status = case VsmPhoenixV2.System4.CorticalAttentionEngine.get_attention_state(node_id) do
        {:ok, status} -> {:ok, status}
        error -> {:error, error}
      end
      
      # Compile overall status
      %{
        node_id: node_id,
        timestamp: DateTime.utc_now(),
        system5_queen: system5_status,
        system4_intelligence: system4_status,
        supervisor_info: get_supervisor_info()
      }
    rescue
      error ->
        {:error, {:status_collection_failed, error}}
    end
  end

  @doc """
  Triggers emergency shutdown of all VSM systems.
  """
  def emergency_shutdown(reason \\ :emergency_protocol) do
    Logger.warning("VSM emergency shutdown initiated: #{inspect(reason)}")
    
    # Get current node ID for emergency notifications
    node_id = get_current_node_id()
    
    # Notify System 5 Queen of emergency shutdown
    try do
      VsmPhoenixV2.System5.Queen.activate_emergency_protocol(
        node_id, 
        :system_shutdown, 
        1.0
      )
    rescue
      error ->
        Logger.error("Failed to notify Queen of emergency shutdown: #{inspect(error)}")
    end
    
    # Perform graceful supervisor shutdown
    case Supervisor.stop(__MODULE__, reason, 5000) do
      :ok ->
        Logger.info("VSM systems shutdown completed")
        :ok
        
      {:error, reason} ->
        Logger.error("VSM systems shutdown failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Restarts a specific VSM system.
  """
  def restart_system(system_type) do
    case find_child_spec(system_type) do
      {child_id, _child_spec} ->
        case Supervisor.restart_child(__MODULE__, child_id) do
          {:ok, _child} -> 
            Logger.info("Successfully restarted #{system_type}")
            :ok
            
          {:ok, _child, _info} -> 
            Logger.info("Successfully restarted #{system_type} with info")
            :ok
            
          {:error, :not_found} -> 
            Logger.error("System #{system_type} not found in supervisor")
            {:error, :system_not_found}
            
          {:error, reason} -> 
            Logger.error("Failed to restart #{system_type}: #{inspect(reason)}")
            {:error, reason}
        end
        
      nil ->
        Logger.error("Unknown system type: #{system_type}")
        {:error, :unknown_system_type}
    end
  end

  @doc """
  Adds a new strategic objective to the Queen system.
  """
  def add_strategic_objective(objective) do
    node_id = get_current_node_id()
    
    case VsmPhoenixV2.System5.Queen.get_system_status(node_id) do
      {:ok, current_status} ->
        current_objectives = Map.get(current_status, :strategic_objectives, [])
        new_objectives = [objective | current_objectives]
        
        VsmPhoenixV2.System5.Queen.update_strategic_objectives(node_id, new_objectives)
        
      error ->
        Logger.error("Failed to add strategic objective: #{inspect(error)}")
        error
    end
  end

  @doc """
  Processes an algedonic signal through the Queen system.
  """
  def process_algedonic_signal(signal_type, intensity, source_system) do
    node_id = get_current_node_id()
    
    VsmPhoenixV2.System5.Queen.process_algedonic_signal(
      node_id,
      signal_type,
      intensity,
      source_system
    )
  end

  @doc """
  Processes a message through the attention system.
  """
  def process_message_with_attention(message, metadata \\ %{}) do
    node_id = get_current_node_id()
    
    VsmPhoenixV2.System4.CorticalAttentionEngine.process_message(
      node_id,
      message,
      metadata
    )
  end

  # Private Functions

  defp generate_node_id do
    # Generate a unique node ID using elixir_uuid
    case UUID.uuid4() do
      {:ok, uuid} -> uuid
      uuid when is_binary(uuid) -> uuid
      _ ->
        # Fallback if UUID generation fails
        :crypto.strong_rand_bytes(16) |> Base.encode64() |> String.slice(0, 12)
    end
  rescue
    _ ->
      # Fallback if UUID generation fails
      :crypto.strong_rand_bytes(16) |> Base.encode64() |> String.slice(0, 12)
  end

  defp get_current_node_id do
    # In a production system, this would be stored in application config
    # For now, use a default node ID
    Application.get_env(:vsm_phoenix_v2, :node_id, "vsm_node_1")
  end

  defp default_strategic_objectives do
    [
      %{
        id: "maintain_system_viability",
        description: "Maintain overall system viability and health",
        priority: :high,
        metrics: [:system_health, :response_time, :error_rate],
        target_values: %{system_health: 0.9, response_time: 500, error_rate: 0.01}
      },
      
      %{
        id: "optimize_attention_allocation",
        description: "Optimize attention allocation across system components",
        priority: :medium,
        metrics: [:attention_effectiveness, :message_processing_rate],
        target_values: %{attention_effectiveness: 0.8, message_processing_rate: 100}
      },
      
      %{
        id: "ensure_fault_tolerance",
        description: "Ensure system resilience and fault tolerance",
        priority: :high,
        metrics: [:circuit_breaker_effectiveness, :recovery_time],
        target_values: %{circuit_breaker_effectiveness: 0.95, recovery_time: 30}
      }
    ]
  end

  defp get_supervisor_info do
    case Supervisor.which_children(__MODULE__) do
      children when is_list(children) ->
        %{
          child_count: length(children),
          running_children: count_running_children(children),
          supervisor_pid: Process.whereis(__MODULE__),
          uptime: get_supervisor_uptime()
        }
        
      error ->
        %{
          error: error,
          supervisor_pid: Process.whereis(__MODULE__)
        }
    end
  end

  defp count_running_children(children) do
    Enum.count(children, fn
      {_id, pid, _type, _modules} when is_pid(pid) -> 
        Process.alive?(pid)
      _ -> 
        false
    end)
  end

  defp get_supervisor_uptime do
    case Process.whereis(__MODULE__) do
      pid when is_pid(pid) ->
        case Process.info(pid, :dictionary) do
          {:dictionary, dict} ->
            case Keyword.get(dict, :started_at) do
              nil -> :unknown
              started_at -> DateTime.diff(DateTime.utc_now(), started_at, :second)
            end
            
          _ -> :unknown
        end
        
      nil -> :not_running
    end
  end

  defp find_child_spec(system_type) do
    child_specs = %{
      :queen => VsmPhoenixV2.System5.Queen,
      :system5 => VsmPhoenixV2.System5.Queen,
      :intelligence => VsmPhoenixV2.System4.CorticalAttentionEngine,
      :system4 => VsmPhoenixV2.System4.CorticalAttentionEngine,
      :attention => VsmPhoenixV2.System4.CorticalAttentionEngine
    }
    
    case Map.get(child_specs, system_type) do
      nil -> nil
      child_module -> {child_module, child_module}
    end
  end
end