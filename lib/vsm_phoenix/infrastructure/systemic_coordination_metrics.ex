defmodule VsmPhoenix.Infrastructure.SystemicCoordinationMetrics do
  @moduledoc """
  Agnostic System 2 Coordination Metrics
  
  Tracks pure systemic coordination patterns:
  - Message Volume: Communications per second
  - Routing Efficiency: Direct vs redirected messages
  - Synchronization Events: Coordination actions
  - Conflict Resolution: Conflicts detected and resolved
  - Flow Balance: Input/output message ratios
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @table_name :systemic_coordination_metrics
  @message_flows_table :systemic_message_flows
  @sync_events_table :systemic_sync_events
  @conflict_table :systemic_conflicts
  
  # Time windows (milliseconds)
  @second 1_000
  @minute 60_000
  @hour 3_600_000
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc "Record a message flow between units"
  def record_message(from_unit, to_unit, routing_type, latency_ms \\ nil) do
    GenServer.cast(@name, {:record_message, from_unit, to_unit, routing_type, latency_ms})
  end
  
  @doc "Record a synchronization event"
  def record_sync_event(units, sync_type, effectiveness_score) do
    GenServer.cast(@name, {:record_sync_event, units, sync_type, effectiveness_score})
  end
  
  @doc "Record a conflict and its resolution"
  def record_conflict(unit1, unit2, conflict_type, resolution_time_ms, resolved?) do
    GenServer.cast(@name, {:record_conflict, unit1, unit2, conflict_type, resolution_time_ms, resolved?})
  end
  
  @doc "Get current coordination metrics"
  def get_metrics do
    GenServer.call(@name, :get_metrics)
  end
  
  @doc "Get message volume statistics"
  def get_message_volume(time_window \\ :last_minute) do
    GenServer.call(@name, {:get_message_volume, time_window})
  end
  
  @doc "Get routing efficiency metrics"
  def get_routing_efficiency do
    GenServer.call(@name, :get_routing_efficiency)
  end
  
  @doc "Get flow balance metrics"
  def get_flow_balance do
    GenServer.call(@name, :get_flow_balance)
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🔄 Starting Systemic Coordination Metrics...")
    
    # Create ETS tables
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@message_flows_table, [:ordered_set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@sync_events_table, [:ordered_set, :public, :named_table, {:read_concurrency, true}])
    :ets.new(@conflict_table, [:ordered_set, :public, :named_table, {:read_concurrency, true}])
    
    # Initialize metrics
    init_metrics()
    
    # Schedule periodic tasks
    schedule_flow_analysis()
    schedule_metric_aggregation()
    schedule_cleanup()
    
    {:ok, %{
      started_at: :erlang.system_time(:millisecond),
      last_flow_analysis: :erlang.system_time(:millisecond),
      last_aggregation: :erlang.system_time(:millisecond)
    }}
  end
  
  @impl true
  def handle_cast({:record_message, from_unit, to_unit, routing_type, latency_ms}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    # Determine if direct or redirected
    is_direct = routing_type in [:direct, :point_to_point, :immediate]
    
    message_record = %{
      from: from_unit,
      to: to_unit,
      routing_type: routing_type,
      is_direct: is_direct,
      latency_ms: latency_ms,
      timestamp: timestamp
    }
    
    :ets.insert(@message_flows_table, {timestamp, message_record})
    
    # Update flow tracking for balance calculations
    update_flow_tracking(from_unit, to_unit)
    
    # Update running metrics
    update_message_metrics(is_direct, latency_ms)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:record_sync_event, units, sync_type, effectiveness_score}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    sync_record = %{
      units: units,
      unit_count: length(units),
      sync_type: sync_type,
      effectiveness: effectiveness_score,
      timestamp: timestamp
    }
    
    :ets.insert(@sync_events_table, {timestamp, sync_record})
    
    # Update sync metrics
    update_sync_metrics(sync_type, effectiveness_score)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:record_conflict, unit1, unit2, conflict_type, resolution_time_ms, resolved?}, state) do
    timestamp = :erlang.system_time(:millisecond)
    
    conflict_record = %{
      units: [unit1, unit2],
      conflict_type: conflict_type,
      resolution_time_ms: resolution_time_ms,
      resolved: resolved?,
      timestamp: timestamp
    }
    
    :ets.insert(@conflict_table, {timestamp, conflict_record})
    
    # Update conflict metrics
    update_conflict_metrics(resolved?, resolution_time_ms)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = calculate_current_metrics()
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call({:get_message_volume, time_window}, _from, state) do
    volume = calculate_message_volume(time_window)
    {:reply, volume, state}
  end
  
  @impl true
  def handle_call(:get_routing_efficiency, _from, state) do
    efficiency = calculate_routing_efficiency()
    {:reply, efficiency, state}
  end
  
  @impl true
  def handle_call(:get_flow_balance, _from, state) do
    balance = calculate_flow_balance()
    {:reply, balance, state}
  end
  
  @impl true
  def handle_info(:analyze_flows, state) do
    analyze_message_flows()
    schedule_flow_analysis()
    {:noreply, %{state | last_flow_analysis: :erlang.system_time(:millisecond)}}
  end
  
  @impl true
  def handle_info(:aggregate_metrics, state) do
    aggregate_and_publish_metrics()
    schedule_metric_aggregation()
    {:noreply, %{state | last_aggregation: :erlang.system_time(:millisecond)}}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    cleanup_old_data()
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp init_metrics do
    initial_metrics = %{
      # Message flow metrics
      total_messages: 0,
      direct_messages: 0,
      redirected_messages: 0,
      message_volume_per_second: 0.0,
      avg_message_latency_ms: 0.0,
      routing_efficiency: 1.0,
      
      # Synchronization metrics
      total_sync_events: 0,
      sync_effectiveness: 1.0,
      sync_frequency: 0.0,
      avg_units_per_sync: 0.0,
      
      # Conflict metrics
      total_conflicts: 0,
      resolved_conflicts: 0,
      unresolved_conflicts: 0,
      conflict_resolution_rate: 1.0,
      avg_resolution_time_ms: 0.0,
      
      # Flow balance metrics
      flow_balance_ratio: 1.0,
      unit_flow_imbalances: %{},
      
      # Metadata
      last_updated: :erlang.system_time(:millisecond),
      measurement_window_ms: @minute
    }
    
    :ets.insert(@table_name, {:current, initial_metrics})
    :ets.insert(@table_name, {:flow_tracking, %{}})
  end
  
  defp update_flow_tracking(from_unit, to_unit) do
    [{:flow_tracking, flows}] = :ets.lookup(@table_name, :flow_tracking)
    
    # Update outgoing count for from_unit
    flows = Map.update(flows, from_unit, %{out: 1, in: 0}, fn unit_flows ->
      Map.update(unit_flows, :out, 1, &(&1 + 1))
    end)
    
    # Update incoming count for to_unit
    flows = Map.update(flows, to_unit, %{out: 0, in: 1}, fn unit_flows ->
      Map.update(unit_flows, :in, 1, &(&1 + 1))
    end)
    
    :ets.insert(@table_name, {:flow_tracking, flows})
  end
  
  defp update_message_metrics(is_direct, latency_ms) do
    [{:current, metrics}] = :ets.lookup(@table_name, :current)
    
    # Update message counts
    updated_metrics = Map.update(metrics, :total_messages, 1, &(&1 + 1))
    
    updated_metrics = if is_direct do
      Map.update(updated_metrics, :direct_messages, 1, &(&1 + 1))
    else
      Map.update(updated_metrics, :redirected_messages, 1, &(&1 + 1))
    end
    
    # Update latency if provided
    updated_metrics = if is_number(latency_ms) do
      total = updated_metrics.total_messages
      current_avg = updated_metrics.avg_message_latency_ms
      new_avg = ((current_avg * (total - 1)) + latency_ms) / total
      Map.put(updated_metrics, :avg_message_latency_ms, new_avg)
    else
      updated_metrics
    end
    
    # Update routing efficiency
    total_messages = updated_metrics.total_messages
    direct_messages = updated_metrics.direct_messages
    routing_efficiency = if total_messages > 0 do
      direct_messages / total_messages
    else
      1.0
    end
    
    updated_metrics = Map.put(updated_metrics, :routing_efficiency, routing_efficiency)
    |> Map.put(:last_updated, :erlang.system_time(:millisecond))
    
    :ets.insert(@table_name, {:current, updated_metrics})
  end
  
  defp update_sync_metrics(sync_type, effectiveness_score) do
    [{:current, metrics}] = :ets.lookup(@table_name, :current)
    
    total_syncs = metrics.total_sync_events + 1
    
    # Calculate new average effectiveness
    current_effectiveness = metrics.sync_effectiveness
    new_effectiveness = ((current_effectiveness * metrics.total_sync_events) + effectiveness_score) / total_syncs
    
    updated_metrics = %{metrics |
      total_sync_events: total_syncs,
      sync_effectiveness: new_effectiveness,
      last_updated: :erlang.system_time(:millisecond)
    }
    
    :ets.insert(@table_name, {:current, updated_metrics})
  end
  
  defp update_conflict_metrics(resolved?, resolution_time_ms) do
    [{:current, metrics}] = :ets.lookup(@table_name, :current)
    
    updated_metrics = Map.update(metrics, :total_conflicts, 1, &(&1 + 1))
    
    updated_metrics = if resolved? do
      # Update resolved count
      resolved_count = Map.get(updated_metrics, :resolved_conflicts, 0) + 1
      
      # Update average resolution time
      current_avg = updated_metrics.avg_resolution_time_ms
      total_resolved = resolved_count
      new_avg = if is_number(resolution_time_ms) and total_resolved > 0 do
        ((current_avg * (total_resolved - 1)) + resolution_time_ms) / total_resolved
      else
        current_avg
      end
      
      %{updated_metrics |
        resolved_conflicts: resolved_count,
        avg_resolution_time_ms: new_avg
      }
    else
      Map.update(updated_metrics, :unresolved_conflicts, 1, &(&1 + 1))
    end
    
    # Update resolution rate
    total = updated_metrics.total_conflicts
    resolved = updated_metrics.resolved_conflicts
    resolution_rate = if total > 0, do: resolved / total, else: 1.0
    
    updated_metrics = Map.put(updated_metrics, :conflict_resolution_rate, resolution_rate)
    |> Map.put(:last_updated, :erlang.system_time(:millisecond))
    
    :ets.insert(@table_name, {:current, updated_metrics})
  end
  
  defp calculate_current_metrics do
    [{:current, base_metrics}] = :ets.lookup(@table_name, :current)
    
    # Calculate real-time rates
    now = :erlang.system_time(:millisecond)
    one_minute_ago = now - @minute
    
    # Message volume per second
    recent_messages = :ets.select_count(@message_flows_table, [
      {{'$1', '_'}, [{:'>=', '$1', one_minute_ago}], [true]}
    ])
    message_volume_per_second = recent_messages / 60.0
    
    # Sync frequency
    recent_syncs = :ets.select_count(@sync_events_table, [
      {{'$1', '_'}, [{:'>=', '$1', one_minute_ago}], [true]}
    ])
    sync_frequency = recent_syncs / 60.0
    
    # Average units per sync
    sync_records = :ets.select(@sync_events_table, [
      {{'$1', '$2'}, [{:'>=', '$1', one_minute_ago}], ['$2']}
    ])
    avg_units_per_sync = if length(sync_records) > 0 do
      total_units = Enum.sum(Enum.map(sync_records, fn r -> r.unit_count end))
      total_units / length(sync_records)
    else
      0.0
    end
    
    # Calculate flow balance
    [{:flow_tracking, flows}] = :ets.lookup(@table_name, :flow_tracking)
    flow_balance = calculate_flow_balance_ratio(flows)
    
    %{base_metrics |
      message_volume_per_second: Float.round(message_volume_per_second, 3),
      sync_frequency: Float.round(sync_frequency, 3),
      avg_units_per_sync: Float.round(avg_units_per_sync, 2),
      flow_balance_ratio: Float.round(flow_balance.overall_balance, 3),
      unit_flow_imbalances: flow_balance.unit_imbalances
    }
  end
  
  defp calculate_message_volume(time_window) do
    now = :erlang.system_time(:millisecond)
    
    start_time = case time_window do
      :last_second -> now - @second
      :last_minute -> now - @minute
      :last_hour -> now - @hour
      :last_5_minutes -> now - (5 * @minute)
      _ -> now - @minute
    end
    
    # Count messages in window
    message_count = :ets.select_count(@message_flows_table, [
      {{'$1', '_'}, [{:'>=', '$1', start_time}], [true]}
    ])
    
    # Get message details for analysis
    messages = :ets.select(@message_flows_table, [
      {{'$1', '$2'}, [{:'>=', '$1', start_time}], ['$2']}
    ])
    
    # Calculate rates
    time_span_seconds = (now - start_time) / @second
    messages_per_second = message_count / time_span_seconds
    
    # Analyze routing types
    direct_count = Enum.count(messages, fn m -> m.is_direct end)
    redirected_count = message_count - direct_count
    
    %{
      window: time_window,
      total_messages: message_count,
      messages_per_second: Float.round(messages_per_second, 3),
      direct_messages: direct_count,
      redirected_messages: redirected_count,
      direct_ratio: if(message_count > 0, do: Float.round(direct_count / message_count, 3), else: 1.0)
    }
  end
  
  defp calculate_routing_efficiency do
    now = :erlang.system_time(:millisecond)
    five_minutes_ago = now - (5 * @minute)
    
    # Get recent messages
    messages = :ets.select(@message_flows_table, [
      {{'$1', '$2'}, [{:'>=', '$1', five_minutes_ago}], ['$2']}
    ])
    
    if length(messages) == 0 do
      %{
        efficiency_score: 1.0,
        direct_percentage: 100.0,
        avg_redirect_penalty: 0.0,
        routing_patterns: %{}
      }
    else
      # Calculate efficiency metrics
      direct_count = Enum.count(messages, fn m -> m.is_direct end)
      total_count = length(messages)
      
      # Calculate latency penalty for redirected messages
      redirected_messages = Enum.filter(messages, fn m -> not m.is_direct end)
      avg_redirect_latency = if length(redirected_messages) > 0 do
        latencies = redirected_messages
        |> Enum.map(fn m -> m.latency_ms end)
        |> Enum.filter(&is_number/1)
        
        if length(latencies) > 0 do
          Enum.sum(latencies) / length(latencies)
        else
          0.0
        end
      else
        0.0
      end
      
      # Analyze routing patterns
      routing_patterns = messages
      |> Enum.group_by(fn m -> m.routing_type end)
      |> Enum.map(fn {type, msgs} -> {type, length(msgs)} end)
      |> Map.new()
      
      %{
        efficiency_score: Float.round(direct_count / total_count, 3),
        direct_percentage: Float.round((direct_count / total_count) * 100, 1),
        avg_redirect_penalty: Float.round(avg_redirect_latency, 2),
        routing_patterns: routing_patterns
      }
    end
  end
  
  defp calculate_flow_balance do
    [{:flow_tracking, flows}] = :ets.lookup(@table_name, :flow_tracking)
    calculate_flow_balance_ratio(flows)
  end
  
  defp calculate_flow_balance_ratio(flows) when flows == %{} do
    %{overall_balance: 1.0, unit_imbalances: %{}}
  end
  defp calculate_flow_balance_ratio(flows) do
    # Calculate balance for each unit
    unit_balances = Enum.map(flows, fn {unit, counts} ->
      incoming = Map.get(counts, :in, 0)
      outgoing = Map.get(counts, :out, 0)
      total = incoming + outgoing
      
      balance = if total > 0 do
        # Perfect balance is 0.5 (equal in/out)
        # Imbalance approaches 0 or 1
        abs(0.5 - (incoming / total))
      else
        0.0
      end
      
      {unit, %{
        incoming: incoming,
        outgoing: outgoing,
        balance_score: Float.round(1.0 - (balance * 2), 3)  # Convert to 0-1 scale where 1 is perfect
      }}
    end)
    |> Map.new()
    
    # Calculate overall balance
    balance_scores = Enum.map(unit_balances, fn {_unit, data} -> data.balance_score end)
    overall_balance = if length(balance_scores) > 0 do
      Enum.sum(balance_scores) / length(balance_scores)
    else
      1.0
    end
    
    %{
      overall_balance: Float.round(overall_balance, 3),
      unit_imbalances: unit_balances
    }
  end
  
  defp analyze_message_flows do
    # This could include more sophisticated flow analysis
    # For now, just ensure metrics are current
    metrics = calculate_current_metrics()
    
    # Detect anomalies or patterns
    if metrics.routing_efficiency < 0.7 do
      Logger.warning("Low routing efficiency detected: #{metrics.routing_efficiency}")
    end
    
    if metrics.conflict_resolution_rate < 0.8 do
      Logger.warning("High conflict rate detected: #{metrics.conflict_resolution_rate}")
    end
  end
  
  defp aggregate_and_publish_metrics do
    metrics = calculate_current_metrics()
    
    # Publish to telemetry
    :telemetry.execute(
      [:vsm, :system2, :systemic_metrics],
      %{
        message_volume: metrics.message_volume_per_second,
        routing_efficiency: metrics.routing_efficiency,
        sync_frequency: metrics.sync_frequency,
        conflict_resolution_rate: metrics.conflict_resolution_rate,
        flow_balance: metrics.flow_balance_ratio
      },
      %{}
    )
  end
  
  defp cleanup_old_data do
    # Remove data older than 1 hour
    cutoff = :erlang.system_time(:millisecond) - @hour
    
    # Clean up each table
    [:ets.select_delete(@message_flows_table, [{{'$1', '_'}, [{:'<', '$1', cutoff}], [true]}]),
     :ets.select_delete(@sync_events_table, [{{'$1', '_'}, [{:'<', '$1', cutoff}], [true]}]),
     :ets.select_delete(@conflict_table, [{{'$1', '_'}, [{:'<', '$1', cutoff}], [true]}])]
  end
  
  defp schedule_flow_analysis do
    Process.send_after(self(), :analyze_flows, @second * 30)  # Every 30 seconds
  end
  
  defp schedule_metric_aggregation do
    Process.send_after(self(), :aggregate_metrics, @second * 10)  # Every 10 seconds
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @minute * 10)  # Every 10 minutes
  end
end