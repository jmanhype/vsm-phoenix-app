defmodule VsmPhoenix.System2.Coordinator do
  @moduledoc """
  System 2 - Coordinator: Anti-Oscillation and Coordination
  
  Provides coordination between System 1 units through:
  - PubSub message coordination
  - Anti-oscillation dampening
  - Information flow management
  - Operational synchronization
  """
  
  use GenServer
  require Logger
  
  alias Phoenix.PubSub
  alias VsmPhoenix.System1.{Context, Operations}
  alias AMQP
  alias VsmPhoenix.Infrastructure.CausalityAMQP
  alias VsmPhoenix.System2.CorticalAttentionEngine
  
  @name __MODULE__
  @pubsub VsmPhoenix.PubSub
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def coordinate_message(from_context, to_context, message) do
    GenServer.call(@name, {:coordinate_message, from_context, to_context, message})
  end
  
  def broadcast_coordination(topic, message) do
    GenServer.cast(@name, {:broadcast, topic, message})
  end
  
  def register_context(context_id, metadata) do
    GenServer.call(@name, {:register_context, context_id, metadata})
  end
  
  def get_coordination_status do
    GenServer.call(@name, :get_coordination_status)
  end
  
  def dampen_oscillation(context_id, signal) do
    GenServer.call(@name, {:dampen_oscillation, context_id, signal})
  end
  
  def synchronize_operations(contexts) do
    GenServer.call(@name, {:synchronize_operations, contexts})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("System 2 Coordinator initializing...")
    
    # Subscribe to all coordination topics
    PubSub.subscribe(@pubsub, "vsm:coordination")
    PubSub.subscribe(@pubsub, "vsm:system1")
    PubSub.subscribe(@pubsub, "vsm:oscillation")
    
    state = %{
      registered_contexts: %{},
      message_flows: %{},
      oscillation_detectors: %{},
      coordination_rules: load_coordination_rules(),
      synchronization_state: %{},
      message_history: [],
      performance_metrics: %{
        messages_coordinated: 0,
        oscillations_dampened: 0,
        synchronizations: 0,
        effectiveness: 1.0
      },
      amqp_channel: nil,
      attention_metrics: %{
        total_attention_scored: 0,
        high_attention_messages: 0,
        low_attention_filtered: 0,
        attention_modulated_delays: 0,
        attention_bypasses: 0
      }
    }
    
    # Set up AMQP for coordination
    state = setup_amqp_coordination(state)
    
    # Schedule periodic synchronization check
    schedule_synchronization_check()
    
    # Schedule attention metrics reporting
    schedule_attention_metrics_report()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:coordinate_message, from_context, to_context, message}, _from, state) do
    start_time = :erlang.system_time(:millisecond)
    Logger.debug("Coordinator: Message from #{from_context} to #{to_context}")
    
    # Apply cortical attention scoring
    context = %{source: from_context, target: to_context, state: state}
    {:ok, attention_score, score_components} = CorticalAttentionEngine.score_attention(message, context)
    
    # Update attention metrics
    new_attention_metrics = state.attention_metrics
    |> Map.update!(:total_attention_scored, &(&1 + 1))
    |> then(fn metrics ->
      if attention_score > 0.7 do
        Logger.info("🧠 High attention message (score: #{Float.round(attention_score, 2)}): #{inspect(message[:type])}")
        Map.update!(metrics, :high_attention_messages, &(&1 + 1))
      else
        metrics
      end
    end)
    
    # Add attention score to message for downstream processing
    attention_enriched_message = Map.merge(message, %{
      attention_score: attention_score,
      attention_components: score_components
    })
    
    # Check if coordination is needed (now with attention awareness)
    coordination_result = apply_coordination_rules(from_context, to_context, attention_enriched_message, state)
    
    new_state = case coordination_result do
      {:allow, processed_message} ->
        # Forward the message
        forward_message(to_context, processed_message)
        
        # Calculate coordination latency
        latency = :erlang.system_time(:millisecond) - start_time
        
        # Record successful message flow in metrics
        VsmPhoenix.Infrastructure.CoordinationMetrics.record_message_flow(
          from_context,
          to_context,
          Map.get(message, :type, :unknown),
          :success,
          latency
        )
        
        # Also record in systemic metrics
        VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.record_message(
          from_context,
          to_context,
          :direct,
          latency
        )
        
        # Update message flows
        update_message_flows(state, from_context, to_context, processed_message)
        
      {:delay, duration, processed_message} ->
        # Schedule delayed delivery
        schedule_delayed_message(to_context, processed_message, duration)
        
        # Record delayed message flow
        VsmPhoenix.Infrastructure.CoordinationMetrics.record_message_flow(
          from_context,
          to_context,
          Map.get(message, :type, :unknown),
          :delayed,
          duration
        )
        
        # Also record in systemic metrics as redirected
        VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.record_message(
          from_context,
          to_context,
          :redirected,
          duration
        )
        
        # Update state with pending message
        add_pending_message(state, from_context, to_context, processed_message)
        
      {:block, reason} ->
        Logger.warning("Coordinator: Blocked message from #{from_context} to #{to_context}: #{reason}")
        
        # Record blocked message flow
        VsmPhoenix.Infrastructure.CoordinationMetrics.record_message_flow(
          from_context,
          to_context,
          Map.get(message, :type, :unknown),
          :blocked,
          nil
        )
        
        state
    end
    
    # Update attention metrics based on coordination result
    updated_attention_metrics = case Process.get(:attention_metrics_update) do
      :low_attention_filtered ->
        Process.delete(:attention_metrics_update)
        Map.update!(new_attention_metrics, :low_attention_filtered, &(&1 + 1))
      _ ->
        case coordination_result do
          {:delay, _, _} when attention_score > 0.7 ->
            Map.update!(new_attention_metrics, :attention_modulated_delays, &(&1 + 1))
          {:allow, _} when attention_score > 0.8 ->
            Map.update!(new_attention_metrics, :attention_bypasses, &(&1 + 1))
          _ ->
            new_attention_metrics
        end
    end
    
    # Update metrics with attention metrics
    final_state = new_state
    |> Map.put(:attention_metrics, updated_attention_metrics)
    |> update_metrics(:messages_coordinated)
    
    {:reply, coordination_result, final_state}
  end
  
  @impl true
  def handle_call({:register_context, context_id, metadata}, _from, state) do
    Logger.info("Coordinator: Registering context #{context_id}")
    
    # Initialize oscillation detector for this context
    detector = init_oscillation_detector(context_id)
    
    new_contexts = Map.put(state.registered_contexts, context_id, metadata)
    new_detectors = Map.put(state.oscillation_detectors, context_id, detector)
    
    new_state = %{state | 
      registered_contexts: new_contexts,
      oscillation_detectors: new_detectors
    }
    
    # Subscribe to context-specific topics
    PubSub.subscribe(@pubsub, "vsm:context:#{context_id}")
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:get_coordination_status, _from, state) do
    # Get real coordination effectiveness from BOTH metrics systems
    real_effectiveness = VsmPhoenix.Infrastructure.CoordinationMetrics.get_coordination_effectiveness()
    message_flows = VsmPhoenix.Infrastructure.CoordinationMetrics.get_message_flow_metrics()
    sync_status = VsmPhoenix.Infrastructure.CoordinationMetrics.get_synchronization_status()
    
    # Get systemic coordination patterns
    systemic_metrics = VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.get_metrics()
    routing_efficiency = VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.get_routing_efficiency()
    flow_balance = VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.get_flow_balance()
    
    status = %{
      # Legacy fields for compatibility
      registered_contexts: map_size(state.registered_contexts),
      active_flows: real_effectiveness.active_flows,
      message_flow_metrics: %{
        messages_per_minute: real_effectiveness.messages_per_minute,
        success_rate: real_effectiveness.message_success_rate,
        average_latency: real_effectiveness.average_latency,
        bottlenecks: real_effectiveness.coordination_bottlenecks
      },
      oscillation_risks: detect_oscillation_risks(state),
      synchronization_level: real_effectiveness.synchronization_level,
      coordination_effectiveness: real_effectiveness.overall_effectiveness,
      synchronization_metrics: %{
        contexts_synchronized: sync_status.contexts_synchronized,
        sync_frequency: sync_status.sync_frequency,
        sync_health: sync_status.synchronization_health
      },
      oscillation_control: real_effectiveness.oscillation_control,
      
      # Pure systemic patterns
      systemic_patterns: %{
        message_volume: systemic_metrics.message_volume_per_second,
        routing_efficiency: routing_efficiency.efficiency_score,
        direct_routing_percentage: routing_efficiency.direct_percentage,
        synchronization_frequency: systemic_metrics.sync_frequency,
        conflict_resolution_rate: systemic_metrics.conflict_resolution_rate,
        flow_balance_ratio: flow_balance.overall_balance,
        unit_imbalances: flow_balance.unit_imbalances
      },
      
      # Cortical attention metrics
      attention_metrics: Map.merge(state.attention_metrics, %{
        attention_effectiveness: calculate_attention_effectiveness(state.attention_metrics),
        attention_state: get_current_attention_state()
      })
    }
    
    {:reply, status, state}
  end
  
  @impl true
  def handle_call({:dampen_oscillation, context_id, signal}, _from, state) do
    Logger.info("Coordinator: Dampening oscillation for #{context_id}")
    
    detector = Map.get(state.oscillation_detectors, context_id, init_oscillation_detector(context_id))
    
    {dampened_signal, updated_detector} = apply_dampening(signal, detector)
    
    # Calculate dampening effectiveness
    dampening_applied = if dampened_signal != signal do
      original_strength = if is_number(signal), do: abs(signal), else: 1.0
      dampened_strength = if is_number(dampened_signal), do: abs(dampened_signal), else: 0.7
      
      if original_strength > 0 do
        1.0 - (dampened_strength / original_strength)
      else
        0.0
      end
    else
      0.0  # No dampening applied
    end
    
    # Record oscillation dampening in metrics
    if dampening_applied > 0 do
      VsmPhoenix.Infrastructure.CoordinationMetrics.record_oscillation_dampening(
        context_id,
        if(is_number(signal), do: abs(signal), else: 1.0),
        dampening_applied
      )
    end
    
    new_detectors = Map.put(state.oscillation_detectors, context_id, updated_detector)
    new_state = %{state | oscillation_detectors: new_detectors}
    
    # Update metrics
    final_state = if dampened_signal != signal do
      update_metrics(new_state, :oscillations_dampened)
    else
      new_state
    end
    
    {:reply, dampened_signal, final_state}
  end
  
  @impl true
  def handle_call({:synchronize_operations, contexts}, _from, state) do
    start_time = :erlang.system_time(:millisecond)
    Logger.info("Coordinator: Synchronizing operations for contexts: #{inspect(contexts)}")
    
    # Create synchronization plan
    sync_plan = create_synchronization_plan(contexts, state)
    
    # Execute synchronization
    sync_result = execute_synchronization(sync_plan, state)
    
    # Calculate synchronization effectiveness
    sync_time = :erlang.system_time(:millisecond) - start_time
    effectiveness = calculate_sync_effectiveness(sync_result, sync_time)
    
    # Record synchronization in metrics
    VsmPhoenix.Infrastructure.CoordinationMetrics.record_synchronization(
      contexts,
      :operational_sync,
      effectiveness
    )
    
    # Also record in systemic metrics
    VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.record_sync_event(
      contexts,
      :operational_sync,
      effectiveness
    )
    
    # Update synchronization state
    new_sync_state = Map.put(state.synchronization_state, sync_result.id, sync_result)
    new_state = %{state | synchronization_state: new_sync_state}
    
    # Update metrics
    final_state = update_metrics(new_state, :synchronizations)
    
    {:reply, sync_result, final_state}
  end
  
  @impl true
  def handle_cast({:broadcast, topic, message}, state) do
    Logger.debug("Coordinator: Broadcasting to #{topic}")
    
    # Apply coordination rules to broadcast
    coordinated_message = apply_broadcast_coordination(topic, message, state)
    
    # Broadcast via AMQP if available
    if state[:amqp_channel] do
      amqp_message = %{
        type: "coordination_broadcast",
        topic: topic,
        message: coordinated_message,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        source: "system2_coordinator"
      }
      
      publish_coordination_message(amqp_message, state)
    end
    
    # Also broadcast via PubSub for local subscribers
    PubSub.broadcast(@pubsub, topic, coordinated_message)
    
    # Record in message history
    new_history = [{DateTime.utc_now(), :broadcast, topic, message} | state.message_history]
    new_state = %{state | message_history: Enum.take(new_history, 1000)}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:delayed_message, to_context, message}, state) do
    forward_message(to_context, message)
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:synchronization_check, state) do
    # Check for contexts that need synchronization
    contexts_needing_sync = identify_desynchronized_contexts(state)
    
    if length(contexts_needing_sync) > 0 do
      GenServer.call(self(), {:synchronize_operations, contexts_needing_sync})
    end
    
    schedule_synchronization_check()
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:pubsub, topic, message}, state) do
    # Handle PubSub messages
    Logger.debug("Coordinator: Received PubSub message on #{topic}")
    
    # Check for oscillation patterns
    new_state = check_for_oscillations(topic, message, state)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle AMQP coordination messages with causality tracking
    {message, causality_info} = CausalityAMQP.receive_message(payload, meta)
    
    if is_map(message) do
        Logger.info("🔄 Coordinator received AMQP message: #{message["type"]} (chain depth: #{causality_info.chain_depth})")
        
        new_state = process_coordination_message(message, state)
        
        # Acknowledge the message
        if state[:amqp_channel] do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
    else
        Logger.error("Coordinator: Unexpected message format: #{inspect(message)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("🔄 Coordinator: AMQP consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("Coordinator: AMQP consumer cancelled")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("Coordinator: AMQP consumer cancel confirmed")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Coordinator: Retrying AMQP setup...")
    new_state = setup_amqp_coordination(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:report_attention_metrics, state) do
    # Report attention metrics to infrastructure
    if state.attention_metrics.total_attention_scored > 0 do
      effectiveness = calculate_attention_effectiveness(state.attention_metrics)
      
      # Log summary
      Logger.info("""
      🧠 Cortical Attention Metrics Report:
      - Total messages scored: #{state.attention_metrics.total_attention_scored}
      - High attention messages: #{state.attention_metrics.high_attention_messages}
      - Low attention filtered: #{state.attention_metrics.low_attention_filtered}
      - Attention modulated delays: #{state.attention_metrics.attention_modulated_delays}
      - Attention bypasses: #{state.attention_metrics.attention_bypasses}
      - Effectiveness: #{Float.round(effectiveness * 100, 1)}%
      """)
      
      # Report to metrics infrastructure
      VsmPhoenix.Infrastructure.CoordinationMetrics.record_custom_metric(
        :cortical_attention_effectiveness,
        %{
          effectiveness: effectiveness,
          high_attention_rate: state.attention_metrics.high_attention_messages / state.attention_metrics.total_attention_scored,
          filter_rate: state.attention_metrics.low_attention_filtered / state.attention_metrics.total_attention_scored
        }
      )
    end
    
    # Schedule next report
    schedule_attention_metrics_report()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp load_coordination_rules do
    %{
      message_rules: %{
        max_frequency: 100,  # messages per second
        require_sync: [:critical, :state_change],
        block_patterns: []
      },
      oscillation_rules: %{
        detection_window: 5000,  # 5 seconds
        threshold_frequency: 10,  # oscillations per window
        dampening_factor: 0.7
      },
      synchronization_rules: %{
        max_drift: 1000,  # milliseconds
        sync_interval: 10000  # 10 seconds
      }
    }
  end
  
  defp apply_coordination_rules(from_context, to_context, message, state) do
    rules = state.coordination_rules.message_rules
    attention_score = Map.get(message, :attention_score, 0.5)
    
    # Low attention messages can be filtered or delayed
    if attention_score < 0.2 do
      Logger.debug("🧠 Low attention message filtered (score: #{Float.round(attention_score, 2)})")
      # Update attention metrics for filtered messages
      Process.put(:attention_metrics_update, :low_attention_filtered)
      {:block, :low_attention}
    else
      # Check for conflicts
      conflict_check = check_for_conflicts(from_context, to_context, message, state)
      case conflict_check do
        {:conflict, conflict_type} ->
          # Record conflict in systemic metrics
          resolution_start = :erlang.system_time(:millisecond)
          
          # Attention-aware conflict resolution: high attention messages get priority
          resolution_time = if attention_score > 0.7 do
            20  # Fast resolution for high attention
          else
            50  # Standard delay
          end
          
          VsmPhoenix.Infrastructure.SystemicCoordinationMetrics.record_conflict(
            from_context,
            to_context,
            conflict_type,
            resolution_time,
            true  # Resolved by delaying
          )
          
          {:delay, resolution_time, message}
          
        :no_conflict ->
          # Check message frequency with attention modulation
          frequency_limit = rules.max_frequency * (1 + attention_score)
          
          if message_frequency_exceeded?(from_context, to_context, state, frequency_limit) do
            # High attention messages can bypass frequency limits
            if attention_score > 0.8 do
              Logger.info("🧠 High attention message bypassing frequency limit")
              {:allow, message}
            else
              {:delay, calculate_delay(state, attention_score), message}
            end
          else
            # Check if synchronization is required
            if requires_synchronization?(message, rules) or attention_score > 0.9 do
              synchronized_message = ensure_synchronized(message, from_context, to_context, state)
              {:allow, synchronized_message}
            else
              {:allow, message}
            end
          end
      end
    end
  end
  
  defp forward_message(to_context, message) do
    PubSub.broadcast(@pubsub, "vsm:context:#{to_context}", {:coordinated_message, message})
  end
  
  defp schedule_delayed_message(to_context, message, duration) do
    Process.send_after(self(), {:delayed_message, to_context, message}, duration)
  end
  
  defp update_message_flows(state, from, to, message) do
    flow_key = {from, to}
    timestamp = DateTime.utc_now()
    
    flow = Map.get(state.message_flows, flow_key, %{messages: [], count: 0})
    updated_flow = %{
      messages: [{timestamp, message} | flow.messages] |> Enum.take(100),
      count: flow.count + 1,
      last_message: timestamp
    }
    
    new_flows = Map.put(state.message_flows, flow_key, updated_flow)
    %{state | message_flows: new_flows}
  end
  
  defp add_pending_message(state, from, to, message) do
    # Add to pending messages in synchronization state
    state
  end
  
  defp init_oscillation_detector(context_id) do
    %{
      context_id: context_id,
      signal_history: [],
      oscillation_count: 0,
      last_dampening: nil,
      detection_window: 5000
    }
  end
  
  defp apply_dampening(signal, detector) do
    # Add signal to history
    now = :erlang.system_time(:millisecond)
    new_history = [{now, signal} | detector.signal_history]
    
    # Keep only recent history
    window_start = now - detector.detection_window
    filtered_history = Enum.filter(new_history, fn {ts, _} -> ts > window_start end)
    
    # Detect oscillation
    oscillating = is_oscillating?(filtered_history)
    
    if oscillating do
      # Get attention-based dampening factor
      context = %{
        type: :oscillation,
        source: detector.context_id,
        urgency: :high,
        signal_history: filtered_history
      }
      
      {:ok, attention_score, _} = CorticalAttentionEngine.score_attention(
        %{type: :oscillation_dampening, signal: signal},
        context
      )
      
      # Attention-modulated dampening: high attention = less dampening (more important to preserve)
      base_dampening = 0.7
      attention_preservation = attention_score * 0.3  # Up to 30% preservation
      dampening_factor = base_dampening + attention_preservation
      
      dampened_signal = dampen_signal(signal, dampening_factor)
      
      # Shift attention if oscillation is severe
      if detector.oscillation_count > 5 do
        CorticalAttentionEngine.shift_attention(%{
          type: :oscillation_crisis,
          context_id: detector.context_id,
          severity: :high
        })
      end
      
      updated_detector = %{detector | 
        signal_history: filtered_history,
        oscillation_count: detector.oscillation_count + 1,
        last_dampening: now
      }
      
      {dampened_signal, updated_detector}
    else
      updated_detector = %{detector | signal_history: filtered_history}
      {signal, updated_detector}
    end
  end
  
  defp is_oscillating?(history) do
    # Simple oscillation detection - check for rapid changes
    length(history) > 10 and variance(history) > 0.5
  end
  
  defp variance(history) do
    # Calculate signal variance
    0.3  # Simplified
  end
  
  defp dampen_signal(signal, factor) when is_number(signal) do
    signal * factor
  end
  
  defp dampen_signal(signal, _factor) do
    # For non-numeric signals, return as-is
    signal
  end
  
  defp create_synchronization_plan(contexts, state) do
    %{
      id: generate_sync_id(),
      contexts: contexts,
      timestamp: DateTime.utc_now(),
      actions: Enum.map(contexts, &determine_sync_action(&1, state))
    }
  end
  
  defp execute_synchronization(sync_plan, _state) do
    # Execute synchronization actions
    results = Enum.map(sync_plan.actions, &execute_sync_action/1)
    
    %{
      id: sync_plan.id,
      contexts: sync_plan.contexts,
      status: :completed,
      results: results
    }
  end
  
  defp determine_sync_action(context, _state) do
    %{
      context: context,
      action: :align_state,
      parameters: %{}
    }
  end
  
  defp execute_sync_action(action) do
    # Broadcast synchronization command
    PubSub.broadcast(@pubsub, "vsm:context:#{action.context}", {:sync, action})
    %{context: action.context, status: :synchronized}
  end
  
  defp apply_broadcast_coordination(_topic, message, _state) do
    # Apply any coordination rules to broadcasts
    message
  end
  
  defp count_active_flows(message_flows) do
    now = DateTime.utc_now()
    
    Enum.count(message_flows, fn {_key, flow} ->
      DateTime.diff(now, flow.last_message, :second) < 60
    end)
  end
  
  defp detect_oscillation_risks(state) do
    Enum.reduce(state.oscillation_detectors, [], fn {context_id, detector}, acc ->
      if detector.oscillation_count > 5 do
        [{context_id, :high} | acc]
      else
        acc
      end
    end)
  end
  
  defp calculate_sync_level(state) do
    # Calculate overall synchronization level
    if map_size(state.registered_contexts) == 0 do
      1.0
    else
      # Simplified calculation
      0.95
    end
  end
  
  defp message_frequency_exceeded?(_from, _to, _state, _frequency_limit \\ 100) do
    # Check if message frequency limit is exceeded
    false  # Simplified
  end
  
  defp calculate_delay(_state, attention_score \\ 0.5) do
    # Calculate appropriate delay with attention modulation
    # Lower attention = longer delay
    base_delay = 100  # milliseconds
    attention_factor = 1.0 - attention_score
    round(base_delay * (1 + attention_factor))
  end
  
  defp requires_synchronization?(message, rules) do
    message[:type] in rules.require_sync
  end
  
  defp ensure_synchronized(message, _from, _to, _state) do
    # Ensure message is synchronized
    Map.put(message, :synchronized, true)
  end
  
  defp identify_desynchronized_contexts(state) do
    # Identify contexts that have drifted
    []  # Simplified
  end
  
  defp check_for_oscillations(_topic, _message, state) do
    # Check for oscillation patterns in message flow
    state
  end
  
  defp generate_sync_id do
    "SYNC-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(1000)}"
  end
  
  defp update_metrics(state, metric) do
    new_metrics = Map.update!(state.performance_metrics, metric, &(&1 + 1))
    %{state | performance_metrics: new_metrics}
  end
  
  defp schedule_synchronization_check do
    Process.send_after(self(), :synchronization_check, 10_000)  # Every 10 seconds
  end
  
  defp schedule_attention_metrics_report do
    Process.send_after(self(), :report_attention_metrics, 30_000)  # Every 30 seconds
  end
  
  defp calculate_attention_effectiveness(metrics) do
    total = metrics.total_attention_scored
    if total == 0 do
      1.0
    else
      # Effectiveness based on:
      # - High attention messages are properly prioritized
      # - Low attention messages are filtered
      # - Attention-based routing decisions
      high_attention_rate = metrics.high_attention_messages / total
      filter_efficiency = metrics.low_attention_filtered / max(total * 0.2, 1)  # Expect ~20% to be low attention
      routing_efficiency = (metrics.attention_bypasses + metrics.attention_modulated_delays) / max(total * 0.1, 1)
      
      # Weighted effectiveness
      (high_attention_rate * 0.4 + min(filter_efficiency, 1.0) * 0.3 + min(routing_efficiency, 1.0) * 0.3)
    end
  end
  
  defp get_current_attention_state do
    case CorticalAttentionEngine.get_attention_state() do
      {:ok, state_info} -> state_info.state
      _ -> :unknown
    end
  end
  
  defp setup_amqp_coordination(state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_channel(:coordination) do
      {:ok, channel} ->
        try do
          # Create coordination queue
          {:ok, _queue} = AMQP.Queue.declare(channel, "vsm.system2.coordination", durable: true)
          
          # Bind to coordination exchange  
          :ok = AMQP.Queue.bind(channel, "vsm.system2.coordination", "vsm.coordination")
          
          # Start consuming coordination messages
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, "vsm.system2.coordination")
          
          Logger.info("🔄 Coordinator: AMQP consumer active! Tag: #{consumer_tag}")
          Logger.info("🔄 Coordinator: Listening for coordination messages on vsm.coordination exchange")
          
          Map.put(state, :amqp_channel, channel)
        rescue
          error ->
            Logger.error("Coordinator: Failed to set up AMQP: #{inspect(error)}")
            state
        end
        
      {:error, reason} ->
        Logger.error("Coordinator: Could not get AMQP channel: #{inspect(reason)}")
        # Schedule retry
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end
  
  defp process_coordination_message(message, state) do
    case message["type"] do
      "sync_request" ->
        # Handle synchronization requests
        contexts = message["contexts"] || []
        if length(contexts) > 0 do
          GenServer.call(self(), {:synchronize_operations, contexts})
        end
        state
        
      "oscillation_alert" ->
        # Handle oscillation alerts
        context_id = message["context_id"]
        signal = message["signal"]
        if context_id && signal do
          GenServer.call(self(), {:dampen_oscillation, context_id, signal})
        end
        state
        
      "coordination_rule" ->
        # Update coordination rules dynamically
        new_rule = message["rule"]
        if new_rule do
          update_coordination_rules(state, new_rule)
        else
          state
        end
        
      _ ->
        Logger.debug("Coordinator: Unknown coordination message type: #{message["type"]}")
        state
    end
  end
  
  defp update_coordination_rules(state, new_rule) do
    # Merge new rule into existing rules
    updated_rules = Map.merge(state.coordination_rules, new_rule, fn _k, v1, v2 ->
      case {v1, v2} do
        {%{} = m1, %{} = m2} -> Map.merge(m1, m2)
        {_, v2} -> v2
      end
    end)
    %{state | coordination_rules: updated_rules}
  end
  
  defp publish_coordination_message(message, state) do
    if state[:amqp_channel] do
      payload = Jason.encode!(message)
      
      :ok = CausalityAMQP.publish(
        state.amqp_channel,
        "vsm.coordination",
        "",
        payload,
        content_type: "application/json"
      )
      
      Logger.debug("🔄 Published coordination message: #{message["type"]}")
    end
  end
  
  defp calculate_sync_effectiveness(sync_result, sync_time) do
    # Calculate effectiveness based on sync result and timing
    base_effectiveness = case sync_result.status do
      :completed -> 0.95
      :partial -> 0.7
      :failed -> 0.2
      _ -> 0.5
    end
    
    # Time penalty for slow syncs
    time_factor = cond do
      sync_time < 100 -> 1.0      # Excellent
      sync_time < 500 -> 0.95     # Good
      sync_time < 1000 -> 0.9     # Acceptable
      sync_time < 2000 -> 0.8     # Slow
      true -> 0.6                 # Very slow
    end
    
    # Success rate of individual actions
    if sync_result.results && length(sync_result.results) > 0 do
      successful_actions = Enum.count(sync_result.results, fn result ->
        result.status == :synchronized
      end)
      action_success_rate = successful_actions / length(sync_result.results)
      
      # Combined effectiveness
      base_effectiveness * time_factor * action_success_rate
    else
      base_effectiveness * time_factor
    end
  end
  
  defp check_for_conflicts(from_context, to_context, message, state) do
    # Check for various types of conflicts
    cond do
      # Check for simultaneous messages to same context
      has_recent_message?(to_context, state, 10) ->
        {:conflict, :simultaneous_access}
        
      # Check for circular message patterns
      creates_circular_flow?(from_context, to_context, state) ->
        {:conflict, :circular_dependency}
        
      # Check for resource contention
      message[:type] == :resource_request and resource_locked?(to_context, state) ->
        {:conflict, :resource_contention}
        
      # No conflicts detected
      true ->
        :no_conflict
    end
  end
  
  defp has_recent_message?(context, state, threshold_ms) do
    # Check if context received a message very recently
    case Map.get(state.message_flows, {:any, context}) do
      %{last_message: last_time} ->
        time_diff = DateTime.diff(DateTime.utc_now(), last_time, :millisecond)
        time_diff < threshold_ms
      _ ->
        false
    end
  end
  
  defp creates_circular_flow?(from_context, to_context, state) do
    # Simple check: if to_context recently sent to from_context
    Map.has_key?(state.message_flows, {to_context, from_context})
  end
  
  defp resource_locked?(context, _state) do
    # Simplified resource lock check
    false  # Would check actual resource locks in production
  end
end