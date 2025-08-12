defmodule VsmPhoenix.System4.Intelligence do
  @moduledoc """
  System 4 - Intelligence: Environmental Scanning and Adaptation
  
  Integrates with Tidewave for market intelligence and:
  - Environmental scanning and trend detection
  - Adaptation proposals and innovation
  - Future modeling and prediction
  - External variety absorption
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System4.LLMVarietySource
  alias AMQP
  alias VsmPhoenix.Infrastructure.CausalityAMQP
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def scan_environment(scope \\ :full) do
    GenServer.call(@name, {:scan_environment, scope})
  end
  
  def analyze_trends(data_source) do
    GenServer.call(@name, {:analyze_trends, data_source})
  end
  
  def generate_adaptation_proposal(challenge) do
    GenServer.call(@name, {:generate_adaptation, challenge})
  end
  
  def get_system_health do
    GenServer.call(@name, :get_system_health)
  end
  
  def implement_adaptation(proposal) do
    GenServer.cast(@name, {:implement_adaptation, proposal})
  end
  
  def request_adaptation_proposals(viability_metrics) do
    GenServer.cast(@name, {:request_proposals, viability_metrics})
  end
  
  def integrate_tidewave_insights(insights) do
    GenServer.cast(@name, {:tidewave_insights, insights})
  end
  
  def get_intelligence_state do
    GenServer.call(@name, :get_intelligence_state)
  end
  
  def analyze_variety_patterns(variety_data, scope \\ :full) do
    GenServer.call(@name, {:analyze_variety_patterns, variety_data, scope})
  end
  
  def get_systemic_patterns do
    GenServer.call(@name, :get_systemic_patterns)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("System 4 Intelligence initializing...")
    
    state = %{
      environmental_data: %{
        market_trends: [],
        technology_shifts: [],
        regulatory_changes: [],
        competitive_landscape: []
      },
      tidewave_connection: nil,
      adaptation_models: %{
        incremental: load_incremental_model(),
        transformational: load_transformational_model(),
        defensive: load_defensive_model()
      },
      current_adaptations: [],
      intelligence_metrics: %{
        scan_coverage: 0.0,
        prediction_accuracy: 0.85,
        adaptation_success_rate: 0.9,
        innovation_index: 0.7
      },
      # Agnostic VSM Pattern Tracking
      systemic_patterns: %{
        environmental_changes: [],      # Detected variations in environment
        pattern_matches: [],            # Recognized patterns with timestamps
        anomaly_score: 0.0,            # Current deviation from normal (0-1)
        adaptation_triggers: [],        # Changes initiated with reasons
        scan_coverage_percentage: 0.0   # Percentage of environment monitored
      },
      pattern_baseline: %{
        normal_variance: 0.1,          # Expected variance threshold
        pattern_library: [],           # Known patterns for matching
        anomaly_history: [],          # Historical anomaly scores
        coverage_targets: %{          # What should be monitored
          market: 1.0,
          technology: 1.0,
          regulatory: 1.0,
          competitive: 1.0
        }
      },
      learning_data: [],
      amqp_channel: nil
    }
    
    # Initialize Tidewave connection
    {:ok, tidewave} = init_tidewave_connection()
    
    # Set up AMQP for environmental alerts
    state = if System.get_env("DISABLE_AMQP") == "true" do
      state
    else
      setup_amqp_intelligence(state)
    end
    
    # DISABLED: No more automatic environmental scanning with fake data
    # schedule_environmental_scan()
    
    {:ok, %{state | tidewave_connection: tidewave}}
  end
  
  @impl true
  def handle_call({:scan_environment, scope}, _from, state) do
    Logger.info("Intelligence: Scanning environment - scope: #{scope}")
    
    scan_results = perform_environmental_scan(scope, state.tidewave_connection)
    
    new_environmental_data = update_environmental_data(state.environmental_data, scan_results)
    
    # AGNOSTIC VSM: Track Environmental Changes
    environmental_changes = detect_environmental_changes(scan_results, state.environmental_data)
    
    # AGNOSTIC VSM: Pattern Matching
    pattern_matches = match_patterns(scan_results, state.pattern_baseline.pattern_library)
    
    # AGNOSTIC VSM: Calculate Anomaly Score
    current_anomaly_score = calculate_anomaly_score(scan_results, state.pattern_baseline)
    
    # AGNOSTIC VSM: Update Scan Coverage
    scan_coverage = calculate_scan_coverage_percentage(scan_results, state.pattern_baseline.coverage_targets)
    
    # Update systemic patterns
    updated_patterns = %{state.systemic_patterns |
      environmental_changes: (state.systemic_patterns.environmental_changes ++ environmental_changes) |> Enum.take(100),
      pattern_matches: (state.systemic_patterns.pattern_matches ++ pattern_matches) |> Enum.take(100),
      anomaly_score: current_anomaly_score,
      scan_coverage_percentage: scan_coverage
    }
    
    # Update anomaly history
    updated_baseline = %{state.pattern_baseline |
      anomaly_history: [{DateTime.utc_now(), current_anomaly_score} | state.pattern_baseline.anomaly_history] |> Enum.take(1000)
    }
    
    new_state = %{state | 
      environmental_data: new_environmental_data,
      systemic_patterns: updated_patterns,
      pattern_baseline: updated_baseline
    }
    
    # Analyze for potential threats or opportunities
    insights = analyze_scan_results(scan_results)
    
    # Update learning data with scan insights
    learning_entry = %{
      timestamp: DateTime.utc_now(),
      scope: scope,
      insights: insights,
      data_quality: calculate_scan_quality(scan_results),
      patterns_detected: count_patterns_in_scan(scan_results),
      anomaly_score: current_anomaly_score,
      scan_coverage: scan_coverage
    }
    new_learning_data = [learning_entry | state.learning_data] |> Enum.take(1000)
    new_state = %{new_state | learning_data: new_learning_data}
    
    # NEW: Detect anomalies and report to S5 for policy synthesis
    anomalies = detect_anomalies(scan_results)
    Enum.each(anomalies, fn anomaly ->
      Logger.warning("🚨 S4: Anomaly detected: #{inspect(anomaly.type)} - Score: #{current_anomaly_score}")
      # Report to Queen for LLM-based policy synthesis
      GenServer.cast(VsmPhoenix.System5.Queen, {:anomaly_detected, Map.put(anomaly, :anomaly_score, current_anomaly_score)})
    end)
    
    if insights.requires_adaptation do
      # Generate adaptation proposal internally without recursive call
      proposal = generate_internal_adaptation_proposal(insights.challenge, state)
      
      # AGNOSTIC VSM: Track Adaptation Trigger
      adaptation_trigger = %{
        timestamp: DateTime.utc_now(),
        trigger_type: insights.challenge.type,
        urgency: insights.challenge[:urgency] || :medium,
        anomaly_score: current_anomaly_score,
        environmental_factors: Enum.take(environmental_changes, 3),
        proposal_id: proposal.id
      }
      
      updated_patterns_with_trigger = %{updated_patterns |
        adaptation_triggers: [adaptation_trigger | updated_patterns.adaptation_triggers] |> Enum.take(100)
      }
      
      new_state = %{new_state | systemic_patterns: updated_patterns_with_trigger}
      
      Queen.approve_adaptation(proposal)
    end
    
    # Publish environmental alert to AMQP
    # Determine alert level based on requires_adaptation and challenge urgency
    alert_level = cond do
      insights.requires_adaptation && insights.challenge && insights.challenge.urgency == :high -> :critical
      insights.requires_adaptation -> :high
      true -> :normal
    end
    
    if alert_level in [:high, :critical] do
      alert = %{
        type: "environmental_alert",
        level: alert_level,
        scope: scope,
        insights: insights,
        anomalies: anomalies,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      publish_environmental_alert(alert, new_state)
      {:reply, insights, new_state}
    else
      {:reply, insights, new_state}
    end
  end
  
  @impl true
  def handle_call({:analyze_trends, data_source}, _from, state) do
    Logger.info("Intelligence: Analyzing trends from #{data_source}")
    
    trends = case data_source do
      :tidewave -> analyze_tidewave_trends(state.tidewave_connection)
      :internal -> analyze_internal_trends(state.learning_data)
      :combined -> combine_trend_analyses(state)
    end
    
    {:reply, trends, state}
  end
  
  @impl true
  def handle_call({:generate_adaptation, challenge}, _from, state) do
    Logger.info("Intelligence: Generating adaptation proposal for challenge")
    
    # Select appropriate adaptation model
    model = select_adaptation_model(challenge, state.adaptation_models)
    
    proposal = %{
      id: generate_proposal_id(),
      challenge: challenge,
      model_type: model.type,
      actions: model[:generate_actions].(challenge),
      impact: model[:estimate_impact].(challenge),
      resources_required: model[:estimate_resources].(challenge),
      timeline: model[:estimate_timeline].(challenge),
      risks: model[:identify_risks].(challenge)
    }
    
    {:reply, proposal, state}
  end
  
  @impl true
  def handle_call(:get_system_health, _from, state) do
    # Calculate dynamic scan coverage based on actual environmental data
    scan_coverage = calculate_real_scan_coverage(state.environmental_data)
    
    # Calculate dynamic innovation capacity from patterns and learning
    innovation_capacity = calculate_real_innovation_capacity(state.learning_data, state.environmental_data)
    
    # Update metrics with real values
    updated_metrics = %{state.intelligence_metrics |
      scan_coverage: scan_coverage,
      innovation_index: innovation_capacity
    }
    
    health = %{
      health: calculate_overall_health(%{state | intelligence_metrics: updated_metrics}),
      scan_coverage: scan_coverage,
      adaptation_readiness: calculate_adaptation_readiness(state),
      innovation_capacity: innovation_capacity
    }
    
    # Update state with new metrics
    new_state = %{state | intelligence_metrics: updated_metrics}
    
    {:reply, health, new_state}
  end
  
  @impl true
  def handle_call(:get_intelligence_state, _from, state) do
    # Return comprehensive intelligence state
    intelligence_state = %{
      environmental_data: state.environmental_data,
      current_adaptations: state.current_adaptations,
      metrics: state.intelligence_metrics,
      tidewave_status: if(state.tidewave_connection, do: :connected, else: :disconnected),
      learning_data_count: length(state.learning_data),
      adaptation_models: Map.keys(state.adaptation_models)
    }
    
    {:reply, {:ok, intelligence_state}, state}
  end
  
  @impl true
  def handle_call(:get_systemic_patterns, _from, state) do
    # Return agnostic VSM systemic patterns
    patterns = %{
      environmental_changes: Enum.take(state.systemic_patterns.environmental_changes, 10),
      pattern_matches: Enum.take(state.systemic_patterns.pattern_matches, 10),
      anomaly_score: state.systemic_patterns.anomaly_score,
      adaptation_triggers: Enum.take(state.systemic_patterns.adaptation_triggers, 10),
      scan_coverage_percentage: state.systemic_patterns.scan_coverage_percentage,
      # Additional context
      anomaly_trend: calculate_anomaly_trend(state.pattern_baseline.anomaly_history),
      pattern_frequency: calculate_pattern_frequency(state.systemic_patterns.pattern_matches),
      adaptation_rate: calculate_adaptation_rate(state.systemic_patterns.adaptation_triggers)
    }
    
    {:reply, {:ok, patterns}, state}
  end
  
  @impl true
  def handle_call({:analyze_variety_patterns, variety_data, scope}, _from, state) do
    Logger.info("Intelligence: Analyzing variety patterns - scope: #{scope}")
    
    # Analyze the variety data for patterns and insights
    analysis = %{
      pattern_count: map_size(variety_data[:novel_patterns] || %{}),
      emergence_level: assess_emergence_level(variety_data),
      recursive_potential: variety_data[:recursive_potential] || [],
      meta_system_recommendation: should_spawn_meta_system?(variety_data),
      adaptation_strategy: recommend_adaptation_strategy(variety_data, state),
      variety_score: calculate_variety_score(variety_data)
    }
    
    # Update learning data with this analysis
    new_learning_data = [{DateTime.utc_now(), analysis} | state.learning_data]
    new_state = %{state | learning_data: Enum.take(new_learning_data, 1000)}
    
    {:reply, {:ok, analysis}, new_state}
  end
  
  @impl true
  def handle_cast({:implement_adaptation, proposal}, state) do
    Logger.info("Intelligence: Implementing adaptation #{proposal.id}")
    
    try do
      # Validate proposal structure
      if not is_map(proposal) or not Map.has_key?(proposal, :id) do
        raise ArgumentError, "Invalid proposal structure"
      end
      
      # Add to current adaptations
      new_adaptations = [proposal | state.current_adaptations]
      
      # Coordinate with System 3 for resource allocation
      case Control.allocate_for_adaptation(proposal) do
        :ok ->
          # Monitor adaptation progress
          schedule_adaptation_monitoring(proposal.id)
          {:noreply, %{state | current_adaptations: new_adaptations}}
          
        {:error, reason} ->
          Logger.error("Failed to allocate resources for adaptation #{proposal.id}: #{inspect(reason)}")
          # Still add to adaptations but mark as resource-constrained
          marked_proposal = Map.put(proposal, :resource_constrained, true)
          new_adaptations = [marked_proposal | state.current_adaptations]
          schedule_adaptation_monitoring(proposal.id)
          {:noreply, %{state | current_adaptations: new_adaptations}}
      end
    rescue
      e ->
        Logger.error("Error implementing adaptation #{inspect(proposal[:id])}: #{inspect(e)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:request_proposals, viability_metrics}, state) do
    Logger.info("Intelligence: Generating proposals for viability issues")
    
    challenges = identify_challenges_from_metrics(viability_metrics)
    
    Enum.each(challenges, fn challenge ->
      # Generate proposal inline to avoid self-call
      proposal = do_generate_adaptation_proposal(challenge, state)
      Queen.approve_adaptation(proposal)
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:tidewave_insights, insights}, state) do
    Logger.info("Intelligence: Processing Tidewave insights")
    
    # Update environmental data with Tidewave insights
    new_environmental_data = merge_tidewave_insights(state.environmental_data, insights)
    
    # Update learning data
    new_learning_data = [{DateTime.utc_now(), insights} | state.learning_data]
    
    new_state = %{
      state | 
      environmental_data: new_environmental_data,
      learning_data: Enum.take(new_learning_data, 1000)
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:scheduled_scan, state) do
    # DISABLED: No more fake scheduled scans
    Logger.debug("Intelligence: Scheduled scan disabled - waiting for real data")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:monitor_adaptation, adaptation_id}, state) do
    adaptation = Enum.find(state.current_adaptations, &(&1.id == adaptation_id))
    
    if adaptation do
      progress = monitor_adaptation_progress(adaptation)
      
      if progress.completed do
        # Update metrics based on success
        new_metrics = update_adaptation_metrics(state.intelligence_metrics, progress)
        
        # Remove from current adaptations
        new_adaptations = Enum.reject(state.current_adaptations, &(&1.id == adaptation_id))
        
        {:noreply, %{state | 
          current_adaptations: new_adaptations,
          intelligence_metrics: new_metrics
        }}
      else
        # Continue monitoring
        schedule_adaptation_monitoring(adaptation_id)
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp generate_internal_adaptation_proposal(challenge, state) do
    # Select appropriate adaptation model
    model = select_adaptation_model(challenge, state.adaptation_models)
    
    %{
      id: generate_proposal_id(),
      challenge: challenge,
      model_type: model.type,
      actions: model[:generate_actions].(challenge),
      impact: model[:estimate_impact].(challenge),
      resources_required: model[:estimate_resources].(challenge),
      timeline: model[:estimate_timeline].(challenge),
      risks: model[:identify_risks].(challenge)
    }
  end
  
  defp init_tidewave_connection do
    # Initialize connection to Tidewave system
    # This would integrate with the actual Tidewave library
    {:ok, %{status: :connected, endpoint: "tidewave://localhost:4000"}}
  end
  
  defp perform_environmental_scan(scope, _tidewave) do
    # Environmental scanning with LLM variety amplification!
    base_scan = %{
      market_signals: generate_market_signals(),
      technology_trends: detect_technology_trends(),
      regulatory_updates: check_regulatory_changes(),
      competitive_moves: analyze_competition(),
      timestamp: DateTime.utc_now()
    }
    
    # LLM analysis is optional - don't let it crash the system
    final_scan = if Application.get_env(:vsm_phoenix, :enable_llm_variety, false) do
      # Run LLM analysis in a separate task with timeout
      task = Task.async(fn ->
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
          Logger.info("🔥 LLM VARIETY EXPLOSION: #{inspect(variety_expansion)}")
          
          # Check if we should spawn a meta-system
          if variety_expansion.meta_system_seeds != %{} do
            Logger.info("🌀 RECURSIVE META-SYSTEM OPPORTUNITY DETECTED!")
            spawn(fn -> LLMVarietySource.pipe_to_system1_meta_generation(variety_expansion) end)
          end
          
          Map.merge(base_scan, %{llm_variety: variety_expansion})
          
        _ ->
          Logger.debug("LLM variety analysis skipped or timed out")
          base_scan
      end
    else
      base_scan
    end
    
    final_scan
  end
  
  defp generate_market_signals do
    # Generate more realistic market signals with some randomization
    base_signals = [
      %{signal: "increased_demand", strength: 0.5 + :rand.uniform() * 0.3, source: "sales_data"},
      %{signal: "price_pressure", strength: 0.3 + :rand.uniform() * 0.3, source: "market_analysis"},
      %{signal: "new_segment_emerging", strength: 0.4 + :rand.uniform() * 0.4, source: "tidewave"}
    ]
    
    # Add dynamic signals based on current time
    hour = DateTime.utc_now().hour
    
    # Add time-based patterns
    time_signals = cond do
      hour >= 9 && hour <= 17 ->  # Business hours
        [%{signal: "peak_activity", strength: 0.6 + :rand.uniform() * 0.2, source: "activity_monitor"}]
      hour >= 22 || hour <= 5 ->   # Night hours
        [%{signal: "low_activity", strength: 0.2 + :rand.uniform() * 0.1, source: "activity_monitor"}]
      true ->
        []
    end
    
    # Occasionally add anomalous signals
    anomaly_signals = if :rand.uniform() > 0.8 do
      [%{signal: "anomaly_detected", strength: 0.8 + :rand.uniform() * 0.2, source: "anomaly_detector"}]
    else
      []
    end
    
    base_signals ++ time_signals ++ anomaly_signals
  end
  
  defp detect_technology_trends do
    # Dynamic technology trends based on probability
    all_trends = [
      %{trend: "ai_adoption", impact: :high, timeline: "6_months", probability: 0.7},
      %{trend: "edge_computing", impact: :medium, timeline: "12_months", probability: 0.5},
      %{trend: "quantum_computing", impact: :high, timeline: "3_years", probability: 0.2},
      %{trend: "blockchain_integration", impact: :low, timeline: "18_months", probability: 0.3},
      %{trend: "5g_deployment", impact: :medium, timeline: "6_months", probability: 0.6},
      %{trend: "iot_expansion", impact: :medium, timeline: "9_months", probability: 0.4}
    ]
    
    # Filter trends based on probability
    Enum.filter(all_trends, fn trend ->
      :rand.uniform() < trend.probability
    end)
    |> Enum.map(fn trend ->
      Map.delete(trend, :probability)
    end)
  end
  
  defp check_regulatory_changes do
    # Dynamic regulatory changes
    regulations = [
      %{regulation: "data_privacy", status: "proposed", impact: :medium, region: "EU"},
      %{regulation: "ai_governance", status: "draft", impact: :high, region: "US"},
      %{regulation: "carbon_emissions", status: "enacted", impact: :low, region: "Global"},
      %{regulation: "cybersecurity", status: "proposed", impact: :high, region: "US"}
    ]
    
    # Randomly select some regulations
    num_regs = :rand.uniform(3)
    Enum.take_random(regulations, num_regs)
  end
  
  defp analyze_competition do
    # Dynamic competitive analysis
    competitors = ["comp_a", "comp_b", "comp_c", "startup_x"]
    actions = ["new_product", "price_cut", "acquisition", "expansion", "partnership"]
    threat_levels = [:low, :medium, :high]
    
    # Generate 0-3 competitive moves
    num_moves = :rand.uniform(4) - 1
    
    Enum.map(1..num_moves, fn _ ->
      %{
        competitor: Enum.random(competitors),
        action: Enum.random(actions),
        threat_level: Enum.random(threat_levels),
        timeline: "#{:rand.uniform(12)}_months"
      }
    end)
  end
  
  defp update_environmental_data(current_data, scan_results) do
    %{
      market_trends: [scan_results.market_signals | current_data.market_trends] |> Enum.take(50),
      technology_shifts: [scan_results.technology_trends | current_data.technology_shifts] |> Enum.take(50),
      regulatory_changes: [scan_results.regulatory_updates | current_data.regulatory_changes] |> Enum.take(50),
      competitive_landscape: [scan_results.competitive_moves | current_data.competitive_landscape] |> Enum.take(50)
    }
  end
  
  defp analyze_scan_results(scan_results) do
    # Analyze scan results for actionable insights
    high_impact_signals = Enum.filter(scan_results.market_signals, &(&1.strength > 0.6))
    
    %{
      requires_adaptation: length(high_impact_signals) > 0,
      challenge: if(length(high_impact_signals) > 0, do: build_challenge(high_impact_signals), else: nil),
      opportunities: identify_opportunities(scan_results),
      threats: identify_threats(scan_results)
    }
  end
  
  defp build_challenge(signals) do
    %{
      type: :market_shift,
      signals: signals,
      urgency: :medium,
      scope: :tactical
    }
  end
  
  defp identify_opportunities(scan_results) do
    Enum.filter(scan_results.market_signals, &(&1.signal == "new_segment_emerging"))
  end
  
  defp identify_threats(scan_results) do
    Enum.filter(scan_results.competitive_moves, &(&1.threat_level in [:high, :medium]))
  end
  
  defp analyze_tidewave_trends(_connection) do
    # Analyze trends from Tidewave data
    %{
      market_direction: :growth,
      volatility: :moderate,
      key_drivers: ["digital_transformation", "sustainability"],
      forecast_confidence: 0.75
    }
  end
  
  defp analyze_internal_trends(learning_data) do
    # Analyze internal system trends
    %{
      performance_trend: :improving,
      adaptation_effectiveness: 0.85,
      resource_efficiency_trend: :stable
    }
  end
  
  defp combine_trend_analyses(state) do
    external = analyze_tidewave_trends(state.tidewave_connection)
    internal = analyze_internal_trends(state.learning_data)
    
    %{
      external: external,
      internal: internal,
      combined_outlook: determine_combined_outlook(external, internal)
    }
  end
  
  defp determine_combined_outlook(external, internal) do
    if external.market_direction == :growth and internal.performance_trend == :improving do
      :positive
    else
      :cautious
    end
  end
  
  defp load_incremental_model do
    %{
      type: :incremental,
      generate_actions: fn _challenge -> ["optimize_processes", "enhance_features"] end,
      estimate_impact: fn _challenge -> 0.2 end,
      estimate_resources: fn _challenge -> %{time: "2_weeks", cost: :low} end,
      estimate_timeline: fn _challenge -> "1_month" end,
      identify_risks: fn _challenge -> [:minimal_disruption] end
    }
  end
  
  defp load_transformational_model do
    %{
      type: :transformational,
      generate_actions: fn _challenge -> ["restructure_operations", "new_capabilities"] end,
      estimate_impact: fn _challenge -> 0.7 end,
      estimate_resources: fn _challenge -> %{time: "3_months", cost: :high} end,
      estimate_timeline: fn _challenge -> "6_months" end,
      identify_risks: fn _challenge -> [:disruption, :resistance] end
    }
  end
  
  defp load_defensive_model do
    %{
      type: :defensive,
      generate_actions: fn _challenge -> ["strengthen_core", "reduce_exposure"] end,
      estimate_impact: fn _challenge -> 0.3 end,
      estimate_resources: fn _challenge -> %{time: "1_month", cost: :medium} end,
      estimate_timeline: fn _challenge -> "2_months" end,
      identify_risks: fn _challenge -> [:opportunity_loss] end
    }
  end
  
  defp select_adaptation_model(challenge, models) do
    case challenge.urgency do
      :high -> models.defensive
      :medium -> models.incremental
      :low -> models.transformational
    end
  end
  
  defp generate_proposal_id do
    "ADAPT-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(1000)}"
  end
  
  defp calculate_overall_health(state) do
    metrics = state.intelligence_metrics
    (metrics.scan_coverage + metrics.prediction_accuracy + 
     metrics.adaptation_success_rate + metrics.innovation_index) / 4
  end
  
  defp calculate_adaptation_readiness(state) do
    # Calculate readiness based on multiple factors
    
    # Current adaptation load
    active_adaptations = length(state.current_adaptations)
    load_factor = case active_adaptations do
      0 -> 1.0    # No load = maximum readiness
      1 -> 0.9    # Light load
      2 -> 0.8    # Moderate load
      3 -> 0.6    # Heavy load
      _ -> 0.3    # Overloaded
    end
    
    # Historical success rate from metrics
    success_factor = state.intelligence_metrics.adaptation_success_rate
    
    # Environmental scanning quality affects readiness
    scan_quality = state.intelligence_metrics.scan_coverage
    
    # Learning data availability
    learning_factor = if length(state.learning_data) > 10 do
      0.9
    else
      0.6 + (length(state.learning_data) / 20)
    end
    
    # Model availability (we have 3 models)
    model_factor = if map_size(state.adaptation_models) >= 3, do: 0.9, else: 0.7
    
    # Tidewave connection status
    connection_factor = if state.tidewave_connection, do: 0.9, else: 0.7
    
    # Weight the factors
    readiness = (load_factor * 0.3) + 
                (success_factor * 0.2) + 
                (scan_quality * 0.2) + 
                (learning_factor * 0.15) + 
                (model_factor * 0.1) + 
                (connection_factor * 0.05)
    
    min(max(readiness, 0.1), 1.0)
  end
  
  defp identify_challenges_from_metrics(metrics) do
    challenges = []
    
    challenges = if metrics.system_health < 0.7, 
      do: [%{type: :health, urgency: :high, scope: :system_wide} | challenges], 
      else: challenges
      
    challenges = if metrics.resource_efficiency < 0.6,
      do: [%{type: :efficiency, urgency: :medium, scope: :operational} | challenges],
      else: challenges
      
    challenges
  end
  
  defp merge_tidewave_insights(environmental_data, insights) do
    %{environmental_data |
      market_trends: [insights[:market] | environmental_data.market_trends] |> Enum.take(50)
    }
  end
  
  defp monitor_adaptation_progress(adaptation) do
    # Simulate monitoring adaptation progress
    %{
      completed: :rand.uniform() > 0.7,
      success: true,
      metrics_impact: %{
        efficiency: 0.1,
        effectiveness: 0.15
      }
    }
  end
  
  defp update_adaptation_metrics(metrics, progress) do
    if progress.success do
      %{metrics | 
        adaptation_success_rate: metrics.adaptation_success_rate * 0.95 + 0.05
      }
    else
      %{metrics | 
        adaptation_success_rate: metrics.adaptation_success_rate * 0.95
      }
    end
  end
  
  defp do_generate_adaptation_proposal(challenge, state) do
    Logger.info("Intelligence: Generating adaptation proposal for challenge")
    
    # Select appropriate adaptation model
    model = select_adaptation_model(challenge, state.adaptation_models)
    
    %{
      id: generate_proposal_id(),
      challenge: challenge,
      model_type: model.type,
      actions: model[:generate_actions].(challenge),
      impact: model[:estimate_impact].(challenge),
      resources_required: model[:estimate_resources].(challenge),
      timeline: model[:estimate_timeline].(challenge),
      risks: model[:identify_risks].(challenge)
    }
  end
  
  defp schedule_environmental_scan do
    Process.send_after(self(), :scheduled_scan, 60_000)  # Scan every minute
  end
  
  defp schedule_adaptation_monitoring(adaptation_id) do
    Process.send_after(self(), {:monitor_adaptation, adaptation_id}, 10_000)
  end
  
  defp detect_anomalies(scan_data) do
    anomalies = []
    
    # Check for variety explosion from LLM
    anomalies = if scan_data[:llm_variety] && scan_data.llm_variety[:novel_patterns] do
      pattern_count = map_size(scan_data.llm_variety.novel_patterns)
      if pattern_count > 10 do
        # Dynamic severity based on pattern count and complexity
        base_severity = min(pattern_count / 20, 0.5)  # Up to 0.5 from count
        complexity_factor = calculate_pattern_complexity(scan_data.llm_variety.novel_patterns)
        severity = min(base_severity + complexity_factor, 1.0)
        
        [%{
          type: :variety_explosion,
          severity: severity,
          description: "LLM detected #{pattern_count} novel patterns exceeding current capacity",
          data: scan_data.llm_variety,
          timestamp: DateTime.utc_now(),
          recommended_action: :spawn_meta_vsm,
          metrics: %{
            pattern_count: pattern_count,
            complexity: complexity_factor,
            emergence_level: scan_data.llm_variety[:emergence_level] || 0
          }
        } | anomalies]
      else
        anomalies
      end
    else
      anomalies
    end
    
    # Check for unusual market signals
    if scan_data[:market_signals] do
      unusual_signals = scan_data.market_signals
      |> Enum.filter(fn signal -> signal.strength > 0.8 end)
      
      anomalies = if length(unusual_signals) > 0 do
        # Dynamic severity based on signal count and average strength
        max_strength = Enum.max_by(unusual_signals, & &1.strength).strength
        avg_strength = Enum.sum(Enum.map(unusual_signals, & &1.strength)) / length(unusual_signals)
        signal_density = min(length(unusual_signals) / 5, 0.3)  # Up to 0.3 from count
        
        severity = (max_strength * 0.5) + (avg_strength * 0.3) + signal_density
        
        [%{
          type: :market_anomaly,
          severity: min(severity, 1.0),
          description: "Unusual market signals detected: #{length(unusual_signals)} high-strength signals",
          data: unusual_signals,
          timestamp: DateTime.utc_now(),
          recommended_action: :policy_adaptation,
          metrics: %{
            signal_count: length(unusual_signals),
            max_strength: max_strength,
            avg_strength: avg_strength
          }
        } | anomalies]
      else
        anomalies
      end
    else
      anomalies
    end
    
    # Check for technology disruption
    if scan_data[:technology_trends] do
      high_impact_tech = scan_data.technology_trends
      |> Enum.filter(fn trend -> trend.impact == :high end)
      
      anomalies = if length(high_impact_tech) > 0 do
        # Dynamic severity based on number of high-impact trends and timeline
        impact_count = length(high_impact_tech)
        urgency_factor = calculate_tech_urgency(high_impact_tech)
        
        severity = min((impact_count / 3) * 0.5 + urgency_factor * 0.5, 1.0)
        
        [%{
          type: :technology_disruption,
          severity: severity,
          description: "High-impact technology trends detected: #{Enum.map(high_impact_tech, & &1.trend) |> Enum.join(", ")}",
          data: high_impact_tech,
          timestamp: DateTime.utc_now(),
          recommended_action: :strategic_pivot,
          metrics: %{
            high_impact_count: impact_count,
            urgency: urgency_factor,
            trends: Enum.map(high_impact_tech, & &1.trend)
          }
        } | anomalies]
      else
        anomalies
      end
    else
      anomalies
    end
    
    # Check for regulatory anomalies
    if scan_data[:regulatory_updates] do
      critical_regs = scan_data.regulatory_updates
      |> Enum.filter(fn reg -> reg.impact == :high || reg.status == "enacted" end)
      
      anomalies = if length(critical_regs) > 0 do
        # Dynamic severity based on regulation status and impact
        enacted_count = Enum.count(critical_regs, fn reg -> reg.status == "enacted" end)
        high_impact_count = Enum.count(critical_regs, fn reg -> reg.impact == :high end)
        
        base_severity = 0.6  # Regulatory is always serious
        enacted_factor = (enacted_count / max(length(critical_regs), 1)) * 0.3
        impact_factor = (high_impact_count / max(length(critical_regs), 1)) * 0.1
        
        severity = min(base_severity + enacted_factor + impact_factor, 1.0)
        
        [%{
          type: :regulatory_anomaly,
          severity: severity,
          description: "Critical regulatory changes detected",
          data: critical_regs,
          timestamp: DateTime.utc_now(),
          recommended_action: :compliance_update,
          metrics: %{
            total_critical: length(critical_regs),
            enacted: enacted_count,
            high_impact: high_impact_count
          }
        } | anomalies]
      else
        anomalies
      end
    else
      anomalies
    end
    
    anomalies
  end
  
  defp calculate_pattern_complexity(patterns) when is_map(patterns) do
    # Calculate complexity based on pattern characteristics
    pattern_values = Map.values(patterns)
    
    if length(pattern_values) == 0 do
      0.0
    else
      # Look for nested structures, interdependencies, etc.
      avg_size = Enum.sum(Enum.map(pattern_values, &estimate_pattern_size/1)) / length(pattern_values)
      # Normalize to 0-0.5 range
      min(avg_size / 100, 0.5)
    end
  end
  defp calculate_pattern_complexity(_), do: 0.0
  
  defp estimate_pattern_size(pattern) when is_map(pattern), do: map_size(pattern) * 2
  defp estimate_pattern_size(pattern) when is_list(pattern), do: length(pattern)
  defp estimate_pattern_size(_), do: 1
  
  defp calculate_tech_urgency(trends) do
    # Calculate urgency based on timelines
    urgent_count = Enum.count(trends, fn trend -> 
      trend[:timeline] in ["3_months", "6_months"]
    end)
    urgent_count / max(length(trends), 1)
  end
  
  defp calculate_real_scan_coverage(environmental_data) do
    # Calculate scan coverage based on actual data collected
    
    # Count data points across all environmental categories
    market_coverage = min(length(environmental_data.market_trends) / 10, 1.0)  # Expect ~10 trend data points
    tech_coverage = min(length(environmental_data.technology_shifts) / 8, 1.0)  # Expect ~8 tech shifts
    regulatory_coverage = min(length(environmental_data.regulatory_changes) / 5, 1.0)  # Expect ~5 reg changes
    competitive_coverage = min(length(environmental_data.competitive_landscape) / 6, 1.0)  # Expect ~6 competitive moves
    
    # Weight different categories
    total_coverage = (market_coverage * 0.3) + 
                    (tech_coverage * 0.25) + 
                    (regulatory_coverage * 0.25) + 
                    (competitive_coverage * 0.2)
    
    # Apply recency factor - more recent data = better coverage
    recency_factor = calculate_data_recency(environmental_data)
    
    final_coverage = total_coverage * recency_factor
    min(max(final_coverage, 0.0), 1.0)
  end
  
  defp calculate_data_recency(environmental_data) do
    # Check how recent our data is
    all_data = environmental_data.market_trends ++ 
               environmental_data.technology_shifts ++ 
               environmental_data.regulatory_changes ++ 
               environmental_data.competitive_landscape
    
    if length(all_data) == 0 do
      0.1  # No data = very low recency
    else
      # Assume each data point has a timestamp in the nested structure
      now = DateTime.utc_now()
      one_hour_ago = DateTime.add(now, -3600, :second)
      one_day_ago = DateTime.add(now, -86400, :second)
      
      # Count recent data points
      recent_count = Enum.count(all_data, fn data_list ->
        # Handle case where data might be nested lists
        recent_in_list = case data_list do
          list when is_list(list) ->
            Enum.any?(list, fn item ->
              timestamp = item[:timestamp] || item["timestamp"] || one_day_ago
              DateTime.compare(timestamp, one_hour_ago) != :lt
            end)
          _ -> false
        end
        recent_in_list
      end)
      
      # Calculate recency factor
      if recent_count > 0 do
        min(recent_count / length(all_data) + 0.5, 1.0)
      else
        0.3  # Old data still has some value
      end
    end
  end
  
  defp calculate_real_innovation_capacity(learning_data, environmental_data) do
    # Base innovation from learning data
    learning_factor = if length(learning_data) > 0 do
      # More learning data = higher innovation capacity
      recent_learning = Enum.take(learning_data, 50)
      min(length(recent_learning) / 50, 0.4)
    else
      0.1  # Minimal without learning
    end
    
    # Pattern diversity from environmental scanning
    pattern_diversity = calculate_pattern_diversity(environmental_data)
    
    # Adaptation success rate affects innovation capacity
    # Use real adaptation data - 0.0 until we have real adaptations
    adaptation_factor = 0.0
    
    # Environmental complexity drives innovation need
    environmental_complexity = calculate_environmental_complexity(environmental_data)
    
    # Combine factors
    innovation = learning_factor + 
                (pattern_diversity * 0.3) + 
                (adaptation_factor * 0.2) + 
                (environmental_complexity * 0.1)
    
    min(max(innovation, 0.1), 1.0)
  end
  
  defp calculate_pattern_diversity(environmental_data) do
    # Count unique patterns across all environmental data
    all_data = [
      environmental_data.market_trends,
      environmental_data.technology_shifts, 
      environmental_data.regulatory_changes,
      environmental_data.competitive_landscape
    ]
    
    total_patterns = Enum.sum(Enum.map(all_data, &length/1))
    
    if total_patterns > 0 do
      # More patterns = more diversity, capped at reasonable level
      min(total_patterns / 30, 0.5)
    else
      0.0
    end
  end
  
  defp calculate_environmental_complexity(environmental_data) do
    # Calculate complexity based on interconnections and variety
    
    # Market signal complexity
    market_complexity = calculate_signal_complexity(environmental_data.market_trends)
    
    # Technology shift complexity  
    tech_complexity = calculate_shift_complexity(environmental_data.technology_shifts)
    
    # Average complexity across domains
    avg_complexity = (market_complexity + tech_complexity) / 2
    min(avg_complexity, 0.3)
  end
  
  defp calculate_signal_complexity(trends) do
    if length(trends) == 0 do
      0.0
    else
      # Flatten nested structure and count unique signal types
      all_signals = Enum.flat_map(trends, fn trend_list ->
        case trend_list do
          list when is_list(list) -> list
          _ -> []
        end
      end)
      
      unique_signals = all_signals
      |> Enum.map(fn signal -> signal[:signal] || signal["signal"] end)
      |> Enum.uniq()
      |> length()
      
      min(unique_signals / 10, 0.3)
    end
  end
  
  defp calculate_shift_complexity(shifts) do
    if length(shifts) == 0 do
      0.0
    else
      # Count high-impact shifts
      all_shifts = Enum.flat_map(shifts, fn shift_list ->
        case shift_list do
          list when is_list(list) -> list
          _ -> []
        end
      end)
      
      high_impact = Enum.count(all_shifts, fn shift ->
        shift[:impact] == :high || shift["impact"] == "high"
      end)
      
      min(high_impact / 5, 0.3)
    end
  end
  
  defp calculate_scan_quality(scan_results) do
    # Assess quality of scan based on data completeness and variety
    
    # Data completeness
    data_fields = [:market_signals, :technology_trends, :regulatory_updates, :competitive_moves]
    present_fields = Enum.count(data_fields, fn field ->
      Map.has_key?(scan_results, field) && not Enum.empty?(scan_results[field])
    end)
    completeness = present_fields / length(data_fields)
    
    # Data variety within each field
    variety_score = if scan_results[:market_signals] do
      signal_types = Enum.map(scan_results.market_signals, & &1.signal) |> Enum.uniq() |> length()
      min(signal_types / 5, 1.0)
    else
      0.0
    end
    
    # LLM variety contribution
    llm_bonus = if scan_results[:llm_variety], do: 0.2, else: 0.0
    
    # Combine factors
    quality = (completeness * 0.6) + (variety_score * 0.2) + llm_bonus
    min(max(quality, 0.0), 1.0)
  end
  
  defp count_patterns_in_scan(scan_results) do
    # Count total patterns detected across all scan categories
    pattern_count = 0
    
    # Market patterns
    pattern_count = pattern_count + length(scan_results[:market_signals] || [])
    
    # Technology patterns
    pattern_count = pattern_count + length(scan_results[:technology_trends] || [])
    
    # Regulatory patterns
    pattern_count = pattern_count + length(scan_results[:regulatory_updates] || [])
    
    # Competitive patterns
    pattern_count = pattern_count + length(scan_results[:competitive_moves] || [])
    
    # LLM patterns
    if scan_results[:llm_variety] && scan_results.llm_variety[:novel_patterns] do
      pattern_count = pattern_count + map_size(scan_results.llm_variety.novel_patterns)
    end
    
    pattern_count
  end
  
  defp assess_emergence_level(variety_data) do
    # Assess the level of emergence in the variety data
    emergent_properties = variety_data[:emergent_properties] || %{}
    
    cond do
      map_size(emergent_properties) > 5 -> :high
      map_size(emergent_properties) > 2 -> :medium
      map_size(emergent_properties) > 0 -> :low
      true -> :none
    end
  end
  
  defp should_spawn_meta_system?(variety_data) do
    # Determine if variety complexity warrants meta-system spawning
    variety_data[:meta_system_seeds] != %{} ||
    length(variety_data[:recursive_potential] || []) > 3
  end
  
  defp recommend_adaptation_strategy(variety_data, state) do
    # Recommend adaptation strategy based on variety patterns
    emergence = assess_emergence_level(variety_data)
    current_load = length(state.current_adaptations)
    
    cond do
      emergence == :high && current_load < 3 -> :transformational
      emergence == :medium -> :incremental
      current_load > 5 -> :defensive
      true -> :balanced
    end
  end
  
  defp calculate_variety_score(variety_data) do
    # Calculate overall variety score with validation
    novel_patterns_size = 
      case variety_data[:novel_patterns] do
        map when is_map(map) -> map_size(map)
        _ -> 0
      end
    
    recursive_potential_length = 
      case variety_data[:recursive_potential] do
        list when is_list(list) -> length(list)
        _ -> 0
      end
    
    factors = [
      min(novel_patterns_size * 0.3, 100.0),  # Cap contribution at 100
      min(recursive_potential_length * 0.2, 100.0),
      (if variety_data[:meta_system_seeds], do: 0.3, else: 0),
      (if variety_data[:emergent_properties], do: 0.2, else: 0)
    ]
    
    # Ensure result is between 0 and 1
    score = Enum.sum(factors)
    min(max(score, 0.0), 1.0)
  end
  
  # AMQP Functions
  
  defp setup_amqp_intelligence(state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_channel(:intelligence) do
      {:ok, channel} ->
        try do
          # Create intelligence queue
          {:ok, _queue} = AMQP.Queue.declare(channel, "vsm.system4.intelligence", durable: true)
          
          # Bind to intelligence exchange
          :ok = AMQP.Queue.bind(channel, "vsm.system4.intelligence", "vsm.intelligence")
          
          # Start consuming intelligence messages
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, "vsm.system4.intelligence")
          
          Logger.info("🔍 Intelligence: AMQP consumer active! Tag: #{consumer_tag}")
          Logger.info("🔍 Intelligence: Listening for environmental alerts on vsm.intelligence exchange")
          
          Map.put(state, :amqp_channel, channel)
        rescue
          error ->
            Logger.error("Intelligence: Failed to set up AMQP: #{inspect(error)}")
            state
        end
        
      {:error, reason} ->
        Logger.error("Intelligence: Could not get AMQP channel: #{inspect(reason)}")
        # Schedule retry
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end
  
  defp publish_environmental_alert(alert, state) do
    if state[:amqp_channel] && System.get_env("DISABLE_AMQP") != "true" do
      try do
        payload = Jason.encode!(alert)
        
        :ok = CausalityAMQP.publish(
          state.amqp_channel,
          "vsm.intelligence",
          "",
          payload,
          content_type: "application/json"
        )
        
        Logger.info("🔍 Published environmental alert: #{alert["type"]}")
      rescue
        e ->
          Logger.warning("Failed to publish alert via AMQP: #{inspect(e)}")
      end
    end
  end
  
  # AMQP Handlers
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle AMQP intelligence messages with causality tracking
    {message, causality_info} = CausalityAMQP.receive_message(payload, meta)
    
    if is_map(message) do
        Logger.info("🔍 Intelligence received AMQP message: #{message["type"]} (chain depth: #{causality_info.chain_depth})")
        
        new_state = process_intelligence_message(message, state)
        
        # Acknowledge the message
        if state[:amqp_channel] do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
    else
        Logger.error("Intelligence: Unexpected message format: #{inspect(message)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("🔍 Intelligence: AMQP consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("Intelligence: AMQP consumer cancelled")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("Intelligence: AMQP consumer cancel confirmed")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Intelligence: Retrying AMQP setup...")
    new_state = setup_amqp_intelligence(state)
    {:noreply, new_state}
  end
  
  defp process_intelligence_message(message, state) do
    case message["type"] do
      "environmental_scan_request" ->
        # Handle scan requests via AMQP
        scope = message["scope"] || :full
        spawn(fn ->
          result = GenServer.call(@name, {:scan_environment, scope})
          
          # Publish results back
          scan_result = %{
            type: "environmental_scan_result",
            request_id: message["request_id"],
            result: result,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
          
          GenServer.cast(@name, {:publish_environmental_alert, scan_result})
        end)
        state
        
      "tidewave_data" ->
        # Process Tidewave market intelligence
        insights = message["insights"]
        if insights do
          GenServer.cast(@name, {:tidewave_insights, insights})
        end
        state
        
      "adaptation_request" ->
        # Handle adaptation requests
        challenge = message["challenge"]
        if challenge do
          spawn(fn ->
            GenServer.call(@name, {:generate_adaptation, challenge})
          end)
        end
        state
        
      _ ->
        Logger.debug("Intelligence: Unknown intelligence message type: #{message["type"]}")
        state
    end
  end
  
  @impl true
  def handle_cast({:publish_environmental_alert, alert}, state) do
    publish_environmental_alert(alert, state)
    {:noreply, state}
  end
  
  # AGNOSTIC VSM Helper Functions
  
  defp detect_environmental_changes(scan_results, previous_data) do
    # Compare current scan with previous data to detect changes
    changes = []
    
    # Market changes
    current_market = Map.get(scan_results, :market_signals, [])
    previous_market = Map.get(previous_data, :market_trends, [])
    market_changes = detect_signal_changes(current_market, previous_market, "market")
    
    # Technology changes
    current_tech = Map.get(scan_results, :technology_trends, [])
    previous_tech = Map.get(previous_data, :technology_shifts, [])
    tech_changes = detect_trend_changes(current_tech, previous_tech, "technology")
    
    # Regulatory changes
    current_reg = Map.get(scan_results, :regulatory_updates, [])
    previous_reg = Map.get(previous_data, :regulatory_changes, [])
    reg_changes = detect_regulatory_changes(current_reg, previous_reg)
    
    # Competitive changes
    current_comp = Map.get(scan_results, :competitive_moves, [])
    previous_comp = Map.get(previous_data, :competitive_landscape, [])
    comp_changes = detect_competitive_changes(current_comp, previous_comp)
    
    (changes ++ market_changes ++ tech_changes ++ reg_changes ++ comp_changes)
    |> Enum.map(fn change ->
      Map.put(change, :timestamp, DateTime.utc_now())
    end)
  end
  
  defp detect_signal_changes(current, _previous, domain) do
    # For now, treat strong signals as changes
    current
    |> Enum.filter(fn signal -> Map.get(signal, :strength, 0) > 0.6 end)
    |> Enum.map(fn signal ->
      %{
        domain: domain,
        type: :signal_detected,
        signal: Map.get(signal, :signal),
        strength: Map.get(signal, :strength),
        source: Map.get(signal, :source)
      }
    end)
  end
  
  defp detect_trend_changes(current, _previous, domain) do
    # High impact trends are considered changes
    current
    |> Enum.filter(fn trend -> Map.get(trend, :impact) in [:high, :critical] end)
    |> Enum.map(fn trend ->
      %{
        domain: domain,
        type: :trend_detected,
        trend: Map.get(trend, :trend),
        impact: Map.get(trend, :impact),
        timeline: Map.get(trend, :timeline)
      }
    end)
  end
  
  defp detect_regulatory_changes(current, _previous) do
    # New or enacted regulations
    current
    |> Enum.filter(fn reg -> Map.get(reg, :status) in ["enacted", "proposed"] end)
    |> Enum.map(fn reg ->
      %{
        domain: "regulatory",
        type: :regulation_change,
        regulation: Map.get(reg, :regulation),
        status: Map.get(reg, :status),
        impact: Map.get(reg, :impact)
      }
    end)
  end
  
  defp detect_competitive_changes(current, _previous) do
    # High threat competitive moves
    current
    |> Enum.filter(fn move -> Map.get(move, :threat_level) in [:high, :critical] end)
    |> Enum.map(fn move ->
      %{
        domain: "competitive",
        type: :competitive_move,
        competitor: Map.get(move, :competitor),
        action: Map.get(move, :action),
        threat_level: Map.get(move, :threat_level)
      }
    end)
  end
  
  defp match_patterns(scan_results, pattern_library) do
    # Match scan results against known patterns
    # For now, use simple pattern matching
    detected_patterns = []
    
    # Market volatility pattern
    market_signals = Map.get(scan_results, :market_signals, [])
    if detect_volatility_pattern(market_signals) do
      detected_patterns = [%{
        pattern_type: :market_volatility,
        confidence: 0.8,
        indicators: Enum.take(market_signals, 3),
        timestamp: DateTime.utc_now()
      } | detected_patterns]
    end
    
    # Technology disruption pattern
    tech_trends = Map.get(scan_results, :technology_trends, [])
    if detect_disruption_pattern(tech_trends) do
      detected_patterns = [%{
        pattern_type: :tech_disruption,
        confidence: 0.7,
        indicators: Enum.take(tech_trends, 2),
        timestamp: DateTime.utc_now()
      } | detected_patterns]
    end
    
    # Regulatory pressure pattern
    reg_updates = Map.get(scan_results, :regulatory_updates, [])
    if length(reg_updates) > 2 do
      detected_patterns = [%{
        pattern_type: :regulatory_pressure,
        confidence: 0.9,
        indicators: reg_updates,
        timestamp: DateTime.utc_now()
      } | detected_patterns]
    end
    
    detected_patterns
  end
  
  defp detect_volatility_pattern(signals) do
    # High variance in signal strengths indicates volatility
    strengths = signals |> Enum.map(fn s -> Map.get(s, :strength, 0) end)
    if length(strengths) > 2 do
      variance = calculate_variance(strengths)
      variance > 0.2
    else
      false
    end
  end
  
  defp detect_disruption_pattern(trends) do
    # Multiple high-impact trends indicate disruption
    high_impact_count = trends
    |> Enum.count(fn t -> Map.get(t, :impact) in [:high, :critical] end)
    
    high_impact_count >= 2
  end
  
  defp calculate_variance(values) when length(values) > 0 do
    mean = Enum.sum(values) / length(values)
    variance = values
    |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    variance
  end
  defp calculate_variance(_), do: 0
  
  defp calculate_anomaly_score(scan_results, pattern_baseline) do
    # Calculate deviation from normal patterns
    scores = []
    
    # Market anomaly
    market_signals = Map.get(scan_results, :market_signals, [])
    market_score = calculate_market_anomaly(market_signals, pattern_baseline.normal_variance)
    scores = [market_score | scores]
    
    # Technology anomaly
    tech_trends = Map.get(scan_results, :technology_trends, [])
    tech_score = calculate_tech_anomaly(tech_trends)
    scores = [tech_score | scores]
    
    # Regulatory anomaly
    reg_count = length(Map.get(scan_results, :regulatory_updates, []))
    reg_score = min(reg_count * 0.2, 1.0)
    scores = [reg_score | scores]
    
    # Competitive anomaly
    comp_moves = Map.get(scan_results, :competitive_moves, [])
    comp_score = calculate_competitive_anomaly(comp_moves)
    scores = [comp_score | scores]
    
    # Average anomaly score
    if length(scores) > 0 do
      Enum.sum(scores) / length(scores)
    else
      0.0
    end
  end
  
  defp calculate_market_anomaly(signals, normal_variance) do
    if length(signals) > 0 do
      strengths = Enum.map(signals, fn s -> Map.get(s, :strength, 0) end)
      variance = calculate_variance(strengths)
      min(variance / (normal_variance + 0.1), 1.0)
    else
      0.0
    end
  end
  
  defp calculate_tech_anomaly(trends) do
    # Unusual number of high-impact trends
    high_impact = Enum.count(trends, fn t -> Map.get(t, :impact) in [:high, :critical] end)
    min(high_impact * 0.3, 1.0)
  end
  
  defp calculate_competitive_anomaly(moves) do
    # High threat moves are anomalous
    high_threat = Enum.count(moves, fn m -> Map.get(m, :threat_level) in [:high, :critical] end)
    min(high_threat * 0.4, 1.0)
  end
  
  defp calculate_scan_coverage_percentage(scan_results, coverage_targets) do
    # Calculate what percentage of target areas were scanned
    covered = []
    
    # Market coverage
    if Map.has_key?(scan_results, :market_signals) && length(scan_results.market_signals) > 0 do
      covered = [:market | covered]
    end
    
    # Technology coverage
    if Map.has_key?(scan_results, :technology_trends) && length(scan_results.technology_trends) > 0 do
      covered = [:technology | covered]
    end
    
    # Regulatory coverage
    if Map.has_key?(scan_results, :regulatory_updates) do
      covered = [:regulatory | covered]
    end
    
    # Competitive coverage
    if Map.has_key?(scan_results, :competitive_moves) do
      covered = [:competitive | covered]
    end
    
    # Calculate percentage
    target_count = map_size(coverage_targets)
    if target_count > 0 do
      (length(covered) / target_count) * 100
    else
      0.0
    end
  end
  
  defp calculate_anomaly_trend(history) do
    # Analyze recent anomaly scores for trend
    recent = Enum.take(history, 10)
    
    if length(recent) >= 3 do
      recent_scores = Enum.map(recent, fn {_time, score} -> score end)
      first_half = Enum.take(recent_scores, div(length(recent_scores), 2))
      second_half = Enum.drop(recent_scores, div(length(recent_scores), 2))
      
      avg_first = Enum.sum(first_half) / length(first_half)
      avg_second = Enum.sum(second_half) / length(second_half)
      
      cond do
        avg_second > avg_first * 1.2 -> :increasing
        avg_second < avg_first * 0.8 -> :decreasing
        true -> :stable
      end
    else
      :insufficient_data
    end
  end
  
  defp calculate_pattern_frequency(pattern_matches) do
    # Calculate how frequently patterns are detected
    if length(pattern_matches) > 0 do
      # Group by pattern type
      grouped = Enum.group_by(pattern_matches, fn p -> p.pattern_type end)
      
      Enum.map(grouped, fn {pattern_type, matches} ->
        {pattern_type, length(matches)}
      end)
      |> Map.new()
    else
      %{}
    end
  end
  
  defp calculate_adaptation_rate(triggers) do
    # Calculate adaptations per time period
    if length(triggers) > 0 do
      # Get time span
      sorted = Enum.sort_by(triggers, fn t -> t.timestamp end)
      oldest = List.first(sorted)
      newest = List.last(sorted)
      
      time_span_hours = DateTime.diff(newest.timestamp, oldest.timestamp) / 3600
      
      if time_span_hours > 0 do
        length(triggers) / time_span_hours
      else
        0.0
      end
    else
      0.0
    end
  end
end