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
    # Get current variety metrics
    metrics = VsmPhoenix.VarietyEngineering.Metrics.VarietyCalculator.get_all_metrics()
    
    # Analyze balance for each level
    new_balance_status = analyze_balance(metrics.variety_metrics, state.alert_threshold)
    
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
      ratio = metrics[level].ratio
      
      status = cond do
        ratio < (1.0 - threshold) -> :underloaded
        ratio > (1.0 + threshold) -> :overloaded
        true -> :balanced
      end
      
      Map.put(acc, level, status)
    end)
  end
  
  defp generate_alerts(new_status, old_status) do
    Enum.reduce([:s1, :s2, :s3, :s4, :s5], [], fn level, alerts ->
      if new_status[level] != old_status[level] && new_status[level] != :balanced do
        alert = %{
          timestamp: DateTime.utc_now(),
          level: level,
          status: new_status[level],
          message: format_alert_message(level, new_status[level])
        }
        [alert | alerts]
      else
        alerts
      end
    end)
  end
  
  defp format_alert_message(level, status) do
    case status do
      :overloaded ->
        "System #{level} is overloaded - receiving more variety than it can process"
      :underloaded ->
        "System #{level} is underloaded - not receiving sufficient variety for effective operation"
    end
  end
  
  defp calculate_overall_health(balance_status) do
    balanced_count = balance_status
                     |> Map.values()
                     |> Enum.count(& &1 == :balanced)
    
    balanced_count / 5.0  # Percentage of balanced systems
  end
  
  defp critical_imbalance?(balance_status) do
    # Critical if more than 2 systems are imbalanced
    imbalanced_count = balance_status
                       |> Map.values()
                       |> Enum.count(& &1 != :balanced)
    
    imbalanced_count > 2
  end
  
  defp trigger_rebalancing(balance_status, metrics) do
    # Notify variety engineering components to adjust filters/amplifiers
    Enum.each([:s1, :s2, :s3, :s4, :s5], fn level ->
      case balance_status[level] do
        :overloaded ->
          # Increase filtering (attenuation)
          adjust_boundary_filtering(level, :increase, metrics[level])
        :underloaded ->
          # Decrease filtering or increase amplification
          adjust_boundary_filtering(level, :decrease, metrics[level])
        _ ->
          :ok
      end
    end)
  end
  
  defp adjust_boundary_filtering(level, direction, metrics) do
    Logger.info("🔧 Adjusting variety #{direction} for #{level}")
    
    # Notify appropriate filter/amplifier
    case {level, direction} do
      {:s1, :increase} -> 
        VsmPhoenix.VarietyEngineering.Filters.S1ToS2.increase_filtering()
      {:s2, :increase} -> 
        VsmPhoenix.VarietyEngineering.Filters.S2ToS3.increase_filtering()
      {:s3, :increase} -> 
        VsmPhoenix.VarietyEngineering.Filters.S3ToS4.increase_filtering()
      {:s4, :increase} -> 
        VsmPhoenix.VarietyEngineering.Filters.S4ToS5.increase_filtering()
      {:s5, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S5ToS4.increase_amplification()
      {:s4, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S4ToS3.increase_amplification()
      {:s3, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S3ToS2.increase_amplification()
      {:s2, :decrease} -> 
        VsmPhoenix.VarietyEngineering.Amplifiers.S2ToS1.increase_amplification()
      _ -> 
        :ok
    end
  end
  
  defp schedule_balance_check do
    Process.send_after(self(), :check_balance, @check_interval)
  end
end