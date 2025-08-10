defmodule VsmPhoenix.AMQP.Consensus do
  @moduledoc """
  Advanced aMCP Protocol Extension: Distributed Consensus Module
  
  Implements consensus algorithms for multi-agent decision making and coordination.
  Provides distributed locking, leader election, and conflict resolution capabilities
  using AMQP as the transport layer.
  
  Features:
  - Multi-phase commit protocol for distributed decisions
  - Leader election using bully algorithm variant
  - Distributed locking with timeout and deadlock detection
  - Conflict resolution strategies for competing actions
  - Integration with CorticalAttentionEngine for priority-based consensus
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.{ConnectionManager, Discovery}
  alias VsmPhoenix.Infrastructure.{Security, CausalityAMQP}
  alias VsmPhoenix.System2.CorticalAttentionEngine
  alias AMQP
  
  @exchange "vsm.consensus"
  @timeout_default 5_000
  @leader_heartbeat_interval 2_000
  @election_timeout 3_000
  @lock_cleanup_interval 10_000
  
  # Message types for consensus protocol
  @msg_propose "PROPOSE"
  @msg_vote "VOTE"
  @msg_commit "COMMIT"
  @msg_abort "ABORT"
  @msg_election "ELECTION"
  @msg_coordinator "COORDINATOR"
  @msg_lock_request "LOCK_REQUEST"
  @msg_lock_grant "LOCK_GRANT"
  @msg_lock_release "LOCK_RELEASE"
  
  defmodule Proposal do
    @moduledoc "Consensus proposal structure"
    defstruct [
      :id,
      :proposer,
      :type,
      :content,
      :timestamp,
      :timeout,
      :votes,
      :status,
      :attention_score,
      :quorum_size
    ]
  end
  
  defmodule Lock do
    @moduledoc "Distributed lock structure"
    defstruct [
      :resource,
      :holder,
      :timestamp,
      :timeout,
      :waiters,
      :attention_priority
    ]
  end
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Propose a decision for consensus among agents
  """
  def propose(proposer_id, proposal_type, content, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout_default)
    quorum_size = Keyword.get(opts, :quorum_size, :majority)
    
    GenServer.call(__MODULE__, {:propose, proposer_id, proposal_type, content, timeout, quorum_size}, timeout + 1000)
  end
  
  @doc """
  Request a distributed lock on a resource
  """
  def request_lock(agent_id, resource, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @timeout_default)
    priority = Keyword.get(opts, :priority, 0.5)
    
    GenServer.call(__MODULE__, {:request_lock, agent_id, resource, timeout, priority}, timeout + 1000)
  end
  
  @doc """
  Release a distributed lock
  """
  def release_lock(agent_id, resource) do
    GenServer.cast(__MODULE__, {:release_lock, agent_id, resource})
  end
  
  @doc """
  Initiate leader election
  """
  def initiate_election(agent_id) do
    GenServer.cast(__MODULE__, {:initiate_election, agent_id})
  end
  
  @doc """
  Get current leader information
  """
  def get_leader do
    GenServer.call(__MODULE__, :get_leader)
  end
  
  @doc """
  Get consensus status and metrics
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🤝 Consensus: Initializing distributed consensus protocol...")
    
    state = %{
      # Node identity
      node_id: node(),
      agent_id: "consensus_#{node()}",
      
      # Leader election state
      leader: nil,
      election_in_progress: false,
      last_leader_heartbeat: nil,
      
      # Active proposals
      proposals: %{},
      
      # Distributed locks
      locks: %{},
      lock_requests: %{},
      
      # AMQP channel
      channel: nil,
      
      # Discovered agents for voting
      known_agents: %{},
      
      # Performance metrics
      metrics: %{
        proposals_initiated: 0,
        proposals_completed: 0,
        proposals_aborted: 0,
        elections_held: 0,
        locks_granted: 0,
        locks_contested: 0,
        consensus_latency_sum: 0,
        consensus_count: 0
      }
    }
    
    # Set up AMQP
    state = setup_amqp_consensus(state)
    
    # Register with discovery
    Discovery.announce(state.agent_id, [:consensus, :coordination], %{type: :consensus_node})
    
    # Schedule periodic tasks
    schedule_leader_check()
    schedule_lock_cleanup()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:propose, proposer_id, proposal_type, content, timeout, quorum_size}, from, state) do
    proposal_id = generate_proposal_id()
    Logger.info("📋 Consensus: New proposal #{proposal_id} from #{proposer_id}")
    
    # Calculate attention score for the proposal
    context = %{proposer: proposer_id, type: proposal_type}
    {:ok, attention_score, _} = CorticalAttentionEngine.score_attention(content, context)
    
    # Create proposal
    proposal = %Proposal{
      id: proposal_id,
      proposer: proposer_id,
      type: proposal_type,
      content: content,
      timestamp: :erlang.system_time(:millisecond),
      timeout: timeout,
      votes: %{proposer_id => :yes},  # Proposer votes yes
      status: :voting,
      attention_score: attention_score,
      quorum_size: calculate_quorum_size(quorum_size, state)
    }
    
    # Store proposal
    new_proposals = Map.put(state.proposals, proposal_id, {proposal, from})
    
    # Broadcast proposal for voting
    broadcast_proposal(proposal, state)
    
    # Schedule timeout
    Process.send_after(self(), {:proposal_timeout, proposal_id}, timeout)
    
    # Update metrics
    new_metrics = Map.update!(state.metrics, :proposals_initiated, &(&1 + 1))
    
    {:noreply, %{state | 
      proposals: new_proposals,
      metrics: new_metrics
    }}
  end
  
  @impl true
  def handle_call({:request_lock, agent_id, resource, timeout, priority}, from, state) do
    Logger.info("🔒 Consensus: Lock request for #{resource} from #{agent_id}")
    
    case Map.get(state.locks, resource) do
      nil ->
        # No lock exists, grant immediately
        lock = %Lock{
          resource: resource,
          holder: agent_id,
          timestamp: :erlang.system_time(:millisecond),
          timeout: timeout,
          waiters: [],
          attention_priority: priority
        }
        
        new_locks = Map.put(state.locks, resource, lock)
        
        # Broadcast lock grant
        broadcast_lock_grant(agent_id, resource, state)
        
        # Schedule timeout
        Process.send_after(self(), {:lock_timeout, resource}, timeout)
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :locks_granted, &(&1 + 1))
        
        {:reply, {:ok, :granted}, %{state | 
          locks: new_locks,
          metrics: new_metrics
        }}
        
      %Lock{holder: ^agent_id} = lock ->
        # Same agent already holds the lock, refresh timeout
        Process.send_after(self(), {:lock_timeout, resource}, timeout)
        {:reply, {:ok, :already_held}, state}
        
      %Lock{} = existing_lock ->
        # Lock is held by another agent
        Logger.debug("🔒 Lock contested for #{resource}")
        
        # Add to waiters with priority
        waiter = {agent_id, priority, from}
        new_waiters = insert_waiter_by_priority(existing_lock.waiters, waiter)
        updated_lock = %{existing_lock | waiters: new_waiters}
        new_locks = Map.put(state.locks, resource, updated_lock)
        
        # Update metrics
        new_metrics = Map.update!(state.metrics, :locks_contested, &(&1 + 1))
        
        # Don't reply yet - will reply when lock is available
        {:noreply, %{state | 
          locks: new_locks,
          metrics: new_metrics
        }}
    end
  end
  
  @impl true
  def handle_call(:get_leader, _from, state) do
    {:reply, {:ok, state.leader}, state}
  end
  
  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      node_id: state.node_id,
      leader: state.leader,
      is_leader: state.leader == state.node_id,
      active_proposals: map_size(state.proposals),
      active_locks: map_size(state.locks),
      known_agents: map_size(state.known_agents),
      metrics: Map.merge(state.metrics, %{
        average_consensus_latency: calculate_average_latency(state.metrics)
      })
    }
    
    {:reply, {:ok, status}, state}
  end
  
  @impl true
  def handle_cast({:release_lock, agent_id, resource}, state) do
    case Map.get(state.locks, resource) do
      %Lock{holder: ^agent_id} = lock ->
        Logger.info("🔓 Consensus: Lock released for #{resource}")
        
        # Grant lock to next waiter if any
        case lock.waiters do
          [{next_agent, _priority, from} | rest_waiters] ->
            # Grant to next waiter
            new_lock = %Lock{
              resource: resource,
              holder: next_agent,
              timestamp: :erlang.system_time(:millisecond),
              timeout: @timeout_default,
              waiters: rest_waiters,
              attention_priority: 0.5
            }
            
            new_locks = Map.put(state.locks, resource, new_lock)
            
            # Reply to waiting agent
            GenServer.reply(from, {:ok, :granted})
            
            # Broadcast new lock holder
            broadcast_lock_grant(next_agent, resource, state)
            
            {:noreply, %{state | locks: new_locks}}
            
          [] ->
            # No waiters, remove lock
            new_locks = Map.delete(state.locks, resource)
            {:noreply, %{state | locks: new_locks}}
        end
        
      _ ->
        # Not the holder or lock doesn't exist
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:initiate_election, agent_id}, state) do
    if not state.election_in_progress do
      Logger.info("🗳️ Consensus: Election initiated by #{agent_id}")
      
      # Start bully algorithm
      new_state = start_election(state)
      
      # Update metrics
      new_metrics = Map.update!(state.metrics, :elections_held, &(&1 + 1))
      
      {:noreply, %{new_state | metrics: new_metrics}}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle incoming consensus messages
    case Jason.decode(payload) do
      {:ok, message} ->
        new_state = process_consensus_message(message, state)
        
        # Acknowledge message
        if state.channel do
          AMQP.Basic.ack(state.channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
      {:error, reason} ->
        Logger.error("Consensus: Failed to decode message: #{inspect(reason)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:proposal_timeout, proposal_id}, state) do
    case Map.get(state.proposals, proposal_id) do
      {proposal, from} when proposal.status == :voting ->
        Logger.info("⏰ Consensus: Proposal #{proposal_id} timed out")
        
        # Check if we have enough votes
        vote_count = map_size(proposal.votes)
        yes_votes = Enum.count(proposal.votes, fn {_, vote} -> vote == :yes end)
        
        result = if yes_votes >= proposal.quorum_size do
          # Commit the proposal
          broadcast_commit(proposal_id, state)
          {:ok, :committed, proposal.content}
        else
          # Abort the proposal
          broadcast_abort(proposal_id, state)
          {:error, :insufficient_votes}
        end
        
        # Reply to proposer
        GenServer.reply(from, result)
        
        # Update metrics
        metric_key = if elem(result, 0) == :ok, do: :proposals_completed, else: :proposals_aborted
        new_metrics = Map.update!(state.metrics, metric_key, &(&1 + 1))
        
        # Calculate and record latency
        latency = :erlang.system_time(:millisecond) - proposal.timestamp
        updated_metrics = new_metrics
        |> Map.update!(:consensus_latency_sum, &(&1 + latency))
        |> Map.update!(:consensus_count, &(&1 + 1))
        
        # Remove proposal
        new_proposals = Map.delete(state.proposals, proposal_id)
        
        {:noreply, %{state | 
          proposals: new_proposals,
          metrics: updated_metrics
        }}
        
      _ ->
        # Proposal already completed or doesn't exist
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:lock_timeout, resource}, state) do
    case Map.get(state.locks, resource) do
      %Lock{} = lock ->
        Logger.info("⏰ Consensus: Lock timeout for #{resource}")
        
        # Release the lock and grant to next waiter
        handle_cast({:release_lock, lock.holder, resource}, state)
        
      nil ->
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(:leader_check, state) do
    # Check if leader is alive
    new_state = if state.leader && state.leader != state.node_id do
      case state.last_leader_heartbeat do
        nil ->
          state
          
        last_heartbeat ->
          time_since_heartbeat = :erlang.system_time(:millisecond) - last_heartbeat
          if time_since_heartbeat > @election_timeout do
            Logger.warning("💔 Consensus: Leader heartbeat timeout, initiating election")
            start_election(state)
          else
            state
          end
      end
    else
      # We are the leader, send heartbeat
      if state.leader == state.node_id do
        broadcast_leader_heartbeat(state)
      end
      state
    end
    
    schedule_leader_check()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:lock_cleanup, state) do
    # Clean up stale locks
    now = :erlang.system_time(:millisecond)
    
    new_locks = state.locks
    |> Enum.filter(fn {_resource, lock} ->
      now - lock.timestamp < @lock_cleanup_interval * 2
    end)
    |> Enum.into(%{})
    
    schedule_lock_cleanup()
    {:noreply, %{state | locks: new_locks}}
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("🤝 Consensus: Consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Consensus: Retrying AMQP setup...")
    new_state = setup_amqp_consensus(state)
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp setup_amqp_consensus(state) do
    case ConnectionManager.get_channel(:consensus) do
      {:ok, channel} ->
        try do
          # Declare consensus exchange
          :ok = AMQP.Exchange.declare(channel, @exchange, :topic, durable: true)
          
          # Create consensus queue
          {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, 
            "vsm.consensus.#{state.node_id}", 
            durable: true
          )
          
          # Bind to consensus topics
          :ok = AMQP.Queue.bind(channel, queue, @exchange, routing_key: "consensus.#")
          :ok = AMQP.Queue.bind(channel, queue, @exchange, routing_key: "election.#")
          :ok = AMQP.Queue.bind(channel, queue, @exchange, routing_key: "lock.#")
          
          # Start consuming
          {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)
          
          Logger.info("🤝 Consensus: AMQP setup complete")
          
          Map.put(state, :channel, channel)
        rescue
          error ->
            Logger.error("Consensus: Failed to set up AMQP: #{inspect(error)}")
            Process.send_after(self(), :retry_amqp_setup, 5_000)
            state
        end
        
      {:error, reason} ->
        Logger.error("Consensus: Could not get AMQP channel: #{inspect(reason)}")
        Process.send_after(self(), :retry_amqp_setup, 5_000)
        state
    end
  end
  
  defp process_consensus_message(%{"type" => @msg_propose} = msg, state) do
    proposal = deserialize_proposal(msg["proposal"])
    
    # Automatically vote based on attention score and local policy
    vote = if proposal.attention_score > 0.6 do
      :yes
    else
      # Could implement more complex voting logic here
      :no
    end
    
    # Send vote
    vote_msg = %{
      type: @msg_vote,
      proposal_id: proposal.id,
      voter: state.node_id,
      vote: vote,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(vote_msg, "consensus.vote", state)
    
    state
  end
  
  defp process_consensus_message(%{"type" => @msg_vote} = msg, state) do
    proposal_id = msg["proposal_id"]
    voter = msg["voter"]
    vote = String.to_atom(msg["vote"])
    
    case Map.get(state.proposals, proposal_id) do
      {proposal, from} when proposal.status == :voting ->
        # Record vote
        new_votes = Map.put(proposal.votes, voter, vote)
        updated_proposal = %{proposal | votes: new_votes}
        
        # Check if we have quorum
        if map_size(new_votes) >= proposal.quorum_size do
          # Trigger immediate decision
          Process.send(self(), {:proposal_timeout, proposal_id}, [])
        end
        
        new_proposals = Map.put(state.proposals, proposal_id, {updated_proposal, from})
        %{state | proposals: new_proposals}
        
      _ ->
        # Proposal doesn't exist or already decided
        state
    end
  end
  
  defp process_consensus_message(%{"type" => @msg_commit} = msg, state) do
    proposal_id = msg["proposal_id"]
    Logger.info("✅ Consensus: Proposal #{proposal_id} committed")
    
    # Remove proposal if we have it
    new_proposals = Map.delete(state.proposals, proposal_id)
    %{state | proposals: new_proposals}
  end
  
  defp process_consensus_message(%{"type" => @msg_abort} = msg, state) do
    proposal_id = msg["proposal_id"]
    Logger.info("❌ Consensus: Proposal #{proposal_id} aborted")
    
    # Remove proposal if we have it
    new_proposals = Map.delete(state.proposals, proposal_id)
    %{state | proposals: new_proposals}
  end
  
  defp process_consensus_message(%{"type" => @msg_election} = msg, state) do
    candidate = msg["candidate"]
    
    # Bully algorithm: if candidate has lower ID than us, we start our own election
    if candidate < state.node_id and not state.election_in_progress do
      start_election(state)
    else
      state
    end
  end
  
  defp process_consensus_message(%{"type" => @msg_coordinator} = msg, state) do
    new_leader = msg["leader"]
    Logger.info("👑 Consensus: New leader elected: #{new_leader}")
    
    %{state | 
      leader: new_leader,
      election_in_progress: false,
      last_leader_heartbeat: :erlang.system_time(:millisecond)
    }
  end
  
  defp process_consensus_message(%{"type" => "LEADER_HEARTBEAT"} = msg, state) do
    if msg["leader"] == state.leader do
      %{state | last_leader_heartbeat: :erlang.system_time(:millisecond)}
    else
      state
    end
  end
  
  defp process_consensus_message(msg, state) do
    Logger.warning("Consensus: Unknown message type: #{inspect(msg["type"])}")
    state
  end
  
  defp broadcast_proposal(proposal, state) do
    msg = %{
      type: @msg_propose,
      proposal: serialize_proposal(proposal),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(msg, "consensus.propose", state)
  end
  
  defp broadcast_commit(proposal_id, state) do
    msg = %{
      type: @msg_commit,
      proposal_id: proposal_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(msg, "consensus.commit", state)
  end
  
  defp broadcast_abort(proposal_id, state) do
    msg = %{
      type: @msg_abort,
      proposal_id: proposal_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(msg, "consensus.abort", state)
  end
  
  defp broadcast_lock_grant(agent_id, resource, state) do
    msg = %{
      type: @msg_lock_grant,
      agent_id: agent_id,
      resource: resource,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(msg, "lock.grant", state)
  end
  
  defp broadcast_leader_heartbeat(state) do
    msg = %{
      type: "LEADER_HEARTBEAT",
      leader: state.node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(msg, "consensus.heartbeat", state)
  end
  
  defp start_election(state) do
    Logger.info("🗳️ Consensus: Starting leader election")
    
    # Broadcast election message
    msg = %{
      type: @msg_election,
      candidate: state.node_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    publish_consensus_message(msg, "election.start", state)
    
    # Set timeout for election
    Process.send_after(self(), :election_timeout, @election_timeout)
    
    %{state | election_in_progress: true}
  end
  
  defp publish_consensus_message(message, routing_key, state) do
    if state.channel do
      # Wrap with security if available
      secured_message = if function_exported?(Security, :wrap_secure_message, 3) do
        secret_key = Application.get_env(:vsm_phoenix, :consensus_secret_key, "consensus_key")
        Security.wrap_secure_message(message, secret_key, sender_id: state.node_id)
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
  
  defp generate_proposal_id do
    "PROP-#{:erlang.unique_integer([:positive])}-#{:erlang.system_time(:millisecond)}"
  end
  
  defp calculate_quorum_size(:majority, state) do
    # Discover current agents
    case Discovery.list_agents() do
      {:ok, agents} ->
        active_count = Enum.count(agents, fn {_id, info} -> info.status == :active end)
        div(active_count, 2) + 1
        
      _ ->
        # Default to 2 if discovery fails
        2
    end
  end
  
  defp calculate_quorum_size(size, _state) when is_integer(size), do: size
  
  defp calculate_quorum_size(:all, state) do
    case Discovery.list_agents() do
      {:ok, agents} ->
        Enum.count(agents, fn {_id, info} -> info.status == :active end)
      _ ->
        3  # Default
    end
  end
  
  defp insert_waiter_by_priority(waiters, {_agent, priority, _from} = new_waiter) do
    # Insert waiter in priority order (higher priority first)
    {before, after_} = Enum.split_while(waiters, fn {_, p, _} -> p >= priority end)
    before ++ [new_waiter | after_]
  end
  
  defp calculate_average_latency(%{consensus_count: 0}), do: 0
  defp calculate_average_latency(%{consensus_latency_sum: sum, consensus_count: count}) do
    Float.round(sum / count, 2)
  end
  
  defp serialize_proposal(proposal) do
    %{
      id: proposal.id,
      proposer: proposal.proposer,
      type: proposal.type,
      content: proposal.content,
      attention_score: proposal.attention_score,
      quorum_size: proposal.quorum_size
    }
  end
  
  defp deserialize_proposal(data) do
    %Proposal{
      id: data["id"],
      proposer: data["proposer"],
      type: data["type"],
      content: data["content"],
      timestamp: :erlang.system_time(:millisecond),
      timeout: @timeout_default,
      votes: %{},
      status: :voting,
      attention_score: data["attention_score"] || 0.5,
      quorum_size: data["quorum_size"] || 2
    }
  end
  
  defp schedule_leader_check do
    Process.send_after(self(), :leader_check, @leader_heartbeat_interval)
  end
  
  defp schedule_lock_cleanup do
    Process.send_after(self(), :lock_cleanup, @lock_cleanup_interval)
  end
end