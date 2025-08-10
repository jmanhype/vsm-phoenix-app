defmodule VsmPhoenix.AMQP.ModelOptimizer do
  @moduledoc """
  Model-Family Specific Optimization for Distributed GEPA Coordination
  
  Implements intelligent model selection and optimization strategies inspired by 
  Claude Code's model-aware routing and the 35x efficiency targeting from GEPA.
  
  ## Key Features:
  - Model-family specific prompt optimization (Claude, GPT, Gemini, etc.)
  - Distributed coordination routing based on model capabilities
  - Intelligent batching and context management per model type
  - Performance-based model selection and fallback strategies
  - Cost-aware optimization with efficiency targeting
  
  ## Architecture:
  ```
  Task Request → Model Selector → Optimization Engine → Distributed Coordination
       ↓              ↓               ↓                        ↓
   Analysis        Claude-3.5      Prompt Batching         AMQP Routing
   Requirements    GPT-4o          Context Windows         Consensus Coord
   Cost Targets    Gemini-Pro      Token Optimization      Result Aggregation
  ```
  
  ## Usage Examples:
  
      # Optimize for specific model family
      {:ok, optimized_config} = ModelOptimizer.optimize_for_model(%{
        model_family: :claude,
        model_version: "claude-3.5-sonnet",
        task_type: :environmental_scanning,
        efficiency_target: 35.0,
        cost_budget: 10.00
      })
      
      # Distributed model coordination
      {:ok, coordination_result} = ModelOptimizer.coordinate_distributed_models([
        {:claude_instance_1, claude_optimized_prompts},
        {:gpt_instance_2, gpt_optimized_prompts},
        {:gemini_instance_3, gemini_optimized_prompts}
      ])
  """
  
  require Logger
  
  alias VsmPhoenix.AMQP.{Discovery, CommandRouter, NetworkOptimizer, ContextWindowManager}
  alias VsmPhoenix.System4.Intelligence.CorticalAttentionEngine
  
  # Model family definitions with optimization parameters
  @model_families %{
    claude: %{
      context_window: 200_000,
      cost_per_1k_tokens: 0.015,
      strengths: [:reasoning, :analysis, :code_generation, :structured_output],
      optimization_strategies: [:context_packing, :tool_use, :xml_structured],
      batching_efficiency: 0.85,
      preferred_prompt_style: :conversational_structured
    },
    gpt: %{
      context_window: 128_000,
      cost_per_1k_tokens: 0.01,
      strengths: [:creative_writing, :general_knowledge, :code_completion],
      optimization_strategies: [:function_calling, :system_messages, :json_mode],
      batching_efficiency: 0.75,
      preferred_prompt_style: :system_user_format
    },
    gemini: %{
      context_window: 1_000_000,
      cost_per_1k_tokens: 0.007,
      strengths: [:long_context, :multimodal, :reasoning],
      optimization_strategies: [:massive_context, :multimodal_fusion, :reasoning_chains],
      batching_efficiency: 0.90,
      preferred_prompt_style: :long_form_detailed
    }
  }
  
  # Efficiency targets and thresholds
  @gepa_efficiency_target 35.0
  @min_efficiency_threshold 5.0
  @cost_optimization_weight 0.3
  @performance_optimization_weight 0.7
  
  defmodule ModelConfig do
    @moduledoc "Model-specific configuration structure"
    defstruct [
      :family,
      :version,
      :context_limit,
      :cost_per_token,
      :optimization_strategy,
      :batching_config,
      :routing_preferences,
      :performance_history
    ]
  end
  
  defmodule OptimizationResult do
    @moduledoc "Optimization result structure"
    defstruct [
      :model_config,
      :optimized_prompts,
      :efficiency_score,
      :cost_estimate,
      :routing_instructions,
      :batching_recommendations,
      :fallback_options
    ]
  end
  
  @doc """
  Optimize configuration for specific model family
  """
  def optimize_for_model(config) do
    model_family = Map.fetch!(config, :model_family)
    model_version = Map.get(config, :model_version)
    task_type = Map.get(config, :task_type, :general)
    efficiency_target = Map.get(config, :efficiency_target, @gepa_efficiency_target)
    cost_budget = Map.get(config, :cost_budget)
    
    # Get model family configuration
    family_config = Map.get(@model_families, model_family)
    
    if family_config do
      # Create optimized configuration
      optimized_config = create_optimized_config(
        family_config,
        model_version,
        task_type,
        efficiency_target,
        cost_budget
      )
      
      {:ok, optimized_config}
    else
      {:error, {:unsupported_model_family, model_family}}
    end
  end
  
  @doc """
  Coordinate distributed model optimization across multiple instances
  """
  def coordinate_distributed_models(model_instances) do
    # Analyze model instance capabilities and current loads
    instance_analysis = analyze_model_instances(model_instances)
    
    # Create optimization plan for distributed coordination
    coordination_plan = create_distributed_optimization_plan(instance_analysis)
    
    # Execute coordination using AMQP infrastructure
    case execute_distributed_coordination(coordination_plan) do
      {:ok, results} ->
        # Aggregate and optimize results
        aggregated_result = aggregate_distributed_results(results)
        {:ok, aggregated_result}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Select optimal model for given task using performance history and requirements
  """
  def select_optimal_model(task_requirements, available_models) do
    # Score each available model against task requirements
    model_scores = Enum.map(available_models, fn model ->
      score = calculate_model_task_compatibility(model, task_requirements)
      {model, score}
    end)
    
    # Select highest scoring model
    case Enum.max_by(model_scores, &elem(&1, 1), fn -> nil end) do
      nil -> {:error, :no_suitable_models}
      {best_model, score} -> {:ok, best_model, score}
    end
  end
  
  @doc """
  Optimize prompt batching for specific model family
  """
  def optimize_prompt_batching(prompts, model_config, efficiency_target) do
    family_config = Map.get(@model_families, model_config.family)
    
    if family_config do
      # Create optimized batches based on model characteristics
      optimized_batches = create_model_specific_batches(
        prompts,
        family_config,
        efficiency_target
      )
      
      {:ok, optimized_batches}
    else
      {:error, {:unsupported_model_family, model_config.family}}
    end
  end
  
  @doc """
  Calculate efficiency score for model configuration
  """
  def calculate_efficiency_score(model_config, performance_metrics) do
    # Base efficiency from model family
    family_config = Map.get(@model_families, model_config.family, %{})
    base_efficiency = Map.get(family_config, :batching_efficiency, 0.5)
    
    # Performance-based adjustments
    success_rate = Map.get(performance_metrics, :success_rate, 0.5)
    avg_response_time = Map.get(performance_metrics, :avg_response_time_ms, 5000)
    cost_efficiency = Map.get(performance_metrics, :cost_per_success, 1.0)
    
    # Calculate composite efficiency score
    time_score = max(0, 1 - (avg_response_time / 10000))  # Normalize to 10s max
    cost_score = max(0, 1 - (cost_efficiency / 2.0))     # Normalize to $2 max
    
    # Weighted combination targeting GEPA 35x efficiency
    composite_score = (
      base_efficiency * 0.3 +
      success_rate * 0.3 +
      time_score * 0.2 +
      cost_score * 0.2
    )
    
    # Scale to GEPA efficiency range (target 35x)
    efficiency_multiplier = composite_score * @gepa_efficiency_target
    
    %{
      efficiency_multiplier: efficiency_multiplier,
      component_scores: %{
        base_efficiency: base_efficiency,
        success_rate: success_rate,
        time_score: time_score,
        cost_score: cost_score
      },
      meets_target: efficiency_multiplier >= @gepa_efficiency_target
    }
  end
  
  # Private implementation functions
  
  defp create_optimized_config(family_config, model_version, task_type, efficiency_target, cost_budget) do
    # Create model-specific optimization configuration
    optimization_strategies = Map.get(family_config, :optimization_strategies, [])
    context_limit = Map.get(family_config, :context_window, 4000)
    
    # Select optimization strategy based on task type and model strengths
    selected_strategy = select_optimization_strategy(
      optimization_strategies,
      task_type,
      Map.get(family_config, :strengths, [])
    )
    
    # Create batching configuration optimized for this model
    batching_config = create_batching_config(family_config, efficiency_target)
    
    # Create routing preferences for distributed coordination
    routing_preferences = create_routing_preferences(family_config, task_type)
    
    %OptimizationResult{
      model_config: %ModelConfig{
        family: get_model_family_from_config(family_config),
        version: model_version,
        context_limit: context_limit,
        cost_per_token: Map.get(family_config, :cost_per_1k_tokens, 0.01) / 1000,
        optimization_strategy: selected_strategy,
        batching_config: batching_config,
        routing_preferences: routing_preferences
      },
      optimized_prompts: [],  # Will be populated during actual optimization
      efficiency_score: calculate_target_efficiency(family_config, efficiency_target),
      cost_estimate: calculate_cost_estimate(family_config, cost_budget),
      routing_instructions: create_routing_instructions(family_config),
      batching_recommendations: create_batching_recommendations(family_config),
      fallback_options: create_fallback_options(family_config)
    }
  end
  
  defp select_optimization_strategy(available_strategies, task_type, model_strengths) do
    # Select best optimization strategy based on task-model alignment
    task_strategy_mapping = %{
      environmental_scanning: [:reasoning, :analysis, :structured_output],
      data_processing: [:analysis, :code_generation, :structured_output],
      creative_generation: [:creative_writing, :general_knowledge],
      code_analysis: [:code_generation, :reasoning, :analysis],
      long_context_analysis: [:long_context, :reasoning]
    }
    
    required_capabilities = Map.get(task_strategy_mapping, task_type, [:general_knowledge])
    
    # Find strategies that align with both model strengths and task requirements
    aligned_strategies = Enum.filter(available_strategies, fn strategy ->
      strategy_capabilities = get_strategy_capabilities(strategy)
      capability_overlap = MapSet.intersection(
        MapSet.new(strategy_capabilities),
        MapSet.new(required_capabilities)
      )
      MapSet.size(capability_overlap) > 0
    end)
    
    # Select the first aligned strategy, or fallback to first available
    case aligned_strategies do
      [] -> List.first(available_strategies, :default)
      [strategy | _] -> strategy
    end
  end
  
  defp get_strategy_capabilities(strategy) do
    # Map strategies to their relevant capabilities
    strategy_capabilities = %{
      context_packing: [:analysis, :reasoning],
      tool_use: [:structured_output, :code_generation],
      xml_structured: [:structured_output, :analysis],
      function_calling: [:code_generation, :structured_output],
      system_messages: [:general_knowledge, :reasoning],
      json_mode: [:structured_output, :data_processing],
      massive_context: [:long_context, :analysis],
      multimodal_fusion: [:multimodal, :analysis],
      reasoning_chains: [:reasoning, :analysis]
    }
    
    Map.get(strategy_capabilities, strategy, [])
  end
  
  defp create_batching_config(family_config, efficiency_target) do
    base_efficiency = Map.get(family_config, :batching_efficiency, 0.5)
    context_limit = Map.get(family_config, :context_window, 4000)
    
    # Calculate optimal batch size based on efficiency target
    target_efficiency_ratio = efficiency_target / @gepa_efficiency_target
    optimal_batch_size = round(base_efficiency * target_efficiency_ratio * 10)
    optimal_batch_size = max(1, min(optimal_batch_size, 50))  # Reasonable bounds
    
    %{
      batch_size: optimal_batch_size,
      context_utilization: min(0.9, target_efficiency_ratio),  # Use up to 90% of context
      parallel_batches: calculate_parallel_batches(base_efficiency),
      timeout_ms: calculate_batch_timeout(efficiency_target)
    }
  end
  
  defp create_routing_preferences(family_config, task_type) do
    strengths = Map.get(family_config, :strengths, [])
    cost_per_token = Map.get(family_config, :cost_per_1k_tokens, 0.01)
    
    # Create routing preferences based on model characteristics
    %{
      preferred_for: strengths,
      cost_tier: categorize_cost_tier(cost_per_token),
      priority_tasks: [task_type],
      load_balancing_weight: calculate_load_balancing_weight(family_config),
      geographic_preferences: [],  # Could be extended for geo-distributed deployments
      time_of_day_preferences: []   # Could be extended for cost optimization
    }
  end
  
  defp analyze_model_instances(model_instances) do
    Enum.map(model_instances, fn {instance_id, config} ->
      # Get current performance metrics for this instance
      performance_metrics = get_instance_performance_metrics(instance_id)
      
      # Calculate current efficiency
      efficiency = calculate_efficiency_score(config, performance_metrics)
      
      # Determine current load and availability
      current_load = get_instance_current_load(instance_id)
      
      %{
        instance_id: instance_id,
        config: config,
        performance_metrics: performance_metrics,
        efficiency: efficiency,
        current_load: current_load,
        availability_score: calculate_availability_score(current_load, performance_metrics)
      }
    end)
  end
  
  defp create_distributed_optimization_plan(instance_analysis) do
    # Sort instances by efficiency and availability
    sorted_instances = Enum.sort_by(instance_analysis, fn analysis ->
      efficiency_score = Map.get(analysis.efficiency, :efficiency_multiplier, 0)
      availability_score = analysis.availability_score
      
      # Combined score prioritizing efficiency with availability
      efficiency_score * 0.7 + availability_score * 0.3
    end, :desc)
    
    # Create workload distribution plan
    total_capacity = calculate_total_capacity(sorted_instances)
    
    distribution_plan = Enum.map(sorted_instances, fn analysis ->
      # Calculate this instance's share based on efficiency and capacity
      instance_capacity = calculate_instance_capacity(analysis)
      workload_ratio = instance_capacity / total_capacity
      
      %{
        instance_id: analysis.instance_id,
        workload_ratio: workload_ratio,
        optimization_config: create_instance_optimization_config(analysis),
        coordination_role: determine_coordination_role(analysis, sorted_instances)
      }
    end)
    
    %{
      instances: distribution_plan,
      coordination_strategy: :hierarchical,  # Best instance becomes coordinator
      efficiency_target: @gepa_efficiency_target,
      fallback_plan: create_fallback_distribution_plan(sorted_instances)
    }
  end
  
  defp execute_distributed_coordination(coordination_plan) do
    instances = coordination_plan.instances
    
    # Execute coordination using AMQP CommandRouter
    coordination_tasks = Enum.map(instances, fn instance_plan ->
      Task.async(fn ->
        execute_instance_coordination(instance_plan, coordination_plan)
      end)
    end)
    
    # Wait for all coordination tasks to complete
    results = Task.await_many(coordination_tasks, 30_000)
    
    # Check for any failures
    {successes, failures} = Enum.split_with(results, fn
      {:ok, _} -> true
      {:error, _} -> false
    end)
    
    if Enum.empty?(failures) do
      success_results = Enum.map(successes, &elem(&1, 1))
      {:ok, success_results}
    else
      Logger.warning("Distributed coordination had failures: #{inspect(failures)}")
      {:partial_success, %{successes: successes, failures: failures}}
    end
  end
  
  defp execute_instance_coordination(instance_plan, coordination_plan) do
    # Send coordination instructions to specific instance via AMQP
    coordination_command = %{
      type: "model_optimization_coordination",
      instance_id: instance_plan.instance_id,
      workload_ratio: instance_plan.workload_ratio,
      optimization_config: instance_plan.optimization_config,
      coordination_role: instance_plan.coordination_role,
      efficiency_target: coordination_plan.efficiency_target
    }
    
    # Route command to appropriate system
    target_system = determine_target_system(instance_plan.instance_id)
    
    case CommandRouter.send_command(target_system, coordination_command, 10_000) do
      {:ok, result} ->
        Logger.info("Coordination successful for instance: #{instance_plan.instance_id}")
        {:ok, %{instance_id: instance_plan.instance_id, result: result}}
        
      {:error, reason} ->
        Logger.error("Coordination failed for instance #{instance_plan.instance_id}: #{inspect(reason)}")
        {:error, %{instance_id: instance_plan.instance_id, reason: reason}}
    end
  end
  
  defp aggregate_distributed_results(results) do
    # Aggregate results from all distributed instances
    successful_instances = Enum.filter(results, &match?(%{result: _}, &1))
    
    total_efficiency = Enum.reduce(successful_instances, 0, fn instance_result, acc ->
      efficiency = get_in(instance_result, [:result, :efficiency_score]) || 0
      acc + efficiency
    end)
    
    average_efficiency = if length(successful_instances) > 0 do
      total_efficiency / length(successful_instances)
    else
      0
    end
    
    %{
      coordination_status: :completed,
      participating_instances: length(successful_instances),
      average_efficiency: average_efficiency,
      meets_gepa_target: average_efficiency >= @gepa_efficiency_target,
      individual_results: results,
      aggregated_metrics: %{
        total_efficiency: total_efficiency,
        efficiency_distribution: calculate_efficiency_distribution(results),
        performance_variance: calculate_performance_variance(results)
      }
    }
  end
  
  defp create_model_specific_batches(prompts, family_config, efficiency_target) do
    context_limit = Map.get(family_config, :context_window, 4000)
    batching_efficiency = Map.get(family_config, :batching_efficiency, 0.5)
    
    # Calculate optimal batch size for this model family
    target_efficiency_ratio = efficiency_target / @gepa_efficiency_target
    optimal_tokens_per_batch = round(context_limit * batching_efficiency * target_efficiency_ratio)
    
    # Group prompts into optimized batches
    batches = batch_prompts_by_token_limit(prompts, optimal_tokens_per_batch)
    
    # Apply model-specific optimizations to each batch
    optimized_batches = Enum.map(batches, fn batch ->
      optimize_batch_for_model_family(batch, family_config)
    end)
    
    optimized_batches
  end
  
  defp batch_prompts_by_token_limit(prompts, token_limit) do
    # Simple batching by estimated token count
    {batches, current_batch, current_tokens} = Enum.reduce(prompts, {[], [], 0}, fn prompt, {batches, current_batch, current_tokens} ->
      prompt_tokens = estimate_prompt_tokens(prompt)
      
      if current_tokens + prompt_tokens > token_limit and not Enum.empty?(current_batch) do
        # Start new batch
        {[current_batch | batches], [prompt], prompt_tokens}
      else
        # Add to current batch
        {batches, [prompt | current_batch], current_tokens + prompt_tokens}
      end
    end)
    
    # Add final batch if not empty
    final_batches = if Enum.empty?(current_batch) do
      batches
    else
      [current_batch | batches]
    end
    
    Enum.map(final_batches, &Enum.reverse/1)  # Reverse to maintain order
  end
  
  defp optimize_batch_for_model_family(batch, family_config) do
    optimization_strategies = Map.get(family_config, :optimization_strategies, [])
    preferred_style = Map.get(family_config, :preferred_prompt_style, :conversational_structured)
    
    # Apply model-specific optimizations
    optimized_prompts = Enum.map(batch, fn prompt ->
      apply_model_specific_optimizations(prompt, optimization_strategies, preferred_style)
    end)
    
    %{
      prompts: optimized_prompts,
      batch_size: length(optimized_prompts),
      estimated_tokens: Enum.sum(Enum.map(optimized_prompts, &estimate_prompt_tokens/1)),
      optimization_applied: optimization_strategies,
      style: preferred_style
    }
  end
  
  defp apply_model_specific_optimizations(prompt, strategies, style) do
    # Apply optimizations based on model family capabilities
    optimized = Enum.reduce(strategies, prompt, fn strategy, acc ->
      apply_optimization_strategy(acc, strategy)
    end)
    
    # Apply style formatting
    format_prompt_for_style(optimized, style)
  end
  
  defp apply_optimization_strategy(prompt, strategy) do
    case strategy do
      :context_packing ->
        # Pack more context efficiently for Claude-style models
        add_context_structure(prompt)
        
      :xml_structured ->
        # Use XML structure for Claude models
        wrap_in_xml_structure(prompt)
        
      :function_calling ->
        # Optimize for function calling models (GPT)
        add_function_call_structure(prompt)
        
      :json_mode ->
        # Structure for JSON output models
        add_json_output_structure(prompt)
        
      :massive_context ->
        # Optimize for very large context windows (Gemini)
        expand_context_for_large_window(prompt)
        
      :reasoning_chains ->
        # Add step-by-step reasoning structure
        add_reasoning_chain_structure(prompt)
        
      _ ->
        prompt  # No optimization for unknown strategies
    end
  end
  
  # Model-specific prompt formatting functions
  
  defp add_context_structure(prompt) do
    # Add structured context for better comprehension
    """
    <context>
    #{Map.get(prompt, :context, "")}
    </context>
    
    <task>
    #{Map.get(prompt, :task, prompt)}
    </task>
    
    <requirements>
    - Be precise and accurate
    - Provide structured output
    - Consider all context information
    </requirements>
    """
  end
  
  defp wrap_in_xml_structure(prompt) do
    # Claude models perform well with XML structure
    """
    <analysis_request>
    #{prompt}
    </analysis_request>
    
    <instructions>
    Please analyze the above request and provide a structured response using appropriate XML tags to organize your analysis.
    </instructions>
    """
  end
  
  defp add_function_call_structure(prompt) do
    # Add function calling context for GPT models
    case prompt do
      %{function_context: context} ->
        Map.put(prompt, :system, "You are an AI assistant with access to specific functions. #{context}")
      _ ->
        prompt
    end
  end
  
  defp add_json_output_structure(prompt) do
    # Structure prompt for JSON output
    """
    #{prompt}
    
    Please provide your response in the following JSON format:
    {
      "analysis": "your analysis here",
      "recommendations": ["rec1", "rec2"],
      "confidence": 0.95
    }
    """
  end
  
  defp expand_context_for_large_window(prompt) do
    # Take advantage of large context windows by adding more detail
    expanded_context = Map.get(prompt, :context, "")
    
    """
    #{prompt}
    
    Additional context for comprehensive analysis:
    #{expanded_context}
    
    Please provide a thorough, detailed analysis taking advantage of the full context provided.
    """
  end
  
  defp add_reasoning_chain_structure(prompt) do
    # Add step-by-step reasoning structure
    """
    #{prompt}
    
    Please approach this systematically:
    1. First, identify the key components of the problem
    2. Then, analyze each component in detail  
    3. Consider the relationships between components
    4. Finally, synthesize your findings into actionable insights
    
    Use clear reasoning at each step.
    """
  end
  
  defp format_prompt_for_style(prompt, style) do
    case style do
      :conversational_structured ->
        # Claude-style conversational but structured
        if is_binary(prompt) do
          prompt
        else
          Jason.encode!(prompt, pretty: true)
        end
        
      :system_user_format ->
        # GPT-style system/user format
        %{
          system: "You are a helpful AI assistant specialized in analysis and problem-solving.",
          user: to_string(prompt)
        }
        
      :long_form_detailed ->
        # Gemini-style detailed format
        """
        Please provide a comprehensive analysis of the following:
        
        #{to_string(prompt)}
        
        Include detailed reasoning, multiple perspectives, and thorough exploration of implications.
        """
        
      _ ->
        prompt
    end
  end
  
  # Utility and helper functions
  
  defp calculate_model_task_compatibility(model, task_requirements) do
    model_family_config = Map.get(@model_families, model.family, %{})
    model_strengths = Map.get(model_family_config, :strengths, [])
    
    required_capabilities = Map.get(task_requirements, :required_capabilities, [])
    preferred_capabilities = Map.get(task_requirements, :preferred_capabilities, [])
    
    # Score based on capability alignment
    required_matches = Enum.count(required_capabilities, &(&1 in model_strengths))
    preferred_matches = Enum.count(preferred_capabilities, &(&1 in model_strengths))
    
    required_score = if Enum.empty?(required_capabilities) do
      0.5
    else
      required_matches / length(required_capabilities)
    end
    
    preferred_score = if Enum.empty?(preferred_capabilities) do
      0.5
    else
      preferred_matches / length(preferred_capabilities)
    end
    
    # Weight required capabilities more heavily
    overall_score = required_score * 0.7 + preferred_score * 0.3
    
    # Apply cost and efficiency adjustments
    cost_efficiency = Map.get(model_family_config, :cost_per_1k_tokens, 0.01)
    batching_efficiency = Map.get(model_family_config, :batching_efficiency, 0.5)
    
    # Normalize cost (lower cost = higher score)
    cost_score = max(0, 1 - (cost_efficiency / 0.02))  # $0.02 as high cost threshold
    
    # Final score combines capability, cost, and efficiency
    final_score = overall_score * 0.6 + cost_score * 0.2 + batching_efficiency * 0.2
    
    final_score
  end
  
  defp estimate_prompt_tokens(prompt) do
    # Simple token estimation
    prompt_text = case prompt do
      %{} -> Jason.encode!(prompt)
      text when is_binary(text) -> text
      _ -> to_string(prompt)
    end
    
    # Rough approximation: 4 characters per token
    round(String.length(prompt_text) / 4)
  end
  
  defp get_model_family_from_config(family_config) do
    # Determine family from config characteristics
    context_window = Map.get(family_config, :context_window, 0)
    
    cond do
      context_window >= 1_000_000 -> :gemini
      context_window >= 200_000 -> :claude
      context_window >= 100_000 -> :gpt
      true -> :unknown
    end
  end
  
  defp calculate_target_efficiency(family_config, efficiency_target) do
    base_efficiency = Map.get(family_config, :batching_efficiency, 0.5)
    
    # Calculate how much improvement is needed to reach target
    improvement_ratio = efficiency_target / @gepa_efficiency_target
    target_score = base_efficiency * improvement_ratio
    
    min(target_score, 1.0)  # Cap at 100% efficiency
  end
  
  defp calculate_cost_estimate(family_config, cost_budget) do
    cost_per_1k_tokens = Map.get(family_config, :cost_per_1k_tokens, 0.01)
    
    if cost_budget do
      estimated_tokens = (cost_budget / cost_per_1k_tokens) * 1000
      %{
        budget: cost_budget,
        estimated_tokens: round(estimated_tokens),
        cost_per_token: cost_per_1k_tokens / 1000
      }
    else
      %{
        cost_per_token: cost_per_1k_tokens / 1000,
        budget: nil,
        estimated_tokens: nil
      }
    end
  end
  
  defp create_routing_instructions(family_config) do
    strengths = Map.get(family_config, :strengths, [])
    
    %{
      preferred_task_types: map_strengths_to_task_types(strengths),
      avoid_for: [],  # Could be populated with unsuitable task types
      load_balancing_factor: Map.get(family_config, :batching_efficiency, 0.5),
      timeout_recommendations: %{
        simple_tasks: 5000,
        complex_tasks: 15000,
        batch_processing: 30000
      }
    }
  end
  
  defp create_batching_recommendations(family_config) do
    context_window = Map.get(family_config, :context_window, 4000)
    batching_efficiency = Map.get(family_config, :batching_efficiency, 0.5)
    
    %{
      optimal_batch_size: round(batching_efficiency * 10),
      max_tokens_per_batch: round(context_window * 0.8),  # Use 80% of context window
      parallel_batches: calculate_parallel_batches(batching_efficiency),
      batching_strategy: determine_batching_strategy(family_config)
    }
  end
  
  defp create_fallback_options(family_config) do
    # Create fallback options for when primary optimization fails
    primary_strategies = Map.get(family_config, :optimization_strategies, [])
    
    fallback_strategies = case primary_strategies do
      [] -> [:default]
      strategies -> strategies ++ [:default]
    end
    
    %{
      fallback_strategies: fallback_strategies,
      degraded_performance_threshold: 0.3,  # 30% efficiency minimum
      fallback_models: suggest_fallback_models(family_config),
      emergency_options: [:reduce_batch_size, :increase_timeout, :split_workload]
    }
  end
  
  defp map_strengths_to_task_types(strengths) do
    # Map model strengths to suitable task types
    task_mapping = %{
      reasoning: [:analysis, :problem_solving, :decision_making],
      analysis: [:data_analysis, :environmental_scanning, :performance_analysis],
      code_generation: [:code_analysis, :software_development, :automation],
      creative_writing: [:content_generation, :creative_tasks],
      long_context: [:document_analysis, :research_synthesis],
      multimodal: [:image_analysis, :multimedia_processing]
    }
    
    Enum.flat_map(strengths, fn strength ->
      Map.get(task_mapping, strength, [])
    end)
    |> Enum.uniq()
  end
  
  defp calculate_parallel_batches(batching_efficiency) do
    # Calculate optimal number of parallel batches
    base_parallel = round(batching_efficiency * 5)
    max(1, min(base_parallel, 10))  # Between 1 and 10 parallel batches
  end
  
  defp calculate_batch_timeout(efficiency_target) do
    # Calculate timeout based on efficiency target
    base_timeout = 5000  # 5 seconds base
    efficiency_ratio = efficiency_target / @gepa_efficiency_target
    
    # Higher efficiency targets get longer timeouts for better results
    timeout = round(base_timeout * (1 + efficiency_ratio))
    min(timeout, 30_000)  # Cap at 30 seconds
  end
  
  defp categorize_cost_tier(cost_per_1k_tokens) do
    cond do
      cost_per_1k_tokens <= 0.005 -> :low_cost
      cost_per_1k_tokens <= 0.015 -> :medium_cost
      true -> :high_cost
    end
  end
  
  defp calculate_load_balancing_weight(family_config) do
    batching_efficiency = Map.get(family_config, :batching_efficiency, 0.5)
    context_window = Map.get(family_config, :context_window, 4000)
    
    # Higher capacity models get higher weight
    capacity_factor = context_window / 100_000  # Normalize to 100k tokens
    weight = batching_efficiency * capacity_factor
    
    min(weight, 1.0)  # Cap at 1.0
  end
  
  defp determine_batching_strategy(family_config) do
    context_window = Map.get(family_config, :context_window, 4000)
    strengths = Map.get(family_config, :strengths, [])
    
    cond do
      context_window >= 1_000_000 -> :massive_context_batching
      :long_context in strengths -> :sequential_context_batching
      :reasoning in strengths -> :logical_grouping_batching
      true -> :size_based_batching
    end
  end
  
  defp suggest_fallback_models(family_config) do
    # Suggest alternative model families as fallbacks
    current_strengths = Map.get(family_config, :strengths, [])
    
    # Find other model families with overlapping strengths
    fallback_families = @model_families
    |> Enum.filter(fn {_family, config} ->
      other_strengths = Map.get(config, :strengths, [])
      overlap = MapSet.intersection(MapSet.new(current_strengths), MapSet.new(other_strengths))
      MapSet.size(overlap) > 0
    end)
    |> Enum.map(&elem(&1, 0))
    
    fallback_families
  end
  
  # Performance metrics and monitoring functions
  
  defp get_instance_performance_metrics(instance_id) do
    # Get real performance metrics for the instance
    # In a real implementation, this would query monitoring systems
    %{
      success_rate: 0.85 + :rand.uniform() * 0.1,  # 85-95%
      avg_response_time_ms: 1000 + :rand.uniform(2000),  # 1-3 seconds
      cost_per_success: 0.01 + :rand.uniform() * 0.02,  # $0.01-0.03
      total_requests: :rand.uniform(10000),
      error_rate: 0.02 + :rand.uniform() * 0.03  # 2-5%
    }
  end
  
  defp get_instance_current_load(instance_id) do
    # Get current load for the instance
    # In a real implementation, this would query the actual instance
    %{
      cpu_usage: 0.3 + :rand.uniform() * 0.4,  # 30-70%
      memory_usage: 0.4 + :rand.uniform() * 0.3,  # 40-70%
      active_requests: :rand.uniform(100),
      queue_depth: :rand.uniform(50)
    }
  end
  
  defp calculate_availability_score(current_load, performance_metrics) do
    cpu_score = max(0, 1 - Map.get(current_load, :cpu_usage, 0.5))
    memory_score = max(0, 1 - Map.get(current_load, :memory_usage, 0.5))
    error_rate = Map.get(performance_metrics, :error_rate, 0.05)
    error_score = max(0, 1 - error_rate * 10)  # Scale error rate
    
    # Weighted availability score
    (cpu_score * 0.4 + memory_score * 0.3 + error_score * 0.3)
  end
  
  defp calculate_total_capacity(instances) do
    Enum.reduce(instances, 0, fn analysis, acc ->
      acc + calculate_instance_capacity(analysis)
    end)
  end
  
  defp calculate_instance_capacity(analysis) do
    efficiency = Map.get(analysis.efficiency, :efficiency_multiplier, 1.0)
    availability = analysis.availability_score
    
    # Capacity is a function of efficiency and availability
    base_capacity = 1.0  # Baseline capacity
    effective_capacity = base_capacity * efficiency * availability
    
    max(0.1, effective_capacity)  # Minimum 10% capacity
  end
  
  defp create_instance_optimization_config(analysis) do
    # Create optimization configuration specific to this instance
    %{
      efficiency_target: calculate_instance_efficiency_target(analysis),
      batching_config: create_instance_batching_config(analysis),
      resource_limits: create_resource_limits(analysis),
      monitoring_config: create_monitoring_config(analysis)
    }
  end
  
  defp determine_coordination_role(analysis, all_instances) do
    # Determine role based on performance and position in sorted list
    efficiency = Map.get(analysis.efficiency, :efficiency_multiplier, 0)
    position = Enum.find_index(all_instances, &(&1.instance_id == analysis.instance_id))
    
    cond do
      position == 0 -> :coordinator  # Best performing instance coordinates
      efficiency > @gepa_efficiency_target * 0.8 -> :primary_worker
      efficiency > @gepa_efficiency_target * 0.5 -> :secondary_worker
      true -> :fallback_worker
    end
  end
  
  defp create_fallback_distribution_plan(instances) do
    # Create a simpler fallback plan in case primary plan fails
    %{
      strategy: :round_robin,
      instances: Enum.map(instances, &(&1.instance_id)),
      fallback_threshold: 0.3,  # Switch to fallback if efficiency drops below 30%
      recovery_strategy: :gradual_restoration
    }
  end
  
  defp determine_target_system(instance_id) do
    # Determine which VSM system handles this instance
    # This is a simplified mapping - in reality would be more sophisticated
    cond do
      String.contains?(instance_id, "system1") -> :system1
      String.contains?(instance_id, "system4") -> :system4
      true -> :system1  # Default to system1
    end
  end
  
  defp calculate_efficiency_distribution(results) do
    efficiencies = Enum.map(results, fn result ->
      get_in(result, [:result, :efficiency_score]) || 0
    end)
    
    if Enum.empty?(efficiencies) do
      %{min: 0, max: 0, avg: 0, std_dev: 0}
    else
      avg = Enum.sum(efficiencies) / length(efficiencies)
      variance = Enum.reduce(efficiencies, 0, fn eff, acc ->
        acc + :math.pow(eff - avg, 2)
      end) / length(efficiencies)
      
      %{
        min: Enum.min(efficiencies),
        max: Enum.max(efficiencies),
        avg: avg,
        std_dev: :math.sqrt(variance)
      }
    end
  end
  
  defp calculate_performance_variance(results) do
    # Calculate variance in performance metrics
    response_times = Enum.map(results, fn result ->
      get_in(result, [:result, :performance_metrics, :avg_response_time_ms]) || 1000
    end)
    
    if Enum.empty?(response_times) do
      0
    else
      avg_time = Enum.sum(response_times) / length(response_times)
      variance = Enum.reduce(response_times, 0, fn time, acc ->
        acc + :math.pow(time - avg_time, 2)
      end) / length(response_times)
      
      :math.sqrt(variance)
    end
  end
  
  # Additional helper functions for instance-specific configurations
  
  defp calculate_instance_efficiency_target(analysis) do
    base_efficiency = Map.get(analysis.efficiency, :efficiency_multiplier, 1.0)
    
    # Set target slightly higher than current performance to encourage improvement
    target = base_efficiency * 1.1
    min(target, @gepa_efficiency_target)  # Don't exceed global target
  end
  
  defp create_instance_batching_config(analysis) do
    current_load = analysis.current_load
    cpu_usage = Map.get(current_load, :cpu_usage, 0.5)
    memory_usage = Map.get(current_load, :memory_usage, 0.5)
    
    # Adjust batching based on current resource usage
    load_factor = (cpu_usage + memory_usage) / 2
    batch_size_adjustment = max(0.5, 1 - load_factor)
    
    %{
      batch_size_multiplier: batch_size_adjustment,
      timeout_adjustment: if(load_factor > 0.7, do: 1.5, else: 1.0),
      parallel_batch_limit: if(load_factor > 0.8, do: 2, else: 5)
    }
  end
  
  defp create_resource_limits(analysis) do
    current_load = analysis.current_load
    
    %{
      max_cpu_usage: 0.8,  # Don't exceed 80% CPU
      max_memory_usage: 0.8,  # Don't exceed 80% memory
      max_concurrent_requests: calculate_max_concurrent(current_load),
      timeout_ms: 30_000
    }
  end
  
  defp create_monitoring_config(analysis) do
    %{
      metrics_collection_interval: 5000,  # 5 seconds
      performance_alert_threshold: 0.3,   # Alert if efficiency drops below 30%
      resource_alert_threshold: 0.9,      # Alert if resources exceed 90%
      enable_detailed_logging: Map.get(analysis.efficiency, :efficiency_multiplier, 0) < 0.5
    }
  end
  
  defp calculate_max_concurrent(current_load) do
    cpu_usage = Map.get(current_load, :cpu_usage, 0.5)
    memory_usage = Map.get(current_load, :memory_usage, 0.5)
    
    # Calculate max concurrent based on available resources
    avg_usage = (cpu_usage + memory_usage) / 2
    available_capacity = 1 - avg_usage
    
    # Estimate max concurrent requests
    base_concurrent = 10
    max_concurrent = round(base_concurrent * available_capacity * 2)
    
    max(1, max_concurrent)  # At least 1 concurrent request
  end
end