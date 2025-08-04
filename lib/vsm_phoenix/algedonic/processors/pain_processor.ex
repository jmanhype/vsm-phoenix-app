defmodule VsmPhoenix.Algedonic.PainProcessor do
  @moduledoc """
  Pain Processor for handling critical system alerts and issues.
  
  Processes pain signals to:
  - Identify root causes
  - Trigger immediate interventions
  - Learn from system failures
  - Prevent cascade failures
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.Queen
  
  @type pain_level :: :discomfort | :pain | :acute_pain | :agony
  @type pain_source :: :performance | :security | :stability | :capacity | :variety
  
  @type pain_signal :: %{
    level: pain_level(),
    source: pain_source(),
    location: String.t(),
    timestamp: DateTime.t(),
    metrics: map(),
    diagnosis: map() | nil
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Process a pain signal and determine appropriate response
  """
  def process(signal) do
    GenServer.cast(__MODULE__, {:process_pain, signal})
  end
  
  @doc """
  Analyze pain patterns for systemic issues
  """
  def analyze_patterns(timeframe \\ :last_hour) do
    GenServer.call(__MODULE__, {:analyze_patterns, timeframe})
  end
  
  @doc """
  Get current pain state of the system
  """
  def pain_state do
    GenServer.call(__MODULE__, :get_pain_state)
  end
  
  @doc """
  Register a pain threshold for automatic alerting
  """
  def register_threshold(metric, threshold, action) do
    GenServer.call(__MODULE__, {:register_threshold, metric, threshold, action})
  end
  
  # Server Callbacks
  
  def init(_opts) do
    state = %{
      pain_history: [],
      active_pains: %{},
      pain_patterns: %{},
      thresholds: default_thresholds(),
      interventions: %{},
      learning_data: [],
      cascade_prevention: %{
        active: false,
        triggers: []
      },
      metrics: %{
        total_pains: 0,
        resolved_pains: 0,
        cascade_prevented: 0,
        intervention_success: 0
      }
    }
    
    # Schedule pattern analysis
    Process.send_after(self(), :analyze_patterns, 60_000)
    
    {:ok, state}
  end
  
  def handle_cast({:process_pain, signal}, state) do
    Logger.warning("Processing pain signal: #{inspect(signal)}")
    
    # Diagnose the pain
    diagnosis = diagnose_pain(signal, state)
    signal = Map.put(signal, :diagnosis, diagnosis)
    
    # Determine pain level
    pain_level = calculate_pain_level(signal, state)
    
    # Record pain
    state = record_pain(state, signal, pain_level)
    
    # Determine and execute intervention
    state = case pain_level do
      :agony -> handle_agony(signal, state)
      :acute_pain -> handle_acute_pain(signal, state)
      :pain -> handle_pain(signal, state)
      :discomfort -> handle_discomfort(signal, state)
    end
    
    # Check for cascade conditions
    state = check_cascade_conditions(state, signal)
    
    # Learn from the pain
    state = learn_from_pain(state, signal, diagnosis)
    
    {:noreply, state}
  end
  
  def handle_call({:analyze_patterns, timeframe}, _from, state) do
    patterns = analyze_pain_patterns(state.pain_history, timeframe)
    
    # Update pattern cache
    state = %{state | pain_patterns: patterns}
    
    # Identify systemic issues
    systemic_issues = identify_systemic_issues(patterns)
    
    {:reply, %{patterns: patterns, systemic_issues: systemic_issues}, state}
  end
  
  def handle_call(:get_pain_state, _from, state) do
    pain_state = %{
      active_pains: Map.keys(state.active_pains),
      pain_level: calculate_overall_pain_level(state),
      recent_patterns: Map.take(state.pain_patterns, [:recurring, :escalating]),
      cascade_risk: assess_cascade_risk(state),
      interventions_active: map_size(state.interventions)
    }
    
    {:reply, pain_state, state}
  end
  
  def handle_call({:register_threshold, metric, threshold, action}, _from, state) do
    thresholds = Map.put(state.thresholds, metric, {threshold, action})
    {:reply, :ok, %{state | thresholds: thresholds}}
  end
  
  def handle_info(:analyze_patterns, state) do
    # Periodic pattern analysis
    patterns = analyze_pain_patterns(state.pain_history, :last_hour)
    
    # Alert on concerning patterns
    if concerning_patterns?(patterns) do
      alert_concerning_patterns(patterns)
    end
    
    # Schedule next analysis
    Process.send_after(self(), :analyze_patterns, 60_000)
    
    {:noreply, %{state | pain_patterns: patterns}}
  end
  
  def handle_info({:intervention_complete, intervention_id, result}, state) do
    # Handle intervention completion
    state = case result do
      :success ->
        %{state | 
          interventions: Map.delete(state.interventions, intervention_id),
          metrics: Map.update!(state.metrics, :intervention_success, &(&1 + 1))
        }
      :failure ->
        escalate_failed_intervention(intervention_id, state)
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp diagnose_pain(signal, state) do
    %{
      root_cause: identify_root_cause(signal, state),
      impact_scope: assess_impact_scope(signal),
      related_issues: find_related_issues(signal, state),
      recommended_action: recommend_action(signal, state),
      urgency: calculate_urgency(signal)
    }
  end
  
  defp identify_root_cause(signal, state) do
    # Analyze signal data and history to identify root cause
    cond do
      resource_exhaustion?(signal) -> :resource_exhaustion
      performance_degradation?(signal) -> :performance_degradation
      variety_imbalance?(signal) -> :variety_imbalance
      security_issue?(signal) -> :security_breach
      cascading_failure?(signal, state) -> :cascade_failure
      true -> :unknown
    end
  end
  
  defp resource_exhaustion?(signal) do
    metrics = Map.get(signal, :data, %{})
    Map.get(metrics, :memory_usage, 0) > 0.9 or
    Map.get(metrics, :cpu_usage, 0) > 0.95 or
    Map.get(metrics, :disk_usage, 0) > 0.9
  end
  
  defp performance_degradation?(signal) do
    metrics = Map.get(signal, :data, %{})
    Map.get(metrics, :latency_ms, 0) > 5000 or
    Map.get(metrics, :error_rate, 0) > 0.1
  end
  
  defp variety_imbalance?(signal) do
    metrics = Map.get(signal, :data, %{})
    Map.get(metrics, :variety_ratio, 0) > 2.0
  end
  
  defp security_issue?(signal) do
    data = Map.get(signal, :data, %{})
    Map.get(data, :security_breach, false) or
    Map.get(data, :unauthorized_access, false)
  end
  
  defp cascading_failure?(signal, state) do
    # Check if this pain is result of cascade
    recent_pains = Enum.filter(state.pain_history, fn p ->
      DateTime.diff(signal.timestamp, p.timestamp) < 60
    end)
    
    length(recent_pains) > 5
  end
  
  defp calculate_pain_level(signal, state) do
    intensity = Map.get(signal, :intensity, :medium)
    diagnosis = Map.get(signal, :diagnosis, %{})
    
    cond do
      intensity == :critical -> :agony
      diagnosis.root_cause == :cascade_failure -> :agony
      diagnosis.urgency == :immediate -> :acute_pain
      intensity == :high -> :acute_pain
      intensity == :medium -> :pain
      true -> :discomfort
    end
  end
  
  defp handle_agony(signal, state) do
    Logger.error("🚨 AGONY LEVEL PAIN - IMMEDIATE INTERVENTION REQUIRED")
    
    # Immediate S5 notification
    Queen.emergency_intervention(%{
      type: :pain_agony,
      signal: signal,
      diagnosis: signal.diagnosis,
      timestamp: DateTime.utc_now()
    })
    
    # Trigger emergency response
    intervention_id = start_emergency_intervention(signal)
    
    # Activate cascade prevention
    state = activate_cascade_prevention(state, signal)
    
    %{state | 
      interventions: Map.put(state.interventions, intervention_id, :emergency),
      active_pains: Map.put(state.active_pains, signal.source, signal)
    }
  end
  
  defp handle_acute_pain(signal, state) do
    Logger.warning("Acute pain detected - initiating intervention")
    
    # Notify S3 for control action
    Control.emergency_control(signal)
    
    # Start targeted intervention
    intervention_id = start_intervention(signal, :targeted)
    
    %{state | 
      interventions: Map.put(state.interventions, intervention_id, :targeted),
      active_pains: Map.put(state.active_pains, signal.source, signal)
    }
  end
  
  defp handle_pain(signal, state) do
    Logger.info("Pain signal detected - monitoring and adjusting")
    
    # Request S4 analysis
    Intelligence.analyze_issue(signal)
    
    # Start monitoring intervention
    intervention_id = start_intervention(signal, :monitoring)
    
    %{state | 
      interventions: Map.put(state.interventions, intervention_id, :monitoring),
      active_pains: Map.put(state.active_pains, signal.source, signal)
    }
  end
  
  defp handle_discomfort(signal, state) do
    Logger.debug("Discomfort noted - tracking for patterns")
    
    # Just track for pattern analysis
    record_for_learning(state, signal)
  end
  
  defp start_emergency_intervention(signal) do
    intervention_id = generate_intervention_id()
    
    # Execute emergency protocols
    Task.start(fn ->
      result = execute_emergency_protocol(signal)
      send(self(), {:intervention_complete, intervention_id, result})
    end)
    
    intervention_id
  end
  
  defp start_intervention(signal, type) do
    intervention_id = generate_intervention_id()
    
    Task.start(fn ->
      result = case type do
        :targeted -> execute_targeted_intervention(signal)
        :monitoring -> execute_monitoring_intervention(signal)
      end
      
      send(self(), {:intervention_complete, intervention_id, result})
    end)
    
    intervention_id
  end
  
  defp execute_emergency_protocol(signal) do
    # Implementation of emergency response
    :telemetry.execute(
      [:vsm, :algedonic, :emergency_protocol],
      %{severity: 1.0},
      %{signal: signal}
    )
    
    # Return result
    :success
  end
  
  defp execute_targeted_intervention(signal) do
    # Implementation of targeted intervention
    :success
  end
  
  defp execute_monitoring_intervention(signal) do
    # Implementation of monitoring intervention
    :success
  end
  
  defp activate_cascade_prevention(state, signal) do
    Logger.error("Activating cascade prevention protocols")
    
    %{state | 
      cascade_prevention: %{
        active: true,
        triggers: [signal | state.cascade_prevention.triggers],
        activated_at: DateTime.utc_now()
      },
      metrics: Map.update!(state.metrics, :cascade_prevented, &(&1 + 1))
    }
  end
  
  defp check_cascade_conditions(state, signal) do
    if cascade_risk_high?(state, signal) and not state.cascade_prevention.active do
      activate_cascade_prevention(state, signal)
    else
      state
    end
  end
  
  defp cascade_risk_high?(state, _signal) do
    # Check multiple failure indicators
    active_pain_count = map_size(state.active_pains)
    recent_pain_rate = calculate_recent_pain_rate(state)
    
    active_pain_count > 3 or recent_pain_rate > 0.5
  end
  
  defp calculate_recent_pain_rate(state) do
    recent = Enum.filter(state.pain_history, fn p ->
      DateTime.diff(DateTime.utc_now(), p.timestamp) < 300
    end)
    
    length(recent) / 5.0  # pains per minute
  end
  
  defp learn_from_pain(state, signal, diagnosis) do
    learning_entry = %{
      signal: signal,
      diagnosis: diagnosis,
      timestamp: DateTime.utc_now(),
      interventions: Map.keys(state.interventions),
      outcome: nil  # Will be updated when intervention completes
    }
    
    %{state | learning_data: [learning_entry | state.learning_data]}
  end
  
  defp record_pain(state, signal, pain_level) do
    pain_record = Map.merge(signal, %{
      pain_level: pain_level,
      recorded_at: DateTime.utc_now()
    })
    
    %{state | 
      pain_history: [pain_record | Enum.take(state.pain_history, 999)],
      metrics: Map.update!(state.metrics, :total_pains, &(&1 + 1))
    }
  end
  
  defp analyze_pain_patterns(history, timeframe) do
    filtered = filter_by_timeframe(history, timeframe)
    
    %{
      recurring: find_recurring_patterns(filtered),
      escalating: find_escalating_patterns(filtered),
      correlated: find_correlated_patterns(filtered),
      time_based: find_time_based_patterns(filtered)
    }
  end
  
  defp filter_by_timeframe(history, :last_hour) do
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
    Enum.filter(history, fn p -> DateTime.compare(p.timestamp, cutoff) == :gt end)
  end
  
  defp find_recurring_patterns(history) do
    history
    |> Enum.group_by(& &1.source)
    |> Enum.filter(fn {_, list} -> length(list) > 2 end)
    |> Map.new(fn {source, list} -> {source, length(list)} end)
  end
  
  defp find_escalating_patterns(history) do
    history
    |> Enum.group_by(& &1.source)
    |> Enum.filter(fn {_, list} -> 
      escalating_severity?(Enum.map(list, & &1.pain_level))
    end)
    |> Map.keys()
  end
  
  defp escalating_severity?(levels) do
    # Check if pain levels are increasing over time
    levels == Enum.sort(levels, &pain_level_compare/2)
  end
  
  defp pain_level_compare(:discomfort, _), do: true
  defp pain_level_compare(:pain, :discomfort), do: false
  defp pain_level_compare(:pain, _), do: true
  defp pain_level_compare(:acute_pain, level) when level in [:discomfort, :pain], do: false
  defp pain_level_compare(:acute_pain, _), do: true
  defp pain_level_compare(:agony, _), do: false
  
  defp find_correlated_patterns(history) do
    # Find patterns that occur together
    []  # Simplified for now
  end
  
  defp find_time_based_patterns(history) do
    # Find patterns based on time of occurrence
    []  # Simplified for now
  end
  
  defp identify_systemic_issues(patterns) do
    issues = []
    
    issues = if map_size(patterns.recurring) > 3 do
      [:multiple_recurring_issues | issues]
    else
      issues
    end
    
    issues = if length(patterns.escalating) > 0 do
      [:escalating_severity | issues]
    else
      issues
    end
    
    issues
  end
  
  defp concerning_patterns?(patterns) do
    map_size(patterns.recurring) > 3 or
    length(patterns.escalating) > 0
  end
  
  defp alert_concerning_patterns(patterns) do
    :telemetry.execute(
      [:vsm, :algedonic, :pattern_alert],
      %{concern_level: 0.8},
      %{patterns: patterns}
    )
  end
  
  defp calculate_overall_pain_level(state) do
    if map_size(state.active_pains) == 0 do
      :healthy
    else
      state.active_pains
      |> Map.values()
      |> Enum.map(& &1.pain_level)
      |> Enum.max_by(&pain_level_to_value/1)
    end
  end
  
  defp pain_level_to_value(:discomfort), do: 1
  defp pain_level_to_value(:pain), do: 2
  defp pain_level_to_value(:acute_pain), do: 3
  defp pain_level_to_value(:agony), do: 4
  defp pain_level_to_value(_), do: 0
  
  defp assess_cascade_risk(state) do
    cond do
      state.cascade_prevention.active -> :high
      map_size(state.active_pains) > 3 -> :medium
      length(state.pain_patterns.escalating) > 0 -> :medium
      true -> :low
    end
  end
  
  defp escalate_failed_intervention(intervention_id, state) do
    Logger.error("Intervention #{intervention_id} failed - escalating")
    
    # Escalate to S5
    Queen.intervention_failed(%{
      intervention_id: intervention_id,
      state: state
    })
    
    %{state | interventions: Map.delete(state.interventions, intervention_id)}
  end
  
  defp record_for_learning(state, signal) do
    %{state | learning_data: [signal | state.learning_data]}
  end
  
  defp generate_intervention_id do
    "intervention_#{:erlang.unique_integer([:positive])}"
  end
  
  defp default_thresholds do
    %{
      error_rate: {0.1, :alert_s3},
      latency_ms: {5000, :alert_s3},
      memory_usage: {0.9, :emergency_intervention},
      cpu_usage: {0.95, :emergency_intervention}
    }
  end
  
  defp assess_impact_scope(signal) do
    # Determine how widespread the impact is
    data = Map.get(signal, :data, %{})
    
    cond do
      Map.get(data, :affected_systems, 0) > 5 -> :system_wide
      Map.get(data, :affected_systems, 0) > 2 -> :multiple_systems
      true -> :isolated
    end
  end
  
  defp find_related_issues(signal, state) do
    # Find issues that might be related
    state.pain_history
    |> Enum.filter(fn p ->
      DateTime.diff(signal.timestamp, p.timestamp) < 300 and
      similar_issue?(p, signal)
    end)
    |> Enum.map(& &1.source)
  end
  
  defp similar_issue?(pain1, pain2) do
    pain1.source == pain2.source or
    (pain1.diagnosis && pain2.diagnosis && 
     pain1.diagnosis.root_cause == pain2.diagnosis.root_cause)
  end
  
  defp recommend_action(signal, _state) do
    case signal.diagnosis.root_cause do
      :resource_exhaustion -> :scale_resources
      :performance_degradation -> :optimize_performance
      :variety_imbalance -> :rebalance_variety
      :security_breach -> :security_lockdown
      :cascade_failure -> :emergency_intervention
      _ -> :investigate
    end
  end
  
  defp calculate_urgency(signal) do
    intensity = Map.get(signal, :intensity, :medium)
    
    case intensity do
      :critical -> :immediate
      :high -> :urgent
      :medium -> :normal
      _ -> :low
    end
  end
end