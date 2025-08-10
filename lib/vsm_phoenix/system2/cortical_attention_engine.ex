defmodule VsmPhoenix.System2.CorticalAttentionEngine do
  @moduledoc """
  Cortical Attention-Engine for System 2 - Neuroscience-inspired attention mechanism
  
  Implements selective attention, priority weighting, and cognitive load management
  based on cortical attention principles from neuroscience.
  
  Key Features:
  - Dynamic attention scoring based on message salience
  - Context-aware priority weighting
  - Attention fatigue and recovery cycles
  - Multi-scale temporal attention windows
  - Selective filtering and routing
  - Attention shift detection and management
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Infrastructure.{CoordinationMetrics, SystemicCoordinationMetrics}
  
  # Attention states inspired by neuroscience
  @attention_states [:focused, :distributed, :shifting, :fatigued, :recovering]
  
  # Temporal scales for attention windows (milliseconds)
  @temporal_scales %{
    immediate: 100,      # Reflexive attention
    short_term: 1000,    # Working memory window
    sustained: 10_000,   # Sustained attention
    long_term: 60_000    # Long-term tracking
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def score_attention(message, context) do
    GenServer.call(__MODULE__, {:score_attention, message, context})
  end
  
  def filter_by_attention(messages, threshold \\ 0.5) do
    GenServer.call(__MODULE__, {:filter_by_attention, messages, threshold})
  end
  
  def get_attention_state do
    GenServer.call(__MODULE__, :get_attention_state)
  end
  
  def shift_attention(new_focus) do
    GenServer.cast(__MODULE__, {:shift_attention, new_focus})
  end
  
  def get_attention_metrics do
    GenServer.call(__MODULE__, :get_attention_metrics)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🧠 Cortical Attention-Engine initializing...")
    
    state = %{
      # Current attention state
      attention_state: :distributed,
      current_focus: nil,
      
      # Attention scoring parameters
      salience_weights: %{
        novelty: 0.3,          # How new/unexpected
        urgency: 0.25,         # Time criticality
        relevance: 0.2,        # Context relevance
        intensity: 0.15,       # Signal strength
        coherence: 0.1         # Pattern coherence
      },
      
      # Attention windows for different temporal scales
      attention_windows: %{
        immediate: [],
        short_term: [],
        sustained: [],
        long_term: []
      },
      
      # Attention fatigue tracking
      fatigue_level: 0.0,
      recovery_rate: 0.01,
      fatigue_threshold: 0.7,
      
      # Context memory for relevance scoring
      context_memory: %{},
      context_decay_rate: 0.95,
      
      # Performance metrics
      metrics: %{
        messages_processed: 0,
        attention_shifts: 0,
        filtered_count: 0,
        average_attention_score: 0.0,
        peak_salience_events: []
      },
      
      # Neuroplasticity - learning from patterns
      learned_patterns: %{},
      learning_rate: 0.1
    }
    
    # Schedule periodic maintenance
    schedule_attention_maintenance()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:score_attention, message, context}, _from, state) do
    # Calculate multi-dimensional attention score
    score_components = %{
      novelty: calculate_novelty(message, state),
      urgency: calculate_urgency(message),
      relevance: calculate_relevance(message, context, state),
      intensity: calculate_intensity(message),
      coherence: calculate_coherence(message, state)
    }
    
    # Apply current attention state modulation
    state_multiplier = get_state_multiplier(state.attention_state)
    
    # Calculate weighted score
    base_score = Enum.reduce(score_components, 0.0, fn {component, value}, acc ->
      weight = state.salience_weights[component] || 0.0
      acc + (value * weight)
    end)
    
    # Apply fatigue dampening
    fatigue_factor = 1.0 - (state.fatigue_level * 0.5)
    final_score = base_score * state_multiplier * fatigue_factor
    
    # Update attention windows
    new_state = update_attention_windows(state, message, final_score)
    
    # Track metrics
    updated_state = update_attention_metrics(new_state, final_score)
    
    {:reply, {:ok, final_score, score_components}, updated_state}
  end
  
  @impl true
  def handle_call({:filter_by_attention, messages, threshold}, _from, state) do
    # Score all messages
    scored_messages = Enum.map(messages, fn msg ->
      {:ok, score, _components} = score_attention_internal(msg, msg[:context] || %{}, state)
      {msg, score}
    end)
    
    # Filter by threshold
    filtered = scored_messages
    |> Enum.filter(fn {_msg, score} -> score >= threshold end)
    |> Enum.sort_by(fn {_msg, score} -> score end, :desc)
    |> Enum.map(fn {msg, _score} -> msg end)
    
    # Update metrics
    new_metrics = Map.update!(state.metrics, :filtered_count, &(&1 + length(messages) - length(filtered)))
    new_state = %{state | metrics: new_metrics}
    
    {:reply, {:ok, filtered}, new_state}
  end
  
  @impl true
  def handle_call(:get_attention_state, _from, state) do
    attention_info = %{
      state: state.attention_state,
      focus: state.current_focus,
      fatigue_level: state.fatigue_level,
      active_patterns: get_active_patterns(state),
      temporal_summary: summarize_temporal_windows(state)
    }
    
    {:reply, {:ok, attention_info}, state}
  end
  
  @impl true
  def handle_call(:get_attention_metrics, _from, state) do
    metrics = Map.merge(state.metrics, %{
      fatigue_level: state.fatigue_level,
      attention_state: state.attention_state,
      learned_patterns_count: map_size(state.learned_patterns),
      context_memory_size: map_size(state.context_memory)
    })
    
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_cast({:shift_attention, new_focus}, state) do
    Logger.info("🧠 Attention shifting to: #{inspect(new_focus)}")
    
    # Record attention shift
    new_metrics = Map.update!(state.metrics, :attention_shifts, &(&1 + 1))
    
    # Calculate shift cost (fatigue)
    shift_cost = calculate_shift_cost(state.current_focus, new_focus)
    new_fatigue = min(state.fatigue_level + shift_cost, 1.0)
    
    # Update state
    new_state = %{state |
      attention_state: :shifting,
      current_focus: new_focus,
      fatigue_level: new_fatigue,
      metrics: new_metrics
    }
    
    # Schedule transition to focused state
    Process.send_after(self(), :complete_attention_shift, 100)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:attention_maintenance, state) do
    # Recover from fatigue
    new_fatigue = max(0.0, state.fatigue_level - state.recovery_rate)
    
    # Decay context memory
    decayed_context = decay_context_memory(state.context_memory, state.context_decay_rate)
    
    # Clean old entries from attention windows
    cleaned_windows = clean_attention_windows(state.attention_windows)
    
    # Update attention state based on fatigue
    new_attention_state = cond do
      new_fatigue > state.fatigue_threshold -> :fatigued
      new_fatigue < 0.2 and state.attention_state == :fatigued -> :recovering
      state.attention_state == :recovering and new_fatigue < 0.1 -> :distributed
      true -> state.attention_state
    end
    
    new_state = %{state |
      fatigue_level: new_fatigue,
      context_memory: decayed_context,
      attention_windows: cleaned_windows,
      attention_state: new_attention_state
    }
    
    # Report metrics if significant changes
    if state.attention_state != new_attention_state do
      report_attention_metrics(new_state)
    end
    
    schedule_attention_maintenance()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:complete_attention_shift, state) do
    new_state = %{state | attention_state: :focused}
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp score_attention_internal(message, context, state) do
    score_components = %{
      novelty: calculate_novelty(message, state),
      urgency: calculate_urgency(message),
      relevance: calculate_relevance(message, context, state),
      intensity: calculate_intensity(message),
      coherence: calculate_coherence(message, state)
    }
    
    state_multiplier = get_state_multiplier(state.attention_state)
    
    base_score = Enum.reduce(score_components, 0.0, fn {component, value}, acc ->
      weight = state.salience_weights[component] || 0.0
      acc + (value * weight)
    end)
    
    fatigue_factor = 1.0 - (state.fatigue_level * 0.5)
    final_score = base_score * state_multiplier * fatigue_factor
    
    {:ok, final_score, score_components}
  end
  
  defp calculate_novelty(message, state) do
    # Check if similar message seen recently
    message_hash = hash_message(message)
    
    novelty = Enum.reduce(@temporal_scales, 1.0, fn {scale, _window}, acc ->
      window = Map.get(state.attention_windows, scale, [])
      
      similar_count = Enum.count(window, fn {_time, _score, msg_hash} ->
        msg_hash == message_hash
      end)
      
      # Reduce novelty based on repetition
      acc * :math.exp(-similar_count * 0.5)
    end)
    
    novelty
  end
  
  defp calculate_urgency(message) do
    cond do
      message[:priority] == :critical -> 1.0
      message[:priority] == :high -> 0.8
      message[:deadline] ->
        # Calculate based on time to deadline
        time_to_deadline = DateTime.diff(message[:deadline], DateTime.utc_now(), :millisecond)
        1.0 - min(1.0, time_to_deadline / 60_000)  # Normalize to 1 minute
      message[:type] in [:alarm, :alert, :emergency] -> 0.9
      true -> 0.3
    end
  end
  
  defp calculate_relevance(message, context, state) do
    # Check context memory for related patterns
    context_key = context[:id] || context[:source] || :unknown
    
    context_weight = Map.get(state.context_memory, context_key, 0.0)
    
    # Check if message relates to current focus
    focus_relevance = if state.current_focus do
      calculate_focus_similarity(message, state.current_focus)
    else
      0.5
    end
    
    # NEW: Calculate conversation continuity relevance from TelegramContextManager
    conversation_relevance = case context[:conversation_history] do
      %{context: %{semantic_continuity: semantic_continuity, conversation_coherence: coherence}} ->
        # Boost relevance based on conversation continuity and coherence
        base_continuity = (semantic_continuity || 0.5) * 0.3
        coherence_boost = (coherence || 0.5) * 0.2
        base_continuity + coherence_boost
      
      %{messages: messages} when length(messages) > 0 ->
        # Fallback: simple message history relevance
        min(0.4, length(messages) * 0.05)
      
      _ ->
        0.0
    end
    
    # Combine all relevance factors
    combined_relevance = max(context_weight, max(focus_relevance, conversation_relevance))
    
    # Ensure conversation continuity gets priority
    if conversation_relevance > 0.3 do
      min(1.0, combined_relevance + 0.2)  # Boost messages with good conversation continuity
    else
      combined_relevance
    end
  end
  
  defp calculate_intensity(message) do
    # Signal intensity based on message characteristics
    base_intensity = 0.5
    
    modifiers = [
      if(message[:volume] == :high, do: 0.2, else: 0.0),
      if(message[:repeat_count] && message[:repeat_count] > 3, do: 0.1, else: 0.0),
      if(message[:source_authority] == :high, do: 0.15, else: 0.0),
      if(map_size(message) > 10, do: 0.05, else: 0.0)  # Complex messages
    ]
    
    min(1.0, base_intensity + Enum.sum(modifiers))
  end
  
  defp calculate_coherence(message, state) do
    # Check if message fits learned patterns
    pattern_matches = Enum.reduce(state.learned_patterns, 0, fn {pattern_id, pattern}, acc ->
      if matches_pattern?(message, pattern) do
        acc + pattern.strength
      else
        acc
      end
    end)
    
    # Normalize to 0-1 range
    min(1.0, pattern_matches)
  end
  
  defp get_state_multiplier(attention_state) do
    case attention_state do
      :focused -> 1.2      # Enhanced attention
      :distributed -> 1.0  # Normal attention
      :shifting -> 0.8     # Reduced during transition
      :fatigued -> 0.6     # Significantly reduced
      :recovering -> 0.8   # Gradually improving
    end
  end
  
  defp update_attention_windows(state, message, score) do
    now = :erlang.system_time(:millisecond)
    message_hash = hash_message(message)
    entry = {now, score, message_hash}
    
    # Update windows if score is significant
    if score > 0.3 do
      new_windows = Enum.reduce(@temporal_scales, state.attention_windows, fn {scale, window_size}, acc ->
        window = Map.get(acc, scale, [])
        
        # Add new entry and trim old ones
        updated_window = [entry | window]
        |> Enum.filter(fn {time, _, _} -> now - time < window_size end)
        |> Enum.take(1000)  # Limit size
        
        Map.put(acc, scale, updated_window)
      end)
      
      %{state | attention_windows: new_windows}
    else
      state
    end
  end
  
  defp update_attention_metrics(state, score) do
    metrics = state.metrics
    
    # Update running average
    total_messages = metrics.messages_processed + 1
    new_avg = ((metrics.average_attention_score * metrics.messages_processed) + score) / total_messages
    
    # Track peak salience events
    peak_events = if score > 0.8 do
      [{DateTime.utc_now(), score} | metrics.peak_salience_events]
      |> Enum.take(100)
    else
      metrics.peak_salience_events
    end
    
    new_metrics = %{metrics |
      messages_processed: total_messages,
      average_attention_score: new_avg,
      peak_salience_events: peak_events
    }
    
    %{state | metrics: new_metrics}
  end
  
  defp hash_message(message) do
    # Create a simple hash for message comparison
    :erlang.phash2({message[:type], message[:source], message[:target]})
  end
  
  defp calculate_shift_cost(old_focus, new_focus) do
    # Higher cost for larger context switches
    if old_focus == new_focus do
      0.0
    else
      base_cost = 0.1
      
      # Add cost based on difference
      if old_focus && new_focus do
        similarity = calculate_focus_similarity(old_focus, new_focus)
        base_cost + (1.0 - similarity) * 0.2
      else
        base_cost
      end
    end
  end
  
  defp calculate_focus_similarity(item1, item2) do
    # Simple similarity based on shared keys/values
    keys1 = if is_map(item1), do: Map.keys(item1), else: []
    keys2 = if is_map(item2), do: Map.keys(item2), else: []
    
    shared_keys = MapSet.intersection(MapSet.new(keys1), MapSet.new(keys2))
    
    if MapSet.size(shared_keys) > 0 do
      MapSet.size(shared_keys) / max(length(keys1), length(keys2))
    else
      0.0
    end
  end
  
  defp decay_context_memory(context_memory, decay_rate) do
    context_memory
    |> Enum.map(fn {key, weight} -> {key, weight * decay_rate} end)
    |> Enum.filter(fn {_key, weight} -> weight > 0.01 end)
    |> Map.new()
  end
  
  defp clean_attention_windows(windows) do
    now = :erlang.system_time(:millisecond)
    
    Enum.reduce(@temporal_scales, windows, fn {scale, window_size}, acc ->
      window = Map.get(acc, scale, [])
      
      cleaned = Enum.filter(window, fn {time, _, _} ->
        now - time < window_size * 2  # Keep 2x window for analysis
      end)
      
      Map.put(acc, scale, cleaned)
    end)
  end
  
  defp get_active_patterns(state) do
    # Analyze attention windows for active patterns
    immediate_window = Map.get(state.attention_windows, :immediate, [])
    
    if length(immediate_window) > 5 do
      # Simple pattern detection
      scores = Enum.map(immediate_window, fn {_, score, _} -> score end)
      avg_score = Enum.sum(scores) / length(scores)
      
      %{
        activity_level: cond do
          avg_score > 0.7 -> :high
          avg_score > 0.4 -> :medium
          true -> :low
        end,
        pattern_type: detect_pattern_type(immediate_window)
      }
    else
      %{activity_level: :low, pattern_type: :none}
    end
  end
  
  defp detect_pattern_type(window) do
    # Simple pattern detection
    scores = Enum.map(window, fn {_, score, _} -> score end)
    
    cond do
      all_similar?(scores, 0.1) -> :steady
      increasing?(scores) -> :escalating
      decreasing?(scores) -> :diminishing
      oscillating?(scores) -> :oscillating
      true -> :mixed
    end
  end
  
  defp all_similar?(scores, threshold) do
    if length(scores) < 2, do: true, else: Enum.max(scores) - Enum.min(scores) < threshold
  end
  
  defp increasing?(scores) do
    scores == Enum.sort(scores)
  end
  
  defp decreasing?(scores) do
    scores == Enum.sort(scores, :desc)
  end
  
  defp oscillating?(scores) do
    # Simple oscillation check
    length(scores) > 4 and variance(scores) > 0.2
  end
  
  defp variance(scores) do
    mean = Enum.sum(scores) / length(scores)
    squared_diffs = Enum.map(scores, fn x -> :math.pow(x - mean, 2) end)
    Enum.sum(squared_diffs) / length(scores)
  end
  
  defp summarize_temporal_windows(state) do
    Enum.reduce(@temporal_scales, %{}, fn {scale, _}, acc ->
      window = Map.get(state.attention_windows, scale, [])
      
      summary = if length(window) > 0 do
        scores = Enum.map(window, fn {_, score, _} -> score end)
        %{
          count: length(window),
          average_score: Enum.sum(scores) / length(scores),
          max_score: Enum.max(scores),
          trend: detect_pattern_type(window)
        }
      else
        %{count: 0, average_score: 0.0, max_score: 0.0, trend: :none}
      end
      
      Map.put(acc, scale, summary)
    end)
  end
  
  defp matches_pattern?(message, pattern) do
    # Simple pattern matching
    required_keys = Map.get(pattern, :required_keys, [])
    Enum.all?(required_keys, fn key -> Map.has_key?(message, key) end)
  end
  
  defp report_attention_metrics(state) do
    # Report to coordination metrics
    CoordinationMetrics.record_custom_metric(
      :attention_state_change,
      %{
        from: state.attention_state,
        fatigue_level: state.fatigue_level,
        messages_processed: state.metrics.messages_processed
      }
    )
    
    # Log significant state changes
    Logger.info("🧠 Attention state changed to: #{state.attention_state} (fatigue: #{Float.round(state.fatigue_level, 2)})")
  end
  
  defp schedule_attention_maintenance do
    Process.send_after(self(), :attention_maintenance, 1000)  # Every second
  end
end