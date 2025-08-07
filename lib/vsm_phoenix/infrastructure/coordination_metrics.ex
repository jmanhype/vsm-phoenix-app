defmodule VsmPhoenix.Infrastructure.CoordinationMetrics do
  @moduledoc """
  Dynamic Coordination Metrics for System 2
  
  Tracks real coordination effectiveness and provides accurate metrics for:
  - Coordination effectiveness based on actual message flows
  - Message flow patterns and bottlenecks
  - Synchronization levels from real sync operations
  - Anti-oscillation performance
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @metrics_table :coordination_metrics
  @flow_table :message_flows
  @sync_table :sync_events
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def record_message_flow(from_context, to_context, message_type, status, latency \\ nil) do
    GenServer.cast(@name, {:record_message_flow, from_context, to_context, message_type, status, latency})
  end
  
  def record_synchronization(contexts, sync_type, effectiveness) do
    GenServer.cast(@name, {:record_synchronization, contexts, sync_type, effectiveness})
  end
  
  def record_oscillation_dampening(context, signal_strength, dampening_applied) do
    GenServer.cast(@name, {:record_oscillation_dampening, context, signal_strength, dampening_applied})
  end
  
  def get_coordination_effectiveness do
    GenServer.call(@name, :get_coordination_effectiveness)
  end
  
  def get_message_flow_metrics do
    GenServer.call(@name, :get_message_flow_metrics)
  end
  
  def get_synchronization_status do
    GenServer.call(@name, :get_synchronization_status)
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🔄 Starting Coordination Metrics tracking...")
    
    # Create ETS tables
    :ets.new(@metrics_table, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@flow_table, [:bag, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@sync_table, [:bag, :public, :named_table, {:read_concurrency, true}])
    
    # Initialize global coordination metrics
    :ets.insert(@metrics_table, {:global, default_global_metrics()})
    
    # Schedule periodic analysis
    schedule_analysis()
    schedule_flow_analysis()
    
    {:ok, %{
      started_at: DateTime.utc_now(),
      last_analysis: DateTime.utc_now()
    }}
  end
  
  @impl true
  def handle_cast({:record_message_flow, from_context, to_context, message_type, status, latency}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Record flow event
    flow_record = %{
      from: from_context,
      to: to_context,
      type: message_type,
      status: status,
      latency: latency,
      timestamp: timestamp
    }
    
    :ets.insert(@flow_table, {timestamp, flow_record})
    
    # Update global coordination metrics
    update_global_metrics(:message_flow, status, latency)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:record_synchronization, contexts, sync_type, effectiveness}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Record sync event
    sync_record = %{
      contexts: contexts,
      type: sync_type,
      effectiveness: effectiveness,
      timestamp: timestamp
    }
    
    :ets.insert(@sync_table, {timestamp, sync_record})
    
    # Update sync metrics
    update_global_metrics(:synchronization, :success, effectiveness)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:record_oscillation_dampening, context, signal_strength, dampening_applied}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Record oscillation event
    osc_record = %{
      context: context,
      signal_strength: signal_strength,
      dampening_applied: dampening_applied,
      timestamp: timestamp
    }
    
    :ets.insert(@flow_table, {timestamp, osc_record})
    
    # Update oscillation metrics
    update_global_metrics(:oscillation_dampening, :applied, dampening_applied)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:get_coordination_effectiveness, _from, state) do
    [{:global, metrics}] = :ets.lookup(@metrics_table, :global)
    
    # Calculate real-time effectiveness
    effectiveness = %{
      overall_effectiveness: metrics.coordination_effectiveness,
      message_success_rate: metrics.message_success_rate,
      average_latency: metrics.average_message_latency,
      synchronization_level: metrics.synchronization_level,
      oscillation_control: metrics.oscillation_control_rate,
      active_flows: count_active_flows(),
      contexts_synchronized: count_synchronized_contexts(),
      messages_per_minute: calculate_message_rate(),
      coordination_bottlenecks: identify_bottlenecks()
    }
    
    {:reply, effectiveness, state}
  end
  
  @impl true
  def handle_call(:get_message_flow_metrics, _from, state) do
    now = :erlang.system_time(:millisecond)
    last_hour = now - (60 * 60 * 1000)
    
    # Get recent flows
    recent_flows = :ets.select(@flow_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", last_hour}], [:"$2"]}
    ])
    
    # Analyze flows
    flow_metrics = %{
      total_messages: length(recent_flows),
      unique_flows: count_unique_flows(recent_flows),
      average_latency: calculate_average_latency(recent_flows),
      success_rate: calculate_flow_success_rate(recent_flows),
      busiest_routes: identify_busiest_routes(recent_flows),
      flow_distribution: analyze_flow_distribution(recent_flows)
    }
    
    {:reply, flow_metrics, state}
  end
  
  @impl true
  def handle_call(:get_synchronization_status, _from, state) do
    now = :erlang.system_time(:millisecond)
    last_hour = now - (60 * 60 * 1000)
    
    # Get recent sync events
    recent_syncs = :ets.select(@sync_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", last_hour}], [:"$2"]}
    ])
    
    sync_status = %{
      synchronizations_completed: length(recent_syncs),
      average_effectiveness: calculate_sync_effectiveness(recent_syncs),
      contexts_synchronized: count_unique_sync_contexts(recent_syncs),
      sync_frequency: calculate_sync_frequency(recent_syncs),
      synchronization_health: calculate_sync_health(recent_syncs)
    }
    
    {:reply, sync_status, state}
  end
  
  @impl true
  def handle_info(:analyze, state) do
    # Perform periodic analysis and updates
    analyze_coordination_patterns()
    
    schedule_analysis()
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:analyze_flows, state) do
    # Analyze message flow patterns
    analyze_message_flows()
    
    schedule_flow_analysis()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp default_global_metrics do
    %{
      coordination_effectiveness: 0.95,
      message_success_rate: 0.98,
      average_message_latency: 50.0,
      synchronization_level: 0.92,
      oscillation_control_rate: 0.89,
      messages_coordinated: 0,
      synchronizations_performed: 0,
      oscillations_dampened: 0,
      started_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now()
    }
  end
  
  defp update_global_metrics(metric_type, status, value \\ nil) do
    [{:global, current_metrics}] = :ets.lookup(@metrics_table, :global)
    
    updated_metrics = case metric_type do
      :message_flow ->
        update_message_metrics(current_metrics, status, value)
      :synchronization ->
        update_sync_metrics(current_metrics, status, value)
      :oscillation_dampening ->
        update_oscillation_metrics(current_metrics, status, value)
    end
    |> Map.put(:last_updated, DateTime.utc_now())
    
    :ets.insert(@metrics_table, {:global, updated_metrics})
  end
  
  defp update_message_metrics(metrics, status, latency) do
    new_total = metrics.messages_coordinated + 1
    
    # Update success rate
    current_successes = trunc(metrics.message_success_rate * metrics.messages_coordinated)
    new_successes = if status in [:success, :delivered], do: current_successes + 1, else: current_successes
    new_success_rate = new_successes / new_total
    
    # Update latency
    new_latency = if is_number(latency) and metrics.messages_coordinated > 0 do
      (metrics.average_message_latency * metrics.messages_coordinated + latency) / new_total
    else
      metrics.average_message_latency
    end
    
    %{metrics |
      messages_coordinated: new_total,
      message_success_rate: new_success_rate,
      average_message_latency: new_latency
    }
  end
  
  defp update_sync_metrics(metrics, status, effectiveness) do
    new_total = metrics.synchronizations_performed + 1
    
    # Update sync effectiveness
    new_effectiveness = if is_number(effectiveness) and metrics.synchronizations_performed > 0 do
      (metrics.synchronization_level * metrics.synchronizations_performed + effectiveness) / new_total
    else
      metrics.synchronization_level
    end
    
    %{metrics |
      synchronizations_performed: new_total,
      synchronization_level: new_effectiveness
    }
  end
  
  defp update_oscillation_metrics(metrics, status, dampening_factor) do
    new_total = metrics.oscillations_dampened + 1
    
    # Update control rate based on dampening effectiveness
    if is_number(dampening_factor) and metrics.oscillations_dampened > 0 do
      current_rate = metrics.oscillation_control_rate * metrics.oscillations_dampened
      new_rate = (current_rate + dampening_factor) / new_total
      
      %{metrics |
        oscillations_dampened: new_total,
        oscillation_control_rate: new_rate
      }
    else
      %{metrics | oscillations_dampened: new_total}
    end
  end
  
  defp count_active_flows do
    now = :erlang.system_time(:millisecond)
    last_minute = now - (60 * 1000)
    
    # Count unique flows in last minute
    recent_flows = :ets.select(@flow_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", last_minute}], [:"$2"]}
    ])
    
    recent_flows
    |> Enum.map(fn flow -> {flow.from, flow.to} end)
    |> Enum.uniq()
    |> length()
  end
  
  defp count_synchronized_contexts do
    now = :erlang.system_time(:millisecond)
    last_hour = now - (60 * 60 * 1000)
    
    # Get contexts that participated in sync in last hour
    recent_syncs = :ets.select(@sync_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", last_hour}], [:"$2"]}
    ])
    
    recent_syncs
    |> Enum.flat_map(fn sync -> sync.contexts end)
    |> Enum.uniq()
    |> length()
  end
  
  defp calculate_message_rate do
    now = :erlang.system_time(:millisecond)
    last_minute = now - (60 * 1000)
    
    message_count = :ets.select_count(@flow_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", last_minute}], [true]}
    ])
    
    message_count  # Messages per minute
  end
  
  defp identify_bottlenecks do
    now = :erlang.system_time(:millisecond)
    last_hour = now - (60 * 60 * 1000)
    
    # Get recent flows with high latency
    high_latency_flows = :ets.select(@flow_table, [
      {{:"$1", :"$2"}, 
       [{:>=, :"$1", last_hour}, {:>, {:map_get, :latency, :"$2"}, 1000}], 
       [:"$2"]}
    ])
    
    # Group by route and count
    high_latency_flows
    |> Enum.group_by(fn flow -> {flow.from, flow.to} end)
    |> Enum.map(fn {{from, to}, flows} ->
      %{
        route: "#{from} -> #{to}",
        high_latency_count: length(flows),
        average_latency: Enum.sum_by(flows, & &1.latency) / length(flows)
      }
    end)
    |> Enum.sort_by(& &1.high_latency_count, :desc)
    |> Enum.take(5)
  end
  
  defp count_unique_flows(flows) do
    flows
    |> Enum.map(fn flow -> {flow.from, flow.to} end)
    |> Enum.uniq()
    |> length()
  end
  
  defp calculate_average_latency(flows) do
    latency_flows = Enum.filter(flows, fn flow -> is_number(flow.latency) end)
    
    if length(latency_flows) > 0 do
      Enum.sum_by(latency_flows, & &1.latency) / length(latency_flows)
    else
      0.0
    end
  end
  
  defp calculate_flow_success_rate(flows) do
    if length(flows) == 0 do
      1.0
    else
      successes = Enum.count(flows, fn flow ->
        flow.status in [:success, :delivered, :coordinated]
      end)
      successes / length(flows)
    end
  end
  
  defp identify_busiest_routes(flows) do
    flows
    |> Enum.group_by(fn flow -> {flow.from, flow.to} end)
    |> Enum.map(fn {{from, to}, route_flows} ->
      %{
        route: "#{from} -> #{to}",
        message_count: length(route_flows),
        success_rate: calculate_flow_success_rate(route_flows),
        average_latency: calculate_average_latency(route_flows)
      }
    end)
    |> Enum.sort_by(& &1.message_count, :desc)
    |> Enum.take(10)
  end
  
  defp analyze_flow_distribution(flows) do
    # Analyze message type distribution
    type_distribution = flows
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, type_flows} ->
      {type, length(type_flows)}
    end)
    |> Enum.into(%{})
    
    # Analyze temporal distribution
    time_buckets = flows
    |> Enum.group_by(fn flow ->
      # Group by 5-minute buckets
      bucket = div(flow.timestamp, 5 * 60 * 1000) * 5 * 60 * 1000
      DateTime.from_unix!(div(bucket, 1000))
    end)
    |> Enum.map(fn {time, bucket_flows} ->
      {time, length(bucket_flows)}
    end)
    
    %{
      by_type: type_distribution,
      by_time: time_buckets
    }
  end
  
  defp calculate_sync_effectiveness(syncs) do
    if length(syncs) == 0 do
      0.95  # Default high effectiveness
    else
      total_effectiveness = Enum.sum_by(syncs, & &1.effectiveness)
      total_effectiveness / length(syncs)
    end
  end
  
  defp count_unique_sync_contexts(syncs) do
    syncs
    |> Enum.flat_map(& &1.contexts)
    |> Enum.uniq()
    |> length()
  end
  
  defp calculate_sync_frequency(syncs) do
    if length(syncs) == 0 do
      0.0
    else
      # Syncs per hour
      length(syncs)
    end
  end
  
  defp calculate_sync_health(syncs) do
    if length(syncs) == 0 do
      1.0
    else
      avg_effectiveness = calculate_sync_effectiveness(syncs)
      frequency = calculate_sync_frequency(syncs)
      
      # Health based on effectiveness and reasonable frequency
      effectiveness_score = avg_effectiveness
      frequency_score = cond do
        frequency < 1 -> 0.8  # Too infrequent
        frequency > 20 -> 0.7  # Too frequent
        true -> 1.0
      end
      
      (effectiveness_score + frequency_score) / 2
    end
  end
  
  defp analyze_coordination_patterns do
    # Analyze patterns and update global effectiveness
    [{:global, metrics}] = :ets.lookup(@metrics_table, :global)
    
    # Calculate overall coordination effectiveness
    effectiveness = calculate_overall_effectiveness(metrics)
    
    updated_metrics = %{metrics |
      coordination_effectiveness: effectiveness,
      last_updated: DateTime.utc_now()
    }
    
    :ets.insert(@metrics_table, {:global, updated_metrics})
    
    # Publish telemetry
    :telemetry.execute(
      [:vsm, :coordination, :effectiveness],
      %{effectiveness: effectiveness},
      %{component: :system2_coordinator}
    )
  end
  
  defp analyze_message_flows do
    # Analyze message flow patterns for bottlenecks
    now = :erlang.system_time(:millisecond)
    analysis_window = now - (15 * 60 * 1000)  # Last 15 minutes
    
    recent_flows = :ets.select(@flow_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", analysis_window}], [:"$2"]}
    ])
    
    # Detect congestion and adjust coordination rules
    congestion_level = detect_congestion(recent_flows)
    
    if congestion_level > 0.8 do
      Logger.warning("🚨 High coordination congestion detected: #{congestion_level}")
      
      # Publish congestion alert
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:coordination:alerts",
        {:congestion_alert, congestion_level, recent_flows}
      )
    end
  end
  
  defp calculate_overall_effectiveness(metrics) do
    # Weighted combination of different effectiveness factors
    weights = %{
      message_success: 0.3,
      sync_level: 0.25,
      oscillation_control: 0.2,
      latency_performance: 0.15,
      flow_balance: 0.1
    }
    
    # Calculate latency performance (lower is better)
    latency_performance = if metrics.average_message_latency > 0 do
      max(0.0, 1.0 - (metrics.average_message_latency / 1000.0))  # 1s = 0% performance
    else
      1.0
    end
    
    # Calculate flow balance (how evenly distributed are flows)
    flow_balance = calculate_flow_balance()
    
    effectiveness = 
      metrics.message_success_rate * weights.message_success +
      metrics.synchronization_level * weights.sync_level +
      metrics.oscillation_control_rate * weights.oscillation_control +
      latency_performance * weights.latency_performance +
      flow_balance * weights.flow_balance
    
    min(1.0, max(0.0, effectiveness))
  end
  
  defp calculate_flow_balance do
    # Analyze how balanced message flows are between contexts
    now = :erlang.system_time(:millisecond)
    last_hour = now - (60 * 60 * 1000)
    
    recent_flows = :ets.select(@flow_table, [
      {{:"$1", :"$2"}, [{:>=, :"$1", last_hour}], [:"$2"]}
    ])
    
    if length(recent_flows) == 0 do
      1.0
    else
      # Calculate distribution variance
      route_counts = recent_flows
      |> Enum.group_by(fn flow -> {flow.from, flow.to} end)
      |> Enum.map(fn {_route, flows} -> length(flows) end)
      
      if length(route_counts) <= 1 do
        1.0
      else
        mean = Enum.sum(route_counts) / length(route_counts)
        variance = Enum.sum_by(route_counts, fn count -> :math.pow(count - mean, 2) end) / length(route_counts)
        
        # Convert variance to balance score (lower variance = higher balance)
        max(0.0, 1.0 - variance / 100.0)
      end
    end
  end
  
  defp detect_congestion(flows) do
    # Detect congestion based on latency and failure rates
    if length(flows) == 0 do
      0.0
    else
      avg_latency = calculate_average_latency(flows)
      failure_rate = 1.0 - calculate_flow_success_rate(flows)
      
      # Congestion score (0-1)
      latency_score = min(1.0, avg_latency / 2000.0)  # 2s = max congestion
      failure_score = failure_rate
      
      (latency_score + failure_score) / 2
    end
  end
  
  defp schedule_analysis do
    Process.send_after(self(), :analyze, 30_000)  # Every 30 seconds
  end
  
  defp schedule_flow_analysis do
    Process.send_after(self(), :analyze_flows, 60_000)  # Every minute
  end
end