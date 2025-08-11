defmodule VsmPhoenix.System5.Decision.DecisionEngine do
  @moduledoc """
  Decision Engine - Handles all policy-based decision making for System 5.
  
  Extracted from Queen god object to follow Single Responsibility Principle.
  Responsible ONLY for:
  - Policy-based decision making and evaluation
  - Option scoring and selection
  - Decision confidence calculation
  - Reasoning generation and explanation
  - Implementation step planning
  - Outcome prediction and analysis
  """
  
  use GenServer
  require Logger
  
  @behaviour VsmPhoenix.System5.Behaviors.DecisionEngine
  
  alias Phoenix.PubSub
  
  @name __MODULE__
  @decision_history_limit 100
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def make_policy_decision(params) do
    GenServer.call(@name, {:make_policy_decision, params})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def evaluate_best_option(options, constraints, context) do
    GenServer.call(@name, {:evaluate_best_option, options, constraints, context})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def calculate_confidence(params, context) do
    GenServer.call(@name, {:calculate_confidence, params, context})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def generate_reasoning(params, selected_option, context) do
    GenServer.call(@name, {:generate_reasoning, params, selected_option, context})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def generate_implementation_steps(decision, context) do
    GenServer.call(@name, {:generate_implementation_steps, decision, context})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def predict_outcomes(decision, context) do
    GenServer.call(@name, {:predict_outcomes, decision, context})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def check_policy_violations(decision, params, policies) do
    GenServer.call(@name, {:check_policy_violations, decision, params, policies})
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def get_decision_metrics do
    GenServer.call(@name, :get_decision_metrics)
  rescue
    e -> {:error, e}
  end
  
  @impl VsmPhoenix.System5.Behaviors.DecisionEngine
  def calculate_identity_drift(decision, strategic_direction, history) do
    GenServer.call(@name, {:calculate_identity_drift, decision, strategic_direction, history})
  rescue
    e -> {:error, e}
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      decision_history: [],
      decision_metrics: initialize_decision_metrics(),
      policy_cache: nil,
      confidence_cache: %{}
    }
    
    Logger.info("🎯 Decision Engine initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:make_policy_decision, params}, _from, state) do
    decision_start = :erlang.system_time(:millisecond)
    
    try do
      Logger.info("🎯 Decision Engine: Making policy decision for #{inspect(params["decision_type"])}")
      
      # Get current policies from PolicyManager
      {:ok, policies} = VsmPhoenix.System5.Policy.PolicyManager.get_all_policies()
      
      # Evaluate the decision based on current policies and constraints
      decision = %{
        decision_type: params["decision_type"],
        selected_option: evaluate_best_option_internal(params, policies, state),
        reasoning: generate_reasoning_internal(params, policies, state),
        confidence: calculate_confidence_internal(params, policies, state),
        implementation_steps: generate_implementation_steps_internal(params, policies, state),
        expected_outcomes: predict_outcomes_internal(params, policies, state)
      }
      
      # Calculate decision latency
      decision_end = :erlang.system_time(:millisecond)
      latency_ms = decision_end - decision_start
      
      # Update decision metrics
      updated_metrics = update_decision_metrics(state.decision_metrics, :decision_made, latency_ms)
      
      # Check if decision violates any policies
      violations = check_policy_violations_internal(decision, params, policies)
      
      # Update violations metrics if any found
      updated_metrics = if length(violations) > 0 do
        update_decision_metrics(updated_metrics, :violations_detected, length(violations))
      else
        updated_metrics
      end
      
      # Record the decision
      decision_record = %{
        timestamp: System.system_time(:millisecond),
        params: params,
        decision: decision,
        latency_ms: latency_ms,
        violations: violations
      }
      
      new_decision_history = [decision_record | state.decision_history] 
                            |> Enum.take(@decision_history_limit)
      
      new_state = %{state | 
        decision_history: new_decision_history,
        decision_metrics: updated_metrics
      }
      
      # Broadcast decision to relevant systems
      PubSub.broadcast(VsmPhoenix.PubSub, "vsm:policy", {:policy_decision, decision})
      
      Logger.debug("🎯 Decision completed in #{latency_ms}ms with confidence #{decision.confidence}")
      {:reply, {:ok, decision}, new_state}
      
    rescue
      e ->
        Logger.error("🎯 Decision making failed: #{inspect(e)}")
        {:reply, {:error, {:decision_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:evaluate_best_option, options, constraints, context}, _from, state) do
    try do
      best_option = evaluate_best_option_with_context(options, constraints, context)
      {:reply, {:ok, best_option}, state}
    rescue
      e ->
        {:reply, {:error, {:evaluation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:calculate_confidence, params, context}, _from, state) do
    try do
      confidence = calculate_confidence_with_context(params, context, state)
      {:reply, {:ok, confidence}, state}
    rescue
      e ->
        {:reply, {:error, {:confidence_calculation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:generate_reasoning, params, selected_option, context}, _from, state) do
    try do
      reasoning = generate_reasoning_with_context(params, selected_option, context)
      {:reply, {:ok, reasoning}, state}
    rescue
      e ->
        {:reply, {:error, {:reasoning_generation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:generate_implementation_steps, decision, context}, _from, state) do
    try do
      steps = generate_implementation_steps_with_context(decision, context)
      {:reply, {:ok, steps}, state}
    rescue
      e ->
        {:reply, {:error, {:step_generation_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:predict_outcomes, decision, context}, _from, state) do
    try do
      outcomes = predict_outcomes_with_context(decision, context)
      {:reply, {:ok, outcomes}, state}
    rescue
      e ->
        {:reply, {:error, {:prediction_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call({:check_policy_violations, decision, params, policies}, _from, state) do
    try do
      violations = check_policy_violations_internal(decision, params, policies)
      {:reply, {:ok, violations}, state}
    rescue
      e ->
        {:reply, {:error, {:violation_check_failed, e}}, state}
    end
  end
  
  @impl true
  def handle_call(:get_decision_metrics, _from, state) do
    enhanced_metrics = enhance_decision_metrics(state.decision_metrics, state)
    {:reply, {:ok, enhanced_metrics}, state}
  end
  
  @impl true
  def handle_call({:calculate_identity_drift, decision, strategic_direction, history}, _from, state) do
    try do
      drift = calculate_identity_drift_internal(decision, strategic_direction, history)
      {:reply, {:ok, drift}, state}
    rescue
      e ->
        {:reply, {:error, {:identity_drift_calculation_failed, e}}, state}
    end
  end
  
  # Private Functions
  
  defp initialize_decision_metrics do
    %{
      decisions_made: 0,
      total_latency_ms: 0,
      average_latency_ms: 0.0,
      violations_detected: 0,
      confidence_sum: 0.0,
      average_confidence: 0.0,
      decisions_by_type: %{},
      last_activity: System.system_time(:millisecond),
      uptime: System.system_time(:millisecond)
    }
  end
  
  defp update_decision_metrics(metrics, operation, value \\ 1) do
    updated_metrics = case operation do
      :decision_made ->
        new_decisions = metrics.decisions_made + 1
        %{metrics | 
          decisions_made: new_decisions,
          total_latency_ms: metrics.total_latency_ms + value,
          average_latency_ms: (metrics.total_latency_ms + value) / new_decisions
        }
      :violations_detected ->
        %{metrics | violations_detected: metrics.violations_detected + value}
      :confidence_recorded ->
        new_decisions = metrics.decisions_made
        new_confidence_sum = metrics.confidence_sum + value
        %{metrics | 
          confidence_sum: new_confidence_sum,
          average_confidence: (if new_decisions > 0, do: new_confidence_sum / new_decisions, else: 0.0)
        }
    end
    
    %{updated_metrics | last_activity: System.system_time(:millisecond)}
  end
  
  defp evaluate_best_option_internal(params, policies, state) do
    options = params["options"] || []
    constraints = params["constraints"] || %{}
    
    # Simple scoring based on constraints and policies
    scored_options = Enum.map(options, fn option ->
      score = calculate_option_score(option, constraints, policies, state)
      {option, score}
    end)
    
    {best_option, _score} = Enum.max_by(scored_options, fn {_opt, score} -> score end, 
                                       fn -> {"maintain_status_quo", 0.5} end)
    best_option
  end
  
  defp evaluate_best_option_with_context(options, constraints, context) do
    # Enhanced option evaluation with context
    scored_options = Enum.map(options, fn option ->
      score = calculate_option_score_with_context(option, constraints, context)
      {option, score}
    end)
    
    {best_option, _score} = Enum.max_by(scored_options, fn {_opt, score} -> score end, 
                                       fn -> {"default_option", 0.5} end)
    best_option
  end
  
  defp calculate_option_score(option, constraints, policies, _state) do
    base_score = 0.5
    
    # Adjust score based on budget constraint
    budget_score = if constraints["budget"] && String.contains?(option, "increase"), do: -0.2, else: 0.1
    
    # Adjust based on time constraint  
    time_score = if constraints["time"] && String.contains?(constraints["time"], "hours") && String.contains?(option, "delay"), do: -0.3, else: 0.1
    
    # Policy alignment score
    policy_score = calculate_policy_alignment_score(option, policies)
    
    base_score + budget_score + time_score + policy_score
  end
  
  defp calculate_option_score_with_context(option, constraints, context) do
    base_score = 0.5
    
    # Budget constraints
    budget_impact = case {Map.get(constraints, "budget"), option} do
      {budget, opt} when is_binary(budget) -> 
        if String.contains?(opt, "increase"), do: -0.2, else: 0.1
      {_, _} -> 0.1
    end
    
    # Time constraints
    time_impact = case {Map.get(constraints, "time"), option} do
      {time, opt} when is_binary(time) -> 
        if String.contains?(time, "hours") and String.contains?(opt, "delay"), do: -0.3, else: 0.1
      {_, _} -> 0.1
    end
    
    # Context-based scoring
    context_impact = case Map.get(context, :priority) do
      :high -> if String.contains?(option, "urgent"), do: 0.3, else: 0.0
      :low -> if String.contains?(option, "delay"), do: 0.2, else: 0.0
      _ -> 0.0
    end
    
    base_score + budget_impact + time_impact + context_impact
  end
  
  defp calculate_policy_alignment_score(option, policies) do
    # Check how well the option aligns with current policies
    resource_policy = Map.get(policies, :resource_allocation, %{})
    governance_policy = Map.get(policies, :governance, %{})
    
    score = 0.0
    
    # Resource policy alignment
    score = if String.contains?(option, "resource") && Map.has_key?(resource_policy, :allocation_priorities) do
      score + 0.1
    else
      score
    end
    
    # Governance policy alignment
    score = if String.contains?(option, "customer") && Map.get(governance_policy, :customer_focus, false) do
      score + 0.2
    else
      score
    end
    
    score
  end
  
  defp generate_reasoning_internal(params, policies, _state) do
    constraints = params["constraints"] || %{}
    budget_info = if constraints["budget"], do: "budget: #{constraints["budget"]}", else: "no budget constraint"
    time_info = if constraints["time"], do: "time: #{constraints["time"]}", else: "no time constraint"
    
    policy_count = map_size(policies)
    
    "Based on current policies (#{policy_count} active) and constraints (#{budget_info}, #{time_info}), " <>
    "this option best balances operational objectives with policy compliance while maintaining system viability."
  end
  
  defp generate_reasoning_with_context(params, selected_option, context) do
    constraints = params["constraints"] || %{}
    decision_type = params["decision_type"] || "unknown"
    
    constraint_summary = summarize_constraints(constraints)
    context_summary = summarize_context(context)
    
    "Decision: #{selected_option} for #{decision_type}. " <>
    "Reasoning: #{constraint_summary}#{context_summary}" <>
    "This choice optimizes for system viability while respecting operational constraints."
  end
  
  defp summarize_constraints(constraints) when map_size(constraints) == 0, do: "No constraints specified. "
  defp summarize_constraints(constraints) do
    constraint_list = Enum.map(constraints, fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")
    "Constraints considered: #{constraint_list}. "
  end
  
  defp summarize_context(context) when map_size(context) == 0, do: ""
  defp summarize_context(context) do
    priority = Map.get(context, :priority, :normal)
    "Priority level: #{priority}. "
  end
  
  defp calculate_confidence_internal(params, policies, state) do
    calculate_confidence_with_context(params, %{policies: policies}, state)
  end
  
  defp calculate_confidence_with_context(params, context, state) do
    policies = Map.get(context, :policies, %{})
    
    # Base confidence from system stability
    base_confidence = 0.5
    
    # Constraint clarity - more constraints increase confidence
    constraints = params["constraints"] || %{}
    constraint_count = map_size(constraints)
    constraint_clarity = case constraint_count do
      0 -> 0.0
      1 -> 0.1
      2 -> 0.15
      _ -> 0.2
    end
    
    # Policy alignment - check if we have relevant policies
    decision_type = params["decision_type"] || "unknown"
    relevant_policies = find_relevant_policies(decision_type, policies)
    policy_confidence = min(length(relevant_policies) * 0.1, 0.3)
    
    # Historical decision success
    historical_confidence = calculate_historical_confidence(decision_type, state.decision_history)
    
    # Combine all factors
    total_confidence = base_confidence + constraint_clarity + policy_confidence + 
                      (historical_confidence * 0.2)
    
    # Ensure between 0.1 and 0.95
    min(max(total_confidence, 0.1), 0.95)
  end
  
  defp find_relevant_policies(decision_type, policies) do
    Enum.filter(policies, fn {_key, policy} ->
      policy_applies_to_decision?(policy, decision_type)
    end)
  end
  
  defp policy_applies_to_decision?(policy, decision_type) do
    cond do
      Map.has_key?(policy, :decision_thresholds) -> true
      Map.has_key?(policy, :decision_types) && decision_type in policy.decision_types -> true
      Map.has_key?(policy, :scope) && String.contains?(decision_type, to_string(policy.scope)) -> true
      true -> false
    end
  end
  
  defp calculate_historical_confidence(decision_type, decision_history) do
    similar_decisions = Enum.filter(decision_history, fn record ->
      get_in(record, [:params, "decision_type"]) == decision_type
    end) |> Enum.take(5)
    
    if length(similar_decisions) == 0 do
      0.5  # No history = neutral confidence
    else
      # Average confidence from past similar decisions
      confidences = Enum.map(similar_decisions, fn record ->
        get_in(record, [:decision, :confidence]) || 0.5
      end)
      Enum.sum(confidences) / length(confidences)
    end
  end
  
  defp generate_implementation_steps_internal(_params, _policies, _state) do
    [
      "1. Notify System 3 (Control) to allocate resources",
      "2. Coordinate with System 2 to prevent oscillations", 
      "3. System 1 contexts to execute operational changes",
      "4. System 4 to monitor environmental response",
      "5. Continuous viability assessment via algedonic channels"
    ]
  end
  
  defp generate_implementation_steps_with_context(decision, context) do
    base_steps = [
      "1. Validate decision parameters and constraints",
      "2. Notify relevant systems of pending changes",
      "3. Execute decision through appropriate system channels",
      "4. Monitor implementation progress and outcomes",
      "5. Assess impact and adjust if necessary"
    ]
    
    # Customize steps based on decision type or context
    decision_type = decision[:decision_type] || "unknown"
    case decision_type do
      "resource_allocation" -> customize_resource_steps(base_steps)
      "adaptation" -> customize_adaptation_steps(base_steps)
      _ -> base_steps
    end
  end
  
  defp customize_resource_steps(base_steps) do
    [
      "1. Assess current resource utilization and availability",
      "2. Calculate resource reallocation requirements",
      "3. Notify System 3 (Control) for resource coordination"
    ] ++ Enum.drop(base_steps, 3)
  end
  
  defp customize_adaptation_steps(base_steps) do
    [
      "1. Validate adaptation proposal against policies",
      "2. Coordinate with System 4 (Intelligence) for implementation",
      "3. Monitor adaptation impact on system viability"
    ] ++ Enum.drop(base_steps, 3)
  end
  
  defp predict_outcomes_internal(params, _policies, _state) do
    predict_outcomes_with_context(params, %{})
  end
  
  defp predict_outcomes_with_context(params, context) do
    decision_type = params["decision_type"] || "unknown"
    
    context_desc = case params["context"] do
      ctx when is_map(ctx) -> inspect(ctx)
      ctx when is_binary(ctx) -> ctx
      _ -> "unspecified context"
    end
    
    base_outcomes = %{
      short_term: "Immediate response to #{decision_type} in #{context_desc}",
      medium_term: "Stabilized operations within defined constraints",
      long_term: "Enhanced system resilience and adaptability",
      risks: ["Implementation complexity", "Resource strain", "Potential coordination issues"],
      opportunities: ["Process optimization", "Improved system performance", "Enhanced viability"]
    }
    
    # Customize outcomes based on decision type
    case decision_type do
      "resource_allocation" -> customize_resource_outcomes(base_outcomes)
      "adaptation" -> customize_adaptation_outcomes(base_outcomes)
      "policy_update" -> customize_policy_outcomes(base_outcomes)
      _ -> base_outcomes
    end
  end
  
  defp customize_resource_outcomes(base_outcomes) do
    %{base_outcomes |
      short_term: "Resource reallocation and utilization optimization",
      risks: ["Resource contention", "Temporary performance impact"],
      opportunities: ["Improved efficiency", "Better resource utilization"]
    }
  end
  
  defp customize_adaptation_outcomes(base_outcomes) do
    %{base_outcomes |
      short_term: "System adaptation and structural changes",
      risks: ["Adaptation failure", "System instability"],
      opportunities: ["Enhanced capabilities", "Better environmental fit"]
    }
  end
  
  defp customize_policy_outcomes(base_outcomes) do
    %{base_outcomes |
      short_term: "Policy propagation and system alignment",
      risks: ["Policy conflicts", "Implementation inconsistency"],
      opportunities: ["Better governance", "Improved coherence"]
    }
  end
  
  defp check_policy_violations_internal(decision, params, policies) do
    violations = []
    
    # Check resource policy violations
    violations = check_resource_violations(decision, params, policies, violations)
    
    # Check adaptation policy violations
    violations = check_adaptation_violations(decision, params, policies, violations)
    
    # Check governance policy violations
    violations = check_governance_violations(decision, params, policies, violations)
    
    violations
  end
  
  defp check_resource_violations(decision, _params, policies, violations) do
    if policies[:resource_allocation] do
      resource_policy = policies[:resource_allocation]
      if String.contains?(decision[:selected_option] || "", "increase") && resource_policy[:resource_limits] do
        ["potential_resource_limit_exceeded" | violations]
      else
        violations
      end
    else
      violations
    end
  end
  
  defp check_adaptation_violations(decision, params, policies, violations) do
    if policies[:adaptation] && params["decision_type"] == "adaptation" do
      adaptation_policy = policies[:adaptation]
      if decision[:confidence] < 0.5 && adaptation_policy[:evaluation_criteria] do
        ["low_confidence_adaptation" | violations]
      else
        violations
      end
    else
      violations
    end
  end
  
  defp check_governance_violations(decision, params, policies, violations) do
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
        ["insufficient_confidence_for_decision_type" | violations]
      else
        violations
      end
    else
      violations
    end
  end
  
  defp calculate_identity_drift_internal(decision, strategic_direction, history) do
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
      # Would compare against historical markers in a real implementation
      base_drift
    else
      base_drift
    end
  end
  
  defp enhance_decision_metrics(metrics, state) do
    uptime = System.system_time(:millisecond) - metrics.uptime
    
    Map.merge(metrics, %{
      uptime_ms: uptime,
      decisions_in_history: length(state.decision_history),
      recent_decision_types: get_recent_decision_types(state.decision_history),
      violation_rate: (if metrics.decisions_made > 0, 
                        do: metrics.violations_detected / metrics.decisions_made, 
                        else: 0.0),
      decision_frequency: (if uptime > 0, 
                           do: metrics.decisions_made / (uptime / 1000), 
                           else: 0.0)
    })
  end
  
  defp get_recent_decision_types(decision_history) do
    decision_history
    |> Enum.take(10)
    |> Enum.map(fn record -> get_in(record, [:params, "decision_type"]) end)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
  end
end