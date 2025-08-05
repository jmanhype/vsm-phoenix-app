defmodule VsmPhoenix.AMQP.MessageChain do
  @moduledoc """
  Tracks message chains for causality preservation in the VSM system.
  
  Features:
  - Message chain tracking with DAG structure
  - Causality preservation across distributed systems
  - Chain visualization for debugging and monitoring
  - Fork detection and merge handling
  """
  
  use GenServer
  require Logger
  
  @chain_ttl 7_200_000  # 2 hours in milliseconds
  @visualization_limit 50  # Max nodes to show in visualization
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    Logger.info("🔗 Message Chain Tracker: Initializing causality tracking")
    
    state = %{
      # Chain storage - DAG structure
      chains: %{},
      
      # Message to chain mapping
      message_chains: %{},
      
      # Fork detection
      forks: %{},
      
      # Chain metadata
      chain_metadata: %{},
      
      # Statistics
      stats: %{
        total_chains: 0,
        total_messages: 0,
        active_forks: 0,
        longest_chain: 0
      },
      
      # Configuration
      ttl: Keyword.get(opts, :ttl, @chain_ttl),
      
      # Persistence (optional)
      persistence: init_persistence(opts)
    }
    
    # Schedule cleanup
    schedule_cleanup()
    
    {:ok, state}
  end
  
  # Public API
  
  def track_message(pid \\ __MODULE__, message, context) do
    GenServer.call(pid, {:track_message, message, context})
  end
  
  def get_chain(pid \\ __MODULE__, chain_id) do
    GenServer.call(pid, {:get_chain, chain_id})
  end
  
  def get_message_chain(pid \\ __MODULE__, message_id) do
    GenServer.call(pid, {:get_message_chain, message_id})
  end
  
  def visualize_chain(pid \\ __MODULE__, chain_id, format \\ :dot) do
    GenServer.call(pid, {:visualize_chain, chain_id, format})
  end
  
  def get_statistics(pid \\ __MODULE__) do
    GenServer.call(pid, :get_statistics)
  end
  
  def detect_forks(pid \\ __MODULE__, chain_id) do
    GenServer.call(pid, {:detect_forks, chain_id})
  end
  
  # Callbacks
  
  def handle_call({:track_message, message, context}, _from, state) do
    {chain_id, state} = add_message_to_chain(message, context, state)
    {:reply, {:ok, chain_id}, state}
  end
  
  def handle_call({:get_chain, chain_id}, _from, state) do
    chain = Map.get(state.chains, chain_id, %{})
    {:reply, {:ok, chain}, state}
  end
  
  def handle_call({:get_message_chain, message_id}, _from, state) do
    chain_id = Map.get(state.message_chains, message_id)
    
    if chain_id do
      chain = Map.get(state.chains, chain_id, %{})
      {:reply, {:ok, chain_id, chain}, state}
    else
      {:reply, {:error, :not_found}, state}
    end
  end
  
  def handle_call({:visualize_chain, chain_id, format}, _from, state) do
    visualization = generate_visualization(state, chain_id, format)
    {:reply, {:ok, visualization}, state}
  end
  
  def handle_call(:get_statistics, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end
  
  def handle_call({:detect_forks, chain_id}, _from, state) do
    forks = detect_chain_forks(state, chain_id)
    {:reply, {:ok, forks}, state}
  end
  
  def handle_info(:cleanup, state) do
    state = cleanup_old_chains(state)
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Chain Management
  
  defp add_message_to_chain(message, context, state) do
    message_id = message["id"] || generate_message_id()
    parent_ids = extract_parent_ids(message, context)
    
    # Determine chain ID
    {chain_id, is_new_chain} = determine_chain_id(message, parent_ids, state)
    
    # Create chain node
    node = create_chain_node(message_id, message, context, parent_ids)
    
    # Update or create chain
    state = if is_new_chain do
      create_new_chain(state, chain_id, node)
    else
      add_node_to_chain(state, chain_id, node)
    end
    
    # Update message to chain mapping
    state = put_in(state.message_chains[message_id], chain_id)
    
    # Check for forks
    state = check_and_record_forks(state, chain_id, node)
    
    # Update statistics
    state = update_statistics(state, chain_id)
    
    {chain_id, state}
  end
  
  defp create_chain_node(message_id, message, context, parent_ids) do
    %{
      id: message_id,
      type: message["type"],
      timestamp: DateTime.utc_now(),
      parents: parent_ids,
      children: [],
      context: context,
      metadata: %{
        sender: message["_sender"],
        depth: message["_depth"],
        priority: context[:priority] || "normal"
      }
    }
  end
  
  defp determine_chain_id(message, parent_ids, state) do
    cond do
      # Explicit chain ID in message
      message["_chain_id"] ->
        {message["_chain_id"], false}
      
      # Continue existing chain from parent
      length(parent_ids) == 1 ->
        parent_id = hd(parent_ids)
        case Map.get(state.message_chains, parent_id) do
          nil -> {generate_chain_id(), true}
          chain_id -> {chain_id, false}
        end
      
      # Multiple parents - potential merge
      length(parent_ids) > 1 ->
        handle_chain_merge(parent_ids, state)
      
      # New chain
      true ->
        {generate_chain_id(), true}
    end
  end
  
  defp handle_chain_merge(parent_ids, state) do
    # Get all parent chains
    parent_chains = parent_ids
      |> Enum.map(fn pid -> Map.get(state.message_chains, pid) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
    
    case parent_chains do
      [] -> {generate_chain_id(), true}
      [chain_id] -> {chain_id, false}
      multiple -> 
        # For now, continue with the first chain and mark as fork
        {hd(multiple), false}
    end
  end
  
  defp create_new_chain(state, chain_id, initial_node) do
    chain = %{
      id: chain_id,
      nodes: %{initial_node.id => initial_node},
      root_nodes: [initial_node.id],
      created_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now()
    }
    
    state
    |> put_in([:chains, chain_id], chain)
    |> put_in([:chain_metadata, chain_id], %{
      message_count: 1,
      fork_count: 0,
      max_depth: 0
    })
    |> update_in([:stats, :total_chains], &(&1 + 1))
  end
  
  defp add_node_to_chain(state, chain_id, node) do
    state
    |> update_in([:chains, chain_id, :nodes], &Map.put(&1, node.id, node))
    |> update_in([:chains, chain_id, :last_updated], fn _ -> DateTime.utc_now() end)
    |> update_parent_children(chain_id, node)
    |> update_in([:chain_metadata, chain_id, :message_count], &(&1 + 1))
  end
  
  defp update_parent_children(state, chain_id, node) do
    Enum.reduce(node.parents, state, fn parent_id, acc ->
      update_in(acc, [:chains, chain_id, :nodes, parent_id, :children], fn
        nil -> [node.id]
        children -> [node.id | children]
      end)
    end)
  end
  
  defp extract_parent_ids(message, _context) do
    case message do
      %{"_causes" => causes} when is_list(causes) -> causes
      %{"parent_id" => parent} when not is_nil(parent) -> [parent]
      %{"in_reply_to" => reply_to} when not is_nil(reply_to) -> [reply_to]
      _ -> []
    end
  end
  
  # Fork Detection
  
  defp check_and_record_forks(state, chain_id, node) do
    if length(node.parents) > 1 do
      fork_info = %{
        node_id: node.id,
        parent_chains: node.parents,
        timestamp: DateTime.utc_now(),
        resolved: false
      }
      
      state
      |> update_in([:forks, chain_id], fn
        nil -> [fork_info]
        forks -> [fork_info | forks]
      end)
      |> update_in([:stats, :active_forks], &(&1 + 1))
      |> update_in([:chain_metadata, chain_id, :fork_count], &(&1 + 1))
    else
      state
    end
  end
  
  defp detect_chain_forks(state, chain_id) do
    case state.chains[chain_id] do
      nil -> []
      chain ->
        # Find all nodes with multiple children (divergence points)
        chain.nodes
        |> Enum.filter(fn {_id, node} -> length(node.children) > 1 end)
        |> Enum.map(fn {id, node} ->
          %{
            divergence_point: id,
            branches: node.children,
            timestamp: node.timestamp
          }
        end)
    end
  end
  
  # Visualization
  
  defp generate_visualization(state, chain_id, format) do
    case state.chains[chain_id] do
      nil -> 
        {:error, :chain_not_found}
      
      chain ->
        case format do
          :dot -> generate_dot_visualization(chain)
          :json -> generate_json_visualization(chain)
          :ascii -> generate_ascii_visualization(chain)
          _ -> {:error, :unsupported_format}
        end
    end
  end
  
  defp generate_dot_visualization(chain) do
    nodes = chain.nodes
      |> Enum.take(@visualization_limit)
      |> Enum.map(fn {id, node} ->
        label = "#{node.type}\\n#{format_time(node.timestamp)}"
        "  \"#{id}\" [label=\"#{label}\"];"
      end)
      |> Enum.join("\n")
    
    edges = chain.nodes
      |> Enum.take(@visualization_limit)
      |> Enum.flat_map(fn {id, node} ->
        Enum.map(node.children, fn child_id ->
          "  \"#{id}\" -> \"#{child_id}\";"
        end)
      end)
      |> Enum.join("\n")
    
    """
    digraph MessageChain {
      rankdir=TB;
      node [shape=box, style=rounded];
      
    #{nodes}
    
    #{edges}
    }
    """
  end
  
  defp generate_json_visualization(chain) do
    nodes = chain.nodes
      |> Enum.take(@visualization_limit)
      |> Enum.map(fn {id, node} ->
        %{
          id: id,
          type: node.type,
          timestamp: node.timestamp,
          parents: node.parents,
          children: node.children,
          metadata: node.metadata
        }
      end)
    
    %{
      chain_id: chain.id,
      created_at: chain.created_at,
      nodes: nodes,
      root_nodes: chain.root_nodes
    }
  end
  
  defp generate_ascii_visualization(chain) do
    # Simple ASCII tree visualization
    lines = build_ascii_tree(chain, chain.root_nodes, 0, %{})
    Enum.join(lines, "\n")
  end
  
  defp build_ascii_tree(chain, node_ids, depth, visited) do
    node_ids
    |> Enum.flat_map(fn node_id ->
      if MapSet.member?(visited, node_id) do
        [String.duplicate("  ", depth) <> "└─ (cycle: #{node_id})"]
      else
        case chain.nodes[node_id] do
          nil -> []
          node ->
            prefix = String.duplicate("  ", depth) <> "└─ "
            label = "#{node.type} (#{node.id})"
            
            visited = MapSet.put(visited, node_id)
            children_lines = build_ascii_tree(chain, node.children, depth + 1, visited)
            
            [prefix <> label | children_lines]
        end
      end
    end)
  end
  
  # Cleanup
  
  defp cleanup_old_chains(state) do
    current_time = System.monotonic_time(:millisecond)
    cutoff_time = current_time - state.ttl
    
    # Find chains to remove
    chains_to_remove = state.chains
      |> Enum.filter(fn {_id, chain} ->
        chain_age = DateTime.diff(DateTime.utc_now(), chain.last_updated, :millisecond)
        chain_age > state.ttl
      end)
      |> Enum.map(fn {id, _} -> id end)
    
    # Remove old chains and update mappings
    state = Enum.reduce(chains_to_remove, state, fn chain_id, acc ->
      # Remove message mappings
      message_ids = acc.chains[chain_id].nodes |> Map.keys()
      acc = Enum.reduce(message_ids, acc, fn msg_id, s ->
        Map.update!(s, :message_chains, &Map.delete(&1, msg_id))
      end)
      
      # Remove chain
      acc
      |> Map.update!(:chains, &Map.delete(&1, chain_id))
      |> Map.update!(:chain_metadata, &Map.delete(&1, chain_id))
      |> Map.update!(:forks, &Map.delete(&1, chain_id))
      |> update_in([:stats, :total_chains], &(&1 - 1))
    end)
    
    state
  end
  
  # Statistics
  
  defp update_statistics(state, chain_id) do
    chain_length = calculate_chain_length(state, chain_id)
    
    state
    |> update_in([:stats, :total_messages], &(&1 + 1))
    |> update_in([:stats, :longest_chain], &max(&1, chain_length))
  end
  
  defp calculate_chain_length(state, chain_id) do
    case state.chains[chain_id] do
      nil -> 0
      chain -> map_size(chain.nodes)
    end
  end
  
  # Persistence
  
  defp init_persistence(opts) do
    case Keyword.get(opts, :persistence, false) do
      true ->
        # Initialize persistence backend
        %{enabled: true}
      _ ->
        %{enabled: false}
    end
  end
  
  # Utilities
  
  defp generate_chain_id do
    "chain_#{:erlang.unique_integer([:positive, :monotonic])}_#{:rand.uniform(1000)}"
  end
  
  defp generate_message_id do
    "msg_#{:erlang.unique_integer([:positive, :monotonic])}_#{:rand.uniform(1000)}"
  end
  
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 300_000)  # 5 minutes
  end
end