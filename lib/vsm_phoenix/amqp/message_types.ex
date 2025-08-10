defmodule VsmPhoenix.AMQP.MessageTypes do
  @moduledoc """
  Advanced aMCP Protocol Extension: Message Type Definitions
  
  Defines the extended AMQP message format for discovery, coordination,
  and distributed consensus. All messages include extensible headers
  for coordination metadata and support recursive message patterns.
  
  Message Categories:
  - Discovery: Agent announcement, capability queries, heartbeats
  - Coordination: Proposals, voting, commits, aborts
  - Consensus: Elections, leader announcements, distributed locks
  - Recursive: Nested VSM communications, meta-learning patterns
  """
  
  require Logger
  
  # Discovery Message Types
  @discovery_types ~w(ANNOUNCE QUERY RESPOND HEARTBEAT GOODBYE CAPABILITY_UPDATE)
  
  # Coordination Message Types  
  @coordination_types ~w(PROPOSE VOTE COMMIT ABORT SYNCHRONIZE CONFLICT_RESOLVE)
  
  # Consensus Message Types
  @consensus_types ~w(ELECTION COORDINATOR LOCK_REQUEST LOCK_GRANT LOCK_RELEASE LEADER_HEARTBEAT)
  
  # Recursive Message Types (from RecursiveProtocol)
  @recursive_types ~w(mcp_request recursive_signal spawn_recursive_vsm variety_amplification meta_learning)
  
  # Message structure version
  @message_version "2.0"
  
  defmodule MessageHeader do
    @moduledoc "Extended message header with coordination metadata"
    defstruct [
      :message_id,
      :correlation_id,
      :type,
      :version,
      :timestamp,
      :source,
      :destination,
      :ttl,
      :priority,
      :attention_score,
      :security_context,
      :causality_context,
      :routing_hints,
      :metadata
    ]
  end
  
  defmodule Message do
    @moduledoc "Complete message structure"
    defstruct [
      :header,
      :payload,
      :attachments
    ]
  end
  
  # Type checking functions
  
  def is_discovery_type?(type), do: type in @discovery_types
  def is_coordination_type?(type), do: type in @coordination_types
  def is_consensus_type?(type), do: type in @consensus_types
  def is_recursive_type?(type), do: type in @recursive_types
  
  def all_types do
    @discovery_types ++ @coordination_types ++ @consensus_types ++ @recursive_types
  end
  
  # Message creation functions
  
  @doc """
  Create a new message with proper structure and headers
  """
  def create_message(type, payload, opts \\ []) do
    unless type in all_types() do
      raise ArgumentError, "Unknown message type: #{type}"
    end
    
    source = Keyword.get(opts, :source, node())
    destination = Keyword.get(opts, :destination, nil)
    correlation_id = Keyword.get(opts, :correlation_id, nil)
    priority = Keyword.get(opts, :priority, 0.5)
    ttl = Keyword.get(opts, :ttl, 60_000)  # 60 seconds default
    metadata = Keyword.get(opts, :metadata, %{})
    
    header = %MessageHeader{
      message_id: generate_message_id(),
      correlation_id: correlation_id,
      type: type,
      version: @message_version,
      timestamp: :erlang.system_time(:millisecond),
      source: source,
      destination: destination,
      ttl: ttl,
      priority: priority,
      attention_score: nil,  # Will be set by CorticalAttentionEngine
      security_context: nil,  # Will be set by Security module
      causality_context: nil,  # Will be set by CausalityAMQP
      routing_hints: determine_routing_hints(type, destination),
      metadata: metadata
    }
    
    %Message{
      header: header,
      payload: payload,
      attachments: []
    }
  end
  
  @doc """
  Create a discovery announcement message
  """
  def create_announce_message(agent_id, capabilities, metadata \\ %{}) do
    payload = %{
      agent_id: agent_id,
      node: node(),
      capabilities: capabilities,
      metadata: metadata,
      status: :active,
      version: "1.0.0"
    }
    
    create_message("ANNOUNCE", payload, 
      source: agent_id,
      metadata: %{category: :discovery}
    )
  end
  
  @doc """
  Create a capability query message
  """
  def create_query_message(requester_id, query_filter, opts \\ []) do
    payload = %{
      requester: requester_id,
      filter: serialize_filter(query_filter),
      max_results: Keyword.get(opts, :max_results, 10),
      timeout: Keyword.get(opts, :timeout, 5_000)
    }
    
    create_message("QUERY", payload,
      source: requester_id,
      metadata: %{category: :discovery}
    )
  end
  
  @doc """
  Create a consensus proposal message
  """
  def create_proposal_message(proposer_id, proposal_type, content, opts \\ []) do
    payload = %{
      proposal_id: generate_proposal_id(),
      proposer: proposer_id,
      proposal_type: proposal_type,
      content: content,
      quorum_required: Keyword.get(opts, :quorum, :majority),
      timeout: Keyword.get(opts, :timeout, 30_000)
    }
    
    create_message("PROPOSE", payload,
      source: proposer_id,
      priority: Keyword.get(opts, :priority, 0.5),
      metadata: %{category: :consensus}
    )
  end
  
  @doc """
  Create a distributed lock request message
  """
  def create_lock_request_message(agent_id, resource, opts \\ []) do
    payload = %{
      agent_id: agent_id,
      resource: resource,
      lock_type: Keyword.get(opts, :type, :exclusive),
      timeout: Keyword.get(opts, :timeout, 10_000),
      priority: Keyword.get(opts, :priority, 0.5)
    }
    
    create_message("LOCK_REQUEST", payload,
      source: agent_id,
      priority: Keyword.get(opts, :priority, 0.5),
      metadata: %{category: :consensus}
    )
  end
  
  @doc """
  Create a recursive VSM spawn request message
  """
  def create_spawn_request_message(parent_id, spawn_config) do
    payload = %{
      parent_id: parent_id,
      config: spawn_config,
      recursive_depth: Map.get(spawn_config, :recursive_depth, 1),
      purpose: Map.get(spawn_config, :purpose, "emergent")
    }
    
    create_message("spawn_recursive_vsm", payload,
      source: parent_id,
      metadata: %{category: :recursive}
    )
  end
  
  @doc """
  Serialize a message for AMQP transmission
  """
  def serialize_message(%Message{} = message) do
    %{
      header: serialize_header(message.header),
      payload: message.payload,
      attachments: message.attachments
    }
    |> Jason.encode!()
  end
  
  @doc """
  Deserialize a message from AMQP
  """
  def deserialize_message(data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, %{"header" => header_data, "payload" => payload} = msg_data} ->
        header = deserialize_header(header_data)
        
        message = %Message{
          header: header,
          payload: payload,
          attachments: Map.get(msg_data, "attachments", [])
        }
        
        {:ok, message}
        
      {:error, reason} ->
        {:error, {:decode_error, reason}}
    end
  end
  
  @doc """
  Add attention score to message (called by CorticalAttentionEngine)
  """
  def add_attention_score(%Message{} = message, attention_score, components \\ nil) do
    updated_header = %{message.header | 
      attention_score: attention_score,
      metadata: Map.put(message.header.metadata, :attention_components, components)
    }
    
    %{message | header: updated_header}
  end
  
  @doc """
  Add security context to message (called by Security module)
  """
  def add_security_context(%Message{} = message, security_context) do
    updated_header = %{message.header | security_context: security_context}
    %{message | header: updated_header}
  end
  
  @doc """
  Add causality context to message (called by CausalityAMQP)
  """
  def add_causality_context(%Message{} = message, causality_context) do
    updated_header = %{message.header | causality_context: causality_context}
    %{message | header: updated_header}
  end
  
  @doc """
  Extract routing key from message for AMQP publishing
  """
  def get_routing_key(%Message{header: %{type: type} = header}) do
    category = get_message_category(type)
    
    base_key = case category do
      :discovery -> "discovery"
      :coordination -> "consensus"
      :consensus -> "consensus"
      :recursive -> "recursive"
      _ -> "vsm"
    end
    
    # Add type-specific routing
    type_key = type |> String.downcase()
    
    # Add destination if specified
    if header.destination do
      "#{base_key}.#{type_key}.#{header.destination}"
    else
      "#{base_key}.#{type_key}"
    end
  end
  
  @doc """
  Check if message has expired based on TTL
  """
  def is_expired?(%Message{header: %{timestamp: timestamp, ttl: ttl}}) do
    now = :erlang.system_time(:millisecond)
    now - timestamp > ttl
  end
  
  @doc """
  Create a response message maintaining correlation
  """
  def create_response(original_message, response_type, response_payload, opts \\ []) do
    create_message(response_type, response_payload,
      Keyword.merge([
        correlation_id: original_message.header.message_id,
        destination: original_message.header.source,
        metadata: %{
          responding_to: original_message.header.type,
          category: get_message_category(response_type)
        }
      ], opts)
    )
  end
  
  # Private functions
  
  defp generate_message_id do
    "MSG-#{:erlang.unique_integer([:positive])}-#{:erlang.system_time(:nanosecond)}"
  end
  
  defp generate_proposal_id do
    "PROP-#{:erlang.unique_integer([:positive])}-#{:erlang.system_time(:millisecond)}"
  end
  
  defp determine_routing_hints(type, destination) do
    hints = %{
      requires_consensus: type in @consensus_types,
      is_broadcast: destination == nil,
      is_recursive: type in @recursive_types
    }
    
    # Add type-specific hints
    case type do
      "ANNOUNCE" -> Map.put(hints, :gossip_enabled, true)
      "PROPOSE" -> Map.put(hints, :requires_quorum, true)
      "LOCK_REQUEST" -> Map.put(hints, :requires_ordering, true)
      _ -> hints
    end
  end
  
  defp get_message_category(type) do
    cond do
      type in @discovery_types -> :discovery
      type in @coordination_types -> :coordination
      type in @consensus_types -> :consensus
      type in @recursive_types -> :recursive
      true -> :unknown
    end
  end
  
  defp serialize_header(%MessageHeader{} = header) do
    %{
      message_id: header.message_id,
      correlation_id: header.correlation_id,
      type: header.type,
      version: header.version,
      timestamp: header.timestamp,
      source: header.source,
      destination: header.destination,
      ttl: header.ttl,
      priority: header.priority,
      attention_score: header.attention_score,
      routing_hints: header.routing_hints,
      metadata: header.metadata
    }
    # Security and causality contexts are handled separately
  end
  
  defp deserialize_header(data) when is_map(data) do
    %MessageHeader{
      message_id: data["message_id"],
      correlation_id: data["correlation_id"],
      type: data["type"],
      version: data["version"],
      timestamp: data["timestamp"],
      source: data["source"],
      destination: data["destination"],
      ttl: data["ttl"] || 60_000,
      priority: data["priority"] || 0.5,
      attention_score: data["attention_score"],
      routing_hints: data["routing_hints"] || %{},
      metadata: data["metadata"] || %{}
    }
  end
  
  defp serialize_filter(filter) when is_function(filter) do
    # For function filters, we need to serialize to a format that can be transmitted
    %{
      type: :function,
      description: "Custom filter function"
    }
  end
  
  defp serialize_filter(filter) when is_list(filter) do
    %{
      type: :capability_list,
      required_capabilities: filter
    }
  end
  
  defp serialize_filter(filter) do
    filter
  end
end