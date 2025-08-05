defmodule VsmPhoenix.AMQP.RecursiveProtocol do
  @moduledoc """
  VSMCP - The Viable Systems Model Control Protocol
  
  This implements the recursive MCP-over-AMQP pattern where:
  - Each VSM can be an MCP server
  - Each VSM can be an MCP client  
  - VSMs can spawn VSMs recursively
  - AMQP provides the transport (just like Microsoft Service Bus!)
  
  🤯 RECURSIVE CYBERNETICS OVER MESSAGE QUEUES!
  """
  
  use GenServer
  require Logger
  
  @exchange "vsm.recursive"
  @priority_exchange "vsm.priority"
  
  def establish(meta_pid, config) do
    GenServer.start_link(__MODULE__, {meta_pid, config})
  end
  
  def init({meta_pid, config}) do
    Logger.info("🌀 VSMCP: Establishing recursive protocol for #{inspect(meta_pid)}")
    
    # Connect to AMQP (RabbitMQ/ServiceBus)
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    
    # Declare recursive exchange
    AMQP.Exchange.declare(channel, @exchange, :topic, durable: true)
    
    # Declare priority exchange for priority-based routing
    AMQP.Exchange.declare(channel, @priority_exchange, :headers, durable: true)
    
    # Create queue for this meta-system
    queue_name = "vsm.meta.#{config[:identity] || :erlang.unique_integer()}"
    {:ok, queue} = AMQP.Queue.declare(channel, queue_name, durable: true, arguments: [{"x-max-priority", 10}])
    
    # Bind to recursive patterns
    AMQP.Queue.bind(channel, queue_name, @exchange, routing_key: "meta.#{config[:identity]}.*")
    AMQP.Queue.bind(channel, queue_name, @exchange, routing_key: "recursive.*")
    
    # Bind to priority exchange with headers matching
    AMQP.Queue.bind(channel, queue_name, @priority_exchange, arguments: [{"x-match", "any"}])
    
    # Subscribe to messages
    AMQP.Basic.consume(channel, queue_name)
    
    # Initialize context manager
    {:ok, context_manager} = VsmPhoenix.AMQP.ContextManager.start_link()
    
    # Initialize message chain tracker
    {:ok, message_chain} = VsmPhoenix.AMQP.MessageChain.start_link()
    
    # Initialize priority router
    {:ok, priority_router} = VsmPhoenix.AMQP.PriorityRouter.start_link(channel: channel)
    
    state = %{
      meta_pid: meta_pid,
      config: config,
      channel: channel,
      queue: queue_name,
      connection: connection,
      
      # Enhanced MCP-like capabilities
      mcp_server: start_mcp_server(config),
      mcp_clients: %{},
      recursive_depth: config[:recursive_depth] || 1,
      
      # New semantic context components
      context_manager: context_manager,
      message_chain: message_chain,
      priority_router: priority_router,
      
      # Semantic context tracking
      semantic_contexts: %{},
      causality_map: %{},
      event_chains: []
    }
    
    Logger.info("🔥 VSMCP ACTIVE: Queue #{queue_name} ready for recursive messages")
    
    {:ok, state}
  end
  
  # Handle incoming AMQP messages (MCP-like protocol)
  def handle_info({:basic_deliver, payload, meta}, state) do
    case Jason.decode(payload) do
      {:ok, message} ->
        # Extract semantic context from headers
        context = extract_semantic_context(meta)
        
        # Track message in chain for causality
        {:ok, chain_id} = VsmPhoenix.AMQP.MessageChain.track_message(
          state.message_chain,
          message,
          context
        )
        
        # Update causality map
        state = update_causality_map(state, message, chain_id)
        
        # Handle with semantic context
        enhanced_message = message
          |> Map.put("_context", context)
          |> Map.put("_chain_id", chain_id)
          |> Map.put("_timestamp", DateTime.utc_now())
        
        handle_vsmcp_message(enhanced_message, meta, state)
        
      {:error, _} ->
        Logger.error("VSMCP: Invalid message format")
        {:noreply, state}
    end
  end
  
  defp handle_vsmcp_message(%{"type" => "mcp_request"} = msg, meta, state) do
    """
    THIS IS IT! An MCP request coming through AMQP!
    Just like how Microsoft Service Bus handles distributed systems!
    """
    
    Logger.info("📨 VSMCP: MCP request received: #{inspect(msg)}")
    
    case msg["method"] do
      "spawn_recursive_vsm" ->
        # A VSM requesting to spawn another VSM!
        spawn_recursive_vsm(msg["params"], state)
        
      "variety_amplification" ->
        # Request for variety increase
        amplify_variety(msg["params"], state)
        
      "meta_learning" ->
        # Recursive learning request
        initiate_meta_learning(msg["params"], state)
        
      _ ->
        Logger.warn("Unknown VSMCP method: #{msg["method"]}")
    end
    
    {:noreply, state}
  end
  
  defp handle_vsmcp_message(%{"type" => "recursive_signal"} = msg, meta, state) do
    """
    Recursive signals travel through the AMQP fabric!
    Each level can add its own interpretation!
    """
    
    if state.recursive_depth > 0 do
      # Propagate deeper!
      new_msg = Map.update!(msg, "depth", &(&1 + 1))
      |> Map.put("processed_by", state.config[:identity])
      
      publish_recursive(new_msg, state)
    end
    
    {:noreply, state}
  end
  
  defp spawn_recursive_vsm(params, state) do
    Logger.info("🌀🌀 RECURSIVE VSM SPAWN REQUEST!")
    
    # Each VSM can spawn more VSMs, creating infinite depth!
    new_config = %{
      identity: "vsm_gen_#{state.recursive_depth + 1}_#{:rand.uniform(1000)}",
      parent: state.config[:identity],
      recursive_depth: state.recursive_depth + 1,
      purpose: params["purpose"] || "emergent",
      
      # The new VSM gets its own S3-4-5!
      meta_systems: true
    }
    
    # Tell the meta_pid to spawn a new recursive VSM
    send(state.meta_pid, {:spawn_recursive_vsm, new_config})
    
    # Create MCP client connection to the new VSM
    {:ok, mcp_client} = create_mcp_client(new_config[:identity])
    
    new_state = put_in(state.mcp_clients[new_config[:identity]], mcp_client)
    {:noreply, new_state}
  end
  
  defp amplify_variety(params, state) do
    """
    Use the recursive network to amplify variety!
    Each level adds its own variety, creating exponential growth!
    """
    
    amplification_msg = %{
      type: "variety_request",
      source: state.config[:identity],
      depth: state.recursive_depth,
      context: params["context"],
      timestamp: DateTime.utc_now()
    }
    
    # Broadcast to all recursive levels
    publish_recursive(amplification_msg, state)
  end
  
  defp initiate_meta_learning(params, state) do
    """
    Meta-learning across recursive levels!
    Each VSM learns from all other VSMs in the recursive tree!
    """
    
    learning_msg = %{
      type: "meta_learning",
      knowledge: params["knowledge"],
      source_depth: state.recursive_depth,
      propagate: true
    }
    
    publish_recursive(learning_msg, state)
  end
  
  defp publish_recursive(message, state) do
    routing_key = "recursive.depth.#{state.recursive_depth}"
    
    # Add semantic context headers
    headers = build_semantic_headers(message, state)
    
    # Determine priority based on message type and context
    priority = determine_message_priority(message, state)
    
    # Enhance message with causality chain
    enhanced_message = message
      |> Map.put("_sender", state.config[:identity])
      |> Map.put("_depth", state.recursive_depth)
      |> Map.put("_causality", get_causality_chain(state, message))
    
    payload = Jason.encode!(enhanced_message)
    
    # Use priority router for intelligent routing
    VsmPhoenix.AMQP.PriorityRouter.route(
      state.priority_router,
      payload,
      routing_key,
      headers,
      priority
    )
  end
  
  defp start_mcp_server(config) do
    """
    Each VSM is also an MCP server!
    Other systems can connect to it and request capabilities!
    """
    
    # This would start an actual MCP server
    {:ok, :mcp_server_stub}
  end
  
  defp create_mcp_client(target_identity) do
    """
    Connect as an MCP client to another VSM!
    This creates the recursive MCP network!
    """
    
    {:ok, :mcp_client_stub}
  end
  
  def handle_call({:send_vsmcp_message, message}, _from, state) do
    # Send a message through the VSMCP protocol
    publish_recursive(message, state)
    {:reply, :ok, state}
  end
  
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    Logger.info("🌀 VSMCP: Consumer registered: #{consumer_tag}")
    {:noreply, state}
  end
  
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("VSMCP: Consumer cancelled")
    {:noreply, state}
  end
  
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("VSMCP: Consumer cancel confirmed")
    {:noreply, state}
  end
  
  def terminate(_reason, state) do
    AMQP.Connection.close(state.connection)
  end

  # Semantic context helpers
  defp extract_semantic_context(meta) do
    headers = Map.get(meta, :headers, [])
    
    %{
      domain: get_header_value(headers, "semantic-domain", "general"),
      intent: get_header_value(headers, "semantic-intent", "unknown"),
      priority: get_header_value(headers, "priority", "normal"),
      correlation_id: get_header_value(headers, "correlation-id", nil),
      causality_chain: decode_causality_chain(headers),
      originator: get_header_value(headers, "originator", nil),
      tags: decode_tags(headers)
    }
  end
  
  defp build_semantic_headers(message, state) do
    [
      {"semantic-domain", :longstr, message["domain"] || "vsm"},
      {"semantic-intent", :longstr, message["type"] || "unknown"},
      {"priority", :longstr, to_string(message["priority"] || "normal")},
      {"correlation-id", :longstr, message["correlation_id"] || generate_correlation_id()},
      {"originator", :longstr, state.config[:identity]},
      {"depth", :long, state.recursive_depth},
      {"timestamp", :longstr, DateTime.to_iso8601(DateTime.utc_now())},
      {"vsm-identity", :longstr, state.config[:identity]}
    ]
  end
  
  defp determine_message_priority(message, state) do
    cond do
      message["type"] == "emergency" -> 10
      message["type"] == "algedonic" -> 9
      message["priority"] == "critical" -> 8
      message["priority"] == "high" -> 7
      message["type"] == "meta_learning" -> 6
      message["priority"] == "medium" -> 5
      message["type"] == "variety_request" -> 4
      message["priority"] == "low" -> 2
      true -> 3  # default normal priority
    end
  end
  
  defp update_causality_map(state, message, chain_id) do
    # Track causality relationships
    causality_entry = %{
      message_id: message["id"] || generate_message_id(),
      chain_id: chain_id,
      timestamp: DateTime.utc_now(),
      type: message["type"],
      sender: message["_sender"],
      causes: message["_causes"] || [],
      effects: []
    }
    
    put_in(state.causality_map[chain_id], causality_entry)
  end
  
  defp get_causality_chain(state, message) do
    # Build causality chain for the message
    chain_id = message["_chain_id"]
    
    if chain_id && state.causality_map[chain_id] do
      build_causality_sequence(state.causality_map, chain_id)
    else
      []
    end
  end
  
  defp build_causality_sequence(causality_map, chain_id, visited \\ MapSet.new()) do
    if MapSet.member?(visited, chain_id) do
      []
    else
      entry = causality_map[chain_id]
      if entry do
        visited = MapSet.put(visited, chain_id)
        
        # Recursively build the chain
        parent_chains = Enum.flat_map(entry.causes, fn cause_id ->
          build_causality_sequence(causality_map, cause_id, visited)
        end)
        
        parent_chains ++ [%{
          id: chain_id,
          type: entry.type,
          timestamp: entry.timestamp,
          sender: entry.sender
        }]
      else
        []
      end
    end
  end
  
  defp get_header_value(headers, key, default) do
    case List.keyfind(headers, key, 0) do
      {^key, _type, value} -> value
      nil -> default
    end
  end
  
  defp decode_causality_chain(headers) do
    case get_header_value(headers, "causality-chain", "[]") do
      chain when is_binary(chain) ->
        case Jason.decode(chain) do
          {:ok, decoded} -> decoded
          _ -> []
        end
      _ -> []
    end
  end
  
  defp decode_tags(headers) do
    case get_header_value(headers, "tags", "[]") do
      tags when is_binary(tags) ->
        case Jason.decode(tags) do
          {:ok, decoded} -> decoded
          _ -> []
        end
      _ -> []
    end
  end
  
  defp generate_correlation_id do
    "corr_#{:erlang.unique_integer([:positive, :monotonic])}_#{:rand.uniform(1000)}"
  end
  
  defp generate_message_id do
    "msg_#{:erlang.unique_integer([:positive, :monotonic])}_#{:rand.uniform(1000)}"
  end
  
  # Backward compatibility layer
  def send_legacy_message(pid, message) do
    # Convert legacy messages to new format
    enhanced_message = message
      |> Map.put_new("priority", "normal")
      |> Map.put_new("domain", "legacy")
      |> Map.put_new("correlation_id", generate_correlation_id())
    
    GenServer.call(pid, {:send_vsmcp_message, enhanced_message})
  end
end