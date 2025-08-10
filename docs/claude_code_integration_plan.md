# Claude Code Integration Plan for Cortical Attention Enhancement

## Executive Summary

This plan integrates Claude Code's cognitive patterns with the VSM Phoenix Cortical Attention-Engine to evolve from reactive to predictive intelligence. The integration leverages Claude's constant reinforcement patterns, specialized prompting, and semantic context management to enhance our neuroscience-inspired architecture.

## Critical Enhancement Areas

### 1. Advanced Prompt Engineering with System Reminders

#### Current State: Basic Attention Cycling
```elixir
# Current attention maintenance cycle (every 1 second)
defp handle_info(:maintain_attention, state) do
  # Basic fatigue recovery and context decay
  new_state = state
    |> apply_fatigue_recovery()
    |> decay_context_memory()
    |> cleanup_attention_windows()
end
```

#### Enhanced State: Claude-Style System Reminders
```elixir
defmodule VsmPhoenix.System2.AttentionReminders do
  @system_reminders [
    %{
      trigger: :attention_shift,
      reminder: "Remember: High attention messages (>0.8) bypass normal filtering and require immediate processing",
      frequency: :every_shift
    },
    %{
      trigger: :fatigue_increase,
      reminder: "Attention fatigue detected. Prioritize novelty and urgency dimensions. Reduce coherence weighting.",
      frequency: :when_fatigued
    },
    %{
      trigger: :pattern_match,
      reminder: "Pattern recognized. Apply learned attention weight: %{pattern_strength}. Consider similar contexts.",
      frequency: :on_pattern_detection
    },
    %{
      trigger: :meta_learning_update,
      reminder: "New pattern from VSM network. Evaluate against local context before integration. Trust score: %{trust_level}",
      frequency: :on_external_pattern
    }
  ]

  def apply_system_reminder(state, trigger, context \\ %{}) do
    reminder = get_reminder(trigger)
    enhanced_context = Map.merge(context, %{
      reminder: interpolate_reminder(reminder, context),
      applied_at: DateTime.utc_now(),
      attention_state: state.attention_state
    })
    
    %{state | 
      current_reminder: enhanced_context,
      reminder_history: [enhanced_context | state.reminder_history] |> Enum.take(10)
    }
  end
end

# Enhanced attention maintenance with constant reinforcement
defp handle_info(:maintain_attention, state) do
  # Apply system reminders based on current state
  state = case state.attention_state do
    :fatigued -> 
      AttentionReminders.apply_system_reminder(state, :fatigue_increase)
    :focused when state.fatigue_level > 0.5 -> 
      AttentionReminders.apply_system_reminder(state, :attention_shift)
    _ -> 
      state
  end
  
  # Apply standard maintenance with reminder context
  new_state = state
    |> apply_fatigue_recovery()
    |> decay_context_memory()
    |> cleanup_attention_windows()
    |> reinforce_learned_patterns()  # New: Constant pattern reinforcement
end
```

### 2. Sub-Agent Architecture with Specialized System Prompts

