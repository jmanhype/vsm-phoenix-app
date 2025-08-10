defmodule VsmPhoenix.System1.Agents.TelegramLoadPredictor do
  @moduledoc """
  Predictive load management for Telegram bot using attention-based resource allocation.
  
  Monitors system metrics, predicts incoming load, and applies adaptive thresholds
  to maintain optimal performance during traffic spikes.
  """

  require Logger
  alias VsmPhoenix.System2.{CorticalAttentionEngine, AttentionToolRouter}

  @doc """
  Predict and manage load for the Telegram bot based on current system state and patterns.
  """
  def predict_and_manage_load(current_state) do
    # Analyze current system metrics
    load_metrics = gather_system_metrics(current_state)
    
    # Predict incoming load based on patterns
    predicted_load = predict_message_volume(current_state)
    
    # Apply attention-based resource management
    resource_strategy = determine_resource_strategy(load_metrics, predicted_load)
    
    # Implement adaptive thresholds
    apply_adaptive_thresholds(resource_strategy, current_state)
  end

  @doc """
  Get current load prediction without applying changes.
  """
  def get_load_prediction(state) do
    load_metrics = gather_system_metrics(state)
    predicted_load = predict_message_volume(state)
    
    %{
      current_metrics: load_metrics,
      predicted_load: predicted_load,
      recommendation: determine_resource_strategy(load_metrics, predicted_load),
      confidence: calculate_prediction_confidence(state)
    }
  end

  @doc """
  Update load prediction model with actual performance data.
  """
  def update_prediction_model(state, actual_metrics) do
    # In a real implementation, this would update ML model weights
    # For now, we'll just log the feedback
    Logger.debug("Load prediction feedback: #{inspect(actual_metrics)}")
    
    %{
      model_updated: true,
      accuracy_improvement: calculate_accuracy_improvement(state, actual_metrics),
      next_prediction_adjustment: recommend_prediction_adjustment(actual_metrics)
    }
  end

  # Private implementation functions

  defp gather_system_metrics(state) do
    current_time = System.system_time(:second)
    
    # Message processing rate (messages per minute)
    message_rate = calculate_message_rate(state)
    
    # Error rate (errors per total operations)
    error_rate = calculate_error_rate(state)
    
    # LLM processing queue size
    llm_queue_size = map_size(state.llm_processing || %{})
    
    # Calculate resource utilization estimates
    resource_utilization = estimate_resource_utilization(state, message_rate, llm_queue_size)
    
    # Response time estimation
    estimated_response_time = estimate_response_time(llm_queue_size, resource_utilization)
    
    %{
      current_message_rate: message_rate,
      llm_queue_length: llm_queue_size,
      attention_fatigue_level: get_attention_fatigue(state),
      resource_utilization: resource_utilization,
      active_conversations: count_active_conversations(state),
      average_response_time: estimated_response_time,
      error_rate: error_rate,
      system_health_score: calculate_system_health_score(state),
      timestamp: current_time
    }
  end

  defp calculate_message_rate(state) do
    if state.metrics && state.metrics.last_message_at do
      time_diff = DateTime.diff(DateTime.utc_now(), state.metrics.last_message_at, :second)
      if time_diff > 0 and time_diff < 300 do  # Last 5 minutes
        (state.metrics.messages_received || 0) / max(1, time_diff / 60)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp calculate_error_rate(state) do
    if state.metrics && (state.metrics.messages_received || 0) > 0 do
      total_errors = (state.metrics.errors || 0) + (state.metrics.api_failures || 0)
      total_messages = state.metrics.messages_received || 1
      (total_errors / total_messages) * 100
    else
      0.0
    end
  end

  defp estimate_resource_utilization(state, message_rate, llm_queue_size) do
    # Estimate resource usage based on activity indicators
    base_cpu = min(90, message_rate * 2 + llm_queue_size * 10)
    base_memory = min(95, message_rate * 1.5 + llm_queue_size * 15)
    
    # Adjust for degradation level
    degradation_multiplier = case state.resilience.current_degradation_level do
      level when level >= 4 -> 1.3  # High degradation means inefficient resource use
      level when level >= 2 -> 1.1
      _ -> 1.0
    end
    
    %{
      cpu: min(100, base_cpu * degradation_multiplier),
      memory: min(100, base_memory * degradation_multiplier),
      network: min(100, message_rate * 3 + llm_queue_size * 5),
      disk_io: min(100, (length(Map.keys(state.conversation_states || %{})) * 2))
    }
  end

  defp estimate_response_time(llm_queue_size, resource_utilization) do
    base_time = case llm_queue_size do
      0 -> 100
      size when size <= 5 -> 200 + size * 50
      size when size <= 10 -> 500 + size * 100
      size -> min(10_000, 1000 + size * 200)
    end
    
    # Adjust for resource contention
    cpu_penalty = if resource_utilization.cpu > 80, do: base_time * 0.5, else: 0
    memory_penalty = if resource_utilization.memory > 85, do: base_time * 0.3, else: 0
    
    round(base_time + cpu_penalty + memory_penalty)
  end

  defp get_attention_fatigue(state) do
    case state.resilience do
      %{current_degradation_level: level} -> level / 5.0  # Convert to 0-1 scale
      _ -> 0.0
    end
  end

  defp count_active_conversations(state) do
    length(Map.keys(state.conversation_states || %{}))
  end

  defp calculate_system_health_score(state) do
    # Calculate overall system health as a score from 0-1
    factors = [
      calculate_error_rate_health(state),
      calculate_response_time_health(state),
      calculate_resource_health(state),
      calculate_user_satisfaction_health(state)
    ]
    
    Enum.sum(factors) / length(factors)
  end

  defp calculate_error_rate_health(state) do
    error_rate = calculate_error_rate(state)
    cond do
      error_rate < 1 -> 1.0    # Excellent
      error_rate < 5 -> 0.8    # Good
      error_rate < 10 -> 0.6   # Acceptable
      error_rate < 20 -> 0.4   # Poor
      true -> 0.2             # Critical
    end
  end

  defp calculate_response_time_health(state) do
    # Estimate current response time and score it
    llm_queue_size = map_size(state.llm_processing || %{})
    estimated_time = estimate_response_time(llm_queue_size, %{cpu: 50, memory: 50})
    
    cond do
      estimated_time < 2000 -> 1.0   # Under 2 seconds - excellent
      estimated_time < 5000 -> 0.8   # Under 5 seconds - good
      estimated_time < 10000 -> 0.6  # Under 10 seconds - acceptable
      estimated_time < 20000 -> 0.4  # Under 20 seconds - poor
      true -> 0.2                    # Over 20 seconds - critical
    end
  end

  defp calculate_resource_health(state) do
    degradation_level = state.resilience.current_degradation_level || 0
    max(0.0, 1.0 - degradation_level / 5.0)
  end

  defp calculate_user_satisfaction_health(state) do
    state.metrics.user_satisfaction_avg || 0.8
  end

  defp predict_message_volume(state) do
    current_hour = DateTime.utc_now().hour
    day_of_week = Date.day_of_week(Date.utc_today())
    
    # Base prediction on time patterns
    base_prediction = classify_time_period(current_hour, day_of_week)
    
    # Adjust based on recent trends
    recent_trend = analyze_recent_message_trend(state)
    
    # Adjust based on system events
    event_adjustment = detect_system_events(state)
    
    final_prediction = adjust_prediction(base_prediction, recent_trend, event_adjustment)
    
    %{
      prediction: final_prediction,
      confidence: calculate_prediction_confidence(state),
      factors: %{
        time_pattern: base_prediction,
        recent_trend: recent_trend,
        system_events: event_adjustment
      }
    }
  end

  defp classify_time_period(hour, day_of_week) do
    case {hour, day_of_week} do
      {h, _} when h in 9..17 -> :high      # Business hours
      {h, d} when h in 18..22 and d in 1..5 -> :moderate  # Weekday evenings
      {h, d} when h in 10..18 and d in 6..7 -> :moderate  # Weekend daytime
      {h, _} when h in 0..6 -> :very_low    # Late night/early morning
      _ -> :low  # Other hours
    end
  end

  defp analyze_recent_message_trend(state) do
    # Analyze message rate over last 15 minutes vs previous period
    current_rate = calculate_message_rate(state)
    
    # In real implementation, would compare with historical data
    # For now, classify based on current activity
    cond do
      current_rate > 20 -> :increasing_rapidly
      current_rate > 10 -> :increasing
      current_rate > 5 -> :stable
      current_rate > 1 -> :decreasing
      true -> :very_low
    end
  end

  defp detect_system_events(state) do
    # Detect events that might affect message volume
    events = []
    
    # Check for recent alerts or system issues
    events = if (state.metrics.api_failures || 0) > 5 do
      [:system_issues | events]
    else
      events
    end
    
    # Check for degradation events
    events = if (state.resilience.current_degradation_level || 0) > 2 do
      [:performance_degradation | events]
    else
      events
    end
    
    # Check for high error rates
    events = if calculate_error_rate(state) > 10 do
      [:high_error_rate | events]
    else
      events
    end
    
    case events do
      [] -> :normal
      [_] -> :minor_impact
      _ -> :major_impact
    end
  end

  defp adjust_prediction(base, trend, events) do
    base_load = case base do
      :very_low -> 0.1
      :low -> 0.3
      :moderate -> 0.6
      :high -> 0.8
      :very_high -> 1.0
    end
    
    trend_adjustment = case trend do
      :increasing_rapidly -> 0.3
      :increasing -> 0.2
      :stable -> 0.0
      :decreasing -> -0.1
      :very_low -> -0.2
    end
    
    event_adjustment = case events do
      :normal -> 0.0
      :minor_impact -> 0.1
      :major_impact -> 0.2
    end
    
    final_load = base_load + trend_adjustment + event_adjustment
    
    cond do
      final_load > 0.9 -> :very_high
      final_load > 0.7 -> :high
      final_load > 0.4 -> :moderate
      final_load > 0.2 -> :low
      true -> :very_low
    end
  end

  defp calculate_prediction_confidence(state) do
    # Calculate confidence based on data quality and consistency
    factors = [
      data_quality_factor(state),
      consistency_factor(state),
      temporal_stability_factor(state)
    ]
    
    Enum.sum(factors) / length(factors)
  end

  defp data_quality_factor(state) do
    # More historical data = higher confidence
    message_count = (state.metrics && state.metrics.messages_received) || 0
    cond do
      message_count > 1000 -> 1.0
      message_count > 100 -> 0.8
      message_count > 10 -> 0.6
      message_count > 0 -> 0.4
      true -> 0.2
    end
  end

  defp consistency_factor(state) do
    # Lower error rates and degradation = higher confidence
    error_rate = calculate_error_rate(state)
    degradation = (state.resilience.current_degradation_level || 0)
    
    error_confidence = max(0.0, 1.0 - error_rate / 20)
    degradation_confidence = max(0.0, 1.0 - degradation / 5)
    
    (error_confidence + degradation_confidence) / 2
  end

  defp temporal_stability_factor(state) do
    # Recent system stability indicates prediction reliability
    if state.metrics && state.metrics.last_message_at do
      time_since_last = DateTime.diff(DateTime.utc_now(), state.metrics.last_message_at, :second)
      cond do
        time_since_last < 300 -> 1.0   # Recent activity - high confidence
        time_since_last < 1800 -> 0.8  # Some recent activity
        time_since_last < 3600 -> 0.6  # Activity within hour
        true -> 0.4                    # Old data - lower confidence
      end
    else
      0.3  # No historical data
    end
  end

  defp determine_resource_strategy(load_metrics, predicted_load) do
    current_load = assess_current_load_level(load_metrics)
    
    case {current_load, predicted_load.prediction} do
      # Critical situations - emergency measures
      {:critical, _} ->
        create_emergency_strategy(load_metrics)
      
      {:high, prediction} when prediction in [:high, :very_high] ->
        create_preventive_strategy(load_metrics, :aggressive)
      
      # Preventive measures
      {:moderate, :very_high} ->
        create_preventive_strategy(load_metrics, :moderate)
      
      {:moderate, :high} ->
        create_preventive_strategy(load_metrics, :light)
      
      # Optimal conditions
      {load_level, prediction} when load_level in [:low, :normal] and 
                                    prediction in [:low, :moderate] ->
        create_optimal_strategy(load_metrics)
      
      # Default balanced approach
      _ ->
        create_balanced_strategy(load_metrics, predicted_load)
    end
  end

  defp assess_current_load_level(metrics) do
    cpu_level = cond do
      metrics.resource_utilization.cpu > 90 -> :critical
      metrics.resource_utilization.cpu > 75 -> :high
      metrics.resource_utilization.cpu > 50 -> :moderate
      metrics.resource_utilization.cpu > 25 -> :normal
      true -> :low
    end
    
    response_level = cond do
      metrics.average_response_time > 10000 -> :critical
      metrics.average_response_time > 5000 -> :high
      metrics.average_response_time > 2000 -> :moderate
      metrics.average_response_time > 1000 -> :normal
      true -> :low
    end
    
    error_level = cond do
      metrics.error_rate > 20 -> :critical
      metrics.error_rate > 10 -> :high
      metrics.error_rate > 5 -> :moderate
      metrics.error_rate > 1 -> :normal
      true -> :low
    end
    
    # Take the worst indicator as overall level
    [cpu_level, response_level, error_level]
    |> Enum.max_by(&load_level_priority/1)
  end

  defp load_level_priority(level) do
    case level do
      :critical -> 5
      :high -> 4
      :moderate -> 3
      :normal -> 2
      :low -> 1
    end
  end

  defp create_emergency_strategy(metrics) do
    %{
      mode: :emergency_throttling,
      attention_threshold: 0.8,  # Only highest attention messages
      llm_usage: :critical_only,
      response_templates: :prefer_templates,
      queue_management: :aggressive_filtering,
      resource_limits: %{
        max_concurrent_llm: 2,
        max_queue_size: 5,
        timeout_reduction: 0.5
      },
      monitoring_interval: 30_000,  # Monitor every 30 seconds
      escalation: :alert_administrators
    }
  end

  defp create_preventive_strategy(metrics, intensity) do
    {threshold, llm_limit, queue_limit} = case intensity do
      :aggressive -> {0.7, 3, 10}
      :moderate -> {0.5, 5, 15}
      :light -> {0.4, 8, 20}
    end
    
    %{
      mode: :preventive_throttling,
      attention_threshold: threshold,
      llm_usage: :reduced,
      response_templates: :smart_mix,
      queue_management: :priority_based,
      resource_limits: %{
        max_concurrent_llm: llm_limit,
        max_queue_size: queue_limit,
        timeout_reduction: 0.2
      },
      monitoring_interval: 60_000,  # Monitor every minute
      escalation: :increase_monitoring
    }
  end

  defp create_optimal_strategy(metrics) do
    %{
      mode: :optimal_service,
      attention_threshold: 0.2,  # Standard filtering
      llm_usage: :full_capability,
      response_templates: :llm_preferred,
      queue_management: :fair_scheduling,
      resource_limits: %{
        max_concurrent_llm: 15,
        max_queue_size: 50,
        timeout_reduction: 0.0
      },
      monitoring_interval: 300_000,  # Monitor every 5 minutes
      escalation: :none
    }
  end

  defp create_balanced_strategy(metrics, predicted_load) do
    %{
      mode: :balanced_service,
      attention_threshold: 0.3,
      llm_usage: :adaptive,
      response_templates: :context_aware,
      queue_management: :adaptive_priority,
      resource_limits: %{
        max_concurrent_llm: 10,
        max_queue_size: 30,
        timeout_reduction: 0.1
      },
      monitoring_interval: 120_000,  # Monitor every 2 minutes
      escalation: :conditional
    }
  end

  defp apply_adaptive_thresholds(strategy, state) do
    Logger.info("🧠 Applying load management strategy: #{strategy.mode}")
    
    # Update attention engine configuration
    new_attention_config = %{
      filtering_threshold: strategy.attention_threshold,
      fatigue_recovery_rate: calculate_recovery_rate(strategy),
      resource_preservation: strategy.mode != :optimal_service,
      max_concurrent_processing: strategy.resource_limits.max_concurrent_llm
    }
    
    # Configure tool router priorities based on strategy
    tool_priorities = determine_tool_priorities(strategy)
    
    # Apply configuration changes
    apply_attention_configuration(new_attention_config)
    apply_tool_priorities(tool_priorities)
    
    # Schedule monitoring based on strategy
    schedule_load_monitoring(strategy.monitoring_interval)
    
    # Handle escalation if needed
    handle_escalation(strategy.escalation, state)
    
    Logger.info("✅ Load management applied: threshold=#{strategy.attention_threshold}, mode=#{strategy.llm_usage}")
    
    strategy
  end

  defp calculate_recovery_rate(strategy) do
    case strategy.mode do
      :emergency_throttling -> 0.8   # Fast recovery from emergency
      :preventive_throttling -> 0.6
      :balanced_service -> 0.4
      :optimal_service -> 0.2        # Slow recovery when optimal
    end
  end

  defp determine_tool_priorities(strategy) do
    case strategy.llm_usage do
      :critical_only -> [:coordination_agent, :sensor_agent]  # No LLM
      :reduced -> [:sensor_agent, :coordination_agent, :llm_worker]  # LLM last
      :adaptive -> [:sensor_agent, :llm_worker, :coordination_agent]  # Balanced
      :full_capability -> [:llm_worker, :sensor_agent, :coordination_agent]  # LLM first
    end
  end

  defp apply_attention_configuration(config) do
    # In real implementation, would update CorticalAttentionEngine configuration
    Logger.debug("Updating attention configuration: #{inspect(config)}")
  end

  defp apply_tool_priorities(priorities) do
    # In real implementation, would update AttentionToolRouter priorities
    Logger.debug("Updating tool priorities: #{inspect(priorities)}")
  end

  defp schedule_load_monitoring(interval) do
    # Schedule next load monitoring check
    Process.send_after(self(), :check_load_management, interval)
  end

  defp handle_escalation(escalation, state) do
    case escalation do
      :alert_administrators ->
        Logger.warning("🚨 Load management escalation: Alerting administrators")
        # Would send alerts in real implementation
        
      :increase_monitoring ->
        Logger.info("📊 Load management: Increasing monitoring frequency")
        
      :conditional ->
        if should_escalate?(state) do
          Logger.warning("⚠️ Load management: Conditional escalation triggered")
        end
        
      _ -> 
        :ok
    end
  end

  defp should_escalate?(state) do
    # Check if conditions warrant escalation
    error_rate = calculate_error_rate(state)
    degradation = state.resilience.current_degradation_level || 0
    
    error_rate > 15 or degradation > 3
  end

  defp calculate_accuracy_improvement(_state, _actual_metrics) do
    # Placeholder for ML model accuracy calculation
    0.05  # 5% improvement
  end

  defp recommend_prediction_adjustment(_actual_metrics) do
    # Placeholder for prediction model adjustment recommendations
    %{
      confidence_adjustment: 0.02,
      trend_sensitivity: 1.1,
      event_weight: 0.9
    }
  end
end