defmodule VsmPhoenix.System5.Components.ViabilityEvaluator do
  @moduledoc """
  Viability Evaluator Component - Monitors and evaluates system viability for System 5

  Responsibilities:
  - Track and calculate viability metrics
  - Evaluate overall system health
  - Monitor adaptation capacity
  - Assess resource efficiency
  - Maintain identity coherence
  - Trigger interventions when viability is threatened
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System2.Coordinator

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def evaluate_viability do
    GenServer.call(__MODULE__, :evaluate_viability)
  end

  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  def update_from_signal(signal_type, intensity) do
    GenServer.cast(__MODULE__, {:update_from_signal, signal_type, intensity})
  end

  def calculate_coherence(intelligence, control, coordination) do
    GenServer.call(__MODULE__, {:calculate_coherence, intelligence, control, coordination})
  end

  def calculate_strategic_alignment(policies, decisions) do
    GenServer.call(__MODULE__, {:calculate_strategic_alignment, policies, decisions})
  end

  def check_intervention_needed do
    GenServer.call(__MODULE__, :check_intervention_needed)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("ViabilityEvaluator initializing...")

    state = %{
      viability_metrics: %{
        system_health: 1.0,
        adaptation_capacity: 1.0,
        resource_efficiency: 1.0,
        identity_coherence: 1.0,
        overall_viability: 1.0
      },
      thresholds: %{
        health_critical: 0.3,
        health_warning: 0.5,
        health_normal: 0.7
      },
      history: [],
      # 30 seconds
      check_interval: 30_000
    }

    # Schedule periodic viability checks
    schedule_viability_check(state.check_interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:evaluate_viability, _from, state) do
    Logger.info("ViabilityEvaluator: Evaluating system viability")

    # Gather metrics from all systems
    intelligence_health = Intelligence.get_system_health()
    control_metrics = Control.get_resource_metrics()
    coordination_status = Coordinator.get_coordination_status()

    # Calculate comprehensive viability
    viability =
      calculate_comprehensive_viability(
        intelligence_health,
        control_metrics,
        coordination_status,
        state.viability_metrics
      )

    # Update state with new metrics
    new_state = %{
      state
      | viability_metrics: viability,
        history: [{DateTime.utc_now(), viability} | state.history] |> Enum.take(100)
    }

    # Check if intervention is needed
    check_and_trigger_intervention(viability, state.thresholds)

    {:reply, {:ok, viability}, new_state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, {:ok, state.viability_metrics}, state}
  end

  @impl true
  def handle_call({:calculate_coherence, intelligence, control, coordination}, _from, state) do
    coherence = do_calculate_coherence(intelligence, control, coordination)
    {:reply, {:ok, coherence}, state}
  end

  @impl true
  def handle_call({:calculate_strategic_alignment, policies, decisions}, _from, state) do
    alignment = do_calculate_strategic_alignment(policies, decisions)
    {:reply, {:ok, alignment}, state}
  end

  @impl true
  def handle_call(:check_intervention_needed, _from, state) do
    intervention_needed = check_intervention_criteria(state.viability_metrics, state.thresholds)
    {:reply, {:ok, intervention_needed}, state}
  end

  @impl true
  def handle_cast({:update_from_signal, signal_type, intensity}, state) do
    Logger.info("ViabilityEvaluator: Updating metrics from #{signal_type} signal (#{intensity})")

    updated_metrics =
      update_viability_from_signal(
        state.viability_metrics,
        signal_type,
        intensity
      )

    new_state = %{state | viability_metrics: updated_metrics}

    # Broadcast updated viability
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:health",
      {:viability_update, updated_metrics}
    )

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_viability, state) do
    # Perform periodic viability check
    {:ok, viability} = evaluate_viability()

    # Schedule next check
    schedule_viability_check(state.check_interval)

    {:noreply, state}
  end

  # Private Functions

  defp calculate_comprehensive_viability(intelligence, control, coordination, current_metrics) do
    # Calculate external viability from system data
    external_health = (intelligence.health + control.efficiency + coordination.effectiveness) / 3
    external_adaptation = intelligence.adaptation_readiness
    external_efficiency = control.resource_utilization
    external_coherence = do_calculate_coherence(intelligence, control, coordination)

    # Blend with current internal metrics (which are affected by algedonic signals)
    %{
      system_health: weighted_average(external_health, current_metrics.system_health, 0.7),
      adaptation_capacity:
        weighted_average(external_adaptation, current_metrics.adaptation_capacity, 0.6),
      resource_efficiency:
        weighted_average(external_efficiency, current_metrics.resource_efficiency, 0.8),
      identity_coherence:
        weighted_average(external_coherence, current_metrics.identity_coherence, 0.5),
      overall_viability:
        calculate_overall_viability(
          external_health,
          external_adaptation,
          external_efficiency,
          external_coherence
        )
    }
  end

  defp weighted_average(external_value, internal_value, external_weight) do
    external_value * external_weight + internal_value * (1 - external_weight)
  end

  defp calculate_overall_viability(health, adaptation, efficiency, coherence) do
    # Weighted calculation of overall viability
    weights = %{
      health: 0.35,
      adaptation: 0.25,
      efficiency: 0.20,
      coherence: 0.20
    }

    health * weights.health +
      adaptation * weights.adaptation +
      efficiency * weights.efficiency +
      coherence * weights.coherence
  end

  defp do_calculate_coherence(intelligence, control, coordination) do
    # Calculate how well all systems are aligned
    alignment_factors = [
      Map.get(intelligence, :strategic_alignment, 0.9),
      Map.get(control, :policy_compliance, 0.85),
      Map.get(coordination, :sync_quality, 0.95)
    ]

    Enum.sum(alignment_factors) / length(alignment_factors)
  end

  defp do_calculate_strategic_alignment(policies, decisions) do
    # Analyze how well decisions align with policies
    if length(decisions) < 2 do
      # Perfect alignment with no decisions
      1.0
    else
      # Simple heuristic: more recent decisions = better alignment
      recency_factor = min(1.0, length(decisions) / 10)
      policy_coverage = min(1.0, map_size(policies) / 5)

      (recency_factor + policy_coverage) / 2
    end
  end

  defp update_viability_from_signal(current_metrics, :pleasure, intensity) do
    # Pleasure signals improve viability metrics
    updated = %{
      current_metrics
      | system_health: min(1.0, current_metrics.system_health + intensity * 0.1),
        adaptation_capacity: min(1.0, current_metrics.adaptation_capacity + intensity * 0.05),
        identity_coherence: min(1.0, current_metrics.identity_coherence + intensity * 0.08)
    }

    # Recalculate overall viability
    Map.put(
      updated,
      :overall_viability,
      calculate_overall_viability(
        updated.system_health,
        updated.adaptation_capacity,
        updated.resource_efficiency,
        updated.identity_coherence
      )
    )
  end

  defp update_viability_from_signal(current_metrics, :pain, intensity) do
    # Pain signals decrease viability metrics
    updated = %{
      current_metrics
      | system_health: max(0.0, current_metrics.system_health - intensity * 0.15),
        adaptation_capacity: max(0.0, current_metrics.adaptation_capacity - intensity * 0.1),
        resource_efficiency: max(0.0, current_metrics.resource_efficiency - intensity * 0.05)
    }

    # Recalculate overall viability
    Map.put(
      updated,
      :overall_viability,
      calculate_overall_viability(
        updated.system_health,
        updated.adaptation_capacity,
        updated.resource_efficiency,
        updated.identity_coherence
      )
    )
  end

  defp check_and_trigger_intervention(viability, thresholds) do
    cond do
      viability.system_health < thresholds.health_critical ->
        Logger.error(
          "ViabilityEvaluator: CRITICAL health level - immediate intervention required!"
        )

        initiate_critical_intervention(viability)

      viability.system_health < thresholds.health_warning ->
        Logger.warning("ViabilityEvaluator: Health below warning threshold")
        initiate_preventive_intervention(viability)

      true ->
        :ok
    end
  end

  defp check_intervention_criteria(metrics, thresholds) do
    %{
      intervention_needed: metrics.system_health < thresholds.health_warning,
      critical: metrics.system_health < thresholds.health_critical,
      reasons: gather_intervention_reasons(metrics, thresholds)
    }
  end

  defp gather_intervention_reasons(metrics, thresholds) do
    reasons = []

    reasons =
      if metrics.system_health < thresholds.health_warning,
        do: ["System health below threshold" | reasons],
        else: reasons

    reasons =
      if metrics.adaptation_capacity < 0.3,
        do: ["Low adaptation capacity" | reasons],
        else: reasons

    reasons =
      if metrics.resource_efficiency < 0.4,
        do: ["Poor resource efficiency" | reasons],
        else: reasons

    reasons =
      if metrics.identity_coherence < 0.5,
        do: ["Identity coherence compromised" | reasons],
        else: reasons

    reasons
  end

  defp initiate_critical_intervention(viability) do
    # Direct System 3 to emergency resource reallocation
    Control.emergency_reallocation(viability)

    # Request immediate adaptation from System 4
    Intelligence.request_adaptation_proposals(%{
      urgency: :critical,
      viability: viability,
      type: :emergency_response
    })

    # Broadcast emergency state
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:emergency",
      {:critical_viability, viability}
    )
  end

  defp initiate_preventive_intervention(viability) do
    # Request adaptation proposals from System 4
    Intelligence.request_adaptation_proposals(%{
      urgency: :high,
      viability: viability,
      type: :preventive_action
    })

    # Notify System 3 for resource optimization
    Control.optimize_resources(viability)
  end

  defp schedule_viability_check(interval) do
    Process.send_after(self(), :check_viability, interval)
  end
end
