defmodule VsmPhoenix.Goldrush.EventAggregator do
  @moduledoc """
  Event Aggregation and Fusion for GoldRush
  
  Features:
  - Time-window based event processing
  - Event fusion and correlation
  - Hierarchical event management
  - Stream processing with backpressure
  - Statistical aggregations (avg, min, max, percentiles)
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @window_cleanup_interval 60_000  # 1 minute
  @max_windows_per_type 100  # Maximum time windows to keep per event type
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Add an event to the aggregator
  """
  def add_event(event) do
    GenServer.cast(@name, {:add_event, event})
  end
  
  @doc """
  Get aggregated data for a specific time window
  
  Options:
  - event_type: Filter by event type
  - window_size: Time window in seconds (default: 60)
  - aggregations: List of aggregations [:count, :avg, :min, :max, :sum, :percentiles]
  """
  def get_window_aggregates(opts \\ []) do
    GenServer.call(@name, {:get_aggregates, opts})
  end
  
  @doc """
  Get correlated events within a time window
  """
  def get_correlated_events(event_types, time_window_seconds \\ 60) do
    GenServer.call(@name, {:get_correlated, event_types, time_window_seconds})
  end
  
  @doc """
  Create a hierarchical event from child events
  """
  def create_hierarchical_event(parent_type, child_events, metadata \\ %{}) do
    GenServer.call(@name, {:create_hierarchical, parent_type, child_events, metadata})
  end
  
  @doc """
  Get event stream statistics
  """
  def get_stream_stats do
    GenServer.call(@name, :get_stream_stats)
  end
  
  @doc """
  Fusion multiple events into a composite event
  """
  def fuse_events(events, fusion_type) do
    GenServer.call(@name, {:fuse_events, events, fusion_type})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("📊 Initializing GoldRush Event Aggregator")
    
    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup_old_windows, @window_cleanup_interval)
    
    state = %{
      # Time windows: {event_type, window_start} => events
      time_windows: %{},
      
      # Hierarchical events: parent_id => {parent_event, child_events}
      hierarchical_events: %{},
      
      # Stream statistics
      stream_stats: %{
        total_events: 0,
        events_per_second: 0,
        event_types: %{},
        last_update: System.system_time(:second)
      },
      
      # Event correlations
      correlation_cache: %{},
      
      # Sliding window for rate calculation
      recent_events: :queue.new(),
      
      # Backpressure control
      backpressure: %{
        enabled: false,
        threshold: 10_000,
        current_load: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:add_event, event}, state) do
    # Check backpressure
    if should_drop_event?(state.backpressure) do
      Logger.warn("⚠️ Dropping event due to backpressure")
      {:noreply, state}
    else
      new_state = state
      |> add_to_time_windows(event)
      |> update_stream_stats(event)
      |> update_recent_events(event)
      |> check_backpressure()
      
      {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_call({:get_aggregates, opts}, _from, state) do
    event_type = Keyword.get(opts, :event_type)
    window_size = Keyword.get(opts, :window_size, 60)
    aggregations = Keyword.get(opts, :aggregations, [:count, :avg])
    
    aggregates = calculate_aggregates(state.time_windows, event_type, window_size, aggregations)
    
    {:reply, {:ok, aggregates}, state}
  end
  
  @impl true
  def handle_call({:get_correlated, event_types, time_window}, _from, state) do
    correlations = find_correlations(state.time_windows, event_types, time_window)
    {:reply, {:ok, correlations}, state}
  end
  
  @impl true
  def handle_call({:create_hierarchical, parent_type, child_events, metadata}, _from, state) do
    parent_event = create_parent_event(parent_type, child_events, metadata)
    parent_id = parent_event.id
    
    new_hierarchical = Map.put(
      state.hierarchical_events,
      parent_id,
      {parent_event, child_events}
    )
    
    # Also add to time windows
    new_state = %{state | hierarchical_events: new_hierarchical}
    |> add_to_time_windows(parent_event)
    
    {:reply, {:ok, parent_event}, new_state}
  end
  
  @impl true
  def handle_call(:get_stream_stats, _from, state) do
    stats = calculate_current_stats(state)
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_call({:fuse_events, events, fusion_type}, _from, state) do
    fused_event = perform_event_fusion(events, fusion_type)
    
    # Add fused event to the stream
    new_state = state
    |> add_to_time_windows(fused_event)
    |> update_stream_stats(fused_event)
    
    {:reply, {:ok, fused_event}, new_state}
  end
  
  @impl true
  def handle_info(:cleanup_old_windows, state) do
    now = System.system_time(:second)
    cutoff_time = now - 3600  # Keep last hour of data
    
    new_windows = state.time_windows
    |> Enum.filter(fn {{_type, window_start}, _events} ->
      window_start > cutoff_time
    end)
    |> Map.new()
    
    # Clear old correlation cache
    new_correlation_cache = state.correlation_cache
    |> Enum.filter(fn {_key, {timestamp, _data}} ->
      timestamp > cutoff_time
    end)
    |> Map.new()
    
    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_windows, @window_cleanup_interval)
    
    {:noreply, %{state | 
      time_windows: new_windows,
      correlation_cache: new_correlation_cache
    }}
  end
  
  # Private Functions
  
  defp add_to_time_windows(state, event) do
    event_type = Map.get(event, :type, :unknown)
    timestamp = Map.get(event, :timestamp, System.system_time(:second))
    
    # Determine window bucket (1-minute windows)
    window_start = div(timestamp, 60) * 60
    key = {event_type, window_start}
    
    new_windows = Map.update(state.time_windows, key, [event], fn events ->
      # Limit events per window to prevent memory issues
      if length(events) < 1000 do
        [event | events]
      else
        events
      end
    end)
    
    %{state | time_windows: new_windows}
  end
  
  defp update_stream_stats(state, event) do
    event_type = Map.get(event, :type, :unknown)
    
    new_stats = state.stream_stats
    |> Map.update(:total_events, 1, &(&1 + 1))
    |> Map.update(:event_types, %{}, fn types ->
      Map.update(types, event_type, 1, &(&1 + 1))
    end)
    
    %{state | stream_stats: new_stats}
  end
  
  defp update_recent_events(state, event) do
    now = System.system_time(:millisecond)
    
    # Add new event with timestamp
    new_queue = :queue.in({now, event}, state.recent_events)
    
    # Remove events older than 1 second
    cutoff = now - 1000
    filtered_queue = remove_old_events(new_queue, cutoff)
    
    # Calculate events per second
    events_per_second = :queue.len(filtered_queue)
    
    %{state | 
      recent_events: filtered_queue,
      stream_stats: Map.put(state.stream_stats, :events_per_second, events_per_second)
    }
  end
  
  defp remove_old_events(queue, cutoff) do
    case :queue.out(queue) do
      {{:value, {timestamp, _event}}, rest} when timestamp < cutoff ->
        remove_old_events(rest, cutoff)
      _ ->
        queue
    end
  end
  
  defp check_backpressure(state) do
    current_load = :queue.len(state.recent_events)
    threshold = state.backpressure.threshold
    
    backpressure = %{state.backpressure |
      current_load: current_load,
      enabled: current_load > threshold
    }
    
    if backpressure.enabled and not state.backpressure.enabled do
      Logger.warn("⚠️ Backpressure activated: #{current_load} events in queue")
    end
    
    %{state | backpressure: backpressure}
  end
  
  defp should_drop_event?(backpressure) do
    backpressure.enabled and :rand.uniform() < 0.5  # Drop 50% when under pressure
  end
  
  defp calculate_aggregates(time_windows, event_type, window_size, aggregations) do
    now = System.system_time(:second)
    window_start = now - window_size
    
    # Filter relevant events
    events = time_windows
    |> Enum.filter(fn
      {{^event_type, window_time}, _} -> window_time >= window_start
      {{type, window_time}, _} when is_nil(event_type) -> window_time >= window_start
      _ -> false
    end)
    |> Enum.flat_map(fn {_key, events} -> events end)
    
    # Calculate requested aggregations
    Enum.map(aggregations, fn agg_type ->
      {agg_type, calculate_aggregation(events, agg_type)}
    end)
    |> Map.new()
  end
  
  defp calculate_aggregation(events, :count), do: length(events)
  
  defp calculate_aggregation(events, :avg) do
    values = extract_numeric_values(events)
    if values == [], do: 0, else: Enum.sum(values) / length(values)
  end
  
  defp calculate_aggregation(events, :min) do
    values = extract_numeric_values(events)
    if values == [], do: nil, else: Enum.min(values)
  end
  
  defp calculate_aggregation(events, :max) do
    values = extract_numeric_values(events)
    if values == [], do: nil, else: Enum.max(values)
  end
  
  defp calculate_aggregation(events, :sum) do
    events |> extract_numeric_values() |> Enum.sum()
  end
  
  defp calculate_aggregation(events, :percentiles) do
    values = extract_numeric_values(events) |> Enum.sort()
    
    if values == [] do
      %{p50: nil, p90: nil, p95: nil, p99: nil}
    else
      %{
        p50: percentile(values, 0.5),
        p90: percentile(values, 0.9),
        p95: percentile(values, 0.95),
        p99: percentile(values, 0.99)
      }
    end
  end
  
  defp extract_numeric_values(events) do
    events
    |> Enum.map(fn event -> Map.get(event, :value) end)
    |> Enum.filter(&is_number/1)
  end
  
  defp percentile(sorted_values, p) do
    index = round(p * (length(sorted_values) - 1))
    Enum.at(sorted_values, index)
  end
  
  defp find_correlations(time_windows, event_types, time_window) do
    now = System.system_time(:second)
    window_start = now - time_window
    
    # Get events for each type within the window
    events_by_type = event_types
    |> Enum.map(fn event_type ->
      events = time_windows
      |> Enum.filter(fn {{type, window_time}, _} ->
        type == event_type and window_time >= window_start
      end)
      |> Enum.flat_map(fn {_key, events} -> events end)
      
      {event_type, events}
    end)
    |> Map.new()
    
    # Find temporal correlations
    correlations = find_temporal_correlations(events_by_type)
    
    %{
      event_counts: Map.new(events_by_type, fn {type, events} -> {type, length(events)} end),
      correlations: correlations,
      time_window: time_window
    }
  end
  
  defp find_temporal_correlations(events_by_type) do
    # Simple correlation: events occurring within 5 seconds of each other
    correlation_window = 5
    
    types = Map.keys(events_by_type)
    
    for type1 <- types,
        type2 <- types,
        type1 < type2 do
      events1 = Map.get(events_by_type, type1, [])
      events2 = Map.get(events_by_type, type2, [])
      
      correlated_count = count_correlated_events(events1, events2, correlation_window)
      total_possible = min(length(events1), length(events2))
      
      correlation_strength = if total_possible > 0 do
        correlated_count / total_possible
      else
        0.0
      end
      
      {{type1, type2}, correlation_strength}
    end
    |> Map.new()
  end
  
  defp count_correlated_events(events1, events2, window) do
    timestamps1 = Enum.map(events1, &Map.get(&1, :timestamp, 0))
    timestamps2 = Enum.map(events2, &Map.get(&1, :timestamp, 0))
    
    Enum.reduce(timestamps1, 0, fn t1, count ->
      if Enum.any?(timestamps2, fn t2 -> abs(t1 - t2) <= window end) do
        count + 1
      else
        count
      end
    end)
  end
  
  defp create_parent_event(parent_type, child_events, metadata) do
    %{
      id: generate_event_id(),
      type: parent_type,
      timestamp: System.system_time(:second),
      child_count: length(child_events),
      child_types: child_events |> Enum.map(&Map.get(&1, :type)) |> Enum.uniq(),
      metadata: metadata,
      hierarchical: true
    }
  end
  
  defp perform_event_fusion(events, fusion_type) do
    base_fusion = %{
      id: generate_event_id(),
      type: :"fused_#{fusion_type}",
      timestamp: System.system_time(:second),
      source_events: length(events),
      fusion_type: fusion_type
    }
    
    case fusion_type do
      :statistical ->
        values = extract_numeric_values(events)
        Map.merge(base_fusion, %{
          avg: if(values != [], do: Enum.sum(values) / length(values), else: 0),
          min: if(values != [], do: Enum.min(values), else: nil),
          max: if(values != [], do: Enum.max(values), else: nil),
          count: length(values)
        })
        
      :temporal ->
        timestamps = Enum.map(events, &Map.get(&1, :timestamp, 0))
        Map.merge(base_fusion, %{
          time_span: if(timestamps != [], do: Enum.max(timestamps) - Enum.min(timestamps), else: 0),
          event_rate: length(events) / max(1, Enum.max(timestamps) - Enum.min(timestamps))
        })
        
      :categorical ->
        Map.merge(base_fusion, %{
          categories: events |> Enum.map(&Map.get(&1, :type)) |> Enum.frequencies()
        })
        
      _ ->
        base_fusion
    end
  end
  
  defp calculate_current_stats(state) do
    Map.merge(state.stream_stats, %{
      window_count: map_size(state.time_windows),
      hierarchical_count: map_size(state.hierarchical_events),
      backpressure_active: state.backpressure.enabled,
      current_load: state.backpressure.current_load
    })
  end
  
  defp generate_event_id do
    "event_#{:erlang.unique_integer([:positive])}_#{System.system_time(:millisecond)}"
  end
end