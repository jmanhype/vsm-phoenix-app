defmodule VsmPhoenix.AMQP.StatelessDelegator do
  @moduledoc """
  Claude-style stateless delegation for VSM Phoenix
  
  Implements Claude Code's delegation patterns within the Advanced aMCP Protocol Extensions.
  Provides stateless task delegation with performance optimization and capability matching.
  
  Key features:
  - Stateless delegation (no shared state between tasks)
  - Capability-based agent selection
  - Performance-optimized routing
  - Claude-style tool definitions with examples
  - Automatic failover and retry mechanisms
  """
  
  require Logger
  
  alias VsmPhoenix.AMQP.{Discovery, CommandRouter, NetworkOptimizer}
  
  @doc """
  Delegate a task to the best available agent using Claude's stateless pattern
  
  ## Examples
  
      # Delegate data analysis task
      {:ok, result} = StatelessDelegator.delegate(%{
        capability: "data_processing",
        task: %{
          type: "analyze_dataset",
          data: market_data,
          analysis_type: "trend_detection"
        },
        strategy: :stateless
      })
      
      # Delegate with specific requirements
      {:ok, result} = StatelessDelegator.delegate(%{
        capability_predicate: fn meta -> 
          :environmental_scanning in meta.capabilities and
          meta.performance_score > 0.8
        end,
        task: %{
          type: "monitor_environment",
          sources: ["news", "social_media"],
          frequency: "real_time"
        },
        timeout: 10_000
      })
  """
  def delegate(options) do
    # Extract delegation parameters
    capability = Map.get(options, :capability)
    capability_predicate = Map.get(options, :capability_predicate)
    task = Map.fetch!(options, :task)
    strategy = Map.get(options, :strategy, :stateless)
    timeout = Map.get(options, :timeout, 5000)
    context = Map.get(options, :context, %{})
    
    # Build capability predicate if simple capability string provided
    predicate = capability_predicate || build_capability_predicate(capability)
    
    # Delegate using CommandRouter with Claude-style patterns
    case CommandRouter.delegate_to_capability(predicate, task, strategy: strategy, timeout: timeout) do
      {:ok, result} ->
        # Log successful delegation (stateless - no state retention)
        log_delegation_success(capability || predicate, task, result)
        {:ok, result}
        
      {:error, :no_capable_agents} ->
        # Try fallback delegation with relaxed requirements
        attempt_fallback_delegation(capability, task, strategy, timeout, context)
        
      {:error, reason} = error ->
        log_delegation_failure(capability || predicate, task, reason)
        error
    end
  end
  
  @doc """
  Spawn a new VSM instance using stateless delegation patterns
  
  This combines recursive VSM spawning with Claude's tool-based approach.
  """
  def spawn_vsm_stateless(spawn_config) do
    # Use RecursiveProtocol's enhanced tool-based spawning
    task = %{
      type: "spawn_recursive_vsm",
      purpose: Map.fetch!(spawn_config, :purpose),
      capabilities: Map.get(spawn_config, :capabilities, []),
      resource_constraints: Map.get(spawn_config, :resource_constraints, %{}),
      parent_context: Map.get(spawn_config, :parent_context, %{})
    }
    
    # Delegate to VSM spawning capability
    delegate(%{
      capability: "recursive_spawning",
      task: task,
      strategy: :stateless,
      timeout: Map.get(spawn_config, :timeout, 10_000)
    })
  end
  
  @doc """
  Amplify variety using Claude-style delegation
  
  Spawns multiple specialized agents for different aspects of a complex problem.
  """
  def amplify_variety_stateless(amplification_config) do
    problem_context = Map.fetch!(amplification_config, :problem_context)
    variety_dimensions = Map.fetch!(amplification_config, :variety_dimensions)
    coordination_strategy = Map.get(amplification_config, :coordination_strategy, :hierarchical)
    
    # Create tasks for each variety dimension
    variety_tasks = Enum.map(variety_dimensions, fn dimension ->
      %{
        type: "amplify_variety",
        problem_context: problem_context,
        variety_dimensions: [dimension],  # Focus on single dimension
        coordination_strategy: coordination_strategy,
        dimension_focus: dimension
      }
    end)
    
    # Delegate all variety tasks in parallel using stateless delegation
    variety_results = parallel_delegate_stateless(variety_tasks, %{
      capability: "variety_management",
      timeout: 15_000
    })
    
    # Combine results
    case variety_results do
      {:ok, results} ->
        combined_result = combine_variety_results(results, variety_dimensions)
        {:ok, combined_result}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Parallel stateless delegation for multiple tasks
  
  Uses Claude Code's parallel execution patterns with AMQP coordination.
  """
  def parallel_delegate_stateless(tasks, common_options) do
    capability = Map.fetch!(common_options, :capability)
    timeout = Map.get(common_options, :timeout, 5000)
    
    # Create parallel tasks using Task.async_stream
    results = Task.async_stream(
      tasks, 
      fn task ->
        delegate(%{
          capability: capability,
          task: task,
          strategy: :stateless,
          timeout: timeout
        })
      end,
      max_concurrency: length(tasks),
      timeout: timeout + 1000
    )
    |> Enum.to_list()
    
    # Process results
    case Enum.split_with(results, fn {status, _} -> status == :ok end) do
      {successes, []} ->
        # All succeeded
        success_results = Enum.map(successes, fn {:ok, {:ok, result}} -> result end)
        {:ok, success_results}
        
      {successes, failures} ->
        # Some failed - return partial results with error info
        success_results = Enum.map(successes, fn {:ok, {:ok, result}} -> result end)
        failure_info = Enum.map(failures, fn {status, error} -> {status, error} end)
        
        Logger.warning("Partial parallel delegation failure: #{inspect(failure_info)}")
        {:partial_success, %{successes: success_results, failures: failure_info}}
    end
  end
  
  # Private helper functions
  
  defp build_capability_predicate(capability) when is_binary(capability) do
    fn meta ->
      capabilities = Map.get(meta, :capabilities, [])
      capability in capabilities
    end
  end
  
  defp build_capability_predicate(capability) when is_atom(capability) do
    build_capability_predicate(Atom.to_string(capability))
  end
  
  defp attempt_fallback_delegation(capability, task, strategy, timeout, context) do
    Logger.info("Attempting fallback delegation for capability: #{inspect(capability)}")
    
    # Try with relaxed capability requirements
    relaxed_predicate = fn meta ->
      # Accept agents with related capabilities or high performance scores
      capabilities = Map.get(meta, :capabilities, [])
      performance_score = Map.get(meta, :performance_score, 0)
      
      has_related_capability = has_related_capability?(capabilities, capability)
      has_high_performance = performance_score > 0.7
      
      has_related_capability or has_high_performance
    end
    
    case CommandRouter.delegate_to_capability(relaxed_predicate, task, strategy: strategy, timeout: timeout) do
      {:ok, result} ->
        Logger.info("Fallback delegation successful")
        {:ok, Map.put(result, :fallback_used, true)}
        
      {:error, reason} ->
        Logger.warning("Fallback delegation also failed: #{inspect(reason)}")
        {:error, {:no_agents_available, capability}}
    end
  end
  
  defp has_related_capability?(agent_capabilities, target_capability) when is_binary(target_capability) do
    # Simple related capability detection based on common keywords
    target_keywords = String.split(target_capability, "_")
    
    Enum.any?(agent_capabilities, fn agent_cap ->
      agent_keywords = String.split(to_string(agent_cap), "_")
      common_keywords = MapSet.intersection(MapSet.new(target_keywords), MapSet.new(agent_keywords))
      MapSet.size(common_keywords) > 0
    end)
  end
  
  defp has_related_capability?(agent_capabilities, target_capability) when is_atom(target_capability) do
    has_related_capability?(agent_capabilities, Atom.to_string(target_capability))
  end
  
  defp combine_variety_results(results, variety_dimensions) do
    # Combine results from multiple variety amplification tasks
    spawned_agents = Enum.flat_map(results, fn result ->
      Map.get(result.result, :spawned_vsms, [])
    end)
    
    total_variety_score = Enum.sum(Enum.map(results, fn result ->
      Map.get(result.result, :variety_score, 0)
    end))
    
    %{
      variety_dimensions: variety_dimensions,
      spawned_agents: spawned_agents,
      total_variety_score: total_variety_score,
      dimension_results: results,
      ashby_compliance: total_variety_score >= length(variety_dimensions),
      coordination_structure: "parallel_stateless_delegation"
    }
  end
  
  defp log_delegation_success(capability, task, result) do
    Logger.info("Stateless delegation successful", %{
      capability: capability,
      task_type: Map.get(task, :type),
      agent: Map.get(result, :agent),
      delegation_type: Map.get(result, :delegation_type),
      performance_metrics: Map.get(result, :performance_metrics)
    })
  end
  
  defp log_delegation_failure(capability, task, reason) do
    Logger.warning("Stateless delegation failed", %{
      capability: capability,
      task_type: Map.get(task, :type),
      reason: reason
    })
  end
end