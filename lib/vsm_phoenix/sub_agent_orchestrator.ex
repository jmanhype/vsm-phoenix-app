defmodule VsmPhoenix.SubAgentOrchestrator do
  @moduledoc """
  Stateless Sub-Agent Orchestration inspired by Claude Code patterns.
  
  Implements hierarchical agent spawning with stateless delegation, perfect for
  Phase 3 recursive VSM spawning. Each sub-agent is spawned independently,
  executes autonomously, and returns results without maintaining state.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.AMQP.RecursiveProtocol
  alias VsmPhoenix.Security.CryptoLayer
  alias VsmPhoenix.PromptArchitecture
  
  @sub_agent_types %{
    crdt_specialist: VsmPhoenix.SubAgents.CRDTSpecialist,
    security_specialist: VsmPhoenix.SubAgents.SecuritySpecialist,
    coordination_specialist: VsmPhoenix.SubAgents.CoordinationSpecialist,
    analysis_specialist: VsmPhoenix.SubAgents.AnalysisSpecialist,
    recursive_spawner: VsmPhoenix.SubAgents.RecursiveSpawner
  }
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Delegate a complex task to appropriate sub-agents using stateless delegation.
  
  ## Examples:
  
      # CRDT synchronization task
      delegate_task("Synchronize CRDT state across 5 nodes with conflict resolution", %{
        task_type: :distributed_coordination,
        priority: :high,
        context: %{nodes: ["node1", "node2", "node3", "node4", "node5"]}
      })
      
      # Security analysis task  
      delegate_task("Analyze cryptographic key rotation security", %{
        task_type: :security_analysis,
        context: %{keys: ["key1", "key2"], rotation_policy: "7d"}
      })
  """
  def delegate_task(task_description, context \\ %{}) do
    GenServer.call(__MODULE__, {:delegate_task, task_description, context}, 30_000)
  end
  
  @doc """
  Spawn multiple sub-agents in parallel for concurrent task execution.
  Perfect for Phase 3 recursive VSM spawning scenarios.
  """
  def parallel_delegate(tasks) when is_list(tasks) do
    GenServer.call(__MODULE__, {:parallel_delegate, tasks}, 60_000)
  end
  
  @doc """
  Execute hierarchical task breakdown with sub-agent delegation.
  Each level can spawn further sub-agents as needed.
  """
  def hierarchical_execute(root_task, max_depth \\ 3) do
    GenServer.call(__MODULE__, {:hierarchical_execute, root_task, max_depth}, 120_000)
  end
  
  # Server Callbacks
  
  def init(opts) do
    {:ok, %{
      active_tasks: %{},
      sub_agent_pool: %{},
      task_counter: 0,
      opts: opts
    }}
  end
  
  def handle_call({:delegate_task, task_description, context}, from, state) do
    task_id = generate_task_id(state.task_counter)
    
    # Analyze task to determine optimal sub-agent type
    agent_type = determine_agent_type(task_description, context)
    
    # Generate specialized prompt for the sub-agent
    prompt = PromptArchitecture.generate_system_prompt(agent_type, %{
      task: task_description,
      context: context,
      delegation_style: :stateless
    })
    
    # Spawn stateless sub-agent
    {:ok, sub_agent_pid} = spawn_sub_agent(agent_type, task_id, prompt, context)
    
    # Track task without maintaining sub-agent state
    new_state = %{
      state | 
      active_tasks: Map.put(state.active_tasks, task_id, %{
        type: agent_type,
        requester: from,
        started_at: System.system_time(:millisecond),
        description: task_description
      }),
      task_counter: state.task_counter + 1
    }
    
    # Don't reply immediately - sub-agent will send result
    {:noreply, new_state}
  end
  
  def handle_call({:parallel_delegate, tasks}, from, state) do
    # Spawn multiple sub-agents concurrently
    task_results = tasks
    |> Enum.map(fn {task_desc, context} ->
      Task.async(fn ->
        agent_type = determine_agent_type(task_desc, context)
        task_id = generate_task_id(System.unique_integer())
        
        prompt = PromptArchitecture.generate_system_prompt(agent_type, %{
          task: task_desc,
          context: context,
          delegation_style: :parallel
        })
        
        {:ok, result} = execute_sub_agent_task(agent_type, task_id, prompt, context)
        {task_desc, result}
      end)
    end)
    |> Task.await_many(60_000)
    
    {:reply, {:ok, task_results}, state}
  end
  
  def handle_call({:hierarchical_execute, root_task, max_depth}, from, state) do
    # Execute task with hierarchical breakdown
    spawn(fn ->
      result = execute_hierarchical_task(root_task, max_depth, 0)
      GenServer.reply(from, {:ok, result})
    end)
    
    {:noreply, state}
  end
  
  def handle_info({:sub_agent_result, task_id, result}, state) do
    case Map.get(state.active_tasks, task_id) do
      %{requester: from} = task_info ->
        # Store result in CRDT for audit trail
        ContextStore.add_to_set("completed_tasks", %{
          task_id: task_id,
          result: result,
          completed_at: System.system_time(:millisecond),
          duration: System.system_time(:millisecond) - task_info.started_at
        })
        
        # Reply to original requester
        GenServer.reply(from, {:ok, result})
        
        # Remove from active tasks
        new_active_tasks = Map.delete(state.active_tasks, task_id)
        {:noreply, %{state | active_tasks: new_active_tasks}}
        
      nil ->
        Logger.warning("Received result for unknown task: #{task_id}")
        {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp determine_agent_type(task_description, context) do
    cond do
      String.contains?(task_description, ["CRDT", "synchroniz", "conflict", "merge"]) ->
        :crdt_specialist
        
      String.contains?(task_description, ["security", "crypto", "encrypt", "key"]) ->
        :security_specialist
        
      String.contains?(task_description, ["coordinate", "consensus", "distribute", "AMQP"]) ->
        :coordination_specialist
        
      String.contains?(task_description, ["recursive", "spawn", "VSM", "system"]) ->
        :recursive_spawner
        
      true ->
        :analysis_specialist
    end
  end
  
  defp spawn_sub_agent(agent_type, task_id, prompt, context) do
    agent_module = Map.get(@sub_agent_types, agent_type)
    
    if agent_module do
      # Spawn as supervised process that will self-terminate
      Task.Supervisor.start_child(VsmPhoenix.SubAgentSupervisor, fn ->
        execute_sub_agent_work(agent_module, task_id, prompt, context)
      end)
    else
      {:error, :unknown_agent_type}
    end
  end
  
  defp execute_sub_agent_work(agent_module, task_id, prompt, context) do
    try do
      # Execute sub-agent task
      result = agent_module.execute(prompt, context)
      
      # Send result back to orchestrator
      send(VsmPhoenix.SubAgentOrchestrator, {:sub_agent_result, task_id, result})
      
      Logger.info("Sub-agent #{agent_module} completed task #{task_id}")
    rescue
      error ->
        Logger.error("Sub-agent #{agent_module} failed: #{inspect(error)}")
        send(VsmPhoenix.SubAgentOrchestrator, {:sub_agent_result, task_id, {:error, error}})
    end
  end
  
  defp execute_sub_agent_task(agent_type, task_id, prompt, context) do
    agent_module = Map.get(@sub_agent_types, agent_type)
    
    if agent_module do
      try do
        result = agent_module.execute(prompt, context)
        {:ok, result}
      rescue
        error -> {:error, error}
      end
    else
      {:error, :unknown_agent_type}
    end
  end
  
  defp execute_hierarchical_task(task, max_depth, current_depth) when current_depth >= max_depth do
    # Reached max depth, execute directly
    Logger.info("Max depth reached, executing task directly: #{inspect(task)}")
    {:ok, "Task executed at max depth: #{current_depth}"}
  end
  
  defp execute_hierarchical_task(task, max_depth, current_depth) do
    # Analyze if task needs breakdown
    if needs_breakdown?(task) do
      subtasks = break_down_task(task)
      
      # Execute subtasks recursively
      results = subtasks
      |> Enum.map(fn subtask ->
        execute_hierarchical_task(subtask, max_depth, current_depth + 1)
      end)
      
      # Synthesize results
      synthesize_results(task, results)
    else
      # Execute task directly
      agent_type = determine_agent_type(task[:description] || "analysis", task[:context] || %{})
      execute_sub_agent_task(agent_type, generate_task_id(System.unique_integer()), 
                           "Execute: #{inspect(task)}", task[:context] || %{})
    end
  end
  
  defp needs_breakdown?(task) do
    # Simple heuristic - tasks with multiple clauses need breakdown
    description = task[:description] || ""
    String.contains?(description, [" and ", " then ", " after ", " while "]) or
    String.length(description) > 200
  end
  
  defp break_down_task(task) do
    # Simple task breakdown - split on conjunctions
    description = task[:description] || ""
    subtask_descriptions = String.split(description, ~r/ and | then | after /, trim: true)
    
    Enum.map(subtask_descriptions, fn desc ->
      %{
        description: String.trim(desc),
        context: task[:context] || %{},
        parent_task: task
      }
    end)
  end
  
  defp synthesize_results(original_task, results) do
    %{
      original_task: original_task,
      subtask_results: results,
      synthesis: "Combined results from #{length(results)} subtasks",
      completed_at: System.system_time(:millisecond)
    }
  end
  
  defp generate_task_id(counter) do
    "task_#{counter}_#{System.unique_integer()}"
  end
end