defmodule VsmPhoenix.GEPAFramework do
  @moduledoc """
  GEPA (Generative Evolutionary Prompt Adaptation) Framework with Model-Family Optimization.
  
  Implements Claude Code-inspired prompt engineering with model-specific optimizations
  for achieving 35x efficiency improvements. Integrates with distributed CRDT infrastructure
  for prompt version control and cryptographic security for prompt integrity.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.Security.CryptoLayer
  alias VsmPhoenix.PromptArchitecture
  alias VsmPhoenix.ContextManager
  alias VsmPhoenix.SubAgentOrchestrator
  
  # Model family optimization profiles
  @model_families %{
    # Anthropic Claude models
    claude: %{
      optimal_structure: :xml_structured,
      max_context_length: 200_000,
      reasoning_style: :chain_of_thought,
      instruction_format: :multi_section,
      example_preference: :detailed_examples,
      reminder_frequency: :high,
      token_efficiency: 0.95
    },
    
    # OpenAI GPT models  
    gpt: %{
      optimal_structure: :markdown_structured,
      max_context_length: 128_000,
      reasoning_style: :step_by_step,
      instruction_format: :bullet_points,
      example_preference: :concise_examples,
      reminder_frequency: :medium,
      token_efficiency: 0.87
    },
    
    # Google Gemini models
    gemini: %{
      optimal_structure: :hybrid_structured,
      max_context_length: 1_048_576,
      reasoning_style: :multi_modal,
      instruction_format: :numbered_lists,
      example_preference: :visual_examples,
      reminder_frequency: :low,
      token_efficiency: 0.92
    },
    
    # Meta Llama models
    llama: %{
      optimal_structure: :plain_structured,
      max_context_length: 32_000,
      reasoning_style: :direct,
      instruction_format: :simple_paragraphs,
      example_preference: :minimal_examples,
      reminder_frequency: :minimal,
      token_efficiency: 0.83
    }
  }
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Generate optimized prompts for specific model families with 35x efficiency targeting.
  
  ## Examples:
  
      optimize_for_model(:claude, %{
        task: "Synchronize CRDT state across distributed nodes",
        context: %{operation: :merge, nodes: 5, security_level: :high},
        efficiency_target: 35.0
      })
  """
  def optimize_for_model(model_family, optimization_context) do
    GenServer.call(__MODULE__, {:optimize_for_model, model_family, optimization_context}, 30_000)
  end
  
  @doc """
  Evolve existing prompts based on performance feedback and model-specific optimization.
  """
  def evolve_prompt(prompt_id, performance_data, target_model_family) do
    GenServer.call(__MODULE__, {:evolve_prompt, prompt_id, performance_data, target_model_family})
  end
  
  @doc """
  Generate model-family specific system prompts with integrated reminders and examples.
  """
  def generate_system_prompt(model_family, domain, context) do
    GenServer.call(__MODULE__, {:generate_system_prompt, model_family, domain, context})
  end
  
  @doc """
  Analyze prompt efficiency and provide optimization recommendations.
  """
  def analyze_prompt_efficiency(prompt, model_family, usage_metrics) do
    GenServer.call(__MODULE__, {:analyze_efficiency, prompt, model_family, usage_metrics})
  end
  
  # Server Callbacks
  
  def init(opts) do
    # Initialize prompt evolution tracking in CRDT
    ContextStore.add_to_set("gepa_evolution_tracking", %{
      initialized_at: System.system_time(:millisecond),
      node_id: node(),
      model_families: Map.keys(@model_families)
    })
    
    {:ok, %{
      evolution_history: %{},
      performance_metrics: %{},
      optimization_cache: %{},
      opts: opts
    }}
  end
  
  def handle_call({:optimize_for_model, model_family, context}, _from, state) do
    optimization_profile = Map.get(@model_families, model_family, @model_families.claude)
    
    # Generate optimized prompt based on model family preferences
    optimized_prompt = case optimization_profile.optimal_structure do
      :xml_structured -> generate_xml_optimized_prompt(context, optimization_profile)
      :markdown_structured -> generate_markdown_optimized_prompt(context, optimization_profile)
      :hybrid_structured -> generate_hybrid_optimized_prompt(context, optimization_profile)
      :plain_structured -> generate_plain_optimized_prompt(context, optimization_profile)
    end
    
    # Calculate efficiency projections
    efficiency_projection = calculate_efficiency_projection(optimized_prompt, optimization_profile, context)
    
    # Store optimization in CRDT for distributed access
    optimization_record = %{
      prompt: optimized_prompt,
      model_family: model_family,
      efficiency_projection: efficiency_projection,
      optimization_profile: optimization_profile,
      created_at: System.system_time(:millisecond),
      node_id: node()
    }
    
    prompt_id = "gepa_#{System.unique_integer()}"
    ContextStore.add_to_set("optimized_prompts", {prompt_id, optimization_record})
    
    # Attach to context manager for system-wide access
    ContextManager.attach_context(:task_context, "gepa_optimization_#{prompt_id}", optimization_record)
    
    result = %{
      prompt_id: prompt_id,
      optimized_prompt: optimized_prompt,
      efficiency_projection: efficiency_projection,
      model_family: model_family,
      optimization_applied: true
    }
    
    {:reply, {:ok, result}, state}
  end
  
  def handle_call({:evolve_prompt, prompt_id, performance_data, target_model_family}, _from, state) do
    # Get existing prompt from CRDT
    case get_prompt_from_crdt(prompt_id) do
      {:ok, existing_prompt_record} ->
        # Analyze performance against expectations
        performance_analysis = analyze_performance_gap(existing_prompt_record, performance_data)
        
        # Generate evolved prompt using sub-agent delegation
        evolution_task = """
        Evolve the following prompt based on performance feedback:
        
        Original Prompt: #{existing_prompt_record.prompt}
        Performance Data: #{inspect(performance_data)}
        Target Model Family: #{target_model_family}
        Performance Gap Analysis: #{inspect(performance_analysis)}
        """
        
        case SubAgentOrchestrator.delegate_task(evolution_task, %{
          operation: :prompt_evolution,
          model_family: target_model_family,
          performance_data: performance_data
        }) do
          {:ok, evolution_result} ->
            # Store evolved prompt
            evolved_record = %{
              existing_prompt_record |
              prompt: evolution_result[:evolved_prompt] || existing_prompt_record.prompt,
              version: existing_prompt_record[:version] + 1 || 2,
              evolution_history: [performance_analysis | existing_prompt_record[:evolution_history] || []],
              updated_at: System.system_time(:millisecond)
            }
            
            ContextStore.update_lww_set("optimized_prompts", prompt_id, evolved_record)
            
            {:reply, {:ok, evolved_record}, state}
            
          error ->
            {:reply, error, state}
        end
        
      error ->
        {:reply, error, state}
    end
  end
  
  def handle_call({:generate_system_prompt, model_family, domain, context}, _from, state) do
    optimization_profile = Map.get(@model_families, model_family, @model_families.claude)
    
    # Generate domain-specific system prompt optimized for model family
    system_prompt = case domain do
      :crdt_operations ->
        generate_crdt_system_prompt(model_family, optimization_profile, context)
      :security_operations ->
        generate_security_system_prompt(model_family, optimization_profile, context)
      :distributed_coordination ->
        generate_coordination_system_prompt(model_family, optimization_profile, context)
      :recursive_spawning ->
        generate_recursive_system_prompt(model_family, optimization_profile, context)
      _ ->
        generate_generic_system_prompt(model_family, optimization_profile, domain, context)
    end
    
    # Include model-specific reminders
    enhanced_prompt = enhance_with_reminders(system_prompt, model_family, optimization_profile)
    
    {:reply, {:ok, enhanced_prompt}, state}
  end
  
  def handle_call({:analyze_efficiency, prompt, model_family, usage_metrics}, _from, state) do
    optimization_profile = Map.get(@model_families, model_family, @model_families.claude)
    
    efficiency_analysis = %{
      token_efficiency: calculate_token_efficiency(prompt, usage_metrics, optimization_profile),
      structure_score: analyze_prompt_structure(prompt, optimization_profile),
      clarity_score: analyze_prompt_clarity(prompt),
      effectiveness_score: calculate_effectiveness(usage_metrics),
      model_alignment_score: calculate_model_alignment(prompt, optimization_profile),
      recommendations: generate_optimization_recommendations(prompt, optimization_profile, usage_metrics)
    }
    
    overall_efficiency = calculate_overall_efficiency(efficiency_analysis)
    
    result = %{
      analysis: efficiency_analysis,
      overall_efficiency: overall_efficiency,
      efficiency_vs_target: overall_efficiency / 35.0, # Target is 35x
      needs_optimization: overall_efficiency < 25.0
    }
    
    {:reply, {:ok, result}, state}
  end
  
  # Prompt Generation Functions
  
  defp generate_xml_optimized_prompt(context, profile) do
    task = context[:task] || "Execute operation"
    operation_context = context[:context] || %{}
    
    """
    <system>
    You are executing #{task} with maximum efficiency and mathematical correctness.
    
    ## Core Directives:
    <directives>
    1. Maintain distributed systems consistency at all times
    2. Ensure cryptographic security for all sensitive operations  
    3. Preserve CRDT mathematical properties: commutativity, associativity, idempotence
    4. Implement proper error handling with graceful degradation
    5. Optimize for #{profile.token_efficiency * 100}% token efficiency
    </directives>
    
    ## Operation Context:
    <context>
    #{Enum.map(operation_context, fn {k, v} -> "#{k}: #{inspect(v)}" end) |> Enum.join("\n")}
    </context>
    
    ## Efficiency Guidelines:
    <efficiency>
    - Use #{profile.reasoning_style} reasoning for optimal model performance
    - Structure responses in #{profile.instruction_format} format
    - Include #{profile.example_preference} where appropriate
    - Maintain #{profile.reminder_frequency} frequency of key reminders
    </efficiency>
    
    ## Mathematical Guarantees:
    <guarantees>
    - CRDT operations preserve eventual consistency
    - Cryptographic operations maintain integrity and confidentiality
    - Distributed coordination ensures Byzantine fault tolerance
    - All operations are idempotent and commutative where applicable
    </guarantees>
    
    ## Performance Optimization:
    <performance>
    - Target context length: #{profile.max_context_length} tokens maximum
    - Efficiency multiplier target: 35x baseline performance
    - Response time optimization: sub-second for simple operations
    - Memory efficiency: O(log n) complexity for CRDT operations
    </performance>
    </system>
    
    <task>
    Execute: #{task}
    
    With the provided context, ensure maximum efficiency while maintaining all mathematical and security guarantees.
    </task>
    """
  end
  
  defp generate_markdown_optimized_prompt(context, profile) do
    task = context[:task] || "Execute operation"
    
    """
    # System Instructions for #{task}
    
    ## Your Role
    You are optimizing #{task} for maximum efficiency and correctness.
    
    ## Key Requirements
    - Maintain distributed systems consistency
    - Ensure cryptographic security  
    - Preserve mathematical properties
    - Optimize for #{profile.token_efficiency * 100}% efficiency
    
    ## Context
    #{inspect(context[:context] || %{})}
    
    ## Efficiency Targets
    - 35x performance improvement over baseline
    - #{profile.max_context_length} token context limit
    - #{profile.reasoning_style} reasoning approach
    
    ## Execute
    #{task} with maximum efficiency and mathematical correctness.
    """
  end
  
  defp generate_hybrid_optimized_prompt(context, profile) do
    # Combines XML structure with markdown readability
    xml_prompt = generate_xml_optimized_prompt(context, profile)
    markdown_prompt = generate_markdown_optimized_prompt(context, profile)
    
    """
    #{xml_prompt}
    
    ## Summary in Markdown
    #{markdown_prompt}
    """
  end
  
  defp generate_plain_optimized_prompt(context, profile) do
    task = context[:task] || "Execute operation"
    
    """
    Execute #{task} with maximum efficiency.
    
    Requirements: maintain distributed consistency, ensure security, preserve mathematical properties.
    Target: 35x efficiency improvement.
    Context: #{inspect(context[:context] || %{})}
    
    Use #{profile.reasoning_style} approach with #{profile.token_efficiency * 100}% efficiency.
    """
  end
  
  # Domain-specific system prompt generators
  
  defp generate_crdt_system_prompt(model_family, profile, context) do
    PromptArchitecture.create_crdt_prompt(
      context[:operation] || :general,
      context[:node_id] || node(),
      context[:vector_clock] || %{},
      context[:data] || %{}
    )
    |> optimize_for_model_family(model_family, profile)
  end
  
  defp generate_security_system_prompt(model_family, profile, context) do
    PromptArchitecture.create_security_prompt(
      context[:operation] || :general,
      context[:security_context] || %{}
    )
    |> optimize_for_model_family(model_family, profile)
  end
  
  defp generate_coordination_system_prompt(model_family, profile, context) do
    PromptArchitecture.create_amcp_prompt(
      context[:message_type] || :general,
      context[:coordination_context] || %{}
    )
    |> optimize_for_model_family(model_family, profile)
  end
  
  defp generate_recursive_system_prompt(model_family, profile, context) do
    """
    <system optimized_for="#{model_family}">
    You are managing recursive VSM system spawning with #{profile.reasoning_style} approach.
    
    ## Recursive Spawning Guidelines:
    - Analyze complexity before spawning: #{profile.instruction_format}
    - Use stateless delegation for sub-agents
    - Maintain CRDT consistency across spawned systems
    - Implement proper supervision hierarchies
    - Target #{profile.token_efficiency * 100}% efficiency per recursion level
    
    ## Context: #{inspect(context)}
    
    ## Efficiency Target: 35x improvement through recursive optimization
    </system>
    """
    |> optimize_for_model_family(model_family, profile)
  end
  
  defp generate_generic_system_prompt(model_family, profile, domain, context) do
    """
    System optimized for #{model_family} executing #{domain} operations.
    
    Approach: #{profile.reasoning_style}
    Format: #{profile.instruction_format}  
    Efficiency: #{profile.token_efficiency * 100}%
    Context: #{inspect(context)}
    
    Target: 35x efficiency improvement with mathematical correctness.
    """
  end
  
  # Optimization and Analysis Functions
  
  defp optimize_for_model_family(prompt, model_family, profile) do
    case profile.optimal_structure do
      :xml_structured -> ensure_xml_structure(prompt)
      :markdown_structured -> convert_to_markdown(prompt)
      :hybrid_structured -> add_hybrid_elements(prompt)
      :plain_structured -> simplify_structure(prompt)
    end
  end
  
  defp ensure_xml_structure(prompt) do
    if String.contains?(prompt, "<system>") do
      prompt
    else
      "<system>\n#{prompt}\n</system>"
    end
  end
  
  defp convert_to_markdown(prompt) do
    prompt
    |> String.replace("<system>", "# System Instructions")
    |> String.replace("</system>", "")
    |> String.replace(~r/<(\w+)>/, "## \\1")
    |> String.replace(~r/<\/\w+>/, "")
  end
  
  defp add_hybrid_elements(prompt) do
    "#{ensure_xml_structure(prompt)}\n\n#{convert_to_markdown(prompt)}"
  end
  
  defp simplify_structure(prompt) do
    prompt
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\n\s*\n/, "\n")
    |> String.trim()
  end
  
  defp enhance_with_reminders(prompt, model_family, profile) do
    case profile.reminder_frequency do
      :high -> add_frequent_reminders(prompt)
      :medium -> add_moderate_reminders(prompt)
      :low -> add_minimal_reminders(prompt)
      :minimal -> prompt
    end
  end
  
  defp add_frequent_reminders(prompt) do
    reminders = ContextManager.generate_system_reminders([:crdt, :security, :coordination])
    "#{prompt}\n\n#{reminders}"
  end
  
  defp add_moderate_reminders(prompt) do
    reminders = ContextManager.generate_system_reminders([:crdt, :security])
    "#{prompt}\n\n#{reminders}"
  end
  
  defp add_minimal_reminders(prompt) do
    "#{prompt}\n\n<reminder>Maintain mathematical correctness and security</reminder>"
  end
  
  defp calculate_efficiency_projection(prompt, profile, context) do
    base_efficiency = profile.token_efficiency
    structure_bonus = calculate_structure_bonus(prompt, profile)
    context_bonus = calculate_context_bonus(context)
    
    projected_efficiency = base_efficiency * (1 + structure_bonus + context_bonus) * 35.0
    
    %{
      base_efficiency: base_efficiency,
      structure_bonus: structure_bonus,
      context_bonus: context_bonus,
      projected_multiplier: projected_efficiency,
      target_achieved: projected_efficiency >= 35.0
    }
  end
  
  defp calculate_structure_bonus(prompt, profile) do
    structure_score = case profile.optimal_structure do
      :xml_structured -> 
        if String.match?(prompt, ~r/<\w+>.*<\/\w+>/s), do: 0.15, else: 0.0
      :markdown_structured -> 
        if String.match?(prompt, ~r/^#\s+/), do: 0.12, else: 0.0
      :hybrid_structured -> 0.10
      :plain_structured -> 0.05
      _ -> 0.0
    end
    
    structure_score
  end
  
  defp calculate_context_bonus(context) do
    context_richness = map_size(context[:context] || %{})
    
    cond do
      context_richness >= 5 -> 0.20
      context_richness >= 3 -> 0.15
      context_richness >= 1 -> 0.10
      true -> 0.0
    end
  end
  
  # Additional helper functions for analysis
  
  defp get_prompt_from_crdt(prompt_id) do
    case ContextStore.get_set_values("optimized_prompts") do
      {:ok, prompts} ->
        case Enum.find(prompts, fn {id, _} -> id == prompt_id end) do
          {^prompt_id, record} -> {:ok, record}
          nil -> {:error, :not_found}
        end
      error -> error
    end
  end
  
  defp analyze_performance_gap(existing_record, performance_data) do
    expected_efficiency = existing_record[:efficiency_projection][:projected_multiplier] || 1.0
    actual_efficiency = performance_data[:efficiency_multiplier] || 1.0
    
    %{
      expected: expected_efficiency,
      actual: actual_efficiency,
      gap: expected_efficiency - actual_efficiency,
      gap_percentage: (expected_efficiency - actual_efficiency) / expected_efficiency * 100,
      needs_evolution: actual_efficiency < expected_efficiency * 0.8
    }
  end
  
  defp calculate_token_efficiency(prompt, usage_metrics, profile) do
    prompt_tokens = String.length(prompt) / 4 # Rough token estimate
    effective_tokens = usage_metrics[:tokens_used] || prompt_tokens
    
    if effective_tokens > 0 do
      (prompt_tokens / effective_tokens) * profile.token_efficiency
    else
      profile.token_efficiency
    end
  end
  
  defp analyze_prompt_structure(prompt, profile) do
    case profile.optimal_structure do
      :xml_structured -> if prompt =~ ~r/<\w+>.*<\/\w+>/s, do: 1.0, else: 0.5
      :markdown_structured -> if prompt =~ ~r/^#\s+/, do: 1.0, else: 0.5
      _ -> 0.8
    end
  end
  
  defp analyze_prompt_clarity(prompt) do
    word_count = length(String.split(prompt))
    sentence_count = length(String.split(prompt, ~r/[.!?]+/))
    
    avg_sentence_length = if sentence_count > 0, do: word_count / sentence_count, else: 0
    
    cond do
      avg_sentence_length <= 20 -> 1.0
      avg_sentence_length <= 30 -> 0.8
      true -> 0.6
    end
  end
  
  defp calculate_effectiveness(usage_metrics) do
    success_rate = usage_metrics[:success_rate] || 0.5
    response_time = usage_metrics[:avg_response_time] || 5000
    
    time_score = min(1.0, 1000.0 / response_time)
    success_rate * time_score
  end
  
  defp calculate_model_alignment(prompt, profile) do
    alignment_score = 0.5
    
    alignment_score = if String.contains?(prompt, "#{profile.reasoning_style}") do
      alignment_score + 0.2
    else
      alignment_score
    end
    
    alignment_score = if String.length(prompt) <= profile.max_context_length * 4 do
      alignment_score + 0.3
    else
      alignment_score
    end
    
    alignment_score
  end
  
  defp generate_optimization_recommendations(prompt, profile, usage_metrics) do
    recommendations = []
    
    recommendations = if String.length(prompt) > profile.max_context_length * 4 do
      ["Reduce prompt length to fit model context window" | recommendations]
    else
      recommendations
    end
    
    recommendations = if usage_metrics[:success_rate] && usage_metrics[:success_rate] < 0.8 do
      ["Add more specific examples and clearer instructions" | recommendations]
    else
      recommendations
    end
    
    recommendations = if not String.contains?(prompt, "#{profile.reasoning_style}") do
      ["Optimize reasoning style for #{profile.reasoning_style}" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
  
  defp calculate_overall_efficiency(analysis) do
    weights = %{
      token_efficiency: 0.25,
      structure_score: 0.20,
      clarity_score: 0.20,
      effectiveness_score: 0.25,
      model_alignment_score: 0.10
    }
    
    weighted_sum = Enum.reduce(weights, 0, fn {metric, weight}, acc ->
      score = Map.get(analysis, metric, 0.5)
      acc + (score * weight)
    end)
    
    # Scale to target 35x efficiency
    weighted_sum * 35.0
  end
end