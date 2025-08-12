defmodule VsmPhoenix.System5.Components.StrategicPlanner do
  @moduledoc """
  Strategic Planner Component - Handles strategic planning and decision-making for System 5

  Responsibilities:
  - Maintain strategic direction (mission, vision, values)
  - Make policy decisions based on constraints and context
  - Evaluate and approve adaptation proposals
  - Generate implementation plans and predict outcomes
  - Track decision history and consistency
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System4.Intelligence

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_strategic_direction do
    GenServer.call(__MODULE__, :get_strategic_direction)
  end

  def set_strategic_direction(direction) do
    GenServer.call(__MODULE__, {:set_strategic_direction, direction})
  end

  def make_policy_decision(params) do
    GenServer.call(__MODULE__, {:make_policy_decision, params})
  end

  def approve_adaptation(adaptation_proposal) do
    GenServer.call(__MODULE__, {:approve_adaptation, adaptation_proposal})
  end

  def get_decision_history(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_decision_history, limit})
  end

  def calculate_decision_consistency do
    GenServer.call(__MODULE__, :calculate_decision_consistency)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("StrategicPlanner initializing...")

    state = %{
      strategic_direction: %{
        mission: "Maintain viable system operations with recursive self-governance",
        vision: "Autonomous, resilient, and adaptive system coordination",
        values: ["autonomy", "viability", "resilience", "coherence", "evolution"]
      },
      decisions: [],
      adaptation_policies: default_adaptation_evaluation_policies()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_strategic_direction, _from, state) do
    {:reply, {:ok, state.strategic_direction}, state}
  end

  @impl true
  def handle_call({:set_strategic_direction, direction}, _from, state) do
    Logger.info("StrategicPlanner: Updating strategic direction")

    new_direction = Map.merge(state.strategic_direction, direction)
    new_state = %{state | strategic_direction: new_direction}

    # Broadcast strategic update
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:strategy",
      {:strategic_direction_update, new_direction}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:make_policy_decision, params}, _from, state) do
    Logger.info(
      "StrategicPlanner: Making policy decision for #{inspect(params["decision_type"])}"
    )

    # Evaluate decision based on strategic direction and constraints
    decision = %{
      decision_type: params["decision_type"],
      selected_option: evaluate_best_option(params, state),
      reasoning: generate_reasoning(params, state),
      confidence: calculate_confidence(params, state),
      implementation_steps: generate_implementation_steps(params, state),
      expected_outcomes: predict_outcomes(params, state),
      strategic_alignment: calculate_option_strategic_alignment(params, state),
      timestamp: DateTime.utc_now()
    }

    # Record the decision
    new_decisions = [{DateTime.utc_now(), params, decision} | state.decisions]
    new_state = %{state | decisions: Enum.take(new_decisions, 1000)}

    # Broadcast decision
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:policy",
      {:policy_decision, decision}
    )

    {:reply, {:ok, decision}, new_state}
  end

  @impl true
  def handle_call({:approve_adaptation, proposal}, _from, state) do
    Logger.info("StrategicPlanner: Evaluating adaptation proposal")

    decision = evaluate_adaptation_proposal(proposal, state)

    # Record the adaptation decision
    adaptation_record = {
      DateTime.utc_now(),
      %{decision_type: "adaptation_approval", proposal: proposal},
      decision
    }

    new_decisions = [adaptation_record | state.decisions]
    new_state = %{state | decisions: Enum.take(new_decisions, 1000)}

    if decision.approved do
      # Notify System 4 to implement the adaptation
      Intelligence.implement_adaptation(proposal)

      # Broadcast approval
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:adaptation",
        {:adaptation_approved, proposal, decision}
      )
    end

    {:reply, {:ok, decision}, new_state}
  end

  @impl true
  def handle_call({:get_decision_history, limit}, _from, state) do
    history =
      state.decisions
      |> Enum.take(limit)
      |> Enum.map(fn {timestamp, params, decision} ->
        %{
          timestamp: timestamp,
          type: decision.decision_type || params["decision_type"],
          decision: decision,
          params: params
        }
      end)

    {:reply, {:ok, history}, state}
  end

  @impl true
  def handle_call(:calculate_decision_consistency, _from, state) do
    consistency = do_calculate_decision_consistency(state.decisions)
    {:reply, {:ok, consistency}, state}
  end

  # Private Functions

  defp default_adaptation_evaluation_policies do
    %{
      allowed_adaptations: [:structure, :process, :resource, :coordination],
      adaptation_limits: %{
        max_structural_change: 0.3,
        max_process_change: 0.5,
        max_resource_reallocation: 0.4
      },
      evaluation_criteria: [:viability_impact, :identity_preservation, :cost_benefit],
      approval_thresholds: %{
        auto_approve: 0.9,
        manual_review: 0.7,
        reject: 0.5
      }
    }
  end

  defp evaluate_best_option(params, state) do
    options = params["options"] || []
    constraints = params["constraints"] || %{}

    # Score each option based on multiple criteria
    scored_options =
      Enum.map(options, fn option ->
        score = calculate_option_score(option, constraints, state)
        {option, score}
      end)

    # Select the best option
    {best_option, _score} =
      Enum.max_by(scored_options, fn {_opt, score} -> score end, fn ->
        {"maintain_status_quo", 0.5}
      end)

    best_option
  end

  defp calculate_option_score(option, constraints, state) do
    base_score = 0.5

    # Strategic alignment score
    strategic_score = calculate_strategic_alignment_score(option, state.strategic_direction)

    # Constraint compliance score
    constraint_score = calculate_constraint_compliance(option, constraints)

    # Risk assessment score
    risk_score = assess_option_risk(option)

    # Weighted combination
    weights = %{strategic: 0.4, constraint: 0.35, risk: 0.25}

    base_score * 0.1 +
      strategic_score * weights.strategic +
      constraint_score * weights.constraint +
      risk_score * weights.risk
  end

  defp calculate_strategic_alignment_score(option, direction) do
    # Check if option aligns with values
    value_alignment =
      Enum.reduce(direction.values, 0, fn value, acc ->
        if String.contains?(String.downcase(option), String.downcase(value)),
          do: acc + 0.2,
          else: acc
      end)

    min(1.0, value_alignment)
  end

  defp calculate_constraint_compliance(option, constraints) do
    violations = 0
    total_constraints = map_size(constraints)

    violations =
      if constraints["budget"] && String.contains?(option, "increase") &&
           String.contains?(option, "spend"),
         do: violations + 1,
         else: violations

    violations =
      if constraints["time"] && String.contains?(constraints["time"], "hours") &&
           String.contains?(option, "delay"),
         do: violations + 1,
         else: violations

    if total_constraints == 0, do: 1.0, else: 1.0 - violations / total_constraints
  end

  defp assess_option_risk(option) do
    # Simple risk heuristics
    high_risk_terms = ["major", "complete", "overhaul", "replace", "eliminate"]
    medium_risk_terms = ["modify", "adjust", "change", "update"]
    low_risk_terms = ["maintain", "monitor", "assess", "review"]

    option_lower = String.downcase(option)

    cond do
      Enum.any?(high_risk_terms, &String.contains?(option_lower, &1)) -> 0.3
      Enum.any?(medium_risk_terms, &String.contains?(option_lower, &1)) -> 0.6
      Enum.any?(low_risk_terms, &String.contains?(option_lower, &1)) -> 0.9
      true -> 0.5
    end
  end

  defp generate_reasoning(params, state) do
    constraints = params["constraints"] || %{}
    decision_type = params["decision_type"] || "unspecified"

    constraint_summary = summarize_constraints(constraints)
    strategic_alignment = assess_strategic_fit(params, state.strategic_direction)

    "Based on #{decision_type} requirements and #{constraint_summary}, " <>
      "this decision #{strategic_alignment} while maintaining system viability " <>
      "and operational coherence within acceptable risk parameters."
  end

  defp summarize_constraints(constraints) do
    parts = []

    parts =
      if constraints["budget"], do: ["budget: #{constraints["budget"]}" | parts], else: parts

    parts = if constraints["time"], do: ["time: #{constraints["time"]}" | parts], else: parts

    parts =
      if constraints["resources"],
        do: ["resources: #{constraints["resources"]}" | parts],
        else: parts

    if Enum.empty?(parts), do: "no specific constraints", else: Enum.join(parts, ", ")
  end

  defp assess_strategic_fit(_params, direction) do
    # Simplified assessment
    "aligns with our #{Enum.join(Enum.take(direction.values, 2), " and ")} values"
  end

  defp calculate_confidence(params, state) do
    # Base confidence
    base_confidence = 0.7

    # Adjust based on constraint clarity
    constraint_bonus = min(0.15, map_size(params["constraints"] || %{}) * 0.05)

    # Adjust based on decision history
    history_bonus = if length(state.decisions) > 10, do: 0.1, else: 0.05

    # Adjust based on option count
    option_penalty = if length(params["options"] || []) > 5, do: -0.05, else: 0

    min(0.95, base_confidence + constraint_bonus + history_bonus + option_penalty)
  end

  defp generate_implementation_steps(params, _state) do
    decision_type = params["decision_type"] || "general"

    base_steps = [
      "1. Communicate decision to all affected systems",
      "2. Allocate necessary resources via System 3",
      "3. Coordinate implementation through System 2",
      "4. Monitor environmental response via System 4",
      "5. Track progress through algedonic feedback channels"
    ]

    # Add specific steps based on decision type
    specific_steps =
      case decision_type do
        "resource_allocation" ->
          ["1a. Perform detailed resource audit", "1b. Identify reallocation opportunities"]

        "policy_change" ->
          ["1a. Update policy documentation", "1b. Train affected components"]

        "adaptation" ->
          ["1a. Create adaptation plan", "1b. Set up rollback procedures"]

        _ ->
          []
      end

    Enum.sort(base_steps ++ specific_steps)
  end

  defp predict_outcomes(params, state) do
    context = params["context"] || %{}
    decision_type = params["decision_type"] || "unspecified"

    %{
      short_term: generate_short_term_prediction(decision_type, context),
      medium_term: "System stabilization and optimization within operational parameters",
      long_term: "Enhanced #{Enum.join(Enum.take(state.strategic_direction.values, 2), " and ")}",
      risks: identify_potential_risks(decision_type, params),
      opportunities: identify_opportunities(decision_type, state)
    }
  end

  defp generate_short_term_prediction(decision_type, context) do
    case decision_type do
      "resource_allocation" ->
        "Immediate resource redistribution to address #{context["issue"] || "current needs"}"

      "policy_change" ->
        "Policy implementation across all system levels"

      "adaptation" ->
        "Structural adjustments to improve system response"

      _ ->
        "Execution of decided action with immediate effect"
    end
  end

  defp identify_potential_risks(decision_type, params) do
    base_risks = ["Temporary performance impact", "Resource constraints"]

    specific_risks =
      case decision_type do
        "adaptation" -> ["Integration complexity", "Rollback requirements"]
        "policy_change" -> ["Compliance challenges", "Training needs"]
        _ -> []
      end

    base_risks ++ specific_risks
  end

  defp identify_opportunities(decision_type, state) do
    base_opportunities = ["Process optimization", "Learning opportunity"]

    value_opportunities =
      state.strategic_direction.values
      |> Enum.take(2)
      |> Enum.map(&"Enhanced #{&1}")

    base_opportunities ++ value_opportunities
  end

  defp calculate_option_strategic_alignment(params, state) do
    selected_option = params["selected_option"] || ""
    score = calculate_strategic_alignment_score(selected_option, state.strategic_direction)

    %{
      score: score,
      level:
        cond do
          score > 0.8 -> :high
          score > 0.5 -> :medium
          true -> :low
        end
    }
  end

  defp evaluate_adaptation_proposal(proposal, state) do
    policies = state.adaptation_policies

    # Calculate impact scores
    viability_impact = calculate_viability_impact(proposal)
    identity_preservation = calculate_identity_preservation(proposal)
    cost_benefit = calculate_cost_benefit(proposal)

    # Overall score
    overall_score = (viability_impact + identity_preservation + cost_benefit) / 3

    # Determine approval
    approval_status =
      cond do
        overall_score >= policies.approval_thresholds.auto_approve -> :approved
        overall_score >= policies.approval_thresholds.manual_review -> :conditional
        true -> :rejected
      end

    %{
      approved: approval_status == :approved,
      status: approval_status,
      scores: %{
        viability_impact: viability_impact,
        identity_preservation: identity_preservation,
        cost_benefit: cost_benefit,
        overall: overall_score
      },
      conditions: generate_adaptation_conditions(proposal, approval_status),
      reasoning: generate_adaptation_reasoning(proposal, overall_score),
      review_date: DateTime.add(DateTime.utc_now(), 86400, :second)
    }
  end

  defp calculate_viability_impact(proposal) do
    # Assess how the proposal affects system viability
    impact = Map.get(proposal, :impact, 0.5)
    urgency = Map.get(proposal, :urgency, :medium)

    urgency_modifier =
      case urgency do
        :critical -> 1.2
        :high -> 1.1
        :medium -> 1.0
        :low -> 0.9
      end

    min(1.0, (1.0 - impact) * urgency_modifier)
  end

  defp calculate_identity_preservation(proposal) do
    # Check if proposal preserves system identity
    if Map.get(proposal, :preserves_identity, true), do: 0.9, else: 0.4
  end

  defp calculate_cost_benefit(proposal) do
    # Simple cost-benefit analysis
    expected_benefit = Map.get(proposal, :expected_benefit, 0.5)
    implementation_cost = Map.get(proposal, :cost, 0.5)

    if implementation_cost > 0, do: expected_benefit / implementation_cost, else: expected_benefit
  end

  defp generate_adaptation_conditions(proposal, status) do
    case status do
      :approved ->
        ["Monitor implementation closely", "Maintain rollback capability"]

      :conditional ->
        ["Requires human oversight", "Limited trial period", "Success metrics must be met"]

      :rejected ->
        ["Does not meet minimum criteria", "Reassess with modifications"]
    end
  end

  defp generate_adaptation_reasoning(proposal, score) do
    "Adaptation proposal scored #{Float.round(score, 2)} based on comprehensive evaluation. " <>
      "Impact analysis shows #{assess_impact_level(proposal)} change with " <>
      "#{assess_risk_level(score)} confidence in successful implementation."
  end

  defp assess_impact_level(proposal) do
    impact = Map.get(proposal, :impact, 0.5)

    cond do
      impact < 0.3 -> "minimal"
      impact < 0.6 -> "moderate"
      true -> "significant"
    end
  end

  defp assess_risk_level(score) do
    cond do
      score > 0.8 -> "high"
      score > 0.6 -> "moderate"
      true -> "low"
    end
  end

  defp do_calculate_decision_consistency(decisions) do
    if length(decisions) < 2 do
      %{score: 0.0, assessment: "Insufficient history for analysis"}  # Real: 0 when no decisions
    else
      recent_decisions = Enum.take(decisions, 20)

      # Analyze decision patterns
      consistency_score = analyze_decision_patterns(recent_decisions)

      %{
        score: consistency_score,
        assessment: assess_consistency_level(consistency_score),
        sample_size: length(recent_decisions)
      }
    end
  end

  defp analyze_decision_patterns(decisions) do
    # Simple consistency check based on decision types and outcomes
    decision_types =
      decisions
      |> Enum.map(fn {_ts, _params, decision} -> decision.decision_type end)
      |> Enum.frequencies()

    # More diverse decisions = potentially less consistency
    type_diversity = map_size(decision_types)
    total_decisions = length(decisions)

    if total_decisions > 0 do
      1.0 - type_diversity / total_decisions * 0.5
    else
      1.0
    end
  end

  defp assess_consistency_level(score) do
    cond do
      score > 0.85 -> "Highly consistent decision-making pattern"
      score > 0.7 -> "Moderately consistent with some variation"
      score > 0.5 -> "Variable decision patterns detected"
      true -> "Inconsistent decision-making requiring review"
    end
  end
end
