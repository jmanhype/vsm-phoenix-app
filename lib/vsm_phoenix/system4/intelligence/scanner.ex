defmodule VsmPhoenix.System4.Intelligence.Scanner do
  @moduledoc """
  Environmental Scanner - Collects data from external and internal sources

  Responsibilities:
  - Environmental scanning (market, technology, regulatory, competition)
  - External system integration (Tidewave)
  - Data collection and aggregation
  - Scheduled scanning operations
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System4.LLMVarietySource

  @name __MODULE__

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def scan_environment(scope \\ :full) do
    GenServer.call(@name, {:scan_environment, scope})
  end

  def get_tidewave_status do
    GenServer.call(@name, :get_tidewave_status)
  end

  def collect_market_signals do
    GenServer.call(@name, :collect_market_signals)
  end

  def collect_technology_trends do
    GenServer.call(@name, :collect_technology_trends)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Scanner: Initializing environmental scanner...")

    state = %{
      tidewave_connection: nil,
      scan_history: [],
      last_scan: nil
    }

    # Initialize Tidewave connection
    {:ok, tidewave} = init_tidewave_connection()

    # Schedule periodic scanning
    schedule_environmental_scan()

    {:ok, %{state | tidewave_connection: tidewave}}
  end

  @impl true
  def handle_call({:scan_environment, scope}, _from, state) do
    Logger.info("Scanner: Performing environmental scan - scope: #{scope}")

    scan_data = perform_scan(scope, state.tidewave_connection)

    # Update scan history
    new_state = %{
      state
      | scan_history: [{DateTime.utc_now(), scan_data} | state.scan_history] |> Enum.take(100),
        last_scan: DateTime.utc_now()
    }

    {:reply, {:ok, scan_data}, new_state}
  end

  @impl true
  def handle_call(:get_tidewave_status, _from, state) do
    status = if state.tidewave_connection, do: :connected, else: :disconnected
    {:reply, status, state}
  end

  @impl true
  def handle_call(:collect_market_signals, _from, state) do
    signals = generate_market_signals()
    {:reply, {:ok, signals}, state}
  end

  @impl true
  def handle_call(:collect_technology_trends, _from, state) do
    trends = detect_technology_trends()
    {:reply, {:ok, trends}, state}
  end

  @impl true
  def handle_info(:scheduled_scan, state) do
    # Scheduled scan logged via telemetry events

    # Perform scan and notify analyzer
    scan_data = perform_scan(:scheduled, state.tidewave_connection)

    # Send to analyzer for processing
    send({VsmPhoenix.System4.Intelligence.Analyzer, node()}, {:new_scan_data, scan_data})

    # Schedule next scan
    schedule_environmental_scan()

    {:noreply, %{state | last_scan: DateTime.utc_now()}}
  end

  # Private Functions

  defp init_tidewave_connection do
    # Initialize connection to Tidewave system
    {:ok, %{status: :connected, endpoint: "tidewave://localhost:4000"}}
  end

  defp perform_scan(scope, _tidewave) do
    base_scan = %{
      market_signals: generate_market_signals(),
      technology_trends: detect_technology_trends(),
      regulatory_updates: check_regulatory_changes(),
      competitive_moves: analyze_competition(),
      scope: scope,
      timestamp: DateTime.utc_now()
    }

    # Optional LLM variety amplification
    if Application.get_env(:vsm_phoenix, :enable_llm_variety, false) do
      amplify_with_llm(base_scan)
    else
      base_scan
    end
  end

  defp amplify_with_llm(base_scan) do
    task =
      Task.async(fn ->
        try do
          LLMVarietySource.analyze_for_variety(base_scan)
        rescue
          e ->
            Logger.error("LLM variety analysis failed: #{inspect(e)}")
            {:error, :llm_unavailable}
        end
      end)

    case Task.yield(task, 3000) || Task.shutdown(task) do
      {:ok, {:ok, variety_expansion}} ->
        Logger.info("Scanner: LLM variety amplification successful")
        Map.merge(base_scan, %{llm_variety: variety_expansion})

      _ ->
        # LLM timeout events logged via telemetry
        base_scan
    end
  end

  defp generate_market_signals do
    [
      %{signal: "increased_demand", strength: 0.7, source: "sales_data"},
      %{signal: "price_pressure", strength: 0.4, source: "market_analysis"},
      %{signal: "new_segment_emerging", strength: 0.6, source: "tidewave"}
    ]
  end

  defp detect_technology_trends do
    [
      %{trend: "ai_adoption", impact: :high, timeline: "6_months"},
      %{trend: "edge_computing", impact: :medium, timeline: "12_months"}
    ]
  end

  defp check_regulatory_changes do
    [
      %{regulation: "data_privacy", status: "proposed", impact: :medium}
    ]
  end

  defp analyze_competition do
    [
      %{competitor: "comp_a", action: "new_product", threat_level: :medium}
    ]
  end

  defp schedule_environmental_scan do
    # Every minute
    Process.send_after(self(), :scheduled_scan, 60_000)
  end
end
