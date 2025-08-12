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
    # DeltaCrdt.put/3 returns the CRDT PID for chaining
    # It doesn't return an error on success, just the PID
    crdt_pid = DeltaCrdt.put(state.crdt, key, value)
    
    if is_pid(crdt_pid) do
      Logger.debug("Context stored: #{inspect(key)} -> #{inspect(value)}")
      {:reply, :ok, state}
    else
      # This should never happen with DeltaCrdt.put, but handle it just in case
      Logger.error("Unexpected CRDT put result: #{inspect(crdt_pid)}")
      {:reply, {:error, {:unexpected_crdt_result, crdt_pid}}, state}
    end
  end

  def handle_call({:get_context, key}, _from, state) do
    # DeltaCrdt.get returns the value or nil if not found
    case DeltaCrdt.get(state.crdt, key) do
      nil ->
        {:reply, {:error, :key_not_found}, state}
        
      value ->
        {:reply, {:ok, value}, state}
    end
  end

  def handle_call(:list_contexts, _from, state) do
    # DeltaCrdt.to_map returns the map directly
    crdt_map = DeltaCrdt.to_map(state.crdt)
    keys = Map.keys(crdt_map)
    {:reply, {:ok, keys}, state}
  end

  def handle_call({:sync_neighbor, neighbor_pid}, _from, state) do
    # Use set_neighbours to establish synchronization
    # DeltaCrdt.set_neighbours expects a list of PIDs
    current_neighbors = state.neighbors || []
    new_neighbors = if neighbor_pid in current_neighbors do
      current_neighbors
    else
      [neighbor_pid | current_neighbors]
    end
    
    DeltaCrdt.set_neighbours(state.crdt, new_neighbors)
    Logger.info("Successfully set neighbor #{inspect(neighbor_pid)} for synchronization")
    {:reply, :ok, %{state | neighbors: new_neighbors}}
  end

  def handle_call(:get_crdt_state, _from, state) do
    # DeltaCrdt.to_map returns the map directly
    crdt_map = DeltaCrdt.to_map(state.crdt)
    debug_info = %{
      node_id: state.node_id,
      crdt_pid: state.crdt,
      neighbors: state.neighbors,
      context_count: map_size(crdt_map),
      contexts: crdt_map
    }
    {:reply, {:ok, debug_info}, state}
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