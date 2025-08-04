defmodule VsmPhoenixWeb.EventsController do
  use VsmPhoenixWeb, :controller
  require Logger
  
  alias VsmPhoenix.Events.{Store, Analytics, PatternMatcher}
  
  def index(conn, _params) do
    render(conn, :index)
  end
  
  def dashboard(conn, _params) do
    # Get real-time dashboard data
    dashboard_data = Analytics.get_dashboard_data()
    pattern_stats = PatternMatcher.get_pattern_stats()
    throughput_stats = Analytics.get_throughput_stats()
    
    render(conn, :dashboard, %{
      dashboard: dashboard_data,
      patterns: pattern_stats,
      throughput: throughput_stats
    })
  end
  
  def inject_event(conn, params) do
    Logger.info("💉 Injecting test event via HTTP: #{inspect(params)}")
    
    # Create test event
    test_event = %VsmPhoenix.Events.Store.Event{
      id: UUID.uuid4(),
      stream_id: Map.get(params, "stream_id", "api_test_events"),
      stream_version: 0,
      event_type: Map.get(params, "event_type", "test.api.event"),
      event_data: Map.get(params, "event_data", %{message: "Test event from API"}),
      metadata: %{source: :api_injection, ip: get_client_ip(conn)},
      timestamp: DateTime.utc_now()
    }
    
    # Inject into event processor
    VsmPhoenix.Events.EventProducer.inject_event(test_event)
    
    json(conn, %{
      status: "success",
      event_id: test_event.id,
      message: "Event injected successfully"
    })
  end
  
  def stream_stats(conn, %{"stream_id" => stream_id}) do
    case Store.get_stream_stats(stream_id) do
      {:ok, stats} ->
        json(conn, stats)
      
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Stream not found", reason: inspect(reason)})
    end
  end
  
  def analytics_data(conn, _params) do
    dashboard_data = Analytics.get_dashboard_data()
    json(conn, dashboard_data)
  end
  
  def pattern_insights(conn, _params) do
    insights = Analytics.get_predictive_insights()
    json(conn, %{insights: insights})
  end
  
  # Private Functions
  
  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [ip | _] -> ip
      [] -> 
        {ip, _port} = conn.remote_ip
        :inet.ntoa(ip) |> to_string()
    end
  end
end

# UUID helper
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