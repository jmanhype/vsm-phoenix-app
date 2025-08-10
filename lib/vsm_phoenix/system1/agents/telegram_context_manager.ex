defmodule VsmPhoenix.System1.Agents.TelegramContextManager do
  @moduledoc """
  Enhanced context management for Telegram conversations with cortical attention integration.
  
  Maintains conversation continuity across interactions using system reminders and
  intelligent context compression.
  """

  require Logger
  alias VsmPhoenix.System2.AttentionReminders

  @doc """
  Process a Telegram message with context-aware system reminders for conversation continuity.
  """
  def process_telegram_message(message, chat_id, state) do
    # Build comprehensive conversation context
    conversation_context = build_conversation_context(chat_id, state)
    
    # Apply context-aware system reminder
    enhanced_state = AttentionReminders.apply_system_reminder(
      state, 
      :conversation_continuity, 
      %{
        chat_id: chat_id,
        user: message["from"]["first_name"],
        conversation_length: length(conversation_context.history),
        last_interaction: conversation_context.last_message_time,
        topic_continuity: conversation_context.current_topic,
        user_intent_pattern: conversation_context.detected_intent,
        message_type: classify_telegram_message(message),
        attention_context: extract_attention_context(message, conversation_context)
      }
    )
    
    enhanced_state
  end

  @doc """
  Build comprehensive conversation context for intelligent processing.
  """
  def build_conversation_context(chat_id, state) do
    # Get conversation history from ETS
    history = get_conversation_history(chat_id, state.conversation_table)
    
    # Extract contextual insights
    %{
      history: history,
      last_message_time: get_last_message_time(history),
      current_topic: extract_topic_from_history(history),
      detected_intent: analyze_user_intent_pattern(history),
      conversation_coherence: calculate_conversation_coherence(history),
      user_engagement_level: assess_user_engagement(history),
      semantic_continuity: analyze_semantic_continuity(history),
      temporal_patterns: identify_temporal_patterns(history)
    }
  end

  @doc """
  Update conversation context with new interaction data.
  """
  def update_conversation_context(chat_id, user_message, bot_response, state) do
    # Get existing context
    current_context = build_conversation_context(chat_id, state)
    
    # Create new message entries with enhanced metadata
    timestamp = DateTime.utc_now()
    
    user_entry = %{
      role: "user",
      content: user_message,
      timestamp: timestamp,
      intent: analyze_message_intent(user_message),
      emotional_tone: detect_emotional_tone(user_message),
      complexity: assess_message_complexity(user_message)
    }
    
    bot_entry = %{
      role: "assistant", 
      content: bot_response,
      timestamp: timestamp,
      response_type: classify_response_type(bot_response),
      satisfaction_estimate: estimate_response_satisfaction(bot_response, user_message)
    }
    
    # Update conversation history with context preservation
    updated_history = [bot_entry, user_entry | current_context.history]
    |> Enum.take(50)  # Keep more history for better context
    |> compress_history_if_needed()
    
    # Store updated context
    :ets.insert(state.conversation_table, {chat_id, %{
      messages: updated_history,
      last_updated: timestamp,
      context_summary: generate_context_summary(updated_history),
      topic_evolution: track_topic_evolution(current_context.current_topic, user_message),
      engagement_trajectory: update_engagement_trajectory(current_context.user_engagement_level, user_entry)
    }})
  end

  # Private helper functions

  defp get_conversation_history(chat_id, conversation_table) do
    case :ets.lookup(conversation_table, chat_id) do
      [{^chat_id, context}] -> context[:messages] || []
      [] -> []
    end
  end

  defp get_last_message_time(history) do
    case history do
      [latest | _] -> latest[:timestamp]
      [] -> DateTime.utc_now()
    end
  end

  defp extract_topic_from_history(history) do
    # Simple topic extraction - would be more sophisticated in real implementation
    recent_messages = Enum.take(history, 5)
    |> Enum.map(fn msg -> msg[:content] || "" end)
    |> Enum.join(" ")
    
    cond do
      String.contains?(recent_messages, ["error", "bug", "problem", "issue"]) -> "technical_support"
      String.contains?(recent_messages, ["status", "health", "metrics", "performance"]) -> "system_monitoring"
      String.contains?(recent_messages, ["how", "what", "help", "explain"]) -> "information_seeking"
      String.contains?(recent_messages, ["hi", "hello", "thanks", "bye"]) -> "social_interaction"
      true -> "general_conversation"
    end
  end

  defp analyze_user_intent_pattern(history) do
    # Analyze patterns in user messages to detect intent
    user_messages = history
    |> Enum.filter(fn msg -> msg[:role] == "user" end)
    |> Enum.take(10)
    
    cond do
      length(user_messages) < 3 -> :exploratory
      frequently_asks_questions?(user_messages) -> :information_seeking
      frequently_reports_issues?(user_messages) -> :problem_solving
      frequently_social_messages?(user_messages) -> :social_engagement
      true -> :task_oriented
    end
  end

  defp calculate_conversation_coherence(history) do
    # Simple coherence calculation based on topic consistency
    if length(history) < 2 do
      1.0
    else
      topics = history
      |> Enum.take(10)
      |> Enum.map(&extract_message_topic/1)
      
      unique_topics = Enum.uniq(topics)
      1.0 - (length(unique_topics) - 1) / max(1, length(topics))
    end
  end

  defp assess_user_engagement(history) do
    user_messages = history
    |> Enum.filter(fn msg -> msg[:role] == "user" end)
    |> Enum.take(5)
    
    cond do
      length(user_messages) == 0 -> 0.0
      has_enthusiastic_markers?(user_messages) -> 0.9
      has_detailed_messages?(user_messages) -> 0.7
      has_follow_up_questions?(user_messages) -> 0.6
      true -> 0.4
    end
  end

  defp analyze_semantic_continuity(history) do
    # Analyze how well messages build on previous context
    consecutive_pairs = history
    |> Enum.take(6)
    |> Enum.chunk_every(2, 1, :discard)
    
    if length(consecutive_pairs) == 0 do
      1.0
    else
      continuity_scores = consecutive_pairs
      |> Enum.map(&calculate_pair_continuity/1)
      
      Enum.sum(continuity_scores) / length(continuity_scores)
    end
  end

  defp identify_temporal_patterns(history) do
    # Identify patterns in message timing
    timestamps = history
    |> Enum.map(fn msg -> msg[:timestamp] end)
    |> Enum.filter(&(&1 != nil))
    
    if length(timestamps) < 2 do
      %{pattern: :insufficient_data, frequency: :unknown}
    else
      intervals = timestamps
      |> Enum.sort(DateTime, :desc)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [newer, older] -> DateTime.diff(newer, older, :second) end)
      
      avg_interval = Enum.sum(intervals) / length(intervals)
      
      %{
        pattern: classify_temporal_pattern(avg_interval),
        frequency: classify_message_frequency(avg_interval),
        regularity: calculate_interval_regularity(intervals)
      }
    end
  end

  defp classify_telegram_message(message) do
    text = message["text"] || ""
    
    cond do
      String.starts_with?(text, "/") -> :command
      String.contains?(text, ["error", "urgent", "critical"]) -> :urgent_inquiry  
      String.contains?(text, ["status", "metrics", "health"]) -> :monitoring_request
      String.match?(text, ~r/\b(hi|hello|hey)\b/i) -> :greeting
      String.contains?(text, ["help", "how", "what", "?"]) -> :question
      String.length(text) > 200 -> :detailed_message
      true -> :general_message
    end
  end

  defp extract_attention_context(message, conversation_context) do
    %{
      message_complexity: assess_message_complexity(message["text"] || ""),
      context_relevance: calculate_context_relevance(message, conversation_context),
      urgency_indicators: detect_urgency_indicators(message["text"] || ""),
      user_emotional_state: detect_emotional_tone(message["text"] || ""),
      conversation_momentum: assess_conversation_momentum(conversation_context)
    }
  end

  # Additional helper functions for message analysis

  defp frequently_asks_questions?(messages) do
    question_count = messages
    |> Enum.count(fn msg -> String.contains?(msg[:content] || "", "?") end)
    
    question_count > length(messages) * 0.6
  end

  defp frequently_reports_issues?(messages) do
    issue_keywords = ["error", "problem", "issue", "bug", "wrong", "not working"]
    
    issue_count = messages
    |> Enum.count(fn msg ->
      content = String.downcase(msg[:content] || "")
      Enum.any?(issue_keywords, &String.contains?(content, &1))
    end)
    
    issue_count > length(messages) * 0.4
  end

  defp frequently_social_messages?(messages) do
    social_keywords = ["hi", "hello", "thanks", "bye", "good", "nice"]
    
    social_count = messages
    |> Enum.count(fn msg ->
      content = String.downcase(msg[:content] || "")
      Enum.any?(social_keywords, &String.contains?(content, &1))
    end)
    
    social_count > length(messages) * 0.5
  end

  defp extract_message_topic(message) do
    content = String.downcase(message[:content] || "")
    
    cond do
      String.contains?(content, ["error", "problem", "bug"]) -> "technical_issue"
      String.contains?(content, ["status", "health", "metrics"]) -> "system_status" 
      String.contains?(content, ["help", "how", "what"]) -> "information_request"
      String.contains?(content, ["hi", "hello", "thanks"]) -> "social"
      true -> "general"
    end
  end

  defp has_enthusiastic_markers?(messages) do
    messages
    |> Enum.any?(fn msg ->
      content = msg[:content] || ""
      String.contains?(content, ["!", "awesome", "great", "perfect", "excellent"]) or
      String.match?(content, ~r/[😊😄😃🎉👍✨💯]/u)
    end)
  end

  defp has_detailed_messages?(messages) do
    messages
    |> Enum.any?(fn msg -> String.length(msg[:content] || "") > 100 end)
  end

  defp has_follow_up_questions?(messages) do
    messages
    |> Enum.any?(fn msg ->
      content = String.downcase(msg[:content] || "")
      String.contains?(content, ["also", "and", "what about", "how about"]) and
      String.contains?(content, "?")
    end)
  end

  defp calculate_pair_continuity([newer, older]) do
    # Simple continuity calculation - would use semantic similarity in real implementation
    newer_words = String.split(String.downcase(newer[:content] || ""))
    older_words = String.split(String.downcase(older[:content] || ""))
    
    common_words = MapSet.intersection(MapSet.new(newer_words), MapSet.new(older_words))
    total_words = MapSet.union(MapSet.new(newer_words), MapSet.new(older_words))
    
    if MapSet.size(total_words) == 0 do
      0.0
    else
      MapSet.size(common_words) / MapSet.size(total_words)
    end
  end

  defp classify_temporal_pattern(avg_interval) do
    cond do
      avg_interval < 60 -> :rapid_fire      # Less than 1 minute
      avg_interval < 300 -> :conversational # Less than 5 minutes
      avg_interval < 3600 -> :periodic      # Less than 1 hour
      true -> :sporadic                     # More than 1 hour
    end
  end

  defp classify_message_frequency(avg_interval) do
    cond do
      avg_interval < 30 -> :very_high
      avg_interval < 120 -> :high
      avg_interval < 600 -> :moderate
      avg_interval < 3600 -> :low
      true -> :very_low
    end
  end

  defp calculate_interval_regularity(intervals) do
    if length(intervals) < 2 do
      1.0
    else
      mean = Enum.sum(intervals) / length(intervals)
      variance = intervals
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(intervals))
      
      # Convert variance to regularity score (lower variance = higher regularity)
      max(0.0, 1.0 - variance / (mean * mean + 1))
    end
  end

  defp analyze_message_intent(text) do
    text_lower = String.downcase(text)
    
    cond do
      String.contains?(text_lower, ["help", "how", "what", "explain"]) -> :information_seeking
      String.contains?(text_lower, ["error", "problem", "issue", "bug"]) -> :problem_reporting
      String.contains?(text_lower, ["status", "health", "check"]) -> :status_inquiry
      String.contains?(text_lower, ["thanks", "thank you", "appreciate"]) -> :gratitude
      String.match?(text, ~r/^\s*(hi|hello|hey)/i) -> :greeting
      String.match?(text, ~r/\?$/) -> :question
      true -> :general_communication
    end
  end

  defp detect_emotional_tone(text) do
    text_lower = String.downcase(text)
    
    cond do
      String.contains?(text, ["!", "!!!"]) and 
      String.contains?(text_lower, ["urgent", "critical", "emergency"]) -> :urgent_stress
      String.contains?(text_lower, ["frustrated", "angry", "annoyed"]) -> :negative
      String.contains?(text_lower, ["thanks", "great", "awesome", "perfect"]) -> :positive
      String.match?(text, ~r/[😊😄😃🎉👍]/u) -> :positive
      String.match?(text, ~r/[😢😞😠😡]/u) -> :negative
      String.contains?(text, ["?"]) -> :curious
      true -> :neutral
    end
  end

  defp assess_message_complexity(text) do
    word_count = length(String.split(text))
    char_count = String.length(text)
    
    cond do
      char_count > 300 -> :high
      word_count > 50 -> :medium
      word_count > 10 -> :low
      true -> :minimal
    end
  end

  defp classify_response_type(response) do
    cond do
      String.contains?(response, ["```", "code"]) -> :technical_explanation
      String.length(response) > 200 -> :detailed_response
      String.contains?(response, ["?", "clarify", "more details"]) -> :clarifying_question
      String.match?(response, ~r/^(ok|yes|no|sure|thanks)/i) -> :simple_acknowledgment
      true -> :informative_response
    end
  end

  defp estimate_response_satisfaction(response, user_message) do
    # Simple satisfaction estimation based on response characteristics
    user_intent = analyze_message_intent(user_message)
    response_length = String.length(response)
    
    base_satisfaction = case user_intent do
      :information_seeking when response_length > 100 -> 0.8
      :problem_reporting -> 
        if Enum.any?(["understand", "help", "solve"], &String.contains?(response, &1)), do: 0.7, else: 0.6
      :status_inquiry -> 
        if Enum.any?(["status", "metrics", "health"], &String.contains?(response, &1)), do: 0.8, else: 0.6
      :question -> 
        if String.contains?(response, "?"), do: 0.6, else: 0.5  # Asked for clarification
      :greeting when response_length < 50 -> 0.9  # Brief greeting response is good
      _ -> 0.6
    end
    
    # Adjust based on response quality indicators
    quality_adjustments = [
      if String.contains?(response, ["error", "unable", "can't"]) do -0.2 else 0.0 end,
      if String.contains?(response, ["help", "assist", "support"]) do 0.1 else 0.0 end,
      if String.length(response) > 300 do -0.1 else 0.0 end,  # Too verbose
      if String.length(response) < 20 do -0.2 else 0.0 end    # Too brief
    ]
    
    final_satisfaction = base_satisfaction + Enum.sum(quality_adjustments)
    max(0.1, min(1.0, final_satisfaction))
  end

  defp compress_history_if_needed(history) do
    # If history is getting long, compress older messages while preserving recent context
    if length(history) > 40 do
      {recent, older} = Enum.split(history, 20)
      compressed_older = compress_message_batch(older)
      recent ++ compressed_older
    else
      history
    end
  end

  defp compress_message_batch(messages) do
    # Group messages by time periods and create summaries
    messages
    |> Enum.group_by(&get_time_period/1)
    |> Enum.map(&create_period_summary/1)
    |> Enum.take(5)  # Keep only 5 compressed periods
  end

  defp get_time_period(message) do
    case message[:timestamp] do
      nil -> :unknown
      timestamp ->
        DateTime.truncate(timestamp, :hour)
    end
  end

  defp create_period_summary({period, messages}) do
    %{
      role: "system",
      content: "Summary: #{length(messages)} messages in period #{period}",
      timestamp: period,
      type: :compressed_summary,
      original_count: length(messages)
    }
  end

  defp generate_context_summary(history) do
    recent_messages = Enum.take(history, 5)
    
    %{
      message_count: length(history),
      recent_topics: recent_messages |> Enum.map(&extract_message_topic/1) |> Enum.uniq(),
      dominant_intent: analyze_dominant_intent(recent_messages),
      engagement_level: assess_user_engagement(recent_messages),
      last_interaction: get_last_message_time(recent_messages)
    }
  end

  defp analyze_dominant_intent(messages) do
    intents = messages
    |> Enum.map(fn msg -> analyze_message_intent(msg[:content] || "") end)
    |> Enum.frequencies()
    
    case Enum.max_by(intents, fn {_intent, count} -> count end, fn -> {:general_communication, 0} end) do
      {intent, _count} -> intent
    end
  end

  defp track_topic_evolution(current_topic, new_message) do
    new_topic = extract_message_topic(%{content: new_message})
    
    if current_topic == new_topic do
      %{status: :continued, topic: current_topic, stability: :stable}
    else
      %{status: :shifted, from: current_topic, to: new_topic, stability: :transitioning}
    end
  end

  defp update_engagement_trajectory(current_level, new_message_entry) do
    new_level = case new_message_entry[:emotional_tone] do
      :positive -> min(1.0, current_level + 0.1)
      :negative -> max(0.0, current_level - 0.15)
      :urgent_stress -> max(0.0, current_level - 0.05)  # Stress but still engaged
      :curious -> min(1.0, current_level + 0.05)
      _ -> current_level
    end
    
    %{
      current: new_level,
      trend: determine_engagement_trend(current_level, new_level),
      last_updated: DateTime.utc_now()
    }
  end

  defp determine_engagement_trend(old_level, new_level) do
    diff = new_level - old_level
    
    cond do
      diff > 0.05 -> :increasing
      diff < -0.05 -> :decreasing
      true -> :stable
    end
  end

  defp calculate_context_relevance(message, conversation_context) do
    message_topic = extract_message_topic(%{content: message["text"] || ""})
    current_topic = conversation_context.current_topic
    
    if message_topic == current_topic do
      1.0
    else
      # Calculate semantic similarity - simplified version
      0.5
    end
  end

  defp detect_urgency_indicators(text) do
    urgency_markers = [
      {~r/urgent|emergency|critical|asap/i, 0.9},
      {~r/quickly|fast|soon|now/i, 0.6},
      {~r/!!!|multiple exclamation/i, 0.7},
      {~r/help|problem|issue|error/i, 0.4}
    ]
    
    max_urgency = urgency_markers
    |> Enum.map(fn {pattern, score} -> 
        if Regex.match?(pattern, text), do: score, else: 0.0
      end)
    |> Enum.max(fn -> 0.0 end)
    
    %{level: max_urgency, indicators: extract_matched_indicators(text, urgency_markers)}
  end

  defp extract_matched_indicators(text, markers) do
    markers
    |> Enum.filter(fn {pattern, _score} -> Regex.match?(pattern, text) end)
    |> Enum.map(fn {pattern, score} -> {pattern, score} end)
  end

  defp assess_conversation_momentum(context) do
    case context.temporal_patterns do
      %{frequency: frequency, regularity: regularity} ->
        base_momentum = case frequency do
          :very_high -> 0.9
          :high -> 0.7
          :moderate -> 0.5
          :low -> 0.3
          :very_low -> 0.1
        end
        
        # Adjust for regularity
        base_momentum * (0.5 + regularity * 0.5)
        
      _ -> 0.5  # Default moderate momentum
    end
  end
end