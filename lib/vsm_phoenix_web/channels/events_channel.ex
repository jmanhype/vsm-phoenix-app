defmodule VsmPhoenixWeb.EventsChannel do
  @moduledoc """
  WebSocket Event Streaming Channel
  
  Features:
  - Real-time event broadcasting
  - Client-side event subscriptions
  - Event filtering and routing
  - Backpressure handling
  - Authentication and authorization
  - Rate limiting
  """
  
  use Phoenix.Channel
  require Logger
  
  alias VsmPhoenix.Events.{Store, Analytics, PatternMatcher}
  
  @max_events_per_second 100
  @rate_limit_window 1000  # 1 second
  
  # Channel callbacks
  
  def join("events:all", _params, socket) do
    Logger.info("📡 Client joined events:all channel")
    
    # Subscribe to all events
    Store.subscribe_to_all(self())
    
    # Initialize rate limiting
    socket = assign(socket, :rate_limit, %{
      count: 0,
      window_start: :erlang.system_time(:millisecond)
    })
    
    {:ok, %{status: "connected", channel: "events:all"}, socket}
  end
  
  def join("events:stream:" <> stream_id, _params, socket) do
    Logger.info("📡 Client joined events:stream:#{stream_id} channel")
    
    # Subscribe to specific stream
    Store.subscribe_to_stream(stream_id, self())
    
    socket = socket
    |> assign(:stream_id, stream_id)
    |> assign(:rate_limit, %{
      count: 0,
      window_start: :erlang.system_time(:millisecond)
    })
    
    {:ok, %{status: "connected", channel: "events:stream:#{stream_id}"}, socket}
  end
  
  def join("events:patterns", _params, socket) do
    Logger.info("📡 Client joined events:patterns channel")
    
    # Subscribe to pattern detection events
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "events:patterns")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "events:pattern_stats")
    
    socket = assign(socket, :rate_limit, %{
      count: 0,
      window_start: :erlang.system_time(:millisecond)
    })
    
    {:ok, %{status: "connected", channel: "events:patterns"}, socket}
  end
  
  def join("events:analytics", _params, socket) do
    Logger.info("📡 Client joined events:analytics channel")
    
    # Subscribe to analytics updates
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "analytics:throughput")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "analytics:insights")
    
    socket = assign(socket, :rate_limit, %{
      count: 0,
      window_start: :erlang.system_time(:millisecond)
    })
    
    {:ok, %{status: "connected", channel: "events:analytics"}, socket}
  end
  
  def join("events:live", _params, socket) do
    Logger.info("📡 Client joined events:live channel for real-time updates")
    
    # Subscribe to live event processing updates
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "events:live")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "events:high_priority")
    
    socket = assign(socket, :rate_limit, %{
      count: 0,
      window_start: :erlang.system_time(:millisecond)
    })
    
    {:ok, %{status: "connected", channel: "events:live"}, socket}
  end
  
  # Handle incoming messages from clients
  
  def handle_in("subscribe_to_stream", %{"stream_id" => stream_id}, socket) do
    Logger.info("📡 Client subscribing to stream: #{stream_id}")
    
    # Add stream subscription
    Store.subscribe_to_stream(stream_id, self())
    
    # Update socket state
    current_streams = Map.get(socket.assigns, :subscribed_streams, MapSet.new())
    new_streams = MapSet.put(current_streams, stream_id)
    socket = assign(socket, :subscribed_streams, new_streams)
    
    {:reply, {:ok, %{stream_id: stream_id, status: "subscribed"}}, socket}
  end
  
  def handle_in("unsubscribe_from_stream", %{"stream_id" => stream_id}, socket) do
    Logger.info("📡 Client unsubscribing from stream: #{stream_id}")
    
    # Remove from subscribed streams
    current_streams = Map.get(socket.assigns, :subscribed_streams, MapSet.new())
    new_streams = MapSet.delete(current_streams, stream_id)
    socket = assign(socket, :subscribed_streams, new_streams)
    
    {:reply, {:ok, %{stream_id: stream_id, status: "unsubscribed"}}, socket}
  end
  
  def handle_in("set_event_filter", %{"filter" => filter_spec}, socket) do
    Logger.info("📡 Client setting event filter: #{inspect(filter_spec)}")
    
    # Validate and set event filter
    case validate_filter(filter_spec) do
      {:ok, parsed_filter} ->
        socket = assign(socket, :event_filter, parsed_filter)
        {:reply, {:ok, %{filter: parsed_filter, status: "applied"}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end
  
  def handle_in("get_dashboard_data", _params, socket) do
    Logger.debug("📡 Client requesting dashboard data")
    
    dashboard_data = Analytics.get_dashboard_data()
    
    {:reply, {:ok, dashboard_data}, socket}
  end
  
  def handle_in("get_pattern_stats", _params, socket) do
    Logger.debug("📡 Client requesting pattern statistics")
    
    pattern_stats = PatternMatcher.get_pattern_stats()
    
    {:reply, {:ok, pattern_stats}, socket}
  end
  
  def handle_in("inject_test_event", %{"event" => event_params}, socket) do
    Logger.info("📡 Client injecting test event")
    
    # Create test event
    test_event = %VsmPhoenix.Events.Store.Event{
      id: UUID.uuid4(),
      stream_id: Map.get(event_params, "stream_id", "test_events"),
      stream_version: 0,
      event_type: Map.get(event_params, "event_type", "test.event"),
      event_data: Map.get(event_params, "event_data", %{}),
      metadata: %{source: :client_injection, injected_by: socket.id},
      timestamp: DateTime.utc_now()
    }
    
    # Inject into event processor
    VsmPhoenix.Events.EventProducer.inject_event(test_event)
    
    {:reply, {:ok, %{event_id: test_event.id, status: "injected"}}, socket}
  end
  
  # Handle incoming events from event store
  
  def handle_info({:event_appended, event}, socket) do
    if should_send_event?(event, socket) do
      case check_rate_limit(socket) do
        {:ok, new_socket} ->
          broadcast_event(event, "event_appended", new_socket)
          {:noreply, new_socket}
        
        {:rate_limited, new_socket} ->
          Logger.warn("📡 Rate limiting client #{socket.id}")
          push(new_socket, "rate_limit_warning", %{message: "Rate limit exceeded"})
          {:noreply, new_socket}
      end
    else
      {:noreply, socket}
    end
  end
  
  def handle_info({:stream_event_appended, stream_id, event}, socket) do
    if should_send_stream_event?(stream_id, event, socket) do
      case check_rate_limit(socket) do
        {:ok, new_socket} ->
          push(new_socket, "stream_event", %{
            stream_id: stream_id,
            event: format_event_for_client(event)
          })
          {:noreply, new_socket}
        
        {:rate_limited, new_socket} ->
          {:noreply, new_socket}
      end
    else
      {:noreply, socket}
    end
  end
  
  def handle_info({:pattern_detected, match}, socket) do
    case check_rate_limit(socket) do
      {:ok, new_socket} ->
        push(new_socket, "pattern_detected", %{
          pattern_name: match.pattern_name,
          severity: match.severity,
          confidence: match.confidence,
          matched_events: Enum.map(match.matched_events, &format_event_for_client/1),
          timestamp: match.timestamp
        })
        {:noreply, new_socket}
      
      {:rate_limited, new_socket} ->
        {:noreply, new_socket}
    end
  end
  
  def handle_info({:pattern_statistics, stats}, socket) do
    push(socket, "pattern_statistics", stats)
    {:noreply, socket}
  end
  
  def handle_info({:throughput_update, events_per_minute}, socket) do
    push(socket, "throughput_update", %{
      events_per_minute: events_per_minute,
      timestamp: DateTime.utc_now()
    })
    {:noreply, socket}
  end
  
  def handle_info({:insights_generated, insights}, socket) do
    push(socket, "analytics_insights", insights)
    {:noreply, socket}
  end
  
  def handle_info({:high_priority_event, event}, socket) do
    # Always send high priority events, bypassing rate limits for critical events
    push(socket, "high_priority_event", %{
      event: format_event_for_client(event),
      priority: "high",
      timestamp: DateTime.utc_now()
    })
    {:noreply, socket}
  end
  
  def handle_info({:event_processed, event_summary}, socket) do
    case check_rate_limit(socket) do
      {:ok, new_socket} ->
        push(new_socket, "event_processed", event_summary)
        {:noreply, new_socket}
      
      {:rate_limited, new_socket} ->
        {:noreply, new_socket}
    end
  end
  
  # Handle client disconnection
  
  def terminate(reason, socket) do
    Logger.info("📡 Client disconnected from events channel: #{inspect(reason)}")
    :ok
  end
  
  # Private Functions
  
  defp should_send_event?(event, socket) do
    # Check event filter if present
    case Map.get(socket.assigns, :event_filter) do
      nil -> true
      filter -> apply_event_filter(event, filter)
    end
  end
  
  defp should_send_stream_event?(stream_id, event, socket) do
    # Check if client is subscribed to this stream
    subscribed_streams = Map.get(socket.assigns, :subscribed_streams, MapSet.new())
    
    if MapSet.member?(subscribed_streams, stream_id) do
      should_send_event?(event, socket)
    else
      # Always send if it's the socket's assigned stream
      stream_id == Map.get(socket.assigns, :stream_id)
    end
  end
  
  defp apply_event_filter(event, filter) do
    Enum.all?(filter, fn {key, value} ->
      case key do
        "event_type" -> match_pattern(event.event_type, value)
        "stream_id" -> match_pattern(event.stream_id, value)
        "severity" -> 
          event_severity = get_event_severity(event)
          event_severity == value or (value == "high" and event_severity in ["high", "critical"])
        _ -> true
      end
    end)
  end
  
  defp match_pattern(text, pattern) do
    cond do
      String.contains?(pattern, "*") ->
        # Convert glob pattern to regex
        regex_pattern = pattern
        |> String.replace("*", ".*")
        |> then(&("^" <> &1 <> "$"))
        
        Regex.match?(~r/#{regex_pattern}/, text)
      
      true ->
        text == pattern
    end
  end
  
  defp get_event_severity(event) do
    cond do
      String.contains?(event.event_type, "critical") -> "critical"
      String.contains?(event.event_type, "error") -> "high"
      String.contains?(event.event_type, "warning") -> "medium"
      String.starts_with?(event.event_type, "algedonic.pain") -> "high"
      String.starts_with?(event.event_type, "system5.policy.violated") -> "high"
      true -> "low"
    end
  end
  
  defp validate_filter(filter_spec) when is_map(filter_spec) do
    allowed_keys = ["event_type", "stream_id", "severity"]
    
    case Map.keys(filter_spec) -- allowed_keys do
      [] -> {:ok, filter_spec}
      invalid_keys -> {:error, "Invalid filter keys: #{Enum.join(invalid_keys, ", ")}"}
    end
  end
  
  defp validate_filter(_), do: {:error, "Filter must be a map"}
  
  defp check_rate_limit(socket) do
    current_time = :erlang.system_time(:millisecond)
    rate_limit = socket.assigns.rate_limit
    
    # Reset window if needed
    {count, window_start} = if current_time - rate_limit.window_start >= @rate_limit_window do
      {0, current_time}
    else
      {rate_limit.count, rate_limit.window_start}
    end
    
    new_count = count + 1
    
    if new_count <= @max_events_per_second do
      new_rate_limit = %{count: new_count, window_start: window_start}
      new_socket = assign(socket, :rate_limit, new_rate_limit)
      {:ok, new_socket}
    else
      new_rate_limit = %{count: new_count, window_start: window_start}
      new_socket = assign(socket, :rate_limit, new_rate_limit)
      {:rate_limited, new_socket}
    end
  end
  
  defp broadcast_event(event, event_name, socket) do
    push(socket, event_name, %{
      event: format_event_for_client(event),
      timestamp: DateTime.utc_now()
    })
  end
  
  defp format_event_for_client(event) do
    %{
      id: event.id,
      stream_id: event.stream_id,
      stream_version: event.stream_version,
      event_type: event.event_type,
      event_data: event.event_data,
      metadata: Map.get(event, :metadata, %{}),
      timestamp: event.timestamp,
      processing_metadata: Map.get(event, :processing_metadata, %{})
    }
  end
end

# UUID helper (reuse from other modules)
defmodule UUID do
  def uuid4 do
    <<u0::32, u1::16, u2::16, u3::16, u4::48>> = :crypto.strong_rand_bytes(16)
    
    <<u0::32, u1::16, 4::4, u2::12, 2::2, u3::14, u4::48>>
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.downcase/1)
    |> Enum.map(fn s -> if String.length(s) == 1, do: "0" <> s, else: s end)
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join/1)
    |> List.to_string()
    |> String.replace(~r/(.{8})(.{4})(.{4})(.{4})(.{12})/, "\\1-\\2-\\3-\\4-\\5")
  end
end