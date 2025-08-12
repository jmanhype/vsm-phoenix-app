defmodule VsmPhoenix.System5.Policy.PolicyManager do
  @moduledoc """
  Policy Manager - Handles all policy operations for System 5.
  
  Extracted from Queen god object to follow Single Responsibility Principle.
  Responsible ONLY for:
  - Policy CRUD operations
  - Policy validation and coherence
  - Policy constraint application
  - Policy violation detection
  """
  
  use GenServer
  require Logger
  
  @behaviour VsmPhoenix.System5.Behaviors.PolicyManager
  
  alias Phoenix.PubSub
  alias VsmPhoenix.System5.PolicySynthesizer
  
  @name __MODULE__
  @policy_storage_key "system5_policies"
  
  # Default policies
  @default_policies %{
    viability_threshold: %{
      minimum_viability: 0.3,
      intervention_threshold: 0.5,
      target_viability: 0.8,
      evaluation_interval: 30_000
    },
    resource_allocation: %{
      max_system_load: 0.85,
      emergency_reserve: 0.15,
      rebalancing_threshold: 0.7
    },
    adaptation_governance: %{
      max_simultaneous_adaptations: 3,
      adaptation_confidence_threshold: 0.6,
      rollback_threshold: 0.4
    },
    algedonic_sensitivity: %{
      pain_escalation_threshold: 0.7,
      pleasure_saturation_point: 0.9,
      intervention_cooldown: 60_000
    }
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def set_policy(policy_type, policy_data) do
    GenServer.call(@name, {:set_policy, policy_type, policy_data})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def get_policy(policy_type) do
    GenServer.call(@name, {:get_policy, policy_type})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def get_all_policies do
    GenServer.call(@name, :get_all_policies)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def synthesize_adaptive_policy(anomaly_data, constraints \\ %{}) do
    GenServer.call(@name, {:synthesize_adaptive_policy, anomaly_data, constraints})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def validate_policy(policy_type, policy_data) do
    GenServer.call(@name, {:validate_policy, policy_type, policy_data})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def calculate_policy_coherence do
    GenServer.call(@name, :calculate_policy_coherence)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def check_policy_violations(current_state, context \\ %{}) do
    GenServer.call(@name, {:check_policy_violations, current_state, context})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def get_policy_metrics do
    GenServer.call(@name, :get_policy_metrics)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def apply_policy_constraints(policy_data, constraints) do
    GenServer.call(@name, {:apply_policy_constraints, policy_data, constraints})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.PolicyManager
  def propagate_policy_change(policy_type, policy_data) do
    GenServer.cast(@name, {:propagate_policy_change, policy_type, policy_data})
    :ok
  rescue
    e -> {:error, e}
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      policies: @default_policies,
      policy_history: [],
      coherence_cache: nil,
      last_coherence_check: nil,
      violation_history: [],
      metrics: initialize_policy_metrics()
    }
    
    Logger.info("📋 Policy Manager initialized with #{map_size(@default_policies)} default policies")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:set_policy, policy_type, policy_data}, _from, state) do
    case validate_policy_internal(policy_type, policy_data, state) do
      :ok ->
        # Update policy
        new_policies = Map.put(state.policies, policy_type, policy_data)
        
        # Record policy change
        policy_change = %{
          type: policy_type,
          old_data: Map.get(state.policies, policy_type),
          new_data: policy_data,
          timestamp: System.system_time(:millisecond),
          change_id: generate_change_id()
        }
        
        new_history = [policy_change | state.policy_history] |> Enum.take(100)
        
        # Invalidate coherence cache
        new_state = %{state |
          policies: new_policies,
          policy_history: new_history,
          coherence_cache: nil,
          metrics: update_policy_metrics(state.metrics, :policy_set)
        }
        
        # Propagate change asynchronously
        Task.start(fn -> 
          propagate_policy_change_internal(policy_type, policy_data)
        end)
        
        Logger.info("📋 Policy updated: #{policy_type}")
        {:reply, :ok, new_state}
        
      {:error, violations} ->
        Logger.warn("📋 Policy validation failed for #{policy_type}: #{inspect(violations)}")
        {:reply, {:error, {:validation_failed, violations}}, state}
    end
  end
  
  @impl true
  def handle_call({:get_policy, policy_type}, _from, state) do
    case Map.get(state.policies, policy_type) do
      nil -> {:reply, {:error, :not_found}, state}
      policy_data -> {:reply, {:ok, policy_data}, state}
    end
  end
  
  @impl true
  def handle_call(:get_all_policies, _from, state) do
    {:reply, {:ok, state.policies}, state}
  end
  
  @impl true
  def handle_call({:synthesize_adaptive_policy, anomaly_data, constraints}, _from, state) do
    try do
      synthesized_policy = PolicySynthesizer.synthesize_policy(anomaly_data, constraints)
      
      # Apply current system constraints
      final_policy = apply_constraints_internal(synthesized_policy, constraints, state)
      
      new_metrics = update_policy_metrics(state.metrics, :policy_synthesized)
      new_state = %{state | metrics: new_metrics}
      
      Logger.debug("📋 Synthesized adaptive policy")
      {:reply, {:ok, final_policy}, new_state}
      
    rescue
      e -> 
        Logger.error("📋 Policy synthesis failed: #{inspect(e)}")
        {:reply, {:error, {:synthesis_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:validate_policy, policy_type, policy_data}, _from, state) do
    result = validate_policy_internal(policy_type, policy_data, state)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:calculate_policy_coherence, _from, state) do
    # Use cached coherence if recent
    now = System.system_time(:millisecond)
    cache_age = if state.last_coherence_check, do: now - state.last_coherence_check, else: :infinity
    
    if cache_age < 30_000 and state.coherence_cache do
      {:reply, {:ok, state.coherence_cache}, state}
    else
      coherence_score = calculate_coherence_internal(state.policies)
      new_state = %{state | 
        coherence_cache: coherence_score,
        last_coherence_check: now
      }
      {:reply, {:ok, coherence_score}, new_state}
    end
  end
  
  @impl true
  def handle_call({:check_policy_violations, current_state, context}, _from, state) do
    violations = check_violations_internal(state.policies, current_state, context)
    
    # Record violations
    if length(violations) > 0 do
      violation_entry = %{
        violations: violations,
        state: current_state,
        context: context,
        timestamp: System.system_time(:millisecond)
      }
      
      new_violation_history = [violation_entry | state.violation_history] |> Enum.take(50)
      new_metrics = update_policy_metrics(state.metrics, :violations_detected, length(violations))
      
      new_state = %{state | 
        violation_history: new_violation_history,
        metrics: new_metrics
      }
      
      {:reply, {:ok, violations}, new_state}
    else
      {:reply, {:ok, []}, state}
    end
  end
  
  @impl true
  def handle_call(:get_policy_metrics, _from, state) do
    enhanced_metrics = Map.merge(state.metrics, %{
      total_policies: map_size(state.policies),
      policy_changes: length(state.policy_history),
      recent_violations: length(state.violation_history),
      coherence_score: state.coherence_cache,
      last_coherence_check: state.last_coherence_check
    })
    
    {:reply, {:ok, enhanced_metrics}, state}
  end
  
  @impl true
  def handle_call({:apply_policy_constraints, policy_data, constraints}, _from, state) do
    constrained_policy = apply_constraints_internal(policy_data, constraints, state)
    {:reply, {:ok, constrained_policy}, state}
  end
  
  @impl true
  def handle_cast({:propagate_policy_change, policy_type, policy_data}, state) do
    propagate_policy_change_internal(policy_type, policy_data)
    {:noreply, state}
  end
  
  # Private Functions
  
  defp initialize_policy_metrics do
    %{
      policies_set: 0,
      policies_synthesized: 0,
      validations_performed: 0,
      violations_detected: 0,
      coherence_checks: 0,
      propagations_sent: 0,
      last_activity: System.system_time(:millisecond)
    }
  end
  
  defp update_policy_metrics(metrics, operation, count \\ 1) do
    updated_metrics = case operation do
      :policy_set -> %{metrics | policies_set: metrics.policies_set + count}
      :policy_synthesized -> %{metrics | policies_synthesized: metrics.policies_synthesized + count}
      :validation_performed -> %{metrics | validations_performed: metrics.validations_performed + count}
      :violations_detected -> %{metrics | violations_detected: metrics.violations_detected + count}
      :coherence_check -> %{metrics | coherence_checks: metrics.coherence_checks + count}
      :propagation_sent -> %{metrics | propagations_sent: metrics.propagations_sent + count}
    end
    
    %{updated_metrics | last_activity: System.system_time(:millisecond)}
  end
  
  defp validate_policy_internal(policy_type, policy_data, state) do
    violations = []
    
    # Check required fields based on policy type
    violations = check_required_fields(policy_type, policy_data, violations)
    
    # Check value ranges
    violations = check_value_ranges(policy_type, policy_data, violations)
    
    # Check for conflicts with existing policies
    violations = check_policy_conflicts(policy_type, policy_data, state.policies, violations)
    
    if violations == [] do
      :ok
    else
      {:error, violations}
    end
  end
  
  defp check_required_fields(policy_type, policy_data, violations) do
    required_fields = get_required_fields(policy_type)
    
    Enum.reduce(required_fields, violations, fn field, acc ->
      if Map.has_key?(policy_data, field) do
        acc
      else
        ["Missing required field: #{field}" | acc]
      end
    end)
  end
  
  defp check_value_ranges(_policy_type, policy_data, violations) do
    Enum.reduce(policy_data, violations, fn {key, value}, acc ->
      cond do
        key in [:minimum_viability, :intervention_threshold, :target_viability] and 
        (not is_number(value) or value < 0.0 or value > 1.0) ->
          ["#{key} must be a number between 0.0 and 1.0" | acc]
          
        key in [:evaluation_interval, :adaptation_cooldown] and 
        (not is_integer(value) or value < 1000) ->
          ["#{key} must be an integer >= 1000 milliseconds" | acc]
          
        true -> acc
      end
    end)
  end
  
  defp check_policy_conflicts(_policy_type, _policy_data, _existing_policies, violations) do
    # Could implement conflict detection logic here
    violations
  end
  
  defp get_required_fields(policy_type) do
    case policy_type do
      :viability_threshold -> [:minimum_viability, :target_viability]
      :resource_allocation -> [:max_system_load]
      :adaptation_governance -> [:adaptation_confidence_threshold]
      :algedonic_sensitivity -> [:pain_escalation_threshold]
      _ -> []
    end
  end
  
  defp calculate_coherence_internal(policies) do
    # Simplified coherence calculation - could be more sophisticated
    policy_values = policies
                   |> Enum.flat_map(fn {_, policy_data} -> Map.values(policy_data) end)
                   |> Enum.filter(&is_number/1)
    
    if policy_values == [] do
      0.0  # Real: 0 when no policies to measure coherence
    else
      # Calculate variance as inverse of coherence
      mean = Enum.sum(policy_values) / length(policy_values)
      variance = policy_values
                |> Enum.map(&:math.pow(&1 - mean, 2))
                |> Enum.sum()
                |> Kernel./(length(policy_values))
      
      # Convert variance to coherence score (0-1)
      max(0.0, 1.0 - variance)
    end
  end
  
  defp check_violations_internal(policies, current_state, _context) do
    violations = []
    
    # Check viability threshold violations
    violations = check_viability_violations(policies, current_state, violations)
    
    # Check resource allocation violations  
    violations = check_resource_violations(policies, current_state, violations)
    
    violations
  end
  
  defp check_viability_violations(policies, state, violations) do
    viability_policy = Map.get(policies, :viability_threshold, %{})
    min_viability = Map.get(viability_policy, :minimum_viability, 0.3)
    current_viability = Map.get(state, :viability, 1.0)
    
    if current_viability < min_viability do
      ["Viability below minimum threshold: #{current_viability} < #{min_viability}" | violations]
    else
      violations
    end
  end
  
  defp check_resource_violations(policies, state, violations) do
    resource_policy = Map.get(policies, :resource_allocation, %{})
    max_load = Map.get(resource_policy, :max_system_load, 0.85)
    current_load = Map.get(state, :system_load, 0.0)
    
    if current_load > max_load do
      ["System load exceeds maximum: #{current_load} > #{max_load}" | violations]
    else
      violations
    end
  end
  
  defp apply_constraints_internal(policy_data, constraints, _state) do
    # Apply system constraints to policy data
    Enum.reduce(constraints, policy_data, fn {constraint_key, constraint_value}, acc ->
      case constraint_key do
        :max_value -> 
          Enum.reduce(acc, acc, fn {k, v}, policy_acc ->
            if is_number(v) and v > constraint_value do
              Map.put(policy_acc, k, constraint_value)
            else
              policy_acc
            end
          end)
          
        :min_value ->
          Enum.reduce(acc, acc, fn {k, v}, policy_acc ->
            if is_number(v) and v < constraint_value do
              Map.put(policy_acc, k, constraint_value)
            else
              policy_acc
            end
          end)
          
        _ -> acc
      end
    end)
  end
  
  defp propagate_policy_change_internal(policy_type, policy_data) do
    # Broadcast policy change to other systems
    change_message = {:policy_changed, policy_type, policy_data, System.system_time(:millisecond)}
    
    PubSub.broadcast(VsmPhoenix.PubSub, "vsm:system5", change_message)
    PubSub.broadcast(VsmPhoenix.PubSub, "vsm:policy", change_message)
    
    Logger.debug("📋 Propagated policy change: #{policy_type}")
  end
  
  defp generate_change_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end