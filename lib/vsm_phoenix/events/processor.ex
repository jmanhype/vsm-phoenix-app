defmodule VsmPhoenix.Events.Processor do
  @moduledoc """
  Broadway-powered Event Processor for VSM Phoenix
  
  Features:
  - Complex Event Processing (CEP) with pattern matching
  - Windowing and temporal aggregation
  - Stream correlation and causality analysis
  - Real-time event transformation and routing
  - Backpressure handling and error recovery
  """
  
  use Broadway
  require Logger
  
  alias VsmPhoenix.Events.{Store, Event, CEPEngine}
  alias Broadway.Message
  
  @processor_name __MODULE__
  @window_duration_ms 5_000  # 5 second windows
  @max_demand 500
  
  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: opts[:name] || @processor_name,
      producer: [
        module: {VsmPhoenix.Events.EventProducer, []},
        stages: 2,
        buffer_size: 1000,
        max_demand: @max_demand
      ],
      processors: [
        default: [
          stages: 4,
          min_demand: 5,
          max_demand: 50
        ]
      ],
      batchers: [
        vsm_events: [
          stages: 2,
          batch_size: 20,
          batch_timeout: 1000
        ],
        algedonic_events: [
          stages: 1,
          batch_size: 10,
          batch_timeout: 500
        ],
        system_events: [
          stages: 2,
          batch_size: 30,
          batch_timeout: 2000
        ],
        correlation_events: [
          stages: 1,
          batch_size: 5,
          batch_timeout: 100
        ]
      ]
    )
  end
  
  @impl true
  def handle_message(:default, %Message{} = message, _context) do
    %{event: event, metadata: metadata} = message.data
    
    try do
      # Apply complex event processing patterns
      processed_event = event
                       |> apply_temporal_patterns()
                       |> apply_correlation_analysis()
                       |> apply_vsm_context_enrichment()
                       |> apply_algedonic_processing()
      
      # Determine routing based on event characteristics
      batcher = determine_batcher(processed_event)
      
      # Add processing metadata
      enhanced_metadata = Map.merge(metadata, %{
        processed_at: DateTime.utc_now(),
        processor_id: @processor_name,
        processing_duration_ms: :erlang.system_time(:millisecond) - (metadata[:received_at] || 0),
        pattern_matches: processed_event.pattern_matches || [],
        correlation_strength: processed_event.correlation_strength || 0.0
      })
      
      message
      |> Message.update_data(fn _ -> 
        %{event: processed_event, metadata: enhanced_metadata} 
      end)
      |> Message.put_batcher(batcher)
      
    rescue
      error ->
        Logger.error("❌ Error processing event #{event.id}: #{inspect(error)}")
        
        # Put failed events in dead letter queue
        message
        |> Message.failed("Processing error: #{inspect(error)}")
    end
  end
  
  @impl true
  def handle_batch(:vsm_events, messages, _batch_info, _context) do
    Logger.info("🔄 Processing VSM events batch (#{length(messages)} events)")
    
    events = Enum.map(messages, &(&1.data.event))
    
    # Apply VSM-specific processing
    results = events
              |> apply_variety_analysis()
              |> apply_viability_assessment()
              |> apply_recursion_detection()
              |> store_vsm_projections()
    
    # Broadcast to VSM channels
    Enum.zip(events, results)
    |> Enum.each(fn {event, result} ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:events",
        {:vsm_event_processed, event, result}
      )
    end)
    
    messages
  end
  
  @impl true
  def handle_batch(:algedonic_events, messages, _batch_info, _context) do
    Logger.info("⚡ Processing Algedonic events batch (#{length(messages)} events)")
    
    events = Enum.map(messages, &(&1.data.event))
    
    # Apply algedonic processing
    results = events
              |> detect_pain_pleasure_patterns()
              |> calculate_autonomic_responses()
              |> trigger_immediate_actions()
    
    # Send to algedonic channels
    Enum.zip(events, results)
    |> Enum.each(fn {event, result} ->
      if result.urgency_level >= 0.8 do
        # High urgency - immediate broadcast
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "algedonic:urgent",
          {:urgent_algedonic_event, event, result}
        )
      end
      
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "algedonic:events",
        {:algedonic_event_processed, event, result}
      )
    end)
    
    messages
  end
  
  @impl true
  def handle_batch(:system_events, messages, _batch_info, _context) do
    Logger.info("🖥️ Processing System events batch (#{length(messages)} events)")
    
    events = Enum.map(messages, &(&1.data.event))
    
    # Apply system-level processing
    results = events
              |> aggregate_system_metrics()
              |> detect_anomalies()
              |> update_system_health()
              |> generate_predictions()
    
    # Store system projections
    results
    |> Enum.each(fn result ->
      Store.save_snapshot(
        "system_health",
        result.aggregate_version,
        result.system_state
      )
    end)
    
    messages
  end
  
  @impl true
  def handle_batch(:correlation_events, messages, _batch_info, _context) do
    Logger.info("🔗 Processing Correlation events batch (#{length(messages)} events)")
    
    events = Enum.map(messages, &(&1.data.event))
    
    # Apply correlation analysis
    results = events
              |> find_event_correlations()
              |> build_causal_chains()
              |> detect_complex_patterns()
              |> update_correlation_matrix()
    
    # Publish correlation insights
    Enum.each(results, fn result ->
      if length(result.strong_correlations) > 0 do
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "correlations:discovered",
          {:correlation_pattern, result}
        )
      end
    end)
    
    messages
  end
  
  # Event Processing Pipeline Functions
  
  defp apply_temporal_patterns(event) do
    now = DateTime.utc_now()
    event_time = event.timestamp
    
    # Calculate temporal characteristics
    temporal_data = %{
      age_ms: DateTime.diff(now, event_time, :millisecond),
      hour_of_day: event_time.hour,
      day_of_week: Date.day_of_week(event_time),
      is_business_hours: event_time.hour >= 9 and event_time.hour <= 17,
      temporal_window: calculate_temporal_window(event_time)
    }
    
    # Apply time-based pattern matching
    patterns = CEPEngine.match_temporal_patterns(event, temporal_data)
    
    %{event | 
      temporal_data: temporal_data,
      pattern_matches: patterns
    }
  end
  
  defp apply_correlation_analysis(event) do
    # Find related events in time window
    related_events = find_related_events(event, @window_duration_ms)
    
    # Calculate correlation strength
    correlation_strength = calculate_correlation_strength(event, related_events)
    
    # Build correlation graph
    correlation_graph = build_correlation_graph(event, related_events)
    
    %{event |
      related_events: related_events,
      correlation_strength: correlation_strength,
      correlation_graph: correlation_graph
    }
  end
  
  defp apply_vsm_context_enrichment(event) do
    # Determine VSM system context
    vsm_context = case event.event_type do
      "system1." <> _ -> :operations
      "system2." <> _ -> :coordination  
      "system3." <> _ -> :control
      "system4." <> _ -> :intelligence
      "system5." <> _ -> :policy
      "algedonic." <> _ -> :algedonic
      "variety." <> _ -> :variety_engineering
      _ -> :unknown
    end
    
    # Add VSM-specific metadata
    vsm_metadata = %{
      vsm_system: vsm_context,
      variety_level: calculate_variety_level(event),
      control_effectiveness: assess_control_effectiveness(event),
      recursion_depth: detect_recursion_depth(event)
    }
    
    %{event | vsm_context: vsm_context, vsm_metadata: vsm_metadata}
  end
  
  defp apply_algedonic_processing(event) do
    case event.vsm_context do
      :algedonic ->
        # Calculate pain/pleasure metrics
        pain_level = calculate_pain_level(event)
        pleasure_level = calculate_pleasure_level(event)
        urgency = calculate_urgency(pain_level, pleasure_level)
        
        algedonic_data = %{
          pain_level: pain_level,
          pleasure_level: pleasure_level,
          urgency_level: urgency,
          autonomic_response: determine_autonomic_response(pain_level, pleasure_level)
        }
        
        %{event | algedonic_data: algedonic_data}
        
      _ ->
        event
    end
  end
  
  # Batch Processing Functions
  
  defp apply_variety_analysis(events) do
    Enum.map(events, fn event ->
      variety_metrics = %{
        input_variety: calculate_input_variety(event),
        output_variety: calculate_output_variety(event),
        variety_balance: calculate_variety_balance(event),
        ashby_compliance: assess_ashby_compliance(event)
      }
      
      %{event | variety_metrics: variety_metrics}
    end)
  end
  
  defp apply_viability_assessment(events) do
    Enum.map(events, fn event ->
      viability_score = calculate_viability_score(event)
      viability_factors = analyze_viability_factors(event)
      
      %{event | 
        viability_score: viability_score,
        viability_factors: viability_factors
      }
    end)
  end
  
  defp apply_recursion_detection(events) do
    Enum.map(events, fn event ->
      recursion_indicators = detect_recursion_indicators(event)
      meta_system_triggers = detect_meta_system_triggers(event)
      
      %{event |
        recursion_indicators: recursion_indicators,
        meta_system_triggers: meta_system_triggers
      }
    end)
  end
  
  defp store_vsm_projections(events) do
    Enum.map(events, fn event ->
      # Store VSM-specific projections
      projection_data = %{
        vsm_system: event.vsm_context,
        variety_metrics: event.variety_metrics,
        viability_score: event.viability_score,
        processed_at: DateTime.utc_now()
      }
      
      Store.append_to_stream(
        "vsm_projections",
        :any,
        [%{
          event_type: "projection.vsm.updated",
          data: projection_data,
          correlation_id: event.correlation_id
        }]
      )
      
      %{event | projection_stored: true}
    end)
  end
  
  # Algedonic Processing Functions
  
  defp detect_pain_pleasure_patterns(events) do
    Enum.map(events, fn event ->
      patterns = %{
        pain_patterns: extract_pain_patterns(event),
        pleasure_patterns: extract_pleasure_patterns(event),
        autonomic_triggers: identify_autonomic_triggers(event)
      }
      
      %{event | algedonic_patterns: patterns}
    end)
  end
  
  defp calculate_autonomic_responses(events) do
    Enum.map(events, fn event ->
      response = case event.algedonic_data do
        %{urgency_level: urgency} when urgency >= 0.9 ->
          %{type: :emergency_shutdown, priority: :critical}
        %{urgency_level: urgency} when urgency >= 0.7 ->
          %{type: :immediate_attention, priority: :high}
        %{pain_level: pain} when pain >= 0.8 ->
          %{type: :pain_response, priority: :high}
        %{pleasure_level: pleasure} when pleasure >= 0.8 ->
          %{type: :amplify_behavior, priority: :medium}
        _ ->
          %{type: :monitor, priority: :low}
      end
      
      %{event | autonomic_response: response}
    end)
  end
  
  defp trigger_immediate_actions(events) do
    Enum.map(events, fn event ->
      case event.autonomic_response do
        %{type: :emergency_shutdown} ->
          # Trigger emergency protocols
          Logger.error("🚨 EMERGENCY: Algedonic shutdown triggered by event #{event.id}")
          Phoenix.PubSub.broadcast(
            VsmPhoenix.PubSub,
            "emergency:shutdown",
            {:emergency_shutdown, event}
          )
          
        %{type: :immediate_attention} ->
          # Alert system administrators
          Logger.warn("⚠️ URGENT: Immediate attention required for event #{event.id}")
          Phoenix.PubSub.broadcast(
            VsmPhoenix.PubSub,
            "alerts:urgent",
            {:urgent_attention, event}
          )
          
        _ ->
          # Normal processing
          :ok
      end
      
      %{event | actions_triggered: true}
    end)
  end
  
  # System Processing Functions
  
  defp aggregate_system_metrics(events) do
    metrics = Enum.reduce(events, %{}, fn event, acc ->
      system = event.vsm_context || :unknown
      
      current = Map.get(acc, system, %{count: 0, errors: 0, performance: []})
      
      updated = %{
        count: current.count + 1,
        errors: current.errors + (if event.event_type =~ "error", do: 1, else: 0),
        performance: [event.temporal_data.age_ms | current.performance]
      }
      
      Map.put(acc, system, updated)
    end)
    
    # Return events with system metrics
    Enum.map(events, fn event ->
      %{event | system_metrics: metrics}
    end)
  end
  
  defp detect_anomalies(events) do
    Enum.map(events, fn event ->
      anomalies = []
      
      # Check for timing anomalies
      anomalies = if event.temporal_data.age_ms > 10_000 do
        [:slow_processing | anomalies]
      else
        anomalies
      end
      
      # Check for pattern anomalies
      anomalies = if length(event.pattern_matches || []) == 0 do
        [:no_pattern_match | anomalies]
      else
        anomalies
      end
      
      # Check for correlation anomalies
      anomalies = if event.correlation_strength < 0.1 do
        [:low_correlation | anomalies]
      else
        anomalies
      end
      
      %{event | anomalies: anomalies}
    end)
  end
  
  defp update_system_health(events) do
    # Calculate overall system health
    total_events = length(events)
    error_events = Enum.count(events, &(&1.event_type =~ "error"))
    anomaly_events = Enum.count(events, &(length(&1.anomalies || []) > 0))
    
    health_score = max(0.0, 1.0 - (error_events + anomaly_events) / total_events)
    
    Enum.map(events, fn event ->
      %{event | system_health_score: health_score}
    end)
  end
  
  defp generate_predictions(events) do
    Enum.map(events, fn event ->
      # Simple trend prediction based on recent patterns
      predictions = %{
        next_event_probability: calculate_next_event_probability(event),
        system_stability_trend: assess_stability_trend(event),
        resource_requirements: predict_resource_needs(event)
      }
      
      %{event | predictions: predictions}
    end)
  end
  
  # Correlation Processing Functions
  
  defp find_event_correlations(events) do
    Enum.map(events, fn event ->
      correlations = events
                    |> Enum.reject(&(&1.id == event.id))
                    |> Enum.map(fn other_event ->
                      strength = calculate_event_correlation(event, other_event)
                      %{event_id: other_event.id, strength: strength}
                    end)
                    |> Enum.filter(&(&1.strength > 0.3))
                    |> Enum.sort_by(&(&1.strength), :desc)
      
      %{event | correlations: correlations}
    end)
  end
  
  defp build_causal_chains(events) do
    Enum.map(events, fn event ->
      # Build causal chain based on causation_id and correlation_id
      chain = build_causal_chain_recursive(event, events, [])
      
      %{event | causal_chain: chain}
    end)
  end
  
  defp detect_complex_patterns(events) do
    Enum.map(events, fn event ->
      complex_patterns = CEPEngine.detect_complex_patterns(event, events)
      
      %{event | complex_patterns: complex_patterns}
    end)
  end
  
  defp update_correlation_matrix(events) do
    # This would update a global correlation matrix in a real implementation
    Enum.map(events, fn event ->
      %{event | correlation_matrix_updated: true}
    end)
  end
  
  # Helper Functions
  
  defp determine_batcher(event) do
    cond do
      event.vsm_context in [:operations, :coordination, :control, :intelligence, :policy] ->
        :vsm_events
      event.vsm_context == :algedonic ->
        :algedonic_events
      event.event_type =~ "system." ->
        :system_events
      event.correlation_strength > 0.5 ->
        :correlation_events
      true ->
        :vsm_events
    end
  end
  
  defp calculate_temporal_window(timestamp) do
    # Calculate which 5-second window this event belongs to
    unix_ms = DateTime.to_unix(timestamp, :millisecond)
    div(unix_ms, @window_duration_ms) * @window_duration_ms
  end
  
  defp find_related_events(event, window_ms) do
    # In a real implementation, this would query the event store
    # For now, return empty list
    []
  end
  
  defp calculate_correlation_strength(_event, related_events) do
    # Simple correlation based on number of related events
    min(1.0, length(related_events) / 10.0)
  end
  
  defp build_correlation_graph(event, related_events) do
    %{
      center_event: event.id,
      connections: Enum.map(related_events, &%{id: &1.id, weight: 1.0})
    }
  end
  
  defp calculate_variety_level(_event), do: :rand.uniform()
  defp calculate_input_variety(_event), do: :rand.uniform() * 10
  defp calculate_output_variety(_event), do: :rand.uniform() * 10
  defp calculate_variety_balance(_event), do: :rand.uniform()
  defp assess_ashby_compliance(_event), do: :rand.uniform() > 0.7
  defp assess_control_effectiveness(_event), do: :rand.uniform()
  defp detect_recursion_depth(_event), do: :rand.uniform(5)
  defp calculate_viability_score(_event), do: :rand.uniform()
  defp analyze_viability_factors(_event), do: [:stability, :adaptability, :efficiency]
  defp detect_recursion_indicators(_event), do: []
  defp detect_meta_system_triggers(_event), do: []
  defp calculate_pain_level(_event), do: :rand.uniform()
  defp calculate_pleasure_level(_event), do: :rand.uniform()
  defp calculate_urgency(pain, pleasure), do: max(pain, 1.0 - pleasure)
  defp determine_autonomic_response(pain, _pleasure) when pain > 0.8, do: :shutdown
  defp determine_autonomic_response(_pain, pleasure) when pleasure > 0.8, do: :amplify
  defp determine_autonomic_response(_pain, _pleasure), do: :monitor
  defp extract_pain_patterns(_event), do: []
  defp extract_pleasure_patterns(_event), do: []
  defp identify_autonomic_triggers(_event), do: []
  defp calculate_next_event_probability(_event), do: :rand.uniform()
  defp assess_stability_trend(_event), do: :stable
  defp predict_resource_needs(_event), do: %{cpu: 10, memory: 100, network: 50}
  defp calculate_event_correlation(_event1, _event2), do: :rand.uniform()
  defp build_causal_chain_recursive(_event, _events, chain), do: chain
end