defmodule VsmPhoenix.System5.Behaviors.DecisionEngine do
  @moduledoc """
  Behavior for Decision Engine in VSM System 5.
  
  Defines the contract for policy-based decision making to ensure consistent
  implementation across different decision engines.
  
  Follows Interface Segregation Principle by focusing only on decision concerns.
  """
  
  @type decision_params :: map()
  @type decision_result :: map()
  @type decision_confidence :: float()  # 0.0 to 1.0
  @type decision_metrics :: map()
  
  @doc """
  Make a policy-based decision given parameters and constraints.
  
  ## Parameters
  - params: Decision parameters including type, options, constraints
  
  ## Returns
  - {:ok, decision_result} with selected option, reasoning, confidence, etc.
  - {:error, reason} on decision failure
  """
  @callback make_policy_decision(decision_params()) :: {:ok, decision_result()} | {:error, term()}
  
  @doc """
  Evaluate the best option from a set of alternatives.
  
  ## Parameters
  - options: List of available options
  - constraints: Decision constraints and limitations
  - context: Additional context for scoring
  
  ## Returns
  - {:ok, best_option} selected option
  - {:error, reason} if no suitable option found
  """
  @callback evaluate_best_option(list(), map(), map()) :: {:ok, term()} | {:error, term()}
  
  @doc """
  Calculate confidence level for a decision.
  
  ## Parameters
  - params: Decision parameters
  - context: Current system context and state
  
  ## Returns
  - {:ok, confidence} value between 0.0 and 1.0
  - {:error, reason} on calculation failure
  """
  @callback calculate_confidence(decision_params(), map()) :: {:ok, decision_confidence()} | {:error, term()}
  
  @doc """
  Generate reasoning explanation for a decision.
  
  ## Parameters
  - params: Decision parameters
  - selected_option: The chosen option
  - context: Current system state
  
  ## Returns
  - {:ok, reasoning} human-readable explanation
  - {:error, reason} on generation failure
  """
  @callback generate_reasoning(decision_params(), term(), map()) :: {:ok, binary()} | {:error, term()}
  
  @doc """
  Generate implementation steps for a decision.
  
  ## Parameters
  - decision: The decision that was made
  - context: Current system context
  
  ## Returns
  - {:ok, steps} list of implementation steps
  - {:error, reason} on generation failure
  """
  @callback generate_implementation_steps(decision_result(), map()) :: {:ok, list()} | {:error, term()}
  
  @doc """
  Predict expected outcomes from a decision.
  
  ## Parameters
  - decision: The decision that was made
  - context: Current system context
  
  ## Returns
  - {:ok, outcomes} predicted short/medium/long term outcomes
  - {:error, reason} on prediction failure
  """
  @callback predict_outcomes(decision_result(), map()) :: {:ok, map()} | {:error, term()}
  
  @doc """
  Check if a decision violates any policies.
  
  ## Parameters
  - decision: The decision to validate
  - params: Original decision parameters
  - policies: Current system policies
  
  ## Returns
  - {:ok, violations} list of policy violations (empty if none)
  - {:error, reason} on check failure
  """
  @callback check_policy_violations(decision_result(), decision_params(), map()) :: {:ok, list()} | {:error, term()}
  
  @doc """
  Get decision engine performance metrics.
  
  ## Returns
  - {:ok, metrics} decision engine performance data
  - {:error, reason} on failure
  """
  @callback get_decision_metrics() :: {:ok, decision_metrics()} | {:error, term()}
  
  @doc """
  Calculate identity drift based on a decision.
  
  ## Parameters
  - decision: The decision made
  - strategic_direction: System's strategic direction and values
  - history: Historical identity markers and decisions
  
  ## Returns
  - {:ok, drift_score} identity drift value (0.0 = no drift, 1.0 = maximum drift)
  - {:error, reason} on calculation failure
  """
  @callback calculate_identity_drift(decision_result(), map(), map()) :: {:ok, float()} | {:error, term()}
  
  @optional_callbacks [
    evaluate_best_option: 3,
    generate_implementation_steps: 2,
    predict_outcomes: 2,
    check_policy_violations: 3,
    get_decision_metrics: 0,
    calculate_identity_drift: 3
  ]
end