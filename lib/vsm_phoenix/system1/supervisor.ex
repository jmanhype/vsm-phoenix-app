defmodule VsmPhoenix.System1.Supervisor do
  @moduledoc """
  DynamicSupervisor for System1 agents.
  Manages spawning and supervision of S1 operational agents.
  """

  use DynamicSupervisor
  require Logger

  alias VsmPhoenix.System1.Registry

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("🚀 S1 DynamicSupervisor starting...")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Spawn a new S1 agent dynamically.
  
  ## Options
  - :type - Agent type (:sensor, :worker, :api)
  - :id - Unique agent ID (auto-generated if not provided)
  - :config - Agent-specific configuration
  """
  def spawn_agent(agent_type, opts \\ []) do
    agent_id = Keyword.get(opts, :id, generate_agent_id(agent_type))
    config = Keyword.get(opts, :config, %{})
    
    agent_module = case agent_type do
      :sensor -> VsmPhoenix.System1.Agents.SensorAgent
      :worker -> VsmPhoenix.System1.Agents.WorkerAgent
      :api -> VsmPhoenix.System1.Agents.ApiAgent
      :llm_worker -> VsmPhoenix.System1.Agents.LLMWorkerAgent
      _ -> raise ArgumentError, "Unknown agent type: #{agent_type}"
    end
    
    Logger.info("🔧 Creating child_spec with config: #{inspect(config)}")
    
    child_spec = {
      agent_module,
      [
        id: agent_id,
        config: config,
        registry: :skip_registration
      ]
    }
    
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        # Register the agent after successful spawn
        metadata = %{
          type: agent_type,
          config: config,
          started_at: DateTime.utc_now()
        }
        
        case Registry.register(agent_id, pid, metadata) do
          :ok ->
            Logger.info("✅ Spawned #{agent_type} agent: #{agent_id} (PID: #{inspect(pid)})")
            {:ok, %{id: agent_id, pid: pid, type: agent_type}}
          {:error, reason} ->
            # Kill the process if registration fails
            Logger.error("❌ Failed to register agent #{agent_id}: #{inspect(reason)}")
            DynamicSupervisor.terminate_child(__MODULE__, pid)
            {:error, {:registration_failed, reason}}
        end
        
      {:error, reason} = error ->
        Logger.error("❌ Failed to spawn agent: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Terminate an S1 agent.
  """
  def terminate_agent(agent_pid) when is_pid(agent_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, agent_pid)
  end

  def terminate_agent(agent_id) when is_binary(agent_id) do
    case Registry.lookup(agent_id) do
      {:ok, pid, _metadata} ->
        terminate_agent(pid)
      {:error, :not_found} ->
        {:error, :agent_not_found}
    end
  end

  @doc """
  List all supervised agents.
  """
  def list_agents do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.list_agents() |> Enum.find(fn agent -> agent.pid == pid end) do
        nil -> nil
        agent -> agent
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Count of active agents.
  """
  def count_agents do
    DynamicSupervisor.count_children(__MODULE__).active
  end

  @doc """
  Spawn multiple agents in parallel.
  """
  def spawn_agents(agent_specs) when is_list(agent_specs) do
    tasks = Enum.map(agent_specs, fn {type, opts} ->
      Task.async(fn -> spawn_agent(type, opts) end)
    end)
    
    Enum.map(tasks, &Task.await/1)
  end

  @doc """
  Restart strategy for agents.
  """
  def restart_agent(agent_id) do
    case Registry.lookup(agent_id) do
      {:ok, pid, metadata} ->
        agent_type = Map.get(metadata, :type, :worker)
        config = Map.get(metadata, :config, %{})
        
        # Terminate old agent
        terminate_agent(pid)
        
        # Spawn new one with same config
        spawn_agent(agent_type, id: agent_id, config: config)
        
      {:error, :not_found} ->
        {:error, :agent_not_found}
    end
  end

  # Private Functions

  defp generate_agent_id(agent_type) do
    timestamp = :erlang.system_time(:millisecond)
    random = :rand.uniform(9999)
    "s1_#{agent_type}_#{timestamp}_#{random}"
  end
end