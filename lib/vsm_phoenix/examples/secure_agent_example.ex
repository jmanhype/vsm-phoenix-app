defmodule VsmPhoenix.Examples.SecureAgentExample do
  @moduledoc """
  Example implementation of a secure VSM agent using CRDT persistence
  and cryptographic security.
  
  This demonstrates:
  - Secure agent initialization with unique cryptographic identity
  - CRDT-based shared state management
  - Encrypted command exchange between agents
  - Distributed consensus using CRDT counters
  - Secure context synchronization
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.SecureContextRouter
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.Security.CryptoLayer
  
  # Client API
  
  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
  end
  
  @doc """
  Send a secure task to another agent
  """
  def send_task(agent_id, target_agent, task) do
    GenServer.call({:global, agent_id}, {:send_task, target_agent, task})
  end
  
  @doc """
  Vote on a proposal using CRDT consensus
  """
  def vote_on_proposal(agent_id, proposal_id, vote) do
    GenServer.call({:global, agent_id}, {:vote, proposal_id, vote})
  end
  
  @doc """
  Get current agent state
  """
  def get_state(agent_id) do
    GenServer.call({:global, agent_id}, :get_state)
  end
  
  @doc """
  Demonstrate secure communication between agents
  """
  def demo_secure_communication do
    Logger.info("🎭 Starting Secure Agent Communication Demo")
    
    # Start three agents
    {:ok, agent1} = start_link(agent_id: "agent_1", role: :coordinator)
    {:ok, agent2} = start_link(agent_id: "agent_2", role: :worker)
    {:ok, agent3} = start_link(agent_id: "agent_3", role: :worker)
    
    # Wait for initialization
    Process.sleep(1000)
    
    # Establish secure channels
    Logger.info("🔐 Establishing secure channels between agents")
    SecureContextRouter.establish_agent_channel("agent_1", "agent_2")
    SecureContextRouter.establish_agent_channel("agent_1", "agent_3")
    SecureContextRouter.establish_agent_channel("agent_2", "agent_3")
    
    # Coordinator sends tasks
    Logger.info("📋 Coordinator sending secure tasks")
    send_task("agent_1", "agent_2", %{
      type: :data_processing,
      payload: "Process customer data batch A",
      priority: :high
    })
    
    send_task("agent_1", "agent_3", %{
      type: :data_processing,
      payload: "Process customer data batch B",
      priority: :medium
    })
    
    Process.sleep(500)
    
    # Create a proposal for consensus
    proposal_id = "proposal_optimize_processing"
    Logger.info("🗳️  Creating proposal: #{proposal_id}")
    
    # Initialize proposal in CRDT
    ContextStore.set_lww("proposal:#{proposal_id}:description", "Optimize processing algorithm")
    ContextStore.set_lww("proposal:#{proposal_id}:created_by", "agent_1")
    ContextStore.set_lww("proposal:#{proposal_id}:created_at", DateTime.utc_now())
    
    # Agents vote
    vote_on_proposal("agent_1", proposal_id, :approve)
    vote_on_proposal("agent_2", proposal_id, :approve)
    vote_on_proposal("agent_3", proposal_id, :reject)
    
    Process.sleep(500)
    
    # Check consensus
    check_consensus(proposal_id)
    
    # Show final states
    Logger.info("📊 Final Agent States:")
    for agent_id <- ["agent_1", "agent_2", "agent_3"] do
      {:ok, state} = get_state(agent_id)
      Logger.info("Agent #{agent_id}: Tasks=#{length(state.tasks)}, Messages=#{state.metrics.messages_sent}")
    end
    
    # Get security metrics
    {:ok, metrics} = SecureContextRouter.get_metrics()
    Logger.info("🔐 Security Metrics: #{inspect(metrics)}")
    
    :ok
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :agent_id)
    role = Keyword.get(opts, :role, :worker)
    
    Logger.info("🤖 Initializing secure agent: #{agent_id} (#{role})")
    
    # Initialize crypto identity
    CryptoLayer.initialize_node_security(agent_id)
    
    # Subscribe to secure commands
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:secure:commands")
    
    state = %{
      agent_id: agent_id,
      role: role,
      tasks: [],
      peers: [],
      metrics: %{
        messages_sent: 0,
        messages_received: 0,
        tasks_completed: 0,
        votes_cast: 0
      }
    }
    
    # Register agent in CRDT
    ContextStore.add_to_set("active_agents", agent_id)
    ContextStore.set_lww("agent:#{agent_id}:role", role)
    ContextStore.set_lww("agent:#{agent_id}:started_at", DateTime.utc_now())
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:send_task, target_agent, task}, _from, state) do
    Logger.info("📤 Agent #{state.agent_id} sending task to #{target_agent}")
    
    # Add task metadata
    task_with_meta = Map.merge(task, %{
      id: generate_task_id(),
      from: state.agent_id,
      sent_at: DateTime.utc_now()
    })
    
    # Store task in CRDT for tracking
    task_key = "task:#{task_with_meta.id}"
    ContextStore.set_lww(task_key, task_with_meta)
    ContextStore.add_to_set("agent:#{target_agent}:pending_tasks", task_with_meta.id)
    
    # Send secure command
    context = %{
      task_id: task_with_meta.id,
      sender_role: state.role
    }
    
    result = SecureContextRouter.send_secure_command(
      target_agent,
      "execute_task",
      context
    )
    
    new_state = %{state |
      metrics: Map.update!(state.metrics, :messages_sent, &(&1 + 1))
    }
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call({:vote, proposal_id, vote}, _from, state) do
    Logger.info("🗳️  Agent #{state.agent_id} voting #{vote} on #{proposal_id}")
    
    # Record vote in CRDT
    vote_key = "proposal:#{proposal_id}:votes:#{state.agent_id}"
    ContextStore.set_lww(vote_key, vote)
    
    # Update vote counters
    case vote do
      :approve ->
        ContextStore.increment_counter("proposal:#{proposal_id}:approvals")
      :reject ->
        ContextStore.increment_counter("proposal:#{proposal_id}:rejections")
      :abstain ->
        ContextStore.increment_counter("proposal:#{proposal_id}:abstentions")
    end
    
    new_state = %{state |
      metrics: Map.update!(state.metrics, :votes_cast, &(&1 + 1))
    }
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_state, _from, state) do
    enhanced_state = Map.merge(state, %{
      pending_tasks: get_pending_tasks(state.agent_id),
      active_peers: get_active_peers()
    })
    
    {:reply, {:ok, enhanced_state}, state}
  end
  
  @impl true
  def handle_info({:secure_command, "execute_task", context, sender}, state) do
    Logger.info("📥 Agent #{state.agent_id} received task from #{sender}")
    
    # Retrieve task from CRDT
    task_id = context["task_id"]
    {:ok, task} = ContextStore.get("task:#{task_id}")
    
    # Add to local tasks
    new_tasks = [task | state.tasks]
    
    # Remove from pending in CRDT
    ContextStore.remove_from_set("agent:#{state.agent_id}:pending_tasks", task_id)
    
    # Simulate task processing
    spawn(fn ->
      Process.sleep(1000)
      complete_task(state.agent_id, task_id)
    end)
    
    new_state = %{state |
      tasks: new_tasks,
      metrics: Map.update!(state.metrics, :messages_received, &(&1 + 1))
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:task_completed, task_id}, state) do
    # Update task status in CRDT
    ContextStore.set_lww("task:#{task_id}:status", :completed)
    ContextStore.set_lww("task:#{task_id}:completed_at", DateTime.utc_now())
    ContextStore.increment_counter("agent:#{state.agent_id}:completed_tasks")
    
    new_state = %{state |
      metrics: Map.update!(state.metrics, :tasks_completed, &(&1 + 1))
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(msg, state) do
    Logger.debug("Agent #{state.agent_id} received: #{inspect(msg)}")
    {:noreply, state}
  end
  
  # Private Functions
  
  defp generate_task_id do
    "task_#{:erlang.unique_integer([:positive, :monotonic])}"
  end
  
  defp get_pending_tasks(agent_id) do
    case ContextStore.get("agent:#{agent_id}:pending_tasks") do
      {:ok, tasks} when is_list(tasks) -> tasks
      _ -> []
    end
  end
  
  defp get_active_peers do
    case ContextStore.get("active_agents") do
      {:ok, agents} when is_list(agents) -> agents
      _ -> []
    end
  end
  
  defp complete_task(agent_id, task_id) do
    send({:global, agent_id}, {:task_completed, task_id})
  end
  
  defp check_consensus(proposal_id) do
    # Get vote counts from CRDT
    {:ok, approvals} = ContextStore.get("proposal:#{proposal_id}:approvals")
    {:ok, rejections} = ContextStore.get("proposal:#{proposal_id}:rejections")
    {:ok, abstentions} = ContextStore.get("proposal:#{proposal_id}:abstentions")
    
    approvals = approvals || 0
    rejections = rejections || 0
    abstentions = abstentions || 0
    
    total_votes = approvals + rejections + abstentions
    
    Logger.info("📊 Consensus for #{proposal_id}:")
    Logger.info("   Approvals: #{approvals}")
    Logger.info("   Rejections: #{rejections}")
    Logger.info("   Abstentions: #{abstentions}")
    Logger.info("   Total: #{total_votes}")
    
    if approvals > rejections do
      Logger.info("✅ Proposal APPROVED by consensus")
      ContextStore.set_lww("proposal:#{proposal_id}:result", :approved)
    else
      Logger.info("❌ Proposal REJECTED by consensus")
      ContextStore.set_lww("proposal:#{proposal_id}:result", :rejected)
    end
  end
end