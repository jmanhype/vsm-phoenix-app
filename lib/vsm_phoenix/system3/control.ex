defmodule VsmPhoenix.System3.Control do
  @moduledoc """
  System 3 - Control: Resource Management and Optimization
  
  Manages internal stability through:
  - Resource allocation and optimization
  - Performance monitoring and control
  - Conflict resolution between System 1 units
  - Efficiency optimization
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System2.Coordinator
  alias VsmPhoenix.System1.{Context, Operations}
  alias AMQP
  
  @name __MODULE__
  @sporadic_audit_interval 60_000  # 1 minute
  @compliance_threshold 0.85
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def allocate_resources(request) do
    GenServer.call(@name, {:allocate_resources, request})
  end
  
  def optimize_performance(target_area) do
    GenServer.call(@name, {:optimize_performance, target_area})
  end
  
  def resolve_conflict(context1, context2, issue) do
    GenServer.call(@name, {:resolve_conflict, context1, context2, issue})
  end
  
  def get_resource_metrics do
    GenServer.call(@name, :get_resource_metrics)
  end
  
  def emergency_reallocation(viability_metrics) do
    GenServer.cast(@name, {:emergency_reallocation, viability_metrics})
  end
  
  def allocate_for_adaptation(proposal) do
    GenServer.cast(@name, {:allocate_for_adaptation, proposal})
  end
  
  def get_resource_state do
    GenServer.call(@name, :get_resource_state)
  end
  
  def audit_resource_usage do
    GenServer.call(@name, :audit_resource_usage)
  end
  
  @doc """
  Direct audit bypass - inspect any S1 agent without S2 coordination
  WARNING: This bypasses normal coordination - use with caution!
  """
  def audit(target_s1, options \\ []) do
    GenServer.call(@name, {:audit_s1_direct, target_s1, options})
  end
  
  @doc """
  Trigger a sporadic audit - randomly selects S1 agents to audit
  """
  def trigger_sporadic_audit do
    GenServer.cast(@name, :sporadic_audit)
  end
  
  @doc """
  Check compliance of a specific S1 agent against policies
  """
  def check_compliance(target_s1) do
    GenServer.call(@name, {:check_compliance, target_s1})
  end
  
  @doc """
  Get comprehensive audit report for System 5
  """
  def get_audit_report(options \\ []) do
    GenServer.call(@name, {:get_audit_report, options})
  end
  
  @doc """
  Configure audit policies and thresholds
  """
  def configure_audit_policy(policy) do
    GenServer.cast(@name, {:configure_audit_policy, policy})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("System 3 Control initializing...")
    
    state = %{
      resource_pools: %{
        compute: %{total: 1.0, allocated: 0.0, reserved: 0.0},
        memory: %{total: 1.0, allocated: 0.0, reserved: 0.0},
        network: %{total: 1.0, allocated: 0.0, reserved: 0.0},
        storage: %{total: 1.0, allocated: 0.0, reserved: 0.0}
      },
      allocations: %{},
      performance_metrics: %{
        efficiency: 0.85,
        utilization: 0.70,
        waste: 0.05,
        bottlenecks: []
      },
      optimization_rules: load_optimization_rules(),
      conflict_history: [],
      audit_log: [],
      audit_policies: load_default_audit_policies(),
      compliance_history: %{},
      audit_statistics: %{
        total_audits: 0,
        sporadic_audits: 0,
        compliance_failures: 0,
        last_sporadic_audit: nil
      },
      amqp_channel: nil
    }
    
    # Set up AMQP for resource control
    state = setup_amqp_control(state)
    
    # Schedule periodic optimization
    schedule_optimization_cycle()
    
    # Schedule sporadic audits
    schedule_sporadic_audit()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:allocate_resources, request}, _from, state) do
    Logger.info("Control: Processing resource allocation request")
    
    case attempt_allocation(request, state.resource_pools) do
      {:ok, updated_pools, allocation_id} ->
        new_allocations = Map.put(state.allocations, allocation_id, request)
        new_state = %{state | 
          resource_pools: updated_pools,
          allocations: new_allocations
        }
        
        # Log the allocation
        audit_entry = %{
          timestamp: DateTime.utc_now(),
          action: :allocate,
          request: request,
          result: :success,
          allocation_id: allocation_id
        }
        
        # Publish allocation event to AMQP
        allocation_event = %{
          type: "resource_allocated",
          allocation_id: allocation_id,
          request: request,
          pools: updated_pools,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
        
        final_state = log_audit(new_state, audit_entry)
        publish_resource_event(allocation_event, final_state)
        
        {:reply, {:ok, allocation_id}, final_state}
        
      {:error, reason} ->
        # Try optimization before rejecting
        case optimize_and_retry(request, state) do
          {:ok, updated_state, allocation_id} ->
            {:reply, {:ok, allocation_id}, updated_state}
          {:error, _} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:optimize_performance, target_area}, _from, state) do
    Logger.info("Control: Optimizing performance for #{target_area}")
    
    optimization_result = case target_area do
      :global -> global_optimization(state)
      :resource -> resource_optimization(state)
      :allocation -> allocation_optimization(state)
      specific -> targeted_optimization(specific, state)
    end
    
    new_state = apply_optimization(optimization_result, state)
    
    {:reply, optimization_result, new_state}
  end
  
  @impl true
  def handle_call({:resolve_conflict, context1, context2, issue}, _from, state) do
    Logger.info("Control: Resolving conflict between #{context1} and #{context2}")
    
    resolution = resolve_resource_conflict(context1, context2, issue, state)
    
    # Record conflict and resolution
    conflict_record = %{
      timestamp: DateTime.utc_now(),
      contexts: [context1, context2],
      issue: issue,
      resolution: resolution
    }
    
    new_history = [conflict_record | state.conflict_history] |> Enum.take(100)
    new_state = %{state | conflict_history: new_history}
    
    # Apply resolution
    updated_state = apply_resolution(resolution, new_state)
    
    {:reply, resolution, updated_state}
  end
  
  @impl true
  def handle_call(:get_resource_metrics, _from, state) do
    metrics = %{
      pools: calculate_pool_metrics(state.resource_pools),
      efficiency: state.performance_metrics.efficiency,
      utilization: calculate_utilization(state.resource_pools),
      resource_utilization: state.performance_metrics.utilization,
      active_allocations: map_size(state.allocations),
      optimization_potential: calculate_optimization_potential(state)
    }
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call(:get_resource_state, _from, state) do
    # Return comprehensive resource state
    resource_state = %{
      resource_pools: state.resource_pools,
      allocations: state.allocations,
      performance_metrics: state.performance_metrics,
      optimization_rules: Map.keys(state.optimization_rules),
      conflict_history_count: length(state.conflict_history),
      current_efficiency: state.performance_metrics.efficiency,
      available_resources: calculate_available_resources(state.resource_pools),
      resource_pressure: calculate_resource_pressure(state)
    }
    
    {:reply, {:ok, resource_state}, state}
  end
  
  @impl true
  def handle_call(:audit_resource_usage, _from, state) do
    audit_report = %{
      current_allocations: state.allocations,
      resource_utilization: calculate_detailed_utilization(state),
      efficiency_analysis: analyze_efficiency(state),
      waste_analysis: identify_waste(state),
      recommendations: generate_recommendations(state)
    }
    
    {:reply, audit_report, state}
  end
  
  @impl true
  def handle_call({:check_compliance, target_s1}, _from, state) do
    Logger.info("🔍 Control: Checking compliance for #{target_s1}")
    
    # Perform direct audit
    audit_result = VsmPhoenix.System3.AuditChannel.send_audit_command(
      target_s1,
      %{operation: :compliance_check}
    )
    
    compliance_result = case audit_result do
      {:ok, data} ->
        compliance_score = calculate_compliance_score(data, state.audit_policies)
        compliant = compliance_score >= @compliance_threshold
        
        result = %{
          target: target_s1,
          score: compliance_score,
          compliant: compliant,
          violations: if(compliant, do: [], else: find_violations(data, state.audit_policies)),
          timestamp: DateTime.utc_now()
        }
        
        # Update compliance history
        new_history = Map.update(
          state.compliance_history,
          target_s1,
          [result],
          &([result | &1] |> Enum.take(100))
        )
        
        {:ok, result, %{state | compliance_history: new_history}}
        
      {:error, reason} ->
        {:error, reason, state}
    end
    
    case compliance_result do
      {:ok, result, new_state} -> {:reply, {:ok, result}, new_state}
      {:error, reason, new_state} -> {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call({:get_audit_report, options}, _from, state) do
    time_range = Keyword.get(options, :time_range, :last_24h)
    include_compliance = Keyword.get(options, :include_compliance, true)
    include_resources = Keyword.get(options, :include_resources, true)
    
    report = %{
      generated_at: DateTime.utc_now(),
      period: time_range,
      audit_statistics: state.audit_statistics,
      recent_audits: get_recent_audits(state.audit_log, time_range),
      compliance_summary: if include_compliance do
        generate_compliance_summary(state.compliance_history)
      else
        nil
      end,
      resource_analysis: if include_resources do
        %{
          current_utilization: calculate_utilization(state.resource_pools),
          efficiency: state.performance_metrics.efficiency,
          bottlenecks: state.performance_metrics.bottlenecks,
          optimization_potential: calculate_optimization_potential(state)
        }
      else
        nil
      end,
      recommendations: generate_audit_recommendations(state),
      risk_assessment: assess_system_risks(state)
    }
    
    # Send report to System 5
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:governance",
      {:audit_report, report}
    )
    
    {:reply, {:ok, report}, state}
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
    
    # Update audit statistics
    new_stats = Map.update!(state.audit_statistics, :total_audits, &(&1 + 1))
    
    final_state = state
      |> log_audit(audit_entry)
      |> Map.put(:audit_statistics, new_stats)
    
    # Check if audit revealed compliance issues
    if elem(result, 0) == :ok do
      check_audit_compliance(elem(result, 1), target_s1, final_state)
    end
    
    {:reply, result, final_state}
  end
  
  @impl true
  def handle_cast(:sporadic_audit, state) do
    Logger.info("🎲 Control: Initiating sporadic audit")
    
    # Get list of active S1 agents
    active_agents = get_active_s1_agents()
    
    if length(active_agents) > 0 do
      # Randomly select an agent to audit
      target = Enum.random(active_agents)
      
      Logger.info("🎲 Sporadic audit target: #{target}")
      
      # Perform audit asynchronously
      Task.start(fn ->
        audit_result = VsmPhoenix.System3.AuditChannel.send_audit_command(
          target,
          %{
            operation: :sporadic_inspection,
            type: "sporadic",
            initiated_by: "system3_control"
          }
        )
        
        # Process result
        GenServer.cast(@name, {:sporadic_audit_complete, target, audit_result})
      end)
      
      # Update statistics
      new_stats = state.audit_statistics
        |> Map.update!(:sporadic_audits, &(&1 + 1))
        |> Map.put(:last_sporadic_audit, DateTime.utc_now())
      
      {:noreply, %{state | audit_statistics: new_stats}}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:sporadic_audit_complete, target, result}, state) do
    Logger.info("🎲 Sporadic audit complete for #{target}")
    
    # Log the sporadic audit
    audit_entry = %{
      timestamp: DateTime.utc_now(),
      action: :sporadic_audit,
      target: target,
      result: elem(result, 0),
      sporadic: true
    }
    
    new_state = log_audit(state, audit_entry)
    
    # Check for anomalies
    if elem(result, 0) == :ok do
      check_for_anomalies(elem(result, 1), target, new_state)
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:configure_audit_policy, policy}, state) do
    Logger.info("🔧 Control: Updating audit policy")
    
    new_policies = Map.merge(state.audit_policies, policy)
    
    {:noreply, %{state | audit_policies: new_policies}}
  end
  
  @impl true
  def handle_cast({:emergency_reallocation, viability_metrics}, state) do
    Logger.warning("Control: Emergency reallocation triggered")
    
    # Identify non-critical allocations
    reallocatable = identify_reallocatable_resources(state.allocations)
    
    # Free up resources
    {freed_resources, remaining_allocations} = free_resources(reallocatable, state)
    
    # Reallocate to critical areas
    new_pools = merge_freed_resources(state.resource_pools, freed_resources)
    
    new_state = %{state |
      resource_pools: new_pools,
      allocations: remaining_allocations
    }
    
    # Notify affected contexts
    notify_reallocation(reallocatable)
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:allocate_for_adaptation, proposal}, state) do
    Logger.info("Control: Allocating resources for adaptation #{proposal.id}")
    
    # Reserve resources for adaptation
    reserved_pools = reserve_for_adaptation(state.resource_pools, proposal.resources_required)
    
    new_state = %{state | resource_pools: reserved_pools}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:sporadic_audit_trigger, state) do
    # Trigger sporadic audit
    GenServer.cast(self(), :sporadic_audit)
    
    # Schedule next sporadic audit with some randomness
    schedule_sporadic_audit()
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:optimization_cycle, state) do
    # Run periodic optimization
    optimization_result = global_optimization(state)
    new_state = apply_optimization(optimization_result, state)
    
    # Update metrics
    updated_metrics = update_performance_metrics(new_state)
    final_state = %{new_state | performance_metrics: updated_metrics}
    
    schedule_optimization_cycle()
    {:noreply, final_state}
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
  
  defp schedule_sporadic_audit do
    # Add some randomness to avoid predictable patterns
    interval = @sporadic_audit_interval + :rand.uniform(30_000) - 15_000
    Process.send_after(self(), :sporadic_audit_trigger, interval)
  end
  
  defp load_default_audit_policies do
    %{
      resource_limits: %{
        max_cpu: 0.8,
        max_memory: 0.9,
        max_network: 0.7
      },
      performance_thresholds: %{
        min_efficiency: 0.7,
        max_response_time: 5000,
        max_error_rate: 0.05
      },
      compliance_rules: %{
        require_authentication: true,
        require_encryption: true,
        require_audit_trail: true
      },
      operational_constraints: %{
        max_idle_time: 300_000,  # 5 minutes
        min_activity_level: 0.1,
        max_resource_hoarding: 0.3
      }
    }
  end
  
  defp calculate_compliance_score(audit_data, policies) do
    scores = []
    
    # Check resource compliance
    if audit_data["resources"] do
      resource_score = check_resource_compliance(audit_data["resources"], policies.resource_limits)
      scores = [resource_score | scores]
    end
    
    # Check performance compliance
    if audit_data["metrics"] do
      perf_score = check_performance_compliance(audit_data["metrics"], policies.performance_thresholds)
      scores = [perf_score | scores]
    end
    
    # Check operational compliance
    if audit_data["operations"] do
      ops_score = check_operational_compliance(audit_data["operations"], policies.operational_constraints)
      scores = [ops_score | scores]
    end
    
    # Calculate average score
    if length(scores) > 0 do
      Enum.sum(scores) / length(scores)
    else
      1.0  # Default to compliant if no data
    end
  end
  
  defp find_violations(audit_data, policies) do
    violations = []
    
    # Check for resource violations
    if audit_data["resources"] do
      resource_violations = find_resource_violations(audit_data["resources"], policies.resource_limits)
      violations = violations ++ resource_violations
    end
    
    # Check for performance violations
    if audit_data["metrics"] do
      perf_violations = find_performance_violations(audit_data["metrics"], policies.performance_thresholds)
      violations = violations ++ perf_violations
    end
    
    violations
  end
  
  defp check_resource_compliance(resources, limits) do
    violations = 0
    checks = 0
    
    if resources["cpu_usage"] do
      checks = checks + 1
      if resources["cpu_usage"] > limits.max_cpu, do: violations = violations + 1
    end
    
    if resources["memory_usage"] do
      checks = checks + 1
      if resources["memory_usage"] > limits.max_memory, do: violations = violations + 1
    end
    
    if checks > 0 do
      1.0 - (violations / checks)
    else
      1.0
    end
  end
  
  defp check_performance_compliance(metrics, thresholds) do
    violations = 0
    checks = 0
    
    if metrics["efficiency"] do
      checks = checks + 1
      if metrics["efficiency"] < thresholds.min_efficiency, do: violations = violations + 1
    end
    
    if metrics["response_time"] do
      checks = checks + 1
      if metrics["response_time"] > thresholds.max_response_time, do: violations = violations + 1
    end
    
    if metrics["error_rate"] do
      checks = checks + 1
      if metrics["error_rate"] > thresholds.max_error_rate, do: violations = violations + 1
    end
    
    if checks > 0 do
      1.0 - (violations / checks)
    else
      1.0
    end
  end
  
  defp check_operational_compliance(operations, constraints) do
    violations = 0
    checks = 0
    
    if operations["idle_time"] do
      checks = checks + 1
      if operations["idle_time"] > constraints.max_idle_time, do: violations = violations + 1
    end
    
    if operations["activity_level"] do
      checks = checks + 1
      if operations["activity_level"] < constraints.min_activity_level, do: violations = violations + 1
    end
    
    if checks > 0 do
      1.0 - (violations / checks)
    else
      1.0
    end
  end
  
  defp find_resource_violations(resources, limits) do
    violations = []
    
    if resources["cpu_usage"] && resources["cpu_usage"] > limits.max_cpu do
      violations = [%{type: :resource, violation: :cpu_exceeded, value: resources["cpu_usage"]} | violations]
    end
    
    if resources["memory_usage"] && resources["memory_usage"] > limits.max_memory do
      violations = [%{type: :resource, violation: :memory_exceeded, value: resources["memory_usage"]} | violations]
    end
    
    violations
  end
  
  defp find_performance_violations(metrics, thresholds) do
    violations = []
    
    if metrics["efficiency"] && metrics["efficiency"] < thresholds.min_efficiency do
      violations = [%{type: :performance, violation: :low_efficiency, value: metrics["efficiency"]} | violations]
    end
    
    if metrics["error_rate"] && metrics["error_rate"] > thresholds.max_error_rate do
      violations = [%{type: :performance, violation: :high_error_rate, value: metrics["error_rate"]} | violations]
    end
    
    violations
  end
  
  defp get_active_s1_agents do
    # Get list of registered S1 agents
    # In practice, this would query the registry or supervisor
    [:operations_context, :agent_1, :agent_2]
  end
  
  defp check_audit_compliance(audit_data, target, state) do
    if audit_data["compliance_issues"] && length(audit_data["compliance_issues"]) > 0 do
      # Report to System 5
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:governance",
        {:compliance_violation, target, audit_data["compliance_issues"]}
      )
      
      # Update compliance failure counter
      new_stats = Map.update!(state.audit_statistics, :compliance_failures, &(&1 + 1))
      %{state | audit_statistics: new_stats}
    else
      state
    end
  end
  
  defp check_for_anomalies(audit_data, target, state) do
    anomalies = detect_anomalies(audit_data)
    
    if length(anomalies) > 0 do
      Logger.warning("🚨 Anomalies detected in #{target}: #{inspect(anomalies)}")
      
      # Report to System 4 for intelligence processing
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:intelligence",
        {:anomaly_detected, target, anomalies}
      )
      
      # Report critical anomalies to System 5
      critical = Enum.filter(anomalies, &(&1.severity == :critical))
      if length(critical) > 0 do
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "vsm:governance",
          {:critical_anomaly, target, critical}
        )
      end
    end
    
    state
  end
  
  defp detect_anomalies(audit_data) do
    anomalies = []
    
    # Check for resource anomalies
    if audit_data["resources"] do
      if audit_data["resources"]["cpu_usage"] > 0.95 do
        anomalies = [%{type: :resource, severity: :critical, description: "CPU near capacity"} | anomalies]
      end
      
      if audit_data["resources"]["memory_usage"] > 0.95 do
        anomalies = [%{type: :resource, severity: :critical, description: "Memory near capacity"} | anomalies]
      end
    end
    
    # Check for behavioral anomalies
    if audit_data["behavior"] do
      if audit_data["behavior"]["unexpected_patterns"] do
        anomalies = [%{type: :behavioral, severity: :warning, description: "Unexpected behavior patterns"} | anomalies]
      end
    end
    
    anomalies
  end
  
  defp get_recent_audits(audit_log, :last_24h) do
    cutoff = DateTime.add(DateTime.utc_now(), -86400, :second)
    
    Enum.filter(audit_log, fn entry ->
      DateTime.compare(entry.timestamp, cutoff) == :gt
    end)
    |> Enum.take(100)
  end
  
  defp get_recent_audits(audit_log, :last_week) do
    cutoff = DateTime.add(DateTime.utc_now(), -604800, :second)
    
    Enum.filter(audit_log, fn entry ->
      DateTime.compare(entry.timestamp, cutoff) == :gt
    end)
    |> Enum.take(500)
  end
  
  defp get_recent_audits(audit_log, _), do: Enum.take(audit_log, 50)
  
  defp generate_compliance_summary(compliance_history) do
    total_checks = compliance_history
      |> Map.values()
      |> List.flatten()
      |> length()
    
    compliant_checks = compliance_history
      |> Map.values()
      |> List.flatten()
      |> Enum.filter(&(&1.compliant))
      |> length()
    
    %{
      total_compliance_checks: total_checks,
      compliant: compliant_checks,
      non_compliant: total_checks - compliant_checks,
      compliance_rate: if(total_checks > 0, do: compliant_checks / total_checks, else: 1.0),
      by_agent: Map.new(compliance_history, fn {agent, history} ->
        recent = Enum.take(history, 10)
        compliant = Enum.count(recent, &(&1.compliant))
        {agent, %{
          total: length(recent),
          compliant: compliant,
          rate: if(length(recent) > 0, do: compliant / length(recent), else: 1.0)
        }}
      end)
    }
  end
  
  defp generate_audit_recommendations(state) do
    recommendations = []
    
    # Check compliance history
    if map_size(state.compliance_history) > 0 do
      low_compliance = Enum.filter(state.compliance_history, fn {_agent, history} ->
        recent = Enum.take(history, 5)
        if length(recent) > 0 do
          compliance_rate = Enum.count(recent, &(&1.compliant)) / length(recent)
          compliance_rate < 0.8
        else
          false
        end
      end)
      
      if length(low_compliance) > 0 do
        recommendations = [
          "Review and address compliance issues in agents: #{inspect(Keyword.keys(low_compliance))}"
          | recommendations
        ]
      end
    end
    
    # Check resource efficiency
    if state.performance_metrics.efficiency < 0.8 do
      recommendations = [
        "Consider resource optimization - current efficiency is #{state.performance_metrics.efficiency}"
        | recommendations
      ]
    end
    
    # Check audit frequency
    if state.audit_statistics.sporadic_audits < 10 do
      recommendations = [
        "Increase sporadic audit frequency for better compliance monitoring"
        | recommendations
      ]
    end
    
    recommendations
  end
  
  defp assess_system_risks(state) do
    risks = []
    
    # Assess resource risks
    utilization = calculate_utilization(state.resource_pools)
    if utilization > 0.85 do
      risks = [%{category: :resource, level: :high, description: "High resource utilization (#{Float.round(utilization * 100, 1)}%)"} | risks]
    end
    
    # Assess compliance risks
    if state.audit_statistics.compliance_failures > 5 do
      risks = [%{category: :compliance, level: :medium, description: "Multiple compliance failures detected"} | risks]
    end
    
    # Assess operational risks
    if length(state.performance_metrics.bottlenecks) > 0 do
      risks = [%{category: :operational, level: :medium, description: "Performance bottlenecks identified"} | risks]
    end
    
    %{
      risk_count: length(risks),
      risk_levels: %{
        high: Enum.count(risks, &(&1.level == :high)),
        medium: Enum.count(risks, &(&1.level == :medium)),
        low: Enum.count(risks, &(&1.level == :low))
      },
      risks: risks
    }
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
end