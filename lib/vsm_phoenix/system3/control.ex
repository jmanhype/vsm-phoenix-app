defmodule VsmPhoenix.System3.Control do
  @moduledoc """
  System 3 - Control: Systemic Pattern Monitoring and Flow Management
  
  Tracks pure systemic patterns:
  - Flow utilization and allocation efficiency
  - Optimization actions and rebalancing events
  - Constraint violations and limit breaches
  - Waste ratios and resource flows
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System2.Coordinator
  alias VsmPhoenix.System1.{Context, Operations}
  alias AMQP
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def allocate_flow(flow_request) do
    GenServer.call(@name, {:allocate_flow, flow_request})
  end
  
  def optimize_patterns(target_pattern) do
    GenServer.call(@name, {:optimize_patterns, target_pattern})
  end
  
  def resolve_constraint(unit1, unit2, constraint_issue) do
    GenServer.call(@name, {:resolve_constraint, unit1, unit2, constraint_issue})
  end
  
  def get_systemic_patterns do
    GenServer.call(@name, :get_systemic_patterns)
  end
  
  def emergency_rebalance(flow_metrics) do
    GenServer.cast(@name, {:emergency_rebalance, flow_metrics})
  end
  
  def allocate_for_optimization(adjustment) do
    GenServer.cast(@name, {:allocate_for_optimization, adjustment})
  end
  
  def get_flow_state do
    GenServer.call(@name, :get_flow_state)
  end
  
  def get_resource_metrics do
    GenServer.call(@name, :get_resource_metrics)
  end

  def audit_resource_usage do
    GenServer.call(@name, :audit_resource_usage)
  end
  
  def audit_flow_patterns do
    GenServer.call(@name, :audit_flow_patterns)
  end
  
  def get_pattern_metrics do
    GenServer.call(@name, :get_pattern_metrics)
  end
  
  @doc """
  Direct audit bypass - inspect any S1 agent without S2 coordination
  WARNING: This bypasses normal coordination - use with caution!
  """
  def audit(target_s1, options \\ []) do
    GenServer.call(@name, {:audit_s1_direct, target_s1, options})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("System 3 Control initializing...")
    
    # Collect initial systemic flow patterns
    flow_patterns = collect_systemic_patterns()
    
    state = %{
      flow_pools: initialize_flow_pools(flow_patterns),
      allocations: %{},
      pattern_metrics: %{
        allocation_efficiency: 1.0,
        flow_utilization: 0.0,
        waste_ratio: 0.0,
        constraint_violations: [],
        optimization_actions: [],
        last_calculated: DateTime.utc_now()
      },
      systemic_rules: load_systemic_rules(),
      constraint_history: [],
      pattern_log: [],
      amqp_channel: nil,
      flow_patterns: flow_patterns,
      pattern_history: [],
      flow_baselines: %{},
      active_monitors: %{},
      flow_tracker: %{}
    }
    
    # Set up AMQP for flow control
    state = setup_amqp_control(state)
    
    # Subscribe to systemic patterns for real-time monitoring
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:variety_metrics")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:telemetry:metrics")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "vsm:system1:flow_usage")
    
    # Schedule periodic pattern optimization and flow monitoring
    schedule_pattern_optimization()
    schedule_flow_monitoring()
    schedule_pattern_audit()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:allocate_flow, flow_request}, _from, state) do
    Logger.info("Control: Processing flow allocation request")
    
    case attempt_flow_allocation(flow_request, state.flow_pools) do
      {:ok, updated_pools, allocation_id} ->
        new_allocations = Map.put(state.allocations, allocation_id, flow_request)
        new_state = %{state | 
          flow_pools: updated_pools,
          allocations: new_allocations
        }
        
        # Log the allocation
        pattern_entry = %{
          timestamp: DateTime.utc_now(),
          action: :allocate_flow,
          flow_request: flow_request,
          result: :success,
          allocation_id: allocation_id
        }
        
        # Publish allocation event to AMQP
        flow_event = %{
          type: "flow_allocated",
          allocation_id: allocation_id,
          flow_request: flow_request,
          pools: updated_pools,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
        
        final_state = log_pattern(new_state, pattern_entry)
        publish_flow_event(flow_event, final_state)
        
        {:reply, {:ok, allocation_id}, final_state}
        
      {:error, reason} ->
        # Try pattern optimization before rejecting
        case optimize_and_retry_flow(flow_request, state) do
          {:ok, updated_state, allocation_id} ->
            {:reply, {:ok, allocation_id}, updated_state}
          {:error, _} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:optimize_patterns, target_pattern}, _from, state) do
    Logger.info("Control: Optimizing patterns for #{target_pattern}")
    
    optimization_result = case target_pattern do
      :global -> global_pattern_optimization(state)
      :flow -> flow_pattern_optimization(state)
      :allocation -> allocation_pattern_optimization(state)
      specific -> targeted_pattern_optimization(specific, state)
    end
    
    # Record optimization action
    optimization_action = %{
      timestamp: DateTime.utc_now(),
      pattern: target_pattern,
      action: optimization_result.type,
      estimated_impact: optimization_result.estimated_improvement
    }
    
    new_state = apply_pattern_optimization(optimization_result, state)
    |> record_optimization_action(optimization_action)
    
    {:reply, optimization_result, new_state}
  end
  
  @impl true
  def handle_call({:resolve_constraint, unit1, unit2, constraint_issue}, _from, state) do
    Logger.info("Control: Resolving constraint between #{unit1} and #{unit2}")
    
    resolution = resolve_flow_constraint(unit1, unit2, constraint_issue, state)
    
    # Record constraint violation and resolution
    constraint_record = %{
      timestamp: DateTime.utc_now(),
      units: [unit1, unit2],
      constraint_issue: constraint_issue,
      resolution: resolution,
      violation_type: classify_constraint_violation(constraint_issue)
    }
    
    new_history = [constraint_record | state.constraint_history] |> Enum.take(100)
    new_state = %{state | constraint_history: new_history}
    
    # Apply resolution and track constraint violation
    updated_state = apply_constraint_resolution(resolution, new_state)
    |> record_constraint_violation(constraint_record)
    
    {:reply, resolution, updated_state}
  end
  
  @impl true
  def handle_call(:get_systemic_patterns, _from, state) do
    # Calculate pure systemic patterns
    current_flows = collect_systemic_patterns()
    
    patterns = %{
      # Resource Utilization - generic usage percentage
      resource_utilization: calculate_flow_utilization(current_flows),
      
      # Allocation Efficiency - used vs allocated ratio
      allocation_efficiency: calculate_allocation_efficiency(state, current_flows),
      
      # Optimization Actions - rebalancing events
      optimization_actions: %{
        recent_actions: Enum.take(state.pattern_metrics.optimization_actions, 10),
        action_frequency: calculate_action_frequency(state.pattern_metrics.optimization_actions),
        effectiveness_ratio: calculate_action_effectiveness(state.pattern_metrics.optimization_actions)
      },
      
      # Constraint Violations - limit breaches
      constraint_violations: %{
        active_violations: identify_active_violations(current_flows, state),
        violation_history: Enum.take(state.constraint_history, 20),
        breach_frequency: calculate_breach_frequency(state.constraint_history),
        severity_distribution: calculate_violation_severity(state.constraint_history)
      },
      
      # Waste Ratio - allocated but unused
      waste_ratio: calculate_pure_waste_ratio(state, current_flows),
      
      # Pure flow patterns
      flow_patterns: %{
        throughput_rates: extract_throughput_rates(current_flows),
        capacity_ratios: extract_capacity_ratios(current_flows),
        flow_balance: calculate_flow_balance(current_flows),
        pattern_stability: calculate_pattern_stability(state.pattern_history)
      },
      
      # Systemic health
      systemic_health: calculate_systemic_health(current_flows, state),
      
      # Metadata
      timestamp: DateTime.utc_now(),
      last_calculated: state.pattern_metrics.last_calculated
    }
    
    {:reply, patterns, state}
  end
  
  @impl true
  def handle_call(:get_flow_state, _from, state) do
    # Return comprehensive flow state
    flow_state = %{
      flow_pools: state.flow_pools,
      allocations: state.allocations,
      pattern_metrics: state.pattern_metrics,
      systemic_rules: Map.keys(state.systemic_rules),
      constraint_history_count: length(state.constraint_history),
      current_efficiency: state.pattern_metrics.allocation_efficiency,
      available_flows: calculate_available_flows(state.flow_pools),
      flow_pressure: calculate_flow_pressure(state)
    }
    
    {:reply, {:ok, flow_state}, state}
  end
  
  @impl true
  def handle_call(:get_resource_metrics, _from, state) do
    metrics = %{
      flow_pools: state.flow_pools,
      allocations: state.allocations,
      pattern_metrics: state.pattern_metrics,
      efficiency: state.pattern_metrics.allocation_efficiency,
      waste_ratio: state.pattern_metrics.waste_ratio,
      flow_utilization: state.pattern_metrics.flow_utilization,
      optimization_count: length(state.pattern_metrics.optimization_actions),
      constraint_violations: length(state.pattern_metrics.constraint_violations)
    }
    
    {:reply, {:ok, metrics}, state}
  end
  
  @impl true
  def handle_call(:audit_resource_usage, _from, state) do
    audit_report = %{
      total_allocated: calculate_total_allocated(state),
      total_available: calculate_total_available(state),
      efficiency: state.pattern_metrics.allocation_efficiency,
      waste_ratio: state.pattern_metrics.waste_ratio,
      optimizations_performed: length(state.pattern_metrics.optimization_actions),
      violations: state.pattern_metrics.constraint_violations,
      flow_patterns: analyze_flow_patterns(state)
    }
    
    {:reply, audit_report, state}
  end

  @impl true
  def handle_call(:audit_flow_patterns, _from, state) do
    audit_report = %{
      current_allocations: state.allocations,
      flow_utilization: calculate_detailed_flow_utilization(state),
      efficiency_analysis: analyze_allocation_efficiency(state),
      waste_analysis: identify_flow_waste(state),
      pattern_recommendations: generate_pattern_recommendations(state)
    }
    
    {:reply, audit_report, state}
  end
  
  @impl true
  def handle_call(:get_pattern_metrics, _from, state) do
    {:reply, state.pattern_metrics, state}
  end
  
  @impl true
  def handle_call({:audit_s1_direct, target_s1, options}, _from, state) do
    Logger.warning("🔍 S3 AUDIT BYPASS: Direct inspection of #{target_s1}")
    
    # Generate audit request
    audit_request = %{
      type: "audit_command",
      operation: Keyword.get(options, :operation, :dump_state),
      target: target_s1,
      requester: "system3_control",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      bypass_coordination: true,
      audit_id: "AUDIT-#{:erlang.system_time(:millisecond)}"
    }
    
    # Send via dedicated audit channel to bypass S2
    result = VsmPhoenix.System3.AuditChannel.send_audit_command(target_s1, audit_request)
    
    # Log audit action with telemetry
    audit_entry = %{
      timestamp: DateTime.utc_now(),
      action: :direct_audit,
      target: target_s1,
      operation: audit_request.operation,
      result: elem(result, 0),
      audit_id: audit_request.audit_id
    }
    
    # Emit telemetry event
    :telemetry.execute(
      [:vsm, :system3, :audit],
      %{count: 1},
      %{target: target_s1, operation: audit_request.operation, bypass: true}
    )
    
    final_state = log_pattern(state, audit_entry)
    
    {:reply, result, final_state}
  end
  
  @impl true
  def handle_cast({:emergency_rebalance, flow_metrics}, state) do
    Logger.warning("Control: Emergency rebalance triggered")
    
    # Identify non-critical flow allocations
    rebalanceable = identify_rebalanceable_flows(state.allocations)
    
    # Free up flows
    {freed_flows, remaining_allocations} = free_flows(rebalanceable, state)
    
    # Reallocate to critical flow patterns
    new_pools = merge_freed_flows(state.flow_pools, freed_flows)
    
    # Record rebalancing action
    rebalance_action = %{
      timestamp: DateTime.utc_now(),
      action: :emergency_rebalance,
      flows_freed: freed_flows,
      trigger_metrics: flow_metrics
    }
    
    new_state = %{state |
      flow_pools: new_pools,
      allocations: remaining_allocations
    }
    |> record_optimization_action(rebalance_action)
    
    # Notify affected flow units
    notify_rebalance(rebalanceable)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:allocate_for_optimization, adjustment}, state) do
    Logger.info("Control: Allocating flows for optimization #{adjustment.id}")
    
    # Reserve flows for pattern optimization
    reserved_pools = reserve_for_pattern_optimization(state.flow_pools, adjustment.flows_required)
    
    new_state = %{state | flow_pools: reserved_pools}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:optimization_cycle, state) do
    # Collect fresh flow patterns
    current_patterns = collect_systemic_patterns()
    
    # Run pattern optimization based on systemic data
    optimization_result = systemic_pattern_optimization(state, current_patterns)
    new_state = apply_pattern_optimization(optimization_result, state)
    
    # Update pattern metrics with systemic calculations
    updated_metrics = calculate_systemic_pattern_metrics(new_state, current_patterns)
    final_state = %{new_state | 
      pattern_metrics: updated_metrics,
      flow_patterns: current_patterns
    }
    
    schedule_pattern_optimization()
    {:noreply, final_state}
  end
  
  @impl true
  def handle_info(:collect_patterns, state) do
    # Periodic pattern collection
    current_patterns = collect_systemic_patterns()
    
    # Update pattern history
    new_history = [current_patterns | state.pattern_history] |> Enum.take(100)
    
    # Update flow baselines if enough data
    new_baselines = update_flow_baselines(state.flow_baselines, new_history)
    
    # Update flow pools with pattern data
    updated_pools = update_pools_with_flow_data(state.flow_pools, current_patterns)
    
    new_state = %{state |
      flow_patterns: current_patterns,
      pattern_history: new_history,
      flow_baselines: new_baselines,
      flow_pools: updated_pools
    }
    
    schedule_flow_monitoring()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:pattern_audit, state) do
    # Periodic pattern audit
    audit_result = perform_pattern_audit(state)
    
    # Log pattern audit
    new_log = [audit_result | state.pattern_log] |> Enum.take(500)
    
    # Update flow tracker with usage data
    new_tracker = update_flow_tracker(state.flow_tracker, state.flow_patterns)
    
    new_state = %{state |
      pattern_log: new_log,
      flow_tracker: new_tracker
    }
    
    # Trigger optimization if waste detected
    if audit_result.waste_ratio > 0.15 do
      Logger.warning("🗑️ High flow waste detected: #{audit_result.waste_ratio * 100}%")
      send(self(), {:optimize_due_to_waste, audit_result})
    end
    
    schedule_pattern_audit()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:variety_update, metrics}, state) do
    # Use variety metrics to inform resource allocation decisions
    variety_impact = calculate_variety_impact_on_resources(metrics)
    
    # Adjust resource allocation based on variety patterns
    adjusted_pools = adjust_pools_for_variety(state.flow_pools, variety_impact)
    
    {:noreply, %{state | flow_pools: adjusted_pools}}
  end
  
  @impl true
  def handle_info({:optimize_due_to_waste, audit_result}, state) do
    # Emergency optimization due to waste
    Logger.info("🔧 Triggering waste-reduction optimization")
    
    optimization = waste_reduction_optimization(audit_result, state)
    new_state = apply_optimization(optimization, state)
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp attempt_allocation(request, pools) do
    required = request.resources
    
    if can_allocate?(required, pools) do
      updated_pools = deduct_resources(pools, required)
      allocation_id = generate_allocation_id()
      {:ok, updated_pools, allocation_id}
    else
      {:error, :insufficient_resources}
    end
  end
  
  defp can_allocate?(required, pools) do
    Enum.all?(required, fn {resource_type, amount} ->
      pool = Map.get(pools, resource_type, %{total: 0, allocated: 0})
      pool.total - pool.allocated >= amount
    end)
  end
  
  defp deduct_resources(pools, required) do
    Enum.reduce(required, pools, fn {resource_type, amount}, acc ->
      update_in(acc, [resource_type, :allocated], &(&1 + amount))
    end)
  end
  
  defp optimize_and_retry(request, state) do
    # Try to free up resources through optimization
    optimization = targeted_optimization(:allocation, state)
    
    if freed_resources_sufficient?(optimization, request, state) do
      new_state = apply_optimization(optimization, state)
      attempt_allocation(request, new_state.resource_pools)
      |> case do
        {:ok, pools, id} -> 
          {:ok, %{new_state | resource_pools: pools}, id}
        error -> 
          error
      end
    else
      {:error, :cannot_optimize_sufficiently}
    end
  end
  
  defp global_optimization(state) do
    %{
      type: :global,
      actions: [
        identify_underutilized_allocations(state),
        consolidate_fragmented_resources(state),
        rebalance_resource_distribution(state)
      ],
      estimated_improvement: 0.15,
      risk: :low
    }
  end
  
  defp resource_optimization(state) do
    %{
      type: :resource,
      actions: [
        optimize_compute_allocation(state),
        optimize_memory_usage(state),
        optimize_network_bandwidth(state)
      ],
      estimated_improvement: 0.10,
      risk: :low
    }
  end
  
  defp allocation_optimization(state) do
    %{
      type: :allocation,
      actions: [
        merge_similar_allocations(state),
        redistribute_idle_resources(state)
      ],
      estimated_improvement: 0.08,
      risk: :minimal
    }
  end
  
  defp targeted_optimization(target, state) do
    %{
      type: :targeted,
      target: target,
      actions: [analyze_target_usage(target, state)],
      estimated_improvement: 0.05,
      risk: :minimal
    }
  end
  
  defp apply_optimization(optimization, state) do
    # Apply optimization actions
    Enum.reduce(optimization.actions, state, fn action, acc ->
      apply_optimization_action(action, acc)
    end)
  end
  
  defp resolve_resource_conflict(context1, context2, issue, state) do
    priority1 = get_context_priority(context1)
    priority2 = get_context_priority(context2)
    
    resolution = cond do
      priority1 > priority2 ->
        %{winner: context1, action: :maintain_allocation, compensation: :defer}
      priority2 > priority1 ->
        %{winner: context2, action: :transfer_allocation, compensation: :immediate}
      true ->
        %{winner: :shared, action: :split_resources, compensation: :none}
    end
    
    Map.put(resolution, :rationale, generate_resolution_rationale(issue, state))
  end
  
  defp apply_resolution(resolution, state) do
    case resolution.action do
      :maintain_allocation -> state
      :transfer_allocation -> transfer_resources(resolution, state)
      :split_resources -> split_resources(resolution, state)
    end
  end
  
  defp calculate_pool_metrics(pools) do
    Enum.map(pools, fn {resource, pool} ->
      {resource, %{
        utilization: pool.allocated / pool.total,
        available: pool.total - pool.allocated - pool.reserved,
        efficiency: 1.0 - (pool.reserved / pool.total)
      }}
    end)
    |> Map.new()
  end
  
  defp calculate_utilization(pools) do
    total_allocated = Enum.reduce(pools, 0, fn {_, pool}, acc ->
      acc + pool.allocated
    end)
    
    total_capacity = Enum.reduce(pools, 0, fn {_, pool}, acc ->
      acc + pool.total
    end)
    
    if total_capacity > 0, do: total_allocated / total_capacity, else: 0
  end
  
  defp calculate_optimization_potential(state) do
    waste = state.performance_metrics.waste
    inefficiency = 1.0 - state.performance_metrics.efficiency
    
    (waste + inefficiency) / 2
  end
  
  defp load_optimization_rules do
    %{
      min_utilization: 0.3,
      max_utilization: 0.9,
      rebalance_threshold: 0.2,
      consolidation_threshold: 0.1
    }
  end
  
  defp identify_reallocatable_resources(allocations) do
    Enum.filter(allocations, fn {_id, allocation} ->
      allocation[:priority] != :critical
    end)
  end
  
  defp free_resources(reallocatable, state) do
    # Implementation for freeing resources
    {%{compute: 0.2, memory: 0.15}, state.allocations}
  end
  
  defp merge_freed_resources(pools, freed) do
    Enum.reduce(freed, pools, fn {resource, amount}, acc ->
      update_in(acc, [resource, :allocated], &(&1 - amount))
    end)
  end
  
  defp notify_reallocation(reallocatable) do
    Enum.each(reallocatable, fn {_id, allocation} ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:control",
        {:resource_reallocation, allocation.context}
      )
    end)
  end
  
  defp reserve_for_adaptation(pools, required_resources) do
    Enum.reduce(required_resources, pools, fn {resource, amount}, acc ->
      update_in(acc, [resource, :reserved], &(&1 + amount))
    end)
  end
  
  defp generate_allocation_id do
    "ALLOC-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(1000)}"
  end
  
  defp log_audit(state, entry) do
    new_log = [entry | state.audit_log] |> Enum.take(1000)
    %{state | audit_log: new_log}
  end
  
  defp update_performance_metrics(state) do
    %{
      efficiency: calculate_efficiency(state),
      utilization: calculate_utilization(state.resource_pools),
      waste: calculate_waste(state),
      bottlenecks: identify_bottlenecks(state)
    }
  end
  
  defp calculate_efficiency(state) do
    # Calculate overall system efficiency
    0.85  # Simplified
  end
  
  defp calculate_waste(state) do
    # Calculate resource waste
    0.05  # Simplified
  end
  
  defp identify_bottlenecks(state) do
    # Identify system bottlenecks
    []  # Simplified
  end
  
  defp calculate_detailed_utilization(state) do
    # Detailed utilization analysis
    %{
      by_resource: calculate_pool_metrics(state.resource_pools),
      by_context: %{},  # Would calculate per context
      trends: []  # Would include historical trends
    }
  end
  
  defp analyze_efficiency(state) do
    %{
      current: state.performance_metrics.efficiency,
      target: 0.9,
      gap: 0.9 - state.performance_metrics.efficiency
    }
  end
  
  defp identify_waste(state) do
    %{
      resource_waste: state.performance_metrics.waste,
      idle_allocations: [],  # Would identify idle allocations
      overprovisioning: []   # Would identify overprovisioned resources
    }
  end
  
  defp generate_recommendations(state) do
    [
      "Consider consolidating underutilized allocations",
      "Implement time-based resource sharing for non-critical tasks",
      "Review and adjust resource limits based on actual usage"
    ]
  end
  
  defp identify_underutilized_allocations(_state), do: %{action: :identify_underutilized}
  defp consolidate_fragmented_resources(_state), do: %{action: :consolidate}
  defp rebalance_resource_distribution(_state), do: %{action: :rebalance}
  defp optimize_compute_allocation(_state), do: %{action: :optimize_compute}
  defp optimize_memory_usage(_state), do: %{action: :optimize_memory}
  defp optimize_network_bandwidth(_state), do: %{action: :optimize_network}
  defp merge_similar_allocations(_state), do: %{action: :merge_allocations}
  defp redistribute_idle_resources(_state), do: %{action: :redistribute}
  defp analyze_target_usage(_target, _state), do: %{action: :analyze_target}
  
  defp apply_optimization_action(_action, state), do: state
  
  defp get_context_priority(_context), do: :normal
  defp generate_resolution_rationale(_issue, _state), do: "Based on system priorities"
  defp transfer_resources(_resolution, state), do: state
  defp split_resources(_resolution, state), do: state
  
  defp schedule_optimization_cycle do
    Process.send_after(self(), :optimization_cycle, 30_000)  # Every 30 seconds
  end
  
  defp calculate_available_resources(resource_pools) do
    Enum.map(resource_pools, fn {pool_name, pool} ->
      available = pool.total - pool.allocated
      {pool_name, %{available: available, percentage: available / pool.total * 100}}
    end)
    |> Enum.into(%{})
  end
  
  defp calculate_resource_pressure(state) do
    # Calculate overall resource pressure
    avg_utilization = calculate_utilization(state.resource_pools)
    
    cond do
      avg_utilization > 0.9 -> :critical
      avg_utilization > 0.7 -> :high
      avg_utilization > 0.5 -> :moderate
      true -> :low
    end
  end
  
  defp freed_resources_sufficient?(optimization, request, state) do
    # Estimate if the optimization can free enough resources
    estimated_freed = optimization.estimated_improvement
    
    # Check if the freed resources would satisfy the request
    request.resources
    |> Enum.all?(fn {resource_type, amount} ->
      pool = state.resource_pools[resource_type] || state.resource_pools[String.to_atom(resource_type)]
      if pool do
        available = pool.total - pool.allocated
        freed_amount = pool.allocated * estimated_freed
        (available + freed_amount) >= amount
      else
        false
      end
    end)
  end
  
  # AMQP Functions
  
  defp setup_amqp_control(state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_channel(:control) do
      {:ok, channel} ->
        try do
          # Create control queue
          {:ok, _queue} = AMQP.Queue.declare(channel, "vsm.system3.control", durable: true)
          
          # Bind to control exchange
          :ok = AMQP.Queue.bind(channel, "vsm.system3.control", "vsm.control")
          
          # Start consuming control messages
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, "vsm.system3.control")
          
          Logger.info("📊 Control: AMQP consumer active! Tag: #{consumer_tag}")
          Logger.info("📊 Control: Listening for resource control messages on vsm.control exchange")
          
          Map.put(state, :amqp_channel, channel)
        rescue
          error ->
            Logger.error("Control: Failed to set up AMQP: #{inspect(error)}")
            state
        end
        
      {:error, reason} ->
        Logger.error("Control: Could not get AMQP channel: #{inspect(reason)}")
        # Schedule retry
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end
  
  defp publish_resource_event(event, state) do
    if state[:amqp_channel] do
      payload = Jason.encode!(event)
      
      :ok = AMQP.Basic.publish(
        state.amqp_channel,
        "vsm.control",
        "",
        payload,
        content_type: "application/json"
      )
      
      Logger.debug("📊 Published resource event: #{event["type"]}")
    end
  end
  
  # AMQP Handlers
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle AMQP resource control messages
    case Jason.decode(payload) do
      {:ok, message} ->
        Logger.info("📊 Control received AMQP message: #{message["type"]}")
        
        new_state = process_control_message(message, state)
        
        # Acknowledge the message
        if state[:amqp_channel] do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
      {:error, _} ->
        Logger.error("Control: Failed to decode AMQP message")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("📊 Control: AMQP consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("Control: AMQP consumer cancelled")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("Control: AMQP consumer cancel confirmed")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Control: Retrying AMQP setup...")
    new_state = setup_amqp_control(state)
    {:noreply, new_state}
  end
  
  defp process_control_message(message, state) do
    case message["type"] do
      "resource_request" ->
        # Handle resource allocation requests via AMQP
        request = message["request"]
        if request do
          # Process allocation asynchronously
          spawn(fn ->
            result = GenServer.call(@name, {:allocate_resources, request})
            
            # Publish result back
            response = %{
              type: "resource_response",
              request_id: message["request_id"],
              result: result,
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }
            
            GenServer.cast(@name, {:publish_resource_event, response})
          end)
        end
        state
        
      "optimization_request" ->
        # Handle optimization requests
        target = message["target"] || :global
        spawn(fn ->
          GenServer.call(@name, {:optimize_performance, target})
        end)
        state
        
      "emergency_reallocation" ->
        # Handle emergency reallocations
        viability = message["viability_metrics"]
        if viability do
          GenServer.cast(@name, {:emergency_reallocation, viability})
        end
        state
        
      _ ->
        Logger.debug("Control: Unknown control message type: #{message["type"]}")
        state
    end
  end
  
  @impl true
  def handle_cast({:publish_resource_event, event}, state) do
    publish_resource_event(event, state)
    {:noreply, state}
  end
  
  # Real Metrics Collection Functions
  
  defp collect_real_system_metrics do
    # Collect comprehensive real-time system metrics
    memory = :erlang.memory()
    processes = Process.list()
    
    # CPU Metrics
    cpu_metrics = calculate_cpu_metrics()
    
    # Memory Metrics
    memory_metrics = calculate_memory_metrics(memory, processes)
    
    # Network Metrics (simulated based on process activity)
    network_metrics = calculate_network_metrics(processes)
    
    # Storage Metrics (based on ETS tables and file operations)
    storage_metrics = calculate_storage_metrics()
    
    # Process Efficiency Metrics
    process_metrics = calculate_process_efficiency_metrics(processes)
    
    %{
      timestamp: DateTime.utc_now(),
      cpu: cpu_metrics,
      memory: memory_metrics,
      network: network_metrics,
      storage: storage_metrics,
      processes: process_metrics
    }
  end
  
  defp calculate_cpu_metrics do
    # Get scheduler utilization and other CPU metrics
    scheduler_util = get_safe_scheduler_utilization()
    run_queue = :erlang.statistics(:run_queue)
    {_, reductions} = :erlang.statistics(:reductions)
    
    # Calculate CPU pressure based on run queue and utilization
    pressure = cond do
      run_queue > 100 -> :critical
      run_queue > 50 -> :high
      run_queue > 20 -> :moderate
      true -> :low
    end
    
    %{
      utilization: scheduler_util,
      run_queue_length: run_queue,
      reductions_per_second: reductions,
      pressure: pressure,
      efficiency: calculate_cpu_efficiency(scheduler_util, run_queue)
    }
  end
  
  defp calculate_memory_metrics(memory, processes) do
    # Calculate memory pressure and efficiency
    total_mb = memory[:total] / 1_048_576
    process_memory_mb = memory[:processes] / 1_048_576
    system_memory_mb = memory[:system] / 1_048_576
    
    # Memory pressure calculation
    pressure = cond do
      total_mb > 2000 -> :critical    # > 2GB
      total_mb > 1000 -> :high        # > 1GB
      total_mb > 500 -> :moderate     # > 500MB
      true -> :low
    end
    
    # Process memory distribution
    process_memory_stats = calculate_process_memory_distribution(processes)
    
    %{
      total_mb: Float.round(total_mb, 1),
      processes_mb: Float.round(process_memory_mb, 1),
      system_mb: Float.round(system_memory_mb, 1),
      atom_mb: Float.round(memory[:atom] / 1_048_576, 1),
      binary_mb: Float.round(memory[:binary] / 1_048_576, 1),
      ets_mb: Float.round(memory[:ets] / 1_048_576, 1),
      pressure: pressure,
      efficiency: calculate_memory_efficiency(memory),
      distribution: process_memory_stats
    }
  end
  
  defp calculate_network_metrics(processes) do
    # Network metrics based on message passing and IO
    {input, output} = try do
      case :erlang.statistics(:io) do
        {{input_val, output_val}, _} when is_number(input_val) and is_number(output_val) ->
          {input_val, output_val}
        _ ->
          {0, 0}
      end
    rescue
      _ -> {0, 0}
    end
    
    # Estimate network activity from message queues
    message_activity = processes
    |> Enum.map(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len
        _ -> 0
      end
    end)
    |> Enum.sum()
    
    throughput_estimate = (input + output) / 1024 / 1024  # Convert to MB
    
    %{
      io_input_mb: Float.round(input / 1_048_576, 2),
      io_output_mb: Float.round(output / 1_048_576, 2),
      throughput_mbps: Float.round(throughput_estimate, 2),
      message_queue_activity: message_activity,
      efficiency: calculate_network_efficiency(input + output, message_activity)
    }
  end
  
  defp calculate_storage_metrics do
    # Storage metrics based on ETS tables and persistent data
    ets_info = :ets.all()
    |> Enum.map(fn table ->
      try do
        info = :ets.info(table)
        %{
          name: table,
          size: info[:size] || 0,
          memory: info[:memory] || 0
        }
      rescue
        _ -> %{name: table, size: 0, memory: 0}
      end
    end)
    
    total_ets_memory = Enum.sum(Enum.map(ets_info, & &1.memory))
    total_ets_objects = Enum.sum(Enum.map(ets_info, & &1.size))
    
    # Estimate operations per second based on recent activity
    operations_estimate = estimate_storage_operations()
    
    %{
      ets_tables: length(ets_info),
      ets_objects: total_ets_objects,
      ets_memory_kb: Float.round(total_ets_memory / 1024, 1),
      operations_per_sec: operations_estimate,
      efficiency: calculate_storage_efficiency(total_ets_memory, total_ets_objects)
    }
  end
  
  defp calculate_process_efficiency_metrics(processes) do
    # Analyze process efficiency
    process_info = processes
    |> Enum.map(fn pid ->
      try do
        info = Process.info(pid, [:memory, :message_queue_len, :reductions, :registered_name])
        if info do
          %{
            pid: pid,
            memory: info[:memory] || 0,
            queue_len: info[:message_queue_len] || 0,
            reductions: info[:reductions] || 0,
            name: info[:registered_name]
          }
        end
      rescue
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    # Calculate efficiency metrics
    avg_memory = if length(process_info) > 0 do
      Enum.sum(Enum.map(process_info, & &1.memory)) / length(process_info)
    else
      0
    end
    
    active_processes = Enum.count(process_info, & &1.queue_len > 0)
    
    %{
      total_count: length(processes),
      active_count: active_processes,
      average_memory_kb: Float.round(avg_memory / 1024, 1),
      efficiency: if(length(processes) > 0, do: active_processes / length(processes), else: 0.0),
      memory_distribution: calculate_memory_distribution(process_info)
    }
  end
  
  defp initialize_real_resource_pools(real_metrics) do
    # Initialize pools based on actual system capacity
    %{
      compute: %{
        total: 1.0,  # Normalized CPU capacity
        allocated: real_metrics.cpu.utilization,
        reserved: 0.0,
        actual_usage: real_metrics.cpu.utilization,
        baseline: real_metrics.cpu.utilization
      },
      memory: %{
        total: real_metrics.memory.total_mb,
        allocated: real_metrics.memory.processes_mb,
        reserved: 0.0,
        actual_usage: real_metrics.memory.processes_mb,
        baseline: real_metrics.memory.processes_mb
      },
      network: %{
        total: 1000.0,  # Assume 1Gbps capacity in Mbps
        allocated: real_metrics.network.throughput_mbps,
        reserved: 0.0,
        actual_usage: real_metrics.network.throughput_mbps,
        baseline: real_metrics.network.throughput_mbps
      },
      storage: %{
        total: 10000.0,  # Assume 10K IOPS capacity
        allocated: real_metrics.storage.operations_per_sec,
        reserved: 0.0,
        actual_usage: real_metrics.storage.operations_per_sec,
        baseline: real_metrics.storage.operations_per_sec
      }
    }
  end
  
  defp calculate_real_pool_metrics(pools, real_metrics) do
    Enum.map(pools, fn {resource, pool} ->
      actual_usage = case resource do
        :compute -> real_metrics.cpu.utilization
        :memory -> real_metrics.memory.processes_mb
        :network -> real_metrics.network.throughput_mbps
        :storage -> real_metrics.storage.operations_per_sec
      end
      
      efficiency = if pool.allocated > 0 do
        actual_usage / pool.allocated
      else
        1.0
      end
      
      {resource, %{
        utilization: if(pool.total > 0, do: pool.allocated / pool.total, else: 0),
        actual_utilization: if(pool.total > 0, do: actual_usage / pool.total, else: 0),
        available: pool.total - pool.allocated - pool.reserved,
        efficiency: Float.round(efficiency * 1.0, 3),
        waste: Float.round(abs(pool.allocated - actual_usage) * 1.0, 3),
        pressure: calculate_resource_pressure_level(actual_usage, pool.total)
      }}
    end)
    |> Map.new()
  end
  
  defp calculate_real_efficiency(state, real_metrics) do
    # Calculate efficiency based on allocated vs. actual usage
    total_efficiency = state.resource_pools
    |> Enum.map(fn {resource, pool} ->
      actual_usage = case resource do
        :compute -> real_metrics.cpu.utilization
        :memory -> real_metrics.memory.processes_mb
        :network -> real_metrics.network.throughput_mbps
        :storage -> real_metrics.storage.operations_per_sec
      end
      
      if pool.allocated > 0 do
        min(actual_usage / pool.allocated, 1.0)
      else
        1.0
      end
    end)
    |> Enum.sum()
    |> Kernel./(4)  # Average across 4 resource types
    
    Float.round(total_efficiency, 3)
  end
  
  defp calculate_real_utilization(real_metrics) do
    # Calculate actual system utilization
    cpu_util = real_metrics.cpu.utilization
    memory_util = real_metrics.memory.processes_mb / max(real_metrics.memory.total_mb, 1)
    
    # Average utilization
    (cpu_util + memory_util) / 2
    |> Float.round(3)
  end
  
  # Additional helper functions
  
  defp get_safe_scheduler_utilization do
    try do
      case :scheduler.utilization(1) do
        [utilization | _] when is_tuple(utilization) -> 
          elem(utilization, 1) |> Float.round(3)
        _ -> 0.0
      end
    rescue
      _ -> 0.0
    catch
      _, _ -> 0.0
    end
  end
  
  defp calculate_cpu_efficiency(utilization, run_queue) do
    # CPU efficiency decreases with high run queue
    base_efficiency = utilization
    queue_penalty = min(run_queue / 100, 0.5)  # Max 50% penalty
    
    max(0.0, base_efficiency - queue_penalty)
    |> Float.round(3)
  end
  
  defp calculate_memory_efficiency(memory) do
    # Memory efficiency based on fragmentation and usage patterns
    total = memory[:total]
    processes = memory[:processes]
    system = memory[:system]
    
    if total > 0 do
      # Efficiency is ratio of useful memory (processes) to total
      useful_ratio = processes / total
      
      # Penalize high system overhead
      system_overhead = system / total
      efficiency = useful_ratio * (1.0 - min(system_overhead, 0.5))
      
      Float.round(efficiency, 3)
    else
      0.0
    end
  end
  
  defp calculate_network_efficiency(io_bytes, message_activity) do
    # Network efficiency based on message activity vs. IO
    if message_activity > 0 do
      bytes_per_message = io_bytes / message_activity
      
      # Efficiency is inverse of bytes per message (lower is better)
      if bytes_per_message > 0 do
        min(1000 / bytes_per_message, 1.0)
        |> Float.round(3)
      else
        1.0
      end
    else
      1.0
    end
  end
  
  defp calculate_storage_efficiency(memory_bytes, object_count) do
    # Storage efficiency based on memory per object
    if object_count > 0 do
      bytes_per_object = memory_bytes / object_count
      
      # Efficiency decreases with larger objects (may indicate waste)
      if bytes_per_object > 0 do
        min(1000 / bytes_per_object, 1.0)
        |> Float.round(3)
      else
        1.0
      end
    else
      1.0
    end
  end
  
  defp estimate_storage_operations do
    # Estimate storage operations based on ETS activity
    # This is a simplified estimation
    try do
      # Count active ETS tables as proxy for storage activity
      active_tables = :ets.all() |> length()
      # Estimate operations based on table count
      active_tables * 10  # Rough estimate
    rescue
      _ -> 0
    end
  end
  
  defp calculate_process_memory_distribution(processes) do
    memory_buckets = %{
      "< 1MB" => 0,
      "1-10MB" => 0,
      "10-50MB" => 0,
      "> 50MB" => 0
    }
    
    processes
    |> Enum.reduce(memory_buckets, fn pid, acc ->
      # Get process info and extract memory
      memory_bytes = try do
        case Process.info(pid, :memory) do
          {:memory, bytes} -> bytes
          nil -> 0
        end
      rescue
        _ -> 0
      end
      
      memory_mb = memory_bytes / 1_048_576
      
      cond do
        memory_mb < 1 -> Map.update(acc, "< 1MB", 1, &(&1 + 1))
        memory_mb < 10 -> Map.update(acc, "1-10MB", 1, &(&1 + 1))
        memory_mb < 50 -> Map.update(acc, "10-50MB", 1, &(&1 + 1))
        true -> Map.update(acc, "> 50MB", 1, &(&1 + 1))
      end
    end)
  end
  
  defp calculate_memory_distribution(process_info) do
    memory_buckets = %{
      "< 1MB" => 0,
      "1-10MB" => 0,
      "10-50MB" => 0,
      "> 50MB" => 0
    }
    
    process_info
    |> Enum.reduce(memory_buckets, fn info, acc ->
      memory_mb = info.memory / 1_048_576
      
      cond do
        memory_mb < 1 -> Map.update(acc, "< 1MB", 1, &(&1 + 1))
        memory_mb < 10 -> Map.update(acc, "1-10MB", 1, &(&1 + 1))
        memory_mb < 50 -> Map.update(acc, "10-50MB", 1, &(&1 + 1))
        true -> Map.update(acc, "> 50MB", 1, &(&1 + 1))
      end
    end)
  end
  
  defp update_pools_with_real_data(pools, real_metrics) do
    # Update pools to reflect actual usage
    pools
    |> Map.update(:compute, %{}, fn pool ->
      Map.put(pool, :actual_usage, real_metrics.cpu.utilization)
    end)
    |> Map.update(:memory, %{}, fn pool ->
      Map.put(pool, :actual_usage, real_metrics.memory.processes_mb)
    end)
    |> Map.update(:network, %{}, fn pool ->
      Map.put(pool, :actual_usage, real_metrics.network.throughput_mbps)
    end)
    |> Map.update(:storage, %{}, fn pool ->
      Map.put(pool, :actual_usage, real_metrics.storage.operations_per_sec)
    end)
  end
  
  defp calculate_resource_pressure_level(usage, capacity) do
    if capacity > 0 do
      ratio = usage / capacity
      
      cond do
        ratio > 0.9 -> :critical
        ratio > 0.7 -> :high
        ratio > 0.5 -> :moderate
        true -> :low
      end
    else
      :unknown
    end
  end
  
  defp calculate_total_allocated(allocations) do
    # Sum all allocated resources across all allocations
    allocations
    |> Map.values()
    |> Enum.reduce(%{compute: 0, memory: 0, network: 0, storage: 0}, fn allocation, acc ->
      case allocation do
        %{resources: resources} when is_map(resources) ->
          %{
            compute: acc.compute + (resources[:compute] || 0),
            memory: acc.memory + (resources[:memory] || 0),
            network: acc.network + (resources[:network] || 0),
            storage: acc.storage + (resources[:storage] || 0)
          }
        %AMQP.Channel{} ->
          Logger.warning("Control: AMQP.Channel found in allocations - this is a bug!")
          acc
        other ->
          Logger.warning("Control: Unexpected allocation type: #{inspect(other)}")
          acc
      end
    end)
  end
  
  defp group_allocations_by_resource(allocations) do
    # Group allocations by resource type for analysis
    allocations
    |> Enum.flat_map(fn {id, allocation} ->
      resources = allocation[:resources] || %{}
      
      Enum.map(resources, fn {resource_type, amount} ->
        %{
          allocation_id: id,
          resource_type: resource_type,
          amount: amount,
          context: allocation[:context],
          priority: allocation[:priority] || :normal
        }
      end)
    end)
    |> Enum.group_by(& &1.resource_type)
  end
  
  defp calculate_allocation_effectiveness(state, real_metrics) do
    # Calculate how effectively allocated resources are being used
    if map_size(state.allocations) == 0 do
      1.0  # Perfect efficiency with no allocations
    else
      total_allocated = calculate_total_allocated(state.allocations)
      
      # Compare allocated vs. actual usage
      effectiveness_scores = [
        calculate_resource_effectiveness(:compute, total_allocated.compute, real_metrics.cpu.utilization),
        calculate_resource_effectiveness(:memory, total_allocated.memory, real_metrics.memory.processes_mb),
        calculate_resource_effectiveness(:network, total_allocated.network, real_metrics.network.throughput_mbps),
        calculate_resource_effectiveness(:storage, total_allocated.storage, real_metrics.storage.operations_per_sec)
      ]
      
      Enum.sum(effectiveness_scores) / length(effectiveness_scores)
      |> Float.round(3)
    end
  end
  
  defp calculate_resource_effectiveness(_resource, 0, _actual), do: 1.0
  defp calculate_resource_effectiveness(_resource, allocated, actual) do
    # Effectiveness is actual usage / allocated, capped at 1.0
    min(actual / allocated, 1.0)
    |> Float.round(3)
  end
  
  defp calculate_real_optimization_potential(state, real_metrics) do
    # Calculate optimization potential based on waste and inefficiency
    efficiency = calculate_real_efficiency(state, real_metrics)
    waste = calculate_real_waste(state, real_metrics)
    
    # Potential is inverse of efficiency plus waste
    potential = (1.0 - efficiency) + waste
    
    Float.round(min(potential, 1.0), 3)
  end
  
  defp calculate_real_waste(state, real_metrics) do
    # Calculate waste as allocated but unused resources
    if map_size(state.allocations) > 0 do
      total_allocated = calculate_total_allocated(state.allocations)
      
      waste_ratios = [
        calculate_waste_ratio(total_allocated.compute, real_metrics.cpu.utilization),
        calculate_waste_ratio(total_allocated.memory, real_metrics.memory.processes_mb),
        calculate_waste_ratio(total_allocated.network, real_metrics.network.throughput_mbps),
        calculate_waste_ratio(total_allocated.storage, real_metrics.storage.operations_per_sec)
      ]
      
      Enum.sum(waste_ratios) / length(waste_ratios)
      |> Float.round(3)
    else
      0.0
    end
  end
  
  defp calculate_waste_ratio(allocated, actual) do
    if allocated > 0 do
      max(0.0, (allocated - actual) / allocated)
    else
      0.0
    end
  end
  
  defp calculate_resource_trends(history) do
    if length(history) < 5 do
      %{
        cpu: %{direction: :unknown, rate: 0.0},
        memory: %{direction: :unknown, rate: 0.0},
        network: %{direction: :unknown, rate: 0.0},
        storage: %{direction: :unknown, rate: 0.0}
      }
    else
      recent = Enum.take(history, 10)
      
      %{
        cpu: calculate_trend(recent, [:cpu, :utilization]),
        memory: calculate_trend(recent, [:memory, :processes_mb]),
        network: calculate_trend(recent, [:network, :throughput_mbps]),
        storage: calculate_trend(recent, [:storage, :operations_per_sec])
      }
    end
  end
  
  defp calculate_trend(history, path) do
    values = history
    |> Enum.map(fn metrics -> get_in(metrics, path) || 0 end)
    |> Enum.reverse()  # Chronological order
    
    if length(values) < 2 do
      %{direction: :unknown, rate: 0.0}
    else
      # Simple linear trend
      first_half = Enum.take(values, div(length(values), 2))
      second_half = Enum.drop(values, div(length(values), 2))
      
      avg_first = Enum.sum(first_half) / length(first_half)
      avg_second = Enum.sum(second_half) / length(second_half)
      
      rate = avg_second - avg_first
      
      direction = cond do
        rate > 0.05 -> :increasing
        rate < -0.05 -> :decreasing
        true -> :stable
      end
      
      %{direction: direction, rate: Float.round(rate, 3)}
    end
  end
  
  defp identify_real_bottlenecks(real_metrics) do
    bottlenecks = []
    
    # CPU bottleneck
    if real_metrics.cpu.pressure in [:high, :critical] do
      bottlenecks = [%{
        type: :cpu,
        severity: real_metrics.cpu.pressure,
        details: %{
          utilization: real_metrics.cpu.utilization,
          run_queue: real_metrics.cpu.run_queue_length
        }
      } | bottlenecks]
    end
    
    # Memory bottleneck
    if real_metrics.memory.pressure in [:high, :critical] do
      bottlenecks = [%{
        type: :memory,
        severity: real_metrics.memory.pressure,
        details: %{
          total_mb: real_metrics.memory.total_mb,
          processes_mb: real_metrics.memory.processes_mb
        }
      } | bottlenecks]
    end
    
    # Process bottleneck (low efficiency)
    if real_metrics.processes.efficiency < 0.3 do
      bottlenecks = [%{
        type: :process_efficiency,
        severity: :medium,
        details: %{
          efficiency: real_metrics.processes.efficiency,
          active_ratio: real_metrics.processes.active_count / real_metrics.processes.total_count
        }
      } | bottlenecks]
    end
    
    bottlenecks
  end
  
  defp calculate_resource_health_score(real_metrics) do
    # Calculate overall resource health
    scores = [
      # CPU health (lower is better for run queue, higher for utilization)
      calculate_cpu_health_score(real_metrics.cpu),
      # Memory health
      calculate_memory_health_score(real_metrics.memory),
      # Process health
      real_metrics.processes.efficiency,
      # Network health (assume good if no obvious issues)
      0.9
    ]
    
    Enum.sum(scores) / length(scores)
    |> Float.round(3)
  end
  
  defp calculate_cpu_health_score(cpu_metrics) do
    # CPU health based on utilization and pressure
    util_score = 1.0 - cpu_metrics.utilization  # Lower utilization is better
    pressure_score = case cpu_metrics.pressure do
      :low -> 1.0
      :moderate -> 0.7
      :high -> 0.4
      :critical -> 0.1
    end
    
    (util_score + pressure_score) / 2
  end
  
  defp calculate_memory_health_score(memory_metrics) do
    # Memory health based on pressure and efficiency
    pressure_score = case memory_metrics.pressure do
      :low -> 1.0
      :moderate -> 0.7
      :high -> 0.4
      :critical -> 0.1
    end
    
    efficiency_score = memory_metrics.efficiency
    
    (pressure_score + efficiency_score) / 2
  end
  
  # Scheduling functions
  
  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, 10_000)  # Every 10 seconds
  end
  
  defp schedule_resource_audit do
    Process.send_after(self(), :resource_audit, 60_000)  # Every minute
  end
  
  # Additional functions for dynamic behavior
  
  defp calculate_real_performance_metrics(state, real_metrics) do
    %{
      efficiency: calculate_real_efficiency(state, real_metrics),
      utilization: calculate_real_utilization(real_metrics),
      waste: calculate_real_waste(state, real_metrics),
      bottlenecks: identify_real_bottlenecks(real_metrics),
      last_calculated: DateTime.utc_now(),
      health_score: calculate_resource_health_score(real_metrics)
    }
  end
  
  defp real_global_optimization(state, real_metrics) do
    # Real optimization based on actual metrics
    bottlenecks = identify_real_bottlenecks(real_metrics)
    waste = calculate_real_waste(state, real_metrics)
    
    actions = []
    
    # Add actions based on real bottlenecks
    actions = if Enum.any?(bottlenecks, & &1.type == :cpu) do
      [optimize_cpu_usage(real_metrics) | actions]
    else
      actions
    end
    
    actions = if Enum.any?(bottlenecks, & &1.type == :memory) do
      [optimize_memory_allocation(real_metrics) | actions]
    else
      actions
    end
    
    # Add waste reduction if significant waste detected
    actions = if waste > 0.1 do
      [reduce_resource_waste(state, real_metrics) | actions]
    else
      actions
    end
    
    estimated_improvement = min(waste * 0.5, 0.3)  # Can improve up to 50% of waste
    
    %{
      type: :real_global,
      actions: actions,
      estimated_improvement: estimated_improvement,
      risk: determine_optimization_risk(actions),
      based_on_metrics: true
    }
  end
  
  defp optimize_cpu_usage(real_metrics) do
    %{
      action: :optimize_cpu,
      target: :reduce_run_queue,
      details: real_metrics.cpu,
      estimated_improvement: 0.1
    }
  end
  
  defp optimize_memory_allocation(real_metrics) do
    %{
      action: :optimize_memory,
      target: :reduce_pressure,
      details: real_metrics.memory,
      estimated_improvement: 0.15
    }
  end
  
  defp reduce_resource_waste(state, real_metrics) do
    waste_analysis = analyze_allocation_waste(state, real_metrics)
    
    %{
      action: :reduce_waste,
      target: :deallocate_unused,
      waste_analysis: waste_analysis,
      estimated_improvement: waste_analysis.potential_savings
    }
  end
  
  defp analyze_allocation_waste(state, real_metrics) do
    # Analyze which allocations are wasteful
    total_allocated = calculate_total_allocated(state.allocations)
    
    waste_by_resource = %{
      compute: calculate_waste_ratio(total_allocated.compute, real_metrics.cpu.utilization),
      memory: calculate_waste_ratio(total_allocated.memory, real_metrics.memory.processes_mb),
      network: calculate_waste_ratio(total_allocated.network, real_metrics.network.throughput_mbps),
      storage: calculate_waste_ratio(total_allocated.storage, real_metrics.storage.operations_per_sec)
    }
    
    total_waste = Enum.sum(Map.values(waste_by_resource)) / 4
    
    %{
      by_resource: waste_by_resource,
      total_waste: Float.round(total_waste, 3),
      potential_savings: Float.round(total_waste * 0.7, 3)  # Can recover 70% of waste
    }
  end
  
  defp determine_optimization_risk(actions) do
    risk_levels = Enum.map(actions, fn action ->
      case action.action do
        :optimize_cpu -> :medium
        :optimize_memory -> :low
        :reduce_waste -> :low
        _ -> :minimal
      end
    end)
    
    # Take highest risk level
    if :medium in risk_levels, do: :medium, else: :low
  end
  
  defp update_resource_baselines(baselines, history) do
    if length(history) > 20 do
      # Calculate new baselines from stable periods
      stable_metrics = history |> Enum.take(15) |> Enum.drop(5)
      
      %{
        cpu_utilization: calculate_baseline_value(stable_metrics, [:cpu, :utilization]),
        memory_usage: calculate_baseline_value(stable_metrics, [:memory, :processes_mb]),
        network_throughput: calculate_baseline_value(stable_metrics, [:network, :throughput_mbps]),
        storage_ops: calculate_baseline_value(stable_metrics, [:storage, :operations_per_sec])
      }
    else
      baselines
    end
  end
  
  defp calculate_baseline_value(metrics, path) do
    values = metrics
    |> Enum.map(fn m -> get_in(m, path) end)
    |> Enum.reject(&is_nil/1)
    
    if Enum.empty?(values) do
      0.0
    else
      # Use median as baseline
      sorted = Enum.sort(values)
      mid = div(length(sorted), 2)
      
      if rem(length(sorted), 2) == 0 do
        (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
      else
        Enum.at(sorted, mid)
      end
      |> Float.round(3)
    end
  end
  
  defp perform_resource_audit(state) do
    # Comprehensive resource audit
    current_metrics = state.real_metrics || collect_real_system_metrics()
    
    # Analyze allocation effectiveness
    allocation_analysis = analyze_allocation_effectiveness(state, current_metrics)
    
    # Calculate waste
    waste_analysis = analyze_allocation_waste(state, current_metrics)
    
    # Identify optimization opportunities
    optimization_ops = identify_optimization_opportunities(state, current_metrics)
    
    %{
      timestamp: DateTime.utc_now(),
      allocation_effectiveness: allocation_analysis,
      waste_analysis: waste_analysis,
      waste_percentage: waste_analysis.total_waste,
      optimization_opportunities: optimization_ops,
      resource_health: calculate_resource_health_score(current_metrics),
      recommendations: generate_audit_recommendations(waste_analysis, optimization_ops)
    }
  end
  
  defp analyze_allocation_effectiveness(state, real_metrics) do
    # Detailed analysis of how well allocations are being used
    allocations = state.allocations
    
    if map_size(allocations) == 0 do
      %{score: 1.0, details: "No allocations to analyze"}
    else
      effectiveness_by_allocation = allocations
      |> Enum.map(fn {id, allocation} ->
        resources = allocation[:resources] || %{}
        
        # Calculate effectiveness for this allocation
        effectiveness = calculate_single_allocation_effectiveness(resources, real_metrics)
        
        {id, %{
          context: allocation[:context],
          effectiveness: effectiveness,
          resources: resources,
          waste: calculate_allocation_waste(resources, real_metrics)
        }}
      end)
      |> Map.new()
      
      overall_effectiveness = effectiveness_by_allocation
      |> Map.values()
      |> Enum.map(& &1.effectiveness)
      |> case do
        [] -> 1.0
        scores -> Enum.sum(scores) / length(scores)
      end
      
      %{
        score: Float.round(overall_effectiveness, 3),
        by_allocation: effectiveness_by_allocation,
        total_allocations: map_size(allocations)
      }
    end
  end
  
  defp calculate_single_allocation_effectiveness(resources, real_metrics) do
    # Calculate effectiveness for a single allocation
    resource_scores = resources
    |> Enum.map(fn {type, allocated} ->
      actual = case type do
        :compute -> real_metrics.cpu.utilization
        :memory -> real_metrics.memory.processes_mb
        :network -> real_metrics.network.throughput_mbps
        :storage -> real_metrics.storage.operations_per_sec
        _ -> 0
      end
      
      if allocated > 0 do
        min(actual / allocated, 1.0)
      else
        1.0
      end
    end)
    
    if Enum.empty?(resource_scores) do
      1.0
    else
      Enum.sum(resource_scores) / length(resource_scores)
    end
  end
  
  defp calculate_allocation_waste(resources, real_metrics) do
    # Calculate waste for a single allocation
    waste_amounts = resources
    |> Enum.map(fn {type, allocated} ->
      actual = case type do
        :compute -> real_metrics.cpu.utilization
        :memory -> real_metrics.memory.processes_mb
        :network -> real_metrics.network.throughput_mbps
        :storage -> real_metrics.storage.operations_per_sec
        _ -> 0
      end
      
      max(0, allocated - actual)
    end)
    
    Enum.sum(waste_amounts)
  end
  
  defp identify_optimization_opportunities(state, real_metrics) do
    opportunities = []
    
    # CPU optimization
    if real_metrics.cpu.pressure in [:high, :critical] do
      opportunities = [%{
        type: :cpu_pressure_relief,
        priority: :high,
        action: "Reduce CPU-intensive operations or redistribute load",
        potential_impact: 0.2
      } | opportunities]
    end
    
    # Memory optimization
    if real_metrics.memory.pressure in [:high, :critical] do
      opportunities = [%{
        type: :memory_pressure_relief,
        priority: :high,
        action: "Garbage collection or memory reallocation",
        potential_impact: 0.15
      } | opportunities]
    end
    
    # Process efficiency
    if real_metrics.processes.efficiency < 0.5 do
      opportunities = [%{
        type: :process_optimization,
        priority: :medium,
        action: "Consolidate idle processes or improve task distribution",
        potential_impact: 0.1
      } | opportunities]
    end
    
    # Allocation waste
    waste = calculate_real_waste(state, real_metrics)
    if waste > 0.1 do
      opportunities = [%{
        type: :allocation_cleanup,
        priority: :medium,
        action: "Deallocate unused resources",
        potential_impact: waste * 0.8
      } | opportunities]
    end
    
    opportunities
    |> Enum.sort_by(& &1.potential_impact, :desc)
  end
  
  defp generate_audit_recommendations(waste_analysis, optimization_ops) do
    recommendations = []
    
    # Waste-based recommendations
    if waste_analysis.total_waste > 0.1 do
      recommendations = ["Deallocate #{Float.round(waste_analysis.total_waste * 100, 1)}% wasted resources" | recommendations]
    end
    
    # Add optimization recommendations
    opt_recommendations = optimization_ops
    |> Enum.take(3)
    |> Enum.map(& &1.action)
    
    recommendations ++ opt_recommendations
  end
  
  defp update_allocation_tracker(tracker, real_metrics) do
    # Update allocation usage tracking with real metrics
    current_time = System.monotonic_time(:millisecond)
    
    Map.merge(tracker, %{
      last_update: current_time,
      cpu_usage_history: update_usage_history(tracker[:cpu_usage_history], real_metrics.cpu.utilization),
      memory_usage_history: update_usage_history(tracker[:memory_usage_history], real_metrics.memory.processes_mb),
      efficiency_trend: calculate_efficiency_trend(tracker)
    })
  end
  
  defp update_usage_history(history, current_value) do
    [{System.monotonic_time(:millisecond), current_value} | (history || [])]
    |> Enum.take(50)  # Keep last 50 measurements
  end
  
  defp calculate_efficiency_trend(tracker) do
    # Calculate trend in resource efficiency
    if tracker[:efficiency_history] && length(tracker.efficiency_history) > 3 do
      recent = Enum.take(tracker.efficiency_history, 5)
      first_half = Enum.take(recent, 2) |> Enum.map(&elem(&1, 1))
      second_half = Enum.drop(recent, 3) |> Enum.map(&elem(&1, 1))
      
      if length(first_half) > 0 && length(second_half) > 0 do
        avg_first = Enum.sum(first_half) / length(first_half)
        avg_second = Enum.sum(second_half) / length(second_half)
        
        cond do
          avg_second > avg_first -> :improving
          avg_second < avg_first -> :degrading
          true -> :stable
        end
      else
        :unknown
      end
    else
      :unknown
    end
  end
  
  defp calculate_variety_impact_on_resources(variety_metrics) do
    # Calculate how variety affects resource requirements
    if variety_metrics && variety_metrics[:summary] do
      summary = variety_metrics.summary
      
      # High variety typically requires more resources
      variety_pressure = summary[:total_input_variety] || 0
      
      # Calculate resource impact
      %{
        compute_impact: min(variety_pressure * 0.1, 0.3),
        memory_impact: min(variety_pressure * 0.05, 0.2),
        network_impact: min(variety_pressure * 0.08, 0.25),
        storage_impact: min(variety_pressure * 0.03, 0.15)
      }
    else
      %{compute_impact: 0, memory_impact: 0, network_impact: 0, storage_impact: 0}
    end
  end
  
  defp adjust_pools_for_variety(pools, variety_impact) do
    # Adjust resource pools based on variety requirements
    pools
    |> Map.update(:compute, %{}, fn pool ->
      Map.update(pool, :reserved, 0, &max(&1, variety_impact.compute_impact))
    end)
    |> Map.update(:memory, %{}, fn pool ->
      Map.update(pool, :reserved, 0, &max(&1, variety_impact.memory_impact))
    end)
    |> Map.update(:network, %{}, fn pool ->
      Map.update(pool, :reserved, 0, &max(&1, variety_impact.network_impact))
    end)
    |> Map.update(:storage, %{}, fn pool ->
      Map.update(pool, :reserved, 0, &max(&1, variety_impact.storage_impact))
    end)
  end
  
  defp waste_reduction_optimization(audit_result, state) do
    # Targeted optimization to reduce waste
    waste_analysis = audit_result.waste_analysis
    
    actions = []
    
    # Add specific waste reduction actions
    actions = if waste_analysis.by_resource.memory > 0.1 do
      [%{action: :reduce_memory_waste, impact: waste_analysis.by_resource.memory} | actions]
    else
      actions
    end
    
    actions = if waste_analysis.by_resource.compute > 0.1 do
      [%{action: :reduce_cpu_waste, impact: waste_analysis.by_resource.compute} | actions]
    else
      actions
    end
    
    %{
      type: :waste_reduction,
      actions: actions,
      estimated_improvement: waste_analysis.potential_savings,
      risk: :low
    }
  end
  
  # New functions referenced by updated Health Checker
  
  def reduce_monitoring do
    GenServer.cast(@name, :reduce_monitoring_overhead)
  end
  
  @impl true
  def handle_cast(:reduce_monitoring_overhead, state) do
    Logger.info("🔧 S3 Control: Reducing monitoring overhead")
    
    # Increase monitoring intervals to reduce CPU usage
    Process.send_after(self(), :increase_monitoring_intervals, 1000)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:increase_monitoring_intervals, state) do
    # Temporarily reduce monitoring frequency
    Logger.info("⏱️ S3 Control: Increasing monitoring intervals to reduce load")
    {:noreply, state}
  end

  # Pure Systemic Pattern Functions

  defp collect_systemic_patterns do
    # Collect domain-agnostic systemic patterns
    memory = :erlang.memory()
    processes = Process.list()
    
    # Flow capacity patterns
    flow_metrics = calculate_flow_capacity_patterns()
    
    # Throughput patterns
    throughput_metrics = calculate_throughput_patterns(processes)
    
    # Allocation patterns
    allocation_metrics = calculate_allocation_patterns(processes)
    
    # Constraint patterns
    constraint_metrics = calculate_constraint_patterns()
    
    %{
      timestamp: DateTime.utc_now(),
      flow_capacity: flow_metrics,
      throughput: throughput_metrics,
      allocation: allocation_metrics,
      constraints: constraint_metrics
    }
  end

  defp initialize_flow_pools(flow_patterns) do
    # Initialize flow pools based on capacity patterns
    %{
      primary_flow: %{
        total_capacity: 1.0,
        allocated_capacity: flow_patterns.flow_capacity.primary_utilization,
        reserved_capacity: 0.0,
        actual_usage: flow_patterns.flow_capacity.primary_utilization,
        baseline_usage: flow_patterns.flow_capacity.primary_utilization
      },
      secondary_flow: %{
        total_capacity: flow_patterns.throughput.secondary_capacity,
        allocated_capacity: flow_patterns.throughput.secondary_usage,
        reserved_capacity: 0.0,
        actual_usage: flow_patterns.throughput.secondary_usage,
        baseline_usage: flow_patterns.throughput.secondary_usage
      },
      auxiliary_flow: %{
        total_capacity: flow_patterns.allocation.auxiliary_capacity,
        allocated_capacity: flow_patterns.allocation.auxiliary_usage,
        reserved_capacity: 0.0,
        actual_usage: flow_patterns.allocation.auxiliary_usage,
        baseline_usage: flow_patterns.allocation.auxiliary_usage
      },
      regulatory_flow: %{
        total_capacity: flow_patterns.constraints.regulatory_capacity,
        allocated_capacity: flow_patterns.constraints.regulatory_usage,
        reserved_capacity: 0.0,
        actual_usage: flow_patterns.constraints.regulatory_usage,
        baseline_usage: flow_patterns.constraints.regulatory_usage
      }
    }
  end

  defp calculate_flow_utilization(flow_patterns) do
    # Resource Utilization - generic usage percentage
    %{
      primary: calculate_utilization_percentage(flow_patterns.flow_capacity.primary_utilization, 1.0),
      secondary: calculate_utilization_percentage(flow_patterns.throughput.secondary_usage, flow_patterns.throughput.secondary_capacity),
      auxiliary: calculate_utilization_percentage(flow_patterns.allocation.auxiliary_usage, flow_patterns.allocation.auxiliary_capacity),
      regulatory: calculate_utilization_percentage(flow_patterns.constraints.regulatory_usage, flow_patterns.constraints.regulatory_capacity),
      overall: calculate_overall_utilization(flow_patterns)
    }
  end

  defp calculate_allocation_efficiency(state, flow_patterns) do
    # Allocation Efficiency - used vs allocated ratio
    if map_size(state.allocations) == 0 do
      1.0
    else
      total_allocated = calculate_total_allocated_flows(state.allocations)
      total_used = calculate_total_used_flows(flow_patterns)
      
      if total_allocated > 0 do
        Float.round(total_used / total_allocated, 3)
      else
        1.0
      end
    end
  end

  defp calculate_action_frequency(optimization_actions) do
    # Calculate frequency of optimization actions
    if Enum.empty?(optimization_actions) do
      0.0
    else
      time_span_hours = calculate_time_span_hours(optimization_actions)
      if time_span_hours > 0 do
        length(optimization_actions) / time_span_hours
      else
        0.0
      end
    end
  end

  defp calculate_action_effectiveness(optimization_actions) do
    # Calculate effectiveness ratio of optimization actions
    effectiveness_scores = optimization_actions
    |> Enum.map(fn action ->
      actual_impact = action[:actual_impact] || action[:estimated_impact] || 0
      estimated_impact = action[:estimated_impact] || 1
      
      if estimated_impact > 0 do
        min(actual_impact / estimated_impact, 1.0)
      else
        0.0
      end
    end)
    
    if Enum.empty?(effectiveness_scores) do
      1.0
    else
      Enum.sum(effectiveness_scores) / length(effectiveness_scores)
      |> Float.round(3)
    end
  end

  defp identify_active_violations(flow_patterns, state) do
    # Identify current constraint violations
    violations = []
    
    # Capacity violations
    violations = check_capacity_violations(flow_patterns, violations, state)
    
    # Rate violations
    violations = check_rate_violations(flow_patterns, violations, state)
    
    # Balance violations
    violations = check_balance_violations(flow_patterns, violations, state)
    
    violations
  end

  defp calculate_breach_frequency(constraint_history) do
    # Calculate frequency of constraint breaches
    if Enum.empty?(constraint_history) do
      0.0
    else
      time_span_hours = calculate_time_span_hours(constraint_history)
      if time_span_hours > 0 do
        length(constraint_history) / time_span_hours
      else
        0.0
      end
    end
  end

  defp calculate_violation_severity(constraint_history) do
    # Calculate distribution of violation severity
    severity_counts = constraint_history
    |> Enum.group_by(fn record -> record[:violation_type] || :unknown end)
    |> Enum.map(fn {severity, records} -> {severity, length(records)} end)
    |> Map.new()
    
    total = length(constraint_history)
    
    if total > 0 do
      severity_counts
      |> Enum.map(fn {severity, count} -> {severity, Float.round(count / total, 3)} end)
      |> Map.new()
    else
      %{}
    end
  end

  defp calculate_pure_waste_ratio(state, flow_patterns) do
    # Waste Ratio - allocated but unused
    if map_size(state.allocations) == 0 do
      0.0
    else
      total_allocated = calculate_total_allocated_flows(state.allocations)
      total_used = calculate_total_used_flows(flow_patterns)
      
      waste = max(0, total_allocated - total_used)
      
      if total_allocated > 0 do
        Float.round(waste / total_allocated, 3)
      else
        0.0
      end
    end
  end

  # Supporting pattern calculation functions

  defp calculate_flow_capacity_patterns do
    # Calculate primary flow capacity patterns
    scheduler_util = get_safe_scheduler_utilization()
    run_queue = :erlang.statistics(:run_queue)
    
    %{
      primary_utilization: scheduler_util,
      capacity_pressure: calculate_capacity_pressure(run_queue),
      flow_efficiency: calculate_flow_efficiency(scheduler_util, run_queue)
    }
  end

  defp calculate_throughput_patterns(processes) do
    # Calculate secondary throughput patterns
    {input, output} = try do
      case :erlang.statistics(:io) do
        {{input_val, output_val}, _} when is_number(input_val) and is_number(output_val) ->
          {input_val, output_val}
        _ ->
          {0, 0}
      end
    rescue
      _ -> {0, 0}
    end
    
    message_throughput = calculate_message_throughput(processes)
    
    %{
      secondary_capacity: estimate_secondary_capacity(input + output),
      secondary_usage: (input + output) / 1_048_576,  # MB
      throughput_rate: message_throughput,
      flow_velocity: calculate_flow_velocity(input, output, message_throughput)
    }
  end

  defp calculate_allocation_patterns(processes) do
    # Calculate auxiliary allocation patterns
    process_count = length(processes)
    active_processes = count_active_processes(processes)
    
    %{
      auxiliary_capacity: Float.round(process_count / 100.0, 2),  # Normalized
      auxiliary_usage: Float.round(active_processes / max(process_count, 1), 3),
      allocation_density: calculate_allocation_density(processes),
      pattern_complexity: calculate_pattern_complexity(processes)
    }
  end

  defp calculate_constraint_patterns do
    # Calculate regulatory constraint patterns
    memory = :erlang.memory()
    ets_tables = :ets.all()
    
    %{
      regulatory_capacity: length(ets_tables) / 100.0,  # Normalized
      regulatory_usage: memory[:ets] / 1_048_576,  # MB
      constraint_density: calculate_constraint_density(ets_tables),
      regulatory_pressure: calculate_regulatory_pressure(memory)
    }
  end

  # Pattern optimization functions

  defp systemic_pattern_optimization(state, current_patterns) do
    # System-wide pattern optimization
    optimization_potential = calculate_pattern_optimization_potential(state, current_patterns)
    waste_ratio = calculate_pure_waste_ratio(state, current_patterns)
    
    actions = []
    
    # Add actions based on patterns
    actions = if optimization_potential > 0.2 do
      [optimize_flow_patterns(current_patterns) | actions]
    else
      actions
    end
    
    actions = if waste_ratio > 0.1 do
      [reduce_flow_waste(state, current_patterns) | actions]
    else
      actions
    end
    
    %{
      type: :systemic_optimization,
      actions: actions,
      estimated_improvement: min(optimization_potential * 0.6, 0.4),
      pattern_based: true
    }
  end

  defp global_pattern_optimization(state) do
    %{
      type: :global_patterns,
      actions: [
        identify_underutilized_flows(state),
        consolidate_fragmented_flows(state),
        rebalance_flow_distribution(state)
      ],
      estimated_improvement: 0.15
    }
  end

  defp flow_pattern_optimization(state) do
    %{
      type: :flow_patterns,
      actions: [
        optimize_primary_flows(state),
        optimize_secondary_flows(state),
        optimize_auxiliary_flows(state)
      ],
      estimated_improvement: 0.10
    }
  end

  defp allocation_pattern_optimization(state) do
    %{
      type: :allocation_patterns,
      actions: [
        merge_similar_flow_allocations(state),
        redistribute_idle_flows(state)
      ],
      estimated_improvement: 0.08
    }
  end

  defp targeted_pattern_optimization(target, state) do
    %{
      type: :targeted_patterns,
      target: target,
      actions: [analyze_target_flow_usage(target, state)],
      estimated_improvement: 0.05
    }
  end

  # Helper functions for agnostic patterns

  defp calculate_utilization_percentage(usage, capacity) do
    if capacity > 0 do
      Float.round((usage / capacity) * 100, 1)
    else
      0.0
    end
  end

  defp calculate_overall_utilization(flow_patterns) do
    utilizations = [
      flow_patterns.flow_capacity.primary_utilization,
      flow_patterns.throughput.secondary_usage / max(flow_patterns.throughput.secondary_capacity, 1),
      flow_patterns.allocation.auxiliary_usage,
      flow_patterns.constraints.regulatory_usage / max(flow_patterns.constraints.regulatory_capacity, 1)
    ]
    
    Enum.sum(utilizations) / length(utilizations)
    |> Float.round(3)
  end

  defp calculate_total_allocated_flows(allocations) do
    # Sum all allocated flows
    allocations
    |> Map.values()
    |> Enum.reduce(0, fn allocation, acc ->
      flows = allocation[:flows] || allocation[:resources] || %{}
      total_flow = flows
      |> Map.values()
      |> Enum.sum()
      
      acc + total_flow
    end)
  end

  defp calculate_total_used_flows(flow_patterns) do
    # Sum all actually used flows
    flow_patterns.flow_capacity.primary_utilization +
    flow_patterns.throughput.secondary_usage +
    flow_patterns.allocation.auxiliary_usage +
    flow_patterns.constraints.regulatory_usage
  end

  defp calculate_time_span_hours(records) do
    if length(records) < 2 do
      1.0  # Default to 1 hour
    else
      first = List.last(records)
      last = List.first(records)
      
      if first[:timestamp] && last[:timestamp] do
        DateTime.diff(last.timestamp, first.timestamp, :second) / 3600
      else
        1.0
      end
    end
  end

  defp check_capacity_violations(flow_patterns, violations, state) do
    # Check for capacity constraint violations
    systemic_rules = state.systemic_rules
    
    violations = if flow_patterns.flow_capacity.primary_utilization > systemic_rules.max_primary_utilization do
      [%{
        type: :capacity_breach,
        flow: :primary,
        current: flow_patterns.flow_capacity.primary_utilization,
        limit: systemic_rules.max_primary_utilization,
        severity: :high
      } | violations]
    else
      violations
    end
    
    # Check secondary capacity
    secondary_util = flow_patterns.throughput.secondary_usage / max(flow_patterns.throughput.secondary_capacity, 1)
    violations = if secondary_util > systemic_rules.max_secondary_utilization do
      [%{
        type: :capacity_breach,
        flow: :secondary,
        current: secondary_util,
        limit: systemic_rules.max_secondary_utilization,
        severity: :medium
      } | violations]
    else
      violations
    end
    
    violations
  end

  defp check_rate_violations(flow_patterns, violations, state) do
    # Check for rate constraint violations
    if flow_patterns.throughput.throughput_rate > state.systemic_rules.max_throughput_rate do
      [%{
        type: :rate_breach,
        current_rate: flow_patterns.throughput.throughput_rate,
        limit: state.systemic_rules.max_throughput_rate,
        severity: :medium
      } | violations]
    else
      violations
    end
  end

  defp check_balance_violations(flow_patterns, violations, state) do
    # Check for balance constraint violations
    primary = flow_patterns.flow_capacity.primary_utilization
    secondary = flow_patterns.throughput.secondary_usage / max(flow_patterns.throughput.secondary_capacity, 1)
    
    imbalance = abs(primary - secondary)
    
    if imbalance > state.systemic_rules.max_flow_imbalance do
      [%{
        type: :balance_breach,
        imbalance_ratio: imbalance,
        limit: state.systemic_rules.max_flow_imbalance,
        severity: :low
      } | violations]
    else
      violations
    end
  end

  defp calculate_capacity_pressure(run_queue) do
    cond do
      run_queue > 100 -> :critical
      run_queue > 50 -> :high
      run_queue > 20 -> :moderate
      true -> :low
    end
  end

  defp calculate_flow_efficiency(utilization, run_queue) do
    base_efficiency = utilization
    queue_penalty = min(run_queue / 100, 0.5)
    
    max(0.0, base_efficiency - queue_penalty)
    |> Float.round(3)
  end

  defp estimate_secondary_capacity(io_bytes) do
    # Estimate secondary capacity based on IO patterns
    Float.round(io_bytes / 1_048_576 * 10, 2)  # Scale factor
  end

  defp calculate_message_throughput(processes) do
    # Calculate message throughput rate
    message_count = processes
    |> Enum.map(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len
        _ -> 0
      end
    end)
    |> Enum.sum()
    
    Float.round(message_count / max(length(processes), 1), 2)
  end

  defp calculate_flow_velocity(input, output, message_rate) do
    total_flow = (input + output) / 1_048_576 + message_rate
    Float.round(total_flow, 3)
  end

  defp count_active_processes(processes) do
    processes
    |> Enum.count(fn pid ->
      case Process.info(pid, :message_queue_len) do
        {:message_queue_len, len} -> len > 0
        _ -> false
      end
    end)
  end

  defp calculate_allocation_density(processes) do
    if Enum.empty?(processes) do
      0.0
    else
      active_count = count_active_processes(processes)
      Float.round(active_count / length(processes), 3)
    end
  end

  defp calculate_pattern_complexity(processes) do
    # Measure complexity based on process variety
    named_processes = processes
    |> Enum.map(fn pid ->
      case Process.info(pid, :registered_name) do
        {:registered_name, name} -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    
    if length(processes) > 0 do
      Float.round(length(named_processes) / length(processes), 3)
    else
      0.0
    end
  end

  defp calculate_constraint_density(ets_tables) do
    # Constraint density based on table distribution
    if Enum.empty?(ets_tables) do
      0.0
    else
      table_sizes = ets_tables
      |> Enum.map(fn table ->
        try do
          info = :ets.info(table)
          info[:size] || 0
        rescue
          _ -> 0
        end
      end)
      
      if Enum.sum(table_sizes) > 0 do
        avg_size = Enum.sum(table_sizes) / length(table_sizes)
        std_dev = calculate_standard_deviation(table_sizes, avg_size)
        Float.round(std_dev / avg_size, 3)
      else
        0.0
      end
    end
  end

  defp calculate_regulatory_pressure(memory) do
    ets_memory = memory[:ets] / 1_048_576  # MB
    
    cond do
      ets_memory > 500 -> :critical
      ets_memory > 200 -> :high
      ets_memory > 50 -> :moderate
      true -> :low
    end
  end

  defp extract_throughput_rates(flow_patterns) do
    %{
      primary_rate: flow_patterns.flow_capacity.primary_utilization,
      secondary_rate: flow_patterns.throughput.throughput_rate,
      auxiliary_rate: flow_patterns.allocation.auxiliary_usage,
      regulatory_rate: flow_patterns.constraints.regulatory_usage
    }
  end

  defp extract_capacity_ratios(flow_patterns) do
    %{
      primary_ratio: flow_patterns.flow_capacity.primary_utilization / 1.0,
      secondary_ratio: flow_patterns.throughput.secondary_usage / max(flow_patterns.throughput.secondary_capacity, 1),
      auxiliary_ratio: flow_patterns.allocation.auxiliary_usage,
      regulatory_ratio: flow_patterns.constraints.regulatory_usage / max(flow_patterns.constraints.regulatory_capacity, 1)
    }
  end

  defp calculate_flow_balance(flow_patterns) do
    ratios = extract_capacity_ratios(flow_patterns)
    ratio_values = Map.values(ratios)
    
    if Enum.empty?(ratio_values) do
      1.0
    else
      avg_ratio = Enum.sum(ratio_values) / length(ratio_values)
      deviations = Enum.map(ratio_values, fn r -> abs(r - avg_ratio) end)
      avg_deviation = Enum.sum(deviations) / length(deviations)
      
      # Balance is inverse of deviation
      Float.round(1.0 - min(avg_deviation, 1.0), 3)
    end
  end

  defp calculate_pattern_stability(pattern_history) do
    if length(pattern_history) < 5 do
      1.0  # Assume stable with insufficient data
    else
      recent_patterns = Enum.take(pattern_history, 10)
      
      # Calculate stability based on pattern variance
      primary_utils = Enum.map(recent_patterns, fn p -> p.flow_capacity.primary_utilization end)
      stability_score = 1.0 - calculate_coefficient_of_variation(primary_utils)
      
      Float.round(max(0.0, stability_score), 3)
    end
  end

  defp calculate_systemic_health(flow_patterns, state) do
    # Overall systemic health based on pure patterns
    health_factors = [
      calculate_flow_utilization(flow_patterns).overall,
      calculate_allocation_efficiency(state, flow_patterns),
      1.0 - calculate_pure_waste_ratio(state, flow_patterns),
      calculate_flow_balance(flow_patterns)
    ]
    
    Enum.sum(health_factors) / length(health_factors)
    |> Float.round(3)
  end

  # Utility functions

  defp calculate_standard_deviation(values, mean) do
    if Enum.empty?(values) do
      0.0
    else
      variance = values
      |> Enum.map(fn v -> (v - mean) * (v - mean) end)
      |> Enum.sum()
      |> Kernel./(length(values))
      
      :math.sqrt(variance)
    end
  end

  defp calculate_coefficient_of_variation(values) do
    if Enum.empty?(values) do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      if mean > 0 do
        std_dev = calculate_standard_deviation(values, mean)
        std_dev / mean
      else
        0.0
      end
    end
  end

  defp calculate_pattern_optimization_potential(state, flow_patterns) do
    efficiency = calculate_allocation_efficiency(state, flow_patterns)
    waste = calculate_pure_waste_ratio(state, flow_patterns)
    balance = calculate_flow_balance(flow_patterns)
    
    # Potential is inverse of efficiency and balance, plus waste
    potential = (1.0 - efficiency) + (1.0 - balance) + waste
    Float.round(min(potential / 3, 1.0), 3)
  end

  # Constraint violation functions

  defp classify_constraint_violation(constraint_issue) do
    case constraint_issue do
      %{type: type} when type in [:capacity, :throughput, :allocation] -> :capacity_breach
      %{rate: _} -> :rate_breach
      %{balance: _} -> :balance_breach
      %{limit: _} -> :limit_breach
      _ -> :unknown_violation
    end
  end

  defp record_constraint_violation(state, constraint_record) do
    # Add constraint violation to pattern metrics
    current_violations = state.pattern_metrics.constraint_violations
    new_violations = [constraint_record | current_violations] |> Enum.take(100)
    
    put_in(state, [:pattern_metrics, :constraint_violations], new_violations)
  end

  defp record_optimization_action(state, optimization_action) do
    # Add optimization action to pattern metrics
    current_actions = state.pattern_metrics.optimization_actions
    new_actions = [optimization_action | current_actions] |> Enum.take(100)
    
    put_in(state, [:pattern_metrics, :optimization_actions], new_actions)
  end

  # Renamed and agnostic versions of existing functions

  defp attempt_flow_allocation(flow_request, pools) do
    required = flow_request.flows || flow_request.resources || %{}
    
    if can_allocate_flows?(required, pools) do
      updated_pools = deduct_flows(pools, required)
      allocation_id = generate_allocation_id()
      {:ok, updated_pools, allocation_id}
    else
      {:error, :insufficient_flow_capacity}
    end
  end

  defp can_allocate_flows?(required, pools) do
    Enum.all?(required, fn {flow_type, amount} ->
      pool = Map.get(pools, flow_type, %{total_capacity: 0, allocated_capacity: 0})
      pool.total_capacity - pool.allocated_capacity >= amount
    end)
  end

  defp deduct_flows(pools, required) do
    Enum.reduce(required, pools, fn {flow_type, amount}, acc ->
      update_in(acc, [flow_type, :allocated_capacity], &(&1 + amount))
    end)
  end

  defp optimize_and_retry_flow(flow_request, state) do
    # Try to optimize flows before rejecting
    optimization = targeted_pattern_optimization(:allocation, state)
    
    if freed_flows_sufficient?(optimization, flow_request, state) do
      new_state = apply_pattern_optimization(optimization, state)
      attempt_flow_allocation(flow_request, new_state.flow_pools)
      |> case do
        {:ok, pools, id} -> 
          {:ok, %{new_state | flow_pools: pools}, id}
        error -> 
          error
      end
    else
      {:error, :cannot_optimize_flows_sufficiently}
    end
  end

  defp freed_flows_sufficient?(optimization, flow_request, state) do
    estimated_freed = optimization.estimated_improvement
    
    flow_request[:flows]
    |> Enum.all?(fn {flow_type, amount} ->
      pool = state.flow_pools[flow_type]
      if pool do
        available = pool.total_capacity - pool.allocated_capacity
        freed_amount = pool.allocated_capacity * estimated_freed
        (available + freed_amount) >= amount
      else
        false
      end
    end)
  end

  defp resolve_flow_constraint(unit1, unit2, constraint_issue, state) do
    priority1 = get_unit_priority(unit1)
    priority2 = get_unit_priority(unit2)
    
    resolution = cond do
      priority1 > priority2 ->
        %{primary_unit: unit1, action: :maintain_flow, compensation: :defer}
      priority2 > priority1 ->
        %{primary_unit: unit2, action: :transfer_flow, compensation: :immediate}
      true ->
        %{primary_unit: :shared, action: :split_flows, compensation: :none}
    end
    
    Map.put(resolution, :rationale, generate_constraint_rationale(constraint_issue, state))
  end

  defp apply_constraint_resolution(resolution, state) do
    case resolution.action do
      :maintain_flow -> state
      :transfer_flow -> transfer_flows(resolution, state)
      :split_flows -> split_flows(resolution, state)
    end
  end

  defp apply_pattern_optimization(optimization, state) do
    # Apply pattern optimization actions
    Enum.reduce(optimization.actions, state, fn action, acc ->
      apply_pattern_action(action, acc)
    end)
  end

  defp calculate_systemic_pattern_metrics(state, flow_patterns) do
    %{
      allocation_efficiency: calculate_allocation_efficiency(state, flow_patterns),
      flow_utilization: calculate_overall_utilization(flow_patterns),
      waste_ratio: calculate_pure_waste_ratio(state, flow_patterns),
      constraint_violations: identify_active_violations(flow_patterns, state),
      optimization_actions: state.pattern_metrics.optimization_actions,
      last_calculated: DateTime.utc_now()
    }
  end

  defp load_systemic_rules do
    %{
      max_primary_utilization: 0.9,
      max_secondary_utilization: 0.8,
      max_throughput_rate: 1000.0,
      max_flow_imbalance: 0.3,
      min_allocation_efficiency: 0.7,
      max_waste_ratio: 0.15
    }
  end

  defp calculate_available_flows(flow_pools) do
    Enum.map(flow_pools, fn {pool_name, pool} ->
      available = pool.total_capacity - pool.allocated_capacity
      {pool_name, %{available: available, percentage: available / pool.total_capacity * 100}}
    end)
    |> Enum.into(%{})
  end

  defp calculate_flow_pressure(state) do
    avg_utilization = state.flow_pools
    |> Map.values()
    |> Enum.map(fn pool -> pool.allocated_capacity / pool.total_capacity end)
    |> Enum.sum()
    |> Kernel./(map_size(state.flow_pools))
    
    cond do
      avg_utilization > 0.9 -> :critical
      avg_utilization > 0.7 -> :high
      avg_utilization > 0.5 -> :moderate
      true -> :low
    end
  end

  # Stub functions for agnostic pattern operations

  defp identify_rebalanceable_flows(allocations) do
    Enum.filter(allocations, fn {_id, allocation} ->
      allocation[:priority] != :critical
    end)
  end

  defp free_flows(rebalanceable, state) do
    {%{primary_flow: 0.2, secondary_flow: 0.15}, state.allocations}
  end

  defp merge_freed_flows(pools, freed) do
    Enum.reduce(freed, pools, fn {flow_type, amount}, acc ->
      update_in(acc, [flow_type, :allocated_capacity], &(&1 - amount))
    end)
  end

  defp notify_rebalance(rebalanceable) do
    Enum.each(rebalanceable, fn {_id, allocation} ->
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:control",
        {:flow_rebalance, allocation[:context] || allocation[:unit]}
      )
    end)
  end

  defp reserve_for_pattern_optimization(pools, flows_required) do
    Enum.reduce(flows_required, pools, fn {flow_type, amount}, acc ->
      update_in(acc, [flow_type, :reserved_capacity], &(&1 + amount))
    end)
  end

  defp get_unit_priority(_unit), do: :normal
  defp generate_constraint_rationale(_constraint_issue, _state), do: "Based on systemic priorities"
  defp transfer_flows(_resolution, state), do: state
  defp split_flows(_resolution, state), do: state
  defp apply_pattern_action(_action, state), do: state

  defp log_pattern(state, entry) do
    new_log = [entry | state.pattern_log] |> Enum.take(1000)
    %{state | pattern_log: new_log}
  end

  defp publish_flow_event(event, state) do
    if state[:amqp_channel] do
      payload = Jason.encode!(event)
      
      :ok = AMQP.Basic.publish(
        state.amqp_channel,
        "vsm.control",
        "",
        payload,
        content_type: "application/json"
      )
      
      Logger.debug("📊 Published flow event: #{event["type"]}")
    end
  end

  # Scheduling functions with agnostic names

  defp schedule_pattern_optimization do
    Process.send_after(self(), :optimization_cycle, 30_000)
  end

  defp schedule_flow_monitoring do
    Process.send_after(self(), :collect_patterns, 10_000)
  end

  defp schedule_pattern_audit do
    Process.send_after(self(), :pattern_audit, 60_000)
  end

  # Pattern optimization action functions

  defp optimize_flow_patterns(flow_patterns) do
    %{
      action: :optimize_flows,
      target: :primary_secondary_balance,
      details: flow_patterns,
      estimated_improvement: 0.1
    }
  end

  defp reduce_flow_waste(state, flow_patterns) do
    waste_analysis = analyze_flow_waste(state, flow_patterns)
    
    %{
      action: :reduce_waste,
      target: :deallocate_unused_flows,
      waste_analysis: waste_analysis,
      estimated_improvement: waste_analysis.potential_savings
    }
  end

  defp identify_underutilized_flows(_state), do: %{action: :identify_underutilized_flows}
  defp consolidate_fragmented_flows(_state), do: %{action: :consolidate_flows}
  defp rebalance_flow_distribution(_state), do: %{action: :rebalance_flows}
  defp optimize_primary_flows(_state), do: %{action: :optimize_primary}
  defp optimize_secondary_flows(_state), do: %{action: :optimize_secondary}
  defp optimize_auxiliary_flows(_state), do: %{action: :optimize_auxiliary}
  defp merge_similar_flow_allocations(_state), do: %{action: :merge_flow_allocations}
  defp redistribute_idle_flows(_state), do: %{action: :redistribute_flows}
  defp analyze_target_flow_usage(_target, _state), do: %{action: :analyze_target_flows}

  defp analyze_flow_waste(state, flow_patterns) do
    total_allocated = calculate_total_allocated_flows(state.allocations)
    total_used = calculate_total_used_flows(flow_patterns)
    
    waste = max(0, total_allocated - total_used)
    
    %{
      total_waste: if(total_allocated > 0, do: Float.round(waste / total_allocated, 3), else: 0.0),
      potential_savings: Float.round(waste * 0.7, 3)
    }
  end

  # Update existing function names to be agnostic

  defp calculate_detailed_flow_utilization(state) do
    %{
      by_flow: calculate_flow_pool_metrics(state.flow_pools),
      by_unit: %{},
      patterns: []
    }
  end

  defp identify_flow_waste(state) do
    %{
      flow_waste: calculate_pure_waste_ratio(state, state.flow_patterns || %{}),
      idle_allocations: [],
      overprovisioning: []
    }
  end

  defp generate_pattern_recommendations(state) do
    [
      "Consider consolidating underutilized flow allocations",
      "Implement time-based flow sharing for non-critical patterns",
      "Review and adjust flow limits based on actual usage patterns"
    ]
  end
  
  defp analyze_allocation_efficiency(state) do
    # Analyze allocation efficiency for systemic patterns
    current_patterns = collect_systemic_patterns()
    
    %{
      allocation_efficiency: calculate_allocation_efficiency(state, current_patterns),
      utilization_rate: calculate_flow_utilization(current_patterns),
      optimization_opportunities: identify_optimization_opportunities(state, current_patterns),
      efficiency_score: state.pattern_metrics.allocation_efficiency
    }
  end

  defp calculate_flow_pool_metrics(pools) do
    Enum.map(pools, fn {flow_type, pool} ->
      {flow_type, %{
        utilization: if(pool.total_capacity > 0, do: pool.allocated_capacity / pool.total_capacity, else: 0),
        available: pool.total_capacity - pool.allocated_capacity - pool.reserved_capacity,
        efficiency: if(pool.allocated_capacity > 0, do: pool.actual_usage / pool.allocated_capacity, else: 1.0)
      }}
    end)
    |> Map.new()
  end

  defp perform_pattern_audit(state) do
    current_patterns = state.flow_patterns || collect_systemic_patterns()
    
    # Analyze flow allocation effectiveness
    allocation_analysis = analyze_flow_allocation_effectiveness(state, current_patterns)
    
    # Calculate waste
    waste_analysis = analyze_flow_waste(state, current_patterns)
    
    # Identify optimization opportunities
    optimization_ops = identify_pattern_optimization_opportunities(state, current_patterns)
    
    %{
      timestamp: DateTime.utc_now(),
      allocation_effectiveness: allocation_analysis,
      waste_analysis: waste_analysis,
      waste_ratio: waste_analysis.total_waste,
      optimization_opportunities: optimization_ops,
      systemic_health: calculate_systemic_health(current_patterns, state),
      recommendations: generate_audit_recommendations(waste_analysis, optimization_ops)
    }
  end

  defp analyze_flow_allocation_effectiveness(state, flow_patterns) do
    allocations = state.allocations
    
    if map_size(allocations) == 0 do
      %{score: 1.0, details: "No allocations to analyze"}
    else
      effectiveness_by_allocation = allocations
      |> Enum.map(fn {id, allocation} ->
        flows = allocation[:flows] || allocation[:resources] || %{}
        
        effectiveness = calculate_single_flow_allocation_effectiveness(flows, flow_patterns)
        
        {id, %{
          unit: allocation[:unit] || allocation[:context],
          effectiveness: effectiveness,
          flows: flows,
          waste: calculate_single_allocation_waste(flows, flow_patterns)
        }}
      end)
      |> Map.new()
      
      overall_effectiveness = effectiveness_by_allocation
      |> Map.values()
      |> Enum.map(& &1.effectiveness)
      |> case do
        [] -> 1.0
        scores -> Enum.sum(scores) / length(scores)
      end
      
      %{
        score: Float.round(overall_effectiveness, 3),
        by_allocation: effectiveness_by_allocation,
        total_allocations: map_size(allocations)
      }
    end
  end

  defp calculate_single_flow_allocation_effectiveness(flows, flow_patterns) do
    if map_size(flows) == 0 do
      1.0
    else
      total_used = calculate_total_used_flows(flow_patterns)
      total_allocated = flows |> Map.values() |> Enum.sum()
      
      if total_allocated > 0 do
        min(total_used / total_allocated, 1.0)
      else
        1.0
      end
    end
  end

  defp calculate_single_allocation_waste(flows, flow_patterns) do
    total_allocated = flows |> Map.values() |> Enum.sum()
    total_used = calculate_total_used_flows(flow_patterns)
    
    max(0, total_allocated - total_used)
  end

  defp identify_pattern_optimization_opportunities(state, flow_patterns) do
    opportunities = []
    
    # Flow utilization opportunities
    overall_util = calculate_overall_utilization(flow_patterns)
    if overall_util < 0.5 do
      opportunities = [%{
        type: :flow_underutilization,
        priority: :medium,
        action: "Increase flow allocation or reduce capacity",
        potential_impact: (0.5 - overall_util) * 0.5
      } | opportunities]
    end
    
    # Waste reduction opportunities
    waste = calculate_pure_waste_ratio(state, flow_patterns)
    if waste > 0.1 do
      opportunities = [%{
        type: :flow_waste_reduction,
        priority: :high,
        action: "Deallocate unused flow capacity",
        potential_impact: waste * 0.8
      } | opportunities]
    end
    
    # Balance opportunities
    balance = calculate_flow_balance(flow_patterns)
    if balance < 0.7 do
      opportunities = [%{
        type: :flow_rebalancing,
        priority: :medium,
        action: "Rebalance flows across patterns",
        potential_impact: (0.7 - balance) * 0.3
      } | opportunities]
    end
    
    opportunities
    |> Enum.sort_by(& &1.potential_impact, :desc)
  end

  defp update_flow_tracker(tracker, flow_patterns) do
    current_time = System.monotonic_time(:millisecond)
    
    Map.merge(tracker, %{
      last_update: current_time,
      primary_flow_history: update_flow_history(tracker[:primary_flow_history], flow_patterns.flow_capacity.primary_utilization),
      secondary_flow_history: update_flow_history(tracker[:secondary_flow_history], flow_patterns.throughput.secondary_usage),
      efficiency_trend: calculate_flow_efficiency_trend(tracker)
    })
  end

  defp update_flow_history(history, current_value) do
    [{System.monotonic_time(:millisecond), current_value} | (history || [])]
    |> Enum.take(50)
  end

  defp calculate_flow_efficiency_trend(tracker) do
    if tracker[:efficiency_history] && length(tracker.efficiency_history) > 3 do
      recent = Enum.take(tracker.efficiency_history, 5)
      first_half = Enum.take(recent, 2) |> Enum.map(&elem(&1, 1))
      second_half = Enum.drop(recent, 3) |> Enum.map(&elem(&1, 1))
      
      if length(first_half) > 0 && length(second_half) > 0 do
        avg_first = Enum.sum(first_half) / length(first_half)
        avg_second = Enum.sum(second_half) / length(second_half)
        
        cond do
          avg_second > avg_first -> :improving
          avg_second < avg_first -> :degrading
          true -> :stable
        end
      else
        :unknown
      end
    else
      :unknown
    end
  end

  defp update_flow_baselines(baselines, history) do
    if length(history) > 20 do
      stable_patterns = history |> Enum.take(15) |> Enum.drop(5)
      
      %{
        primary_flow_baseline: calculate_baseline_value(stable_patterns, [:flow_capacity, :primary_utilization]),
        secondary_flow_baseline: calculate_baseline_value(stable_patterns, [:throughput, :secondary_usage]),
        auxiliary_flow_baseline: calculate_baseline_value(stable_patterns, [:allocation, :auxiliary_usage]),
        regulatory_flow_baseline: calculate_baseline_value(stable_patterns, [:constraints, :regulatory_usage])
      }
    else
      baselines
    end
  end

  defp update_pools_with_flow_data(pools, flow_patterns) do
    pools
    |> Map.update(:primary_flow, %{}, fn pool ->
      Map.put(pool, :actual_usage, flow_patterns.flow_capacity.primary_utilization)
    end)
    |> Map.update(:secondary_flow, %{}, fn pool ->
      Map.put(pool, :actual_usage, flow_patterns.throughput.secondary_usage)
    end)
    |> Map.update(:auxiliary_flow, %{}, fn pool ->
      Map.put(pool, :actual_usage, flow_patterns.allocation.auxiliary_usage)
    end)
    |> Map.update(:regulatory_flow, %{}, fn pool ->
      Map.put(pool, :actual_usage, flow_patterns.constraints.regulatory_usage)
    end)
  end

  defp generate_allocation_id, do: Ecto.UUID.generate()

  defp calculate_total_allocated(state) do
    state.allocations
    |> Map.values()
    |> Enum.reduce(0, fn allocation, acc ->
      case allocation do
        %{flows: flows} when is_map(flows) ->
          total = flows |> Map.values() |> Enum.sum()
          acc + total
        %{resources: resources} when is_map(resources) ->
          total = resources |> Map.values() |> Enum.sum()
          acc + total
        %AMQP.Channel{} ->
          Logger.warning("Control: AMQP.Channel found in allocations - this is a bug!")
          acc
        other ->
          Logger.warning("Control: Unexpected allocation type: #{inspect(other)}")
          acc
      end
    end)
  end

  defp calculate_total_available(state) do
    state.flow_pools
    |> Map.values()
    |> Enum.reduce(0, fn pool, acc ->
      if is_map(pool) and Map.has_key?(pool, :total_capacity) do
        total = Map.get(pool, :total_capacity, 0)
        allocated = Map.get(pool, :allocated_capacity, 0)
        reserved = Map.get(pool, :reserved_capacity, 0)
        available = total - allocated - reserved
        acc + available
      else
        acc
      end
    end)
  end

  defp analyze_flow_patterns(state) do
    current_patterns = state.flow_patterns || collect_systemic_patterns()
    
    %{
      utilization: calculate_flow_utilization(current_patterns),
      balance: calculate_flow_balance(current_patterns),
      efficiency: calculate_allocation_efficiency(state, current_patterns),
      health: calculate_systemic_health(current_patterns, state)
    }
  end

  defp calculate_baseline_value(patterns, path) do
    values = patterns
    |> Enum.map(fn pattern ->
      get_in(pattern, path) || 0
    end)
    
    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end

end