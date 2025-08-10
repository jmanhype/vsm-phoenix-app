defmodule VsmPhoenix.Telemetry.GEPAPerformanceMonitor do
  @moduledoc """
  GEPA Performance Monitor - 35x Efficiency Measurement System

  Tracks evolutionary prompt optimization performance in real-time:
  1. Token efficiency measurement and trending
  2. Prompt evolution effectiveness scoring
  3. Baseline comparison and efficiency ratios
  4. Real-time 35x target progress tracking
  5. Performance anomaly detection for regression prevention
  """

  use GenServer
  require Logger
  alias VsmPhoenix.Telemetry.{PatternDetector, ContextFusionEngine}

  @target_efficiency 35.0
  @measurement_window_ms 60_000  # 1 minute windows
  @efficiency_history_limit 1000
  @anomaly_threshold 0.15  # 15% performance regression threshold

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def track_prompt_execution(prompt_id, execution_metrics) do
    GenServer.call(__MODULE__, {:track_execution, prompt_id, execution_metrics})
  end

  def measure_efficiency_gain(prompt_id, baseline_metrics, optimized_metrics) do
    GenServer.call(__MODULE__, {:measure_efficiency, prompt_id, baseline_metrics, optimized_metrics})
  end

  def get_current_efficiency_status() do
    GenServer.call(__MODULE__, :get_efficiency_status)
  end

  def get_35x_progress_report() do
    GenServer.call(__MODULE__, :get_35x_progress)
  end

  def track_evolution_cycle(evolution_id, cycle_metrics) do
    GenServer.call(__MODULE__, {:track_evolution, evolution_id, cycle_metrics})
  end

  def detect_performance_regression(prompt_id) do
    GenServer.call(__MODULE__, {:detect_regression, prompt_id})
  end

  def get_optimization_recommendations(system_context) do
    GenServer.call(__MODULE__, {:get_recommendations, system_context})
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    Logger.info("📊 GEPA Performance Monitor initializing...")
    
    # Initialize ETS tables for performance tracking
    :ets.new(:gepa_executions, [:ordered_set, :public, :named_table])
    :ets.new(:efficiency_history, [:ordered_set, :public, :named_table])
    :ets.new(:evolution_cycles, [:ordered_set, :public, :named_table])
    :ets.new(:baseline_metrics, [:set, :public, :named_table])
    :ets.new(:performance_alerts, [:ordered_set, :public, :named_table])

    # Schedule periodic analysis
    :timer.send_interval(@measurement_window_ms, :analyze_efficiency_trends)

    state = %{
      current_efficiency: 1.0,
      peak_efficiency: 1.0,
      efficiency_trend: :stable,
      total_executions: 0,
      total_tokens_saved: 0,
      performance_stats: %{
        successful_optimizations: 0,
        failed_optimizations: 0,
        regression_events: 0,
        efficiency_improvements: []
      },
      alert_thresholds: %{
        regression: @anomaly_threshold,
        stagnation: 0.05,  # Less than 5% improvement over time
        volatility: 0.3    # High variance in efficiency
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:track_execution, prompt_id, execution_metrics}, _from, state) do
    timestamp = System.monotonic_time(:microsecond)
    
    # Store execution data
    execution_entry = %{
      prompt_id: prompt_id,
      timestamp: timestamp,
      tokens_used: execution_metrics[:tokens_used] || 0,
      response_time_ms: execution_metrics[:response_time_ms] || 0,
      quality_score: execution_metrics[:quality_score] || 0.8,
      cost_estimate: execution_metrics[:cost_estimate] || 0.0,
      optimization_stage: execution_metrics[:optimization_stage] || :baseline,
      context_metadata: execution_metrics[:context] || %{}
    }

    :ets.insert(:gepa_executions, {timestamp, execution_entry})

    # Update execution count
    new_state = %{state | total_executions: state.total_executions + 1}

    # Trigger real-time efficiency calculation
    current_efficiency = calculate_current_efficiency(prompt_id)
    updated_state = update_efficiency_metrics(new_state, current_efficiency)

    {:reply, {:ok, execution_entry}, updated_state}
  end

  @impl true
  def handle_call({:measure_efficiency, prompt_id, baseline_metrics, optimized_metrics}, _from, state) do
    # Calculate efficiency improvement
    efficiency_ratio = calculate_efficiency_ratio(baseline_metrics, optimized_metrics)
    tokens_saved = (baseline_metrics[:tokens_used] || 0) - (optimized_metrics[:tokens_used] || 0)
    
    # Store baseline for comparison
    :ets.insert(:baseline_metrics, {prompt_id, baseline_metrics})
    
    # Create efficiency measurement
    efficiency_entry = %{
      prompt_id: prompt_id,
      timestamp: System.monotonic_time(:microsecond),
      baseline_tokens: baseline_metrics[:tokens_used] || 0,
      optimized_tokens: optimized_metrics[:tokens_used] || 0,
      efficiency_ratio: efficiency_ratio,
      tokens_saved: tokens_saved,
      quality_maintained: compare_quality_scores(baseline_metrics, optimized_metrics),
      optimization_method: optimized_metrics[:optimization_method] || :unknown,
      progress_toward_35x: (efficiency_ratio / @target_efficiency) * 100
    }

    :ets.insert(:efficiency_history, {efficiency_entry.timestamp, efficiency_entry})

    # Update state with new efficiency data
    new_tokens_saved = state.total_tokens_saved + max(tokens_saved, 0)
    new_stats = update_performance_stats(state.performance_stats, efficiency_entry)

    updated_state = %{state | 
      current_efficiency: efficiency_ratio,
      total_tokens_saved: new_tokens_saved,
      performance_stats: new_stats
    }

    # Check for new peak efficiency
    peak_updated_state = if efficiency_ratio > state.peak_efficiency do
      Logger.info("🚀 New peak efficiency achieved: #{Float.round(efficiency_ratio, 2)}x")
      %{updated_state | peak_efficiency: efficiency_ratio}
    else
      updated_state
    end

    {:reply, {:ok, efficiency_entry}, peak_updated_state}
  end

  @impl true
  def handle_call(:get_efficiency_status, _from, state) do
    recent_efficiency = get_recent_efficiency_average()
    trend_analysis = analyze_efficiency_trend()
    
    status = %{
      current_efficiency: state.current_efficiency,
      peak_efficiency: state.peak_efficiency,
      recent_average: recent_efficiency,
      trend: state.efficiency_trend,
      progress_to_35x: (state.current_efficiency / @target_efficiency) * 100,
      total_executions: state.total_executions,
      total_tokens_saved: state.total_tokens_saved,
      trend_analysis: trend_analysis,
      performance_health: calculate_performance_health(state)
    }

    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call(:get_35x_progress, _from, state) do
    progress_report = generate_35x_progress_report(state)
    {:reply, {:ok, progress_report}, state}
  end

  @impl true
  def handle_call({:track_evolution, evolution_id, cycle_metrics}, _from, state) do
    timestamp = System.monotonic_time(:microsecond)
    
    evolution_entry = %{
      evolution_id: evolution_id,
      timestamp: timestamp,
      cycle_number: cycle_metrics[:cycle_number] || 1,
      mutation_success_rate: cycle_metrics[:mutation_success_rate] || 0.0,
      crossover_effectiveness: cycle_metrics[:crossover_effectiveness] || 0.0,
      selection_pressure: cycle_metrics[:selection_pressure] || 0.5,
      population_diversity: cycle_metrics[:population_diversity] || 0.8,
      fitness_improvement: cycle_metrics[:fitness_improvement] || 0.0,
      convergence_rate: cycle_metrics[:convergence_rate] || 0.1
    }

    :ets.insert(:evolution_cycles, {timestamp, evolution_entry})

    {:reply, {:ok, evolution_entry}, state}
  end

  @impl true
  def handle_call({:detect_regression, prompt_id}, _from, state) do
    regression_analysis = perform_regression_analysis(prompt_id, state)
    
    if regression_analysis.regression_detected do
      # Log alert
      alert_entry = %{
        prompt_id: prompt_id,
        timestamp: System.monotonic_time(:microsecond),
        alert_type: :performance_regression,
        severity: regression_analysis.severity,
        details: regression_analysis,
        recommended_actions: suggest_regression_remedies(regression_analysis)
      }
      
      :ets.insert(:performance_alerts, {alert_entry.timestamp, alert_entry})
      
      Logger.warn("⚠️  Performance regression detected for prompt #{prompt_id}: #{regression_analysis.severity}")
    end

    {:reply, {:ok, regression_analysis}, state}
  end

  @impl true
  def handle_call({:get_recommendations, system_context}, _from, state) do
    recommendations = generate_optimization_recommendations(state, system_context)
    {:reply, {:ok, recommendations}, state}
  end

  @impl true
  def handle_info(:analyze_efficiency_trends, state) do
    # Periodic trend analysis
    new_trend = analyze_current_trend()
    
    # Update state with trend
    updated_state = %{state | efficiency_trend: new_trend}
    
    # Check for stagnation or other concerning patterns
    check_performance_health(updated_state)
    
    {:noreply, updated_state}
  end

  # Performance Calculation Functions

  defp calculate_efficiency_ratio(baseline_metrics, optimized_metrics) do
    baseline_tokens = baseline_metrics[:tokens_used] || 1
    optimized_tokens = optimized_metrics[:tokens_used] || 1
    
    # Efficiency ratio = tokens_saved / original_tokens + 1
    if optimized_tokens > 0 do
      baseline_tokens / optimized_tokens
    else
      1.0
    end
  end

  defp calculate_current_efficiency(prompt_id) do
    # Get recent executions for this prompt
    recent_executions = get_recent_executions(prompt_id, 10)
    
    if length(recent_executions) > 1 do
      # Compare latest against earlier executions
      latest = List.first(recent_executions)
      earlier = Enum.drop(recent_executions, 1)
      
      latest_tokens = latest.tokens_used
      avg_earlier_tokens = Enum.reduce(earlier, 0, &(&1.tokens_used + &2)) / length(earlier)
      
      if latest_tokens > 0 do
        avg_earlier_tokens / latest_tokens
      else
        1.0
      end
    else
      1.0
    end
  end

  defp get_recent_executions(prompt_id, limit) do
    :ets.tab2list(:gepa_executions)
    |> Enum.filter(fn {_, entry} -> entry.prompt_id == prompt_id end)
    |> Enum.sort_by(fn {timestamp, _} -> -timestamp end)
    |> Enum.take(limit)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  defp update_efficiency_metrics(state, new_efficiency) do
    # Update peak if necessary
    new_peak = max(state.peak_efficiency, new_efficiency)
    
    %{state | 
      current_efficiency: new_efficiency,
      peak_efficiency: new_peak
    }
  end

  defp compare_quality_scores(baseline_metrics, optimized_metrics) do
    baseline_quality = baseline_metrics[:quality_score] || 0.8
    optimized_quality = optimized_metrics[:quality_score] || 0.8
    
    quality_ratio = optimized_quality / max(baseline_quality, 0.1)
    
    %{
      quality_maintained: quality_ratio >= 0.95,  # Quality maintained if >= 95% of original
      quality_ratio: quality_ratio,
      quality_change: optimized_quality - baseline_quality
    }
  end

  defp update_performance_stats(stats, efficiency_entry) do
    # Determine if this was a successful optimization
    success = efficiency_entry.efficiency_ratio > 1.05  # At least 5% improvement
    
    new_stats = if success do
      %{stats | successful_optimizations: stats.successful_optimizations + 1}
    else
      %{stats | failed_optimizations: stats.failed_optimizations + 1}
    end

    # Add to efficiency improvements list
    improvements = [efficiency_entry.efficiency_ratio | stats.efficiency_improvements]
    |> Enum.take(100)  # Keep last 100 improvements
    
    %{new_stats | efficiency_improvements: improvements}
  end

  defp get_recent_efficiency_average(window_ms \\ 300_000) do
    # Get average efficiency over last 5 minutes
    cutoff_time = System.monotonic_time(:microsecond) - window_ms * 1000
    
    recent_entries = :ets.tab2list(:efficiency_history)
    |> Enum.filter(fn {timestamp, _} -> timestamp > cutoff_time end)
    |> Enum.map(fn {_, entry} -> entry end)
    
    if length(recent_entries) > 0 do
      total_efficiency = Enum.reduce(recent_entries, 0.0, &(&1.efficiency_ratio + &2))
      total_efficiency / length(recent_entries)
    else
      1.0
    end
  end

  defp analyze_efficiency_trend(window_count \\ 20) do
    # Analyze trend over last N efficiency measurements
    recent_entries = :ets.tab2list(:efficiency_history)
    |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
    |> Enum.take(-window_count)
    |> Enum.map(fn {_, entry} -> entry.efficiency_ratio end)
    
    if length(recent_entries) > 5 do
      case PatternDetector.detect_trend("efficiency_trend", :auto) do
        {:ok, trend_analysis} ->
          %{
            direction: trend_analysis.trend_direction,
            strength: trend_analysis.trend_strength,
            r_squared: trend_analysis.r_squared,
            slope: trend_analysis[:slope] || 0.0
          }
        _ ->
          %{direction: :unknown, strength: :none, r_squared: 0.0}
      end
    else
      %{direction: :insufficient_data, strength: :none, r_squared: 0.0}
    end
  end

  defp analyze_current_trend() do
    trend_data = analyze_efficiency_trend()
    
    cond do
      trend_data.direction == :increasing and trend_data.r_squared > 0.7 -> :improving
      trend_data.direction == :decreasing and trend_data.r_squared > 0.7 -> :declining
      trend_data.r_squared < 0.3 -> :volatile
      true -> :stable
    end
  end

  defp generate_35x_progress_report(state) do
    # Calculate detailed progress toward 35x target
    current_progress = (state.current_efficiency / @target_efficiency) * 100
    peak_progress = (state.peak_efficiency / @target_efficiency) * 100
    
    # Estimate time to reach target based on current trend
    trend_analysis = analyze_efficiency_trend()
    estimated_time_to_target = estimate_time_to_35x(state, trend_analysis)
    
    # Get performance breakdown by optimization method
    method_breakdown = get_efficiency_by_method()
    
    %{
      target_efficiency: @target_efficiency,
      current_efficiency: state.current_efficiency,
      current_progress_percent: Float.round(current_progress, 2),
      peak_efficiency: state.peak_efficiency,
      peak_progress_percent: Float.round(peak_progress, 2),
      total_tokens_saved: state.total_tokens_saved,
      efficiency_gap: @target_efficiency - state.current_efficiency,
      estimated_time_to_target: estimated_time_to_target,
      trend_analysis: trend_analysis,
      method_breakdown: method_breakdown,
      milestones: %{
        "10x" => state.current_efficiency >= 10.0,
        "20x" => state.current_efficiency >= 20.0,
        "30x" => state.current_efficiency >= 30.0,
        "35x" => state.current_efficiency >= 35.0
      }
    }
  end

  defp estimate_time_to_35x(state, trend_analysis) do
    if trend_analysis.direction == :improving and trend_analysis[:slope] do
      remaining_efficiency = @target_efficiency - state.current_efficiency
      improvement_rate = trend_analysis.slope
      
      if improvement_rate > 0 do
        estimated_days = remaining_efficiency / improvement_rate
        
        cond do
          estimated_days < 1 -> "Less than 1 day"
          estimated_days < 7 -> "#{Float.round(estimated_days, 1)} days"
          estimated_days < 30 -> "#{Float.round(estimated_days / 7, 1)} weeks" 
          true -> "#{Float.round(estimated_days / 30, 1)} months"
        end
      else
        "Unable to estimate - no improvement trend"
      end
    else
      "Unable to estimate - insufficient trend data"
    end
  end

  defp get_efficiency_by_method() do
    # Analyze efficiency gains by optimization method
    method_data = :ets.tab2list(:efficiency_history)
    |> Enum.map(fn {_, entry} -> entry end)
    |> Enum.group_by(& &1.optimization_method)
    |> Enum.map(fn {method, entries} ->
      avg_efficiency = Enum.reduce(entries, 0.0, &(&1.efficiency_ratio + &2)) / length(entries)
      max_efficiency = Enum.reduce(entries, 0.0, &max(&1.efficiency_ratio, &2))
      
      {method, %{
        count: length(entries),
        average_efficiency: Float.round(avg_efficiency, 2),
        max_efficiency: Float.round(max_efficiency, 2)
      }}
    end)
    |> Enum.into(%{})
    
    method_data
  end

  defp perform_regression_analysis(prompt_id, state) do
    recent_efficiency = get_recent_prompt_efficiency(prompt_id, 10)
    historical_efficiency = get_historical_prompt_efficiency(prompt_id, 50)
    
    if length(recent_efficiency) > 3 and length(historical_efficiency) > 10 do
      recent_avg = Enum.sum(recent_efficiency) / length(recent_efficiency)
      historical_avg = Enum.sum(historical_efficiency) / length(historical_efficiency)
      
      efficiency_drop = historical_avg - recent_avg
      relative_drop = efficiency_drop / max(historical_avg, 0.1)
      
      regression_detected = relative_drop > state.alert_thresholds.regression
      
      severity = cond do
        relative_drop > 0.3 -> :critical
        relative_drop > 0.2 -> :high
        relative_drop > 0.1 -> :medium
        true -> :low
      end
      
      %{
        regression_detected: regression_detected,
        severity: severity,
        efficiency_drop: Float.round(efficiency_drop, 3),
        relative_drop_percent: Float.round(relative_drop * 100, 2),
        recent_average: Float.round(recent_avg, 3),
        historical_average: Float.round(historical_avg, 3),
        sample_sizes: %{recent: length(recent_efficiency), historical: length(historical_efficiency)}
      }
    else
      %{
        regression_detected: false,
        severity: :none,
        reason: :insufficient_data
      }
    end
  end

  defp get_recent_prompt_efficiency(prompt_id, limit) do
    get_recent_executions(prompt_id, limit * 2)
    |> Enum.map(&calculate_execution_efficiency/1)
    |> Enum.filter(&(&1 > 0))
    |> Enum.take(limit)
  end

  defp get_historical_prompt_efficiency(prompt_id, limit) do
    # Get historical efficiency data (older than recent window)
    cutoff_time = System.monotonic_time(:microsecond) - 600_000_000  # 10 minutes ago
    
    :ets.tab2list(:gepa_executions)
    |> Enum.filter(fn {timestamp, entry} -> 
      entry.prompt_id == prompt_id and timestamp < cutoff_time
    end)
    |> Enum.sort_by(fn {timestamp, _} -> -timestamp end)
    |> Enum.take(limit)
    |> Enum.map(fn {_, entry} -> calculate_execution_efficiency(entry) end)
    |> Enum.filter(&(&1 > 0))
  end

  defp calculate_execution_efficiency(execution) do
    # Simple efficiency based on tokens per unit quality
    if execution.quality_score > 0 and execution.tokens_used > 0 do
      execution.quality_score / execution.tokens_used * 1000  # Scale for readability
    else
      0.0
    end
  end

  defp suggest_regression_remedies(regression_analysis) do
    base_recommendations = [
      "Review recent prompt modifications",
      "Check for environmental changes affecting performance",
      "Validate optimization pipeline integrity"
    ]
    
    severity_recommendations = case regression_analysis.severity do
      :critical -> [
        "Immediately rollback to previous prompt version",
        "Trigger emergency performance analysis",
        "Alert optimization team"
      ]
      :high -> [
        "Schedule prompt reoptimization cycle",
        "Review evolution parameters"
      ]
      :medium -> [
        "Monitor closely for further degradation",
        "Consider additional training data"
      ]
      _ -> []
    end
    
    base_recommendations ++ severity_recommendations
  end

  defp generate_optimization_recommendations(state, system_context) do
    # Generate recommendations based on current performance and context
    base_recommendations = analyze_performance_gaps(state)
    context_recommendations = generate_context_specific_recommendations(system_context)
    trend_recommendations = generate_trend_based_recommendations(state.efficiency_trend)
    
    %{
      performance_based: base_recommendations,
      context_specific: context_recommendations,
      trend_based: trend_recommendations,
      priority: determine_recommendation_priority(state),
      estimated_impact: estimate_recommendation_impact(state)
    }
  end

  defp analyze_performance_gaps(state) do
    efficiency_gap = @target_efficiency - state.current_efficiency
    
    cond do
      efficiency_gap > 25 -> [
        "Focus on fundamental prompt architecture improvements",
        "Implement aggressive compression techniques",
        "Explore few-shot to zero-shot optimization"
      ]
      efficiency_gap > 15 -> [
        "Optimize context window utilization",
        "Implement better caching strategies",
        "Refine evolutionary parameters"
      ]
      efficiency_gap > 5 -> [
        "Fine-tune existing optimizations", 
        "Focus on edge case improvements",
        "Optimize for specific use case patterns"
      ]
      true -> [
        "Maintain current optimization level",
        "Focus on consistency and reliability"
      ]
    end
  end

  defp generate_context_specific_recommendations(system_context) do
    phase = system_context[:current_phase] || :unknown
    
    case phase do
      :system1 -> ["Optimize for operational speed", "Focus on task-specific prompts"]
      :system2 -> ["Enhance coordination context", "Optimize attention-based prompts"]
      :system3 -> ["Focus on resource optimization", "Streamline control prompts"] 
      :system4 -> ["Optimize environmental scanning", "Enhance intelligence gathering"]
      :system5 -> ["Optimize policy synthesis", "Focus on strategic prompts"]
      _ -> ["General optimization recommendations"]
    end
  end

  defp generate_trend_based_recommendations(trend) do
    case trend do
      :improving -> ["Continue current optimization strategy", "Gradually increase targets"]
      :declining -> ["Review recent changes", "Consider rollback strategies"]
      :volatile -> ["Stabilize optimization parameters", "Reduce mutation rates"]
      :stable -> ["Introduce controlled perturbations", "Explore new optimization spaces"]
      _ -> ["Establish baseline performance metrics"]
    end
  end

  defp determine_recommendation_priority(state) do
    cond do
      state.current_efficiency < 2.0 -> :critical
      state.efficiency_trend == :declining -> :high
      state.current_efficiency < @target_efficiency / 2 -> :high
      state.efficiency_trend == :volatile -> :medium
      true -> :normal
    end
  end

  defp estimate_recommendation_impact(state) do
    # Estimate potential efficiency gains from recommendations
    base_impact = case state.current_efficiency do
      e when e < 5.0 -> %{min: 2.0, max: 8.0}
      e when e < 15.0 -> %{min: 1.5, max: 5.0}
      e when e < 25.0 -> %{min: 1.2, max: 3.0}
      _ -> %{min: 1.1, max: 1.5}
    end
    
    # Adjust based on trend
    trend_multiplier = case state.efficiency_trend do
      :improving -> 1.2
      :stable -> 1.0
      :volatile -> 0.8
      :declining -> 0.6
      _ -> 0.9
    end
    
    %{
      min_efficiency_gain: Float.round(base_impact.min * trend_multiplier, 2),
      max_efficiency_gain: Float.round(base_impact.max * trend_multiplier, 2),
      confidence: if(state.total_executions > 50, do: :high, else: :medium)
    }
  end

  defp calculate_performance_health(state) do
    # Overall health score based on multiple factors
    efficiency_health = min(state.current_efficiency / 10.0, 1.0)  # Health maxes at 10x efficiency
    trend_health = case state.efficiency_trend do
      :improving -> 1.0
      :stable -> 0.8
      :volatile -> 0.6
      :declining -> 0.3
      _ -> 0.5
    end
    
    consistency_health = if length(state.performance_stats.efficiency_improvements) > 10 do
      std_dev = Statistics.standard_deviation(state.performance_stats.efficiency_improvements)
      max(0.0, 1.0 - std_dev / 5.0)  # Lower std dev = higher health
    else
      0.7  # Neutral for insufficient data
    end
    
    overall_health = (efficiency_health + trend_health + consistency_health) / 3.0
    
    %{
      overall: Float.round(overall_health, 3),
      efficiency: Float.round(efficiency_health, 3),
      trend: Float.round(trend_health, 3),
      consistency: Float.round(consistency_health, 3),
      status: categorize_health_status(overall_health)
    }
  end

  defp categorize_health_status(health_score) do
    cond do
      health_score > 0.8 -> :excellent
      health_score > 0.6 -> :good
      health_score > 0.4 -> :fair
      health_score > 0.2 -> :poor
      true -> :critical
    end
  end

  defp check_performance_health(state) do
    health = calculate_performance_health(state)
    
    if health.status in [:poor, :critical] do
      Logger.warn("⚠️  GEPA Performance Health: #{health.status} (#{health.overall})")
      
      # Could trigger additional alerts or remediation here
    end
  end
end