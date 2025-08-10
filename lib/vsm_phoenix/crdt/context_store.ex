defmodule VsmPhoenix.CRDT.ContextStore do
  @moduledoc """
  CRDT-based Context Persistence for aMCP Protocol
  
  Implements a Conflict-free Replicated Data Type mechanism for distributed
  state synchronization across multiple agents without central coordination.
  
  Uses a combination of:
  - GCounter for monotonic counters
  - PNCounter for increment/decrement operations
  - ORSet for add/remove operations on sets
  - LWW-Element-Set for last-write-wins semantics
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.{GCounter, PNCounter, ORSet, LWWElementSet}
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @sync_interval 5_000  # Sync every 5 seconds
  @crdt_exchange "vsm.crdt.sync"
  
  # Client API
  
  def start_link(opts) do
    node_id = opts[:node_id] || node()
    GenServer.start_link(__MODULE__, {node_id, opts}, name: __MODULE__)
  end
  
  @doc """
  Update a counter value (increment only)
  """
  def increment_counter(key, value \\ 1) do
    GenServer.call(__MODULE__, {:increment_counter, key, value})
  end
  
  @doc """
  Update a PN counter (increment/decrement)
  """
  def update_pn_counter(key, delta) do
    GenServer.call(__MODULE__, {:update_pn_counter, key, delta})
  end
  
  @doc """
  Add an element to a set
  """
  def add_to_set(key, element) do
    GenServer.call(__MODULE__, {:add_to_set, key, element})
  end
  
  @doc """
  Remove an element from a set
  """
  def remove_from_set(key, element) do
    GenServer.call(__MODULE__, {:remove_from_set, key, element})
  end
  
  @doc """
  Update a last-write-wins value
  """
  def set_lww(key, value) do
    GenServer.call(__MODULE__, {:set_lww, key, value})
  end
  
  @doc """
  Get the current value of any CRDT type
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Get counter value for a specific key.
  """
  def get_counter_value(key) do
    case get(key) do
      {:ok, counter} when is_map(counter) ->
        # Try to determine counter type and get value
        cond do
          Map.has_key?(counter, :p) and Map.has_key?(counter, :n) ->
            {:ok, VsmPhoenix.CRDT.PNCounter.value(counter)}
          Map.has_key?(counter, :entries) ->
            {:ok, VsmPhoenix.CRDT.GCounter.value(counter)}
          true ->
            {:ok, 0}
        end
      _ ->
        {:ok, 0}
    end
  end

  @doc """
  Reset counter to zero.
  """
  def reset_counter(key) do
    GenServer.call(__MODULE__, {:set_counter, key, 0})
  end

  @doc """
  Get values from a set.
  """
  def get_set_values(key) do
    case get(key) do
      {:ok, set} when is_map(set) ->
        if Map.has_key?(set, :elements) do
          {:ok, VsmPhoenix.CRDT.ORSet.value(set)}
        else
          {:ok, []}
        end
      _ ->
        {:ok, []}
    end
  end
  
  @doc """
  Get the full state for debugging
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
  
  @doc """
  Merge a remote state into our local state
  """
  def merge_state(remote_state) do
    GenServer.cast(__MODULE__, {:merge_state, remote_state})
  end

  @doc """
  Create a new vector clock
  """
  def new_vector_clock do
    %{}
  end
  
  # Server Callbacks
  
  @impl true
  def init({node_id, _opts}) do
    Logger.info("🔄 Initializing CRDT Context Store for node: #{node_id}")
    
    state = %{
      node_id: node_id,
      gcounters: %{},
      pncounters: %{},
      orsets: %{},
      lww_sets: %{},
      vector_clock: %{node_id => 0},
      channel: nil,
      sync_timer: nil
    }
    
    # Set up AMQP for state synchronization
    send(self(), :setup_amqp)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:increment_counter, key, value}, _from, state) do
    counter = Map.get(state.gcounters, key, GCounter.new())
    updated_counter = GCounter.increment(counter, state.node_id, value)
    
    new_state = %{state | 
      gcounters: Map.put(state.gcounters, key, updated_counter),
      vector_clock: increment_vector_clock(state.vector_clock, state.node_id)
    }
    
    broadcast_update(:gcounter, key, updated_counter, new_state)
    
    {:reply, {:ok, GCounter.value(updated_counter)}, new_state}
  end
  
  @impl true
  def handle_call({:update_pn_counter, key, delta}, _from, state) do
    counter = Map.get(state.pncounters, key, PNCounter.new())
    
    updated_counter = if delta > 0 do
      PNCounter.increment(counter, state.node_id, abs(delta))
    else
      PNCounter.decrement(counter, state.node_id, abs(delta))
    end
    
    new_state = %{state | 
      pncounters: Map.put(state.pncounters, key, updated_counter),
      vector_clock: increment_vector_clock(state.vector_clock, state.node_id)
    }
    
    broadcast_update(:pncounter, key, updated_counter, new_state)
    
    {:reply, {:ok, PNCounter.value(updated_counter)}, new_state}
  end
  
  @impl true
  def handle_call({:add_to_set, key, element}, _from, state) do
    set = Map.get(state.orsets, key, ORSet.new())
    updated_set = ORSet.add(set, element, state.node_id)
    
    new_state = %{state | 
      orsets: Map.put(state.orsets, key, updated_set),
      vector_clock: increment_vector_clock(state.vector_clock, state.node_id)
    }
    
    broadcast_update(:orset, key, updated_set, new_state)
    
    {:reply, {:ok, ORSet.value(updated_set)}, new_state}
  end
  
  @impl true
  def handle_call({:remove_from_set, key, element}, _from, state) do
    set = Map.get(state.orsets, key, ORSet.new())
    updated_set = ORSet.remove(set, element)
    
    new_state = %{state | 
      orsets: Map.put(state.orsets, key, updated_set),
      vector_clock: increment_vector_clock(state.vector_clock, state.node_id)
    }
    
    broadcast_update(:orset, key, updated_set, new_state)
    
    {:reply, {:ok, ORSet.value(updated_set)}, new_state}
  end
  
  @impl true
  def handle_call({:set_lww, key, value}, _from, state) do
    lww_set = Map.get(state.lww_sets, key, LWWElementSet.new())
    timestamp = :erlang.system_time(:microsecond)
    updated_set = LWWElementSet.add(lww_set, {key, value}, timestamp, state.node_id)
    
    new_state = %{state | 
      lww_sets: Map.put(state.lww_sets, key, updated_set),
      vector_clock: increment_vector_clock(state.vector_clock, state.node_id)
    }
    
    broadcast_update(:lww, key, updated_set, new_state)
    
    {:reply, {:ok, value}, new_state}
  end
  
  @impl true
  def handle_call({:get, key}, _from, state) do
    value = cond do
      Map.has_key?(state.gcounters, key) ->
        GCounter.value(state.gcounters[key])
        
      Map.has_key?(state.pncounters, key) ->
        PNCounter.value(state.pncounters[key])
        
      Map.has_key?(state.orsets, key) ->
        ORSet.value(state.orsets[key])
        
      Map.has_key?(state.lww_sets, key) ->
        LWWElementSet.value(state.lww_sets[key])
        
      true ->
        nil
    end
    
    {:reply, {:ok, value}, state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    full_state = %{
      node_id: state.node_id,
      vector_clock: state.vector_clock,
      gcounters: state.gcounters,
      pncounters: state.pncounters,
      orsets: state.orsets,
      lww_sets: state.lww_sets
    }
    
    {:reply, {:ok, full_state}, state}
  end

  @impl true
  def handle_call({:set_counter, key, value}, _from, state) do
    # Reset counter by creating new counter with specified value
    counter = VsmPhoenix.CRDT.PNCounter.new()
    counter = VsmPhoenix.CRDT.PNCounter.increment(counter, state.node_id, value)
    new_pncounters = Map.put(state.pncounters, key, counter)
    {:reply, :ok, %{state | pncounters: new_pncounters}}
  end
  
  @impl true
  def handle_cast({:merge_state, remote_state}, state) do
    Logger.debug("🔄 Merging remote CRDT state from node: #{remote_state.node_id}")
    
    new_state = %{state |
      gcounters: merge_maps(state.gcounters, remote_state.gcounters, &GCounter.merge/2),
      pncounters: merge_maps(state.pncounters, remote_state.pncounters, &PNCounter.merge/2),
      orsets: merge_maps(state.orsets, remote_state.orsets, &ORSet.merge/2),
      lww_sets: merge_maps(state.lww_sets, remote_state.lww_sets, &LWWElementSet.merge/2),
      vector_clock: merge_vector_clocks(state.vector_clock, remote_state.vector_clock)
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:setup_amqp, state) do
    case ConnectionManager.get_channel(:crdt) do
      {:ok, channel} ->
        # Set up CRDT synchronization exchange
        :ok = AMQP.Exchange.declare(channel, @crdt_exchange, :fanout, durable: true)
        
        # Create our queue for receiving sync messages
        {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, "", exclusive: true)
        :ok = AMQP.Queue.bind(channel, queue, @crdt_exchange)
        
        # Subscribe to sync messages
        {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)
        
        # Start periodic state broadcasting
        sync_timer = Process.send_after(self(), :broadcast_state, @sync_interval)
        
        Logger.info("✅ CRDT AMQP synchronization established")
        
        {:noreply, %{state | channel: channel, sync_timer: sync_timer}}
        
      {:error, reason} ->
        Logger.warning("⚠️  Could not set up CRDT AMQP channel: #{inspect(reason)}")
        Process.send_after(self(), :setup_amqp, 5_000)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:broadcast_state, state) do
    if state.channel do
      broadcast_full_state(state)
    end
    
    sync_timer = Process.send_after(self(), :broadcast_state, @sync_interval)
    {:noreply, %{state | sync_timer: sync_timer}}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    case Jason.decode(payload) do
      {:ok, %{"type" => "crdt_sync", "state" => remote_state}} ->
        remote_state = atomize_keys(remote_state)
        
        if remote_state.node_id != state.node_id do
          handle_cast({:merge_state, remote_state}, state)
        else
          {:noreply, state}
        end
        
      _ ->
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    {:noreply, state}
  end
  
  # Private Functions
  
  defp increment_vector_clock(clock, node_id) do
    Map.update(clock, node_id, 1, &(&1 + 1))
  end
  
  defp merge_vector_clocks(clock1, clock2) do
    Map.merge(clock1, clock2, fn _k, v1, v2 -> max(v1, v2) end)
  end
  
  defp merge_maps(map1, map2, merge_fn) do
    Map.merge(map1, map2, fn _k, v1, v2 -> merge_fn.(v1, v2) end)
  end
  
  defp broadcast_update(type, key, value, state) do
    # Temporarily disable AMQP broadcasting to fix context persistence issue
    Logger.debug("CRDT update: type=#{type}, key=#{inspect key}, value=#{inspect value, limit: 10}")
  end
  
  defp broadcast_full_state(state) do
    # Temporarily disable AMQP broadcasting 
    Logger.debug("CRDT full state sync requested, disabled for testing")
  end
  
  defp convert_atoms_to_strings(data) when is_map(data) do
    Map.new(data, fn {k, v} ->
      new_key = if is_atom(k), do: Atom.to_string(k), else: k
      new_value = convert_atoms_to_strings(v)
      {new_key, new_value}
    end)
  end
  
  defp convert_atoms_to_strings(data) when is_list(data) do
    Enum.map(data, &convert_atoms_to_strings/1)
  end
  
  defp convert_atoms_to_strings(data) when is_atom(data) and data not in [nil, true, false] do
    Atom.to_string(data)
  end
  
  defp convert_atoms_to_strings(data), do: data

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> 
      {String.to_atom(k), atomize_keys(v)}
    end)
  end
  
  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end
  
  defp atomize_keys(value), do: value
end