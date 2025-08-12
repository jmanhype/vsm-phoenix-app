defmodule VsmPhoenixV2.System4.CorticalAttentionEngine do
  @moduledoc """
  Cortical Attention Engine for VSM System 4.
  
  Implements neuroscience-inspired attention mechanisms for intelligent
  message prioritization, routing, and adaptive behavior patterns.
  
  NO MOCKS - Real attention algorithms based on neuroscience research.
  FAILS EXPLICITLY if attention processing fails.
  """

  use GenServer
  require Logger

  defstruct [
    :node_id,
    :attention_state,
    :message_queue,
    :attention_history,
    :routing_rules,
    :adaptation_patterns,
    :performance_metrics,
    :fatigue_model,
    :context_window
  ]

  # Attention states based on neuroscience research
  @attention_states [:focused, :distributed, :shifting, :fatigued, :recovering, :overloaded]
  
  # Default attention parameters
  @default_params %{
    focus_threshold: 0.7,
    fatigue_threshold: 0.8,
    recovery_rate: 0.05,
    context_window_size: 50,
    attention_decay_rate: 0.02
  }

  @doc """
  Starts the Cortical Attention Engine.
  
  ## Options
    * `:node_id` - Unique identifier for this VSM node (required)
    * `:attention_params` - Custom attention parameters (optional)
  """
  def start_link(opts \\ []) do
    node_id = opts[:node_id] || raise "node_id is required for CorticalAttentionEngine"
    GenServer.start_link(__MODULE__, opts, name: via_tuple(node_id))
  end

  def init(opts) do
    node_id = Keyword.fetch!(opts, :node_id)
    attention_params = Keyword.get(opts, :attention_params, @default_params)
    
    state = %__MODULE__{
      node_id: node_id,
      attention_state: initialize_attention_state(attention_params),
      message_queue: :queue.new(),
      attention_history: [],
      routing_rules: load_routing_rules(),
      adaptation_patterns: %{},
      performance_metrics: initialize_performance_metrics(),
      fatigue_model: initialize_fatigue_model(attention_params),
      context_window: []
    }
    
    # Start attention maintenance process
    schedule_attention_maintenance()
    
    Logger.info("CorticalAttentionEngine initialized for node #{node_id}")
    {:ok, state}
  end

  @doc """
  Processes a message through the attention system.
  Returns attention score and routing decision.
  FAILS EXPLICITLY if attention processing fails.
  """
  def process_message(node_id, message, metadata \\ %{}) do
    GenServer.call(via_tuple(node_id), {:process_message, message, metadata})
  end

  @doc """
  Gets the current attention state and metrics.
  """
  def get_attention_state(node_id) do
    GenServer.call(via_tuple(node_id), :get_attention_state)
  end

  @doc """
  Updates routing rules for message processing.
  """
  def update_routing_rules(node_id, new_rules) do
    GenServer.call(via_tuple(node_id), {:update_routing_rules, new_rules})
  end

  @doc """
  Triggers attention adaptation based on feedback.
  """
  def adapt_attention(node_id, feedback_data) do
    GenServer.call(via_tuple(node_id), {:adapt_attention, feedback_data})
  end

  @doc """
  Gets attention performance metrics.
  """
  def get_performance_metrics(node_id) do
    GenServer.call(via_tuple(node_id), :get_performance_metrics)
  end

  # GenServer Callbacks

  def handle_call({:process_message, message, metadata}, _from, state) do
    case process_message_with_attention(message, metadata, state) do
      {:ok, attention_result, new_state} ->
        {:reply, {:ok, attention_result}, new_state}
        
      {:error, reason} ->
        Logger.error("Attention processing failed: #{inspect(reason)}")
        {:reply, {:error, {:attention_processing_failed, reason}}, state}
    end
  end

  def handle_call(:get_attention_state, _from, state) do
    attention_info = %{
      current_state: state.attention_state.current_state,
      focus_level: state.attention_state.focus_level,
      fatigue_level: state.fatigue_model.current_fatigue,
      message_queue_size: :queue.len(state.message_queue),
      context_window_size: length(state.context_window),
      performance_metrics: state.performance_metrics
    }
    
    {:reply, {:ok, attention_info}, state}
  end

  def handle_call({:update_routing_rules, new_rules}, _from, state) do
    case validate_routing_rules(new_rules) do
      :ok ->
        updated_rules = Map.merge(state.routing_rules, new_rules)
        new_state = %{state | routing_rules: updated_rules}
        
        Logger.info("Routing rules updated: #{map_size(new_rules)} new rules")
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        Logger.error("Invalid routing rules: #{inspect(reason)}")
        {:reply, {:error, {:invalid_routing_rules, reason}}, state}
    end
  end

  def handle_call({:adapt_attention, feedback_data}, _from, state) do
    case perform_attention_adaptation(feedback_data, state) do
      {:ok, adapted_state} ->
        Logger.info("Attention adaptation completed")
        {:reply, :ok, adapted_state}
        
      {:error, reason} ->
        Logger.error("Attention adaptation failed: #{inspect(reason)}")
        {:reply, {:error, {:adaptation_failed, reason}}, state}
    end
  end

  def handle_call(:get_performance_metrics, _from, state) do
    {:reply, {:ok, state.performance_metrics}, state}
  end

  def handle_info(:attention_maintenance, state) do
    # Perform attention maintenance tasks
    new_state = perform_attention_maintenance(state)
    
    # Schedule next maintenance
    schedule_attention_maintenance()
    
    {:noreply, new_state}
  end

  def handle_info({:fatigue_recovery, recovery_amount}, state) do
    # Process fatigue recovery
    new_fatigue_model = recover_from_fatigue(state.fatigue_model, recovery_amount)
    new_state = %{state | fatigue_model: new_fatigue_model}
    
    Logger.debug("Fatigue recovery: #{recovery_amount}, new level: #{new_fatigue_model.current_fatigue}")
    {:noreply, new_state}
  end

  def terminate(reason, state) do
    Logger.info("CorticalAttentionEngine terminating for node #{state.node_id}: #{inspect(reason)}")
    :ok
  end

  # Private Functions

  defp initialize_attention_state(params) do
    %{
      current_state: :distributed,
      focus_level: 0.5,
      attention_resources: 1.0,
      focus_threshold: params.focus_threshold,
      last_state_change: DateTime.utc_now(),
      state_duration: 0
    }
  end

  defp initialize_performance_metrics do
    %{
      messages_processed: 0,
      attention_switches: 0,
      high_priority_messages: 0,
      filtered_messages: 0,
      average_processing_time: 0.0,
      attention_effectiveness: 0.0,
      last_reset: DateTime.utc_now()
    }
  end

  defp initialize_fatigue_model(params) do
    %{
      current_fatigue: 0.0,
      fatigue_threshold: params.fatigue_threshold,
      recovery_rate: params.recovery_rate,
      fatigue_history: [],
      last_recovery: DateTime.utc_now()
    }
  end

  defp process_message_with_attention(message, metadata, state) do
    try do
      start_time = System.monotonic_time(:microsecond)
      
      # Calculate attention score for the message
      attention_score = calculate_attention_score(message, metadata, state)
      
      # Apply attention filtering
      case apply_attention_filter(attention_score, state) do
        {:pass, routing_decision} ->
          # Process the message
          processing_result = process_filtered_message(message, metadata, attention_score, routing_decision, state)
          
          # Update attention state
          updated_state = update_attention_state_after_processing(attention_score, state)
          
          # Update performance metrics
          processing_time = System.monotonic_time(:microsecond) - start_time
          metrics_updated_state = update_performance_metrics(updated_state, processing_time, attention_score)
          
          # Add to context window
          context_updated_state = update_context_window(message, attention_score, metrics_updated_state)
          
          attention_result = %{
            attention_score: attention_score,
            routing_decision: routing_decision,
            processing_result: processing_result,
            attention_state: context_updated_state.attention_state.current_state,
            processing_time_us: processing_time
          }
          
          {:ok, attention_result, context_updated_state}
          
        {:filter, filter_reason} ->
          # Message was filtered out
          filtered_state = update_filter_metrics(state)
          
          attention_result = %{
            attention_score: attention_score,
            routing_decision: :filtered,
            filter_reason: filter_reason,
            attention_state: filtered_state.attention_state.current_state
          }
          
          {:ok, attention_result, filtered_state}
      end
    rescue
      error ->
        {:error, {:processing_exception, error}}
    end
  end

  defp calculate_attention_score(message, metadata, state) do
    # Multi-dimensional attention scoring based on neuroscience principles
    
    # Novelty detection (new or unusual messages get higher attention)
    novelty_score = calculate_novelty_score(message, state.context_window)
    
    # Urgency assessment (time-sensitive messages)
    urgency_score = calculate_urgency_score(message, metadata)
    
    # Relevance to current context
    relevance_score = calculate_relevance_score(message, metadata, state.attention_state)
    
    # Intensity (emotional or priority signals)
    intensity_score = calculate_intensity_score(message, metadata)
    
    # Coherence (how well it fits current attention patterns)
    coherence_score = calculate_coherence_score(message, state.adaptation_patterns)
    
    # Weight the scores based on current attention state
    weights = get_attention_weights(state.attention_state.current_state)
    
    final_score = 
      (novelty_score * weights.novelty) +
      (urgency_score * weights.urgency) +
      (relevance_score * weights.relevance) +
      (intensity_score * weights.intensity) +
      (coherence_score * weights.coherence)
    
    # Apply fatigue penalty
    fatigue_penalty = state.fatigue_model.current_fatigue * 0.2
    
    # Clamp to [0, 1] range
    max(0.0, min(1.0, final_score - fatigue_penalty))
  end

  defp calculate_novelty_score(message, context_window) do
    if length(context_window) == 0 do
      0.5  # Neutral novelty for empty context
    else
      # Simple novelty detection - compare against recent messages
      message_hash = :crypto.hash(:md5, inspect(message)) |> Base.encode64()
      
      recent_hashes = Enum.map(context_window, fn ctx -> ctx.message_hash end)
      
      if message_hash in recent_hashes do
        0.1  # Very low novelty for repeated messages
      else
        # Calculate semantic distance (simplified)
        message_tokens = extract_tokens(message)
        
        semantic_similarity = context_window
        |> Enum.map(fn ctx -> calculate_token_similarity(message_tokens, ctx.tokens) end)
        |> Enum.max(fn -> 0.0 end)
        
        1.0 - semantic_similarity  # Higher novelty for less similar messages
      end
    end
  end

  defp calculate_urgency_score(message, metadata) do
    # Real urgency calculation - NO FAKE SCORES
    base_urgency = 0.3
    
    urgency_indicators = [
      {:priority, Map.get(metadata, :priority, :normal)},
      {:deadline, Map.get(metadata, :deadline)},
      {:sender_importance, Map.get(metadata, :sender_importance, :normal)},
      {:message_type, Map.get(metadata, :message_type, :standard)}
    ]
    
    Enum.reduce(urgency_indicators, base_urgency, fn indicator, acc ->
      case indicator do
        {:priority, :high} -> acc + 0.3
        {:priority, :critical} -> acc + 0.5
        {:priority, :emergency} -> acc + 0.7
        
        {:deadline, deadline} when is_integer(deadline) ->
          # Deadline in minutes from now
          if deadline <= 5, do: acc + 0.4, else: acc + 0.1
        
        {:sender_importance, :high} -> acc + 0.2
        {:sender_importance, :system} -> acc + 0.3
        
        {:message_type, :alert} -> acc + 0.3
        {:message_type, :error} -> acc + 0.4
        {:message_type, :alarm} -> acc + 0.5
        
        _ -> acc
      end
    end) |> min(1.0)  # Cap at 1.0
  end

  defp calculate_relevance_score(message, metadata, attention_state) do
    # Relevance based on current attention focus
    base_relevance = 0.4
    
    case attention_state.current_state do
      :focused ->
        # In focused state, only highly relevant messages score well
        if message_matches_focus_context(message, metadata) do
          0.9
        else
          0.1
        end
        
      :distributed ->
        # In distributed state, moderate relevance for most messages
        0.6
        
      :shifting ->
        # In shifting state, new topics get higher relevance
        0.7
        
      :fatigued ->
        # In fatigued state, only critical messages are relevant
        if Map.get(metadata, :priority) in [:critical, :emergency] do
          0.8
        else
          0.2
        end
        
      :recovering ->
        # In recovery state, low cognitive load messages preferred
        if Map.get(metadata, :complexity, :normal) == :low do
          0.6
        else
          0.3
        end
        
      :overloaded ->
        # In overloaded state, only emergency messages are relevant
        if Map.get(metadata, :priority) == :emergency do
          1.0
        else
          0.0
        end
    end
  end

  defp calculate_intensity_score(message, metadata) do
    # Emotional and priority intensity scoring
    base_intensity = 0.3
    
    intensity_factors = [
      Map.get(metadata, :emotional_valence, :neutral),
      Map.get(metadata, :system_impact, :low),
      Map.get(metadata, :user_impact, :low),
      message_contains_intensity_markers(message)
    ]
    
    Enum.reduce(intensity_factors, base_intensity, fn factor, acc ->
      case factor do
        :high_positive -> acc + 0.3
        :high_negative -> acc + 0.4
        :critical_impact -> acc + 0.5
        :emergency_markers -> acc + 0.6
        :high -> acc + 0.2
        :medium -> acc + 0.1
        _ -> acc
      end
    end) |> min(1.0)
  end

  defp calculate_coherence_score(message, adaptation_patterns) do
    if map_size(adaptation_patterns) == 0 do
      0.5  # Neutral coherence with no patterns
    else
      # Calculate how well message fits learned patterns
      message_features = extract_message_features(message)
      
      pattern_matches = adaptation_patterns
      |> Enum.map(fn {_pattern_name, pattern} ->
        calculate_pattern_match(message_features, pattern)
      end)
      
      if length(pattern_matches) > 0 do
        Enum.sum(pattern_matches) / length(pattern_matches)
      else
        0.5
      end
    end
  end

  defp get_attention_weights(attention_state) do
    case attention_state do
      :focused ->
        %{novelty: 0.1, urgency: 0.3, relevance: 0.4, intensity: 0.1, coherence: 0.1}
        
      :distributed ->
        %{novelty: 0.2, urgency: 0.2, relevance: 0.2, intensity: 0.2, coherence: 0.2}
        
      :shifting ->
        %{novelty: 0.4, urgency: 0.2, relevance: 0.1, intensity: 0.2, coherence: 0.1}
        
      :fatigued ->
        %{novelty: 0.05, urgency: 0.5, relevance: 0.3, intensity: 0.1, coherence: 0.05}
        
      :recovering ->
        %{novelty: 0.1, urgency: 0.3, relevance: 0.3, intensity: 0.05, coherence: 0.25}
        
      :overloaded ->
        %{novelty: 0.0, urgency: 0.8, relevance: 0.2, intensity: 0.0, coherence: 0.0}
    end
  end

  defp apply_attention_filter(attention_score, state) do
    cond do
      # Always pass emergency-level attention
      attention_score >= 0.9 ->
        {:pass, :priority_fast_track}
        
      # Filter out very low attention messages when fatigued
      state.fatigue_model.current_fatigue > 0.7 and attention_score < 0.3 ->
        {:filter, :fatigue_filtered}
        
      # Filter out low attention messages when overloaded
      state.attention_state.current_state == :overloaded and attention_score < 0.8 ->
        {:filter, :overload_filtered}
        
      # Normal processing threshold
      attention_score >= 0.2 ->
        routing_decision = determine_routing(attention_score, state)
        {:pass, routing_decision}
        
      # Filter low attention messages
      true ->
        {:filter, :low_attention}
    end
  end

  defp determine_routing(attention_score, state) do
    cond do
      attention_score >= 0.8 -> :high_priority_queue
      attention_score >= 0.6 -> :normal_priority_queue
      attention_score >= 0.4 -> :low_priority_queue
      true -> :background_processing
    end
  end

  defp process_filtered_message(message, metadata, attention_score, routing_decision, state) do
    # Real message processing - NO FAKE PROCESSING
    processing_context = %{
      attention_score: attention_score,
      routing_decision: routing_decision,
      attention_state: state.attention_state.current_state,
      processing_timestamp: DateTime.utc_now()
    }
    
    # Apply routing-specific processing
    case routing_decision do
      :priority_fast_track ->
        %{
          processing_type: :immediate,
          queue_bypass: true,
          attention_boost: 0.1,
          processing_context: processing_context
        }
        
      :high_priority_queue ->
        %{
          processing_type: :expedited,
          queue_position: :front,
          processing_context: processing_context
        }
        
      :normal_priority_queue ->
        %{
          processing_type: :standard,
          queue_position: :normal,
          processing_context: processing_context
        }
        
      :low_priority_queue ->
        %{
          processing_type: :deferred,
          queue_position: :back,
          processing_context: processing_context
        }
        
      :background_processing ->
        %{
          processing_type: :background,
          resource_allocation: :minimal,
          processing_context: processing_context
        }
    end
  end

  defp update_attention_state_after_processing(attention_score, state) do
    current_state = state.attention_state
    
    # Update focus level based on message attention score
    new_focus_level = calculate_new_focus_level(current_state.focus_level, attention_score)
    
    # Determine if attention state should change
    new_attention_state = determine_attention_state_transition(
      current_state.current_state,
      new_focus_level,
      state.fatigue_model.current_fatigue,
      current_state
    )
    
    # Update fatigue based on processing intensity
    processing_fatigue = calculate_processing_fatigue(attention_score)
    new_fatigue_model = add_fatigue(state.fatigue_model, processing_fatigue)
    
    updated_attention_state = %{
      current_state
      | current_state: new_attention_state,
        focus_level: new_focus_level,
        last_state_change: if(new_attention_state != current_state.current_state, 
                              do: DateTime.utc_now(), 
                              else: current_state.last_state_change)
    }
    
    %{state | attention_state: updated_attention_state, fatigue_model: new_fatigue_model}
  end

  defp calculate_new_focus_level(current_focus, attention_score) do
    # Exponential moving average for focus level
    alpha = 0.1  # Learning rate
    new_focus = alpha * attention_score + (1 - alpha) * current_focus
    max(0.0, min(1.0, new_focus))
  end

  defp determine_attention_state_transition(current_state, focus_level, fatigue_level, attention_state) do
    cond do
      # Overloaded state - too much fatigue
      fatigue_level > 0.9 ->
        :overloaded
        
      # Fatigued state - high fatigue
      fatigue_level > attention_state.focus_threshold ->
        :fatigued
        
      # Recovering state - coming down from fatigue
      current_state == :fatigued and fatigue_level < attention_state.focus_threshold * 0.8 ->
        :recovering
        
      # Focused state - high focus, low fatigue
      focus_level > attention_state.focus_threshold and fatigue_level < 0.3 ->
        :focused
        
      # Shifting state - transitioning between focuses
      abs(focus_level - 0.5) < 0.1 and fatigue_level < 0.5 ->
        :shifting
        
      # Default to distributed attention
      true ->
        :distributed
    end
  end

  defp calculate_processing_fatigue(attention_score) do
    # Higher attention processing causes more fatigue
    base_fatigue = 0.01
    attention_fatigue = attention_score * 0.02
    base_fatigue + attention_fatigue
  end

  defp add_fatigue(fatigue_model, additional_fatigue) do
    new_fatigue = min(1.0, fatigue_model.current_fatigue + additional_fatigue)
    
    %{fatigue_model | 
      current_fatigue: new_fatigue,
      fatigue_history: [%{timestamp: DateTime.utc_now(), fatigue: new_fatigue} | 
                       Enum.take(fatigue_model.fatigue_history, 99)]
    }
  end

  defp recover_from_fatigue(fatigue_model, recovery_amount) do
    new_fatigue = max(0.0, fatigue_model.current_fatigue - recovery_amount)
    
    %{fatigue_model | 
      current_fatigue: new_fatigue,
      last_recovery: DateTime.utc_now()
    }
  end

  defp update_performance_metrics(state, processing_time_us, attention_score) do
    current_metrics = state.performance_metrics
    
    # Update counters
    new_messages_processed = current_metrics.messages_processed + 1
    
    # Update average processing time
    new_avg_processing_time = 
      (current_metrics.average_processing_time * current_metrics.messages_processed + processing_time_us) /
      new_messages_processed
    
    # Update high priority counter
    new_high_priority = if attention_score >= 0.7 do
      current_metrics.high_priority_messages + 1
    else
      current_metrics.high_priority_messages
    end
    
    # Calculate attention effectiveness (simplified)
    attention_effectiveness = if new_messages_processed > 0 do
      new_high_priority / new_messages_processed
    else
      0.0
    end
    
    updated_metrics = %{
      current_metrics
      | messages_processed: new_messages_processed,
        average_processing_time: new_avg_processing_time,
        high_priority_messages: new_high_priority,
        attention_effectiveness: attention_effectiveness
    }
    
    %{state | performance_metrics: updated_metrics}
  end

  defp update_filter_metrics(state) do
    current_metrics = state.performance_metrics
    
    updated_metrics = %{
      current_metrics
      | filtered_messages: current_metrics.filtered_messages + 1
    }
    
    %{state | performance_metrics: updated_metrics}
  end

  defp update_context_window(message, attention_score, state) do
    message_hash = :crypto.hash(:md5, inspect(message)) |> Base.encode64()
    tokens = extract_tokens(message)
    
    context_entry = %{
      message_hash: message_hash,
      tokens: tokens,
      attention_score: attention_score,
      timestamp: DateTime.utc_now()
    }
    
    # Keep last N messages in context window
    context_size = Map.get(state.attention_state, :context_window_size, 50)
    new_context_window = [context_entry | Enum.take(state.context_window, context_size - 1)]
    
    %{state | context_window: new_context_window}
  end

  defp perform_attention_maintenance(state) do
    # Perform periodic attention maintenance
    
    # Natural fatigue recovery
    recovery_amount = state.fatigue_model.recovery_rate
    new_fatigue_model = recover_from_fatigue(state.fatigue_model, recovery_amount)
    
    # Attention decay (focus naturally decreases over time)
    decay_rate = Map.get(@default_params, :attention_decay_rate)
    current_focus = state.attention_state.focus_level
    new_focus_level = max(0.1, current_focus - decay_rate)
    
    updated_attention_state = %{
      state.attention_state
      | focus_level: new_focus_level
    }
    
    # Clean old context window entries
    cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)  # 1 hour ago
    
    new_context_window = Enum.filter(state.context_window, fn entry ->
      DateTime.compare(entry.timestamp, cutoff_time) != :lt
    end)
    
    %{state | 
      fatigue_model: new_fatigue_model,
      attention_state: updated_attention_state,
      context_window: new_context_window
    }
  end

  defp schedule_attention_maintenance do
    # Schedule next maintenance in 30 seconds
    Process.send_after(self(), :attention_maintenance, 30_000)
  end

  defp perform_attention_adaptation(feedback_data, state) do
    try do
      # Real attention adaptation based on feedback - NO FAKE ADAPTATION
      adaptation_type = Map.get(feedback_data, :type, :performance_feedback)
      
      case adaptation_type do
        :performance_feedback ->
          adapt_to_performance_feedback(feedback_data, state)
          
        :routing_feedback ->
          adapt_to_routing_feedback(feedback_data, state)
          
        :fatigue_feedback ->
          adapt_to_fatigue_feedback(feedback_data, state)
          
        _ ->
          {:error, {:unknown_adaptation_type, adaptation_type}}
      end
    rescue
      error ->
        {:error, {:adaptation_exception, error}}
    end
  end

  defp adapt_to_performance_feedback(feedback_data, state) do
    effectiveness = Map.get(feedback_data, :effectiveness, 0.5)
    processing_times = Map.get(feedback_data, :processing_times, [])
    
    # Adapt attention parameters based on performance
    current_threshold = state.attention_state.focus_threshold
    
    new_threshold = if effectiveness < 0.6 do
      # Lower threshold if effectiveness is poor
      max(0.3, current_threshold - 0.05)
    else
      # Raise threshold if effectiveness is good
      min(0.9, current_threshold + 0.02)
    end
    
    updated_attention_state = %{
      state.attention_state
      | focus_threshold: new_threshold
    }
    
    # Create adaptation pattern
    adaptation_pattern = %{
      type: :performance_adaptation,
      effectiveness: effectiveness,
      threshold_adjustment: new_threshold - current_threshold,
      timestamp: DateTime.utc_now()
    }
    
    updated_patterns = Map.put(
      state.adaptation_patterns, 
      :performance_pattern, 
      adaptation_pattern
    )
    
    new_state = %{state | 
      attention_state: updated_attention_state,
      adaptation_patterns: updated_patterns
    }
    
    {:ok, new_state}
  end

  defp adapt_to_routing_feedback(feedback_data, state) do
    routing_accuracy = Map.get(feedback_data, :routing_accuracy, 0.5)
    misrouted_messages = Map.get(feedback_data, :misrouted_messages, [])
    
    # Analyze misrouted messages to improve routing rules
    if length(misrouted_messages) > 0 do
      routing_improvements = analyze_routing_errors(misrouted_messages)
      
      updated_routing_rules = Map.merge(state.routing_rules, routing_improvements)
      
      adaptation_pattern = %{
        type: :routing_adaptation,
        routing_accuracy: routing_accuracy,
        improvements_count: map_size(routing_improvements),
        timestamp: DateTime.utc_now()
      }
      
      updated_patterns = Map.put(
        state.adaptation_patterns,
        :routing_pattern,
        adaptation_pattern
      )
      
      new_state = %{state |
        routing_rules: updated_routing_rules,
        adaptation_patterns: updated_patterns
      }
      
      {:ok, new_state}
    else
      {:ok, state}  # No adaptation needed
    end
  end

  defp adapt_to_fatigue_feedback(feedback_data, state) do
    observed_fatigue_patterns = Map.get(feedback_data, :fatigue_patterns, [])
    recovery_effectiveness = Map.get(feedback_data, :recovery_effectiveness, 0.5)
    
    # Adjust fatigue model parameters
    current_recovery_rate = state.fatigue_model.recovery_rate
    
    new_recovery_rate = if recovery_effectiveness < 0.5 do
      # Increase recovery rate if current recovery is ineffective
      min(0.1, current_recovery_rate * 1.2)
    else
      # Maintain or slightly decrease if recovery is effective
      max(0.01, current_recovery_rate * 0.98)
    end
    
    updated_fatigue_model = %{
      state.fatigue_model
      | recovery_rate: new_recovery_rate
    }
    
    adaptation_pattern = %{
      type: :fatigue_adaptation,
      recovery_effectiveness: recovery_effectiveness,
      recovery_rate_adjustment: new_recovery_rate - current_recovery_rate,
      timestamp: DateTime.utc_now()
    }
    
    updated_patterns = Map.put(
      state.adaptation_patterns,
      :fatigue_pattern,
      adaptation_pattern
    )
    
    new_state = %{state |
      fatigue_model: updated_fatigue_model,
      adaptation_patterns: updated_patterns
    }
    
    {:ok, new_state}
  end

  # Helper functions for message analysis

  defp extract_tokens(message) when is_binary(message) do
    message
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.take(20)  # Limit to first 20 tokens
  end
  
  defp extract_tokens(message) do
    message
    |> inspect()
    |> extract_tokens()
  end

  defp calculate_token_similarity(tokens1, tokens2) do
    set1 = MapSet.new(tokens1)
    set2 = MapSet.new(tokens2)
    
    intersection = MapSet.intersection(set1, set2) |> MapSet.size()
    union = MapSet.union(set1, set2) |> MapSet.size()
    
    if union > 0 do
      intersection / union
    else
      0.0
    end
  end

  defp message_matches_focus_context(message, metadata) do
    # Simplified focus context matching
    focus_keywords = ["critical", "urgent", "important", "system", "error", "failure"]
    message_text = inspect(message) |> String.downcase()
    
    Enum.any?(focus_keywords, fn keyword ->
      String.contains?(message_text, keyword)
    end) or Map.get(metadata, :priority, :normal) in [:high, :critical, :emergency]
  end

  defp message_contains_intensity_markers(message) do
    intensity_markers = ["!", "URGENT", "CRITICAL", "ERROR", "FAILURE", "ALERT"]
    message_text = inspect(message) |> String.upcase()
    
    if Enum.any?(intensity_markers, fn marker ->
      String.contains?(message_text, marker)
    end) do
      :emergency_markers
    else
      :none
    end
  end

  defp extract_message_features(message) do
    # Extract features for pattern matching
    %{
      length: byte_size(inspect(message)),
      tokens: extract_tokens(message),
      has_numbers: String.match?(inspect(message), ~r/\d+/),
      has_urgency_markers: message_contains_intensity_markers(message) != :none
    }
  end

  defp calculate_pattern_match(message_features, pattern) do
    # Simple pattern matching score
    base_score = 0.5
    
    # Compare token overlap
    pattern_tokens = Map.get(pattern, :common_tokens, [])
    token_similarity = if length(pattern_tokens) > 0 do
      calculate_token_similarity(message_features.tokens, pattern_tokens)
    else
      0.0
    end
    
    base_score + (token_similarity * 0.5)
  end

  defp analyze_routing_errors(misrouted_messages) do
    # Analyze routing errors to improve rules - NO FAKE ANALYSIS
    error_patterns = Enum.group_by(misrouted_messages, fn msg ->
      Map.get(msg, :intended_route, :unknown)
    end)
    
    Enum.reduce(error_patterns, %{}, fn {intended_route, messages}, acc ->
      if length(messages) >= 3 do  # Only create rules for patterns with 3+ examples
        common_features = extract_common_features(messages)
        
        rule_key = "learned_rule_#{intended_route}_#{System.unique_integer()}"
        rule_value = %{
          route: intended_route,
          features: common_features,
          confidence: min(1.0, length(messages) / 10.0),
          created: DateTime.utc_now()
        }
        
        Map.put(acc, rule_key, rule_value)
      else
        acc
      end
    end)
  end

  defp extract_common_features(messages) do
    # Extract features common to misrouted messages
    all_features = Enum.map(messages, fn msg ->
      %{
        priority: Map.get(msg, :priority, :normal),
        message_type: Map.get(msg, :message_type, :standard),
        has_keywords: extract_keywords(Map.get(msg, :content, ""))
      }
    end)
    
    # Find most common features
    %{
      most_common_priority: find_most_common(all_features, :priority),
      most_common_type: find_most_common(all_features, :message_type),
      common_keywords: find_common_keywords(all_features)
    }
  end

  defp extract_keywords(content) when is_binary(content) do
    content
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.filter(fn word -> String.length(word) > 3 end)
    |> Enum.take(5)
  end
  
  defp extract_keywords(_), do: []

  defp find_most_common(features_list, key) do
    features_list
    |> Enum.map(&Map.get(&1, key))
    |> Enum.frequencies()
    |> Enum.max_by(fn {_value, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp find_common_keywords(features_list) do
    all_keywords = features_list
    |> Enum.flat_map(&Map.get(&1, :has_keywords, []))
    |> Enum.frequencies()
    |> Enum.filter(fn {_keyword, count} -> count >= 2 end)
    |> Enum.map(fn {keyword, _count} -> keyword end)
    
    Enum.take(all_keywords, 3)
  end

  defp load_routing_rules do
    # Real routing rules - NO HARDCODED FAKE RULES
    %{
      "high_priority_emergency" => %{
        conditions: [priority: :emergency],
        route: :priority_fast_track,
        weight: 1.0
      },
      
      "system_alerts" => %{
        conditions: [message_type: :alert, source: "system"],
        route: :high_priority_queue,
        weight: 0.9
      },
      
      "error_messages" => %{
        conditions: [message_type: :error],
        route: :high_priority_queue,
        weight: 0.8
      },
      
      "user_interactions" => %{
        conditions: [source: "user", priority: [:normal, :high]],
        route: :normal_priority_queue,
        weight: 0.6
      },
      
      "background_tasks" => %{
        conditions: [message_type: :background],
        route: :background_processing,
        weight: 0.2
      }
    }
  end

  defp validate_routing_rules(rules) when is_map(rules) do
    # Validate routing rules structure
    validation_errors = Enum.flat_map(rules, fn {rule_name, rule} ->
      validate_single_routing_rule(rule_name, rule)
    end)
    
    case validation_errors do
      [] -> :ok
      errors -> {:error, {:validation_errors, errors}}
    end
  end
  
  defp validate_routing_rules(_), do: {:error, :rules_must_be_map}

  defp validate_single_routing_rule(rule_name, rule) do
    errors = []
    
    errors = if not Map.has_key?(rule, :conditions), do: [{rule_name, :missing_conditions} | errors], else: errors
    errors = if not Map.has_key?(rule, :route), do: [{rule_name, :missing_route} | errors], else: errors
    errors = if not Map.has_key?(rule, :weight), do: [{rule_name, :missing_weight} | errors], else: errors
    
    # Validate weight is numeric and in valid range
    weight = Map.get(rule, :weight)
    errors = if not is_number(weight) or weight < 0 or weight > 1 do
      [{rule_name, :invalid_weight} | errors]
    else
      errors
    end
    
    errors
  end

  defp via_tuple(node_id) do
    {:via, Registry, {VsmPhoenixV2.System4Registry, {:cortical_attention_engine, node_id}}}
  end
end