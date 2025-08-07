defmodule VsmPhoenix.System5.Persistence.VarietyMetricsStore do
  @moduledoc """
  ETS-based persistence store for variety metrics tracking.

  Features:
  - Time-series storage of variety measurements
  - Variety gap analysis and tracking
  - Requisite variety calculations
  - System capacity monitoring
  - Variety amplification/attenuation metrics
  """

  use GenServer
  require Logger

  @table_name :system5_variety_metrics
  @timeseries_table :system5_variety_timeseries
  @analysis_table :system5_variety_analysis

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def record_variety_measurement(source, measurement) do
    GenServer.call(__MODULE__, {:record_measurement, source, measurement})
  end

  def get_current_variety(source) do
    GenServer.call(__MODULE__, {:get_current_variety, source})
  end

  def get_variety_history(source, time_range \\ :hour) do
    GenServer.call(__MODULE__, {:get_history, source, time_range})
  end

  def calculate_variety_gap(environmental_variety, system_variety) do
    GenServer.call(__MODULE__, {:calculate_gap, environmental_variety, system_variety})
  end

  def record_amplification(amplifier_id, input_variety, output_variety) do
    GenServer.call(
      __MODULE__,
      {:record_amplification, amplifier_id, input_variety, output_variety}
    )
  end

  def record_attenuation(attenuator_id, input_variety, output_variety) do
    GenServer.call(
      __MODULE__,
      {:record_attenuation, attenuator_id, input_variety, output_variety}
    )
  end

  def analyze_variety_trends(time_range \\ :day) do
    GenServer.call(__MODULE__, {:analyze_trends, time_range})
  end

  def get_requisite_variety_status do
    GenServer.call(__MODULE__, :get_requisite_status)
  end

  def set_variety_threshold(source, threshold) do
    GenServer.call(__MODULE__, {:set_threshold, source, threshold})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("VarietyMetricsStore: Initializing ETS-based variety metrics persistence")

    # Create ETS tables
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@timeseries_table, [:bag, :public, :named_table])
    :ets.new(@analysis_table, [:set, :public, :named_table])

    state = %{
      sources: MapSet.new(),
      thresholds: %{},
      last_analysis: DateTime.utc_now(),
      measurement_count: 0
    }

    # Schedule periodic analysis
    schedule_analysis()

    {:ok, state}
  end

  @impl true
  def handle_call({:record_measurement, source, measurement}, _from, state) do
    timestamp = DateTime.utc_now()

    # Create measurement record
    measurement_record = %{
      source: source,
      variety: measurement.variety,
      capacity: Map.get(measurement, :capacity, measurement.variety),
      metadata: Map.get(measurement, :metadata, %{}),
      timestamp: timestamp
    }

    # Store current value
    :ets.insert(@table_name, {source, measurement_record})

    # Store in time series
    :ets.insert(@timeseries_table, {{source, timestamp}, measurement_record})

    # Update sources
    new_sources = MapSet.put(state.sources, source)

    # Check for threshold violations
    check_threshold_violation(source, measurement.variety, state.thresholds)

    new_state = %{state | sources: new_sources, measurement_count: state.measurement_count + 1}

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_current_variety, source}, _from, state) do
    case :ets.lookup(@table_name, source) do
      [{^source, measurement}] ->
        {:reply, {:ok, measurement}, state}

      _ ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_history, source, time_range}, _from, state) do
    cutoff_time = calculate_cutoff_time(time_range)

    # Retrieve measurements within time range
    measurements =
      :ets.select(@timeseries_table, [
        {{{source, :"$1"}, :"$2"}, [{:>, :"$1", cutoff_time}], [:"$2"]}
      ])
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})

    {:reply, {:ok, measurements}, state}
  end

  @impl true
  def handle_call({:calculate_gap, environmental_variety, system_variety}, _from, state) do
    # Calculate variety gap
    gap = environmental_variety - system_variety
    gap_ratio = if system_variety > 0, do: environmental_variety / system_variety, else: :infinity

    analysis = %{
      environmental_variety: environmental_variety,
      system_variety: system_variety,
      variety_gap: gap,
      gap_ratio: gap_ratio,
      requisite_variety_met: gap <= 0,
      deficit: max(0, gap),
      timestamp: DateTime.utc_now()
    }

    # Store analysis
    :ets.insert(@analysis_table, {:variety_gap, analysis})

    {:reply, {:ok, analysis}, state}
  end

  @impl true
  def handle_call(
        {:record_amplification, amplifier_id, input_variety, output_variety},
        _from,
        state
      ) do
    amplification_factor = if input_variety > 0, do: output_variety / input_variety, else: 0

    record = %{
      type: :amplification,
      component_id: amplifier_id,
      input_variety: input_variety,
      output_variety: output_variety,
      factor: amplification_factor,
      timestamp: DateTime.utc_now()
    }

    # Store in current metrics
    :ets.insert(@table_name, {{:amplifier, amplifier_id}, record})

    # Store in time series
    :ets.insert(@timeseries_table, {{:amplifier, amplifier_id, record.timestamp}, record})

    {:reply, {:ok, amplification_factor}, state}
  end

  @impl true
  def handle_call(
        {:record_attenuation, attenuator_id, input_variety, output_variety},
        _from,
        state
      ) do
    attenuation_factor = if input_variety > 0, do: output_variety / input_variety, else: 0

    record = %{
      type: :attenuation,
      component_id: attenuator_id,
      input_variety: input_variety,
      output_variety: output_variety,
      factor: attenuation_factor,
      timestamp: DateTime.utc_now()
    }

    # Store in current metrics
    :ets.insert(@table_name, {{:attenuator, attenuator_id}, record})

    # Store in time series
    :ets.insert(@timeseries_table, {{:attenuator, attenuator_id, record.timestamp}, record})

    {:reply, {:ok, attenuation_factor}, state}
  end

  @impl true
  def handle_call({:analyze_trends, time_range}, _from, state) do
    Logger.info("VarietyMetricsStore: Analyzing variety trends for #{time_range}")

    cutoff_time = calculate_cutoff_time(time_range)

    # Analyze trends for each source
    trends =
      state.sources
      |> Enum.map(fn source ->
        measurements =
          :ets.select(@timeseries_table, [
            {{{source, :"$1"}, :"$2"}, [{:>, :"$1", cutoff_time}], [:"$2"]}
          ])

        trend_analysis = analyze_source_trend(source, measurements)
        {source, trend_analysis}
      end)
      |> Map.new()

    # Overall system analysis
    system_analysis = %{
      trends: trends,
      overall_trend: calculate_overall_trend(trends),
      critical_sources: identify_critical_sources(trends),
      timestamp: DateTime.utc_now()
    }

    # Store analysis
    :ets.insert(@analysis_table, {:trend_analysis, system_analysis})

    {:reply, {:ok, system_analysis}, state}
  end

  @impl true
  def handle_call(:get_requisite_status, _from, state) do
    # Get all current variety measurements
    all_measurements = :ets.tab2list(@table_name)

    # Separate environmental and system varieties
    {environmental, system} =
      Enum.reduce(all_measurements, {%{}, %{}}, fn
        {{source, measurement}, _}, {env, sys} when is_atom(source) ->
          case source do
            s when s in [:environment, :external, :market] ->
              {Map.put(env, source, measurement.variety), sys}

            _ ->
              {env, Map.put(sys, source, measurement.variety)}
          end

        _, acc ->
          acc
      end)

    # Calculate requisite variety status
    total_env_variety = environmental |> Map.values() |> Enum.sum()
    total_sys_variety = system |> Map.values() |> Enum.sum()

    status = %{
      environmental_variety: total_env_variety,
      system_variety: total_sys_variety,
      variety_gap: total_env_variety - total_sys_variety,
      requisite_variety_met: total_sys_variety >= total_env_variety,
      coverage_ratio:
        if(total_env_variety > 0, do: total_sys_variety / total_env_variety, else: 1.0),
      details: %{
        environmental_sources: environmental,
        system_sources: system
      },
      timestamp: DateTime.utc_now()
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call({:set_threshold, source, threshold}, _from, state) do
    new_thresholds = Map.put(state.thresholds, source, threshold)

    {:reply, :ok, %{state | thresholds: new_thresholds}}
  end

  @impl true
  def handle_info(:periodic_analysis, state) do
    # Run automatic trend analysis
    {:ok, _analysis} = handle_call({:analyze_trends, :hour}, self(), state)

    # Clean up old time series data
    cleanup_old_data()

    # Schedule next analysis
    schedule_analysis()

    {:noreply, %{state | last_analysis: DateTime.utc_now()}}
  end

  # Private Functions

  defp calculate_cutoff_time(time_range) do
    now = DateTime.utc_now()

    case time_range do
      :minute -> DateTime.add(now, -60, :second)
      :hour -> DateTime.add(now, -3600, :second)
      :day -> DateTime.add(now, -86400, :second)
      :week -> DateTime.add(now, -604_800, :second)
      :month -> DateTime.add(now, -2_592_000, :second)
      seconds when is_integer(seconds) -> DateTime.add(now, -seconds, :second)
    end
  end

  defp check_threshold_violation(source, variety, thresholds) do
    case Map.get(thresholds, source) do
      nil ->
        :ok

      threshold when variety > threshold ->
        Logger.warning(
          "VarietyMetricsStore: Variety threshold exceeded for #{source}: #{variety} > #{threshold}"
        )

        # Broadcast threshold violation
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "vsm:variety",
          {:variety_threshold_exceeded,
           %{
             source: source,
             variety: variety,
             threshold: threshold,
             timestamp: DateTime.utc_now()
           }}
        )

      _ ->
        :ok
    end
  end

  defp analyze_source_trend(source, measurements) when length(measurements) < 2 do
    %{
      source: source,
      trend: :insufficient_data,
      measurements: length(measurements)
    }
  end

  defp analyze_source_trend(source, measurements) do
    # Sort by timestamp
    sorted = Enum.sort_by(measurements, & &1.timestamp)

    # Calculate trend using simple linear regression
    {xs, ys} =
      sorted
      |> Enum.with_index()
      |> Enum.map(fn {m, i} -> {i, m.variety} end)
      |> Enum.unzip()

    n = length(xs)
    sum_x = Enum.sum(xs)
    sum_y = Enum.sum(ys)
    sum_xy = Enum.zip(xs, ys) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
    sum_x2 = xs |> Enum.map(&(&1 * &1)) |> Enum.sum()

    # Calculate slope
    slope =
      if n * sum_x2 - sum_x * sum_x == 0 do
        0
      else
        (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
      end

    # Calculate statistics
    varieties = Enum.map(sorted, & &1.variety)
    avg_variety = Enum.sum(varieties) / n
    max_variety = Enum.max(varieties)
    min_variety = Enum.min(varieties)

    %{
      source: source,
      trend: categorize_trend(slope),
      slope: slope,
      average_variety: avg_variety,
      max_variety: max_variety,
      min_variety: min_variety,
      volatility: max_variety - min_variety,
      measurement_count: n,
      latest_variety: List.last(sorted).variety
    }
  end

  defp categorize_trend(slope) do
    cond do
      slope > 0.1 -> :increasing
      slope < -0.1 -> :decreasing
      true -> :stable
    end
  end

  defp calculate_overall_trend(trends) do
    trend_counts =
      trends
      |> Map.values()
      |> Enum.map(& &1.trend)
      |> Enum.frequencies()

    # Determine dominant trend
    cond do
      Map.get(trend_counts, :increasing, 0) > Map.get(trend_counts, :decreasing, 0) -> :increasing
      Map.get(trend_counts, :decreasing, 0) > Map.get(trend_counts, :increasing, 0) -> :decreasing
      true -> :stable
    end
  end

  defp identify_critical_sources(trends) do
    trends
    |> Enum.filter(fn {_source, analysis} ->
      analysis.trend == :increasing && analysis.slope > 0.5
    end)
    |> Enum.map(fn {source, _} -> source end)
  end

  defp cleanup_old_data do
    # Keep only last 7 days of time series data
    cutoff = DateTime.add(DateTime.utc_now(), -604_800, :second)

    # Get all old entries
    old_entries =
      :ets.select(@timeseries_table, [
        {{{:"$1", :"$2"}, :"$3"}, [{:<, :"$2", cutoff}], [:"$_"]}
      ])

    # Delete old entries
    Enum.each(old_entries, fn entry ->
      :ets.delete_object(@timeseries_table, entry)
    end)

    Logger.debug("VarietyMetricsStore: Cleaned up #{length(old_entries)} old entries")
  end

  defp schedule_analysis do
    # Run analysis every 15 minutes
    Process.send_after(self(), :periodic_analysis, :timer.minutes(15))
  end
end
