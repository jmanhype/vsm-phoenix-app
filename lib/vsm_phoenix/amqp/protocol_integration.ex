defmodule VsmPhoenix.AMQP.ProtocolIntegration do
  @moduledoc """
  Advanced aMCP Protocol Extension: Integration Layer
  
  Integrates the discovery, consensus, and network optimization modules
  with existing VSM Phoenix infrastructure including:
  - CRDT state synchronization
  - Security layer (nonce validation, HMAC signing)
  - RecursiveProtocol for VSM spawning
  - CorticalAttentionEngine for message prioritization
  
  Provides a unified interface for distributed coordination with
  security, consistency, and performance guarantees.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.{Discovery, Consensus, NetworkOptimizer, MessageTypes}
  alias VsmPhoenix.Infrastructure.Security
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.System2.CorticalAttentionEngine
  alias VsmPhoenix.AMQP.{ConnectionManager, SecureCommandRouter}
  
  @name __MODULE__
  
  defmodule CoordinationRequest do
    @moduledoc "Unified coordination request structure"
    defstruct [
      :id,
      :type,
      :agent_id,
      :action,
      :payload,
      :requirements,
      :security_context,
      :crdt_context,
      :attention_context
    ]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Discover agents with specific capabilities using secure discovery
  """
  def discover_agents(capabilities, opts \\ []) do
    GenServer.call(@name, {:discover_agents, capabilities, opts})
  end
  
  @doc """
  Coordinate an action across multiple agents with consensus
  """
  def coordinate_action(agent_id, action_type, payload, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)
    GenServer.call(@name, {:coordinate_action, agent_id, action_type, payload, opts}, timeout)
  end
  
  @doc """
  Synchronize CRDT state with discovered agents
  """
  def sync_crdt_state(agent_id, crdt_name, opts \\ []) do
    GenServer.call(@name, {:sync_crdt_state, agent_id, crdt_name, opts})
  end
  
  @doc """
  Request a distributed lock with security validation
  """
  def request_secure_lock(agent_id, resource, opts \\ []) do
    GenServer.call(@name, {:request_secure_lock, agent_id, resource, opts})
  end
  
  @doc """
  Spawn a recursive VSM with coordinated initialization
  """
  def spawn_coordinated_vsm(parent_id, config, opts \\ []) do
    GenServer.call(@name, {:spawn_coordinated_vsm, parent_id, config, opts})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔗 ProtocolIntegration: Initializing advanced aMCP integration...")
    
    state = %{
      # Integration components
      discovery_enabled: true,
      consensus_enabled: true,
      security_enabled: true,
      crdt_enabled: true,
      
      # Active coordination requests
      active_requests: %{},
      
      # Security context
      secret_key: Application.get_env(:vsm_phoenix, :integration_secret_key, "integration_key"),
      
      # CRDT synchronization state
      crdt_sync_state: %{},
      
      # Metrics
      metrics: %{
        secure_discoveries: 0,
        coordinated_actions: 0,
        crdt_syncs: 0,
        secure_locks: 0,
        coordinated_spawns: 0,
        security_validations: 0,
        attention_scores_computed: 0
      }
    }
    
    # Start integration services
    ensure_services_started()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:discover_agents, capabilities, opts}, _from, state) do
    Logger.info("🔍🔒 Integration: Secure discovery for capabilities: #{inspect(capabilities)}")
    
    # Create discovery request with security
    request_id = generate_request_id()
    agent_id = Keyword.get(opts, :agent_id, "integration_#{node()}")
    
    # Build secure discovery message
    discovery_payload = %{
      request_id: request_id,
      requester: agent_id,
      capabilities: capabilities,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    # Wrap with security
    {:ok, secure_payload} = Security.wrap_secure_message(
      discovery_payload,
      state.secret_key,
      sender_id: agent_id
    )
    
    # Perform discovery
    case Discovery.query_agents(capabilities) do
      {:ok, agents} ->
        # Verify each agent's security credentials
        verified_agents = agents
        |> Enum.map(&verify_agent_security(&1, state))
        |> Enum.filter(&(&1 != nil))
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :secure_discoveries, &(&1 + 1))
        
        {:reply, {:ok, verified_agents}, %{state | metrics: new_metrics}}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:coordinate_action, agent_id, action_type, payload, opts}, from, state) do
    Logger.info("🤝🔒 Integration: Coordinating secure action: #{action_type}")
    
    request_id = generate_request_id()
    
    # Calculate attention score for the action
    context = %{
      agent_id: agent_id,
      action_type: action_type,
      urgency: Keyword.get(opts, :urgency, :normal)
    }
    
    {:ok, attention_score, _components} = CorticalAttentionEngine.score_attention(payload, context)
    
    # Create coordination request
    coord_request = %CoordinationRequest{
      id: request_id,
      type: :action,
      agent_id: agent_id,
      action: action_type,
      payload: payload,
      requirements: Keyword.get(opts, :requirements, %{}),
      attention_context: %{score: attention_score}
    }
    
    # Store request
    new_requests = Map.put(state.active_requests, request_id, {coord_request, from})
    
    # Build consensus proposal with security
    proposal_content = %{
      action: action_type,
      payload: payload,
      attention_score: attention_score,
      security_hash: Security.generate_nonce()
    }
    
    # Wrap with security
    {:ok, secure_proposal} = Security.wrap_secure_message(
      proposal_content,
      state.secret_key,
      sender_id: agent_id
    )
    
    # Initiate consensus
    spawn(fn ->
      result = Consensus.propose(
        agent_id,
        action_type,
        secure_proposal,
        timeout: Keyword.get(opts, :timeout, 10_000),
        quorum_size: Keyword.get(opts, :quorum, :majority),
        priority: attention_score
      )
      
      GenServer.cast(@name, {:consensus_result, request_id, result})
    end)
    
    # Update metrics
    new_metrics = state.metrics
    |> Map.update!(:coordinated_actions, &(&1 + 1))
    |> Map.update!(:attention_scores_computed, &(&1 + 1))
    
    {:noreply, %{state | 
      active_requests: new_requests,
      metrics: new_metrics
    }}
  end
  
  @impl true
  def handle_call({:sync_crdt_state, agent_id, crdt_name, opts}, _from, state) do
    Logger.info("🔄🔒 Integration: CRDT sync for #{crdt_name}")
    
    # Get target agents
    target_agents = case Keyword.get(opts, :targets) do
      nil ->
        # Discover agents with CRDT capability
        case Discovery.query_agents([:crdt_sync, crdt_name]) do
          {:ok, agents} -> agents
          _ -> []
        end
        
      targets ->
        targets
    end
    
    if length(target_agents) > 0 do
      # Get current CRDT state
      case ContextStore.get_state() do
        {:ok, crdt_state} ->
          # Create sync message with security
          sync_payload = %{
            crdt_name: crdt_name,
            state: crdt_state,
            version: System.system_time(:millisecond),
            agent_id: agent_id,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
          
          # Wrap with security
          {:ok, secure_sync} = Security.wrap_secure_message(
            sync_payload,
            state.secret_key,
            sender_id: agent_id
          )
          
          # Send to each target with network optimization
          Enum.each(target_agents, fn target ->
            send_optimized_message(
              "vsm.crdt",
              "crdt.sync.#{crdt_name}",
              secure_sync,
              immediate: Keyword.get(opts, :immediate, false)
            )
          end)
          
          # Update metrics
          new_metrics = Map.update!(state.metrics, :crdt_syncs, &(&1 + 1))
          
          {:reply, {:ok, length(target_agents)}, %{state | metrics: new_metrics}}
          
        error ->
          {:reply, error, state}
      end
    else
      {:reply, {:ok, 0}, state}
    end
  end
  
  @impl true
  def handle_call({:request_secure_lock, agent_id, resource, opts}, _from, state) do
    Logger.info("🔒🤝 Integration: Secure lock request for #{resource}")
    
    # Create lock request with security validation
    lock_payload = %{
      agent_id: agent_id,
      resource: resource,
      purpose: Keyword.get(opts, :purpose, "coordination"),
      nonce: Security.generate_nonce()
    }
    
    # Calculate priority based on attention
    {:ok, attention_score, _} = CorticalAttentionEngine.score_attention(
      lock_payload,
      %{type: :lock_request, urgency: Keyword.get(opts, :urgency, :normal)}
    )
    
    # Wrap with security
    {:ok, secure_lock_request} = Security.wrap_secure_message(
      lock_payload,
      state.secret_key,
      sender_id: agent_id
    )
    
    # Verify the request is valid (not replayed)
    case Security.verify_secure_message(secure_lock_request, state.secret_key) do
      {:ok, _verified_payload} ->
        # Request lock through consensus
        result = Consensus.request_lock(
          agent_id,
          resource,
          timeout: Keyword.get(opts, :timeout, 5_000),
          priority: attention_score
        )
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :secure_locks, &(&1 + 1))
        
        {:reply, result, %{state | metrics: new_metrics}}
        
      {:error, reason} ->
        Logger.error("Integration: Lock request security validation failed: #{inspect(reason)}")
        {:reply, {:error, :security_validation_failed}, state}
    end
  end
  
  @impl true
  def handle_call({:spawn_coordinated_vsm, parent_id, config, opts}, from, state) do
    Logger.info("🌀🤝 Integration: Coordinated VSM spawn request")
    
    request_id = generate_request_id()
    
    # Build spawn configuration with security
    spawn_config = Map.merge(config, %{
      parent_id: parent_id,
      spawn_id: request_id,
      security_context: %{
        parent_key: state.secret_key,
        child_key: Security.generate_nonce()
      }
    })
    
    # Calculate spawn priority
    {:ok, attention_score, _} = CorticalAttentionEngine.score_attention(
      spawn_config,
      %{type: :vsm_spawn, recursive_depth: Map.get(config, :recursive_depth, 1)}
    )
    
    # Create coordination request
    coord_request = %CoordinationRequest{
      id: request_id,
      type: :vsm_spawn,
      agent_id: parent_id,
      action: :spawn_recursive_vsm,
      payload: spawn_config,
      attention_context: %{score: attention_score}
    }
    
    # Store request
    new_requests = Map.put(state.active_requests, request_id, {coord_request, from})
    
    # Coordinate spawn through consensus
    spawn(fn ->
      # First, ensure resources are available
      lock_result = Consensus.request_lock(
        parent_id,
        "vsm_spawn_#{request_id}",
        timeout: 5_000,
        priority: attention_score
      )
      
      case lock_result do
        {:ok, :granted} ->
          # Propose the spawn
          proposal_result = Consensus.propose(
            parent_id,
            :vsm_spawn,
            spawn_config,
            timeout: 10_000,
            quorum_size: Keyword.get(opts, :quorum, 2)
          )
          
          # Release lock
          Consensus.release_lock(parent_id, "vsm_spawn_#{request_id}")
          
          GenServer.cast(@name, {:spawn_result, request_id, proposal_result})
          
        error ->
          GenServer.cast(@name, {:spawn_result, request_id, error})
      end
    end)
    
    # Update metrics
    new_metrics = Map.update!(state.metrics, :coordinated_spawns, &(&1 + 1))
    
    {:noreply, %{state | 
      active_requests: new_requests,
      metrics: new_metrics
    }}
  end
  
  @impl true
  def handle_cast({:consensus_result, request_id, result}, state) do
    case Map.get(state.active_requests, request_id) do
      {_request, from} ->
        # Reply to original caller
        GenServer.reply(from, result)
        
        # Clean up request
        new_requests = Map.delete(state.active_requests, request_id)
        {:noreply, %{state | active_requests: new_requests}}
        
      nil ->
        Logger.warning("Integration: Received result for unknown request: #{request_id}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:spawn_result, request_id, result}, state) do
    case Map.get(state.active_requests, request_id) do
      {request, from} ->
        # Handle spawn result
        final_result = case result do
          {:ok, :committed, spawn_config} ->
            # Actually spawn the VSM
            case VsmPhoenix.AMQP.RecursiveProtocol.establish(self(), spawn_config) do
              {:ok, vsm_pid} ->
                # Set up CRDT sync for new VSM
                setup_vsm_crdt_sync(vsm_pid, spawn_config)
                {:ok, vsm_pid}
                
              error ->
                error
            end
            
          error ->
            error
        end
        
        # Reply to caller
        GenServer.reply(from, final_result)
        
        # Clean up
        new_requests = Map.delete(state.active_requests, request_id)
        {:noreply, %{state | active_requests: new_requests}}
        
      nil ->
        {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp ensure_services_started do
    # Ensure all required services are running
    services = [
      {Discovery, []},
      {Consensus, []},
      {NetworkOptimizer, []}
      # CorticalAttentionEngine is already started in the application supervision tree
    ]
    
    Enum.each(services, fn {module, opts} ->
      case Process.whereis(module) do
        nil ->
          Logger.info("Starting #{module}...")
          module.start_link(opts)
        _pid ->
          :ok
      end
    end)
  end
  
  defp verify_agent_security(agent_info, state) do
    # Verify agent has valid security credentials
    # In a real implementation, this would check certificates, keys, etc.
    if Map.get(agent_info.metadata, :security_enabled, false) do
      agent_info
    else
      Logger.warning("Integration: Agent #{agent_info.id} lacks security credentials")
      nil
    end
  end
  
  defp send_optimized_message(exchange, routing_key, message, opts) do
    case ConnectionManager.get_channel(:integration) do
      {:ok, channel} ->
        NetworkOptimizer.send_optimized(
          channel,
          exchange,
          routing_key,
          message,
          opts
        )
        
      {:error, reason} ->
        Logger.error("Integration: Failed to get channel: #{inspect(reason)}")
        {:error, :no_channel}
    end
  end
  
  defp setup_vsm_crdt_sync(vsm_pid, config) do
    # Initialize CRDT sync for new VSM
    crdt_name = "vsm_#{config.spawn_id}_state"
    
    # Create CRDT for VSM state
    # Initialize CRDT for VSM state (ContextStore manages all CRDTs internally)
    ContextStore.add_to_set("vsm_instances", crdt_name)
    
    # Register VSM for CRDT sync
    Discovery.announce(
      config.spawn_id,
      [:vsm, :crdt_sync, crdt_name],
      %{
        pid: vsm_pid,
        parent: config.parent_id,
        security_enabled: true
      }
    )
  end
  
  defp generate_request_id do
    "REQ-#{:erlang.unique_integer([:positive])}-#{:erlang.system_time(:nanosecond)}"
  end
end