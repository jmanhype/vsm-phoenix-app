defmodule VsmPhoenix.System2.AttentionReminders do
  @moduledoc """
  Claude-Code inspired system reminders for cortical attention cycling.
  
  Implements constant reinforcement patterns to maintain attention state awareness
  and optimize decision-making through persistent contextual hints.
  """

  require Logger

  @system_reminders [
    %{
      trigger: :attention_shift,
      template: "High attention detected (score: %{attention_score}). Messages >0.8 bypass normal filtering. Current focus: %{current_focus}",
      frequency: :every_shift,
      importance: :critical
    },
    %{
      trigger: :fatigue_increase,
      template: "Attention fatigue: %{fatigue_level}. Prioritize novelty (%{novelty_weight}) and urgency (%{urgency_weight}). Reduce coherence processing.",
      frequency: :when_fatigued,
      importance: :warning
    },
    %{
      trigger: :pattern_match,
      template: "Pattern recognized: %{pattern_id} (strength: %{pattern_strength}). Apply learned weights. Success rate: %{success_rate}%",
      frequency: :on_pattern_detection,
      importance: :info
    },
    %{
      trigger: :meta_learning_update,
      template: "Network pattern from VSM %{source_vsm}: '%{pattern_type}'. Trust: %{trust_score}. Validate before integration.",
      frequency: :on_external_pattern,
      importance: :info
    },
    %{
      trigger: :resource_constraint,
      template: "Resource pressure detected. CPU: %{cpu_usage}%, Memory: %{memory_usage}%. Increase filtering threshold to %{new_threshold}",
      frequency: :on_resource_pressure,
      importance: :warning
    },
    %{
      trigger: :temporal_coherence,
      template: "Temporal window analysis: %{active_windows} windows active. Coherence trend: %{coherence_trend}. Adjust temporal weighting.",
      frequency: :periodic,
      importance: :debug
    }
  ]

  @doc """
  Apply system reminder based on trigger and context.
  Returns updated state with reminder context.
  """
  def apply_system_reminder(state, trigger, context \\ %{}) do
    case get_reminder_for_trigger(trigger) do
      nil ->
        state
        
      reminder_config ->
        reminder_text = interpolate_reminder(reminder_config.template, context)
        
        enhanced_context = %{
          reminder: reminder_text,
          trigger: trigger,
          importance: reminder_config.importance,
          applied_at: DateTime.utc_now(),
          attention_state: state.attention_state,
          context_snapshot: extract_context_snapshot(state, context)
        }
        
        updated_state = %{state | 
          current_reminder: enhanced_context,
          reminder_history: [enhanced_context | Map.get(state, :reminder_history, [])] |> Enum.take(20)
        }
        
        # Log critical and warning reminders
        if reminder_config.importance in [:critical, :warning] do
          Logger.info("🧠 Attention Reminder (#{reminder_config.importance}): #{reminder_text}")
        end
        
        updated_state
    end
  end

  @doc """
  Get current reminder context for external systems
  """
  def get_current_reminder_context(state) do
    case Map.get(state, :current_reminder) do
      nil -> %{reminder: "No active reminders", context: %{}}
      reminder -> reminder
    end
  end

  @doc """
  Generate attention decision explanation with reminder context
  """
  def explain_attention_decision(message, attention_score, components, state) do
    current_reminder = get_current_reminder_context(state)
    
    explanation = """
    Attention Decision Analysis:
    
    Message: #{inspect(message, limit: :infinity) |> String.slice(0, 100)}...
    Final Score: #{Float.round(attention_score, 3)}
    
    Component Breakdown:
    - Novelty: #{Float.round(components.novelty, 3)} (weight: #{state.salience_weights.novelty})
    - Urgency: #{Float.round(components.urgency, 3)} (weight: #{state.salience_weights.urgency})
    - Relevance: #{Float.round(components.relevance, 3)} (weight: #{state.salience_weights.relevance})
    - Intensity: #{Float.round(components.intensity, 3)} (weight: #{state.salience_weights.intensity})
    - Coherence: #{Float.round(components.coherence, 3)} (weight: #{state.salience_weights.coherence})
    
    Attention State: #{state.attention_state}
    Fatigue Level: #{Float.round(state.fatigue_level, 3)}
    State Multiplier: #{get_state_multiplier(state.attention_state)}
    
    Current System Reminder:
    #{current_reminder.reminder}
    
    Decision: #{if attention_score > 0.2, do: "PROCESS", else: "FILTER"}
    Reasoning: #{generate_decision_reasoning(attention_score, components, state)}
    """
    
    explanation
  end

  @doc """
  Check if reminders should trigger based on system state changes
  """
  def check_reminder_triggers(old_state, new_state) do
    triggers = []
    
    # Attention state change
    triggers = if old_state.attention_state != new_state.attention_state do
      [:attention_shift | triggers]
    else
      triggers
    end
    
    # Fatigue increase
    triggers = if new_state.fatigue_level > old_state.fatigue_level + 0.1 do
      [:fatigue_increase | triggers]
    else
      triggers
    end
    
    # Resource pressure (mock detection - would integrate with real metrics)
    triggers = if :rand.uniform() > 0.95 do
      [:resource_constraint | triggers]
    else
      triggers
    end
    
    triggers
  end

  # Private functions

  defp get_reminder_for_trigger(trigger) do
    Enum.find(@system_reminders, fn reminder -> reminder.trigger == trigger end)
  end

  defp interpolate_reminder(template, context) do
    # Replace %{key} patterns with context values
    Regex.replace(~r/%\{(\w+)\}/, template, fn _, key ->
      case Map.get(context, String.to_atom(key)) do
        nil -> "unknown"
        value when is_float(value) -> Float.round(value, 3) |> to_string()
        value -> to_string(value)
      end
    end)
  end

  defp extract_context_snapshot(state, context) do
    %{
      fatigue_level: state.fatigue_level,
      attention_state: state.attention_state,
      active_windows: count_active_windows(state.attention_windows),
      recent_patterns: get_recent_patterns(state),
      context_keys: Map.keys(context)
    }
  end

  defp count_active_windows(attention_windows) do
    Enum.reduce(attention_windows, 0, fn {_scale, window}, acc ->
      acc + length(window)
    end)
  end

  defp get_recent_patterns(state) do
    # Extract recent patterns from learned_patterns if available
    case Map.get(state, :learned_patterns, %{}) do
      patterns when map_size(patterns) > 0 ->
        patterns
        |> Enum.take(5)
        |> Enum.map(fn {pattern_id, pattern_data} -> 
          "#{pattern_id} (#{pattern_data.strength})"
        end)
      
      _ -> ["No recent patterns"]
    end
  end

  defp get_state_multiplier(:focused), do: 1.2
  defp get_state_multiplier(:distributed), do: 1.0
  defp get_state_multiplier(:shifting), do: 0.8
  defp get_state_multiplier(:fatigued), do: 0.6
  defp get_state_multiplier(:recovering), do: 0.8

  defp generate_decision_reasoning(attention_score, components, state) do
    cond do
      attention_score > 0.8 ->
        "High attention score - bypass normal filtering. Dominant component: #{get_dominant_component(components)}"
      
      attention_score > 0.5 ->
        "Moderate attention - normal processing. State: #{state.attention_state}, Fatigue: #{Float.round(state.fatigue_level, 2)}"
      
      attention_score > 0.2 ->
        "Low attention - process but monitor. Risk of filtering if fatigue increases."
      
      true ->
        "Below threshold (0.2) - filtered to preserve cognitive resources. Dominant weakness: #{get_weakest_component(components)}"
    end
  end

  defp get_dominant_component(components) do
    {component, _value} = Enum.max_by(components, fn {_k, v} -> v end)
    component
  end

  defp get_weakest_component(components) do
    {component, _value} = Enum.min_by(components, fn {_k, v} -> v end)
    component
  end
end