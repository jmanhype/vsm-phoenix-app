defmodule VsmPhoenix.Events.PatternMatcher do
  @moduledoc """
  Real-Time Complex Event Processing (CEP) Pattern Matcher
  
  Features:
  - Complex event pattern detection
  - Temporal pattern matching
  - Event correlation rules
  - Real-time alerting
  - Pattern learning and adaptation
  - VSM-specific pattern recognition
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Events.{Store, Analytics}
  
  @name __MODULE__
  @pattern_window_ms 30_000  # 30 second sliding window
  @max_pattern_history 1000
  @critical_threshold 0.8
  
  # Pattern Types - Define as a function since attributes can't contain functions
  defp get_vsm_patterns do
    %{
    # System stability patterns
    "variety_imbalance" => %{
      events: ["variety.amplified", "variety.filtered"],
      condition: fn events -> 
        amplified = Enum.count(events, &(&1.event_type == "variety.amplified"))
        filtered = Enum.count(events, &(&1.event_type == "variety.filtered"))
        
        ratio = if filtered > 0, do: amplified / filtered, else: amplified
        ratio > 3.0  # More than 3:1 ratio indicates imbalance
      end,
      severity: :warning,
      action: :rebalance_variety
    },
    
    # Algedonic cascade pattern
    "algedonic_cascade" => %{
      events: ["algedonic.pain.detected", "system*.*.degraded"],
      condition: fn events ->
        pain_events = Enum.filter(events, &String.starts_with?(&1.event_type, "algedonic.pain"))
        system_events = Enum.filter(events, &String.contains?(&1.event_type, ".degraded"))
        
        length(pain_events) > 0 and length(system_events) >= 2
      end,
      severity: :critical,
      action: :trigger_autonomic_response
    },
    
    # Recursive spawning pattern
    "recursive_explosion" => %{
      events: ["recursion.meta_vsm.spawned"],
      condition: fn events ->
        spawn_events = Enum.filter(events, &(&1.event_type == "recursion.meta_vsm.spawned"))
        
        # Check for rapid spawning (>5 spawns in window)
        length(spawn_events) > 5
      end,
      severity: :critical,
      action: :limit_recursion
    },
    
    # System coordination breakdown
    "coordination_failure" => %{
      events: ["system2.coordination.failed", "system1.operation.timeout"],
      condition: fn events ->
        coordination_failures = Enum.count(events, &(&1.event_type == "system2.coordination.failed"))
        operation_timeouts = Enum.count(events, &(&1.event_type == "system1.operation.timeout"))
        
        coordination_failures >= 3 or operation_timeouts >= 5
      end,
      severity: :warning,
      action: :restart_coordination
    },
    
    # Intelligence overload pattern
    "intelligence_overload" => %{
      events: ["system4.intelligence.analyzed", "system4.analysis.timeout"],
      condition: fn events ->
        analyzed = Enum.count(events, &(&1.event_type == "system4.intelligence.analyzed"))
        timeouts = Enum.count(events, &(&1.event_type == "system4.analysis.timeout"))
        
        timeout_ratio = if analyzed > 0, do: timeouts / analyzed, else: 1.0
        timeout_ratio > 0.3  # >30% timeout rate
      end,
      severity: :warning,
      action: :scale_intelligence
    },
    
    # Emergent behavior detection
    "emergent_behavior" => %{
      events: ["emergent.*", "system*.unexpected.*"],
      condition: fn events ->
        emergent_events = Enum.filter(events, &String.starts_with?(&1.event_type, "emergent."))
        unexpected_events = Enum.filter(events, &String.contains?(&1.event_type, ".unexpected."))
        
        total_unusual = length(emergent_events) + length(unexpected_events)
        total_unusual >= 3
      end,
      severity: :info,
      action: :analyze_emergence
    },
    
    # Policy violation cascade
    "policy_violation_cascade" => %{
      events: ["system5.policy.violated", "system3.control.override"],
      condition: fn events ->
        violations = Enum.count(events, &(&1.event_type == "system5.policy.violated"))
        overrides = Enum.count(events, &(&1.event_type == "system3.control.override"))
        
        violations >= 2 and overrides >= 1
      end,
      severity: :critical,
      action: :enforce_policies
    }
  }
  end
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Process events for pattern matching
  """
  def process_events(events) when is_list(events) do
    GenServer.cast(@name, {:process_events, events})
  end
  
  @doc """
  Check for critical patterns immediately
  """
  def check_critical_patterns(event) do
    GenServer.cast(@name, {:check_critical, event})
  end
  
  @doc """
  Check for standard patterns (batched)
  """
  def check_standard_patterns(event) do
    GenServer.cast(@name, {:check_standard, event})
  end
  
  @doc """
  Add custom pattern rule
  """
  def add_pattern_rule(name, pattern_spec) do
    GenServer.call(@name, {:add_pattern, name, pattern_spec})
  end
  
  @doc """
  Get pattern statistics
  """
  def get_pattern_stats do
    GenServer.call(@name, :get_pattern_stats)
  end
  
  @doc """
  Train pattern recognition with historical data
  """
  def train_patterns(historical_events) do
    GenServer.cast(@name, {:train_patterns, historical_events})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔍 Starting Real-Time Pattern Matcher")
    
    # Subscribe to all events
    Store.subscribe_to_all(self())
    
    state = %{
      event_window: [],
      patterns: get_vsm_patterns(),
      custom_patterns: %{},
      pattern_matches: [],
      statistics: %{
        total_events_processed: 0,
        patterns_detected: 0,
        critical_patterns: 0,
        processing_time_ms: 0
      },
      learned_patterns: %{},
      correlation_cache: %{}
    }
    
    # Cleanup old events periodically
    :timer.send_interval(5000, :cleanup_window)
    
    # Generate pattern statistics
    :timer.send_interval(30000, :generate_stats)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:process_events, events}, state) do
    start_time = :erlang.system_time(:millisecond)
    
    Logger.debug("🔍 Processing #{length(events)} events for patterns")
    
    # Add events to sliding window
    new_window = add_events_to_window(state.event_window, events)
    
    # Check all patterns
    {pattern_matches, new_state} = check_all_patterns(new_window, state)
    
    # Process any matches
    process_pattern_matches(pattern_matches)
    
    # Update statistics
    processing_time = :erlang.system_time(:millisecond) - start_time
    updated_stats = update_statistics(new_state.statistics, length(events), length(pattern_matches), processing_time)
    
    final_state = %{new_state | 
      event_window: new_window,
      statistics: updated_stats
    }
    
    {:noreply, final_state}
  end
  
  @impl true
  def handle_cast({:check_critical, event}, state) do
    Logger.debug("⚡ Checking critical patterns for event: #{event.event_type}")
    
    # Add to window
    new_window = add_events_to_window(state.event_window, [event])
    
    # Only check critical patterns
    critical_patterns = get_critical_patterns(state.patterns, state.custom_patterns)
    {matches, new_state} = check_specific_patterns(new_window, critical_patterns, state)
    
    # Process critical matches immediately
    Enum.each(matches, fn match ->
      if match.severity == :critical do
        Logger.warn("🚨 CRITICAL PATTERN DETECTED: #{match.pattern_name}")
        handle_critical_pattern(match)
      end
    end)
    
    {:noreply, %{new_state | event_window: new_window}}
  end
  
  @impl true
  def handle_cast({:check_standard, event}, state) do
    # Add to batch for later processing
    new_window = add_events_to_window(state.event_window, [event])
    
    {:noreply, %{state | event_window: new_window}}
  end
  
  @impl true
  def handle_cast({:train_patterns, historical_events}, state) do
    Logger.info("🧠 Training pattern recognition with #{length(historical_events)} historical events")
    
    # Analyze historical events for new patterns
    learned_patterns = analyze_for_patterns(historical_events)
    
    # Merge with existing learned patterns
    new_learned = Map.merge(state.learned_patterns, learned_patterns)
    
    Logger.info("📚 Learned #{map_size(learned_patterns)} new patterns")
    
    {:noreply, %{state | learned_patterns: new_learned}}
  end
  
  @impl true
  def handle_call({:add_pattern, name, pattern_spec}, _from, state) do
    Logger.info("➕ Adding custom pattern: #{name}")
    
    new_custom = Map.put(state.custom_patterns, name, pattern_spec)
    
    {:reply, :ok, %{state | custom_patterns: new_custom}}
  end
  
  @impl true
  def handle_call(:get_pattern_stats, _from, state) do
    enhanced_stats = Map.merge(state.statistics, %{
      active_patterns: map_size(state.patterns) + map_size(state.custom_patterns),
      learned_patterns: map_size(state.learned_patterns),
      window_size: length(state.event_window),
      recent_matches: length(state.pattern_matches)
    })
    
    {:reply, enhanced_stats, state}
  end
  
  @impl true
  def handle_info({:event_appended, event}, state) do
    # Real-time event processing
    new_window = add_events_to_window(state.event_window, [event])
    
    # Quick check for immediate patterns
    quick_matches = check_immediate_patterns(event, new_window, state)
    
    unless Enum.empty?(quick_matches) do
      process_pattern_matches(quick_matches)
    end
    
    {:noreply, %{state | event_window: new_window}}
  end
  
  @impl true
  def handle_info(:cleanup_window, state) do
    # Remove events older than the window
    cutoff_time = DateTime.add(DateTime.utc_now(), -@pattern_window_ms, :millisecond)
    
    new_window = Enum.filter(state.event_window, fn event ->
      DateTime.compare(event.timestamp, cutoff_time) == :gt
    end)
    
    # Also cleanup old pattern matches
    new_matches = Enum.take(state.pattern_matches, -100)  # Keep last 100 matches
    
    {:noreply, %{state | event_window: new_window, pattern_matches: new_matches}}
  end
  
  @impl true
  def handle_info(:generate_stats, state) do
    # Generate and broadcast pattern statistics
    stats = %{
      events_in_window: length(state.event_window),
      total_patterns: map_size(state.patterns) + map_size(state.custom_patterns),
      recent_matches: length(Enum.take(state.pattern_matches, -10)),
      processing_rate: state.statistics.total_events_processed / max(1, :erlang.system_time(:second) - 1000),
      pattern_efficiency: calculate_pattern_efficiency(state)
    }
    
    # Broadcast stats
    Phoenix.PubSub.broadcast!(
      VsmPhoenix.PubSub,
      "events:pattern_stats",
      {:pattern_statistics, stats}
    )
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp add_events_to_window(window, events) do
    # Add new events and keep window size manageable
    new_window = window ++ events
    
    if length(new_window) > @max_pattern_history do
      Enum.take(new_window, -@max_pattern_history)
    else
      new_window
    end
  end
  
  defp check_all_patterns(event_window, state) do
    all_patterns = Map.merge(state.patterns, state.custom_patterns)
    check_specific_patterns(event_window, all_patterns, state)
  end
  
  defp check_specific_patterns(event_window, patterns, state) do
    matches = Enum.reduce(patterns, [], fn {pattern_name, pattern_spec}, acc ->
      case evaluate_pattern(pattern_name, pattern_spec, event_window) do
        {:match, match_data} ->
          match = %{
            pattern_name: pattern_name,
            severity: pattern_spec.severity,
            action: pattern_spec.action,
            matched_events: match_data.events,
            confidence: match_data.confidence,
            timestamp: DateTime.utc_now()
          }
          [match | acc]
        
        :no_match ->
          acc
      end
    end)
    
    # Update pattern matches history
    new_matches = state.pattern_matches ++ matches
    new_state = %{state | pattern_matches: new_matches}
    
    {matches, new_state}
  end
  
  defp evaluate_pattern(pattern_name, pattern_spec, event_window) do
    # Filter events that match the pattern event types
    relevant_events = filter_relevant_events(event_window, pattern_spec.events)
    
    if length(relevant_events) >= 2 do
      # Check temporal constraints (events within window)
      recent_events = filter_recent_events(relevant_events, @pattern_window_ms)
      
      if length(recent_events) >= 1 do
        # Evaluate pattern condition
        case pattern_spec.condition.(recent_events) do
          true ->
            confidence = calculate_pattern_confidence(recent_events, pattern_spec)
            {:match, %{events: recent_events, confidence: confidence}}
          
          false ->
            :no_match
        end
      else
        :no_match
      end
    else
      :no_match
    end
  end
  
  defp filter_relevant_events(events, pattern_event_types) do
    Enum.filter(events, fn event ->
      Enum.any?(pattern_event_types, fn pattern_type ->
        match_event_type?(event.event_type, pattern_type)
      end)
    end)
  end
  
  defp match_event_type?(event_type, pattern_type) do
    cond do
      # Exact match
      event_type == pattern_type ->
        true
      
      # Wildcard match (e.g., "system*" matches "system1.operation.completed")
      String.ends_with?(pattern_type, "*") ->
        prefix = String.trim_trailing(pattern_type, "*")
        String.starts_with?(event_type, prefix)
      
      # Contains match (e.g., "*.degraded" matches "system1.service.degraded")
      String.starts_with?(pattern_type, "*") ->
        suffix = String.trim_leading(pattern_type, "*")
        String.ends_with?(event_type, suffix)
      
      # Middle wildcard (e.g., "system*.degraded")
      String.contains?(pattern_type, "*") ->
        [prefix, suffix] = String.split(pattern_type, "*", parts: 2)
        String.starts_with?(event_type, prefix) and String.ends_with?(event_type, suffix)
      
      true ->
        false
    end
  end
  
  defp filter_recent_events(events, window_ms) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -window_ms, :millisecond)
    
    Enum.filter(events, fn event ->
      DateTime.compare(event.timestamp, cutoff_time) == :gt
    end)
  end
  
  defp calculate_pattern_confidence(events, _pattern_spec) do
    # Simple confidence calculation based on event recency and frequency
    now = DateTime.utc_now()
    
    recency_scores = Enum.map(events, fn event ->
      age_ms = DateTime.diff(now, event.timestamp, :millisecond)
      max(0.0, 1.0 - (age_ms / @pattern_window_ms))
    end)
    
    avg_recency = Enum.sum(recency_scores) / length(recency_scores)
    frequency_score = min(1.0, length(events) / 5.0)  # Normalize to max 5 events
    
    (avg_recency + frequency_score) / 2
  end
  
  defp get_critical_patterns(patterns, custom_patterns) do
    all_patterns = Map.merge(patterns, custom_patterns)
    
    Enum.filter(all_patterns, fn {_name, spec} ->
      spec.severity == :critical
    end)
    |> Enum.into(%{})
  end
  
  defp check_immediate_patterns(event, event_window, state) do
    # Check only patterns that could be triggered by this single event
    immediate_patterns = Map.filter(state.patterns, fn {_name, spec} ->
      Enum.any?(spec.events, &match_event_type?(event.event_type, &1))
    end)
    
    {matches, _} = check_specific_patterns(event_window, immediate_patterns, state)
    matches
  end
  
  defp process_pattern_matches(matches) do
    Enum.each(matches, fn match ->
      Logger.info("🎯 Pattern detected: #{match.pattern_name} (#{match.severity}, confidence: #{Float.round(match.confidence, 2)})")
      
      # Record match in analytics
      Analytics.record_pattern_match(match)
      
      # Broadcast pattern match
      Phoenix.PubSub.broadcast!(
        VsmPhoenix.PubSub,
        "events:patterns",
        {:pattern_detected, match}
      )
      
      # Execute pattern action
      execute_pattern_action(match)
    end)
  end
  
  defp execute_pattern_action(match) do
    case match.action do
      :rebalance_variety ->
        Logger.info("🔄 Executing variety rebalancing")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "variety:rebalance", {:rebalance_request, match})
      
      :trigger_autonomic_response ->
        Logger.warn("⚡ Triggering autonomic response for algedonic cascade")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "algedonic:response", {:autonomic_trigger, match})
      
      :limit_recursion ->
        Logger.warn("🛑 Limiting recursive spawning")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "recursion:limit", {:limit_spawning, match})
      
      :restart_coordination ->
        Logger.info("🔄 Restarting coordination system")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "system2:restart", {:restart_request, match})
      
      :scale_intelligence ->
        Logger.info("📈 Scaling intelligence capacity")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "system4:scale", {:scale_request, match})
      
      :analyze_emergence ->
        Logger.info("🔬 Analyzing emergent behavior")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "emergence:analyze", {:analyze_request, match})
      
      :enforce_policies ->
        Logger.warn("📜 Enforcing policy compliance")
        Phoenix.PubSub.broadcast!(VsmPhoenix.PubSub, "system5:enforce", {:enforce_request, match})
      
      _ ->
        Logger.debug("❓ Unknown pattern action: #{match.action}")
    end
  end
  
  defp handle_critical_pattern(match) do
    # Immediate response for critical patterns
    case match.action do
      :trigger_autonomic_response ->
        # Emergency response
        Logger.error("🚨 EMERGENCY: Algedonic cascade detected - triggering immediate response")
        
        # Could trigger system-wide emergency procedures
        Phoenix.PubSub.broadcast!(
          VsmPhoenix.PubSub, 
          "emergency:response", 
          {:critical_pattern, match}
        )
      
      :limit_recursion ->
        Logger.error("🚨 EMERGENCY: Recursive explosion detected - limiting recursion")
        
        # Could immediately halt recursive spawning
        Phoenix.PubSub.broadcast!(
          VsmPhoenix.PubSub,
          "emergency:recursion",
          {:emergency_limit, match}
        )
      
      _ ->
        # Standard critical pattern handling
        execute_pattern_action(match)
    end
  end
  
  defp analyze_for_patterns(historical_events) do
    # Simple pattern learning - identify frequent event sequences
    event_sequences = extract_event_sequences(historical_events, 3)  # 3-event sequences
    
    frequent_sequences = event_sequences
    |> Enum.frequencies()
    |> Enum.filter(fn {_sequence, count} -> count >= 5 end)  # Occurred at least 5 times
    |> Enum.map(fn {sequence, count} ->
        pattern_name = "learned_#{sequence |> Enum.join("_") |> String.replace(".", "_")}"
        
        pattern_spec = %{
          events: sequence,
          condition: fn events ->
            # Simple condition: all events in sequence present
            sequence_events = Enum.map(sequence, fn event_type ->
              Enum.find(events, &(&1.event_type == event_type))
            end)
            
            Enum.all?(sequence_events, &(&1 != nil))
          end,
          severity: :info,
          action: :log_learned_pattern,
          learned: true,
          frequency: count
        }
        
        {pattern_name, pattern_spec}
      end)
    |> Enum.into(%{})
    
    frequent_sequences
  end
  
  defp extract_event_sequences(events, sequence_length) do
    events
    |> Enum.sort_by(& &1.timestamp, DateTime)
    |> Enum.chunk_every(sequence_length, 1, :discard)
    |> Enum.map(fn chunk ->
        Enum.map(chunk, & &1.event_type)
      end)
  end
  
  defp update_statistics(stats, events_processed, patterns_detected, processing_time) do
    %{stats |
      total_events_processed: stats.total_events_processed + events_processed,
      patterns_detected: stats.patterns_detected + patterns_detected,
      critical_patterns: stats.critical_patterns + Enum.count([], & &1.severity == :critical),
      processing_time_ms: stats.processing_time_ms + processing_time
    }
  end
  
  defp calculate_pattern_efficiency(state) do
    if state.statistics.total_events_processed > 0 do
      state.statistics.patterns_detected / state.statistics.total_events_processed
    else
      0.0
    end
  end
end