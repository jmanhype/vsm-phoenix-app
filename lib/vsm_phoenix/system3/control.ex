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
  
  @name __MODULE__
  
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
      audit_log: []
    }
    
    # Schedule periodic optimization
    schedule_optimization_cycle()
    
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
        
        {:reply, {:ok, allocation_id}, log_audit(new_state, audit_entry)}
        
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
    
    if optimization.freed_resources_sufficient?(request) do
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
end