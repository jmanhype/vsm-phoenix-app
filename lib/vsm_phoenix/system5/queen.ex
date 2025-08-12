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
  
  # Legacy system aliases (to be phased out)
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System2.Coordinator
  alias VsmPhoenix.System5.PolicySynthesizer
  alias AMQP
  alias VsmPhoenix.Infrastructure.CausalityAMQP
  
  # NEW: Refactored components
  alias VsmPhoenix.System5.Algedonic.SignalProcessor, as: AlgedonicProcessor
  alias VsmPhoenix.System5.Policy.PolicyManager
  alias VsmPhoenix.System5.Viability.ViabilityEvaluator
  alias VsmPhoenix.System5.Decision.DecisionEngine
  
  # NEW: Integration with other swarm's modules
  alias VsmPhoenix.System2.CorticalAttentionEngine
  alias VsmPhoenix.AMQP.ProtocolIntegration
  alias VsmPhoenix.Telemetry.RefactoredAnalogArchitect
  alias VsmPhoenix.Resilience.{CircuitBreaker, Integration}
  alias VsmPhoenix.CRDT.ContextStore
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def set_policy(policy_type, policy_data) do
    # NEW: Delegate to PolicyManager
    PolicyManager.set_policy(policy_type, policy_data)
  end
  
  def evaluate_viability do
    # NEW: Delegate to ViabilityEvaluator
    case ViabilityEvaluator.evaluate_viability() do
      {:ok, viability_data} -> viability_data
      {:error, _reason} -> 
        # Fallback to default viability metrics if evaluator fails
        %{
          system_health: 0.0,
          adaptation_capacity: 0.0,
          resource_efficiency: 0.0,
          identity_coherence: 0.0,
          viability_index: 0.0
        }
    end
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
    # NEW: Delegate to DecisionEngine
    DecisionEngine.make_policy_decision(params)
  end
  
  def send_pleasure_signal(intensity, context) do
    # NEW: Delegate to AlgedonicProcessor
    AlgedonicProcessor.send_pleasure_signal(intensity, context)
  end
  
  def send_pain_signal(intensity, context) do
    # NEW: Delegate to AlgedonicProcessor
    AlgedonicProcessor.send_pain_signal(intensity, context)
  end
  
  def get_governance_state do
    GenServer.call(@name, :get_governance_state)
  end
  
  def get_policy_metrics do
    GenServer.call(@name, :get_policy_metrics)
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
      # Agnostic VSM Policy Metrics
      policy_metrics: %{
        coherence_score: 1.0,           # System alignment (0-1)
        policy_violations: [],          # Rule breaches with timestamps
        identity_drift: 0.0,           # Deviation from purpose (0-1)
        viability_index: 1.0,          # Overall health (0-1)
        decision_latency: 0.0          # Policy response time in ms
      },
      policy_baseline: %{
        acceptable_coherence: 0.7,      # Minimum acceptable coherence
        violation_threshold: 5,         # Max violations before intervention
        identity_tolerance: 0.2,        # Acceptable drift from identity
        target_latency: 1000,          # Target decision time in ms
        evaluation_window: 3600000     # 1 hour in ms
      },
      policy_history: %{
        coherence_trend: [],           # Historical coherence scores
        violation_log: [],             # All violations with context
        identity_markers: [],          # Identity checkpoints
        decision_times: [],            # Decision latency history
        viability_snapshots: []        # Periodic viability captures
      },
      decisions: [],
      algedonic_signals: [],
      algedonic_state: %{
        pain_level: 0.0,
        pleasure_level: 0.0,
        arousal_level: 0.0,
        overall_tone: :neutral
      }
    }
    
    # Schedule periodic viability checks
    schedule_viability_check()
    
    # Set up AMQP consumer for algedonic signals
    state_with_amqp = if System.get_env("DISABLE_AMQP") == "true" do
      state
    else
      setup_algedonic_consumer(state)
    end
    
    {:ok, state_with_amqp}
  end
  
  @impl true
  def handle_call({:set_policy, policy_type, policy_data}, _from, state) do
    Logger.info("Queen: Setting policy #{policy_type}")
    
    new_policies = Map.put(state.policies, policy_type, policy_data)
    
    # Track policy update in history
    policy_update = %{
      type: :policy_update,
      policy_type: policy_type,
      timestamp: DateTime.utc_now()
    }
    
    # Update coherence score based on policy alignment
    new_coherence = calculate_policy_coherence(new_policies)
    
    updated_metrics = %{state.policy_metrics |
      coherence_score: new_coherence
    }
    
    updated_history = %{state.policy_history |
      coherence_trend: [{DateTime.utc_now(), new_coherence} | state.policy_history.coherence_trend] |> Enum.take(100)
    }
    
    new_state = %{state | 
      policies: new_policies,
      policy_metrics: updated_metrics,
      policy_history: updated_history
    }
    
    # Propagate policy changes to lower systems
    propagate_policy_change(policy_type, policy_data)
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:evaluate_viability, _from, state) do
    Logger.info("Queen: Evaluating system viability")
    
    # Gather metrics from all systems
    intelligence_health = Intelligence.get_system_health()
    {:ok, control_metrics} = Control.get_resource_metrics()
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
    decision_start = :erlang.system_time(:millisecond)
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
    
    # Calculate decision latency
    decision_end = :erlang.system_time(:millisecond)
    latency_ms = decision_end - decision_start
    
    # Update policy metrics with decision latency
    updated_metrics = %{state.policy_metrics |
      decision_latency: latency_ms
    }
    
    # Track decision latency in history
    updated_history = %{state.policy_history |
      decision_times: [{DateTime.utc_now(), latency_ms} | state.policy_history.decision_times] |> Enum.take(100)
    }
    
    # Check if decision violates any policies
    violations = check_policy_violations(decision, params, state.policies)
    
    # Update violations if any found
    {updated_metrics, updated_history} = if length(violations) > 0 do
      new_violations = violations ++ state.policy_metrics.policy_violations
      violation_entries = Enum.map(violations, fn v -> 
        %{violation: v, timestamp: DateTime.utc_now(), decision_type: params["decision_type"]}
      end)
      
      {
        %{updated_metrics | policy_violations: Enum.take(new_violations, 50)},
        %{updated_history | violation_log: violation_entries ++ state.policy_history.violation_log |> Enum.take(100)}
      }
    else
      {updated_metrics, updated_history}
    end
    
    # Calculate identity drift based on decision alignment
    identity_drift = calculate_identity_drift(decision, state.strategic_direction, state.policy_history)
    updated_metrics = %{updated_metrics | identity_drift: identity_drift}
    
    # Update viability index
    viability_index = calculate_viability_index(updated_metrics, state.viability_metrics)
    updated_metrics = %{updated_metrics | viability_index: viability_index}
    
    # Record the decision
    new_decisions = [{DateTime.utc_now(), params, decision} | state.decisions]
    
    # Add viability snapshot periodically
    updated_history = if rem(length(new_decisions), 10) == 0 do
      snapshot = %{
        timestamp: DateTime.utc_now(),
        viability_index: viability_index,
        metrics: updated_metrics
      }
      %{updated_history | viability_snapshots: [snapshot | updated_history.viability_snapshots] |> Enum.take(50)}
    else
      updated_history
    end
    
    new_state = %{state | 
      decisions: Enum.take(new_decisions, 100),
      policy_metrics: updated_metrics,
      policy_history: updated_history
    }
    
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
  def handle_call(:get_policy_metrics, _from, state) do
    # Return agnostic VSM policy metrics
    metrics = %{
      coherence_score: state.policy_metrics.coherence_score,
      policy_violations: state.policy_metrics.policy_violations,
      identity_drift: state.policy_metrics.identity_drift,
      viability_index: state.policy_metrics.viability_index,
      decision_latency: state.policy_metrics.decision_latency,
      baseline: state.policy_baseline,
      trends: %{
        coherence_trend: Enum.take(state.policy_history.coherence_trend, 10),
        recent_violations: Enum.take(state.policy_history.violation_log, 10),
        decision_times: Enum.take(state.policy_history.decision_times, 10),
        viability_snapshots: Enum.take(state.policy_history.viability_snapshots, 5)
      }
    }
    
    {:reply, {:ok, metrics}, state}
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
    
    # Update algedonic state dynamically
    updated_algedonic_state = update_algedonic_state(state.algedonic_state, :pleasure, intensity, new_algedonic)
    
    new_state = %{state | 
      algedonic_signals: Enum.take(new_algedonic, 1000),
      policies: reinforced_policies,
      viability_metrics: updated_viability,
      algedonic_state: updated_algedonic_state
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
    
    # Update algedonic state dynamically
    updated_algedonic_state = update_algedonic_state(state.algedonic_state, :pain, intensity, new_algedonic)
    
    new_state = %{state | 
      algedonic_signals: Enum.take(new_algedonic, 1000),
      viability_metrics: updated_viability,
      algedonic_state: updated_algedonic_state
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
    
    # Update viability index in policy metrics
    viability_index = calculate_viability_index(state.policy_metrics, state.viability_metrics)
    
    updated_metrics = %{state.policy_metrics |
      viability_index: viability_index
    }
    
    # Add periodic viability snapshot
    snapshot = %{
      timestamp: DateTime.utc_now(),
      viability_index: viability_index,
      metrics: updated_metrics
    }
    
    updated_history = %{state.policy_history |
      viability_snapshots: [snapshot | state.policy_history.viability_snapshots] |> Enum.take(50)
    }
    
    # Check if intervention needed
    if viability.system_health < 0.7 or viability_index < state.policy_baseline.acceptable_coherence do
      Logger.warning("Queen: System health below threshold, initiating intervention")
      initiate_health_intervention(viability)
      
      # Record as a policy violation
      violation = %{
        type: :low_viability,
        timestamp: DateTime.utc_now(),
        viability_index: viability_index,
        system_health: viability.system_health
      }
      
      new_violations = [violation | state.policy_metrics.policy_violations] |> Enum.take(50)
      updated_metrics = %{updated_metrics | policy_violations: new_violations}
    end
    
    new_state = %{state |
      policy_metrics: updated_metrics,
      policy_history: updated_history
    }
    
    schedule_viability_check()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    IO.puts("👑👑👑 QUEEN RECEIVED AMQP MESSAGE! Payload: #{inspect(payload)}")
    # Handle AMQP message from algedonic channel with causality tracking
    {message, causality_info} = CausalityAMQP.receive_message(payload, meta)
    
    if is_map(message) do
        Logger.info("👑 Queen received algedonic signal: #{message["signal_type"]} from #{message["context"]} (chain depth: #{causality_info.chain_depth})")
        
        # Process the algedonic signal
        IO.puts("🔥 CALLING process_algedonic_signal")
        new_state = process_algedonic_signal(message, state)
        IO.puts("🔥 RETURNED from process_algedonic_signal")
        
        # Acknowledge the message
        if state[:amqp_channel] do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end
        
        {:noreply, new_state}
        
    else
        Logger.error("Queen: Unexpected message format: #{inspect(message)}")
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
      system_health: (intelligence.health + control.efficiency + coordination.coordination_effectiveness) / 3,
      adaptation_capacity: intelligence.adaptation_readiness,
      resource_efficiency: control.flow_utilization || 0.0,
      identity_coherence: calculate_coherence(intelligence, control, coordination)
    }
  end
  
  defp calculate_coherence(intelligence, control, coordination) do
    # Calculate how well all systems are aligned with identity
    
    # Base coherence from system health metrics
    health_coherence = (intelligence.health + control.efficiency + coordination.coordination_effectiveness) / 3
    
    # Alignment between subsystems
    adaptation_alignment = min(intelligence.adaptation_readiness, control.flow_utilization || 0.0)
    
    # Scan coverage indicates how well we understand our environment
    environmental_coherence = intelligence.scan_coverage
    
    # Innovation capacity shows our ability to evolve coherently
    innovation_coherence = intelligence.innovation_capacity
    
    # Weight the factors
    coherence = (health_coherence * 0.3) + 
                (adaptation_alignment * 0.3) + 
                (environmental_coherence * 0.2) + 
                (innovation_coherence * 0.2)
    
    # Ensure result is between 0 and 1
    min(max(coherence, 0.0), 1.0)
  end
  
  defp calculate_strategic_alignment(state) do
    # Measure how well current operations align with strategic direction
    
    # Analyze recent decisions for alignment with values
    values = state.strategic_direction.values
    recent_decisions = Enum.take(state.decisions, 20)
    
    value_alignment = if length(recent_decisions) > 0 do
      # Check how many decisions align with our values
      aligned_count = Enum.count(recent_decisions, fn {_time, _params, decision} ->
        decision_aligns_with_values?(decision, values)
      end)
      aligned_count / length(recent_decisions)
    else
      0.8  # Default when no decisions yet
    end
    
    # Check policy coherence
    policy_count = map_size(state.policies)
    policy_coherence = if policy_count > 0 do
      # More policies generally mean better coverage, but cap at reasonable level
      min(policy_count / 10, 1.0)
    else
      0.5
    end
    
    # Check algedonic balance (pleasure vs pain signals)
    recent_signals = Enum.take(state.algedonic_signals, 50)
    algedonic_balance = calculate_algedonic_balance(recent_signals)
    
    # Current focus alignment - crisis management reduces strategic alignment
    focus_factor = case determine_current_focus(state) do
      :crisis_management -> 0.6
      :viability_restoration -> 0.7
      :steady_state_governance -> 0.9
      :opportunity_exploitation -> 1.0
    end
    
    # Weight the factors
    alignment = (value_alignment * 0.3) + 
                (policy_coherence * 0.2) + 
                (algedonic_balance * 0.2) + 
                (focus_factor * 0.3)
    
    min(max(alignment, 0.0), 1.0)
  end
  
  defp decision_aligns_with_values?(decision, values) do
    # Check if decision reasoning mentions any of our core values
    reasoning = decision[:reasoning] || ""
    Enum.any?(values, fn value ->
      String.contains?(String.downcase(reasoning), String.downcase(to_string(value)))
    end)
  end
  
  defp calculate_algedonic_balance(signals) do
    if length(signals) == 0 do
      0.8  # Neutral default
    else
      pleasure_count = Enum.count(signals, fn {type, _, _, _} -> type == :pleasure end)
      pain_count = Enum.count(signals, fn {type, _, _, _} -> type == :pain end)
      total = pleasure_count + pain_count
      
      if total > 0 do
        # More pleasure signals indicate better alignment
        pleasure_ratio = pleasure_count / total
        # Transform to 0-1 scale where 0.5 ratio = 0.8 alignment
        0.6 + (pleasure_ratio * 0.4)
      else
        0.8
      end
    end
  end
  
  defp calculate_decision_consistency(decisions) do
    # Analyze consistency of recent decisions
    if length(decisions) < 2 do
      1.0  # Perfect consistency with fewer than 2 decisions
    else
      recent_decisions = Enum.take(decisions, 10)
      
      # Extract decision types and outcomes
      decision_patterns = Enum.map(recent_decisions, fn {_time, params, decision} ->
        %{
          type: params["decision_type"] || decision[:decision_type],
          outcome: decision[:selected_option] || decision[:approved],
          confidence: decision[:confidence] || 0.5
        }
      end)
      
      # Group by decision type to check consistency
      grouped = Enum.group_by(decision_patterns, & &1.type)
      
      # Calculate consistency for each decision type
      type_consistencies = Enum.map(grouped, fn {_type, type_decisions} ->
        if length(type_decisions) < 2 do
          1.0
        else
          # Check outcome consistency
          outcomes = Enum.map(type_decisions, & &1.outcome)
          unique_outcomes = Enum.uniq(outcomes)
          outcome_consistency = 1.0 / length(unique_outcomes)
          
          # Check confidence stability
          confidences = Enum.map(type_decisions, & &1.confidence)
          avg_confidence = Enum.sum(confidences) / length(confidences)
          confidence_variance = calculate_variance(confidences, avg_confidence)
          confidence_stability = 1.0 - min(confidence_variance, 1.0)
          
          # Combine factors
          (outcome_consistency * 0.7) + (confidence_stability * 0.3)
        end
      end)
      
      # Overall consistency is the average across all decision types
      if length(type_consistencies) > 0 do
        consistency = Enum.sum(type_consistencies) / length(type_consistencies)
        min(max(consistency, 0.0), 1.0)
      else
        0.85  # Default moderate consistency
      end
    end
  end
  
  defp calculate_variance(values, mean) do
    if length(values) == 0 do
      0.0
    else
      sum_squared_diff = Enum.reduce(values, 0.0, fn value, acc ->
        diff = value - mean
        acc + (diff * diff)
      end)
      sum_squared_diff / length(values)
    end
  end
  
  defp determine_current_focus(state) do
    # Determine what the governance system is currently focused on
    pain_level = state.algedonic_state.pain_level
    pleasure_level = state.algedonic_state.pleasure_level
    arousal_level = state.algedonic_state.arousal_level
    system_health = state.viability_metrics.system_health
    
    cond do
      pain_level > 0.7 || system_health < 0.4 -> :crisis_management
      pain_level > 0.5 || system_health < 0.6 -> :viability_restoration
      pleasure_level > 0.8 && arousal_level > 0.6 -> :opportunity_exploitation
      arousal_level > 0.7 -> :active_optimization
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
    # Confidence based on multiple dynamic factors
    
    # Base confidence from system health
    base_confidence = state.viability_metrics.system_health * 0.5
    
    # Constraint clarity - more constraints actually increase confidence
    constraints = params["constraints"] || %{}
    constraint_count = map_size(constraints)
    constraint_clarity = case constraint_count do
      0 -> 0.0     # No constraints = low confidence
      1 -> 0.1     # Single constraint = some confidence
      2 -> 0.15    # Two constraints = good confidence
      _ -> 0.2     # Multiple constraints = high confidence
    end
    
    # Policy alignment - check if we have relevant policies
    decision_type = params["decision_type"] || "unknown"
    relevant_policies = find_relevant_policies(decision_type, state.policies)
    policy_confidence = min(length(relevant_policies) * 0.1, 0.3)
    
    # Historical decision success for similar decisions
    historical_confidence = calculate_historical_confidence(decision_type, state.decisions)
    
    # Current system stability from algedonic signals
    recent_signals = Enum.take(state.algedonic_signals, 20)
    stability_confidence = calculate_stability_confidence(recent_signals)
    
    # Combine all factors
    total_confidence = base_confidence + constraint_clarity + policy_confidence + 
                      (historical_confidence * 0.15) + (stability_confidence * 0.1)
    
    # Ensure between 0 and 1
    min(max(total_confidence, 0.1), 0.95)
  end
  
  defp find_relevant_policies(decision_type, policies) do
    # Find policies that might apply to this decision type
    Enum.filter(policies, fn {_key, policy} ->
      policy_applies_to_decision?(policy, decision_type)
    end)
  end
  
  defp policy_applies_to_decision?(policy, decision_type) do
    # Check if policy has decision thresholds or types that match
    cond do
      Map.has_key?(policy, :decision_thresholds) -> true
      Map.has_key?(policy, :decision_types) && decision_type in policy.decision_types -> true
      Map.has_key?(policy, :scope) && String.contains?(decision_type, to_string(policy.scope)) -> true
      true -> false
    end
  end
  
  defp calculate_historical_confidence(decision_type, decisions) do
    # Look at past decisions of same type and their outcomes
    similar_decisions = Enum.filter(decisions, fn {_time, params, _decision} ->
      params["decision_type"] == decision_type
    end) |> Enum.take(5)
    
    if length(similar_decisions) == 0 do
      0.5  # No history = neutral confidence
    else
      # Average confidence from past similar decisions
      confidences = Enum.map(similar_decisions, fn {_time, _params, decision} ->
        decision[:confidence] || 0.5
      end)
      Enum.sum(confidences) / length(confidences)
    end
  end
  
  defp calculate_stability_confidence(recent_signals) do
    if length(recent_signals) == 0 do
      0.8  # No signals = assume stable
    else
      # More pain signals = less stability confidence
      pain_count = Enum.count(recent_signals, fn {type, _, _, _} -> type == :pain end)
      pain_ratio = pain_count / length(recent_signals)
      1.0 - (pain_ratio * 0.5)  # Max 50% reduction from pain
    end
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
    
    # Update algedonic state dynamically
    updated_algedonic_state = update_algedonic_state(state.algedonic_state, signal_type, abs(delta), new_algedonic_signals)
    
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
      viability_metrics: updated_metrics,
      algedonic_state: updated_algedonic_state
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
    if state[:amqp_channel] && System.get_env("DISABLE_AMQP") != "true" do
      policy_message = %{
        type: "policy_update",
        policy_type: to_string(policy_type),
        policy_data: policy_data,
        source: "system5_queen",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      payload = Jason.encode!(policy_message)
      
      # Publish to policy fanout exchange with causality tracking
      :ok = CausalityAMQP.publish(
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
  
  # Dynamic algedonic state calculation
  defp update_algedonic_state(current_state, signal_type, intensity, all_signals) do
    # Calculate current pain and pleasure levels from recent signals
    recent_signals = Enum.take(all_signals, 20)
    
    pain_signals = Enum.filter(recent_signals, fn {type, _, _, _} -> type == :pain end)
    pleasure_signals = Enum.filter(recent_signals, fn {type, _, _, _} -> type == :pleasure end)
    
    # Calculate weighted averages with recency bias
    pain_level = calculate_weighted_signal_level(pain_signals)
    pleasure_level = calculate_weighted_signal_level(pleasure_signals)
    
    # Calculate arousal level from signal frequency and intensity
    signal_frequency = length(recent_signals) / 20  # Normalize to 0-1
    avg_intensity = if length(recent_signals) > 0 do
      total_intensity = Enum.sum(Enum.map(recent_signals, fn {_, intensity, _, _} -> intensity end))
      total_intensity / length(recent_signals)
    else
      0.0
    end
    
    arousal_level = min((signal_frequency * 0.6) + (avg_intensity * 0.4), 1.0)
    
    # Determine overall emotional tone
    overall_tone = cond do
      pain_level > 0.7 -> :distressed
      pain_level > 0.5 -> :concerned
      pleasure_level > 0.8 -> :thriving
      pleasure_level > 0.6 -> :satisfied
      arousal_level > 0.7 -> :activated
      arousal_level < 0.2 -> :dormant
      true -> :neutral
    end
    
    %{
      pain_level: pain_level,
      pleasure_level: pleasure_level,
      arousal_level: arousal_level,
      overall_tone: overall_tone
    }
  end
  
  defp calculate_weighted_signal_level(signals) do
    if length(signals) == 0 do
      0.0
    else
      # More recent signals have higher weight
      weighted_sum = Enum.with_index(signals)
      |> Enum.reduce(0.0, fn {{_type, intensity, _context, _time}, index}, acc ->
        # Recent signals (lower index) get higher weight
        weight = 1.0 - (index / length(signals) * 0.5)  # Weight from 1.0 to 0.5
        acc + (intensity * weight)
      end)
      
      # Calculate weighted average
      total_weight = Enum.with_index(signals)
      |> Enum.reduce(0.0, fn {_, index}, acc ->
        weight = 1.0 - (index / length(signals) * 0.5)
        acc + weight
      end)
      
      if total_weight > 0 do
        min(weighted_sum / total_weight, 1.0)
      else
        0.0
      end
    end
  end
  
  # Helper functions for agnostic VSM policy metrics
  
  defp calculate_policy_coherence(policies) do
    # Calculate coherence based on policy count, consistency, and coverage
    policy_count = map_size(policies)
    
    # Base coherence from policy coverage
    coverage_score = min(policy_count / 8, 1.0)  # Assume 8 policies for full coverage
    
    # Check for conflicting policies
    conflict_score = 1.0  # Would be reduced if conflicts detected
    
    # Check policy completeness
    essential_policies = [:governance, :adaptation, :resource_allocation, :identity_preservation]
    present_policies = Map.keys(policies)
    completeness_score = length(Enum.filter(essential_policies, &(&1 in present_policies))) / length(essential_policies)
    
    # Weighted coherence
    coherence = (coverage_score * 0.3) + (conflict_score * 0.4) + (completeness_score * 0.3)
    min(max(coherence, 0.0), 1.0)
  end
  
  defp check_policy_violations(decision, params, policies) do
    violations = []
    
    # Check resource policy violations
    if policies[:resource_allocation] do
      resource_policy = policies[:resource_allocation]
      if decision[:selected_option] =~ "increase" && resource_policy[:resource_limits] do
        # Check if decision would exceed resource limits
        violations = ["potential_resource_limit_exceeded" | violations]
      end
    end
    
    # Check adaptation policy violations
    if policies[:adaptation] && decision[:decision_type] == "adaptation" do
      adaptation_policy = policies[:adaptation]
      if decision[:confidence] < 0.5 && adaptation_policy[:evaluation_criteria] do
        violations = ["low_confidence_adaptation" | violations]
      end
    end
    
    # Check governance policy violations
    if policies[:governance] do
      governance_policy = policies[:governance]
      thresholds = governance_policy[:decision_thresholds] || %{}
      
      # Check if decision confidence meets threshold for decision type
      required_confidence = case params["decision_type"] do
        "critical" -> thresholds[:critical] || 0.9
        "major" -> thresholds[:major] || 0.7
        "minor" -> thresholds[:minor] || 0.5
        _ -> 0.5
      end
      
      if decision[:confidence] < required_confidence do
        violations = ["insufficient_confidence_for_decision_type" | violations]
      end
    end
    
    violations
  end
  
  defp calculate_identity_drift(decision, strategic_direction, history) do
    # Calculate how far the decision deviates from core identity
    values = strategic_direction.values || []
    mission_keywords = String.split(String.downcase(strategic_direction.mission || ""), " ")
    
    # Check if decision aligns with values
    decision_text = String.downcase("#{decision[:reasoning]} #{decision[:selected_option]}")
    
    value_alignment = Enum.count(values, fn value ->
      String.contains?(decision_text, String.downcase(to_string(value)))
    end) / max(length(values), 1)
    
    # Check mission alignment
    mission_alignment = Enum.count(mission_keywords, fn keyword ->
      String.length(keyword) > 3 && String.contains?(decision_text, keyword)
    end) / max(length(mission_keywords), 1)
    
    # Calculate drift (0 = perfect alignment, 1 = complete drift)
    base_drift = 1.0 - ((value_alignment * 0.6) + (mission_alignment * 0.4))
    
    # Consider historical identity markers
    identity_markers = history[:identity_markers] || []
    if length(identity_markers) > 0 do
      # Would compare against historical markers
      base_drift
    else
      base_drift
    end
  end
  
  defp calculate_viability_index(policy_metrics, viability_metrics) do
    # Comprehensive viability calculation
    
    # Policy health factors
    coherence_factor = policy_metrics.coherence_score
    violation_factor = if length(policy_metrics.policy_violations) > 5 do
      0.5  # Many violations reduce viability
    else
      1.0 - (length(policy_metrics.policy_violations) * 0.1)
    end
    identity_factor = 1.0 - policy_metrics.identity_drift
    
    # System health factors
    system_health = viability_metrics.system_health
    adaptation_capacity = viability_metrics.adaptation_capacity
    resource_efficiency = viability_metrics.resource_efficiency
    
    # Decision-making efficiency
    latency_factor = if policy_metrics.decision_latency > 5000 do
      0.5  # Slow decisions reduce viability
    else
      1.0 - (policy_metrics.decision_latency / 10000.0)
    end
    
    # Calculate weighted viability index
    viability = (coherence_factor * 0.15) +
                (violation_factor * 0.15) +
                (identity_factor * 0.1) +
                (system_health * 0.2) +
                (adaptation_capacity * 0.15) +
                (resource_efficiency * 0.15) +
                (latency_factor * 0.1)
    
    min(max(viability, 0.0), 1.0)
  end
end