#### Meta-Learning Component Specialization
```elixir
defmodule VsmPhoenix.System2.SpecializedPrompts do
  @meta_learning_prompts %{
    pattern_extractor: %{
      system_prompt: """
      You are a Pattern Extraction Agent focused on identifying valuable attention patterns from VSM operations.
      
      Key capabilities:
      - Analyze message flows for recurring attention patterns
      - Identify successful attention allocation strategies
      - Extract context-dependent attention weights
      - Recognize temporal attention cycles
      
      Remember: Pattern strength is measured by successful message routing outcomes.
      Always consider: Novelty decay rates, urgency temporal windows, relevance context matching.
      
      Current context: %{context}
      Attention state: %{attention_state}
      Recent patterns: %{recent_patterns}
      """,
      
      capabilities: [:pattern_recognition, :temporal_analysis, :success_correlation],
      attention_bias: %{novelty: 0.4, coherence: 0.3, relevance: 0.3}
    },
    
    pattern_validator: %{
      system_prompt: """
      You are a Pattern Validation Agent responsible for validating external attention patterns before integration.
      
      Key capabilities:
      - Assess pattern compatibility with local VSM context
      - Validate pattern effectiveness against historical data
      - Detect potentially harmful or conflicting patterns
      - Score pattern trustworthiness based on source VSM performance
      
      Remember: Trust scores decrease with distance from source VSM and increase with validation consensus.
      Always verify: Pattern applicability to current context, potential negative interactions with existing patterns.
      
      Source VSM: %{source_vsm}
      Pattern trust score: %{trust_score}
      Local context compatibility: %{compatibility_score}
      """,
      
      capabilities: [:pattern_validation, :trust_assessment, :conflict_detection],
      attention_bias: %{urgency: 0.4, intensity: 0.3, coherence: 0.3}
    },
    
    context_fusion_agent: %{
      system_prompt: """
      You are a Context Fusion Agent that integrates multiple information streams into coherent attention contexts.
      
      Key capabilities:
      - Merge temporal attention windows into unified context
      - Resolve conflicting attention signals from different sources
      - Maintain context continuity across attention shifts
      - Generate semantic context embeddings for attention scoring
      
      Remember: Context fusion must preserve causal relationships and temporal ordering.
      Always maintain: Message causality, temporal coherence, semantic consistency.
      
      Active contexts: %{active_contexts}
      Fusion conflicts: %{conflicts}
      Temporal alignment: %{temporal_state}
      """,
      
      capabilities: [:context_fusion, :conflict_resolution, :semantic_embedding],
      attention_bias: %{relevance: 0.5, coherence: 0.3, intensity: 0.2}
    }
  }

  def get_specialized_prompt(agent_type, context) do
    prompt_config = @meta_learning_prompts[agent_type]
    interpolated_prompt = String.replace(prompt_config.system_prompt, ~r/%\{(\w+)\}/, fn _, key ->
      Map.get(context, String.to_atom(key), "unknown")
    end)
    
    %{
      system_prompt: interpolated_prompt,
      capabilities: prompt_config.capabilities,
      attention_bias: prompt_config.attention_bias
    }
  end
end
```

### 3. Enhanced Attention-Based Tool Routing

#### Current Tool Selection
```elixir
# Basic tool routing in coordinator
defp route_message(message, context, state) do
  attention_score = score_attention(message, context)
  if attention_score > 0.2, do: process_message(message), else: {:drop, message}
end
```

