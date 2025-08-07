defmodule VsmPhoenix.VarietyEngineering.Filters.S1ToS2 do
  @moduledoc """
  Event Aggregation Filter: S1 → S2
  
  Reduces operational variety from System 1 to coordination patterns
  for System 2 by aggregating events and filtering noise.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @aggregation_window 5_000  # 5 seconds
  @pattern_threshold 0.7     # Significance threshold
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def set_threshold(threshold) do
    GenServer.call(@name, {:set_threshold, threshold})
  end
  
  def increase_filtering do
    GenServer.cast(@name, :increase_filtering)
  end
  
  def adjust_filtering(magnitude) do
    GenServer.cast(@name, {:adjust_filtering, magnitude})
  end
  
  def dampen_oscillations() do
    GenServer.cast(@name, :dampen_oscillations)
  end
  
  def get_stats do
    GenServer.call(@name, :get_stats)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔽 Starting S1→S2 Event Aggregation Filter...")
    
    state = %{
      event_buffer: %{},  # Grouped by context
      pattern_threshold: @pattern_threshold,
      filtering_level: 1.0,
      stats: %{
        events_received: 0,
        patterns_forwarded: 0,
        noise_filtered: 0,
        aggregation_ratio: 0.0,
        effectiveness_score: 1.0,
        pattern_quality: 1.0
      },
      adaptation_enabled: true,
      pattern_feedback: %{},  # Track S2 feedback on pattern quality
      effectiveness_history: []
    }
    
    # Subscribe to S1 events
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system1")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:operations")
    
    # Schedule periodic aggregation
    schedule_aggregation()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:set_threshold, threshold}, _from, state) do
    {:reply, :ok, %{state | pattern_threshold: threshold}}
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end
  
  @impl true
  def handle_cast(:increase_filtering, state) do
    new_level = min(state.filtering_level * 1.2, 2.0)
    Logger.info("📈 Increasing S1→S2 filtering to #{new_level}")
    {:noreply, %{state | filtering_level: new_level}}
  end
  
  @impl true
  def handle_cast({:adjust_filtering, magnitude}, state) do
    new_level = state.filtering_level * magnitude
    |> max(0.5)   # Minimum filtering (allow more through)
    |> min(3.0)   # Maximum filtering (very restrictive)
    
    Logger.info("🔧 Adjusting S1→S2 filtering: #{state.filtering_level} → #{new_level}")
    {:noreply, %{state | filtering_level: new_level}}
  end
  
  @impl true
  def handle_cast(:dampen_oscillations, state) do
    # Increase filtering to reduce oscillations
    dampened_level = state.filtering_level * 1.2
    |> min(2.5)
    
    # Also increase pattern threshold
    dampened_threshold = state.pattern_threshold * 1.1
    |> min(0.9)
    
    Logger.info("🎚️ Dampening S1→S2 oscillations: level=#{dampened_level}, threshold=#{dampened_threshold}")
    {:noreply, %{state | 
      filtering_level: dampened_level,
      pattern_threshold: dampened_threshold
    }}
  end
  
  @impl true
  def handle_info({:system1_event, event}, state) do
    # Buffer S1 events for aggregation
    context = event[:context] || :default
    timestamp = System.monotonic_time(:millisecond)
    
    new_buffer = Map.update(state.event_buffer, context, [{timestamp, event}], fn events ->
      [{timestamp, event} | events]
    end)
    
    new_stats = Map.update(state.stats, :events_received, 1, &(&1 + 1))
    
    {:noreply, %{state | event_buffer: new_buffer, stats: new_stats}}
  end
  
  @impl true
  def handle_info(:aggregate_events, state) do
    # Process buffered events into patterns
    patterns = state.event_buffer
               |> Enum.flat_map(fn {context, events} ->
                 extract_patterns(context, events, state.pattern_threshold)
               end)
               |> apply_filtering(state.filtering_level)
    
    # Forward significant patterns to S2
    Enum.each(patterns, fn pattern ->
      forward_to_s2(pattern)
    end)
    
    # Update stats
    new_stats = state.stats
                |> Map.update(:patterns_forwarded, length(patterns), &(&1 + length(patterns)))
                |> Map.put(:aggregation_ratio, calculate_ratio(state.stats))
    
    # Clear old events from buffer
    cleaned_buffer = clean_buffer(state.event_buffer)
    
    schedule_aggregation()
    {:noreply, %{state | event_buffer: cleaned_buffer, stats: new_stats}}
  end
  
  # Handle other S1 message formats
  def handle_info({topic, message}, state) when is_binary(topic) do
    if String.contains?(topic, "system1") do
      handle_info({:system1_event, normalize_message(message)}, state)
    else
      {:noreply, state}
    end
  end
  
  def handle_info(_, state), do: {:noreply, state}
  
  # Private functions
  
  defp extract_patterns(context, events, threshold) do
    # Group events by type and detect patterns
    events
    |> Enum.group_by(fn {_, event} -> event[:type] || :unknown end)
    |> Enum.filter(fn {_type, type_events} -> 
      # Pattern significance based on frequency
      length(type_events) / length(events) >= threshold
    end)
    |> Enum.map(fn {type, type_events} ->
      %{
        context: context,
        pattern_type: categorize_pattern(type, type_events),
        event_count: length(type_events),
        significance: calculate_significance(type_events, events),
        sample_events: Enum.take(type_events, 3),
        timestamp: DateTime.utc_now()
      }
    end)
  end
  
  defp categorize_pattern(type, events) do
    # Categorize patterns for S2 coordination
    cond do
      type in [:error, :failure, :exception] -> :anomaly_pattern
      type in [:resource_request, :allocation] -> :resource_pattern
      type in [:sync_required, :coordination] -> :coordination_pattern
      high_frequency?(events) -> :oscillation_pattern
      true -> :operational_pattern
    end
  end
  
  defp high_frequency?(events) do
    # Detect high-frequency oscillations
    length(events) > 10 && time_span(events) < 1000  # More than 10 events in 1 second
  end
  
  defp time_span(events) do
    timestamps = Enum.map(events, fn {ts, _} -> ts end)
    Enum.max(timestamps) - Enum.min(timestamps)
  end
  
  defp calculate_significance(type_events, all_events) do
    frequency = length(type_events) / length(all_events)
    recency = recent_event_weight(type_events)
    
    frequency * 0.7 + recency * 0.3
  end
  
  defp recent_event_weight(events) do
    now = System.monotonic_time(:millisecond)
    recent_count = Enum.count(events, fn {ts, _} -> now - ts < 2000 end)
    recent_count / length(events)
  end
  
  defp apply_filtering(patterns, filtering_level) do
    # Apply dynamic filtering based on current level
    min_significance = 0.5 * filtering_level
    
    patterns
    |> Enum.filter(fn pattern ->
      pattern.significance >= min_significance
    end)
    |> Enum.sort_by(& &1.significance, :desc)
    |> Enum.take(round(10 / filtering_level))  # Reduce variety as filtering increases
  end
  
  defp forward_to_s2(pattern) do
    # Send aggregated pattern to System 2
    message = {:coordination_pattern, pattern}
    
    # Via PubSub
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:system2",
      message
    )
    
    # Direct call if critical
    if pattern.pattern_type in [:anomaly_pattern, :oscillation_pattern] do
      VsmPhoenix.System2.Coordinator.dampen_oscillation(pattern.context, pattern)
    end
    
    # Track variety flow
    VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.record_message(:s2, :inbound, pattern.pattern_type)
  end
  
  defp clean_buffer(buffer) do
    cutoff = System.monotonic_time(:millisecond) - @aggregation_window
    
    buffer
    |> Enum.map(fn {context, events} ->
      filtered = Enum.filter(events, fn {ts, _} -> ts > cutoff end)
      {context, filtered}
    end)
    |> Enum.filter(fn {_, events} -> length(events) > 0 end)
    |> Map.new()
  end
  
  defp calculate_ratio(stats) do
    if stats.events_received > 0 do
      stats.patterns_forwarded / stats.events_received
    else
      0.0
    end
  end
  
  defp normalize_message(message) do
    case message do
      %{} = map -> map
      {type, data} -> %{type: type, data: data}
      _ -> %{type: :unknown, data: message}
    end
  end
  
  defp schedule_aggregation do
    Process.send_after(self(), :aggregate_events, @aggregation_window)
  end
end