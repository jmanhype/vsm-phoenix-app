defmodule VsmPhoenix.VarietyEngineering.Metrics.BalanceMonitor do
  @moduledoc """
  Monitors variety balance across the VSM hierarchy.
  
  Implements Ashby's Law by ensuring each system level has
  requisite variety to handle its environment.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @check_interval 10_000  # 10 seconds
  @imbalance_threshold 0.3  # 30% deviation triggers alert
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def get_balance_status do
    GenServer.call(@name, :get_balance_status)
  end
  
  def set_alert_threshold(threshold) do
    GenServer.call(@name, {:set_threshold, threshold})
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("⚖️ Starting Variety Balance Monitor...")
    
    state = %{
      balance_status: %{
        s1: :balanced,
        s2: :balanced,
        s3: :balanced,
        s4: :balanced,
        s5: :balanced
      },
      alert_threshold: @imbalance_threshold,
      balance_history: [],
      alerts: []
    }
    
    # Subscribe to variety metrics
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:variety_metrics")
    
    # Schedule periodic balance check
    schedule_balance_check()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(:get_balance_status, _from, state) do
    status = %{
      current_balance: state.balance_status,
      alerts: Enum.take(state.alerts, 10),
      history: Enum.take(state.balance_history, 20),
      overall_health: calculate_overall_health(state.balance_status)
    }
    {:reply, status, state}
  end
  
  @impl true
  def handle_call({:set_threshold, threshold}, _from, state) do
    {:reply, :ok, %{state | alert_threshold: threshold}}
  end
  
  @impl true
  def handle_info(:check_balance, state) do
    # Get current variety metrics safely
    metrics = try do
      VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.get_all_metrics()
    rescue
      _ -> %{variety_metrics: %{}}
    end
    
    # Analyze balance for each level
    variety_metrics = Map.get(metrics || %{}, :variety_metrics, %{})
    new_balance_status = analyze_balance(variety_metrics, state.alert_threshold)
    
    # Generate alerts for imbalances
    new_alerts = generate_alerts(new_balance_status, state.balance_status)
    
    # Record history
    history_entry = %{
      timestamp: DateTime.utc_now(),
      balance: new_balance_status,
      metrics: metrics.variety_metrics
    }
    
    new_state = %{state |
      balance_status: new_balance_status,
      alerts: new_alerts ++ state.alerts,
      balance_history: [history_entry | state.balance_history] |> Enum.take(100)
    }
    
    # Broadcast balance status
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:variety_balance",
      {:balance_update, new_balance_status}
    )
    
    schedule_balance_check()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:variety_update, metrics}, state) do
    # React to variety metric updates
    new_balance_status = analyze_balance(metrics, state.alert_threshold)
    
    if critical_imbalance?(new_balance_status) do
      Logger.warning("⚠️ Critical variety imbalance detected!")
      trigger_rebalancing(new_balance_status, metrics)
    end
    
    {:noreply, %{state | balance_status: new_balance_status}}
  end
  
  # Private functions
  
  defp analyze_balance(metrics, threshold) do
    Enum.reduce([:s1, :s2, :s3, :s4, :s5], %{}, fn level, acc ->
      level_metrics = metrics[level]
      
      # Use entropy ratio for information-theoretic balance
      entropy_ratio = get_in(level_metrics, [:entropy, :ratio]) || level_metrics.ratio || 0
      
      # Consider volume imbalance as well
      volume_ratio = if level_metrics[:volume] do
        input_vol = level_metrics.volume.input || 0
        output_vol = level_metrics.volume.output || 0
        if input_vol > 0, do: output_vol / input_vol, else: 0
      else
        1.0
      end
      
      # Consider velocity for rapid changes
      velocity = level_metrics[:velocity] || 0
      
      # Determine status based on multiple factors
      status = cond do
        # Critical overload: high entropy ratio AND high volume
        entropy_ratio > (1.0 + threshold * 2) && volume_ratio > 1.5 -> :critical_overload
        
        # Overloaded: either high entropy or high volume
        entropy_ratio > (1.0 + threshold) || volume_ratio > (1.0 + threshold) -> :overloaded
        
        # Underloaded: low entropy ratio
        entropy_ratio < (1.0 - threshold) -> :underloaded
        
        # Unstable: rapid changes in variety
        abs(velocity) > 0.5 -> :unstable
        
        # Otherwise balanced
        true -> :balanced
      end
      
      Map.put(acc, level, %{
        status: status,
        entropy_ratio: entropy_ratio,
        volume_ratio: volume_ratio,
        velocity: velocity
      })
    end)
  end
  
  defp generate_alerts(new_status, old_status) do
    Enum.reduce([:s1, :s2, :s3, :s4, :s5], [], fn level, alerts ->
      new_level_status = new_status[level]
      old_level_status = if is_map(old_status[level]), do: old_status[level].status, else: old_status[level]
      
      if new_level_status.status != old_level_status && new_level_status.status != :balanced do
        alert = %{
          timestamp: DateTime.utc_now(),
          level: level,
          status: new_level_status.status,
          metrics: %{
            entropy_ratio: Float.round(new_level_status.entropy_ratio, 3),
            volume_ratio: Float.round(new_level_status.volume_ratio, 3),
            velocity: Float.round(new_level_status.velocity, 3)
          },
          message: format_alert_message(level, new_level_status)
        }
        [alert | alerts]
      else
        alerts
      end
    end)
  end
  
  defp format_alert_message(level, level_status) do
    status = if is_map(level_status), do: level_status.status, else: level_status
    
    base_msg = case status do
      :critical_overload ->
        "System #{level} is critically overloaded - immediate intervention required"
      :overloaded ->
        "System #{level} is overloaded - receiving more variety than it can process"
      :underloaded ->
        "System #{level} is underloaded - not receiving sufficient variety for effective operation"
      :unstable ->
        "System #{level} is unstable - rapid variety changes detected"
      _ ->
        "System #{level} status: #{status}"
    end
    
    if is_map(level_status) do
      "#{base_msg} (entropy: #{Float.round(level_status.entropy_ratio, 2)}, volume: #{Float.round(level_status.volume_ratio, 2)}, velocity: #{Float.round(level_status.velocity, 2)})"
    else
      base_msg
    end
  end
  
  defp calculate_overall_health(balance_status) do
    # Calculate health based on status and metrics
    health_scores = balance_status
    |> Map.values()
    |> Enum.map(fn level_status ->
      status = if is_map(level_status), do: level_status.status, else: level_status
      
      case status do
        :balanced -> 1.0
        :unstable -> 0.7
        :underloaded -> 0.5
        :overloaded -> 0.3
        :critical_overload -> 0.1
        _ -> 0.0
      end
    end)
    
    # Average health score
    if length(health_scores) > 0 do
      Enum.sum(health_scores) / length(health_scores)
    else
      0.0
    end
  end
  
  defp critical_imbalance?(balance_status) do
    # Critical if systems are critically overloaded or multiple systems imbalanced
    critical_count = balance_status
    |> Map.values()
    |> Enum.count(fn level_status ->
      status = if is_map(level_status), do: level_status.status, else: level_status
      status == :critical_overload
    end)
    
    imbalanced_count = balance_status
    |> Map.values()
    |> Enum.count(fn level_status ->
      status = if is_map(level_status), do: level_status.status, else: level_status
      status != :balanced
    end)
    
    critical_count > 0 || imbalanced_count > 2
  end
  
  defp trigger_rebalancing(balance_status, metrics) do
    # Notify variety engineering components to adjust filters/amplifiers
    Enum.each([:s1, :s2, :s3, :s4, :s5], fn level ->
      level_status = balance_status[level]
      status = if is_map(level_status), do: level_status.status, else: level_status
      
      adjustment_params = if is_map(level_status) do
        %{
          entropy_ratio: level_status.entropy_ratio,
          volume_ratio: level_status.volume_ratio,
          velocity: level_status.velocity,
          metrics: metrics[level]
        }
      else
        %{metrics: metrics[level]}
      end
      
      case status do
        :critical_overload ->
          # Emergency filtering
          adjust_boundary_filtering(level, :emergency_increase, adjustment_params)
          
        :overloaded ->
          # Increase filtering (attenuation)
          adjust_boundary_filtering(level, :increase, adjustment_params)
          
        :underloaded ->
          # Decrease filtering or increase amplification
          adjust_boundary_filtering(level, :decrease, adjustment_params)
          
        :unstable ->
          # Stabilize variety flow
          adjust_boundary_filtering(level, :stabilize, adjustment_params)
          
        _ ->
          :ok
      end
    end)
  end
  
  defp adjust_boundary_filtering(level, direction, params) do
    Logger.info("🔧 Adjusting variety #{direction} for #{level} with params: #{inspect(params)}")
    
    # Calculate adjustment magnitude based on metrics
    adjustment_magnitude = calculate_adjustment_magnitude(direction, params)
    
    # Notify appropriate filter/amplifier with magnitude
    case {level, direction} do
      {:s1, dir} when dir in [:increase, :emergency_increase] -> 
        VsmPhoenix.VarietyEngineering.Filters.S1ToS2.adjust_filtering(adjustment_magnitude)
        
      {:s2, dir} when dir in [:increase, :emergency_increase] -> 
        VsmPhoenix.VarietyEngineering.Filters.S2ToS3.adjust_filtering(adjustment_magnitude)
        
      {:s3, dir} when dir in [:increase, :emergency_increase] -> 
        VsmPhoenix.VarietyEngineering.Filters.S3ToS4.adjust_filtering(adjustment_magnitude)
        
      {:s4, dir} when dir in [:increase, :emergency_increase] -> 
        VsmPhoenix.VarietyEngineering.Filters.S4ToS5.adjust_filtering(adjustment_magnitude)
        
      {:s5, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S5ToS4.adjust_amplification(adjustment_magnitude)
        
      {:s4, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S4ToS3.adjust_amplification(adjustment_magnitude)
        
      {:s3, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S3ToS2.adjust_amplification(adjustment_magnitude)
        
      {:s2, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1.adjust_amplification(adjustment_magnitude)
        
      {level, :stabilize} ->
        # For unstable systems, adjust both directions slightly
        stabilize_system_variety(level, params)
        
      _ -> 
        :ok
    end
  end
  
  defp calculate_adjustment_magnitude(direction, params) do
    base_magnitude = case direction do
      :emergency_increase -> 2.0   # Double filtering
      :increase -> 1.3             # 30% increase
      :decrease -> 0.7             # 30% decrease
      :stabilize -> 1.0            # No change in magnitude
      _ -> 1.0
    end
    
    # Adjust based on how far from balance
    if params[:entropy_ratio] do
      deviation = abs(params.entropy_ratio - 1.0)
      base_magnitude * (1.0 + deviation)
    else
      base_magnitude
    end
  end
  
  defp stabilize_system_variety(level, params) do
    # Stabilize by dampening oscillations
    Logger.info("🎚️ Stabilizing variety for #{level}")
    
    # Small adjustments to both filter and amplifier
    case level do
      :s1 -> 
        VsmPhoenix.VarietyEngineering.Filters.S1ToS2.dampen_oscillations()
      :s2 ->
        VsmPhoenix.VarietyEngineering.Filters.S2ToS3.dampen_oscillations()
        VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1.dampen_oscillations()
      :s3 ->
        VsmPhoenix.VarietyEngineering.Filters.S3ToS4.dampen_oscillations()
        VsmPhoenix.VarietyEngineering.Amplifiers.S3ToS2.dampen_oscillations()
      :s4 ->
        VsmPhoenix.VarietyEngineering.Filters.S4ToS5.dampen_oscillations()
        VsmPhoenix.VarietyEngineering.Amplifiers.S4ToS3.dampen_oscillations()
      :s5 ->
        VsmPhoenix.VarietyEngineering.Amplifiers.S5ToS4.dampen_oscillations()
      _ ->
        :ok
    end
  end
  
  defp schedule_balance_check do
    Process.send_after(self(), :check_balance, @check_interval)
  end
end