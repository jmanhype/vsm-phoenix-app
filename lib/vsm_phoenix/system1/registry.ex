defmodule VsmPhoenix.System1.Registry do
  @moduledoc """
  Registry for System1 operational units.
  Provides unique key registration and lookup for S1 agents.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.Infrastructure.SafePubSub

  @registry_name :s1_registry

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register an S1 agent with a unique key.
  """
  def register(agent_id, pid, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:register, agent_id, pid, metadata})
  end

  @doc """
  Unregister an S1 agent.
  """
  def unregister(agent_id) do
    GenServer.call(__MODULE__, {:unregister, agent_id})
  end

  @doc """
  Lookup an S1 agent by ID.
  """
  def lookup(agent_id) do
    case Registry.lookup(@registry_name, agent_id) do
      [{pid, metadata}] -> {:ok, pid, metadata}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  List all registered S1 agents.
  """
  def list_agents do
    Registry.select(@registry_name, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.map(fn {agent_id, pid, metadata} ->
      %{
        agent_id: agent_id,
        pid: pid,
        metadata: metadata,
        alive: Process.alive?(pid)
      }
    end)
  end

  @doc """
  Count of registered agents.
  """
  def count do
    Registry.count(@registry_name)
  end
  
  @doc """
  whereis_name callback for :via tuple support.
  """
  def whereis_name({@registry_name, agent_id}) do
    case Registry.lookup(@registry_name, agent_id) do
      [{pid, _metadata}] -> pid
      [] -> :undefined
    end
  end
  
  @doc """
  register_name callback for :via tuple support.
  """
  def register_name({@registry_name, agent_id}, pid) do
    case Registry.register(@registry_name, agent_id, %{}) do
      {:ok, _} -> :yes
      {:error, _} -> :no
    end
  end
  
  @doc """
  unregister_name callback for :via tuple support.
  """
  def unregister_name({@registry_name, agent_id}) do
    Registry.unregister(@registry_name, agent_id)
  end
  
  @doc """
  send callback for :via tuple support.
  """
  def send({@registry_name, agent_id}, message) do
    case whereis_name({@registry_name, agent_id}) do
      :undefined -> :erlang.error(:badarg)
      pid -> Kernel.send(pid, message)
    end
  end

  @doc """
  Subscribe to registry events.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm.registry.events")
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Start the registry process
    {:ok, _} = Registry.start_link(keys: :unique, name: @registry_name)
    
    Logger.info("S1 Registry started")
    
    # Schedule periodic health check
    Process.send_after(self(), :health_check, 10_000)
    
    {:ok, %{started_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:register, agent_id, pid, metadata}, _from, state) do
    case Registry.register(@registry_name, agent_id, metadata) do
      {:ok, _} ->
        # Monitor the process
        Process.monitor(pid)
        
        # Broadcast registration event
        SafePubSub.broadcast!(
          "vsm.registry.events",
          {:agent_registered, agent_id, pid, metadata}
        )
        
        Logger.info("S1 Agent registered: #{agent_id}")
        {:reply, :ok, state}
        
      {:error, {:already_registered, _}} ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:unregister, agent_id}, _from, state) do
    case Registry.unregister(@registry_name, agent_id) do
      :ok ->
        # Broadcast unregistration event
        SafePubSub.broadcast!(
          "vsm.registry.events",
          {:agent_unregistered, agent_id}
        )
        
        Logger.info("S1 Agent unregistered: #{agent_id}")
        {:reply, :ok, state}
        
      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Find and unregister the agent when its process dies
    Registry.select(@registry_name, [{{:"$1", :"$2", :"$3"}, [{:==, :"$2", pid}], [:"$1"]}])
    |> Enum.each(fn agent_id ->
      Registry.unregister(@registry_name, agent_id)
      
      SafePubSub.broadcast!(
        "vsm.registry.events",
        {:agent_crashed, agent_id, reason}
      )
      
      Logger.warning("S1 Agent crashed: #{agent_id}, reason: #{inspect(reason)}")
    end)
    
    {:noreply, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Perform health check on all registered agents
    agents = list_agents()
    alive_count = Enum.count(agents, & &1.alive)
    total_count = length(agents)
    
    if alive_count < total_count do
      Logger.warning("S1 Registry health check: #{alive_count}/#{total_count} agents alive")
    end
    
    # Schedule next health check
    Process.send_after(self(), :health_check, 10_000)
    
    {:noreply, state}
  end
end