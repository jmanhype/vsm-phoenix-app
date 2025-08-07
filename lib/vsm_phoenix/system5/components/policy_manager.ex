defmodule VsmPhoenix.System5.Components.PolicyManager do
  @moduledoc """
  Policy Manager Component - Handles all policy-related operations for System 5

  Responsibilities:
  - Store and manage all system policies
  - Validate and apply policy constraints
  - Propagate policy changes throughout the VSM
  - Execute policies when appropriate
  - Maintain policy coherence and consistency
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def set_policy(policy_type, policy_data) do
    GenServer.call(__MODULE__, {:set_policy, policy_type, policy_data})
  end

  def get_policy(policy_type) do
    GenServer.call(__MODULE__, {:get_policy, policy_type})
  end

  def get_all_policies do
    GenServer.call(__MODULE__, :get_all_policies)
  end

  def apply_constraints(policy, constraints) do
    GenServer.call(__MODULE__, {:apply_constraints, policy, constraints})
  end

  def execute_policy(policy_id) do
    GenServer.call(__MODULE__, {:execute_policy, policy_id})
  end

  def synthesize_policy(policy_data) do
    GenServer.call(__MODULE__, {:synthesize_policy, policy_data})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("PolicyManager initializing...")

    state = %{
      policies: %{
        governance: default_governance_policy(),
        adaptation: default_adaptation_policy(),
        resource_allocation: default_resource_policy(),
        identity_preservation: default_identity_policy()
      },
      amqp_channel: nil
    }

    # Set up AMQP for policy broadcasting
    state_with_amqp = setup_amqp_channel(state)

    {:ok, state_with_amqp}
  end

  @impl true
  def handle_call({:set_policy, policy_type, policy_data}, _from, state) do
    Logger.info("PolicyManager: Setting policy #{policy_type}")

    new_policies = Map.put(state.policies, policy_type, policy_data)
    new_state = %{state | policies: new_policies}

    # Propagate policy changes
    propagate_policy_change(policy_type, policy_data, state)

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_policy, policy_type}, _from, state) do
    policy = Map.get(state.policies, policy_type)
    {:reply, {:ok, policy}, state}
  end

  @impl true
  def handle_call(:get_all_policies, _from, state) do
    {:reply, {:ok, state.policies}, state}
  end

  @impl true
  def handle_call({:apply_constraints, policy, constraints}, _from, state) do
    constrained_policy = apply_policy_constraints(policy, constraints)
    {:reply, {:ok, constrained_policy}, state}
  end

  @impl true
  def handle_call({:execute_policy, policy_id}, _from, state) do
    case Map.get(state.policies, policy_id) do
      nil ->
        {:reply, {:error, :policy_not_found}, state}

      policy ->
        execute_policy_impl(policy, state)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:synthesize_policy, policy_data}, _from, state) do
    new_policy = synthesize_new_policy(policy_data)
    policy_id = new_policy.id || generate_policy_id()

    new_policies = Map.put(state.policies, policy_id, new_policy)
    new_state = %{state | policies: new_policies}

    {:reply, {:ok, new_policy}, new_state}
  end

  @impl true
  def handle_info(:retry_amqp_setup, state) do
    new_state = setup_amqp_channel(state)
    {:noreply, new_state}
  end

  # Private Functions

  defp default_governance_policy do
    %{
      decision_thresholds: %{
        critical: 0.9,
        major: 0.7,
        minor: 0.5
      },
      autonomy_levels: %{
        system1: :high,
        system2: :medium,
        system3: :medium,
        system4: :high
      },
      intervention_triggers: %{
        health_threshold: 0.7,
        resource_threshold: 0.6,
        coherence_threshold: 0.8
      }
    }
  end

  defp default_adaptation_policy do
    %{
      allowed_adaptations: [:structure, :process, :resource, :coordination],
      adaptation_limits: %{
        max_structural_change: 0.3,
        max_process_change: 0.5,
        max_resource_reallocation: 0.4
      },
      evaluation_criteria: [:viability_impact, :identity_preservation, :cost_benefit]
    }
  end

  defp default_resource_policy do
    %{
      allocation_priorities: [:critical_operations, :adaptation, :optimization, :innovation],
      resource_limits: %{
        compute: 0.8,
        memory: 0.85,
        network: 0.7
      },
      efficiency_targets: %{
        min_utilization: 0.6,
        max_waste: 0.1
      }
    }
  end

  defp default_identity_policy do
    %{
      core_functions: [:policy_governance, :viability_maintenance, :identity_preservation],
      identity_markers: [:vsm_hierarchy, :recursive_structure, :autonomous_operation],
      evolution_constraints: %{
        preserve_core: true,
        allow_peripheral_change: true,
        maintain_coherence: true
      }
    }
  end

  defp propagate_policy_change(policy_type, policy_data, state) do
    # Notify all systems of policy changes via PubSub
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:policy",
      {:policy_update, policy_type, policy_data}
    )

    # Also broadcast via AMQP if available
    broadcast_policy_amqp(policy_type, policy_data, state)
  end

  defp apply_policy_constraints(policy, constraints) do
    constrained_policy = policy

    # Apply budget constraints
    constrained_policy =
      if constraints[:max_budget] do
        Map.update(constrained_policy, :resource_limits, %{}, fn limits ->
          Map.put(limits, :budget, constraints.max_budget)
        end)
      else
        constrained_policy
      end

    # Apply time constraints
    constrained_policy =
      if constraints[:max_duration] do
        Map.put(constrained_policy, :time_limit, constraints.max_duration)
      else
        constrained_policy
      end

    # Apply approval requirements
    if constraints[:require_human_approval] do
      Map.put(constrained_policy, :auto_executable, false)
    else
      constrained_policy
    end
  end

  defp execute_policy_impl(policy, state) do
    Logger.info("⚡ Executing policy: #{inspect(policy)}")

    # Execute each step if policy has SOP
    if Map.has_key?(policy, :sop) && Map.has_key?(policy.sop, :steps) do
      Enum.each(policy.sop.steps, fn step ->
        Logger.info("  → Executing: #{step}")
        # In production, this would actually execute the step
      end)
    end

    # Apply mitigation steps if available
    if Map.has_key?(policy, :mitigation_steps) do
      Enum.each(policy.mitigation_steps, fn mitigation ->
        case mitigation.priority do
          :high -> execute_immediate_mitigation(mitigation)
          :medium -> schedule_mitigation(mitigation, 5_000)
          :low -> schedule_mitigation(mitigation, 30_000)
        end
      end)
    end

    # Broadcast policy execution
    broadcast_policy_execution(policy, state)
  end

  defp execute_immediate_mitigation(mitigation) do
    Logger.info("🚨 IMMEDIATE MITIGATION: #{mitigation.action}")
    # Real implementation would execute the action
  end

  defp schedule_mitigation(mitigation, delay) do
    Process.send_after(self(), {:execute_mitigation, mitigation}, delay)
  end

  defp broadcast_policy_amqp(policy_type, policy_data, state) do
    if state.amqp_channel do
      policy_message = %{
        type: "policy_update",
        policy_type: to_string(policy_type),
        policy_data: policy_data,
        source: "policy_manager",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      payload = Jason.encode!(policy_message)

      # Publish to policy fanout exchange
      :ok =
        AMQP.Basic.publish(
          state.amqp_channel,
          "vsm.policy",
          "",
          payload,
          content_type: "application/json"
        )

      Logger.info("PolicyManager: Broadcast policy update via AMQP - #{policy_type}")
    end
  end

  defp broadcast_policy_execution(policy, state) do
    execution_data = %{
      policy_id: Map.get(policy, :id, "unknown"),
      policy_type: Map.get(policy, :type, "unknown"),
      executed_at: DateTime.utc_now()
    }

    # PubSub broadcast
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:policy",
      {:policy_executed, execution_data}
    )

    # AMQP broadcast
    if state.amqp_channel do
      message =
        Map.merge(execution_data, %{
          type: "policy_executed",
          source: "policy_manager"
        })

      payload = Jason.encode!(message)

      AMQP.Basic.publish(
        state.amqp_channel,
        "vsm.policy",
        "",
        payload,
        content_type: "application/json"
      )
    end
  end

  defp setup_amqp_channel(state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_channel(:policy_manager) do
      {:ok, channel} ->
        Map.put(state, :amqp_channel, channel)

      {:error, reason} ->
        Logger.error("PolicyManager: Could not get AMQP channel: #{inspect(reason)}")
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end

  defp synthesize_new_policy(policy_data) do
    %{
      id: generate_policy_id(),
      type: Map.get(policy_data, :type, :custom),
      rules: Map.get(policy_data, :rules, []),
      constraints: Map.get(policy_data, :constraints, %{}),
      auto_executable: Map.get(policy_data, :auto_executable, false),
      created_at: DateTime.utc_now()
    }
  end

  defp generate_policy_id do
    "policy_#{:erlang.system_time(:millisecond)}_#{:rand.uniform(1000)}"
  end
end
