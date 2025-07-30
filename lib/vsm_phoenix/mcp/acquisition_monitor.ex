defmodule VsmPhoenix.MCP.AcquisitionMonitor do
  @moduledoc """
  Monitors the autonomous acquisition system's health and performance.
  Tracks metrics, detects issues, and provides telemetry data.
  """

  use GenServer
  require Logger

  @metrics_retention_period 24 * 60 * 60  # 24 hours in seconds

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      metrics: %{
        acquisitions_attempted: 0,
        acquisitions_successful: 0,
        acquisitions_failed: 0,
        variety_gaps_identified: 0,
        variety_gaps_resolved: 0,
        average_acquisition_time: 0,
        total_acquisition_time: 0,
        decision_accuracy: 1.0,
        system_health: 1.0
      },
      events: [],
      alerts: [],
      performance_history: []
    }
    
    # Schedule periodic health check
    Process.send_after(self(), :health_check, 5000)
    
    {:ok, state}
  end

  @doc """
  Record an acquisition attempt.
  """
  def record_acquisition_attempt(server_id, outcome, duration) do
    GenServer.cast(__MODULE__, {:record_acquisition, server_id, outcome, duration})
  end

  @doc """
  Record variety gap identification.
  """
  def record_gap_identified(gap) do
    GenServer.cast(__MODULE__, {:record_gap, :identified, gap})
  end

  @doc """
  Record variety gap resolution.
  """
  def record_gap_resolved(gap) do
    GenServer.cast(__MODULE__, {:record_gap, :resolved, gap})
  end

  @doc """
  Get current metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get recent events.
  """
  def get_events(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_events, limit})
  end

  @doc """
  Get active alerts.
  """
  def get_alerts do
    GenServer.call(__MODULE__, :get_alerts)
  end

  @impl true
  def handle_cast({:record_acquisition, server_id, outcome, duration}, state) do
    new_metrics = case outcome do
      :success ->
        %{state.metrics |
          acquisitions_attempted: state.metrics.acquisitions_attempted + 1,
          acquisitions_successful: state.metrics.acquisitions_successful + 1,
          total_acquisition_time: state.metrics.total_acquisition_time + duration
        }
        
      {:error, _reason} ->
        %{state.metrics |
          acquisitions_attempted: state.metrics.acquisitions_attempted + 1,
          acquisitions_failed: state.metrics.acquisitions_failed + 1
        }
    end
    
    # Update average acquisition time
    if new_metrics.acquisitions_successful > 0 do
      avg_time = new_metrics.total_acquisition_time / new_metrics.acquisitions_successful
      new_metrics = %{new_metrics | average_acquisition_time: avg_time}
    end
    
    # Update decision accuracy
    if new_metrics.acquisitions_attempted > 0 do
      accuracy = new_metrics.acquisitions_successful / new_metrics.acquisitions_attempted
      new_metrics = %{new_metrics | decision_accuracy: accuracy}
    end
    
    # Record event
    event = %{
      type: :acquisition,
      timestamp: DateTime.utc_now(),
      server_id: server_id,
      outcome: outcome,
      duration: duration
    }
    
    new_state = %{state |
      metrics: new_metrics,
      events: [event | state.events] |> Enum.take(1000)  # Keep last 1000 events
    }
    
    # Check for alerts
    new_state = check_for_alerts(new_state)
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:record_gap, action, gap}, state) do
    new_metrics = case action do
      :identified ->
        %{state.metrics | variety_gaps_identified: state.metrics.variety_gaps_identified + 1}
        
      :resolved ->
        %{state.metrics | variety_gaps_resolved: state.metrics.variety_gaps_resolved + 1}
    end
    
    event = %{
      type: :variety_gap,
      timestamp: DateTime.utc_now(),
      action: action,
      gap: gap
    }
    
    new_state = %{state |
      metrics: new_metrics,
      events: [event | state.events] |> Enum.take(1000)
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    # Calculate additional derived metrics
    enhanced_metrics = Map.merge(state.metrics, %{
      success_rate: calculate_success_rate(state.metrics),
      gap_resolution_rate: calculate_gap_resolution_rate(state.metrics),
      efficiency_score: calculate_efficiency_score(state.metrics)
    })
    
    {:reply, enhanced_metrics, state}
  end

  @impl true
  def handle_call({:get_events, limit}, _from, state) do
    events = Enum.take(state.events, limit)
    {:reply, events, state}
  end

  @impl true
  def handle_call(:get_alerts, _from, state) do
    active_alerts = Enum.filter(state.alerts, & &1.active)
    {:reply, active_alerts, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    # Perform system health check
    health_score = calculate_health_score(state)
    
    new_metrics = %{state.metrics | system_health: health_score}
    
    # Record performance snapshot
    snapshot = %{
      timestamp: DateTime.utc_now(),
      health_score: health_score,
      metrics: new_metrics
    }
    
    new_history = [snapshot | state.performance_history]
    |> Enum.take(288)  # Keep 24 hours of 5-minute snapshots
    
    new_state = %{state |
      metrics: new_metrics,
      performance_history: new_history
    }
    
    # Check for health-based alerts
    new_state = check_health_alerts(new_state, health_score)
    
    # Schedule next health check
    Process.send_after(self(), :health_check, 5 * 60 * 1000)  # 5 minutes
    
    {:noreply, new_state}
  end

  # Private functions

  defp calculate_success_rate(metrics) do
    if metrics.acquisitions_attempted > 0 do
      metrics.acquisitions_successful / metrics.acquisitions_attempted
    else
      1.0
    end
  end

  defp calculate_gap_resolution_rate(metrics) do
    if metrics.variety_gaps_identified > 0 do
      metrics.variety_gaps_resolved / metrics.variety_gaps_identified
    else
      1.0
    end
  end

  defp calculate_efficiency_score(metrics) do
    # Composite efficiency score
    factors = [
      calculate_success_rate(metrics) * 0.3,
      calculate_gap_resolution_rate(metrics) * 0.3,
      metrics.decision_accuracy * 0.2,
      (1.0 - min(metrics.average_acquisition_time / 60_000, 1.0)) * 0.2  # Penalty for slow acquisitions
    ]
    
    Enum.sum(factors)
  end

  defp calculate_health_score(state) do
    # Check various health indicators
    recent_failures = count_recent_failures(state.events, 60)  # Last hour
    
    indicators = [
      # Success rate indicator
      (if calculate_success_rate(state.metrics) > 0.7, do: 0.25, else: 0),
      
      # Gap resolution indicator
      (if calculate_gap_resolution_rate(state.metrics) > 0.6, do: 0.25, else: 0),
      
      # No recent failures indicator
      (if recent_failures < 3, do: 0.25, else: 0),
      
      # Performance stability indicator
      (if is_performance_stable?(state.performance_history), do: 0.25, else: 0)
    ]
    
    Enum.sum(indicators)
  end

  defp count_recent_failures(events, minutes) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)
    
    events
    |> Enum.filter(fn event ->
      event.type == :acquisition && 
      match?({:error, _}, event[:outcome]) &&
      DateTime.compare(event.timestamp, cutoff) == :gt
    end)
    |> length()
  end

  defp is_performance_stable?(history) do
    # Check if performance has been stable
    recent = Enum.take(history, 12)  # Last hour
    
    if length(recent) < 3 do
      true  # Not enough data
    else
      health_scores = Enum.map(recent, & &1.health_score)
      variance = calculate_variance(health_scores)
      variance < 0.1  # Low variance indicates stability
    end
  end

  defp calculate_variance(values) do
    if Enum.empty?(values) do
      0
    else
      mean = Enum.sum(values) / length(values)
      sum_squared_diff = values
      |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
      |> Enum.sum()
      
      sum_squared_diff / length(values)
    end
  end

  defp check_for_alerts(state) do
    alerts = []
    
    # High failure rate alert
    if state.metrics.acquisitions_failed > 5 && calculate_success_rate(state.metrics) < 0.5 do
      alerts = [create_alert(:high_failure_rate, :warning) | alerts]
    end
    
    # Slow acquisition alert
    if state.metrics.average_acquisition_time > 30_000 do  # > 30 seconds
      alerts = [create_alert(:slow_acquisitions, :info) | alerts]
    end
    
    # Many unresolved gaps alert
    unresolved = state.metrics.variety_gaps_identified - state.metrics.variety_gaps_resolved
    if unresolved > 10 do
      alerts = [create_alert(:many_unresolved_gaps, :warning) | alerts]
    end
    
    %{state | alerts: merge_alerts(state.alerts, alerts)}
  end

  defp check_health_alerts(state, health_score) do
    alerts = []
    
    # System health degraded
    if health_score < 0.5 do
      alerts = [create_alert(:system_health_degraded, :error) | alerts]
    end
    
    # Performance declining
    if is_performance_declining?(state.performance_history) do
      alerts = [create_alert(:performance_declining, :warning) | alerts]
    end
    
    %{state | alerts: merge_alerts(state.alerts, alerts)}
  end

  defp is_performance_declining?(history) do
    # Check if performance is trending down
    if length(history) < 10 do
      false
    else
      recent = Enum.take(history, 6)
      older = Enum.slice(history, 6, 6)
      
      recent_avg = Enum.sum(Enum.map(recent, & &1.health_score)) / length(recent)
      older_avg = Enum.sum(Enum.map(older, & &1.health_score)) / length(older)
      
      recent_avg < older_avg * 0.8  # 20% decline
    end
  end

  defp create_alert(type, severity) do
    %{
      id: "alert_#{:erlang.phash2({type, DateTime.utc_now()})}",
      type: type,
      severity: severity,
      message: alert_message(type),
      created_at: DateTime.utc_now(),
      active: true
    }
  end

  defp alert_message(:high_failure_rate), do: "High acquisition failure rate detected"
  defp alert_message(:slow_acquisitions), do: "Acquisitions are taking longer than expected"
  defp alert_message(:many_unresolved_gaps), do: "Many variety gaps remain unresolved"
  defp alert_message(:system_health_degraded), do: "System health has degraded"
  defp alert_message(:performance_declining), do: "System performance is declining"

  defp merge_alerts(existing, new) do
    # Don't duplicate alerts of the same type
    existing_types = Enum.map(existing, & &1.type) |> MapSet.new()
    
    new_unique = Enum.reject(new, fn alert ->
      MapSet.member?(existing_types, alert.type)
    end)
    
    (existing ++ new_unique)
    |> Enum.take(50)  # Keep max 50 alerts
  end
end