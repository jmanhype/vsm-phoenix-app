defmodule VsmPhoenix.System4.VarietyExplosionDetector do
  @moduledoc """
  Variety Explosion Detector for System 4 Intelligence.
  
  This module detects and manages variety explosions - situations where
  the environmental variety exceeds the system's regulatory capacity,
  potentially triggering meta-system spawning or emergency adaptations.
  
  Features:
  - Real-time variety monitoring
  - Explosion threshold detection
  - Cascade prediction
  - Meta-system triggering
  - Variety absorption strategies
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System4.QuantumVarietyAnalyzer
  alias VsmPhoenix.System4.EmergentPatternDetector
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.System3.Control
  
  @name __MODULE__
  @explosion_threshold 0.85
  @cascade_threshold 0.75
  @critical_variety_ratio 3.0  # External variety / Internal variety
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def monitor_variety(variety_data) do
    GenServer.call(@name, {:monitor_variety, variety_data})
  end
  
  def check_explosion_risk do
    GenServer.call(@name, :check_explosion_risk)
  end
  
  def predict_cascade(current_variety) do
    GenServer.call(@name, {:predict_cascade, current_variety})
  end
  
  def trigger_emergency_response(explosion_data) do
    GenServer.cast(@name, {:emergency_response, explosion_data})
  end
  
  def get_variety_state do
    GenServer.call(@name, :get_variety_state)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("💥 Variety Explosion Detector initializing...")
    
    state = %{
      variety_history: [],
      current_variety_level: 0.0,
      internal_variety_capacity: 1.0,
      explosion_events: [],
      cascade_predictions: [],
      absorption_strategies: load_absorption_strategies(),
      emergency_protocols: load_emergency_protocols(),
      variety_metrics: %{
        peak_variety: 0.0,
        average_variety: 0.0,
        explosion_count: 0,
        cascade_events: 0,
        absorption_rate: 0.7,
        recovery_time: 0
      },
      monitoring_active: true
    }
    
    # Schedule periodic variety assessment
    schedule_variety_assessment()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:monitor_variety, variety_data}, _from, state) do
    Logger.info("💥 Monitoring variety levels")
    
    # Calculate variety metrics
    external_variety = calculate_external_variety(variety_data)
    variety_ratio = external_variety / state.internal_variety_capacity
    
    # Check for explosion
    explosion_risk = assess_explosion_risk(variety_ratio, state)
    
    # Update history
    new_history = [{DateTime.utc_now(), external_variety} | state.variety_history]
    |> Enum.take(1000)
    
    # Prepare response
    monitoring_result = %{
      external_variety: external_variety,
      internal_capacity: state.internal_variety_capacity,
      variety_ratio: variety_ratio,
      explosion_risk: explosion_risk,
      recommended_action: recommend_action(explosion_risk, variety_ratio),
      absorption_capability: calculate_absorption_capability(state)
    }
    
    # Update state
    new_state = %{state |
      variety_history: new_history,
      current_variety_level: external_variety
    }
    
    # Trigger responses if needed
    new_state = if explosion_risk > @explosion_threshold do
      Logger.warning("💥🚨 VARIETY EXPLOSION IMMINENT! Risk: #{explosion_risk}")
      handle_explosion_threat(monitoring_result, new_state)
    else
      new_state
    end
    
    {:reply, {:ok, monitoring_result}, new_state}
  end
  
  @impl true
  def handle_call(:check_explosion_risk, _from, state) do
    Logger.info("💥 Checking explosion risk")
    
    risk_assessment = %{
      current_risk: calculate_current_risk(state),
      trend: analyze_variety_trend(state.variety_history),
      time_to_explosion: estimate_time_to_explosion(state),
      cascade_probability: calculate_cascade_probability(state),
      mitigation_options: generate_mitigation_options(state)
    }
    
    {:reply, {:ok, risk_assessment}, state}
  end
  
  @impl true
  def handle_call({:predict_cascade, current_variety}, _from, state) do
    Logger.info("💥 Predicting variety cascade effects")
    
    cascade_prediction = %{
      initial_variety: current_variety,
      cascade_stages: predict_cascade_stages(current_variety, state),
      affected_systems: identify_affected_systems(current_variety),
      peak_variety: predict_peak_variety(current_variety, state),
      duration: estimate_cascade_duration(current_variety),
      containment_probability: calculate_containment_probability(current_variety, state)
    }
    
    # Store prediction
    new_predictions = [cascade_prediction | state.cascade_predictions] |> Enum.take(50)
    new_state = %{state | cascade_predictions: new_predictions}
    
    {:reply, {:ok, cascade_prediction}, new_state}
  end
  
  @impl true
  def handle_call(:get_variety_state, _from, state) do
    variety_summary = %{
      current_level: state.current_variety_level,
      internal_capacity: state.internal_variety_capacity,
      variety_ratio: state.current_variety_level / state.internal_variety_capacity,
      explosion_events: length(state.explosion_events),
      cascade_predictions: length(state.cascade_predictions),
      metrics: state.variety_metrics,
      monitoring_active: state.monitoring_active
    }
    
    {:reply, {:ok, variety_summary}, state}
  end
  
  @impl true
  def handle_cast({:emergency_response, explosion_data}, state) do
    Logger.warning("💥🚨 EXECUTING EMERGENCY VARIETY RESPONSE!")
    
    # Select emergency protocol
    protocol = select_emergency_protocol(explosion_data, state.emergency_protocols)
    
    # Execute protocol
    response_result = execute_emergency_protocol(protocol, explosion_data, state)
    
    # Record explosion event
    event = %{
      timestamp: DateTime.utc_now(),
      explosion_data: explosion_data,
      protocol_used: protocol,
      response_result: response_result
    }
    
    new_events = [event | state.explosion_events] |> Enum.take(100)
    
    # Update metrics
    new_metrics = update_explosion_metrics(state.variety_metrics, event)
    
    new_state = %{state |
      explosion_events: new_events,
      variety_metrics: new_metrics
    }
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:assess_variety, state) do
    # Periodic variety assessment
    current_ratio = state.current_variety_level / state.internal_variety_capacity
    
    new_state = if current_ratio > @critical_variety_ratio do
      Logger.warning("💥 Critical variety ratio detected: #{current_ratio}")
      
      # Auto-trigger cascade prediction
      {:ok, cascade} = handle_call({:predict_cascade, state.current_variety_level}, nil, state)
      |> elem(1)
      
      # Notify System 5 if cascade is likely
      if cascade.containment_probability < 0.5 do
        notify_system5_cascade_risk(cascade)
      end
      
      state
    else
      state
    end
    
    # Update internal variety capacity based on learning
    new_capacity = adapt_internal_variety(state)
    new_state = %{new_state | internal_variety_capacity: new_capacity}
    
    # Schedule next assessment
    schedule_variety_assessment()
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp calculate_external_variety(variety_data) do
    # Calculate total external variety
    factors = [
      map_size(variety_data[:novel_patterns] || %{}) * 0.3,
      length(variety_data[:emergent_properties] || []) * 0.2,
      length(variety_data[:recursive_potential] || []) * 0.25,
      map_size(variety_data[:meta_system_seeds] || %{}) * 0.25
    ]
    
    base_variety = Enum.sum(factors)
    
    # Apply quantum amplification if present
    if variety_data[:quantum_superposition] do
      base_variety * 1.5
    else
      base_variety
    end
  end
  
  defp assess_explosion_risk(variety_ratio, state) do
    # Assess risk of variety explosion
    base_risk = min(variety_ratio / @critical_variety_ratio, 1.0)
    
    # Adjust for trend
    trend_factor = case analyze_variety_trend(state.variety_history) do
      :increasing -> 1.2
      :stable -> 1.0
      :decreasing -> 0.8
    end
    
    # Adjust for absorption capacity
    absorption_factor = 1.0 - state.variety_metrics.absorption_rate
    
    (base_risk * trend_factor * (1 + absorption_factor))
    |> min(1.0)
  end
  
  defp analyze_variety_trend(history) do
    # Analyze trend in variety levels
    if length(history) < 3 do
      :stable
    else
      recent = Enum.take(history, 10)
      values = Enum.map(recent, fn {_, v} -> v end)
      
      # Simple trend detection
      first_half = Enum.take(values, div(length(values), 2))
      second_half = Enum.drop(values, div(length(values), 2))
      
      first_avg = Enum.sum(first_half) / length(first_half)
      second_avg = Enum.sum(second_half) / length(second_half)
      
      cond do
        second_avg > first_avg * 1.1 -> :increasing
        second_avg < first_avg * 0.9 -> :decreasing
        true -> :stable
      end
    end
  end
  
  defp recommend_action(explosion_risk, variety_ratio) do
    # Recommend action based on risk and ratio
    cond do
      explosion_risk > 0.9 -> :immediate_meta_system_spawn
      explosion_risk > 0.7 -> :emergency_absorption
      variety_ratio > 2.0 -> :increase_internal_variety
      variety_ratio > 1.5 -> :selective_filtering
      true -> :monitor
    end
  end
  
  defp calculate_absorption_capability(state) do
    # Calculate current absorption capability
    base_capability = state.variety_metrics.absorption_rate
    
    # Adjust for current load
    load_factor = 1.0 - (state.current_variety_level / 10.0)
    |> max(0.1)
    
    base_capability * load_factor
  end
  
  defp handle_explosion_threat(monitoring_result, state) do
    # Handle imminent variety explosion
    Logger.warning("💥 Handling variety explosion threat")
    
    # Select absorption strategy
    strategy = select_absorption_strategy(monitoring_result, state.absorption_strategies)
    
    # Execute strategy
    case execute_absorption_strategy(strategy, monitoring_result, state) do
      {:ok, absorbed_variety} ->
        Logger.info("💥 Successfully absorbed #{absorbed_variety} variety units")
        
        # Update metrics
        new_metrics = Map.update!(state.variety_metrics, :absorption_rate, fn rate ->
          rate * 0.9 + 0.1  # Improve absorption rate
        end)
        
        %{state | variety_metrics: new_metrics}
        
      {:error, :capacity_exceeded} ->
        Logger.error("💥 VARIETY ABSORPTION FAILED - TRIGGERING META-SYSTEM!")
        
        # Trigger meta-system spawning
        trigger_meta_system_spawn(monitoring_result)
        
        # Record explosion
        event = %{
          timestamp: DateTime.utc_now(),
          variety_level: monitoring_result.external_variety,
          type: :uncontrolled_explosion
        }
        
        %{state | explosion_events: [event | state.explosion_events]}
    end
  end
  
  defp select_absorption_strategy(monitoring_result, strategies) do
    # Select appropriate absorption strategy
    ratio = monitoring_result.variety_ratio
    
    cond do
      ratio > 3.0 -> strategies.emergency_absorption
      ratio > 2.0 -> strategies.selective_absorption  
      ratio > 1.5 -> strategies.gradual_absorption
      true -> strategies.normal_absorption
    end
  end
  
  defp execute_absorption_strategy(strategy, monitoring_result, state) do
    # Execute variety absorption strategy
    Logger.info("💥 Executing absorption strategy: #{strategy.name}")
    
    absorption_capacity = calculate_absorption_capability(state)
    variety_to_absorb = monitoring_result.external_variety
    
    if variety_to_absorb <= absorption_capacity do
      # Can absorb the variety
      absorbed = min(variety_to_absorb, absorption_capacity)
      
      # Apply strategy-specific absorption
      case strategy.type do
        :emergency ->
          # Emergency absorption - accept all variety
          {:ok, absorbed}
          
        :selective ->
          # Selective absorption - filter harmful variety
          filtered = absorbed * 0.7
          {:ok, filtered}
          
        :gradual ->
          # Gradual absorption over time
          gradual = absorbed * 0.5
          {:ok, gradual}
          
        _ ->
          {:ok, absorbed * 0.3}
      end
    else
      # Cannot absorb - capacity exceeded
      {:error, :capacity_exceeded}
    end
  end
  
  defp trigger_meta_system_spawn(monitoring_result) do
    # Trigger spawning of meta-system to handle variety
    Logger.warning("💥🌀 TRIGGERING META-SYSTEM SPAWN FOR VARIETY MANAGEMENT")
    
    spawn_config = %{
      reason: :variety_explosion,
      variety_level: monitoring_result.external_variety,
      variety_ratio: monitoring_result.variety_ratio,
      urgency: :critical,
      meta_system_type: :variety_absorber
    }
    
    # Notify System 5 Queen
    Queen.spawn_meta_system_emergency(spawn_config)
  end
  
  defp calculate_current_risk(state) do
    # Calculate current explosion risk
    ratio = state.current_variety_level / state.internal_variety_capacity
    assess_explosion_risk(ratio, state)
  end
  
  defp estimate_time_to_explosion(state) do
    # Estimate time until variety explosion
    if length(state.variety_history) < 2 do
      :infinity
    else
      # Calculate rate of variety increase
      recent = Enum.take(state.variety_history, 10)
      
      if length(recent) < 2 do
        :infinity
      else
        [{t1, v1} | rest] = recent
        {t2, v2} = List.last(rest)
        
        time_diff = DateTime.diff(t1, t2, :second)
        variety_diff = v1 - v2
        
        if variety_diff <= 0 do
          :infinity
        else
          rate = variety_diff / time_diff  # variety per second
          
          # Calculate remaining capacity
          remaining = state.internal_variety_capacity * @critical_variety_ratio - state.current_variety_level
          
          if remaining <= 0 do
            0  # Already at explosion point
          else
            round(remaining / rate)  # seconds to explosion
          end
        end
      end
    end
  end
  
  defp calculate_cascade_probability(state) do
    # Calculate probability of variety cascade
    current_ratio = state.current_variety_level / state.internal_variety_capacity
    
    if current_ratio > @cascade_threshold do
      # Exponential increase above threshold
      base_prob = (current_ratio - @cascade_threshold) / (1 - @cascade_threshold)
      min(base_prob * base_prob, 1.0)
    else
      0.0
    end
  end
  
  defp generate_mitigation_options(state) do
    # Generate variety mitigation options
    options = []
    
    # Option 1: Increase internal variety
    options = [%{
      action: :increase_internal_variety,
      effectiveness: 0.7,
      cost: :medium,
      time_to_effect: :immediate
    } | options]
    
    # Option 2: Filter external variety
    options = [%{
      action: :filter_external_variety,
      effectiveness: 0.5,
      cost: :low,
      time_to_effect: :immediate
    } | options]
    
    # Option 3: Spawn meta-system
    if state.current_variety_level > state.internal_variety_capacity * 2 do
      [%{
        action: :spawn_meta_system,
        effectiveness: 0.9,
        cost: :high,
        time_to_effect: :delayed
      } | options]
    else
      options
    end
  end
  
  defp predict_cascade_stages(initial_variety, state) do
    # Predict stages of variety cascade
    stages = []
    current = initial_variety
    capacity = state.internal_variety_capacity
    
    # Stage 1: Initial overload
    if current > capacity do
      stages = [%{
        stage: 1,
        description: "Initial variety overload",
        variety_level: current,
        system_impact: :moderate,
        duration: 100  # ms
      } | stages]
      
      current = current * 1.2  # Cascade amplification
    end
    
    # Stage 2: System stress
    if current > capacity * 1.5 do
      stages = [%{
        stage: 2,
        description: "System stress and degradation",
        variety_level: current,
        system_impact: :severe,
        duration: 500
      } | stages]
      
      current = current * 1.3
    end
    
    # Stage 3: Cascade propagation
    if current > capacity * 2 do
      stages = [%{
        stage: 3,
        description: "Cascade propagation to subsystems",
        variety_level: current,
        system_impact: :critical,
        duration: 1000
      } | stages]
      
      current = current * 1.5
    end
    
    # Stage 4: System collapse risk
    if current > capacity * 3 do
      stages = [%{
        stage: 4,
        description: "System collapse risk",
        variety_level: current,
        system_impact: :catastrophic,
        duration: :indefinite
      } | stages]
    end
    
    Enum.reverse(stages)
  end
  
  defp identify_affected_systems(variety_level) do
    # Identify which systems would be affected by cascade
    affected = []
    
    # System 3 affected first (operational control)
    affected = if variety_level > 1.0 do
      [:system3_control | affected]
    else
      affected
    end
    
    # System 1 affected at higher levels
    affected = if variety_level > 2.0 do
      [:system1_operations | affected]
    else
      affected
    end
    
    # System 2 coordination breakdown
    affected = if variety_level > 3.0 do
      [:system2_coordination | affected]
    else
      affected
    end
    
    # System 5 policy failure
    affected = if variety_level > 4.0 do
      [:system5_policy | affected]
    else
      affected
    end
    
    # Total system failure
    if variety_level > 5.0 do
      [:total_system_failure | affected]
    else
      affected
    end
  end
  
  defp predict_peak_variety(initial_variety, state) do
    # Predict peak variety during cascade
    amplification_factor = case analyze_variety_trend(state.variety_history) do
      :increasing -> 2.5
      :stable -> 1.8
      :decreasing -> 1.3
    end
    
    initial_variety * amplification_factor
  end
  
  defp estimate_cascade_duration(variety_level) do
    # Estimate how long cascade would last
    # Higher variety = longer cascade
    base_duration = 1000  # 1 second base
    
    (base_duration * variety_level)
    |> round()
  end
  
  defp calculate_containment_probability(variety_level, state) do
    # Calculate probability of containing the cascade
    absorption_capability = calculate_absorption_capability(state)
    
    if variety_level <= absorption_capability do
      0.9  # High containment probability
    else
      ratio = absorption_capability / variety_level
      max(ratio * ratio, 0.1)  # Quadratic decay
    end
  end
  
  defp load_absorption_strategies do
    # Load variety absorption strategies
    %{
      normal_absorption: %{
        name: "Normal Absorption",
        type: :normal,
        capacity_multiplier: 1.0,
        filter_rate: 0.3
      },
      gradual_absorption: %{
        name: "Gradual Absorption",
        type: :gradual,
        capacity_multiplier: 1.2,
        filter_rate: 0.5
      },
      selective_absorption: %{
        name: "Selective Absorption",
        type: :selective,
        capacity_multiplier: 1.5,
        filter_rate: 0.7
      },
      emergency_absorption: %{
        name: "Emergency Absorption",
        type: :emergency,
        capacity_multiplier: 2.0,
        filter_rate: 0.0  # Accept everything
      }
    }
  end
  
  defp load_emergency_protocols do
    # Load emergency response protocols
    %{
      meta_spawn: %{
        name: "Meta-System Spawn",
        trigger_threshold: 0.9,
        actions: [:spawn_meta_system, :redistribute_variety]
      },
      emergency_filter: %{
        name: "Emergency Filtering",
        trigger_threshold: 0.7,
        actions: [:activate_filters, :reduce_inputs]
      },
      cascade_prevention: %{
        name: "Cascade Prevention",
        trigger_threshold: 0.75,
        actions: [:isolate_subsystems, :activate_dampeners]
      },
      controlled_degradation: %{
        name: "Controlled Degradation",
        trigger_threshold: 0.6,
        actions: [:reduce_functionality, :preserve_core]
      }
    }
  end
  
  defp select_emergency_protocol(explosion_data, protocols) do
    # Select appropriate emergency protocol
    risk = explosion_data[:explosion_risk] || 1.0
    
    protocols
    |> Enum.filter(fn {_, protocol} ->
      risk >= protocol.trigger_threshold
    end)
    |> Enum.max_by(fn {_, protocol} ->
      protocol.trigger_threshold
    end, fn -> {:none, %{name: "None", actions: []}} end)
    |> elem(1)
  end
  
  defp execute_emergency_protocol(protocol, explosion_data, state) do
    Logger.warning("💥 Executing emergency protocol: #{protocol.name}")
    
    # Execute each action in the protocol
    results = Enum.map(protocol.actions, fn action ->
      execute_protocol_action(action, explosion_data, state)
    end)
    
    %{
      protocol: protocol.name,
      actions_executed: protocol.actions,
      results: results,
      success: Enum.all?(results, fn {status, _} -> status == :ok end)
    }
  end
  
  defp execute_protocol_action(action, explosion_data, state) do
    case action do
      :spawn_meta_system ->
        trigger_meta_system_spawn(explosion_data)
        {:ok, :meta_system_triggered}
        
      :redistribute_variety ->
        redistribute_variety_load(explosion_data, state)
        {:ok, :variety_redistributed}
        
      :activate_filters ->
        activate_variety_filters(explosion_data)
        {:ok, :filters_activated}
        
      :reduce_inputs ->
        reduce_input_channels(explosion_data)
        {:ok, :inputs_reduced}
        
      :isolate_subsystems ->
        isolate_affected_subsystems(explosion_data)
        {:ok, :subsystems_isolated}
        
      :activate_dampeners ->
        activate_variety_dampeners()
        {:ok, :dampeners_active}
        
      :reduce_functionality ->
        reduce_system_functionality()
        {:ok, :functionality_reduced}
        
      :preserve_core ->
        preserve_core_functions()
        {:ok, :core_preserved}
        
      _ ->
        {:error, :unknown_action}
    end
  end
  
  defp redistribute_variety_load(explosion_data, _state) do
    # Redistribute variety across subsystems
    Logger.info("💥 Redistributing variety load across subsystems")
    
    # Notify System 3 to rebalance
    Control.redistribute_variety(explosion_data)
  end
  
  defp activate_variety_filters(_explosion_data) do
    # Activate variety filtering mechanisms
    Logger.info("💥 Activating variety filters")
    
    # This would interact with input systems
    :ok
  end
  
  defp reduce_input_channels(_explosion_data) do
    # Reduce number of input channels
    Logger.info("💥 Reducing input channels to manage variety")
    :ok
  end
  
  defp isolate_affected_subsystems(_explosion_data) do
    # Isolate subsystems to prevent cascade
    Logger.info("💥 Isolating affected subsystems")
    :ok
  end
  
  defp activate_variety_dampeners do
    # Activate dampening mechanisms
    Logger.info("💥 Activating variety dampeners")
    :ok
  end
  
  defp reduce_system_functionality do
    # Reduce non-essential functionality
    Logger.info("💥 Reducing system functionality to essential operations")
    :ok
  end
  
  defp preserve_core_functions do
    # Preserve core system functions
    Logger.info("💥 Preserving core system functions")
    :ok
  end
  
  defp update_explosion_metrics(metrics, event) do
    # Update metrics after explosion event
    %{metrics |
      explosion_count: metrics.explosion_count + 1,
      peak_variety: max(metrics.peak_variety, event.explosion_data[:external_variety] || 0)
    }
  end
  
  defp notify_system5_cascade_risk(cascade) do
    # Notify System 5 of cascade risk
    Logger.warning("💥 Notifying System 5 of cascade risk")
    
    Queen.handle_cascade_risk(%{
      cascade_prediction: cascade,
      urgency: :high,
      recommended_action: :preemptive_meta_spawn
    })
  end
  
  defp adapt_internal_variety(state) do
    # Adapt internal variety capacity based on experience
    current_capacity = state.internal_variety_capacity
    
    # Learn from explosion events
    if length(state.explosion_events) > 0 do
      # Increase capacity after explosions
      current_capacity * 1.05
    else
      # Gradual increase if stable
      if state.current_variety_level < current_capacity * 0.5 do
        current_capacity * 0.98  # Reduce if underutilized
      else
        current_capacity * 1.01  # Slight increase
      end
    end
    |> max(0.5)  # Minimum capacity
    |> min(10.0)  # Maximum capacity
  end
  
  defp schedule_variety_assessment do
    Process.send_after(self(), :assess_variety, 5_000)  # Every 5 seconds
  end
end