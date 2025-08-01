defmodule VsmPhoenix.System5.Queen do
  @moduledoc """
  System 5 - Queen: Policy and Identity Governance
  
  The Queen oversees the entire VSM hierarchy, ensuring:
  - Policy coherence across all systems
  - Identity preservation and evolution
  - Strategic direction and purpose
  - Viability and sustainability
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System2.Coordinator
  alias VsmPhoenix.System5.PolicySynthesizer
  alias AMQP
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def set_policy(policy_type, policy_data) do
    GenServer.call(@name, {:set_policy, policy_type, policy_data})
  end
  
  def evaluate_viability do
    GenServer.call(@name, :evaluate_viability)
  end
  
  def get_strategic_direction do
    GenServer.call(@name, :get_strategic_direction)
  end
  
  def approve_adaptation(adaptation_proposal) do
    GenServer.call(@name, {:approve_adaptation, adaptation_proposal})
  end
  
  def get_identity_metrics do
    GenServer.call(@name, :get_identity_metrics)
  end
  
  def make_policy_decision(params) do
    GenServer.call(@name, {:make_policy_decision, params})
  end
  
  def send_pleasure_signal(intensity, context) do
    GenServer.cast(@name, {:pleasure_signal, intensity, context})
  end
  
  def send_pain_signal(intensity, context) do
    GenServer.cast(@name, {:pain_signal, intensity, context})
  end
  
  def get_governance_state do
    GenServer.call(@name, :get_governance_state)
  end
  
  def synthesize_adaptive_policy(anomaly_data, constraints \\ %{}) do
    GenServer.call(@name, {:synthesize_adaptive_policy, anomaly_data, constraints})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("System 5 Queen initializing...")
    
    state = %{
      policies: %{
        governance: default_governance_policy(),
        adaptation: default_adaptation_policy(),
        resource_allocation: default_resource_policy(),
        identity_preservation: default_identity_policy()
      },
      strategic_direction: %{
        mission: "Maintain viable system operations with recursive self-governance",
        vision: "Autonomous, resilient, and adaptive system coordination",
        values: ["autonomy", "viability", "resilience", "coherence", "evolution"]
      },
      viability_metrics: %{
        system_health: 1.0,
        adaptation_capacity: 1.0,
        resource_efficiency: 1.0,
        identity_coherence: 1.0
      },
      decisions: [],
      algedonic_signals: []
    }
    
    # Schedule periodic viability checks
    schedule_viability_check()
    
    # Set up AMQP consumer for algedonic signals
    state_with_amqp = setup_algedonic_consumer(state)
    
    {:ok, state_with_amqp}
  end
  
  @impl true
  def handle_call({:set_policy, policy_type, policy_data}, _from, state) do
    Logger.info("Queen: Setting policy #{policy_type}")
    
    new_policies = Map.put(state.policies, policy_type, policy_data)
    new_state = %{state | policies: new_policies}
    
    # Propagate policy changes to lower systems
    propagate_policy_change(policy_type, policy_data)
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:evaluate_viability, _from, state) do
    Logger.info("Queen: Evaluating system viability")
    
    # Gather metrics from all systems
    intelligence_health = Intelligence.get_system_health()
    control_metrics = Control.get_resource_metrics()
    coordination_status = Coordinator.get_coordination_status()
    
    # Calculate viability from external systems
    external_viability = calculate_viability(intelligence_health, control_metrics, coordination_status)
    
    # Merge with internal viability metrics (which are updated by algedonic signals)
    viability = Map.merge(external_viability, state.viability_metrics)
    
    # Don't overwrite the internal metrics, just return the merged result
    {:reply, viability, state}
  end
  
  @impl true
  def handle_call(:get_strategic_direction, _from, state) do
    {:reply, state.strategic_direction, state}
  end
  
  @impl true
  def handle_call({:approve_adaptation, proposal}, _from, state) do
    Logger.info("Queen: Evaluating adaptation proposal")
    
    decision = evaluate_adaptation_proposal(proposal, state)
    
    new_decisions = [{DateTime.utc_now(), proposal, decision} | state.decisions]
    new_state = %{state | decisions: Enum.take(new_decisions, 100)}
    
    if decision.approved do
      # Notify System 4 to implement the adaptation
      Intelligence.implement_adaptation(proposal)
    end
    
    {:reply, decision, new_state}
  end
  
  @impl true
  def handle_call({:make_policy_decision, params}, _from, state) do
    Logger.info("Queen: Making policy decision for #{inspect(params["decision_type"])}")
    
    # Evaluate the decision based on current policies and constraints
    decision = %{
      decision_type: params["decision_type"],
      selected_option: evaluate_best_option(params, state),
      reasoning: generate_reasoning(params, state),
      confidence: calculate_confidence(params, state),
      implementation_steps: generate_implementation_steps(params, state),
      expected_outcomes: predict_outcomes(params, state)
    }
    
    # Record the decision
    new_decisions = [{DateTime.utc_now(), params, decision} | state.decisions]
    new_state = %{state | decisions: Enum.take(new_decisions, 100)}
    
    # Broadcast decision to relevant systems
    Phoenix.PubSub.broadcast(VsmPhoenix.PubSub, "vsm:policy", {:policy_decision, decision})
    
    {:reply, {:ok, decision}, new_state}
  end
  
  @impl true
  def handle_call(:get_identity_metrics, _from, state) do
    metrics = %{
      coherence: state.viability_metrics.identity_coherence,
      policies: Map.keys(state.policies),
      strategic_alignment: calculate_strategic_alignment(state),
      decision_consistency: calculate_decision_consistency(state.decisions)
    }
    
    {:reply, metrics, state}
  end
  
  @impl true
  def handle_call(:get_governance_state, _from, state) do
    # Return comprehensive governance state
    governance_state = %{
      policies: state.policies,
      strategic_direction: state.strategic_direction,
      viability_metrics: state.viability_metrics,
      identity: state.identity,
      algedonic_state: state.algedonic_state,
      decision_count: length(state.decisions),
      active_policy_types: Map.keys(state.policies),
      current_focus: determine_current_focus(state)
    }
    
    {:reply, {:ok, governance_state}, state}
  end
  
  @impl true
  def handle_call({:synthesize_adaptive_policy, anomaly_data, constraints}, _from, state) do
    Logger.info("Queen: Synthesizing adaptive policy for anomaly")
    
    # Use PolicySynthesizer for the actual synthesis
    case PolicySynthesizer.synthesize_policy_from_anomaly(anomaly_data) do
      {:ok, policy} ->
        # Apply constraints if any
        constrained_policy = apply_policy_constraints(policy, constraints)
        
        # Store the new policy
        new_policies = Map.put(state.policies, policy.id, constrained_policy)
        new_state = %{state | policies: new_policies}
        
        {:reply, {:ok, constrained_policy}, new_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_cast({:pleasure_signal, intensity, context}, state) do
    Logger.info("Queen: Received pleasure signal (#{intensity}) from #{inspect(context)}")
    
    # Record positive feedback
    new_algedonic = [{:pleasure, intensity, context, DateTime.utc_now()} | state.algedonic_signals]
    
    # Reinforce current policies that led to this positive outcome
    reinforced_policies = reinforce_policies(state.policies, context, intensity)
    
    # Update viability metrics based on pleasure signal
    updated_viability = update_viability_from_signal(state.viability_metrics, :pleasure, intensity)
    
    new_state = %{state | 
      algedonic_signals: Enum.take(new_algedonic, 1000),
      policies: reinforced_policies,
      viability_metrics: updated_viability
    }
    
    # Broadcast the updated viability
    Phoenix.PubSub.broadcast(VsmPhoenix.PubSub, "vsm:health", {:viability_update, updated_viability})
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:pain_signal, intensity, context}, state) do
    Logger.warning("Queen: Received pain signal (#{intensity}) from #{inspect(context)}")
    
    # Record negative feedback
    new_algedonic = [{:pain, intensity, context, DateTime.utc_now()} | state.algedonic_signals]
    
    # Trigger immediate adaptation if pain is severe
    if intensity > 0.7 do
      Intelligence.generate_adaptation_proposal(%{
        type: :algedonic_response,
        urgency: :high,
        pain_level: intensity,
        context: context
      })
      
      # NEW: LLM-based policy synthesis from anomaly!
      spawn(fn ->
        Logger.info("🧠 TRIGGERING LLM POLICY SYNTHESIS FROM PAIN SIGNAL")
        
        anomaly_data = %{
          type: :pain_signal,
          intensity: intensity,
          context: context,
          severity: intensity,
          timestamp: DateTime.utc_now(),
          system_state: summarize_system_state(state)
        }
        
        case PolicySynthesizer.synthesize_policy_from_anomaly(anomaly_data) do
          {:ok, policy} ->
            Logger.info("✅ NEW POLICY SYNTHESIZED: #{policy.id}")
            # Apply the new policy
            GenServer.cast(@name, {:apply_synthesized_policy, policy})
            
          {:error, reason} ->
            Logger.error("Policy synthesis failed: #{inspect(reason)}")
        end
      end)
    end
    
    # Update viability metrics based on pain signal
    updated_viability = update_viability_from_signal(state.viability_metrics, :pain, intensity)
    
    new_state = %{state | 
      algedonic_signals: Enum.take(new_algedonic, 1000),
      viability_metrics: updated_viability
    }
    
    # Broadcast the updated viability
    Phoenix.PubSub.broadcast(VsmPhoenix.PubSub, "vsm:health", {:viability_update, updated_viability})
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:apply_synthesized_policy, policy}, state) do
    Logger.info("🏛️ Queen: Applying synthesized policy #{policy.id}")
    
    # Add to active policies
    new_policies = Map.put(state.policies, policy.id, policy)
    
    # If policy is auto-executable, apply immediately
    if policy.auto_executable do
      execute_policy(policy, state)
    end
    
    # Broadcast new policy to all systems
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:policies",
      {:new_policy, policy}
    )
    
    {:noreply, %{state | policies: new_policies}}
  end
  
  @impl true
  def handle_cast({:anomaly_detected, anomaly}, state) do
    Logger.warning("🚨 Queen: Anomaly reported by System 4")
    
    # Trigger policy synthesis for anomaly
    spawn(fn ->
      case PolicySynthesizer.synthesize_policy_from_anomaly(anomaly) do
        {:ok, policy} ->
          GenServer.cast(@name, {:apply_synthesized_policy, policy})
        {:error, _reason} ->
          :ok
      end
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:check_viability, state) do
    # Direct evaluation instead of self-call
    viability = calculate_viability(state)
    
    if viability.system_health < 0.7 do
      Logger.warning("Queen: System health below threshold, initiating intervention")
      initiate_health_intervention(viability)
    end
    
    schedule_viability_check()
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    IO.puts("👑👑👑 QUEEN RECEIVED AMQP MESSAGE! Payload: #{inspect(payload)}")
    # Handle AMQP message from algedonic channel
    case Jason.decode(payload) do
      {:ok, message} ->
        Logger.info("👑 Queen received algedonic signal: #{message["signal_type"]} from #{message["context"]}")
        
        # Process the algedonic signal
        IO.puts("🔥 CALLING process_algedonic_signal")
        new_state = process_algedonic_signal(message, state)
        IO.puts("🔥 RETURNED from process_algedonic_signal")
        
        # Acknowledge the message
        if state[:amqp_channel] do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
      {:error, _} ->
        Logger.error("Queen: Failed to decode algedonic message")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("👑 Queen: AMQP consumer registered successfully")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("Queen: AMQP consumer cancelled")
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("Queen: AMQP consumer cancel confirmed")
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("Queen: Retrying AMQP setup...")
    new_state = setup_algedonic_consumer(state)
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp calculate_viability(state) do
    # Calculate overall viability from metrics
    health = state.viability_metrics.system_health
    adaptation = state.viability_metrics.adaptation_capacity
    efficiency = state.viability_metrics.resource_efficiency
    coherence = state.viability_metrics.identity_coherence
    
    overall = (health + adaptation + efficiency + coherence) / 4
    
    %{
      overall_viability: overall,
      system_health: health,
      adaptation_capacity: adaptation,
      resource_efficiency: efficiency,
      identity_coherence: coherence
    }
  end
  
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
  
  defp propagate_policy_change(policy_type, policy_data) do
    # Notify all systems of policy changes via PubSub
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:policy",
      {:policy_update, policy_type, policy_data}
    )
    
    # Also broadcast via AMQP
    GenServer.cast(@name, {:broadcast_policy_amqp, policy_type, policy_data})
  end
  
  defp calculate_viability(intelligence, control, coordination) do
    %{
      system_health: (intelligence.health + control.efficiency + coordination.effectiveness) / 3,
      adaptation_capacity: intelligence.adaptation_readiness,
      resource_efficiency: control.resource_utilization,
      identity_coherence: calculate_coherence(intelligence, control, coordination)
    }
  end
  
  defp calculate_coherence(_intelligence, _control, _coordination) do
    # Calculate how well all systems are aligned with identity
    0.95  # Simplified for now
  end
  
  defp calculate_strategic_alignment(state) do
    # Measure how well current operations align with strategic direction
    0.9  # Simplified for now
  end
  
  defp calculate_decision_consistency(decisions) do
    # Analyze consistency of recent decisions
    if length(decisions) < 2, do: 1.0, else: 0.85
  end
  
  defp determine_current_focus(state) do
    # Determine what the governance system is currently focused on
    cond do
      state.algedonic_state[:pain_level] > 0.7 -> :crisis_management
      state.viability_metrics.system_health < 0.5 -> :viability_restoration
      state.algedonic_state[:pleasure_level] > 0.8 -> :opportunity_exploitation
      true -> :steady_state_governance
    end
  end
  
  defp apply_policy_constraints(policy, constraints) do
    # Apply any constraints to the policy
    constrained_policy = policy
    
    # Apply budget constraints
    constrained_policy = if constraints[:max_budget] do
      Map.update(constrained_policy, :resource_limits, %{}, fn limits ->
        Map.put(limits, :budget, constraints.max_budget)
      end)
    else
      constrained_policy
    end
    
    # Apply time constraints
    constrained_policy = if constraints[:max_duration] do
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
  
  defp evaluate_best_option(params, state) do
    options = params["options"] || []
    constraints = params["constraints"] || %{}
    
    # Simple scoring based on constraints and policies
    scored_options = Enum.map(options, fn option ->
      score = calculate_option_score(option, constraints, state)
      {option, score}
    end)
    
    {best_option, _score} = Enum.max_by(scored_options, fn {_opt, score} -> score end, fn -> {"maintain_status_quo", 0.5} end)
    best_option
  end
  
  defp calculate_option_score(option, constraints, state) do
    base_score = 0.5
    
    # Adjust score based on budget constraint
    budget_score = if constraints["budget"] && option =~ "increase", do: -0.2, else: 0.1
    
    # Adjust based on time constraint  
    time_score = if constraints["time"] && constraints["time"] =~ "hours" && option =~ "delay", do: -0.3, else: 0.1
    
    # Policy alignment score
    policy_score = if option =~ "customer", do: 0.2, else: 0.0
    
    base_score + budget_score + time_score + policy_score
  end
  
  defp generate_reasoning(params, state) do
    constraints = params["constraints"] || %{}
    budget_info = if constraints["budget"], do: "budget: #{constraints["budget"]}", else: "no budget constraint"
    time_info = if constraints["time"], do: "time: #{constraints["time"]}", else: "no time constraint"
    
    "Based on current policies and constraints (#{budget_info}, #{time_info}), " <>
    "this option best balances customer satisfaction with operational viability while maintaining system coherence."
  end
  
  defp calculate_confidence(params, state) do
    # Confidence based on clarity of constraints and policy alignment
    base_confidence = 0.7
    constraint_clarity = if map_size(params["constraints"] || %{}) > 1, do: 0.1, else: 0.0
    policy_alignment = 0.15
    
    base_confidence + constraint_clarity + policy_alignment
  end
  
  defp generate_implementation_steps(params, state) do
    [
      "1. Notify System 3 (Control) to allocate resources",
      "2. Coordinate with System 2 to prevent oscillations",
      "3. System 1 contexts to execute operational changes",
      "4. System 4 to monitor environmental response",
      "5. Continuous viability assessment via algedonic channels"
    ]
  end
  
  defp predict_outcomes(params, state) do
    context_desc = case params["context"] do
      ctx when is_map(ctx) -> inspect(ctx)
      ctx when is_binary(ctx) -> ctx
      _ -> "unspecified context"
    end
    
    %{
      short_term: "Immediate response to #{context_desc}",
      medium_term: "Stabilized operations within constraints",
      long_term: "Enhanced system resilience and adaptability",
      risks: ["Resource strain", "Potential quality impacts"],
      opportunities: ["Customer loyalty", "Process optimization"]
    }
  end
  
  defp reinforce_policies(policies, context, intensity) do
    # Strengthen policies that led to positive outcomes
    policies
  end
  
  defp evaluate_adaptation_proposal(proposal, state) do
    # Evaluate proposal against policies and current state
    adaptation_policy = state.policies.adaptation
    
    %{
      approved: proposal.impact < adaptation_policy.adaptation_limits.max_structural_change,
      reason: "Within adaptation limits",
      conditions: ["monitor_impact", "preserve_identity"],
      review_date: DateTime.add(DateTime.utc_now(), 86400, :second)
    }
  end
  
  defp initiate_health_intervention(viability) do
    Logger.warning("Queen: Initiating health intervention")
    
    # Direct System 3 to reallocate resources
    Control.emergency_reallocation(viability)
    
    # Request adaptation proposals from System 4
    Intelligence.request_adaptation_proposals(viability)
  end
  
  defp schedule_viability_check do
    Process.send_after(self(), :check_viability, 30_000)  # Check every 30 seconds
  end
  
  defp setup_algedonic_consumer(state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_channel(:algedonic_consumer) do
      {:ok, channel} ->
        try do
          # Ensure queue exists first
          {:ok, _queue} = AMQP.Queue.declare(channel, "vsm.system5.policy", durable: true)
          
          # Bind queue to algedonic exchange (fanout)
          :ok = AMQP.Queue.bind(channel, "vsm.system5.policy", "vsm.algedonic")
          
          # Set up consumer for algedonic signals
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, "vsm.system5.policy")
          
          Logger.info("👑 Queen: AMQP consumer active! Tag: #{consumer_tag}")
          Logger.info("👑 Queen: Listening for algedonic signals on vsm.system5.policy via vsm.algedonic exchange")
          
          Map.put(state, :amqp_channel, channel)
        rescue
          error ->
            Logger.error("Queen: Failed to set up AMQP consumer: #{inspect(error)}")
            state
        end
        
      {:error, reason} ->
        Logger.error("Queen: Could not get AMQP channel: #{inspect(reason)}")
        # Schedule retry
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end
  
  defp summarize_system_state(state) do
    %{
      viability_metrics: state.viability_metrics,
      active_policies: Map.keys(state.policies),
      recent_algedonic: Enum.take(state.algedonic_signals, 5),
      decision_count: length(state.decisions)
    }
  end
  
  defp process_algedonic_signal(message, state) do
    signal_type = String.to_atom(message["signal_type"])
    delta = message["viability_delta"]
    health = message["current_health"]
    context = message["context"]
    
    # Record the signal
    new_signal = {signal_type, abs(delta), context, DateTime.utc_now()}
    new_algedonic_signals = [new_signal | state.algedonic_signals] |> Enum.take(1000)
    
    # Update viability metrics based on signal
    updated_metrics = case signal_type do
      :pain -> update_viability_from_signal(state.viability_metrics, :pain, abs(delta))
      :pleasure -> update_viability_from_signal(state.viability_metrics, :pleasure, abs(delta))
      _ -> state.viability_metrics
    end
    
    # Handle pain signals with potential intervention
    state = if signal_type == :pain && abs(delta) > 0.2 do
      Logger.warning("👑 Queen: Significant pain signal (#{delta}) - evaluating intervention")
      
      # Request immediate adaptation if needed
      if health < 0.5 do
        Intelligence.generate_adaptation_proposal(%{
          type: :algedonic_response,
          urgency: :high,
          pain_level: abs(delta),
          context: context,
          current_health: health
        })
      end
      
      state
    else
      state
    end
    
    # Broadcast updated viability to dashboard
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub, 
      "vsm:health", 
      {:viability_update, updated_metrics}
    )
    
    # Broadcast algedonic signal to dashboard
    algedonic_message = %{
      signal_type: signal_type,
      delta: delta,
      health: health,
      context: context,
      timestamp: message["timestamp"]
    }
    
    IO.puts("📢 BROADCASTING ALGEDONIC SIGNAL: #{inspect(algedonic_message)}")
    
    broadcast_result = Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:algedonic",
      {:algedonic_signal, algedonic_message}
    )
    
    IO.puts("📢 BROADCAST RESULT: #{inspect(broadcast_result)}")
    
    %{state | 
      algedonic_signals: new_algedonic_signals,
      viability_metrics: updated_metrics
    }
  end
  
  defp update_viability_from_signal(current_metrics, :pleasure, intensity) do
    # Pleasure signals improve viability metrics
    %{current_metrics |
      system_health: min(1.0, current_metrics.system_health + (intensity * 0.1)),
      adaptation_capacity: min(1.0, current_metrics.adaptation_capacity + (intensity * 0.05)),
      identity_coherence: min(1.0, current_metrics.identity_coherence + (intensity * 0.08))
    }
  end
  
  defp update_viability_from_signal(current_metrics, :pain, intensity) do
    # Pain signals decrease viability metrics
    %{current_metrics |
      system_health: max(0.0, current_metrics.system_health - (intensity * 0.15)),
      adaptation_capacity: max(0.0, current_metrics.adaptation_capacity - (intensity * 0.1)),
      resource_efficiency: max(0.0, current_metrics.resource_efficiency - (intensity * 0.05))
    }
  end
  
  defp execute_policy(policy, state) do
    Logger.info("⚡ AUTO-EXECUTING POLICY: #{policy.id}")
    
    # Execute each step in the SOP
    Enum.each(policy.sop.steps, fn step ->
      Logger.info("  → Executing: #{step}")
      # In production, this would actually execute the step
    end)
    
    # Apply mitigation steps
    Enum.each(policy.mitigation_steps, fn mitigation ->
      case mitigation.priority do
        :high -> execute_immediate_mitigation(mitigation, state)
        :medium -> schedule_mitigation(mitigation, 5_000)
        :low -> schedule_mitigation(mitigation, 30_000)
      end
    end)
    
    # Broadcast policy execution via AMQP
    GenServer.cast(@name, {:broadcast_policy_amqp, :policy_executed, %{
      policy_id: policy.id,
      policy_type: policy.type,
      executed_at: DateTime.utc_now()
    }})
  end
  
  defp execute_immediate_mitigation(mitigation, _state) do
    Logger.info("🚨 IMMEDIATE MITIGATION: #{mitigation.action}")
    # Real implementation would execute the action
  end
  
  defp schedule_mitigation(mitigation, delay) do
    Process.send_after(self(), {:execute_mitigation, mitigation}, delay)
  end
  
  @impl true
  def handle_cast({:broadcast_policy_amqp, policy_type, policy_data}, state) do
    # Broadcast policy changes via AMQP
    if state[:amqp_channel] do
      policy_message = %{
        type: "policy_update",
        policy_type: to_string(policy_type),
        policy_data: policy_data,
        source: "system5_queen",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      payload = Jason.encode!(policy_message)
      
      # Publish to policy fanout exchange
      :ok = AMQP.Basic.publish(
        state.amqp_channel,
        "vsm.policy",  # fanout exchange for policies
        "",
        payload,
        content_type: "application/json"
      )
      
      Logger.info("👑 Queen: Broadcast policy update via AMQP - #{policy_type}")
    end
    
    {:noreply, state}
  end
end