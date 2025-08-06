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
      learning_data: [],
      amqp_channel: nil
    }
    
    # Initialize Tidewave connection
    {:ok, tidewave} = init_tidewave_connection()
    
    # Set up AMQP for environmental alerts
    state = setup_amqp_intelligence(state)
    
    # Schedule periodic environmental scanning
    schedule_environmental_scan()
    
    {:ok, %{state | tidewave_connection: tidewave}}
  end
  
  @impl true
  def handle_call({:scan_environment, scope}, _from, state) do
    Logger.info("Intelligence: Scanning environment - scope: #{scope}")
    
    scan_results = perform_environmental_scan(scope, state.tidewave_connection)
    
    new_environmental_data = update_environmental_data(state.environmental_data, scan_results)
    new_state = %{state | environmental_data: new_environmental_data}
    
    # Analyze for potential threats or opportunities
    insights = analyze_scan_results(scan_results)
    
    # NEW: Detect anomalies and report to S5 for policy synthesis
    anomalies = detect_anomalies(scan_results)
    Enum.each(anomalies, fn anomaly ->
      Logger.warning("🚨 S4: Anomaly detected: #{inspect(anomaly.type)}")
      # Report to Queen for LLM-based policy synthesis
      GenServer.cast(VsmPhoenix.System5.Queen, {:anomaly_detected, anomaly})
    end)
    
    if insights.requires_adaptation do
      # Generate adaptation proposal internally without recursive call
      proposal = generate_internal_adaptation_proposal(insights.challenge, state)
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
    health = %{
      health: calculate_overall_health(state),
      scan_coverage: state.intelligence_metrics.scan_coverage,
      adaptation_readiness: calculate_adaptation_readiness(state),
      innovation_capacity: state.intelligence_metrics.innovation_index
    }
    
    {:reply, health, state}
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
    # Direct scan instead of self-call
    case handle_call({:scan_environment, :scheduled}, nil, state) do
      {:reply, _result, new_state} ->
        Logger.debug("Scheduled scan completed")
        schedule_environmental_scan()
        {:noreply, new_state}
      _ ->
        Logger.warning("Scheduled scan failed")
        schedule_environmental_scan()
        {:noreply, state}
    end
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
    active_adaptations = length(state.current_adaptations)
    if active_adaptations > 3, do: 0.5, else: 0.9
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
        [%{
          type: :variety_explosion,
          severity: min(pattern_count / 10, 1.0),
          description: "LLM detected #{pattern_count} novel patterns exceeding current capacity",
          data: scan_data.llm_variety,
          timestamp: DateTime.utc_now(),
          recommended_action: :spawn_meta_vsm
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
        [%{
          type: :market_anomaly,
          severity: Enum.max_by(unusual_signals, & &1.strength).strength,
          description: "Unusual market signals detected: #{length(unusual_signals)} high-strength signals",
          data: unusual_signals,
          timestamp: DateTime.utc_now(),
          recommended_action: :policy_adaptation
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
        [%{
          type: :technology_disruption,
          severity: 0.8,
          description: "High-impact technology trends detected: #{Enum.map(high_impact_tech, & &1.trend) |> Enum.join(", ")}",
          data: high_impact_tech,
          timestamp: DateTime.utc_now(),
          recommended_action: :strategic_pivot
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
        [%{
          type: :regulatory_anomaly,
          severity: 0.9,
          description: "Critical regulatory changes detected",
          data: critical_regs,
          timestamp: DateTime.utc_now(),
          recommended_action: :compliance_update
        } | anomalies]
      else
        anomalies
      end
    else
      anomalies
    end
    
    anomalies
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
    if state[:amqp_channel] do
      try do
        payload = Jason.encode!(alert)
        
        :ok = AMQP.Basic.publish(
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
    # Handle AMQP intelligence messages
    case Jason.decode(payload) do
      {:ok, message} ->
        Logger.info("🔍 Intelligence received AMQP message: #{message["type"]}")
        
        new_state = process_intelligence_message(message, state)
        
        # Acknowledge the message
        if state[:amqp_channel] do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
      {:error, _} ->
        Logger.error("Intelligence: Failed to decode AMQP message")
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
end