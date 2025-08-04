defmodule VsmPhoenix.Events.Analytics do
  @moduledoc """
  Event Analytics Engine
  
  Features:
  - Event metrics and statistics
  - Performance monitoring
  - Throughput analysis
  - Latency measurements
  - Real-time dashboards
  - Predictive analytics
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @metrics_window_ms 60_000  # 1 minute window
  @retention_hours 24
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Record that an event was processed
  """
  def record_event_processed(event, start_time) do
    GenServer.cast(@name, {:event_processed, event, start_time})
  end
  
  @doc """
  Process a batch of events for analytics
  """
  def process_batch(events) do
    GenServer.cast(@name, {:process_batch, events})
  end
  
  @doc """
  Update system metrics
  """
  def update_metrics(event) do
    GenServer.cast(@name, {:update_metrics, event})
  end
  
  @doc """
  Record pattern match
  """
  def record_pattern_match(match) do
    GenServer.cast(@name, {:pattern_match, match})
  end
  
  @doc """
  Get current analytics dashboard data
  """
  def get_dashboard_data do
    GenServer.call(@name, :get_dashboard_data)
  end
  
  @doc """
  Get event throughput statistics
  """
  def get_throughput_stats do
    GenServer.call(@name, :get_throughput_stats)
  end
  
  @doc """
  Get latency statistics
  """
  def get_latency_stats do
    GenServer.call(@name, :get_latency_stats)
  end
  
  @doc """
  Get event type distribution
  """
  def get_event_distribution do
    GenServer.call(@name, :get_event_distribution)
  end
  
  @doc """
  Get predictive insights
  """
  def get_predictive_insights do
    GenServer.call(@name, :get_predictive_insights)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("📊 Starting Event Analytics Engine")
    
    state = %{
      # Event processing metrics
      events_processed: 0,
      total_latency_ms: 0,
      min_latency_ms: nil,
      max_latency_ms: 0,
      
      # Throughput tracking
      throughput_history: [],
      current_minute_events: 0,
      last_minute_timestamp: current_minute(),
      
      # Event type distribution
      event_type_counts: %{},
      stream_counts: %{},
      
      # Pattern matching metrics
      patterns_detected: 0,
      pattern_types: %{},
      
      # System health metrics
      system_metrics: %{
        system1: %{operations: 0, errors: 0, avg_latency: 0},
        system2: %{coordinations: 0, failures: 0, avg_latency: 0},
        system3: %{controls: 0, overrides: 0, avg_latency: 0},
        system4: %{analyses: 0, timeouts: 0, avg_latency: 0},
        system5: %{policies: 0, violations: 0, avg_latency: 0}
      },
      
      # Algedonic metrics
      algedonic_metrics: %{
        total_pain_events: 0,
        total_pleasure_events: 0,
        avg_pain_level: 0.0,
        avg_pleasure_level: 0.0,
        autonomic_responses: 0
      },
      
      # Performance insights
      performance_trends: [],
      anomalies_detected: [],
      
      # Real-time dashboard cache
      dashboard_cache: %{},
      cache_updated_at: nil
    }
    
    # Update metrics every minute
    :timer.send_interval(60_000, :update_minute_metrics)
    
    # Generate insights every 5 minutes
    :timer.send_interval(300_000, :generate_insights)
    
    # Clean old data every hour
    :timer.send_interval(3_600_000, :cleanup_old_data)
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:event_processed, event, start_time}, state) do
    processing_time = :erlang.system_time(:millisecond) - start_time
    
    # Update processing metrics
    new_state = state
    |> update_processing_metrics(processing_time)
    |> update_event_distribution(event)
    |> update_system_metrics(event, processing_time)
    |> increment_throughput_counter()
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:process_batch, events}, state) do
    Logger.debug("📊 Processing analytics batch: #{length(events)} events")
    
    # Process each event for analytics
    new_state = Enum.reduce(events, state, fn event, acc_state ->
      acc_state
      |> update_event_distribution(event)
      |> update_system_metrics(event, 0)  # Batch processing, no individual latency
    end)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:update_metrics, event}, state) do
    new_state = update_system_metrics(state, event, 0)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:pattern_match, match}, state) do
    Logger.debug("📊 Recording pattern match: #{match.pattern_name}")
    
    # Update pattern metrics
    new_patterns_detected = state.patterns_detected + 1
    new_pattern_types = Map.update(state.pattern_types, match.pattern_name, 1, &(&1 + 1))
    
    new_state = %{state |
      patterns_detected: new_patterns_detected,
      pattern_types: new_pattern_types
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_dashboard_data, _from, state) do
    # Return cached dashboard data or generate fresh
    dashboard_data = get_or_generate_dashboard_data(state)
    {:reply, dashboard_data, state}
  end
  
  @impl true
  def handle_call(:get_throughput_stats, _from, state) do
    throughput_stats = %{
      current_events_per_minute: state.current_minute_events,
      throughput_history: Enum.take(state.throughput_history, -60),  # Last hour
      peak_throughput: Enum.max(state.throughput_history ++ [0]),
      average_throughput: calculate_average_throughput(state.throughput_history)
    }
    
    {:reply, throughput_stats, state}
  end
  
  @impl true
  def handle_call(:get_latency_stats, _from, state) do
    avg_latency = if state.events_processed > 0 do
      state.total_latency_ms / state.events_processed
    else
      0
    end
    
    latency_stats = %{
      average_latency_ms: avg_latency,
      min_latency_ms: state.min_latency_ms,
      max_latency_ms: state.max_latency_ms,
      total_events_processed: state.events_processed
    }
    
    {:reply, latency_stats, state}
  end
  
  @impl true
  def handle_call(:get_event_distribution, _from, state) do
    total_events = Enum.sum(Map.values(state.event_type_counts))
    
    distribution = %{
      event_types: state.event_type_counts,
      stream_distribution: state.stream_counts,
      total_events: total_events,
      unique_event_types: map_size(state.event_type_counts),
      unique_streams: map_size(state.stream_counts)
    }
    
    {:reply, distribution, state}
  end
  
  @impl true
  def handle_call(:get_predictive_insights, _from, state) do
    insights = generate_predictive_insights(state)
    {:reply, insights, state}
  end
  
  @impl true
  def handle_info(:update_minute_metrics, state) do
    current_minute = current_minute()
    
    # Add current minute's events to history
    new_throughput_history = state.throughput_history ++ [state.current_minute_events]
    
    # Keep only last 24 hours of data
    trimmed_history = Enum.take(new_throughput_history, -(@retention_hours * 60))
    
    # Reset current minute counter
    new_state = %{state |
      throughput_history: trimmed_history,
      current_minute_events: 0,
      last_minute_timestamp: current_minute
    }
    
    # Broadcast throughput update
    Phoenix.PubSub.broadcast!(
      VsmPhoenix.PubSub,
      "analytics:throughput",
      {:throughput_update, state.current_minute_events}
    )
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:generate_insights, state) do
    Logger.info("🔮 Generating predictive insights")
    
    # Generate performance trends
    trends = analyze_performance_trends(state)
    
    # Detect anomalies
    anomalies = detect_anomalies(state)
    
    # Update insights
    new_state = %{state |
      performance_trends: trends,
      anomalies_detected: anomalies
    }
    
    # Broadcast insights
    Phoenix.PubSub.broadcast!(
      VsmPhoenix.PubSub,
      "analytics:insights",
      {:insights_generated, %{trends: trends, anomalies: anomalies}}
    )
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:cleanup_old_data, state) do
    Logger.info("🧹 Cleaning old analytics data")
    
    # Keep only recent performance trends
    recent_trends = Enum.take(state.performance_trends, -100)
    
    # Keep only recent anomalies
    recent_anomalies = Enum.take(state.anomalies_detected, -50)
    
    # Clear dashboard cache to force refresh
    new_state = %{state |
      performance_trends: recent_trends,
      anomalies_detected: recent_anomalies,
      dashboard_cache: %{},
      cache_updated_at: nil
    }
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp update_processing_metrics(state, processing_time) do
    new_events_processed = state.events_processed + 1
    new_total_latency = state.total_latency_ms + processing_time
    
    new_min_latency = case state.min_latency_ms do
      nil -> processing_time
      current_min -> min(current_min, processing_time)
    end
    
    new_max_latency = max(state.max_latency_ms, processing_time)
    
    %{state |
      events_processed: new_events_processed,
      total_latency_ms: new_total_latency,
      min_latency_ms: new_min_latency,
      max_latency_ms: new_max_latency
    }
  end
  
  defp update_event_distribution(state, event) do
    # Update event type counts
    new_event_types = Map.update(state.event_type_counts, event.event_type, 1, &(&1 + 1))
    
    # Update stream counts
    new_stream_counts = Map.update(state.stream_counts, event.stream_id, 1, &(&1 + 1))
    
    %{state |
      event_type_counts: new_event_types,
      stream_counts: new_stream_counts
    }
  end
  
  defp update_system_metrics(state, event, processing_time) do
    case categorize_event(event.event_type) do
      {:system, system_num} ->
        update_specific_system_metrics(state, system_num, event, processing_time)
      
      :algedonic ->
        update_algedonic_metrics(state, event)
      
      _ ->
        state
    end
  end
  
  defp categorize_event(event_type) do
    cond do
      String.starts_with?(event_type, "system1.") -> {:system, :system1}
      String.starts_with?(event_type, "system2.") -> {:system, :system2}
      String.starts_with?(event_type, "system3.") -> {:system, :system3}
      String.starts_with?(event_type, "system4.") -> {:system, :system4}
      String.starts_with?(event_type, "system5.") -> {:system, :system5}
      String.starts_with?(event_type, "algedonic.") -> :algedonic
      true -> :other
    end
  end
  
  defp update_specific_system_metrics(state, system_key, event, processing_time) do
    current_metrics = get_in(state, [:system_metrics, system_key])
    
    updated_metrics = 
      if String.contains?(event.event_type, ".error") or String.contains?(event.event_type, ".failed") do
        %{current_metrics | errors: current_metrics.errors + 1}
      else
        if String.contains?(event.event_type, ".timeout") do
          %{current_metrics | errors: current_metrics.errors + 1}
        else
            if String.contains?(event.event_type, ".override") do
              %{current_metrics | overrides: current_metrics.overrides + 1}
            else
              if String.contains?(event.event_type, ".violation") do
                %{current_metrics | violations: current_metrics.violations + 1}
              else
                # Update operation counts based on system
                case system_key do
                  :system1 -> %{current_metrics | operations: current_metrics.operations + 1}
                  :system2 -> %{current_metrics | coordinations: current_metrics.coordinations + 1}
                  :system3 -> %{current_metrics | controls: current_metrics.controls + 1}
                  :system4 -> %{current_metrics | analyses: current_metrics.analyses + 1}
                  :system5 -> %{current_metrics | policies: current_metrics.policies + 1}
                end
              end
            end
        end
      end
    
    # Update average latency
    final_metrics = if processing_time > 0 do
      current_avg = updated_metrics.avg_latency
      operation_count = get_operation_count(updated_metrics, system_key)
      
      new_avg = if operation_count > 1 do
        (current_avg * (operation_count - 1) + processing_time) / operation_count
      else
        processing_time
      end
      
      %{updated_metrics | avg_latency: new_avg}
    else
      updated_metrics
    end
    
    put_in(state, [:system_metrics, system_key], final_metrics)
  end
  
  defp update_algedonic_metrics(state, event) do
    current_algedonic = state.algedonic_metrics
    
    updated_algedonic = case event.event_type do
      "algedonic.pain." <> _ ->
        pain_level = get_in(event, [:event_data, :pain_level]) || 0.5
        
        new_total_pain = current_algedonic.total_pain_events + 1
        new_avg_pain = (current_algedonic.avg_pain_level * current_algedonic.total_pain_events + pain_level) / new_total_pain
        
        %{current_algedonic |
          total_pain_events: new_total_pain,
          avg_pain_level: new_avg_pain
        }
      
      "algedonic.pleasure." <> _ ->
        pleasure_level = get_in(event, [:event_data, :pleasure_level]) || 0.5
        
        new_total_pleasure = current_algedonic.total_pleasure_events + 1
        new_avg_pleasure = (current_algedonic.avg_pleasure_level * current_algedonic.total_pleasure_events + pleasure_level) / new_total_pleasure
        
        %{current_algedonic |
          total_pleasure_events: new_total_pleasure,
          avg_pleasure_level: new_avg_pleasure
        }
      
      "algedonic.response." <> _ ->
        %{current_algedonic | autonomic_responses: current_algedonic.autonomic_responses + 1}
      
      _ ->
        current_algedonic
    end
    
    %{state | algedonic_metrics: updated_algedonic}
  end
  
  defp get_operation_count(metrics, system_key) do
    case system_key do
      :system1 -> metrics.operations
      :system2 -> metrics.coordinations
      :system3 -> metrics.controls
      :system4 -> metrics.analyses
      :system5 -> metrics.policies
    end
  end
  
  defp increment_throughput_counter(state) do
    %{state | current_minute_events: state.current_minute_events + 1}
  end
  
  defp current_minute do
    div(:erlang.system_time(:millisecond), 60_000)
  end
  
  defp get_or_generate_dashboard_data(state) do
    cache_age = if state.cache_updated_at do
      :erlang.system_time(:millisecond) - state.cache_updated_at
    else
      :infinity
    end
    
    if cache_age > 30_000 do  # Cache for 30 seconds
      generate_dashboard_data(state)
    else
      state.dashboard_cache
    end
  end
  
  defp generate_dashboard_data(state) do
    avg_latency = if state.events_processed > 0 do
      state.total_latency_ms / state.events_processed
    else
      0
    end
    
    current_throughput = state.current_minute_events
    avg_throughput = calculate_average_throughput(state.throughput_history)
    
    # System health scores
    system_health = calculate_system_health_scores(state.system_metrics)
    
    # Algedonic balance
    algedonic_balance = calculate_algedonic_balance(state.algedonic_metrics)
    
    dashboard_data = %{
      # Performance metrics
      total_events_processed: state.events_processed,
      average_latency_ms: Float.round(avg_latency, 2),
      current_throughput: current_throughput,
      average_throughput: Float.round(avg_throughput, 2),
      
      # System health
      system_health: system_health,
      
      # Event distribution
      top_event_types: get_top_event_types(state.event_type_counts, 10),
      active_streams: map_size(state.stream_counts),
      
      # Pattern detection
      patterns_detected: state.patterns_detected,
      pattern_distribution: state.pattern_types,
      
      # Algedonic system
      algedonic_balance: algedonic_balance,
      
      # Trends and insights
      performance_trends: Enum.take(state.performance_trends, -10),
      recent_anomalies: Enum.take(state.anomalies_detected, -5),
      
      # Metadata
      generated_at: DateTime.utc_now()
    }
    
    dashboard_data
  end
  
  defp calculate_average_throughput(history) when length(history) > 0 do
    Enum.sum(history) / length(history)
  end
  defp calculate_average_throughput(_), do: 0.0
  
  defp calculate_system_health_scores(system_metrics) do
    Enum.map(system_metrics, fn {system, metrics} ->
      total_operations = get_total_operations(metrics, system)
      error_rate = if total_operations > 0, do: metrics.errors / total_operations, else: 0.0
      
      health_score = max(0.0, 1.0 - error_rate)
      
      {system, %{
        health_score: Float.round(health_score, 3),
        error_rate: Float.round(error_rate, 3),
        total_operations: total_operations,
        avg_latency_ms: Float.round(metrics.avg_latency, 2)
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp get_total_operations(metrics, system) do
    case system do
      :system1 -> metrics.operations
      :system2 -> metrics.coordinations
      :system3 -> metrics.controls
      :system4 -> metrics.analyses
      :system5 -> metrics.policies
    end
  end
  
  defp calculate_algedonic_balance(algedonic_metrics) do
    total_events = algedonic_metrics.total_pain_events + algedonic_metrics.total_pleasure_events
    
    if total_events > 0 do
      pain_ratio = algedonic_metrics.total_pain_events / total_events
      pleasure_ratio = algedonic_metrics.total_pleasure_events / total_events
      
      balance_score = pleasure_ratio - pain_ratio  # Range: -1 to 1
      
      %{
        balance_score: Float.round(balance_score, 3),
        pain_ratio: Float.round(pain_ratio, 3),
        pleasure_ratio: Float.round(pleasure_ratio, 3),
        avg_pain_level: Float.round(algedonic_metrics.avg_pain_level, 3),
        avg_pleasure_level: Float.round(algedonic_metrics.avg_pleasure_level, 3),
        autonomic_responses: algedonic_metrics.autonomic_responses
      }
    else
      %{
        balance_score: 0.0,
        pain_ratio: 0.0,
        pleasure_ratio: 0.0,
        avg_pain_level: 0.0,
        avg_pleasure_level: 0.0,
        autonomic_responses: 0
      }
    end
  end
  
  defp get_top_event_types(event_counts, limit) do
    event_counts
    |> Enum.sort_by(fn {_type, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.into(%{})
  end
  
  defp analyze_performance_trends(state) do
    if length(state.throughput_history) >= 10 do
      recent_throughput = Enum.take(state.throughput_history, -10)
      
      # Simple trend analysis
      first_half = Enum.take(recent_throughput, 5)
      second_half = Enum.take(recent_throughput, -5)
      
      first_avg = Enum.sum(first_half) / 5
      second_avg = Enum.sum(second_half) / 5
      
      trend_direction = cond do
        second_avg > first_avg * 1.1 -> :increasing
        second_avg < first_avg * 0.9 -> :decreasing
        true -> :stable
      end
      
      [%{
        metric: :throughput,
        direction: trend_direction,
        change_percent: ((second_avg - first_avg) / first_avg * 100),
        timestamp: DateTime.utc_now()
      }]
    else
      []
    end
  end
  
  defp detect_anomalies(state) do
    anomalies = []
    
    # Check for throughput anomalies
    throughput_anomalies = if length(state.throughput_history) >= 5 do
      recent = Enum.take(state.throughput_history, -5)
      avg = Enum.sum(recent) / 5
      std_dev = calculate_std_dev(recent, avg)
      
      current = state.current_minute_events
      
      if abs(current - avg) > 2 * std_dev and std_dev > 0 do
        [%{
          type: :throughput_anomaly,
          severity: if(abs(current - avg) > 3 * std_dev, do: :high, else: :medium),
          description: "Throughput anomaly detected: #{current} events (expected ~#{Float.round(avg, 1)})",
          timestamp: DateTime.utc_now()
        }]
      else
        []
      end
    else
      []
    end
    
    # Check for latency anomalies
    latency_anomalies = if state.events_processed > 0 do
      avg_latency = state.total_latency_ms / state.events_processed
      
      if state.max_latency_ms > avg_latency * 5 do
        [%{
          type: :latency_anomaly,
          severity: :medium,
          description: "High latency spike detected: #{state.max_latency_ms}ms (avg: #{Float.round(avg_latency, 1)}ms)",
          timestamp: DateTime.utc_now()
        }]
      else
        []
      end
    else
      []
    end
    
    anomalies ++ throughput_anomalies ++ latency_anomalies
  end
  
  defp calculate_std_dev(values, mean) do
    variance = values
    |> Enum.map(fn x -> (x - mean) * (x - mean) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    :math.sqrt(variance)
  end
  
  defp generate_predictive_insights(state) do
    insights = []
    
    # Throughput predictions
    throughput_insights = if length(state.throughput_history) >= 20 do
      trend = analyze_throughput_trend(state.throughput_history)
      
      [%{
        type: :throughput_prediction,
        prediction: "Based on current trends, expect #{Float.round(trend.predicted_next, 1)} events/min",
        confidence: trend.confidence,
        timeframe: "next_minute"
      }]
    else
      []
    end
    
    # System health predictions
    health_insights = predict_system_health_issues(state.system_metrics)
    
    insights ++ throughput_insights ++ health_insights
  end
  
  defp analyze_throughput_trend(history) do
    recent = Enum.take(history, -10)
    
    # Simple linear regression
    n = length(recent)
    sum_x = n * (n + 1) / 2
    sum_y = Enum.sum(recent)
    sum_xy = recent |> Enum.with_index(1) |> Enum.map(fn {y, x} -> x * y end) |> Enum.sum()
    sum_x2 = Enum.sum(1..n, fn x -> x * x end)
    
    slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    intercept = (sum_y - slope * sum_x) / n
    
    predicted_next = slope * (n + 1) + intercept
    
    # Calculate confidence based on how well the trend fits
    confidence = min(1.0, max(0.0, 1.0 - abs(slope) / 10))
    
    %{
      predicted_next: max(0, predicted_next),
      confidence: confidence,
      trend_slope: slope
    }
  end
  
  defp predict_system_health_issues(system_metrics) do
    Enum.reduce(system_metrics, [], fn {system, metrics}, acc ->
      total_ops = get_total_operations(metrics, system)
      error_rate = if total_ops > 0, do: metrics.errors / total_ops, else: 0.0
      
      cond do
        error_rate > 0.1 ->
          [%{
            type: :system_health_warning,
            system: system,
            prediction: "System #{system} showing elevated error rate (#{Float.round(error_rate * 100, 1)}%)",
            severity: :medium,
            recommendation: "Consider investigating #{system} stability"
          } | acc]
        
        metrics.avg_latency > 1000 ->
          [%{
            type: :performance_warning,
            system: system,
            prediction: "System #{system} showing high latency (#{Float.round(metrics.avg_latency, 1)}ms)",
            severity: :low,
            recommendation: "Monitor #{system} performance trends"
          } | acc]
        
        true ->
          acc
      end
    end)
  end
end