#### Enhanced Tool Routing with Verbose Descriptions
```elixir
defmodule VsmPhoenix.System2.AttentionToolRouter do
  @tool_descriptions %{
    llm_worker: %{
      description: """
      LLM Worker Agent: Specialized for natural language processing and conversation handling.
      
      Use when:
      - Message contains natural language that requires interpretation
      - Attention score > 0.6 AND relevance component > 0.5
      - Context indicates conversational thread or user interaction
      - Novelty score > 0.4 (new conversation patterns)
      
      Do NOT use when:
      - Message is pure system telemetry (intensity < 0.3)
      - Attention score < 0.4 (resource conservation)
      - Message is part of bulk data processing (coherence < 0.2)
      - Fatigue level > 0.7 (preserve cognitive resources)
      
      Performance characteristics:
      - High token consumption: Use only for high-attention messages
      - Contextual memory: Maintains conversation state
      - Response latency: 2-5 seconds average
      
      Integration with attention:
      - Successful responses strengthen relevance patterns
      - Failed responses trigger attention weight adjustment
      - Conversation context feeds back into future attention scoring
      """,
      
      attention_requirements: %{
        minimum_score: 0.4,
        preferred_dimensions: [:relevance, :novelty],
        resource_cost: :high,
        fatigue_impact: 0.15
      }
    },
    
    sensor_agent: %{
      description: """
      Sensor Agent: Optimized for environmental data collection and monitoring.
      
      Use when:
      - Message requires external data gathering or API calls
      - Urgency component > 0.6 (time-sensitive data collection)
      - Intensity score > 0.5 (strong signal requiring verification)
      - Pattern matches known data collection triggers
      
      Do NOT use when:
      - Data collection would introduce latency > attention timeout
      - Message is internal system communication (relevance to external < 0.3)
      - Current attention state is 'focused' on different domain
      
      Performance characteristics:
      - External API dependency: May fail or timeout
      - Data freshness: Provides real-time environmental context
      - Resource usage: Network I/O intensive
      
      Integration with attention:
      - Fresh data increases novelty scoring for related messages
      - API failures reduce trust in sensor-based attention patterns
      - Environmental changes trigger attention recalibration
      """,
      
      attention_requirements: %{
        minimum_score: 0.3,
        preferred_dimensions: [:urgency, :intensity],
        resource_cost: :medium,
        fatigue_impact: 0.08
      }
    },
    
    meta_learning_processor: %{
      description: """
      Meta-Learning Processor: Handles pattern sharing and network intelligence integration.
      
      Use when:
      - Message contains attention patterns from other VSM instances
      - Coherence score > 0.7 (well-formed pattern data)
      - Message metadata indicates meta-learning origin
      - Current fatigue level < 0.5 (sufficient cognitive capacity)
      
      Do NOT use when:
      - Pattern source has low trust score (< 0.4)
      - Local attention patterns are performing well (> 0.8 effectiveness)
      - System is under high message load (preserve local resources)
      
      Performance characteristics:
      - Pattern validation: CPU intensive analysis
      - Memory impact: Stores pattern candidates in ETS
      - Network effect: Improves system-wide attention quality
      
      Integration with attention:
      - Successful pattern integration improves attention effectiveness
      - Pattern conflicts require attention-guided resolution
      - Network patterns influence local attention weight evolution
      """,
      
      attention_requirements: %{
        minimum_score: 0.5,
        preferred_dimensions: [:coherence, :novelty],
        resource_cost: :medium,
        fatigue_impact: 0.12
      }
    }
  }

  def select_optimal_tool(message, attention_components, system_state) do
    available_tools = get_available_tools(system_state)
    
    tool_scores = Enum.map(available_tools, fn tool_name ->
      tool_config = @tool_descriptions[tool_name]
      score = calculate_tool_fitness(message, attention_components, tool_config, system_state)
      
      {tool_name, score, tool_config.attention_requirements}
    end)
    
    # Select highest scoring tool that meets attention requirements
    {best_tool, score, requirements} = Enum.max_by(tool_scores, fn {_, score, _} -> score end)
    
    if score > requirements.minimum_score do
      {:ok, best_tool, %{
        selection_reason: generate_selection_explanation(best_tool, score, attention_components),
        expected_fatigue_impact: requirements.fatigue_impact,
        resource_cost: requirements.resource_cost
      }}
    else
      {:defer, %{
        reason: "No tool meets minimum attention threshold",
        best_candidate: best_tool,
        required_score: requirements.minimum_score,
        actual_score: score
      }}
    end
  end

  defp generate_selection_explanation(tool_name, score, components) do
    tool_desc = @tool_descriptions[tool_name]
    
    """
    Selected #{tool_name} (score: #{Float.round(score, 3)})
    
    Attention components:
    - Novelty: #{Float.round(components.novelty, 3)}
    - Urgency: #{Float.round(components.urgency, 3)} 
    - Relevance: #{Float.round(components.relevance, 3)}
    - Intensity: #{Float.round(components.intensity, 3)}
    - Coherence: #{Float.round(components.coherence, 3)}
    
    Selection criteria met:
    #{Enum.join(tool_desc.attention_requirements.preferred_dimensions, ", ")} dimensions optimal
    
    Expected outcomes:
    - Resource cost: #{tool_desc.attention_requirements.resource_cost}
    - Fatigue impact: #{tool_desc.attention_requirements.fatigue_impact}
    """
  end
end
```

### 4. Structured Context Management with Semantic Meaning

