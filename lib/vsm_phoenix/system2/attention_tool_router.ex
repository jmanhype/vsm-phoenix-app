defmodule VsmPhoenix.System2.AttentionToolRouter do
  @moduledoc """
  Enhanced tool routing with verbose descriptions and Claude-Code inspired selection logic.
  
  Provides detailed explanations for tool selection decisions and integrates with
  the cortical attention system for intelligent resource allocation.
  """

  require Logger
  alias VsmPhoenix.System2.AttentionReminders

  @tool_descriptions %{
    llm_worker: %{
      description: """
      LLM Worker Agent: Specialized for natural language processing and conversational intelligence.
      
      Optimal Usage Scenarios:
      - Natural language messages requiring semantic interpretation
      - Attention score > 0.6 AND relevance component > 0.5 (high contextual relevance)
      - Conversational threads with established context (coherence > 0.4)
      - Novel communication patterns requiring creative responses (novelty > 0.4)
      - User-initiated interactions with emotional or complex content
      
      Avoid When:
      - Pure system telemetry or metrics (intensity < 0.3, relevance < 0.2)
      - Attention score < 0.4 (resource conservation priority)
      - Bulk data processing with repetitive patterns (coherence < 0.2, novelty < 0.1)
      - System fatigue > 0.7 (preserve cognitive resources for critical tasks)
      - High-frequency automated messages (urgency < 0.2, pattern detected)
      
      Performance Characteristics:
      - Token consumption: High (500-2000 tokens per interaction)
      - Response latency: 2-8 seconds (depends on prompt complexity)
      - Context memory: Maintains conversation state across interactions
      - Learning capability: Improves response quality through feedback
      - Resource intensity: CPU + Network I/O intensive
      
      Attention Integration:
      - Successful responses strengthen relevance and coherence pattern weights
      - Conversation quality feedback adjusts future attention scoring
      - Token efficiency metrics influence resource allocation decisions
      - Context continuity improves through attention-guided memory management
      """,
      
      attention_requirements: %{
        minimum_score: 0.4,
        optimal_score: 0.7,
        preferred_dimensions: [:relevance, :novelty, :coherence],
        avoid_dimensions: [:intensity_only],
        resource_cost: :high,
        fatigue_impact: 0.15,
        processing_time_ms: 3000,
        success_criteria: [:response_quality, :context_continuity, :user_satisfaction]
      },
      
      capability_keywords: [:nlp, :conversation, :creative, :reasoning, :context]
    },
    
    sensor_agent: %{
      description: """
      Environmental Sensor Agent: Optimized for real-time data collection and monitoring.
      
      Optimal Usage Scenarios:
      - External data collection requests with time sensitivity (urgency > 0.6)
      - Environmental monitoring triggers requiring fresh data (intensity > 0.5)
      - API integration messages with clear data requirements
      - System health checks and status verification requests
      - Threshold-based alerts requiring immediate data validation
      
      Avoid When:
      - Data freshness not critical (urgency < 0.3)
      - Internal system communications without external dependencies
      - Attention state is 'focused' on unrelated domain (context mismatch)
      - Recent similar data collection completed (novelty < 0.2, temporal window check)
      - Network connectivity issues detected (system health check)
      
      Performance Characteristics:
      - External dependency: May timeout or fail due to API/network issues
      - Data freshness: Provides current environmental state information
      - Caching: Intelligent caching reduces redundant API calls
      - Latency: 100ms-5s depending on data source
      - Reliability: 95% success rate under normal conditions
      
      Attention Integration:
      - Fresh environmental data increases novelty scoring for related messages
      - API failures temporarily reduce sensor-based attention pattern trust
      - Successful data collection strengthens intensity and urgency pattern weights
      - Environmental changes trigger attention recalibration for affected domains
      """,
      
      attention_requirements: %{
        minimum_score: 0.3,
        optimal_score: 0.6,
        preferred_dimensions: [:urgency, :intensity],
        avoid_dimensions: [:coherence_only],
        resource_cost: :medium,
        fatigue_impact: 0.08,
        processing_time_ms: 1500,
        success_criteria: [:data_freshness, :api_success_rate, :relevance_to_request]
      },
      
      capability_keywords: [:monitoring, :api, :external, :realtime, :health]
    },
    
    meta_learning_processor: %{
      description: """
      Meta-Learning Intelligence Processor: Handles pattern sharing and network intelligence integration.
      
      Optimal Usage Scenarios:
      - Messages containing attention patterns from trusted VSM instances
      - Well-formed pattern data with high coherence scores (coherence > 0.7)
      - Network intelligence updates from successful VSM deployments
      - System performance optimization requests requiring pattern analysis
      - Cross-VSM collaboration messages with verified authentication
      
      Avoid When:
      - Pattern source has low trust score (< 0.4) or unknown provenance
      - Local attention patterns performing exceptionally well (> 0.85 effectiveness)
      - System under high message load (preserve local processing resources)
      - Recent pattern integration still being evaluated (temporal cooldown)
      - Conflicting patterns from multiple sources requiring manual resolution
      
      Performance Characteristics:
      - Pattern validation: CPU intensive analysis (graph algorithms, similarity matching)
      - Memory impact: Stores pattern candidates and evaluation metrics in ETS
      - Network effect: Improvements compound across connected VSM instances
      - Learning curve: Effectiveness increases with pattern diversity and volume
      - Convergence time: 5-30 minutes for pattern integration and validation
      
      Attention Integration:
      - Successful pattern integration improves overall attention system effectiveness
      - Pattern conflict detection requires attention-guided resolution strategies
      - Network pattern adoption influences local attention weight evolution
      - Cross-VSM performance metrics feed back into trust scoring algorithms
      """,
      
      attention_requirements: %{
        minimum_score: 0.5,
        optimal_score: 0.8,
        preferred_dimensions: [:coherence, :novelty],
        avoid_dimensions: [:urgency_only],
        resource_cost: :medium,
        fatigue_impact: 0.12,
        processing_time_ms: 2500,
        success_criteria: [:pattern_validation, :integration_success, :performance_improvement]
      },
      
      capability_keywords: [:learning, :patterns, :network, :optimization, :intelligence]
    },
    
    coordination_agent: %{
      description: """
      System Coordination Agent: Manages inter-system communication and conflict resolution.
      
      Optimal Usage Scenarios:
      - Messages requiring coordination between System 1 agents
      - Conflict resolution requests with multiple competing priorities
      - Resource allocation decisions with system-wide implications
      - Anti-oscillation interventions for unstable message patterns
      - Cross-system synchronization and state management requests
      
      Avoid When:
      - Simple message routing that doesn't require coordination
      - Single-agent tasks without inter-system dependencies
      - Low-priority maintenance tasks during high system load
      - Conflicts already resolved by attention filtering
      - Messages with clear single-destination routing
      
      Performance Characteristics:
      - Coordination overhead: Requires communication with multiple agents
      - Decision latency: 500ms-2s for complex coordination scenarios  
      - Resource arbitration: Manages fair allocation across competing requests
      - Stability impact: Reduces system oscillation and improves coherence
      - Learning capability: Improves coordination strategies over time
      
      Attention Integration:
      - Coordination success strengthens system-wide attention coherence
      - Failed coordination attempts adjust conflict detection sensitivity
      - Multi-agent interaction patterns influence attention weight distribution
      - System stability metrics feed back into coordination strategy selection
      """,
      
      attention_requirements: %{
        minimum_score: 0.4,
        optimal_score: 0.6,
        preferred_dimensions: [:relevance, :urgency, :coherence],
        avoid_dimensions: [:novelty_only],
        resource_cost: :medium,
        fatigue_impact: 0.10,
        processing_time_ms: 1000,
        success_criteria: [:conflict_resolution, :system_stability, :resource_efficiency]
      },
      
      capability_keywords: [:coordination, :conflict, :resources, :stability, :routing]
    }
  }

  @doc """
  Select the optimal tool for processing a message based on attention analysis.
  
  Returns comprehensive selection information including reasoning and expected outcomes.
  """
  def select_optimal_tool(message, attention_components, system_state) do
    available_tools = get_available_tools(system_state)
    
    tool_evaluations = Enum.map(available_tools, fn tool_name ->
      tool_config = @tool_descriptions[tool_name]
      fitness_score = calculate_tool_fitness(message, attention_components, tool_config, system_state)
      
      {tool_name, fitness_score, tool_config}
    end)
    
    # Sort by fitness score (descending)
    sorted_tools = Enum.sort_by(tool_evaluations, fn {_, score, _} -> score end, :desc)
    
    case sorted_tools do
      [{best_tool, score, config} | _] when score > config.attention_requirements.minimum_score ->
        selection_context = generate_selection_context(best_tool, score, config, attention_components, system_state)
        
        {:ok, %{
          selected_tool: best_tool,
          fitness_score: score,
          selection_reasoning: selection_context,
          expected_outcomes: predict_outcomes(best_tool, config, attention_components),
          resource_impact: calculate_resource_impact(config, system_state),
          alternatives: format_alternatives(sorted_tools, 3)
        }}
        
      [{best_candidate, score, config} | _] ->
        {:defer, %{
          reason: "No tool meets minimum attention threshold",
          best_candidate: best_candidate,
          candidate_score: score,
          required_score: config.attention_requirements.minimum_score,
          shortfall: config.attention_requirements.minimum_score - score,
          recommendation: generate_deferral_recommendation(score, config, system_state)
        }}
        
      [] ->
        {:error, "No tools available for processing"}
    end
  end

  @doc """
  Calculate comprehensive tool fitness score based on attention components and system state.
  """
  def calculate_tool_fitness(message, attention_components, tool_config, system_state) do
    requirements = tool_config.attention_requirements
    
    # Base score from attention components and tool preferences
    dimension_score = calculate_dimension_alignment(attention_components, requirements)
    
    # System state adjustments
    fatigue_penalty = calculate_fatigue_penalty(system_state.fatigue_level, requirements.fatigue_impact)
    resource_penalty = calculate_resource_penalty(system_state, requirements.resource_cost)
    temporal_bonus = calculate_temporal_bonus(message, system_state, requirements)
    
    # Capability matching bonus
    capability_bonus = calculate_capability_bonus(message, tool_config.capability_keywords)
    
    # Final score with bounds checking
    base_score = dimension_score * (1.0 - fatigue_penalty - resource_penalty) + temporal_bonus + capability_bonus
    max(0.0, min(1.0, base_score))
  end

  @doc """
  Generate detailed explanation of tool selection decision.
  """
  def explain_tool_selection(selection_result, message) do
    case selection_result do
      {:ok, result} ->
        """
        🔧 Tool Selection: #{result.selected_tool} (Score: #{Float.round(result.fitness_score, 3)})
        
        #{result.selection_reasoning}
        
        Expected Outcomes:
        #{format_expected_outcomes(result.expected_outcomes)}
        
        Resource Impact:
        #{format_resource_impact(result.resource_impact)}
        
        Alternative Considerations:
        #{format_alternatives_summary(result.alternatives)}
        """
        
      {:defer, result} ->
        """
        ⏸️ Tool Selection Deferred: #{result.best_candidate}
        
        Reason: #{result.reason}
        Score Gap: #{Float.round(result.shortfall, 3)} (need #{result.required_score}, got #{Float.round(result.candidate_score, 3)})
        
        Recommendation: #{result.recommendation}
        """
        
      {:error, reason} ->
        "❌ Tool Selection Failed: #{reason}"
    end
  end

  # Private Functions

  defp get_available_tools(system_state) do
    # In a real implementation, this would check system health, resource availability, etc.
    base_tools = [:sensor_agent, :coordination_agent]
    
    # Add LLM worker if not resource constrained
    tools = if system_state.fatigue_level < 0.8 and system_state[:resource_availability] != :low do
      [:llm_worker | base_tools]
    else
      base_tools
    end
    
    # Add meta-learning if patterns available
    if system_state[:network_patterns_available] do
      [:meta_learning_processor | tools]
    else
      tools
    end
  end

  defp calculate_dimension_alignment(components, requirements) do
    preferred = requirements.preferred_dimensions
    avoided = Map.get(requirements, :avoid_dimensions, [])
    
    # Calculate preference alignment score
    preferred_score = Enum.reduce(preferred, 0.0, fn dim, acc ->
      component_value = Map.get(components, dim, 0.0)
      acc + component_value
    end) / length(preferred)
    
    # Apply avoidance penalty
    avoidance_penalty = Enum.reduce(avoided, 0.0, fn dim, acc ->
      case dim do
        :intensity_only -> 
          if components.intensity > 0.7 and Enum.all?([:novelty, :urgency, :relevance], &(Map.get(components, &1, 0) < 0.3)) do
            acc + 0.3
          else
            acc
          end
        :coherence_only ->
          if components.coherence > 0.7 and Enum.all?([:novelty, :urgency, :intensity], &(Map.get(components, &1, 0) < 0.3)) do
            acc + 0.3
          else
            acc
          end
        _ -> acc
      end
    end)
    
    max(0.0, preferred_score - avoidance_penalty)
  end

  defp calculate_fatigue_penalty(fatigue_level, fatigue_impact) do
    # Higher fatigue increases penalty for tools with high fatigue impact
    fatigue_level * fatigue_impact * 2.0
  end

  defp calculate_resource_penalty(system_state, resource_cost) do
    resource_multiplier = case resource_cost do
      :high -> 0.3
      :medium -> 0.15
      :low -> 0.05
    end
    
    # Apply penalty if system is resource constrained
    if system_state[:resource_availability] == :low do
      resource_multiplier
    else
      0.0
    end
  end

  defp calculate_temporal_bonus(message, system_state, requirements) do
    # Bonus for messages that align with optimal processing time
    current_time = DateTime.utc_now()
    
    # Simple temporal bonus - in reality would be much more sophisticated
    case requirements.processing_time_ms do
      time when time < 1000 -> 0.05  # Quick processing bonus
      _ -> 0.0
    end
  end

  defp calculate_capability_bonus(message, capability_keywords) do
    # Extract message characteristics and match with tool capabilities
    message_text = inspect(message) |> String.downcase()
    
    matching_keywords = Enum.count(capability_keywords, fn keyword ->
      String.contains?(message_text, to_string(keyword))
    end)
    
    # Bonus based on capability alignment
    (matching_keywords / length(capability_keywords)) * 0.1
  end

  defp generate_selection_context(tool_name, score, config, components, system_state) do
    dominant_component = get_dominant_component(components)
    
    """
    Selected: #{tool_name} (Fitness: #{Float.round(score, 3)})
    
    Decision Factors:
    - Dominant attention dimension: #{dominant_component} (#{Float.round(Map.get(components, dominant_component), 3)})
    - Dimension alignment: #{evaluate_dimension_alignment(components, config.attention_requirements.preferred_dimensions)}
    - System fatigue impact: #{Float.round(config.attention_requirements.fatigue_impact, 3)} (current: #{Float.round(system_state.fatigue_level, 3)})
    - Resource cost: #{config.attention_requirements.resource_cost}
    
    Attention Component Breakdown:
    #{format_component_breakdown(components)}
    
    Tool Optimization:
    - Preferred dimensions: #{Enum.join(config.attention_requirements.preferred_dimensions, ", ")}
    - Expected processing time: #{config.attention_requirements.processing_time_ms}ms
    - Success criteria: #{Enum.join(config.attention_requirements.success_criteria, ", ")}
    """
  end

  defp predict_outcomes(tool_name, config, components) do
    %{
      processing_time: "#{config.attention_requirements.processing_time_ms}ms",
      resource_usage: config.attention_requirements.resource_cost,
      success_probability: calculate_success_probability(components, config),
      fatigue_impact: config.attention_requirements.fatigue_impact,
      expected_benefits: get_tool_benefits(tool_name, components)
    }
  end

  defp calculate_resource_impact(config, system_state) do
    base_impact = case config.attention_requirements.resource_cost do
      :high -> %{cpu: 0.4, memory: 0.3, network: 0.5}
      :medium -> %{cpu: 0.2, memory: 0.15, network: 0.25}
      :low -> %{cpu: 0.1, memory: 0.05, network: 0.1}
    end
    
    # Adjust for current system state
    fatigue_multiplier = 1.0 + system_state.fatigue_level * 0.5
    
    %{
      cpu: base_impact.cpu * fatigue_multiplier,
      memory: base_impact.memory * fatigue_multiplier,
      network: base_impact.network,
      duration_estimate: "#{config.attention_requirements.processing_time_ms}ms"
    }
  end

  defp get_dominant_component(components) do
    {component, _value} = Enum.max_by(components, fn {_k, v} -> v end)
    component
  end

  defp evaluate_dimension_alignment(components, preferred_dimensions) do
    alignment_scores = Enum.map(preferred_dimensions, fn dim ->
      "#{dim}: #{Float.round(Map.get(components, dim, 0.0), 3)}"
    end)
    
    Enum.join(alignment_scores, ", ")
  end

  defp format_component_breakdown(components) do
    Enum.map(components, fn {component, value} ->
      "  - #{component}: #{Float.round(value, 3)}"
    end)
    |> Enum.join("\n")
  end

  defp calculate_success_probability(components, config) do
    # Simple heuristic - would be more sophisticated in practice
    preferred_score = Enum.reduce(config.attention_requirements.preferred_dimensions, 0.0, fn dim, acc ->
      acc + Map.get(components, dim, 0.0)
    end) / length(config.attention_requirements.preferred_dimensions)
    
    Float.round(min(0.95, preferred_score * 1.2), 2)
  end

  defp get_tool_benefits(tool_name, components) do
    case tool_name do
      :llm_worker -> ["High-quality responses", "Context understanding", "Creative problem solving"]
      :sensor_agent -> ["Real-time data", "Environmental awareness", "System monitoring"]
      :meta_learning_processor -> ["Pattern optimization", "Network intelligence", "Performance improvement"]
      :coordination_agent -> ["Conflict resolution", "Resource optimization", "System stability"]
      _ -> ["General processing"]
    end
  end

  defp format_expected_outcomes(outcomes) do
    """
    - Processing time: #{outcomes.processing_time}
    - Resource usage: #{outcomes.resource_usage}
    - Success probability: #{outcomes.success_probability * 100}%
    - Fatigue impact: #{Float.round(outcomes.fatigue_impact, 3)}
    - Benefits: #{Enum.join(outcomes.expected_benefits, ", ")}
    """
  end

  defp format_resource_impact(impact) do
    """
    - CPU: #{Float.round(impact.cpu * 100, 1)}%
    - Memory: #{Float.round(impact.memory * 100, 1)}%
    - Network: #{Float.round(impact.network * 100, 1)}%
    - Duration: #{impact.duration_estimate}
    """
  end

  defp format_alternatives(tool_evaluations, count) do
    tool_evaluations
    |> Enum.take(count)
    |> Enum.map(fn {tool, score, config} ->
      %{
        tool: tool,
        score: Float.round(score, 3),
        min_required: config.attention_requirements.minimum_score
      }
    end)
  end

  defp format_alternatives_summary(alternatives) do
    alternatives
    |> Enum.map(fn alt ->
      "  - #{alt.tool}: #{alt.score} (min: #{alt.min_required})"
    end)
    |> Enum.join("\n")
  end

  defp generate_deferral_recommendation(score, config, system_state) do
    cond do
      system_state.fatigue_level > 0.6 ->
        "Consider reducing system fatigue through maintenance cycle before retrying"
        
      score < config.attention_requirements.minimum_score * 0.8 ->
        "Message attention score too low - consider filtering or routing to simpler processor"
        
      true ->
        "Wait for system state improvement or message priority increase"
    end
  end
end