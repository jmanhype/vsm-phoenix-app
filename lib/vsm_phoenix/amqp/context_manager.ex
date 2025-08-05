defmodule VsmPhoenix.AMQP.ContextManager do
  @moduledoc """
  Manages semantic context across distributed VSM systems using CRDTs.
  
  Features:
  - CRDT-based context merging for eventual consistency
  - Context persistence with configurable storage backends
  - Distributed state synchronization
  - Conflict resolution using semantic rules
  """
  
  use GenServer
  require Logger
  
  alias Phoenix.PubSub
  
  @sync_interval 5_000  # 5 seconds
  @context_ttl 3_600_000  # 1 hour in milliseconds
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    Logger.info("🧠 Context Manager: Initializing with CRDT support")
    
    # Initialize CRDT structures
    state = %{
      # G-Counter CRDT for tracking context versions
      version_counter: %{},
      
      # OR-Set CRDT for context data
      contexts: %{},
      
      # LWW-Register for latest context values
      lww_registers: %{},
      
      # Vector clock for causality
      vector_clock: %{},
      
      # Node identity
      node_id: node_id(opts),
      
      # Persistence backend
      persistence: init_persistence(opts),
      
      # PubSub for distributed sync
      pubsub: VsmPhoenix.PubSub
    }
    
    # Schedule periodic sync
    schedule_sync()
    
    # Subscribe to context updates
    Phoenix.PubSub.subscribe(state.pubsub, "context:updates")
    
    # Load persisted contexts
    state = load_persisted_contexts(state)
    
    {:ok, state}
  end
  
  # Public API
  
  def merge_context(context_id, new_context, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:merge_context, context_id, new_context, metadata})
  end
  
  def get_context(context_id) do
    GenServer.call(__MODULE__, {:get_context, context_id})
  end
  
  def list_contexts(filter \\ %{}) do
    GenServer.call(__MODULE__, {:list_contexts, filter})
  end
  
  def sync_with_node(node) do
    GenServer.cast(__MODULE__, {:sync_with_node, node})
  end
  
  # Callbacks
  
  def handle_call({:merge_context, context_id, new_context, metadata}, _from, state) do
    Logger.debug("Context merge request for #{context_id}")
    
    # Update vector clock
    state = update_vector_clock(state)
    
    # Merge using CRDT operations
    {merged_context, state} = perform_crdt_merge(state, context_id, new_context, metadata)
    
    # Persist the merged context
    persist_context(state, context_id, merged_context)
    
    # Broadcast update to other nodes
    broadcast_context_update(state, context_id, merged_context)
    
    {:reply, {:ok, merged_context}, state}
  end
  
  def handle_call({:get_context, context_id}, _from, state) do
    context = resolve_context(state, context_id)
    {:reply, {:ok, context}, state}
  end
  
  def handle_call({:list_contexts, filter}, _from, state) do
    contexts = list_filtered_contexts(state, filter)
    {:reply, {:ok, contexts}, state}
  end
  
  def handle_cast({:sync_with_node, node}, state) do
    Logger.info("Syncing context with node: #{node}")
    
    # Exchange vector clocks and contexts
    send({__MODULE__, node}, {:sync_request, state.node_id, state.vector_clock, state.contexts})
    
    {:noreply, state}
  end
  
  def handle_info({:sync_request, remote_node, remote_clock, remote_contexts}, state) do
    Logger.debug("Received sync request from #{remote_node}")
    
    # Merge remote state
    state = merge_remote_state(state, remote_node, remote_clock, remote_contexts)
    
    # Send our state back
    send({__MODULE__, remote_node}, {:sync_response, state.node_id, state.vector_clock, state.contexts})
    
    {:noreply, state}
  end
  
  def handle_info({:sync_response, remote_node, remote_clock, remote_contexts}, state) do
    # Merge remote state from sync response
    state = merge_remote_state(state, remote_node, remote_clock, remote_contexts)
    {:noreply, state}
  end
  
  def handle_info({:context_update, context_id, context, metadata}, state) do
    # Handle context updates from other nodes
    {_merged, state} = perform_crdt_merge(state, context_id, context, metadata)
    {:noreply, state}
  end
  
  def handle_info(:sync_tick, state) do
    # Periodic sync with other nodes
    nodes = Node.list()
    Enum.each(nodes, &sync_with_node/1)
    
    # Clean up old contexts
    state = cleanup_old_contexts(state)
    
    # Schedule next sync
    schedule_sync()
    
    {:noreply, state}
  end
  
  # CRDT Operations
  
  defp perform_crdt_merge(state, context_id, new_context, metadata) do
    # G-Counter increment for version
    version = increment_version(state.version_counter, state.node_id, context_id)
    
    # OR-Set add operation
    or_set = Map.get(state.contexts, context_id, %{additions: MapSet.new(), removals: MapSet.new()})
    
    # Convert context to set elements with timestamps
    context_elements = context_to_elements(new_context, state.node_id)
    updated_or_set = or_set_add(or_set, context_elements)
    
    # LWW-Register update
    lww_register = Map.get(state.lww_registers, context_id, %{})
    updated_lww = lww_register_update(lww_register, new_context, state.node_id)
    
    # Update state
    state = state
      |> put_in([:version_counter, context_id], version)
      |> put_in([:contexts, context_id], updated_or_set)
      |> put_in([:lww_registers, context_id], updated_lww)
    
    # Resolve final context
    merged_context = resolve_context(state, context_id)
    
    {merged_context, state}
  end
  
  defp increment_version(counter, node_id, context_id) do
    current = Map.get(counter, {context_id, node_id}, 0)
    Map.put(counter, {context_id, node_id}, current + 1)
  end
  
  defp or_set_add(or_set, elements) do
    %{or_set | additions: MapSet.union(or_set.additions, elements)}
  end
  
  defp or_set_remove(or_set, elements) do
    %{or_set | removals: MapSet.union(or_set.removals, elements)}
  end
  
  defp or_set_elements(or_set) do
    MapSet.difference(or_set.additions, or_set.removals)
  end
  
  defp lww_register_update(register, value, node_id) do
    timestamp = System.monotonic_time()
    
    if Map.get(register, :timestamp, 0) < timestamp do
      %{
        value: value,
        timestamp: timestamp,
        node_id: node_id
      }
    else
      register
    end
  end
  
  defp context_to_elements(context, node_id) do
    timestamp = System.monotonic_time()
    
    context
    |> Enum.map(fn {k, v} ->
      %{
        key: k,
        value: v,
        timestamp: timestamp,
        node_id: node_id,
        id: generate_element_id()
      }
    end)
    |> MapSet.new()
  end
  
  defp resolve_context(state, context_id) do
    # Combine OR-Set and LWW-Register data
    or_set = Map.get(state.contexts, context_id, %{additions: MapSet.new(), removals: MapSet.new()})
    lww_register = Map.get(state.lww_registers, context_id, %{})
    
    # Get current elements from OR-Set
    elements = or_set_elements(or_set)
    
    # Build context from elements
    base_context = elements
      |> Enum.reduce(%{}, fn elem, acc ->
        Map.put(acc, elem.key, elem.value)
      end)
    
    # Overlay LWW-Register value if newer
    if lww_register[:value] do
      Map.merge(base_context, lww_register.value)
    else
      base_context
    end
  end
  
  # Vector Clock Operations
  
  defp update_vector_clock(state) do
    clock = Map.update(state.vector_clock, state.node_id, 1, &(&1 + 1))
    %{state | vector_clock: clock}
  end
  
  defp merge_vector_clocks(clock1, clock2) do
    Map.merge(clock1, clock2, fn _k, v1, v2 -> max(v1, v2) end)
  end
  
  defp vector_clock_compare(clock1, clock2) do
    keys = MapSet.union(MapSet.new(Map.keys(clock1)), MapSet.new(Map.keys(clock2)))
    
    comparison = Enum.reduce(keys, :equal, fn key, acc ->
      v1 = Map.get(clock1, key, 0)
      v2 = Map.get(clock2, key, 0)
      
      case {acc, compare(v1, v2)} do
        {:equal, :equal} -> :equal
        {:equal, :less} -> :less
        {:equal, :greater} -> :greater
        {:less, :greater} -> :concurrent
        {:greater, :less} -> :concurrent
        {acc, _} -> acc
      end
    end)
    
    comparison
  end
  
  defp compare(v1, v2) when v1 < v2, do: :less
  defp compare(v1, v2) when v1 > v2, do: :greater
  defp compare(_, _), do: :equal
  
  # State Synchronization
  
  defp merge_remote_state(state, remote_node, remote_clock, remote_contexts) do
    # Merge vector clocks
    merged_clock = merge_vector_clocks(state.vector_clock, remote_clock)
    
    # Merge each context
    merged_contexts = Map.merge(state.contexts, remote_contexts, fn _k, local, remote ->
      merge_or_sets(local, remote)
    end)
    
    %{state | vector_clock: merged_clock, contexts: merged_contexts}
  end
  
  defp merge_or_sets(set1, set2) do
    %{
      additions: MapSet.union(set1.additions, set2.additions),
      removals: MapSet.union(set1.removals, set2.removals)
    }
  end
  
  # Persistence
  
  defp init_persistence(opts) do
    backend = Keyword.get(opts, :persistence_backend, :ets)
    
    case backend do
      :ets ->
        table = :ets.new(:context_persistence, [:set, :public])
        %{backend: :ets, table: table}
        
      :dets ->
        file = Keyword.get(opts, :persistence_file, "context_manager.dets")
        {:ok, table} = :dets.open_file(String.to_atom(file), [])
        %{backend: :dets, table: table}
        
      _ ->
        %{backend: :none}
    end
  end
  
  defp persist_context(state, context_id, context) do
    case state.persistence.backend do
      :ets ->
        :ets.insert(state.persistence.table, {context_id, context, System.monotonic_time()})
        
      :dets ->
        :dets.insert(state.persistence.table, {context_id, context, System.monotonic_time()})
        
      _ ->
        :ok
    end
  end
  
  defp load_persisted_contexts(state) do
    case state.persistence.backend do
      backend when backend in [:ets, :dets] ->
        contexts = :ets.tab2list(state.persistence.table)
        
        Enum.reduce(contexts, state, fn {context_id, context, _timestamp}, acc ->
          {_, new_state} = perform_crdt_merge(acc, context_id, context, %{source: :persistence})
          new_state
        end)
        
      _ ->
        state
    end
  end
  
  # Broadcasting
  
  defp broadcast_context_update(state, context_id, context) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "context:updates",
      {:context_update, context_id, context, %{node: state.node_id}}
    )
  end
  
  # Utilities
  
  defp node_id(opts) do
    Keyword.get(opts, :node_id, "#{node()}_#{:erlang.unique_integer([:positive])}")
  end
  
  defp generate_element_id do
    "elem_#{:erlang.unique_integer([:positive, :monotonic])}"
  end
  
  defp schedule_sync do
    Process.send_after(self(), :sync_tick, @sync_interval)
  end
  
  defp cleanup_old_contexts(state) do
    current_time = System.monotonic_time()
    
    # Clean up contexts older than TTL
    # This is simplified - in production, use more sophisticated cleanup
    state
  end
  
  defp list_filtered_contexts(state, filter) do
    state.contexts
    |> Enum.map(fn {id, _} -> {id, resolve_context(state, id)} end)
    |> Enum.filter(fn {_id, context} ->
      apply_filter(context, filter)
    end)
    |> Enum.into(%{})
  end
  
  defp apply_filter(_context, filter) when map_size(filter) == 0, do: true
  defp apply_filter(context, filter) do
    Enum.all?(filter, fn {key, value} ->
      Map.get(context, key) == value
    end)
  end
end