#### Context Attachment Architecture
```elixir
defmodule VsmPhoenix.System2.SemanticContext do
  @context_schema %{
    message_context: %{
      semantic_embedding: :vector,      # For meaning graph integration
      causal_chain: :list,             # Message causality relationships
      attention_history: :temporal,     # Previous attention scores for similar messages
      domain_classification: :atom,     # :user_interaction, :system_telemetry, :meta_learning
      confidence_metrics: :map         # Certainty levels for different context aspects
    },
    
    attention_context: %{
      current_state: :atom,            # :focused, :distributed, etc.
      state_duration: :integer,        # How long in current state
      recent_shifts: :list,            # Recent attention shifts with reasons
      fatigue_trajectory: :list,       # Fatigue level changes over time
      learned_associations: :map       # Message patterns -> attention outcomes
    },
    
    system_context: %{
      network_intelligence: :map,      # Patterns from other VSM instances
      environmental_state: :map,       # From System 4 intelligence
      resource_availability: :map,     # Current system resources
      performance_metrics: :map       # Recent system performance indicators
    }
  }

  def attach_semantic_context(message, base_context, state) do
    enhanced_context = %{
      message: enrich_message_context(message, state),
      attention: build_attention_context(state),
      system: gather_system_context(state),
      
      # Claude-style structured context
      context_metadata: %{
        created_at: DateTime.utc_now(),
        context_version: "2.0",
        semantic_confidence: calculate_semantic_confidence(message, state),
        integration_hints: generate_integration_hints(message, base_context, state)
      }
    }

    # Validate context structure matches schema
    validated_context = validate_context_schema(enhanced_context, @context_schema)
    
    {:ok, validated_context}
  end

  defp generate_integration_hints(message, base_context, state) do
    """
    Context Integration Hints for Message Processing:
    
    Message Type: #{classify_message_domain(message)}
    Attention State: #{state.attention_state} (duration: #{state.state_duration}ms)
    
    Recommended Processing:
    #{get_processing_recommendations(message, state)}
    
    Context Interactions:
    - Similar messages: #{count_similar_messages(message, state)} in last hour
    - Pattern matches: #{get_pattern_matches(message, state)} 
    - Causal relationships: #{identify_causal_chain(message, base_context)}
    
    Attention Guidance:
    - Focus areas: #{state.current_focus || "distributed"}
    - Avoid patterns: #{get_fatigue_patterns(state)}
    - Amplify signals: #{get_amplification_targets(state)}
    """
  end
end
```

### 5. Implementation Priority and Integration Path

#### Phase 1: Foundation (Week 1-2)
1. **System Reminders Integration**
   - Implement `AttentionReminders` module
   - Add reminder triggers to attention maintenance cycle
   - Create reminder interpolation and history tracking

2. **Basic Tool Routing Enhancement**
   - Create verbose tool descriptions
   - Implement fitness scoring for tool selection
   - Add selection explanation generation

#### Phase 2: Specialized Agents (Week 3-4)
3. **Meta-Learning Prompt Specialization**
   - Implement specialized prompt configurations
   - Create context interpolation for prompts
   - Add capability-based attention biasing

4. **Semantic Context Architecture**
   - Design context schema and validation
   - Implement context enrichment pipeline
   - Create integration hints generation

#### Phase 3: Advanced Integration (Week 5-6)
5. **Predictive Attention Evolution**
   - Integrate environmental context from System 4
   - Implement proactive attention allocation
   - Create meaning graph integration points

## Expected Outcomes

### Immediate Benefits (Phase 1)
- **Reduced Oscillation**: System reminders prevent attention thrashing
- **Improved Tool Selection**: Verbose descriptions enable better routing decisions
- **Enhanced Debugging**: Clear explanations for all attention decisions

### Medium-term Benefits (Phase 2-3)
- **Adaptive Intelligence**: Specialized prompts enable focused learning
- **Semantic Awareness**: Context becomes meaning-rich rather than syntactic
- **Predictive Capability**: System anticipates rather than reacts

### Long-term Benefits (Full Integration)
- **35x Efficiency**: Claude-style constant reinforcement + neuroscience architecture
- **Collective Intelligence**: Network-aware attention with semantic understanding
- **Self-Optimizing**: System evolves attention strategies through reinforcement

## Success Metrics

1. **Attention Accuracy**: Percentage of messages correctly prioritized
2. **Response Latency**: Time from message arrival to appropriate tool selection
3. **Resource Efficiency**: CPU/memory usage per message processed
4. **Learning Rate**: Speed of attention pattern adaptation
5. **Network Effect**: Improvement from meta-learning pattern sharing

This integration plan transforms the Cortical Attention-Engine from a reactive filter into a predictive, semantically-aware, and collectively-intelligent cognitive system that leverages the best of both neuroscience-inspired architecture and Claude Code's reinforcement patterns.