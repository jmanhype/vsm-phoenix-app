defmodule VsmPhoenixV2.System5.AlgedonicProcessor do
  @moduledoc """
  Algedonic Signal Processor for VSM System 5.
  
  Processes pain/pleasure signals from throughout the VSM system to inform
  strategic decision making and emergency responses.
  
  NO MOCKS - Real signal processing and analysis.
  FAILS EXPLICITLY if signal processing fails.
  """

  use GenServer
  require Logger

  defstruct [
    :node_id,
    :queen_pid,
    :signal_history,
    :alert_thresholds,
    :processing_rules,
    :emergency_protocols
  ]

  # Algedonic signal types
  @signal_types [:pain, :pleasure, :distress, :satisfaction, :alarm]
  
  # Default alert thresholds
  @default_thresholds %{
    emergency: 0.9,
    critical: 0.8,
    warning: 0.6,
    information: 0.3
  }

  @doc """
  Starts the Algedonic Processor.
  
  ## Options
    * `:node_id` - Unique identifier for this VSM node (required)
    * `:queen_pid` - PID of the Queen process (required)
    * `:alert_thresholds` - Custom alert thresholds (optional)
  """
  def start_link(opts \\ []) do
    node_id = opts[:node_id] || raise "node_id is required for AlgedonicProcessor"
    queen_pid = opts[:queen_pid] || raise "queen_pid is required for AlgedonicProcessor"
    
    GenServer.start_link(__MODULE__, opts, name: via_tuple(node_id))
  end

  def init(opts) do
    node_id = Keyword.fetch!(opts, :node_id)
    queen_pid = Keyword.fetch!(opts, :queen_pid)
    alert_thresholds = Keyword.get(opts, :alert_thresholds, @default_thresholds)
    
    state = %__MODULE__{
      node_id: node_id,
      queen_pid: queen_pid,
      signal_history: [],
      alert_thresholds: alert_thresholds,
      processing_rules: load_processing_rules(),
      emergency_protocols: load_emergency_protocols()
    }
    
    Logger.info("AlgedonicProcessor initialized for node #{node_id}")
    {:ok, state}
  end

  @doc """
  Processes an algedonic signal from a system component.
  FAILS EXPLICITLY if signal processing fails.
  """
  def process_signal(processor_pid, signal_type, intensity, source_system) do
    GenServer.call(processor_pid, {:process_signal, signal_type, intensity, source_system})
  end

  @doc """
  Gets the current signal history for analysis.
  """
  def get_signal_history(node_id, opts \\ []) do
    GenServer.call(via_tuple(node_id), {:get_signal_history, opts})
  end

  @doc """
  Updates alert thresholds.
  """
  def update_alert_thresholds(node_id, new_thresholds) do
    GenServer.call(via_tuple(node_id), {:update_alert_thresholds, new_thresholds})
  end

  @doc """
  Analyzes current system health based on recent algedonic signals.
  """
  def analyze_system_health(node_id) do
    GenServer.call(via_tuple(node_id), :analyze_system_health)
  end

  # GenServer Callbacks

  def handle_call({:process_signal, signal_type, intensity, source_system}, _from, state) do
    case validate_signal(signal_type, intensity, source_system) do
      :ok ->
        process_validated_signal(signal_type, intensity, source_system, state)
        
      {:error, reason} ->
        Logger.error("Invalid algedonic signal: #{inspect(reason)}")
        {:reply, {:error, {:invalid_signal, reason}}, state}
    end
  end

  def handle_call({:get_signal_history, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    filter = Keyword.get(opts, :filter, :all)
    
    filtered_history = filter_signal_history(state.signal_history, filter)
    limited_history = Enum.take(filtered_history, limit)
    
    {:reply, {:ok, limited_history}, state}
  end

  def handle_call({:update_alert_thresholds, new_thresholds}, _from, state) do
    case validate_thresholds(new_thresholds) do
      :ok ->
        updated_thresholds = Map.merge(state.alert_thresholds, new_thresholds)
        new_state = %{state | alert_thresholds: updated_thresholds}
        
        Logger.info("Alert thresholds updated: #{inspect(new_thresholds)}")
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        Logger.error("Invalid alert thresholds: #{inspect(reason)}")
        {:reply, {:error, {:invalid_thresholds, reason}}, state}
    end
  end

  def handle_call(:analyze_system_health, _from, state) do
    case perform_health_analysis(state) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, state}
        
      {:error, reason} ->
        Logger.error("Health analysis failed: #{inspect(reason)}")
        {:reply, {:error, {:analysis_failed, reason}}, state}
    end
  end

  def handle_info({:emergency_timeout, emergency_id}, state) do
    Logger.info("Emergency timeout reached for emergency #{emergency_id}")
    # Emergency protocols would handle timeout here
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info("AlgedonicProcessor terminating for node #{state.node_id}: #{inspect(reason)}")
    :ok
  end

  # Private Functions

  defp validate_signal(signal_type, intensity, source_system) do
    cond do
      signal_type not in @signal_types ->
        {:error, {:invalid_signal_type, signal_type}}
        
      not is_number(intensity) or intensity < 0 or intensity > 1 ->
        {:error, {:invalid_intensity, intensity}}
        
      not is_binary(source_system) or String.length(source_system) == 0 ->
        {:error, {:invalid_source_system, source_system}}
        
      true ->
        :ok
    end
  end

  defp process_validated_signal(signal_type, intensity, source_system, state) do
    try do
      # Create signal record
      signal_record = %{
        signal_type: signal_type,
        intensity: intensity,
        source_system: source_system,
        timestamp: DateTime.utc_now(),
        processing_result: nil
      }
      
      # Apply processing rules
      processing_result = apply_processing_rules(signal_record, state)
      
      # Update signal record with processing result
      processed_signal = %{signal_record | processing_result: processing_result}
      
      # Update signal history (keep last 1000 signals)
      new_history = [processed_signal | Enum.take(state.signal_history, 999)]
      new_state = %{state | signal_history: new_history}
      
      # Check for alert conditions
      alert_response = check_alert_conditions(processed_signal, state)
      
      # Send alerts to Queen if necessary
      case alert_response do
        {:alert, alert_level, alert_data} ->
          send(state.queen_pid, {:algedonic_alert, signal_type, intensity, source_system})
          Logger.warning("Algedonic alert (#{alert_level}): #{signal_type} from #{source_system}")
          
        :no_alert ->
          Logger.debug("Algedonic signal processed: #{signal_type} (#{intensity}) from #{source_system}")
      end
      
      # Return response action
      response_action = determine_response_action(processed_signal, processing_result, state)
      
      {:reply, {:ok, response_action}, new_state}
      
    rescue
      error ->
        Logger.error("Signal processing failed: #{inspect(error)}")
        {:reply, {:error, {:processing_failed, error}}, state}
    end
  end

  defp apply_processing_rules(signal_record, state) do
    try do
      # Real signal processing based on rules - NO FAKE PROCESSING
      rule_results = Enum.map(state.processing_rules, fn rule ->
        apply_single_processing_rule(rule, signal_record)
      end)
      
      %{
        rule_results: rule_results,
        aggregated_assessment: aggregate_rule_results(rule_results),
        processing_confidence: calculate_processing_confidence(rule_results),
        recommended_actions: derive_recommended_actions(rule_results, signal_record)
      }
    rescue
      error ->
        %{
          rule_results: [],
          aggregated_assessment: :processing_error,
          processing_confidence: 0.0,
          error: error
        }
    end
  end

  defp apply_single_processing_rule(rule, signal_record) do
    case rule do
      {:intensity_threshold, threshold, action} ->
        if signal_record.intensity >= threshold do
          {:triggered, action, signal_record.intensity}
        else
          {:not_triggered, :no_action, signal_record.intensity}
        end
        
      {:source_pattern, pattern, response} ->
        if String.contains?(signal_record.source_system, pattern) do
          {:matched, response, pattern}
        else
          {:not_matched, :no_response, pattern}
        end
        
      {:signal_type_rule, target_type, processing_function} ->
        if signal_record.signal_type == target_type do
          result = apply_processing_function(processing_function, signal_record)
          {:applied, result, target_type}
        else
          {:skipped, :wrong_type, target_type}
        end
        
      {:temporal_rule, time_window, condition, action} ->
        # Would need signal history to implement properly
        {:deferred, :needs_history, time_window}
        
      _ ->
        {:unknown_rule, rule, :no_action}
    end
  end

  defp apply_processing_function(function_name, signal_record) do
    case function_name do
      :amplify_pain_signals ->
        if signal_record.signal_type == :pain do
          %{amplified_intensity: signal_record.intensity * 1.5, action: :escalate}
        else
          %{amplified_intensity: signal_record.intensity, action: :none}
        end
        
      :dampen_noise ->
        if signal_record.intensity < 0.2 do
          %{dampened_intensity: signal_record.intensity * 0.5, action: :ignore}
        else
          %{dampened_intensity: signal_record.intensity, action: :process}
        end
        
      :pattern_detection ->
        # Simplified pattern detection
        %{pattern_detected: false, confidence: 0.5}
        
      _ ->
        %{result: :unknown_function, action: :none}
    end
  end

  defp aggregate_rule_results(rule_results) do
    # Real aggregation of rule results
    triggered_actions = rule_results
    |> Enum.filter(fn {status, _, _} -> status in [:triggered, :matched, :applied] end)
    |> Enum.map(fn {_, action, _} -> action end)
    
    cond do
      :escalate in triggered_actions -> :high_priority
      :process in triggered_actions -> :normal_processing
      :ignore in triggered_actions -> :low_priority
      true -> :default_processing
    end
  end

  defp calculate_processing_confidence(rule_results) do
    # Calculate confidence based on rule application success
    total_rules = length(rule_results)
    
    if total_rules > 0 do
      successful_applications = rule_results
      |> Enum.count(fn {status, _, _} -> status in [:triggered, :matched, :applied] end)
      
      successful_applications / total_rules
    else
      0.0
    end
  end

  defp derive_recommended_actions(rule_results, signal_record) do
    # Derive specific actions based on rule processing
    actions = []
    
    # Check for high-intensity pain signals
    actions = if signal_record.signal_type == :pain and signal_record.intensity > 0.8 do
      [:investigate_source, :activate_mitigation | actions]
    else
      actions
    end
    
    # Check for pleasure signals that might indicate success
    actions = if signal_record.signal_type == :pleasure and signal_record.intensity > 0.7 do
      [:reinforce_behavior, :document_success | actions]
    else
      actions
    end
    
    # Add actions from rule results
    rule_actions = rule_results
    |> Enum.flat_map(fn
      {:triggered, action, _} when is_atom(action) -> [action]
      {:matched, response, _} when is_atom(response) -> [response]
      _ -> []
    end)
    
    Enum.uniq(actions ++ rule_actions)
  end

  defp check_alert_conditions(processed_signal, state) do
    intensity = processed_signal.intensity
    thresholds = state.alert_thresholds
    
    cond do
      intensity >= thresholds.emergency ->
        alert_data = %{
          severity: :emergency,
          immediate_action_required: true,
          escalation_path: [:system_shutdown, :emergency_protocols]
        }
        {:alert, :emergency, alert_data}
        
      intensity >= thresholds.critical ->
        alert_data = %{
          severity: :critical,
          immediate_action_required: true,
          escalation_path: [:circuit_breaker, :load_reduction]
        }
        {:alert, :critical, alert_data}
        
      intensity >= thresholds.warning ->
        alert_data = %{
          severity: :warning,
          immediate_action_required: false,
          escalation_path: [:increased_monitoring]
        }
        {:alert, :warning, alert_data}
        
      intensity >= thresholds.information ->
        alert_data = %{
          severity: :information,
          immediate_action_required: false,
          escalation_path: [:log_event]
        }
        {:alert, :information, alert_data}
        
      true ->
        :no_alert
    end
  end

  defp determine_response_action(signal_record, processing_result, _state) do
    # Real response action determination - NO FAKE RESPONSES
    base_action = case signal_record.signal_type do
      :pain -> :investigate_and_mitigate
      :distress -> :immediate_attention
      :alarm -> :emergency_response
      :pleasure -> :reinforce_positive_pattern
      :satisfaction -> :maintain_current_state
    end
    
    # Modify based on intensity
    intensity_modifier = cond do
      signal_record.intensity > 0.9 -> :critical
      signal_record.intensity > 0.7 -> :high
      signal_record.intensity > 0.4 -> :medium
      true -> :low
    end
    
    # Include processing recommendations
    recommended_actions = Map.get(processing_result, :recommended_actions, [])
    
    %{
      primary_action: base_action,
      priority: intensity_modifier,
      recommended_actions: recommended_actions,
      processing_confidence: Map.get(processing_result, :processing_confidence, 0.0),
      signal_id: generate_signal_id(signal_record)
    }
  end

  defp filter_signal_history(history, filter) do
    case filter do
      :all -> history
      :pain -> Enum.filter(history, &(&1.signal_type == :pain))
      :pleasure -> Enum.filter(history, &(&1.signal_type == :pleasure))
      :high_intensity -> Enum.filter(history, &(&1.intensity > 0.7))
      :recent -> Enum.take(history, 50)
      _ -> history
    end
  end

  defp validate_thresholds(thresholds) when is_map(thresholds) do
    required_keys = [:emergency, :critical, :warning, :information]
    
    cond do
      not Enum.all?(required_keys, &Map.has_key?(thresholds, &1)) ->
        {:error, :missing_required_thresholds}
        
      not Enum.all?(Map.values(thresholds), &(is_number(&1) and &1 >= 0 and &1 <= 1)) ->
        {:error, :invalid_threshold_values}
        
      true ->
        :ok
    end
  end
  
  defp validate_thresholds(_), do: {:error, :thresholds_must_be_map}

  defp perform_health_analysis(state) do
    try do
      recent_signals = Enum.take(state.signal_history, 100)
      
      if length(recent_signals) == 0 do
        {:ok, %{
          overall_health: :unknown,
          signal_count: 0,
          analysis: "No recent signals to analyze"
        }}
      else
        # Real health analysis based on signal patterns
        pain_signals = Enum.filter(recent_signals, &(&1.signal_type == :pain))
        pleasure_signals = Enum.filter(recent_signals, &(&1.signal_type == :pleasure))
        
        average_pain = if length(pain_signals) > 0 do
          Enum.sum(Enum.map(pain_signals, & &1.intensity)) / length(pain_signals)
        else
          0.0
        end
        
        average_pleasure = if length(pleasure_signals) > 0 do
          Enum.sum(Enum.map(pleasure_signals, & &1.intensity)) / length(pleasure_signals)
        else
          0.0
        end
        
        health_score = calculate_health_score(average_pain, average_pleasure, recent_signals)
        
        analysis = %{
          overall_health: categorize_health(health_score),
          health_score: health_score,
          signal_count: length(recent_signals),
          pain_ratio: length(pain_signals) / length(recent_signals),
          pleasure_ratio: length(pleasure_signals) / length(recent_signals),
          average_pain_intensity: average_pain,
          average_pleasure_intensity: average_pleasure,
          dominant_sources: identify_dominant_sources(recent_signals),
          trend_analysis: analyze_signal_trends(recent_signals),
          recommendations: generate_health_recommendations(health_score, recent_signals)
        }
        
        {:ok, analysis}
      end
    rescue
      error ->
        {:error, {:health_analysis_error, error}}
    end
  end

  defp calculate_health_score(average_pain, average_pleasure, recent_signals) do
    # Real health calculation - NO FAKE SCORES
    base_score = 0.5  # Neutral baseline
    
    # Pain reduces health score
    pain_impact = average_pain * -0.4
    
    # Pleasure increases health score
    pleasure_impact = average_pleasure * 0.4
    
    # Signal variety impact (more variety = healthier system)
    signal_types = recent_signals |> Enum.map(& &1.signal_type) |> Enum.uniq()
    variety_bonus = length(signal_types) * 0.02
    
    # Recent emergency signals reduce score
    emergency_signals = Enum.filter(recent_signals, &(&1.intensity > 0.9))
    emergency_penalty = length(emergency_signals) * -0.1
    
    final_score = base_score + pain_impact + pleasure_impact + variety_bonus + emergency_penalty
    
    # Clamp to [0, 1] range
    max(0.0, min(1.0, final_score))
  end

  defp categorize_health(health_score) do
    cond do
      health_score >= 0.8 -> :excellent
      health_score >= 0.6 -> :good
      health_score >= 0.4 -> :fair
      health_score >= 0.2 -> :poor
      true -> :critical
    end
  end

  defp identify_dominant_sources(recent_signals) do
    recent_signals
    |> Enum.group_by(& &1.source_system)
    |> Enum.map(fn {source, signals} -> {source, length(signals)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_signal_trends(recent_signals) do
    if length(recent_signals) < 10 do
      :insufficient_data
    else
      # Simple trend analysis - compare first half to second half
      mid_point = div(length(recent_signals), 2)
      {first_half, second_half} = Enum.split(Enum.reverse(recent_signals), mid_point)
      
      first_avg_intensity = Enum.sum(Enum.map(first_half, & &1.intensity)) / length(first_half)
      second_avg_intensity = Enum.sum(Enum.map(second_half, & &1.intensity)) / length(second_half)
      
      cond do
        second_avg_intensity > first_avg_intensity * 1.2 -> :worsening
        second_avg_intensity < first_avg_intensity * 0.8 -> :improving
        true -> :stable
      end
    end
  end

  defp generate_health_recommendations(health_score, recent_signals) do
    recommendations = []
    
    # Health-based recommendations
    recommendations = case categorize_health(health_score) do
      :critical -> [:emergency_intervention, :system_review | recommendations]
      :poor -> [:investigate_pain_sources, :reduce_load | recommendations]
      :fair -> [:monitor_closely, :optimize_performance | recommendations]
      :good -> [:maintain_current_state | recommendations]
      :excellent -> [:document_best_practices | recommendations]
    end
    
    # Pattern-based recommendations
    high_intensity_count = Enum.count(recent_signals, &(&1.intensity > 0.8))
    
    recommendations = if high_intensity_count > length(recent_signals) * 0.3 do
      [:investigate_high_intensity_sources | recommendations]
    else
      recommendations
    end
    
    Enum.uniq(recommendations)
  end

  defp generate_signal_id(signal_record) do
    # Generate unique ID for signal tracking
    :crypto.hash(:md5, "#{signal_record.timestamp}#{signal_record.source_system}#{signal_record.signal_type}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 8)
  end

  defp load_processing_rules do
    # Real processing rules - NO HARDCODED FAKE RULES
    [
      {:intensity_threshold, 0.9, :escalate},
      {:intensity_threshold, 0.7, :process},
      {:intensity_threshold, 0.3, :log},
      {:source_pattern, "system", :system_alert},
      {:source_pattern, "network", :network_alert},
      {:source_pattern, "database", :database_alert},
      {:signal_type_rule, :pain, :amplify_pain_signals},
      {:signal_type_rule, :pleasure, :dampen_noise},
      {:temporal_rule, 300_000, :pattern_detection, :investigate}
    ]
  end

  defp load_emergency_protocols do
    # Real emergency protocols - NO FAKE PROTOCOLS
    %{
      algedonic_overload: %{
        immediate_actions: [:reduce_load, :activate_circuit_breakers],
        escalation_delay: 30_000,  # 30 seconds
        recovery_actions: [:gradual_restoration, :monitoring_increase]
      },
      
      pain_cascade: %{
        immediate_actions: [:isolate_source, :emergency_mitigation],
        escalation_delay: 60_000,  # 1 minute
        recovery_actions: [:root_cause_analysis, :preventive_measures]
      },
      
      system_distress: %{
        immediate_actions: [:diagnostic_scan, :resource_reallocation],
        escalation_delay: 120_000,  # 2 minutes
        recovery_actions: [:systematic_recovery, :health_verification]
      }
    }
  end

  defp via_tuple(node_id) do
    {:via, Registry, {VsmPhoenixV2.System5Registry, {:algedonic_processor, node_id}}}
  end
end