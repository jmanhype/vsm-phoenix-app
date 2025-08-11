defmodule VsmPhoenix.System5.Viability.ViabilityEvaluator do
  @moduledoc """
  Viability Evaluator - Handles system viability assessment for System 5.
  
  Extracted from Queen god object to follow Single Responsibility Principle.
  Responsible ONLY for:
  - System health assessment and viability calculations
  - Viability index computation and monitoring  
  - Intervention triggers and health recovery
  - Viability trend analysis and prediction
  """
  
  use GenServer
  require Logger
  
  @behaviour VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  
  alias Phoenix.PubSub
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System2.Coordinator
  
  @name __MODULE__
  @evaluation_interval 30_000  # 30 seconds
  @history_retention_count 100
  
  # Viability thresholds
  @critical_threshold 0.3
  @warning_threshold 0.5
  @target_viability 0.8
  @optimal_threshold 0.9
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def evaluate_viability do
    GenServer.call(@name, :evaluate_viability)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def calculate_viability_index(current_metrics, historical_data \\ %{}) do
    GenServer.call(@name, {:calculate_viability_index, current_metrics, historical_data})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def requires_intervention do
    GenServer.call(@name, :requires_intervention)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def initiate_intervention(viability_data) do
    GenServer.cast(@name, {:initiate_intervention, viability_data})
    :ok
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def get_viability_trends(time_window \\ 3600_000) do  # 1 hour default
    GenServer.call(@name, {:get_viability_trends, time_window})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def calculate_resilience_score do
    GenServer.call(@name, :calculate_resilience_score)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def predict_viability(prediction_horizon \\ 1800_000) do  # 30 minutes default
    GenServer.call(@name, {:predict_viability, prediction_horizon})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.ViabilityEvaluator
  def get_evaluation_metrics do
    GenServer.call(@name, :get_evaluation_metrics)
  rescue
    e -> {:error, e}
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Schedule periodic viability evaluation
    Process.send_after(self(), :periodic_evaluation, @evaluation_interval)
    
    state = %{
      current_viability: nil,
      viability_history: [],
      last_evaluation: nil,
      intervention_history: [],
      metrics: initialize_metrics(),
      trend_cache: nil,
      resilience_cache: nil
    }
    
    Logger.info("💓 Viability Evaluator initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_call(:evaluate_viability, _from, state) do
    try do
      viability_data = perform_viability_evaluation(state)
      
      # Update state with new evaluation
      new_state = %{state |
        current_viability: viability_data,
        last_evaluation: System.system_time(:millisecond),
        viability_history: update_history(state.viability_history, viability_data),
        metrics: update_metrics(state.metrics, :evaluation_performed)
      }
      
      Logger.debug("💓 Viability evaluated: #{viability_data.viability_index}")
      {:reply, {:ok, viability_data}, new_state}
      
    rescue
      e ->
        Logger.error("💓 Viability evaluation failed: #{inspect(e)}")
        {:reply, {:error, {:evaluation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:calculate_viability_index, current_metrics, historical_data}, _from, state) do
    try do
      viability_index = calculate_viability_index_internal(current_metrics, historical_data)
      new_metrics = update_metrics(state.metrics, :index_calculated)
      
      new_state = %{state | metrics: new_metrics}
      {:reply, {:ok, viability_index}, new_state}
      
    rescue
      e ->
        Logger.error("💓 Viability index calculation failed: #{inspect(e)}")
        {:reply, {:error, {:calculation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call(:requires_intervention, _from, state) do
    intervention_type = case state.current_viability do
      %{viability_index: index} when index <= @critical_threshold -> :emergency
      %{viability_index: index} when index <= @warning_threshold -> :urgent
      %{trend: :declining, viability_index: index} when index <= 0.6 -> :maintenance
      _ -> :none
    end
    
    {:reply, {:ok, intervention_type}, state}
  end
  
  @impl true
  def handle_call({:get_viability_trends, time_window}, _from, state) do
    try do
      trends = analyze_viability_trends(state.viability_history, time_window)
      new_state = %{state | trend_cache: {trends, System.system_time(:millisecond)}}
      
      {:reply, {:ok, trends}, new_state}
      
    rescue
      e ->
        Logger.error("💓 Trend analysis failed: #{inspect(e)}")
        {:reply, {:error, {:trend_analysis_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call(:calculate_resilience_score, _from, state) do
    try do
      resilience_score = calculate_resilience_score_internal(state.viability_history)
      new_state = %{state | resilience_cache: {resilience_score, System.system_time(:millisecond)}}
      
      {:reply, {:ok, resilience_score}, new_state}
      
    rescue
      e ->
        Logger.error("💓 Resilience calculation failed: #{inspect(e)}")
        {:reply, {:error, {:resilience_calculation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:predict_viability, prediction_horizon}, _from, state) do
    try do
      predicted_viability = predict_viability_internal(state.viability_history, prediction_horizon)
      {:reply, {:ok, predicted_viability}, state}
      
    rescue
      e ->
        Logger.error("💓 Viability prediction failed: #{inspect(e)}")
        {:reply, {:error, {:prediction_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call(:get_evaluation_metrics, _from, state) do
    enhanced_metrics = enhance_metrics(state.metrics, state)
    {:reply, {:ok, enhanced_metrics}, state}
  end
  
  @impl true
  def handle_cast({:initiate_intervention, viability_data}, state) do
    intervention_result = perform_intervention(viability_data)
    
    # Record intervention
    intervention_record = %{
      viability_data: viability_data,
      intervention_type: determine_intervention_type(viability_data),
      timestamp: System.system_time(:millisecond),
      result: intervention_result,
      intervention_id: generate_intervention_id()
    }
    
    new_intervention_history = [intervention_record | state.intervention_history] |> Enum.take(50)
    new_metrics = update_metrics(state.metrics, :intervention_initiated)
    
    new_state = %{state |
      intervention_history: new_intervention_history,
      metrics: new_metrics
    }
    
    Logger.info("💓 Health intervention initiated: #{intervention_record.intervention_type}")
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:periodic_evaluation, state) do
    # Perform automatic viability evaluation
    try do
      viability_data = perform_viability_evaluation(state)
      
      # Check if intervention is needed
      if viability_data.viability_index <= @critical_threshold do
        perform_intervention(viability_data)
      end
      
      # Update state
      new_state = %{state |
        current_viability: viability_data,
        last_evaluation: System.system_time(:millisecond),
        viability_history: update_history(state.viability_history, viability_data),
        metrics: update_metrics(state.metrics, :periodic_evaluation)
      }
      
      # Schedule next evaluation
      Process.send_after(self(), :periodic_evaluation, @evaluation_interval)
      
      {:noreply, new_state}
      
    rescue
      e ->
        Logger.error("💓 Periodic evaluation failed: #{inspect(e)}")
        # Still schedule next evaluation
        Process.send_after(self(), :periodic_evaluation, @evaluation_interval)
        {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp initialize_metrics do
    %{
      evaluations_performed: 0,
      indices_calculated: 0,
      interventions_initiated: 0,
      periodic_evaluations: 0,
      trend_analyses: 0,
      resilience_calculations: 0,
      predictions_made: 0,
      last_activity: System.system_time(:millisecond),
      uptime: System.system_time(:millisecond)
    }
  end
  
  defp update_metrics(metrics, operation) do
    updated_metrics = case operation do
      :evaluation_performed -> %{metrics | evaluations_performed: metrics.evaluations_performed + 1}
      :index_calculated -> %{metrics | indices_calculated: metrics.indices_calculated + 1}
      :intervention_initiated -> %{metrics | interventions_initiated: metrics.interventions_initiated + 1}
      :periodic_evaluation -> %{metrics | periodic_evaluations: metrics.periodic_evaluations + 1}
      :trend_analysis -> %{metrics | trend_analyses: metrics.trend_analyses + 1}
      :resilience_calculation -> %{metrics | resilience_calculations: metrics.resilience_calculations + 1}
      :prediction_made -> %{metrics | predictions_made: metrics.predictions_made + 1}
    end
    
    %{updated_metrics | last_activity: System.system_time(:millisecond)}
  end
  
  defp perform_viability_evaluation(state) do
    # Gather metrics from all VSM systems
    system_metrics = gather_system_metrics()
    
    # Calculate viability components
    system_health = calculate_system_health(system_metrics)
    resource_availability = calculate_resource_availability(system_metrics)
    adaptation_capability = calculate_adaptation_capability(system_metrics)
    variety_balance = calculate_variety_balance(system_metrics)
    algedonic_state = get_algedonic_state()
    
    # Calculate overall viability index
    viability_index = calculate_viability_index_internal(system_metrics, %{history: state.viability_history})
    
    # Determine trend
    trend = determine_viability_trend(state.viability_history, viability_index)
    
    # Create comprehensive viability data
    %{
      viability_index: viability_index,
      system_health: system_health,
      resource_availability: resource_availability,
      adaptation_capability: adaptation_capability,
      variety_balance: variety_balance,
      algedonic_state: algedonic_state,
      trend: trend,
      timestamp: System.system_time(:millisecond),
      requires_intervention: viability_index <= @warning_threshold,
      intervention_urgency: determine_intervention_urgency(viability_index),
      recommendations: generate_recommendations(viability_index, system_metrics)
    }
  end
  
  defp gather_system_metrics do
    # Safely gather metrics from all systems with fallbacks
    %{
      intelligence: safe_get_intelligence_metrics(),
      control: safe_get_control_metrics(),
      coordination: safe_get_coordination_metrics(),
      operations: safe_get_operations_metrics(),
      system_load: get_system_load(),
      memory_usage: get_memory_usage(),
      process_health: get_process_health(),
      message_queue_depth: get_message_queue_depth()
    }
  end
  
  defp safe_get_intelligence_metrics do
    try do
      Intelligence.get_metrics()
    rescue
      _ -> %{status: :unavailable, health_score: 0.5}
    end
  end
  
  defp safe_get_control_metrics do
    try do
      Control.get_metrics()
    rescue
      _ -> %{status: :unavailable, health_score: 0.5}
    end
  end
  
  defp safe_get_coordination_metrics do
    try do
      Coordinator.get_metrics()
    rescue
      _ -> %{status: :unavailable, health_score: 0.5}
    end
  end
  
  defp safe_get_operations_metrics do
    try do
      # Would call System1.Operations.get_metrics() if available
      %{status: :operational, health_score: 0.7}
    rescue
      _ -> %{status: :unavailable, health_score: 0.5}
    end
  end
  
  defp get_system_load do
    # Get current system load (CPU, memory, etc.)
    case :cpu_sup.avg1() do
      load when is_number(load) -> load / 100
      _ -> 0.5
    end
  end
  
  defp get_memory_usage do
    # Get memory usage percentage
    case :memsup.get_system_memory_data() do
      data when is_list(data) ->
        total = Keyword.get(data, :total_memory, 1)
        available = Keyword.get(data, :available_memory, total)
        1.0 - (available / total)
      _ -> 0.5
    end
  end
  
  defp get_process_health do
    # Check process health across the system
    process_count = length(Process.list())
    # Normalized score based on process count
    min(process_count / 1000, 1.0)
  end
  
  defp get_message_queue_depth do
    # Check message queue depths for key processes
    key_processes = [VsmPhoenix.System5.Queen, VsmPhoenix.System4.Intelligence, VsmPhoenix.System3.Control]
    
    avg_depth = key_processes
                |> Enum.map(fn process ->
                  case Process.whereis(process) do
                    pid when is_pid(pid) ->
                      case Process.info(pid, :message_queue_len) do
                        {_, len} -> len
                        _ -> 0
                      end
                    _ -> 0
                  end
                end)
                |> Enum.sum()
                |> Kernel./(length(key_processes))
    
    # Normalize to 0-1 scale (assuming 100 messages is max healthy depth)
    min(avg_depth / 100, 1.0)
  end
  
  defp calculate_system_health(metrics) do
    # Weight different health factors
    intelligence_weight = 0.25
    control_weight = 0.25
    coordination_weight = 0.20
    operations_weight = 0.15
    process_weight = 0.15
    
    intelligence_health = Map.get(metrics.intelligence, :health_score, 0.5)
    control_health = Map.get(metrics.control, :health_score, 0.5)
    coordination_health = Map.get(metrics.coordination, :health_score, 0.5)
    operations_health = Map.get(metrics.operations, :health_score, 0.5)
    process_health = metrics.process_health
    
    (intelligence_health * intelligence_weight) +
    (control_health * control_weight) +
    (coordination_health * coordination_weight) +
    (operations_health * operations_weight) +
    (process_health * process_weight)
  end
  
  defp calculate_resource_availability(metrics) do
    # Consider CPU, memory, and message queue capacity
    cpu_availability = max(0.0, 1.0 - metrics.system_load)
    memory_availability = max(0.0, 1.0 - metrics.memory_usage)
    queue_availability = max(0.0, 1.0 - metrics.message_queue_depth)
    
    # Weighted average
    (cpu_availability * 0.4) + (memory_availability * 0.4) + (queue_availability * 0.2)
  end
  
  defp calculate_adaptation_capability(_metrics) do
    # Simplified - would be more sophisticated in practice
    # Based on system responsiveness and available adaptation mechanisms
    0.7
  end
  
  defp calculate_variety_balance(_metrics) do
    # Simplified - would integrate with Variety Engineering system
    0.6
  end
  
  defp get_algedonic_state do
    # Try to get algedonic state from the AlgedonicProcessor
    try do
      case VsmPhoenix.System5.Algedonic.SignalProcessor.get_algedonic_state() do
        state when is_map(state) -> state.viability_impact || 1.0
        _ -> 1.0
      end
    rescue
      _ -> 1.0
    end
  end
  
  defp calculate_viability_index_internal(system_metrics, historical_data) do
    # Calculate weighted viability index
    system_health = calculate_system_health(system_metrics)
    resource_availability = calculate_resource_availability(system_metrics)
    adaptation_capability = calculate_adaptation_capability(system_metrics)
    variety_balance = calculate_variety_balance(system_metrics)
    algedonic_impact = get_algedonic_state()
    
    # Historical trend adjustment
    trend_adjustment = calculate_trend_adjustment(historical_data)
    
    base_viability = (system_health * 0.3) +
                    (resource_availability * 0.25) +
                    (adaptation_capability * 0.2) +
                    (variety_balance * 0.15) +
                    (algedonic_impact * 0.1)
    
    # Apply trend adjustment
    final_viability = base_viability * (1.0 + trend_adjustment)
    
    # Clamp to valid range
    max(0.0, min(1.0, final_viability))
  end
  
  defp calculate_trend_adjustment(%{history: history}) when is_list(history) and length(history) >= 3 do
    recent_indices = history
                    |> Enum.take(5)
                    |> Enum.map(& &1.viability_index)
    
    if length(recent_indices) >= 2 do
      first = List.first(recent_indices)
      last = List.last(recent_indices)
      
      # Calculate trend slope (positive = improving, negative = declining)
      trend_slope = (first - last) / length(recent_indices)
      
      # Convert to adjustment factor (max ±10% adjustment)
      max(-0.1, min(0.1, trend_slope))
    else
      0.0
    end
  end
  defp calculate_trend_adjustment(_), do: 0.0
  
  defp determine_viability_trend(history, current_index) when is_list(history) and length(history) >= 2 do
    recent_indices = [current_index | Enum.take(history, 4)]
                    |> Enum.map(fn
                      %{viability_index: idx} -> idx
                      idx when is_number(idx) -> idx
                      _ -> current_index
                    end)
    
    if length(recent_indices) >= 3 do
      [latest, mid, oldest] = Enum.take(recent_indices, 3)
      
      cond do
        latest > mid and mid > oldest -> :improving
        latest < mid and mid < oldest -> :declining
        abs(latest - oldest) < 0.05 -> :stable
        latest > oldest -> :improving
        true -> :declining
      end
    else
      :stable
    end
  end
  defp determine_viability_trend(_, _), do: :stable
  
  defp determine_intervention_urgency(viability_index) do
    cond do
      viability_index <= @critical_threshold -> :critical
      viability_index <= @warning_threshold -> :high
      viability_index <= 0.6 -> :medium
      viability_index <= 0.7 -> :low
      true -> :none
    end
  end
  
  defp generate_recommendations(viability_index, system_metrics) do
    recommendations = []
    
    recommendations = if viability_index <= @critical_threshold do
      ["Immediate emergency intervention required" | recommendations]
    else
      recommendations
    end
    
    recommendations = if system_metrics.system_load > 0.8 do
      ["Reduce system load - consider scaling or load balancing" | recommendations]
    else
      recommendations
    end
    
    recommendations = if system_metrics.memory_usage > 0.9 do
      ["Memory usage critical - investigate memory leaks" | recommendations]
    else
      recommendations
    end
    
    recommendations
  end
  
  defp update_history(history, new_data) do
    [new_data | history] |> Enum.take(@history_retention_count)
  end
  
  defp analyze_viability_trends(history, time_window) do
    now = System.system_time(:millisecond)
    relevant_data = Enum.filter(history, fn data ->
      (now - data.timestamp) <= time_window
    end)
    
    if length(relevant_data) >= 3 do
      indices = Enum.map(relevant_data, & &1.viability_index)
      timestamps = Enum.map(relevant_data, & &1.timestamp)
      
      %{
        trend_direction: calculate_trend_direction(indices),
        average_viability: Enum.sum(indices) / length(indices),
        volatility: calculate_volatility(indices),
        data_points: length(relevant_data),
        time_span: List.last(timestamps) - List.first(timestamps),
        min_viability: Enum.min(indices),
        max_viability: Enum.max(indices)
      }
    else
      %{
        trend_direction: :insufficient_data,
        average_viability: 0.5,
        volatility: 0.0,
        data_points: length(relevant_data),
        time_span: 0,
        min_viability: 0.0,
        max_viability: 1.0
      }
    end
  end
  
  defp calculate_trend_direction(indices) do
    if length(indices) >= 3 do
      first_half = Enum.take(indices, div(length(indices), 2))
      second_half = Enum.drop(indices, div(length(indices), 2))
      
      first_avg = Enum.sum(first_half) / length(first_half)
      second_avg = Enum.sum(second_half) / length(second_half)
      
      cond do
        second_avg > first_avg + 0.02 -> :improving
        second_avg < first_avg - 0.02 -> :declining
        true -> :stable
      end
    else
      :stable
    end
  end
  
  defp calculate_volatility(indices) do
    if length(indices) >= 2 do
      mean = Enum.sum(indices) / length(indices)
      variance = indices
                |> Enum.map(&:math.pow(&1 - mean, 2))
                |> Enum.sum()
                |> Kernel./(length(indices))
      :math.sqrt(variance)
    else
      0.0
    end
  end
  
  defp calculate_resilience_score_internal(history) do
    # Analyze how well the system recovers from low viability periods
    if length(history) >= 10 do
      indices = Enum.map(history, & &1.viability_index)
      
      # Find low viability periods and recovery times
      recovery_scores = calculate_recovery_patterns(indices)
      
      # Average recovery performance
      if recovery_scores == [] do
        0.7  # Default resilience score
      else
        Enum.sum(recovery_scores) / length(recovery_scores)
      end
    else
      0.7  # Default when insufficient data
    end
  end
  
  defp calculate_recovery_patterns(indices) do
    # Simplified recovery pattern analysis
    # Look for periods where viability dropped below threshold and then recovered
    recovery_scores = []
    
    indices
    |> Enum.with_index()
    |> Enum.reduce(recovery_scores, fn {index, pos}, acc ->
      if index <= @warning_threshold and pos < length(indices) - 3 do
        # Found a low point, look for recovery in next few points
        future_indices = Enum.drop(indices, pos + 1) |> Enum.take(3)
        recovery_rate = calculate_recovery_rate(index, future_indices)
        [recovery_rate | acc]
      else
        acc
      end
    end)
  end
  
  defp calculate_recovery_rate(low_point, future_indices) do
    if future_indices != [] do
      max_recovery = Enum.max(future_indices)
      recovery_magnitude = max_recovery - low_point
      
      # Normalize recovery score (how much did it recover from low point)
      min(max(recovery_magnitude * 2, 0.0), 1.0)
    else
      0.5
    end
  end
  
  defp predict_viability_internal(history, prediction_horizon) do
    if length(history) >= 5 do
      recent_trend = analyze_viability_trends(history, 1800_000)  # Last 30 minutes
      current_viability = case List.first(history) do
        %{viability_index: idx} -> idx
        _ -> 0.5
      end
      
      # Simple linear extrapolation based on trend
      trend_factor = case recent_trend.trend_direction do
        :improving -> 0.1
        :declining -> -0.1
        :stable -> 0.0
        _ -> 0.0
      end
      
      # Apply volatility adjustment
      volatility_adjustment = recent_trend.volatility * 0.5
      
      predicted_index = current_viability + (trend_factor * (prediction_horizon / 1800_000))
      predicted_index = max(0.0, min(1.0, predicted_index))
      
      %{
        predicted_viability_index: predicted_index,
        confidence: max(0.1, 1.0 - volatility_adjustment),
        prediction_horizon: prediction_horizon,
        based_on_trend: recent_trend.trend_direction,
        timestamp: System.system_time(:millisecond),
        assumptions: ["Linear trend extrapolation", "Current volatility continues"]
      }
    else
      %{
        predicted_viability_index: 0.5,
        confidence: 0.1,
        prediction_horizon: prediction_horizon,
        based_on_trend: :insufficient_data,
        timestamp: System.system_time(:millisecond),
        assumptions: ["Insufficient historical data for prediction"]
      }
    end
  end
  
  defp enhance_metrics(metrics, state) do
    Map.merge(metrics, %{
      current_viability: state.current_viability,
      history_size: length(state.viability_history),
      intervention_count: length(state.intervention_history),
      last_evaluation: state.last_evaluation,
      uptime: System.system_time(:millisecond) - metrics.uptime,
      evaluation_frequency: calculate_evaluation_frequency(metrics),
      cache_status: %{
        trend_cache_age: get_cache_age(state.trend_cache),
        resilience_cache_age: get_cache_age(state.resilience_cache)
      }
    })
  end
  
  defp calculate_evaluation_frequency(metrics) do
    if metrics.evaluations_performed > 0 do
      uptime = System.system_time(:millisecond) - metrics.uptime
      metrics.evaluations_performed / (uptime / 1000)  # evaluations per second
    else
      0.0
    end
  end
  
  defp get_cache_age({_data, timestamp}) do
    System.system_time(:millisecond) - timestamp
  end
  defp get_cache_age(_), do: :no_cache
  
  defp determine_intervention_type(viability_data) do
    cond do
      viability_data.viability_index <= 0.2 -> :emergency
      viability_data.viability_index <= @critical_threshold -> :urgent
      viability_data.viability_index <= @warning_threshold -> :maintenance
      viability_data.trend == :declining -> :preventive
      true -> :none
    end
  end
  
  defp perform_intervention(viability_data) do
    intervention_type = determine_intervention_type(viability_data)
    
    Logger.warn("💓 Performing #{intervention_type} intervention (viability: #{viability_data.viability_index})")
    
    # Broadcast intervention signal
    PubSub.broadcast(VsmPhoenix.PubSub, "vsm:system5", {:viability_intervention, intervention_type, viability_data})
    PubSub.broadcast(VsmPhoenix.PubSub, "vsm:interventions", {:health_intervention, intervention_type, viability_data})
    
    case intervention_type do
      :emergency ->
        # Trigger emergency protocols
        perform_emergency_intervention(viability_data)
        
      :urgent ->
        # Trigger urgent recovery measures
        perform_urgent_intervention(viability_data)
        
      :maintenance ->
        # Schedule maintenance activities
        perform_maintenance_intervention(viability_data)
        
      :preventive ->
        # Implement preventive measures
        perform_preventive_intervention(viability_data)
        
      _ ->
        :no_intervention_needed
    end
  end
  
  defp perform_emergency_intervention(viability_data) do
    # Emergency intervention protocols
    try do
      # Would trigger emergency protocols in a real system
      Logger.error("💓 EMERGENCY INTERVENTION: Viability critically low (#{viability_data.viability_index})")
      :emergency_protocols_activated
    rescue
      e -> 
        Logger.error("💓 Emergency intervention failed: #{inspect(e)}")
        :intervention_failed
    end
  end
  
  defp perform_urgent_intervention(viability_data) do
    # Urgent intervention protocols
    try do
      Logger.warn("💓 URGENT INTERVENTION: Viability below threshold (#{viability_data.viability_index})")
      :urgent_protocols_activated
    rescue
      e ->
        Logger.error("💓 Urgent intervention failed: #{inspect(e)}")
        :intervention_failed
    end
  end
  
  defp perform_maintenance_intervention(viability_data) do
    # Maintenance intervention protocols
    Logger.info("💓 MAINTENANCE INTERVENTION: Preventive maintenance triggered (#{viability_data.viability_index})")
    :maintenance_scheduled
  end
  
  defp perform_preventive_intervention(viability_data) do
    # Preventive intervention protocols
    Logger.info("💓 PREVENTIVE INTERVENTION: Trend-based prevention (#{viability_data.viability_index})")
    :preventive_measures_applied
  end
  
  defp generate_intervention_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end