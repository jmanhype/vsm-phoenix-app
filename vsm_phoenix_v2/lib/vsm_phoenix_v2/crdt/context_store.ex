defmodule VsmPhoenixV2.CRDT.ContextStore do
  @moduledoc """
  CRDT-based distributed context store for VSM Phoenix V2.
  
  Implements CRDT state management for System 5 (Queen) coordination.
  NO FALLBACKS - Fails explicitly if CRDT operations fail.
  """

  use GenServer
  require Logger
  alias DeltaCrdt

  defstruct [:crdt, :node_id, :neighbors]

  @doc """
  Starts the CRDT context store.
  
  ## Options
    * `:node_id` - Unique identifier for this node (required)
    * `:neighbors` - List of neighbor node PIDs for synchronization
  """
  def start_link(opts \\ []) do
    node_id = opts[:node_id] || raise "node_id is required for CRDT context store"
    GenServer.start_link(__MODULE__, opts, name: via_tuple(node_id))
  end

  def init(opts) do
    node_id = Keyword.fetch!(opts, :node_id)
    neighbors = Keyword.get(opts, :neighbors, [])
    
    # Initialize CRDT with fail-fast error handling
    case DeltaCrdt.start_link(DeltaCrdt.AWLWWMap, []) do
      {:ok, crdt_pid} ->
        state = %__MODULE__{
          crdt: crdt_pid,
          node_id: node_id,
          neighbors: neighbors
        }
        
        Logger.info("CRDT ContextStore initialized for node #{node_id}")
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to initialize CRDT: #{inspect(reason)}")
        {:stop, {:crdt_init_failed, reason}}
    end
  end

  @doc """
  Stores a context value with CRDT replication.
  FAILS EXPLICITLY if CRDT operation fails.
  """
  def put_context(node_id, key, value) do
    GenServer.call(via_tuple(node_id), {:put_context, key, value})
  end

  @doc """
  Retrieves a context value from CRDT.
  Returns {:error, :key_not_found} if key doesn't exist - NO DEFAULT VALUES.
  """
  def get_context(node_id, key) do
    GenServer.call(via_tuple(node_id), {:get_context, key})
  end

  @doc """
  Lists all context keys in the CRDT.
  """
  def list_contexts(node_id) do
    GenServer.call(via_tuple(node_id), :list_contexts)
  end

  @doc """
  Synchronizes with a neighboring CRDT node.
  FAILS EXPLICITLY if synchronization fails.
  """
  def sync_with_neighbor(node_id, neighbor_pid) do
    GenServer.call(via_tuple(node_id), {:sync_neighbor, neighbor_pid})
  end

  @doc """
  Gets the current CRDT state for debugging.
  """
  def get_crdt_state(node_id) do
    GenServer.call(via_tuple(node_id), :get_crdt_state)
  end

  # GenServer Callbacks

  def handle_call({:put_context, key, value}, _from, state) do
    case DeltaCrdt.put(state.crdt, key, value) do
      :ok ->
        Logger.debug("Context stored: #{key} -> #{inspect(value)}")
        {:reply, :ok, state}
        
      {:error, reason} ->
        Logger.error("CRDT put failed for key #{key}: #{inspect(reason)}")
        {:reply, {:error, {:crdt_put_failed, reason}}, state}
    end
  end

  def handle_call({:get_context, key}, _from, state) do
    case DeltaCrdt.read(state.crdt, key) do
      {:ok, value} ->
        {:reply, {:ok, value}, state}
        
      :error ->
        {:reply, {:error, :key_not_found}, state}
    end
  end

  def handle_call(:list_contexts, _from, state) do
    case DeltaCrdt.to_map(state.crdt) do
      {:ok, crdt_map} ->
        keys = Map.keys(crdt_map)
        {:reply, {:ok, keys}, state}
        
      {:error, reason} ->
        Logger.error("Failed to list CRDT contexts: #{inspect(reason)}")
        {:reply, {:error, {:crdt_read_failed, reason}}, state}
    end
  end

  def handle_call({:sync_neighbor, neighbor_pid}, _from, state) do
    case DeltaCrdt.sync(state.crdt, neighbor_pid) do
      :ok ->
        Logger.info("Successfully synchronized with neighbor #{inspect(neighbor_pid)}")
        {:reply, :ok, state}
        
      {:error, reason} ->
        Logger.error("CRDT synchronization failed with #{inspect(neighbor_pid)}: #{inspect(reason)}")
        {:reply, {:error, {:sync_failed, reason}}, state}
    end
  end

  def handle_call(:get_crdt_state, _from, state) do
    case DeltaCrdt.to_map(state.crdt) do
      {:ok, crdt_map} ->
        debug_info = %{
          node_id: state.node_id,
          crdt_pid: state.crdt,
          neighbors: state.neighbors,
          context_count: map_size(crdt_map),
          contexts: crdt_map
        }
        {:reply, {:ok, debug_info}, state}
        
      {:error, reason} ->
        {:reply, {:error, {:crdt_state_read_failed, reason}}, state}
    end
  end

  def handle_info({:crdt_update, _delta}, state) do
    Logger.debug("CRDT delta update received for node #{state.node_id}")
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("CRDT ContextStore terminating for node #{state.node_id}: #{inspect(reason)}")
    :ok
  end

  # Private Functions

  defp via_tuple(node_id) do
    {:via, Registry, {VsmPhoenixV2.CRDTRegistry, {:context_store, node_id}}}
  end
end