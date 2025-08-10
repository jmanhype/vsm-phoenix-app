defmodule VsmPhoenix.System1.Agents.TelegramAttentionProcessor do
  @moduledoc """
  Telegram-specific attention processor implementing cortical attention patterns for message prioritization.
  
  Routes messages based on attention scores and system load to optimize user experience
  and system performance.
  """

  require Logger
  alias VsmPhoenix.System2.{CorticalAttentionEngine, AttentionToolRouter}

  @doc """
  Process a Telegram message using cortical attention analysis to determine routing priority.
  
  Returns a routing decision with action, priority, processing mode, and resource requirements.
  """
  def process_message(message, state) do
    # Extract message characteristics
    message_context = %{
      source: "telegram",
      chat_id: message["chat"]["id"],
      user: message["from"],
      message_type: classify_message_type(message),
      timestamp: DateTime.utc_now()
    }
    
    # Score attention across all dimensions
    {:ok, attention_score, components} = CorticalAttentionEngine.score_attention(
      message, 
      message_context
    )
    
    # Route based on attention score and system state
    routing_decision = route_by_attention(attention_score, components, message, state)
    
    Logger.info("📱 Telegram message attention: #{Float.round(attention_score, 3)} - #{routing_decision.action}")
    
    routing_decision
  end

  defp classify_message_type(message) do
    text = message["text"] || ""
    
    cond do
      String.starts_with?(text, "/") -> :command
      String.contains?(text, ["error", "alert", "urgent", "critical"]) -> :urgent_inquiry
      String.contains?(text, ["status", "health", "metrics"]) -> :monitoring_request
      String.contains?(text, ["help", "how", "what", "?"]) -> :support_request
      String.match?(text, ~r/\b(hi|hello|hey)\b/i) -> :social_greeting
      true -> :general_conversation
    end
  end

  defp route_by_attention(score, components, message, state) do
    # Get system fatigue level for load-aware routing
    fatigue_level = get_system_fatigue_level(state)
    
    # Adjust thresholds based on system load
    {critical_threshold, high_threshold, normal_threshold} = calculate_adaptive_thresholds(fatigue_level)
    
    cond do
      # CRITICAL: Immediate processing (score > critical_threshold)
      score > critical_threshold ->
        %{
          action: :immediate_processing,
          priority: :critical,
          processing_mode: :llm_enhanced,
          max_response_time: 2000,  # 2 second max
          context: "High attention - likely urgent user need or system issue",
          bypass_queues: true,
          attention_score: score,
          components: components
        }
      
      # HIGH: Priority processing (score > high_threshold)  
      score > high_threshold ->
        %{
          action: :priority_processing,
          priority: :high,
          processing_mode: determine_optimal_mode(components, fatigue_level),
          max_response_time: 5000,  # 5 second max
          context: "Moderate-high attention - important user interaction",
          bypass_queues: false,
          attention_score: score,
          components: components
        }
      
      # NORMAL: Standard processing (score > normal_threshold)
      score > normal_threshold ->
        %{
          action: :standard_processing, 
          priority: :normal,
          processing_mode: :efficient,
          max_response_time: 10000,  # 10 second max
          context: "Standard attention - normal conversation flow",
          bypass_queues: false,
          attention_score: score,
          components: components
        }
      
      # LOW: Defer or simple response (score < normal_threshold)
      true ->
        %{
          action: :defer_or_simple,
          priority: :low,
          processing_mode: determine_low_priority_mode(message, fatigue_level),
          max_response_time: 15000,  # 15 second max
          context: "Low attention - likely small talk or low-priority request",
          bypass_queues: false,
          attention_score: score,
          components: components
        }
    end
  end

  defp get_system_fatigue_level(state) do
    # Extract fatigue level from resilience system if available
    case state.resilience do
      %{current_degradation_level: level} -> level / 5.0  # Convert to 0-1 scale
      _ -> 0.0  # No fatigue data available
    end
  end

  defp calculate_adaptive_thresholds(fatigue_level) do
    # Adjust attention thresholds based on system fatigue
    base_critical = 0.85
    base_high = 0.6
    base_normal = 0.2
    
    # Under high fatigue, require higher attention scores to trigger expensive processing
    fatigue_adjustment = fatigue_level * 0.2
    
    {
      min(0.95, base_critical + fatigue_adjustment),  # Critical threshold
      min(0.8, base_high + fatigue_adjustment),       # High threshold  
      max(0.1, base_normal - fatigue_adjustment * 0.5) # Normal threshold (less restrictive)
    }
  end

  defp determine_optimal_mode(components, fatigue_level) do
    cond do
      # If system is fatigued, use simpler processing
      fatigue_level > 0.6 -> :template_response
      
      # If relevance and coherence are high, use full LLM
      components.relevance > 0.7 and components.coherence > 0.6 -> :llm_enhanced
      
      # If urgency is high but other factors moderate, use efficient mode
      components.urgency > 0.7 -> :efficient
      
      # Default to efficient processing
      true -> :efficient
    end
  end

  defp determine_low_priority_mode(message, fatigue_level) do
    text = message["text"] || ""
    
    cond do
      # If system is highly fatigued, use minimal responses
      fatigue_level > 0.8 -> :minimal_response
      
      # For very short messages, use templates
      String.length(text) < 20 -> :template_response
      
      # For social greetings, use simple acknowledgment
      String.match?(text, ~r/\b(hi|hello|hey|thanks|bye)\b/i) -> :social_template
      
      # Default to template response for low priority
      true -> :template_response
    end
  end
end