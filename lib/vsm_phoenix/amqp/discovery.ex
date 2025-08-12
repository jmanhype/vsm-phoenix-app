defmodule VsmPhoenix.AMQP.Discovery do
  @moduledoc """
  Advanced aMCP Protocol Extension: Agent Discovery Module
  
  Implements gossip-based discovery protocol for distributed agent coordination.
  Agents can announce their presence, advertise capabilities, and discover peers
  in a decentralized network using AMQP as the transport layer.
  
  Features:
  - Gossip-based agent discovery
  - Capability advertisement and querying
  - Heartbeat mechanism for liveness detection
  - Registry integration for local agent tracking
  - Automatic failure detection and cleanup
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.ConnectionManager
  alias VsmPhoenix.Infrastructure.{Security, CausalityAMQP}
  alias AMQP
  
  @exchange "vsm.discovery"
  @broadcast_interval 5_000  # 5 seconds
  @heartbeat_interval 2_000  # 2 seconds
  @agent_timeout 15_000      # 15 seconds before considering agent dead
  @gossip_fanout 3           # Number of peers to gossip to
  @debug_unknown_messages Application.compile_env(:vsm_phoenix, :debug_discovery_messages, false)
  
  # Message types for discovery protocol
  @msg_announce "ANNOUNCE"
  @msg_query "QUERY"
  @msg_respond "RESPOND"
  @msg_heartbeat "HEARTBEAT"
  @msg_goodbye "GOODBYE"
  
  defmodule AgentInfo do
    @moduledoc """
    Agent information structure for Claude-style discovery with rich metadata
    
    Enhanced with comprehensive capability descriptions and usage patterns
    inspired by Claude Code's tool documentation approach.
    """
    defstruct [
      :id,
      :node,
      :capabilities,
      :metadata,
      :last_seen,
      :status,
      :version,
      :tool_definitions,  # Claude-style tool descriptions
      :usage_patterns,    # When/how to use this agent
      :performance_hints  # Optimization suggestions
    ]
  end
  
  # Claude-style capability definitions with abundant examples
  def define_capability_catalog do
    %{
      "data_processing" => %{
        description: "Processes and analyzes various data formats with specialized algorithms",
        input_types: ["json", "csv", "xml", "binary", "stream"],
        output_types: ["analysis_report", "processed_data", "insights", "metrics"],
        when_to_use: [
          "Large dataset analysis requiring specialized algorithms",
          "Real-time data stream processing",
          "Complex data transformation tasks",
          "Pattern recognition in structured/unstructured data"
        ],
        examples: [
          %{
            description: "Process financial market data for trend analysis",
            input: %{type: "market_data_stream", format: "json", volume: "high"},
            expected_output: %{type: "trend_analysis", confidence: "high", timeframe: "real-time"},
            performance: %{latency: "< 100ms", throughput: "10k events/sec"}
          },
          %{
            description: "Analyze customer behavior patterns from logs",
            input: %{type: "log_data", format: "csv", timeframe: "30_days"},
            expected_output: %{type: "behavior_patterns", segments: "user_cohorts", insights: "actionable"},
            performance: %{latency: "< 5 minutes", accuracy: "> 90%"}
          }
        ],
        resource_requirements: %{
          min_memory_mb: 512,
          recommended_memory_mb: 2048,
          cpu_intensive: true,
          network_bandwidth: "medium"
        }
      },
      "environmental_scanning" => %{
        description: "Monitors and analyzes environmental changes, trends, and patterns using LLM integration",
        input_types: ["news_feeds", "social_media", "sensor_data", "api_data", "documents"],
        output_types: ["environment_report", "trend_alerts", "risk_assessments", "opportunities"],
        when_to_use: [
          "Continuous monitoring of market conditions",
          "Early warning system for environmental changes",
          "Competitive intelligence gathering",
          "Regulatory compliance monitoring"
        ],
        examples: [
          %{
            description: "Monitor regulatory changes affecting business operations",
            input: %{sources: ["gov_websites", "legal_feeds"], domain: "fintech", frequency: "daily"},
            expected_output: %{alerts: "regulatory_changes", risk_level: "assessed", compliance_actions: "recommended"},
            integration: %{llm_provider: "anthropic", model: "claude-3-opus", cost_per_scan: "$0.05"}
          },
          %{
            description: "Track competitor product launches and market positioning",
            input: %{sources: ["press_releases", "social_media", "product_pages"], competitors: ["list"]},
            expected_output: %{competitive_landscape: "updated", threat_assessment: "scored", response_recommendations: "prioritized"}
          }
        ]
      },
      "consensus_coordination" => %{
        description: "Coordinates distributed decision-making using advanced consensus protocols",
        input_types: ["proposal", "vote_request", "decision_context", "stakeholder_input"],
        output_types: ["consensus_decision", "voting_results", "coordination_plan", "conflict_resolution"],
        when_to_use: [
          "Multi-agent systems requiring coordinated decisions",
          "Distributed resource allocation",
          "Conflict resolution between competing priorities",
          "Democratic decision-making in agent networks"
        ],
        examples: [
          %{
            description: "Coordinate resource allocation across multiple VSM instances",
            input: %{
              proposal: %{type: "resource_request", amount: 1000, priority: "high"}, 
              participants: ["vsm_1", "vsm_2", "vsm_3"],
              constraints: %{total_budget: 5000, min_consensus: "majority"}
            },
            expected_output: %{
              decision: "approved/rejected",
              allocation: %{vsm_1: 400, vsm_2: 300, vsm_3: 300},
              consensus_strength: 0.85,
              execution_plan: "step_by_step"
            }
          }
        ],
        protocol_details: %{
          consensus_algorithm: "multi_phase_commit_with_attention_scoring",
          voting_threshold: "configurable_quorum",
          timeout_handling: "graceful_degradation",
          byzantine_tolerance: "up_to_33_percent"
        }
      },
      "variety_management" => %{
        description: "Implements Ashby's Law by managing system variety to match environmental complexity",
        input_types: ["complexity_assessment", "variety_request", "adaptation_signal", "environment_change"],
        output_types: ["variety_amplification", "capability_spawn", "adaptation_strategy", "complexity_match"],
        when_to_use: [
          "System complexity insufficient for environmental demands",
          "Need to amplify problem-solving capabilities",
          "Adaptive response to changing conditions required",
          "Scaling system variety to match external variety"
        ],
        examples: [
          %{
            description: "Amplify variety for complex multi-domain problem solving",
            input: %{
              problem_complexity: %{domains: ["technical", "business", "regulatory"], interactions: "high"},
              current_variety: %{capabilities: 5, specializations: 2},
              target_variety: %{min_capabilities: 12, optimal_specializations: 6}
            },
            expected_output: %{
              spawned_agents: [
                %{id: "tech_specialist_1", capability: "technical_analysis", specialization: "cloud_architecture"},
                %{id: "business_analyst_1", capability: "business_analysis", specialization: "market_strategy"},
                %{id: "regulatory_expert_1", capability: "compliance_analysis", specialization: "data_privacy"}
              ],
              variety_score: 4.2,
              ashby_compliance: true,
              coordination_structure: "hierarchical_with_cross_links"
            }
          }
        ]
      }
    }
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Announce this agent's presence and capabilities to the network
  """
  def announce(agent_id, capabilities, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:announce, agent_id, capabilities, metadata})
  end
  
  @doc """
  Query for agents with specific capabilities
  """
  def query_agents(capability_filter) when is_function(capability_filter) do
    GenServer.call(__MODULE__, {:query_agents, capability_filter})
  end
  
  def query_agents(required_capabilities) when is_list(required_capabilities) do
    filter = fn agent_info ->
      Enum.all?(required_capabilities, &(&1 in agent_info.capabilities))
    end
    query_agents(filter)
  end
  
  @doc """
  Get all discovered agents
  """
  def list_agents do
    GenServer.call(__MODULE__, :list_agents)
  end
  
  @doc """
  Get a specific agent's information
  """
  def get_agent(agent_id) do
    GenServer.call(__MODULE__, {:get_agent, agent_id})
  end
  
  @doc """
  Gracefully remove an agent from the network
  """
  def goodbye(agent_id) do
    GenServer.cast(__MODULE__, {:goodbye, agent_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔍 Discovery: Initializing agent discovery protocol...")
    
    # Create discovery registry
    Registry.start_link(keys: :unique, name: VsmPhoenix.DiscoveryRegistry)
    
    state = %{
      # Local agent information
      local_agents: %{},
      
      # Discovered remote agents
      remote_agents: %{},
      
      # AMQP channel
      channel: nil,
      
      # Gossip state
      gossip_peers: [],
      gossip_round: 0,
      
      # Performance metrics
      metrics: %{
        announcements_sent: 0,
        announcements_received: 0,
        queries_processed: 0,
        heartbeats_sent: 0,
        agents_discovered: 0
      }
    }
    
    # Set up AMQP
    state = setup_amqp_discovery(state)
    
    # Schedule periodic broadcasts
    schedule_broadcast()
    schedule_heartbeat()
    schedule_cleanup()
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:announce, agent_id, capabilities, metadata}, state) do
    Logger.info("📢 Discovery: Announcing agent #{agent_id} with capabilities: #{inspect(capabilities)}")
    
    # Create agent info
    agent_info = %AgentInfo{
      id: agent_id,
      node: node(),
      capabilities: capabilities,
      metadata: metadata,
      last_seen: :erlang.system_time(:millisecond),
      status: :active,
      version: "1.0.0"
    }
    
    # Register locally
    Registry.register(VsmPhoenix.DiscoveryRegistry, agent_id, agent_info)
    
    # Update local agents
    new_local_agents = Map.put(state.local_agents, agent_id, agent_info)
    
    # Broadcast announcement
    broadcast_announcement(agent_info, state)
    
    # Update metrics
    new_metrics = Map.update!(state.metrics, :announcements_sent, &(&1 + 1))
    
    {:noreply, %{state | 
      local_agents: new_local_agents,
      metrics: new_metrics
    }}
  end
  
  @impl true
  def handle_cast({:goodbye, agent_id}, state) do
    Logger.info("👋 Discovery: Agent #{agent_id} saying goodbye")
    
    # Remove from local agents
    new_local_agents = Map.delete(state.local_agents, agent_id)
    
    # Unregister from registry
    Registry.unregister(VsmPhoenix.DiscoveryRegistry, agent_id)
    
    # Broadcast goodbye message
    goodbye_msg = %{
      type: @msg_goodbye,
      agent_id: agent_id,
      node: node(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_discovery_message(goodbye_msg, state)
    
    {:noreply, %{state | local_agents: new_local_agents}}
  end
  
  @impl true
  def handle_call({:query_agents, capability_filter}, _from, state) do
    Logger.debug("🔍 Discovery: Querying agents with filter")
    
    # Combine local and remote agents
    all_agents = Map.merge(state.remote_agents, state.local_agents)
    
    # Filter agents based on capabilities
    matching_agents = all_agents
    |> Map.values()
    |> Enum.filter(&(&1.status == :active))
    |> Enum.filter(capability_filter)
    
    # Update metrics
    new_metrics = Map.update!(state.metrics, :queries_processed, &(&1 + 1))
    
    {:reply, {:ok, matching_agents}, %{state | metrics: new_metrics}}
  end
  
  @impl true
  def handle_call(:list_agents, _from, state) do
    all_agents = Map.merge(state.remote_agents, state.local_agents)
    {:reply, {:ok, all_agents}, state}
  end
  
  @impl true
  def handle_call({:get_agent, agent_id}, _from, state) do
    agent = Map.get(state.local_agents, agent_id) || 
            Map.get(state.remote_agents, agent_id)
    
    reply = if agent, do: {:ok, agent}, else: {:error, :not_found}
    {:reply, reply, state}
  end
  
  @impl true
  def handle_info(:broadcast, state) do
    # Broadcast all local agents
    Enum.each(state.local_agents, fn {_id, agent_info} ->
      broadcast_announcement(agent_info, state)
    end)
    
    # Schedule next broadcast
    schedule_broadcast()
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:heartbeat, state) do
    # Send heartbeats for all local agents
    Enum.each(state.local_agents, fn {agent_id, _info} ->
      heartbeat_msg = %{
        type: @msg_heartbeat,
        agent_id: agent_id,
        node: node(),
        timestamp: :erlang.system_time(:millisecond)
      }
      
      publish_discovery_message(heartbeat_msg, state)
    end)
    
    # Update metrics
    heartbeat_count = map_size(state.local_agents)
    new_metrics = Map.update!(state.metrics, :heartbeats_sent, &(&1 + heartbeat_count))
    
    # Schedule next heartbeat
    schedule_heartbeat()
    
    {:noreply, %{state | metrics: new_metrics}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Remove stale remote agents
    now = :erlang.system_time(:millisecond)
    
    new_remote_agents = state.remote_agents
    |> Enum.filter(fn {_id, agent} ->
      now - agent.last_seen < @agent_timeout
    end)
    |> Enum.into(%{})
    
    removed_count = map_size(state.remote_agents) - map_size(new_remote_agents)
    if removed_count > 0 do
      Logger.info("🧹 Discovery: Cleaned up #{removed_count} stale agents")
    end
    
    # Schedule next cleanup
    schedule_cleanup()
    
    {:noreply, %{state | remote_agents: new_remote_agents}}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle incoming discovery messages
    case Jason.decode(payload) do
      {:ok, message} ->
        new_state = process_discovery_message(message, state)
        
        # Acknowledge message
        if state.channel do
          AMQP.Basic.ack(state.channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.error("Discovery: Failed to decode message: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("🔍 Discovery: Consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Discovery: Retrying AMQP setup...")
    new_state = setup_amqp_discovery(state)
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp setup_amqp_discovery(state) do
    case ConnectionManager.get_channel(:discovery) do
      {:ok, channel} ->
        try do
          # Declare discovery exchange
          :ok = AMQP.Exchange.declare(channel, @exchange, :topic, durable: true)
          
          # Create discovery queue
          {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, "", exclusive: true)
          
          # Bind to discovery topics
          :ok = AMQP.Queue.bind(channel, queue, @exchange, routing_key: "discovery.#")
          
          # Start consuming
          {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)
          
          Logger.info("🔍 Discovery: AMQP setup complete")
          
          Map.put(state, :channel, channel)
        rescue
          error ->
            Logger.error("Discovery: Failed to set up AMQP: #{inspect(error)}")
            Process.send_after(self(), :retry_amqp_setup, 5_000)
            state
        end
        
      {:error, reason} ->
        Logger.error("Discovery: Could not get AMQP channel: #{inspect(reason)}")
        Process.send_after(self(), :retry_amqp_setup, 5_000)
        state
    end
  end
  
  defp broadcast_announcement(agent_info, state) do
    announcement = %{
      type: @msg_announce,
      agent: %{
        id: agent_info.id,
        node: agent_info.node,
        capabilities: agent_info.capabilities,
        metadata: agent_info.metadata,
        version: agent_info.version
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    # Use gossip protocol - send to subset of peers
    gossip_to_peers(announcement, state)
    
    # Also broadcast to discovery exchange
    publish_discovery_message(announcement, state)
  end
  
  defp gossip_to_peers(message, state) do
    # Select random peers for gossip
    selected_peers = state.remote_agents
    |> Map.keys()
    |> Enum.take_random(@gossip_fanout)
    
    # In a real implementation, this would send directly to peers
    # For now, we use the broadcast mechanism
    Logger.debug("📨 Gossip to #{length(selected_peers)} peers")
  end
  
  defp publish_discovery_message(message, state) do
    if state.channel do
      routing_key = "discovery.#{message.type |> String.downcase()}"
      
      # Wrap with security if available
      secured_message = if function_exported?(Security, :wrap_secure_message, 3) do
        secret_key = Application.get_env(:vsm_phoenix, :discovery_secret_key, "discovery_key")
        Security.wrap_secure_message(message, secret_key, sender_id: node())
      else
        message
      end
      
      payload = Jason.encode!(secured_message)
      
      :ok = CausalityAMQP.publish(
        state.channel,
        @exchange,
        routing_key,
        payload,
        content_type: "application/json"
      )
    end
  end
  
  defp process_discovery_message(%{"type" => @msg_announce} = msg, state) do
    agent_data = msg["agent"]
    
    agent_info = %AgentInfo{
      id: agent_data["id"],
      node: agent_data["node"],
      capabilities: agent_data["capabilities"],
      metadata: agent_data["metadata"] || %{},
      last_seen: :erlang.system_time(:millisecond),
      status: :active,
      version: agent_data["version"] || "1.0.0"
    }
    
    # Don't process our own announcements
    if agent_info.node != node() do
      Logger.debug("📥 Discovery: Received announcement from #{agent_info.id}")
      
      # Update remote agents
      new_remote_agents = Map.put(state.remote_agents, agent_info.id, agent_info)
      
      # Update metrics
      is_new = not Map.has_key?(state.remote_agents, agent_info.id)
      new_metrics = state.metrics
      |> Map.update!(:announcements_received, &(&1 + 1))
      |> then(fn m -> if is_new, do: Map.update!(m, :agents_discovered, &(&1 + 1)), else: m end)
      
      %{state | 
        remote_agents: new_remote_agents,
        metrics: new_metrics
      }
    else
      state
    end
  end
  
  defp process_discovery_message(%{"type" => @msg_heartbeat} = msg, state) do
    agent_id = msg["agent_id"]
    
    # Update last seen time for remote agent
    new_remote_agents = Map.update(state.remote_agents, agent_id, nil, fn agent ->
      if agent do
        %{agent | last_seen: :erlang.system_time(:millisecond)}
      end
    end)
    
    %{state | remote_agents: new_remote_agents}
  end
  
  defp process_discovery_message(%{"type" => @msg_goodbye} = msg, state) do
    agent_id = msg["agent_id"]
    Logger.info("👋 Discovery: Agent #{agent_id} left the network")
    
    # Remove from remote agents
    new_remote_agents = Map.delete(state.remote_agents, agent_id)
    
    %{state | remote_agents: new_remote_agents}
  end
  
  defp process_discovery_message(%{"type" => @msg_query} = msg, state) do
    # Handle capability queries
    # This would be implemented based on the query protocol
    state
  end
  
  defp process_discovery_message(%{"type" => @msg_respond} = msg, state) do
    # Handle query responses
    # This would be implemented based on the query protocol
    state
  end
  
  defp process_discovery_message(msg, state) do
    # Best practice: Don't log unknown messages in production as it can flood logs
    # Instead, track metrics and only log in debug mode
    case msg do
      %{"type" => nil} ->
        # Silently ignore messages with nil type - common in discovery protocols
        state
      
      %{"type" => type} when is_binary(type) ->
        # Track unknown message types for monitoring but don't log each one
        :telemetry.execute(
          [:vsm, :discovery, :unknown_message],
          %{count: 1},
          %{message_type: type}
        )
        
        # Only log if debug mode is enabled
        if @debug_unknown_messages do
          Logger.debug("Discovery: Unknown message type: #{type}")
        end
        
        state
      
      _ ->
        # Malformed messages - track but don't log
        :telemetry.execute(
          [:vsm, :discovery, :malformed_message],
          %{count: 1},
          %{}
        )
        
        if @debug_unknown_messages do
          Logger.debug("Discovery: Malformed message received: #{inspect(msg)}")
        end
        
        state
    end
  end
  
  defp schedule_broadcast do
    Process.send_after(self(), :broadcast, @broadcast_interval)
  end
  
  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @agent_timeout)
  end
end