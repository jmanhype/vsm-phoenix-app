defmodule VsmPhoenix.System4.Intelligence.Analyzer do
  @moduledoc """
  Pattern Analyzer - Detects patterns, anomalies, and insights from scan data

  Responsibilities:
  - Pattern detection and analysis
  - Anomaly detection
  - Trend analysis and insights
  - Variety pattern assessment
  - Emergence level assessment
  - Opportunity/threat identification
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System5.Queen

  @name __MODULE__

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def analyze_scan_data(scan_data) do
    GenServer.call(@name, {:analyze_scan_data, scan_data})
  end

  def analyze_trends(data_source) do
    GenServer.call(@name, {:analyze_trends, data_source})
  end

  def analyze_variety_patterns(variety_data, scope \\ :full) do
    GenServer.call(@name, {:analyze_variety_patterns, variety_data, scope})
  end

  def detect_anomalies(scan_data) do
    GenServer.call(@name, {:detect_anomalies, scan_data})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Analyzer: Initializing pattern analyzer...")

    state = %{
      analysis_history: [],
      detected_patterns: %{},
      anomaly_threshold: 0.8,
      learning_data: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:analyze_scan_data, scan_data}, _from, state) do
    Logger.info("Analyzer: Analyzing scan data")

    # Perform comprehensive analysis
    insights = %{
      requires_adaptation: needs_adaptation?(scan_data),
      challenge: identify_challenge(scan_data),
      opportunities: identify_opportunities(scan_data),
      threats: identify_threats(scan_data),
      patterns: detect_patterns(scan_data, state),
      anomalies: find_anomalies(scan_data, state.anomaly_threshold)
    }

    # Report anomalies to Queen if needed
    report_anomalies_to_queen(insights.anomalies)

    # Update state with new patterns
    new_state = update_detected_patterns(state, insights.patterns)

    {:reply, {:ok, insights}, new_state}
  end

  @impl true
  def handle_call({:analyze_trends, data_source}, _from, state) do
    Logger.info("Analyzer: Analyzing trends from #{data_source}")

    trends =
      case data_source do
        :internal -> analyze_internal_trends(state.learning_data)
        :combined -> combine_trend_analyses(state)
        _ -> %{error: "Unknown data source"}
      end

    {:reply, {:ok, trends}, state}
  end

  @impl true
  def handle_call({:analyze_variety_patterns, variety_data, scope}, _from, state) do
    Logger.info("Analyzer: Analyzing variety patterns - scope: #{scope}")

    analysis = %{
      pattern_count: map_size(variety_data[:novel_patterns] || %{}),
      emergence_level: assess_emergence_level(variety_data),
      recursive_potential: variety_data[:recursive_potential] || [],
      meta_system_recommendation: should_spawn_meta_system?(variety_data),
      variety_score: calculate_variety_score(variety_data)
    }

    # Update learning data
    new_learning_data = [{DateTime.utc_now(), analysis} | state.learning_data]
    new_state = %{state | learning_data: Enum.take(new_learning_data, 1000)}

    {:reply, {:ok, analysis}, new_state}
  end

  @impl true
  def handle_call({:detect_anomalies, scan_data}, _from, state) do
    anomalies = find_anomalies(scan_data, state.anomaly_threshold)
    {:reply, {:ok, anomalies}, state}
  end

  @impl true
  def handle_info({:new_scan_data, scan_data}, state) do
    Logger.info("Analyzer: Received new scan data from Scanner")

    # Analyze the new scan data
    case handle_call({:analyze_scan_data, scan_data}, nil, state) do
      {:reply, {:ok, insights}, new_state} ->
        # If adaptation needed, notify AdaptationEngine
        if insights.requires_adaptation do
          send(
            {VsmPhoenix.System4.Intelligence.AdaptationEngine, node()},
            {:adaptation_needed, insights.challenge}
          )
        end

        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  # Private Functions

  defp needs_adaptation?(scan_data) do
    high_impact_signals =
      scan_data[:market_signals]
      |> Enum.filter(&(&1.strength > 0.6))

    length(high_impact_signals) > 0
  end

  defp identify_challenge(scan_data) do
    high_impact_signals =
      scan_data[:market_signals]
      |> Enum.filter(&(&1.strength > 0.6))

    if length(high_impact_signals) > 0 do
      %{
        type: :market_shift,
        signals: high_impact_signals,
        urgency: determine_urgency(high_impact_signals),
        scope: :tactical
      }
    else
      nil
    end
  end

  defp determine_urgency(signals) do
    max_strength =
      signals
      |> Enum.map(& &1.strength)
      |> Enum.max(fn -> 0 end)

    cond do
      max_strength > 0.8 -> :high
      max_strength > 0.6 -> :medium
      true -> :low
    end
  end

  defp identify_opportunities(scan_data) do
    scan_data[:market_signals]
    |> Enum.filter(&(&1.signal == "new_segment_emerging"))
  end

  defp identify_threats(scan_data) do
    scan_data[:competitive_moves]
    |> Enum.filter(&(&1.threat_level in [:high, :medium]))
  end

  defp detect_patterns(scan_data, state) do
    # Pattern detection logic
    %{
      market_patterns: detect_market_patterns(scan_data),
      technology_patterns: detect_tech_patterns(scan_data),
      combined_patterns: combine_patterns(scan_data, state.detected_patterns)
    }
  end

  defp detect_market_patterns(scan_data) do
    scan_data[:market_signals]
    |> Enum.group_by(& &1.source)
    |> Enum.map(fn {source, signals} ->
      {source, analyze_signal_pattern(signals)}
    end)
    |> Map.new()
  end

  defp detect_tech_patterns(scan_data) do
    scan_data[:technology_trends]
    |> Enum.group_by(& &1.impact)
    |> Map.new()
  end

  defp analyze_signal_pattern(signals) do
    total_strength = Enum.map(signals, & &1.strength) |> Enum.sum()
    avg_strength = total_strength / length(signals)
    %{average_strength: avg_strength, count: length(signals)}
  end

  defp combine_patterns(scan_data, existing_patterns) do
    # Combine new patterns with existing ones
    Map.merge(existing_patterns, %{
      timestamp: scan_data[:timestamp],
      new_patterns: true
    })
  end

  defp find_anomalies(scan_data, threshold) do
    anomalies = []

    # Check for variety explosion
    anomalies = check_variety_explosion(scan_data, anomalies)

    # Check for market anomalies
    anomalies = check_market_anomalies(scan_data, anomalies, threshold)

    # Check for technology disruption
    anomalies = check_technology_disruption(scan_data, anomalies)

    # Check for regulatory anomalies
    check_regulatory_anomalies(scan_data, anomalies)
  end

  defp check_variety_explosion(scan_data, anomalies) do
    if scan_data[:llm_variety] && scan_data.llm_variety[:novel_patterns] do
      pattern_count = map_size(scan_data.llm_variety.novel_patterns)

      if pattern_count > 10 do
        [
          %{
            type: :variety_explosion,
            severity: min(pattern_count / 10, 1.0),
            description:
              "LLM detected #{pattern_count} novel patterns exceeding current capacity",
            data: scan_data.llm_variety,
            timestamp: DateTime.utc_now(),
            recommended_action: :spawn_meta_vsm
          }
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp check_market_anomalies(scan_data, anomalies, threshold) do
    if scan_data[:market_signals] do
      unusual_signals =
        scan_data.market_signals
        |> Enum.filter(fn signal -> signal.strength > threshold end)

      if length(unusual_signals) > 0 do
        [
          %{
            type: :market_anomaly,
            severity: Enum.max_by(unusual_signals, & &1.strength).strength,
            description:
              "Unusual market signals detected: #{length(unusual_signals)} high-strength signals",
            data: unusual_signals,
            timestamp: DateTime.utc_now(),
            recommended_action: :policy_adaptation
          }
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp check_technology_disruption(scan_data, anomalies) do
    if scan_data[:technology_trends] do
      high_impact_tech =
        scan_data.technology_trends
        |> Enum.filter(fn trend -> trend.impact == :high end)

      if length(high_impact_tech) > 0 do
        [
          %{
            type: :technology_disruption,
            severity: 0.8,
            description:
              "High-impact technology trends detected: #{Enum.map(high_impact_tech, & &1.trend) |> Enum.join(", ")}",
            data: high_impact_tech,
            timestamp: DateTime.utc_now(),
            recommended_action: :strategic_pivot
          }
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp check_regulatory_anomalies(scan_data, anomalies) do
    if scan_data[:regulatory_updates] do
      critical_regs =
        scan_data.regulatory_updates
        |> Enum.filter(fn reg -> reg.impact == :high || reg.status == "enacted" end)

      if length(critical_regs) > 0 do
        [
          %{
            type: :regulatory_anomaly,
            severity: 0.9,
            description: "Critical regulatory changes detected",
            data: critical_regs,
            timestamp: DateTime.utc_now(),
            recommended_action: :compliance_update
          }
          | anomalies
        ]
      else
        anomalies
      end
    else
      anomalies
    end
  end

  defp report_anomalies_to_queen(anomalies) do
    Enum.each(anomalies, fn anomaly ->
      Logger.warning("Analyzer: Anomaly detected: #{inspect(anomaly.type)}")
      GenServer.cast(Queen, {:anomaly_detected, anomaly})
    end)
  end

  defp update_detected_patterns(state, new_patterns) do
    %{
      state
      | detected_patterns: Map.merge(state.detected_patterns, new_patterns),
        analysis_history:
          [{DateTime.utc_now(), new_patterns} | state.analysis_history] |> Enum.take(100)
    }
  end

  defp analyze_internal_trends(learning_data) do
    %{
      performance_trend: :improving,
      adaptation_effectiveness: 0.85,
      resource_efficiency_trend: :stable,
      pattern_evolution: analyze_pattern_evolution(learning_data)
    }
  end

  defp analyze_pattern_evolution(learning_data) do
    # Analyze how patterns have evolved over time
    recent_data = Enum.take(learning_data, 10)

    if length(recent_data) > 5 do
      %{
        variety_trend: calculate_variety_trend(recent_data),
        emergence_trend: calculate_emergence_trend(recent_data)
      }
    else
      %{variety_trend: :insufficient_data, emergence_trend: :insufficient_data}
    end
  end

  defp calculate_variety_trend(data) do
    scores = Enum.map(data, fn {_time, analysis} -> analysis[:variety_score] || 0 end)

    if length(scores) > 1 and List.first(scores) > List.last(scores),
      do: :increasing,
      else: :stable
  end

  defp calculate_emergence_trend(data) do
    levels = Enum.map(data, fn {_time, analysis} -> analysis[:emergence_level] || :none end)
    if Enum.any?(levels, &(&1 in [:high, :medium])), do: :active, else: :dormant
  end

  defp combine_trend_analyses(state) do
    internal = analyze_internal_trends(state.learning_data)

    %{
      internal: internal,
      pattern_summary: summarize_patterns(state.detected_patterns),
      recommendation: generate_trend_recommendation(internal)
    }
  end

  defp summarize_patterns(patterns) do
    %{
      total_patterns: map_size(patterns),
      pattern_types: Map.keys(patterns)
    }
  end

  defp generate_trend_recommendation(internal_trends) do
    if internal_trends.performance_trend == :improving do
      :maintain_course
    else
      :adjust_strategy
    end
  end

  defp assess_emergence_level(variety_data) do
    emergent_properties = variety_data[:emergent_properties] || %{}

    cond do
      map_size(emergent_properties) > 5 -> :high
      map_size(emergent_properties) > 2 -> :medium
      map_size(emergent_properties) > 0 -> :low
      true -> :none
    end
  end

  defp should_spawn_meta_system?(variety_data) do
    variety_data[:meta_system_seeds] != %{} ||
      length(variety_data[:recursive_potential] || []) > 3
  end

  defp calculate_variety_score(variety_data) do
    factors = [
      map_size(variety_data[:novel_patterns] || %{}) * 0.3,
      length(variety_data[:recursive_potential] || []) * 0.2,
      if(variety_data[:meta_system_seeds], do: 0.3, else: 0),
      if(variety_data[:emergent_properties], do: 0.2, else: 0)
    ]

    Enum.sum(factors)
  end
end
