defmodule VsmPhoenix.Telemetry.ContextFusionEngine do
  @moduledoc """
  Context Fusion Engine - Claude Code Enhanced

  Integrates Claude-style context management with analog signal processing:
  1. Dynamic context injection based on current system phase
  2. XML-structured semantic blocks for telemetry data processing
  3. Context filtering aligned with continuous signal processing
  4. Performance monitoring for evolutionary prompt optimization
  """

  use GenServer
  require Logger
  alias VsmPhoenix.Telemetry.PatternDetector

  @context_types [
    :system_phase,      # Current VSM system phase (1-5)
    :causal_chain,      # Event causality relationships
    :semantic_block,    # XML-structured context blocks
    :performance_meta,  # GEPA efficiency tracking
    :meaning_graph,     # Cybernetic.ai meaning relationships
    :signal_coherence   # Cross-signal correlation context
  ]

  @phase_contexts %{
    system1: %{
      focus: :operational_execution,
      context_weight: 0.8,
      signal_priority: [:agent_health, :task_completion, :resource_usage],
      semantic_tags: ["<operation>", "<execution>", "<variety-flow>"]
    },
    system2: %{
      focus: :coordination_patterns,
      context_weight: 0.9,
      signal_priority: [:attention_weights, :coordination_efficiency, :conflict_resolution],
      semantic_tags: ["<coordination>", "<attention>", "<anti-oscillation>"]
    },
    system3: %{
      focus: :resource_control,
      context_weight: 0.85,
      signal_priority: [:resource_allocation, :performance_metrics, :threshold_monitoring],
      semantic_tags: ["<control>", "<resources>", "<optimization>"]
    },
    system4: %{
      focus: :environmental_intelligence,
      context_weight: 0.95,
      signal_priority: [:environmental_scan, :adaptation_triggers, :gepa_efficiency],
      semantic_tags: ["<intelligence>", "<environment>", "<adaptation>"]
    },
    system5: %{
      focus: :policy_synthesis,
      context_weight: 1.0,
      signal_priority: [:policy_effectiveness, :identity_coherence, :strategic_alignment],
      semantic_tags: ["<policy>", "<identity>", "<strategy>"]
    }
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def attach_context(signal_id, context_type, metadata) do
    GenServer.call(__MODULE__, {:attach_context, signal_id, context_type, metadata})
  end

  def filter_context_by_phase(system_phase, signal_data) do
    GenServer.call(__MODULE__, {:filter_context_by_phase, system_phase, signal_data})
  end

  def build_semantic_block(signal_id, analysis_results, context) do
    GenServer.call(__MODULE__, {:build_semantic_block, signal_id, analysis_results, context})
  end

  def track_gepa_performance(prompt_id, efficiency_metrics) do
    GenServer.call(__MODULE__, {:track_gepa_performance, prompt_id, efficiency_metrics})
  end

  def create_meaning_graph_node(signal_id, causal_relationships) do
    GenServer.call(__MODULE__, {:create_meaning_graph_node, signal_id, causal_relationships})
  end

  def inject_dynamic_context(signal_id, current_phase, signal_coherence) do
    GenServer.call(__MODULE__, {:inject_dynamic_context, signal_id, current_phase, signal_coherence})
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    Logger.info("🧠 Context Fusion Engine initializing...")
    
    # Initialize ETS tables for context storage
    :ets.new(:context_attachments, [:set, :public, :named_table])
    :ets.new(:semantic_blocks, [:set, :public, :named_table])
    :ets.new(:meaning_graph_nodes, [:set, :public, :named_table])
    :ets.new(:gepa_performance, [:set, :public, :named_table])
    :ets.new(:context_cache, [:set, :public, :named_table])

    state = %{
      active_contexts: %{},
      phase_filters: @phase_contexts,
      context_stats: %{
        attachments_created: 0,
        semantic_blocks_built: 0,
        performance_tracks: 0,
        meaning_nodes_created: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:attach_context, signal_id, context_type, metadata}, _from, state) do
    context_entry = %{
      signal_id: signal_id,
      context_type: context_type,
      metadata: metadata,
      timestamp: System.monotonic_time(:microsecond),
      coherence_score: calculate_context_coherence(metadata)
    }

    # Store in ETS
    :ets.insert(:context_attachments, {signal_id, context_entry})

    # Update active contexts
    new_contexts = Map.update(state.active_contexts, signal_id, [context_entry], fn contexts ->
      [context_entry | contexts] |> Enum.take(10)  # Keep last 10 contexts
    end)

    # Update stats
    new_stats = Map.update!(state.context_stats, :attachments_created, &(&1 + 1))

    {:reply, {:ok, context_entry}, %{state | 
      active_contexts: new_contexts,
      context_stats: new_stats
    }}
  end

  @impl true
  def handle_call({:filter_context_by_phase, system_phase, signal_data}, _from, state) do
    phase_config = state.phase_filters[system_phase]
    
    if phase_config do
      filtered_context = apply_phase_filtering(signal_data, phase_config)
      weighted_signals = apply_context_weighting(filtered_context, phase_config.context_weight)
      
      result = %{
        filtered_signals: weighted_signals,
        focus_area: phase_config.focus,
        priority_signals: phase_config.signal_priority,
        semantic_context: phase_config.semantic_tags
      }
      
      {:reply, {:ok, result}, state}
    else
      {:reply, {:error, :unknown_phase}, state}
    end
  end

  @impl true
  def handle_call({:build_semantic_block, signal_id, analysis_results, context}, _from, state) do
    semantic_block = construct_xml_semantic_block(signal_id, analysis_results, context)
    
    # Store semantic block
    :ets.insert(:semantic_blocks, {signal_id, semantic_block})
    
    # Update stats
    new_stats = Map.update!(state.context_stats, :semantic_blocks_built, &(&1 + 1))
    
    {:reply, {:ok, semantic_block}, %{state | context_stats: new_stats}}
  end

  @impl true
  def handle_call({:track_gepa_performance, prompt_id, efficiency_metrics}, _from, state) do
    performance_entry = %{
      prompt_id: prompt_id,
      timestamp: System.monotonic_time(:microsecond),
      efficiency_metrics: efficiency_metrics,
      baseline_comparison: calculate_baseline_comparison(efficiency_metrics),
      toward_35x_target: calculate_35x_progress(efficiency_metrics)
    }

    :ets.insert(:gepa_performance, {prompt_id, performance_entry})
    
    # Update stats
    new_stats = Map.update!(state.context_stats, :performance_tracks, &(&1 + 1))
    
    {:reply, {:ok, performance_entry}, %{state | context_stats: new_stats}}
  end

  @impl true
  def handle_call({:create_meaning_graph_node, signal_id, causal_relationships}, _from, state) do
    # Create node in meaning graph with causal connections
    graph_node = %{
      signal_id: signal_id,
      timestamp: System.monotonic_time(:microsecond),
      causal_relationships: causal_relationships,
      semantic_weight: calculate_semantic_weight(causal_relationships),
      context_coherence: extract_context_coherence(signal_id)
    }

    :ets.insert(:meaning_graph_nodes, {signal_id, graph_node})
    
    # Update stats
    new_stats = Map.update!(state.context_stats, :meaning_nodes_created, &(&1 + 1))
    
    {:reply, {:ok, graph_node}, %{state | context_stats: new_stats}}
  end

  @impl true
  def handle_call({:inject_dynamic_context, signal_id, current_phase, signal_coherence}, _from, state) do
    # Dynamic context injection based on current system state
    dynamic_context = build_dynamic_context(signal_id, current_phase, signal_coherence)
    
    # Cache the dynamic context
    cache_key = "#{signal_id}_#{current_phase}"
    :ets.insert(:context_cache, {cache_key, dynamic_context})
    
    {:reply, {:ok, dynamic_context}, state}
  end

  # Context Processing Functions

  defp calculate_context_coherence(metadata) do
    # Calculate how well the context fits with existing patterns
    semantic_score = calculate_semantic_consistency(metadata)
    temporal_score = calculate_temporal_consistency(metadata)
    causal_score = calculate_causal_consistency(metadata)
    
    (semantic_score + temporal_score + causal_score) / 3.0
  end

  defp apply_phase_filtering(signal_data, phase_config) do
    # Filter signals based on phase priority
    Enum.filter(signal_data, fn signal ->
      signal_type = extract_signal_type(signal)
      signal_type in phase_config.signal_priority or 
      signal.importance_score >= phase_config.context_weight
    end)
  end

  defp apply_context_weighting(signals, context_weight) do
    Enum.map(signals, fn signal ->
      %{signal | 
        weighted_value: signal.value * context_weight,
        context_influence: context_weight,
        adjusted_importance: signal.importance_score * context_weight
      }
    end)
  end

  defp construct_xml_semantic_block(signal_id, analysis_results, context) do
    phase_tags = get_phase_semantic_tags(context[:current_phase])
    causal_tags = build_causal_xml_tags(context[:causal_relationships])
    
    xml_block = """
    <telemetry-context signal-id="#{signal_id}" timestamp="#{System.monotonic_time(:microsecond)}">
      #{phase_tags}
      <analysis-results>
        #{format_analysis_as_xml(analysis_results)}
      </analysis-results>
      <causal-chain>
        #{causal_tags}
      </causal-chain>
      <coherence-metrics>
        <signal-coherence>#{context[:signal_coherence] || 0.8}</signal-coherence>
        <context-weight>#{context[:context_weight] || 0.9}</context-weight>
        <semantic-consistency>#{calculate_semantic_consistency(context)}</semantic-consistency>
      </coherence-metrics>
      <performance-context>
        <efficiency-target>35x</efficiency-target>
        <current-efficiency>#{context[:current_efficiency] || "baseline"}</current-efficiency>
      </performance-context>
    </telemetry-context>
    """

    %{
      xml_content: xml_block,
      parsed_structure: parse_semantic_structure(xml_block),
      context_metadata: context,
      coherence_score: calculate_context_coherence(context)
    }
  end

  defp get_phase_semantic_tags(phase) when is_atom(phase) do
    tags = @phase_contexts[phase][:semantic_tags] || []
    Enum.join(tags, "\n    ")
  end
  defp get_phase_semantic_tags(_), do: ""

  defp build_causal_xml_tags(nil), do: ""
  defp build_causal_xml_tags(relationships) when is_list(relationships) do
    Enum.map(relationships, fn rel ->
      """
      <causal-link>
        <cause>#{rel[:cause]}</cause>
        <effect>#{rel[:effect]}</effect>
        <strength>#{rel[:strength] || 0.7}</strength>
        <temporal-delay>#{rel[:delay] || 0}ms</temporal-delay>
      </causal-link>
      """
    end)
    |> Enum.join("\n      ")
  end
  defp build_causal_xml_tags(_), do: ""

  defp format_analysis_as_xml(analysis_results) when is_map(analysis_results) do
    Enum.map(analysis_results, fn {key, value} ->
      "<#{key}>#{format_value_as_xml(value)}</#{key}>"
    end)
    |> Enum.join("\n        ")
  end
  defp format_analysis_as_xml(_), do: ""

  defp format_value_as_xml(value) when is_number(value), do: to_string(value)
  defp format_value_as_xml(value) when is_binary(value), do: value
  defp format_value_as_xml(value) when is_map(value) do
    Jason.encode!(value)
  end
  defp format_value_as_xml(value), do: inspect(value)

  defp calculate_baseline_comparison(efficiency_metrics) do
    baseline_tokens = efficiency_metrics[:baseline_tokens] || 1000
    current_tokens = efficiency_metrics[:current_tokens] || 1000
    
    improvement_ratio = baseline_tokens / max(current_tokens, 1)
    
    %{
      improvement_ratio: improvement_ratio,
      tokens_saved: baseline_tokens - current_tokens,
      efficiency_gain: (improvement_ratio - 1.0) * 100
    }
  end

  defp calculate_35x_progress(efficiency_metrics) do
    current_efficiency = efficiency_metrics[:efficiency_ratio] || 1.0
    target_efficiency = 35.0
    
    progress_percentage = (current_efficiency / target_efficiency) * 100
    
    %{
      current_efficiency: current_efficiency,
      target_efficiency: target_efficiency,
      progress_percentage: min(progress_percentage, 100.0),
      remaining_improvement: max(target_efficiency - current_efficiency, 0)
    }
  end

  defp calculate_semantic_weight(causal_relationships) when is_list(causal_relationships) do
    # Weight based on number and strength of causal connections
    total_strength = Enum.reduce(causal_relationships, 0.0, fn rel, acc ->
      acc + (rel[:strength] || 0.5)
    end)
    
    connection_count = length(causal_relationships)
    
    # Normalize to 0-1 range
    base_weight = min(total_strength / max(connection_count, 1), 1.0)
    
    # Bonus for multiple strong connections
    if connection_count > 3 and base_weight > 0.8 do
      min(base_weight * 1.2, 1.0)
    else
      base_weight
    end
  end
  defp calculate_semantic_weight(_), do: 0.5

  defp extract_context_coherence(signal_id) do
    case :ets.lookup(:context_attachments, signal_id) do
      [{^signal_id, context_entry}] -> context_entry.coherence_score
      [] -> 0.5
    end
  end

  defp build_dynamic_context(signal_id, current_phase, signal_coherence) do
    # Get recent patterns for this signal
    recent_patterns = get_recent_patterns(signal_id)
    
    # Get cross-signal correlations
    correlations = get_signal_correlations(signal_id)
    
    # Build phase-aware context
    phase_context = @phase_contexts[current_phase]
    
    %{
      signal_id: signal_id,
      current_phase: current_phase,
      signal_coherence: signal_coherence,
      recent_patterns: recent_patterns,
      cross_correlations: correlations,
      phase_focus: phase_context[:focus],
      context_weight: phase_context[:context_weight],
      dynamic_tags: generate_dynamic_tags(recent_patterns, correlations),
      temporal_context: build_temporal_context(signal_id),
      causal_influence: calculate_causal_influence(signal_id, correlations)
    }
  end

  defp get_recent_patterns(signal_id) do
    # Get patterns detected in the last few minutes
    case PatternDetector.detect_patterns(signal_id, :all) do
      {:ok, patterns} -> patterns
      _ -> %{}
    end
  end

  defp get_signal_correlations(signal_id) do
    # Get correlations with other active signals
    all_signals = get_all_active_signals()
    other_signals = Enum.filter(all_signals, &(&1 != signal_id))
    
    case PatternDetector.correlate_patterns([signal_id | other_signals]) do
      {:ok, correlation_data} -> correlation_data.significant_pairs
      _ -> []
    end
  end

  defp get_all_active_signals do
    # Get list of all currently active signal IDs
    :ets.tab2list(:signal_buffers)
    |> Enum.map(fn {signal_id, _} -> signal_id end)
  end

  defp generate_dynamic_tags(patterns, correlations) do
    pattern_tags = Enum.map(Map.keys(patterns), fn pattern_type ->
      "<pattern type=\"#{pattern_type}\" detected=\"true\" />"
    end)
    
    correlation_tags = Enum.map(correlations, fn corr ->
      "<correlation strength=\"#{corr.correlation}\" relationship=\"#{corr.relationship}\" />"
    end)
    
    pattern_tags ++ correlation_tags
  end

  defp build_temporal_context(signal_id) do
    # Build context about temporal patterns and timing
    now = System.monotonic_time(:microsecond)
    
    %{
      current_timestamp: now,
      time_of_day: extract_time_of_day(),
      temporal_phase: determine_temporal_phase(now),
      recent_activity_level: calculate_recent_activity(signal_id)
    }
  end

  defp calculate_causal_influence(signal_id, correlations) do
    # Calculate how much this signal influences others vs. being influenced
    influencing = Enum.count(correlations, fn corr ->
      {i, j} = corr.signals
      i == get_signal_index(signal_id) and corr.correlation > 0.7
    end)
    
    influenced_by = Enum.count(correlations, fn corr ->
      {i, j} = corr.signals
      j == get_signal_index(signal_id) and corr.correlation > 0.7
    end)
    
    total = influencing + influenced_by
    
    if total > 0 do
      %{
        influence_ratio: influencing / total,
        total_connections: total,
        role: determine_causal_role(influencing, influenced_by)
      }
    else
      %{influence_ratio: 0.5, total_connections: 0, role: :isolated}
    end
  end

  # Helper Functions

  defp calculate_semantic_consistency(metadata) when is_map(metadata) do
    # Check consistency with existing semantic patterns
    keys = Map.keys(metadata)
    expected_keys = [:source, :importance, :context_type, :temporal_info]
    
    key_overlap = length(Enum.filter(keys, &(&1 in expected_keys)))
    base_score = key_overlap / length(expected_keys)
    
    # Bonus for semantic richness
    richness_bonus = if length(keys) > 5, do: 0.1, else: 0.0
    
    min(base_score + richness_bonus, 1.0)
  end
  defp calculate_semantic_consistency(_), do: 0.5

  defp calculate_temporal_consistency(metadata) do
    # Check if temporal information is consistent
    if metadata[:timestamp] do
      now = System.monotonic_time(:microsecond)
      time_diff = abs(now - metadata[:timestamp])
      
      # Recent timestamps get higher consistency
      if time_diff < 60_000_000 do  # 1 minute
        1.0
      else
        max(0.1, 1.0 - (time_diff / 600_000_000))  # Decay over 10 minutes
      end
    else
      0.5
    end
  end

  defp calculate_causal_consistency(metadata) do
    # Check if causal relationships make sense
    if metadata[:causal_relationships] do
      relationships = metadata[:causal_relationships]
      
      # Check for logical consistency (no circular causality, etc.)
      circular_score = check_circular_causality(relationships)
      strength_score = check_causal_strength_consistency(relationships)
      
      (circular_score + strength_score) / 2.0
    else
      0.7  # Neutral score for no causal info
    end
  end

  defp extract_signal_type(signal) do
    signal[:type] || signal[:signal_type] || :unknown
  end

  defp parse_semantic_structure(xml_content) do
    # Simple XML parsing for semantic structure
    # In production, would use proper XML parser
    %{
      has_analysis: String.contains?(xml_content, "<analysis-results>"),
      has_causal_chain: String.contains?(xml_content, "<causal-chain>"),
      has_coherence: String.contains?(xml_content, "<coherence-metrics>"),
      has_performance: String.contains?(xml_content, "<performance-context>")
    }
  end

  defp extract_time_of_day do
    {:ok, dt} = DateTime.now("Etc/UTC")
    dt.hour
  end

  defp determine_temporal_phase(timestamp) do
    # Determine what temporal phase we're in (morning, afternoon, etc.)
    hour = extract_time_of_day()
    
    cond do
      hour < 6 -> :night
      hour < 12 -> :morning  
      hour < 18 -> :afternoon
      true -> :evening
    end
  end

  defp calculate_recent_activity(signal_id) do
    # Calculate activity level in recent time window
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] ->
        samples = :queue.to_list(buffer)
        recent_samples = Enum.take(samples, -10)  # Last 10 samples
        
        if length(recent_samples) > 1 do
          values = Enum.map(recent_samples, & &1.value)
          std_dev = Statistics.standard_deviation(values)
          
          cond do
            std_dev > 1.0 -> :high
            std_dev > 0.5 -> :medium
            true -> :low
          end
        else
          :unknown
        end
      [] -> :no_data
    end
  end

  defp get_signal_index(signal_id) do
    # Convert signal_id to index for correlation matrix
    # Simplified implementation
    :erlang.phash2(signal_id, 1000)
  end

  defp determine_causal_role(influencing, influenced_by) do
    cond do
      influencing > influenced_by * 1.5 -> :influencer
      influenced_by > influencing * 1.5 -> :follower
      true -> :bidirectional
    end
  end

  defp check_circular_causality(relationships) when is_list(relationships) do
    # Simple check for circular causality
    causes = Enum.map(relationships, & &1[:cause])
    effects = Enum.map(relationships, & &1[:effect])
    
    # Check if any effect is also a cause
    circular_count = length(Enum.filter(effects, &(&1 in causes)))
    total_count = length(relationships)
    
    if total_count > 0 do
      1.0 - (circular_count / total_count)
    else
      1.0
    end
  end
  defp check_circular_causality(_), do: 1.0

  defp check_causal_strength_consistency(relationships) when is_list(relationships) do
    # Check if causal strengths are consistent
    strengths = Enum.map(relationships, & &1[:strength] || 0.5)
    
    if length(strengths) > 1 do
      std_dev = Statistics.standard_deviation(strengths)
      # Lower standard deviation = more consistent
      max(0.0, 1.0 - std_dev)
    else
      1.0
    end
  end
  defp check_causal_strength_consistency(_), do: 1.0
end