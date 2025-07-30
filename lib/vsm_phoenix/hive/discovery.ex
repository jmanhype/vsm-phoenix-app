defmodule VsmPhoenix.Hive.Discovery do
  @moduledoc """
  VSM HIVE DISCOVERY SYSTEM
  
  This module implements the discovery protocol that allows VSMs to find and
  connect to each other, forming a cybernetic hive mind network.
  
  DISCOVERY MECHANISMS:
  1. Multicast discovery (UDP broadcast on local network)
  2. Registry-based discovery (central registry for remote VSMs)
  3. Peer-to-peer discovery (VSMs share knowledge of other VSMs)
  4. DNS-SD discovery (service discovery via DNS)
  
  Each VSM advertises its:
  - Identity and capabilities
  - System 1-5 specializations
  - Available MCP tools
  - Network address/connection info
  - Current load and availability
  
  This enables true emergent intelligence through VSM collaboration!
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @multicast_group {224, 0, 0, 251}  # mDNS multicast group
  @discovery_port 5353
  @heartbeat_interval 30_000  # 30 seconds
  @node_timeout 120_000       # 2 minutes
  
  # Client API
  
  def start_link(vsm_id) do
    GenServer.start_link(__MODULE__, vsm_id, name: @name)
  end
  
  @doc """
  Register this VSM with the hive discovery system
  """
  def register_vsm(vsm_id) do
    GenServer.call(@name, {:register_vsm, vsm_id})
  end
  
  @doc """
  Discover all VSM nodes in the hive
  """
  def discover_vsm_nodes do
    GenServer.call(@name, :discover_nodes)
  end
  
  @doc """
  Find a specific VSM by identity
  """
  def find_vsm(vsm_id) do
    GenServer.call(@name, {:find_vsm, vsm_id})
  end
  
  @doc """
  Get current hive nodes
  """
  def get_hive_nodes do
    GenServer.call(@name, :get_nodes)
  end
  
  @doc """
  Get aggregated capabilities across all nodes
  """
  def get_aggregated_capabilities do
    GenServer.call(@name, :get_capabilities)
  end
  
  @doc """
  Get network topology
  """
  def get_topology do
    GenServer.call(@name, :get_topology)
  end
  
  # Server Callbacks
  
  @impl true
  def init(vsm_id) do
    Logger.info("🔍 Starting VSM Discovery for #{vsm_id}")
    
    state = %{
      vsm_id: vsm_id,
      local_node: create_node_info(vsm_id),
      discovered_nodes: %{},
      multicast_socket: nil,
      registry_connections: %{},
      last_discovery: nil,
      heartbeat_timer: nil
    }
    
    # Start UDP multicast discovery
    case setup_multicast_discovery(state) do
      {:ok, socket} ->
        new_state = %{state | multicast_socket: socket}
        
        # Start heartbeat timer
        timer = Process.send_after(self(), :heartbeat, @heartbeat_interval)
        final_state = %{new_state | heartbeat_timer: timer}
        
        # Announce our presence
        announce_presence(final_state)
        
        {:ok, final_state}
        
      {:error, reason} ->
        Logger.warn("⚠️  Failed to setup multicast discovery: #{inspect(reason)}")
        {:ok, state}
    end
  end
  
  @impl true
  def handle_call({:register_vsm, vsm_id}, _from, state) do
    Logger.info("📝 Registering VSM #{vsm_id} with discovery")
    
    updated_node = %{state.local_node | 
      registered_at: DateTime.utc_now(),
      status: :active
    }
    
    new_state = %{state | local_node: updated_node}
    
    # Announce registration to the hive
    announce_presence(new_state)
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:discover_nodes, _from, state) do
    Logger.info("🔍 Discovering VSM nodes in hive")
    
    # Trigger active discovery
    perform_discovery(state)
    
    # Return current known nodes
    nodes = Map.values(state.discovered_nodes)
    {:reply, nodes, state}
  end
  
  @impl true
  def handle_call({:find_vsm, vsm_id}, _from, state) do
    case Map.get(state.discovered_nodes, vsm_id) do
      nil ->
        # Try to discover the specific VSM
        perform_targeted_discovery(vsm_id, state)
        
        case Map.get(state.discovered_nodes, vsm_id) do
          nil -> {:reply, {:error, :not_found}, state}
          node -> {:reply, {:ok, node}, state}
        end
        
      node ->
        {:reply, {:ok, node}, state}
    end
  end
  
  @impl true
  def handle_call(:get_nodes, _from, state) do
    nodes = Map.values(state.discovered_nodes)
    
    response = %{
      nodes: nodes,
      count: length(nodes),
      local_node: state.local_node,
      last_discovery: state.last_discovery
    }
    
    {:reply, response, state}
  end
  
  @impl true
  def handle_call(:get_capabilities, _from, state) do
    all_capabilities = 
      state.discovered_nodes
      |> Map.values()
      |> Enum.flat_map(& &1.capabilities)
      |> Enum.uniq()
    
    local_capabilities = state.local_node.capabilities
    
    response = %{
      total_capabilities: all_capabilities ++ local_capabilities,
      capability_count: length(all_capabilities) + length(local_capabilities),
      nodes_contributing: map_size(state.discovered_nodes) + 1,
      timestamp: DateTime.utc_now()
    }
    
    {:reply, response, state}
  end
  
  @impl true
  def handle_call(:get_topology, _from, state) do
    nodes = [state.local_node | Map.values(state.discovered_nodes)]
    
    topology = %{
      nodes: nodes,
      connections: analyze_connections(nodes),
      network_type: determine_network_type(nodes),
      resilience_score: calculate_resilience(nodes),
      timestamp: DateTime.utc_now()
    }
    
    {:reply, topology, state}
  end
  
  @impl true
  def handle_info(:heartbeat, state) do
    Logger.debug("💓 VSM heartbeat for #{state.vsm_id}")
    
    # Clean up stale nodes
    cleaned_nodes = cleanup_stale_nodes(state.discovered_nodes)
    
    # Send heartbeat announcement
    announce_presence(state)
    
    # Schedule next heartbeat
    timer = Process.send_after(self(), :heartbeat, @heartbeat_interval)
    
    new_state = %{state | 
      discovered_nodes: cleaned_nodes,
      heartbeat_timer: timer
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:udp, socket, ip, port, data}, state) do
    Logger.debug("📡 Received UDP discovery message from #{inspect(ip)}:#{port}")
    
    case decode_discovery_message(data) do
      {:ok, message} ->
        new_state = process_discovery_message(message, ip, port, state)
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.warn("⚠️  Failed to decode discovery message: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("🔍 Discovery received unknown message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  # Private Functions - Discovery Implementation
  
  defp create_node_info(vsm_id) do
    %{
      identity: vsm_id,
      node: node(),
      pid: self(),
      capabilities: get_local_capabilities(),
      systems: %{
        s1: true,  # Operations
        s2: true,  # Coordination  
        s3: true,  # Control
        s4: true,  # Intelligence
        s5: true   # Governance
      },
      specializations: determine_specializations(),
      network_info: get_network_info(),
      load: get_current_load(),
      status: :initializing,
      announced_at: DateTime.utc_now(),
      registered_at: nil,
      last_seen: DateTime.utc_now()
    }
  end
  
  defp get_local_capabilities do
    VsmPhoenix.MCP.VsmTools.list_tools()
    |> Enum.map(& &1.name)
  end
  
  defp determine_specializations do
    # Analyze current VSM configuration to determine specializations
    [
      :policy_synthesis,     # S5 governance
      :intelligence_scan,    # S4 adaptation
      :resource_control,     # S3 management
      :context_coordination, # S2 coordination
      :operations_execution  # S1 implementation
    ]
  end
  
  defp get_network_info do
    {:ok, hostname} = :inet.gethostname()
    
    %{
      hostname: to_string(hostname),
      node: node(),
      mcp_port: Application.get_env(:vsm_phoenix, :mcp_port, 4000),
      discovery_port: @discovery_port
    }
  end
  
  defp get_current_load do
    # Calculate current system load
    %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      active_connections: 0,
      tasks_queued: 0
    }
  end
  
  defp get_cpu_usage do
    case :cpu_sup.util() do
      {:error, _} -> 0.1
      usage when is_number(usage) -> usage / 100.0
      _ -> 0.1
    end
  end
  
  defp get_memory_usage do
    memory_info = :erlang.memory()
    total = memory_info[:total] || 1
    used = memory_info[:processes] || 0
    used / total
  end
  
  defp setup_multicast_discovery(state) do
    Logger.info("🌐 Setting up multicast discovery on port #{@discovery_port}")
    
    socket_opts = [
      :binary,
      :inet,
      {:active, true},
      {:reuseaddr, true},
      {:multicast_ttl, 4},
      {:multicast_loop, true}
    ]
    
    case :gen_udp.open(@discovery_port, socket_opts) do
      {:ok, socket} ->
        # Join multicast group
        case :inet.setopts(socket, [{:add_membership, {@multicast_group, {0, 0, 0, 0}}}]) do
          :ok ->
            Logger.info("✅ Joined multicast group #{inspect(@multicast_group)}")
            {:ok, socket}
            
          {:error, reason} ->
            Logger.error("❌ Failed to join multicast group: #{inspect(reason)}")
            :gen_udp.close(socket)
            {:error, reason}
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to open UDP socket: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp announce_presence(state) do
    message = create_announcement_message(state)
    
    case encode_discovery_message(message) do
      {:ok, data} ->
        if state.multicast_socket do
          :gen_udp.send(state.multicast_socket, @multicast_group, @discovery_port, data)
          Logger.debug("📢 Announced presence to hive")
        end
        
      {:error, reason} ->
        Logger.warn("⚠️  Failed to encode announcement: #{inspect(reason)}")
    end
  end
  
  defp create_announcement_message(state) do
    %{
      type: :vsm_announcement,
      vsm_id: state.vsm_id,
      node_info: state.local_node,
      timestamp: DateTime.utc_now(),
      protocol_version: "1.0"
    }
  end
  
  defp encode_discovery_message(message) do
    try do
      data = Jason.encode!(message)
      {:ok, data}
    rescue
      error ->
        {:error, error}
    end
  end
  
  defp decode_discovery_message(data) do
    try do
      message = Jason.decode!(data, keys: :atoms)
      {:ok, message}
    rescue
      error ->
        {:error, error}
    end
  end
  
  defp process_discovery_message(message, ip, port, state) do
    case message.type do
      :vsm_announcement ->
        process_vsm_announcement(message, ip, port, state)
        
      :vsm_query ->
        process_vsm_query(message, ip, port, state)
        
      :vsm_response ->
        process_vsm_response(message, ip, port, state)
        
      _ ->
        Logger.warn("⚠️  Unknown discovery message type: #{message.type}")
        state
    end
  end
  
  defp process_vsm_announcement(message, ip, _port, state) do
    vsm_id = message.vsm_id
    
    # Don't process our own announcements
    if vsm_id == state.vsm_id do
      state
    else
      Logger.info("👋 Discovered VSM: #{vsm_id} at #{inspect(ip)}")
      
      node_info = Map.merge(message.node_info, %{
        ip_address: ip,
        discovered_at: DateTime.utc_now(),
        last_seen: DateTime.utc_now()
      })
      
      new_nodes = Map.put(state.discovered_nodes, vsm_id, node_info)
      
      %{state | 
        discovered_nodes: new_nodes,
        last_discovery: DateTime.utc_now()
      }
    end
  end
  
  defp process_vsm_query(message, ip, port, state) do
    Logger.debug("❓ Received VSM query from #{inspect(ip)}")
    
    # Respond to query with our information
    response = %{
      type: :vsm_response,
      vsm_id: state.vsm_id,
      node_info: state.local_node,
      query_id: message.query_id,
      timestamp: DateTime.utc_now()
    }
    
    case encode_discovery_message(response) do
      {:ok, data} ->
        if state.multicast_socket do
          :gen_udp.send(state.multicast_socket, ip, port, data)
        end
        
      {:error, reason} ->
        Logger.warn("⚠️  Failed to send query response: #{inspect(reason)}")
    end
    
    state
  end
  
  defp process_vsm_response(message, ip, _port, state) do
    vsm_id = message.vsm_id
    
    if vsm_id != state.vsm_id do
      Logger.info("📨 Received VSM response from: #{vsm_id}")
      
      node_info = Map.merge(message.node_info, %{
        ip_address: ip,
        discovered_at: DateTime.utc_now(),
        last_seen: DateTime.utc_now()
      })
      
      new_nodes = Map.put(state.discovered_nodes, vsm_id, node_info)
      
      %{state | discovered_nodes: new_nodes}
    else
      state
    end
  end
  
  defp perform_discovery(state) do
    Logger.debug("🔍 Performing active discovery")
    
    query = %{
      type: :vsm_query,
      query_id: :erlang.unique_integer([:positive]),
      from_vsm: state.vsm_id,
      timestamp: DateTime.utc_now()
    }
    
    case encode_discovery_message(query) do
      {:ok, data} ->
        if state.multicast_socket do
          :gen_udp.send(state.multicast_socket, @multicast_group, @discovery_port, data)
        end
        
      {:error, reason} ->
        Logger.warn("⚠️  Failed to send discovery query: #{inspect(reason)}")
    end
  end
  
  defp perform_targeted_discovery(target_vsm_id, state) do
    Logger.info("🎯 Performing targeted discovery for #{target_vsm_id}")
    
    query = %{
      type: :vsm_query,
      query_id: :erlang.unique_integer([:positive]),
      target_vsm: target_vsm_id,
      from_vsm: state.vsm_id,
      timestamp: DateTime.utc_now()
    }
    
    case encode_discovery_message(query) do
      {:ok, data} ->
        if state.multicast_socket do
          :gen_udp.send(state.multicast_socket, @multicast_group, @discovery_port, data)
        end
        
      {:error, reason} ->
        Logger.warn("⚠️  Failed to send targeted discovery: #{inspect(reason)}")
    end
  end
  
  defp cleanup_stale_nodes(nodes) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@node_timeout, :millisecond)
    
    Enum.filter(nodes, fn {_id, node} ->
      DateTime.compare(node.last_seen, cutoff_time) == :gt
    end)
    |> Map.new()
  end
  
  defp analyze_connections(nodes) do
    # Analyze network connections between nodes
    total_nodes = length(nodes)
    potential_connections = total_nodes * (total_nodes - 1) / 2
    
    %{
      total_nodes: total_nodes,
      potential_connections: potential_connections,
      connection_density: if(total_nodes > 1, do: 1.0, else: 0.0),
      network_diameter: calculate_diameter(nodes)
    }
  end
  
  defp determine_network_type(nodes) when length(nodes) <= 1, do: :isolated
  defp determine_network_type(nodes) when length(nodes) <= 3, do: :small_cluster
  defp determine_network_type(nodes) when length(nodes) <= 10, do: :mesh_network
  defp determine_network_type(_nodes), do: :large_hive
  
  defp calculate_resilience(nodes) do
    # Calculate network resilience based on node distribution and capabilities
    node_count = length(nodes)
    capability_distribution = analyze_capability_distribution(nodes)
    
    base_score = min(node_count / 10.0, 1.0)  # Up to 10 nodes for full score
    diversity_bonus = capability_distribution * 0.5
    
    min(base_score + diversity_bonus, 1.0)
  end
  
  defp calculate_diameter(nodes) when length(nodes) <= 1, do: 0
  defp calculate_diameter(_nodes), do: 2  # Simplified - assume direct connectivity
  
  defp analyze_capability_distribution(nodes) do
    all_capabilities = 
      nodes
      |> Enum.flat_map(& &1.capabilities)
      |> Enum.uniq()
      |> length()
    
    if all_capabilities > 0 do
      unique_capabilities_per_node = 
        nodes
        |> Enum.map(&length(Enum.uniq(&1.capabilities)))
        |> Enum.sum()
      
      unique_capabilities_per_node / (length(nodes) * all_capabilities)
    else
      0.0
    end
  end
end