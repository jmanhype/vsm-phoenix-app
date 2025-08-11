defmodule VsmPhoenix.System5.Behaviors.PolicyManager do
  @moduledoc """
  Behavior for Policy Management in VSM System 5.
  
  Defines the contract for policy operations to ensure consistent
  implementation across different policy managers.
  
  Follows Interface Segregation Principle by focusing only on policy concerns.
  """
  
  @type policy_type :: atom()
  @type policy_data :: map()
  @type policy_metrics :: map()
  @type constraints :: map()
  
  @doc """
  Set or update a policy in the system.
  
  ## Parameters
  - policy_type: Type of policy (e.g., :resource_allocation, :viability_threshold)
  - policy_data: Policy configuration and parameters
  
  ## Returns
  - :ok on successful policy update
  - {:error, reason} on failure
  """
  @callback set_policy(policy_type(), policy_data()) :: :ok | {:error, term()}
  
  @doc """
  Get current policy configuration for a specific type.
  
  ## Parameters
  - policy_type: Type of policy to retrieve
  
  ## Returns
  - {:ok, policy_data} if policy exists
  - {:error, :not_found} if policy doesn't exist
  - {:error, reason} on other failures
  """
  @callback get_policy(policy_type()) :: {:ok, policy_data()} | {:error, term()}
  
  @doc """
  Get all current policies.
  
  ## Returns
  - {:ok, policies} map of all current policies
  - {:error, reason} on failure
  """
  @callback get_all_policies() :: {:ok, map()} | {:error, term()}
  
  @doc """
  Synthesize an adaptive policy based on system conditions.
  
  ## Parameters
  - anomaly_data: System anomaly information
  - constraints: Constraints to apply to policy generation
  
  ## Returns
  - {:ok, synthesized_policy} on successful synthesis
  - {:error, reason} on failure
  """
  @callback synthesize_adaptive_policy(map(), constraints()) :: {:ok, policy_data()} | {:error, term()}
  
  @doc """
  Validate a policy against system constraints and rules.
  
  ## Parameters
  - policy_type: Type of policy to validate
  - policy_data: Policy data to validate
  
  ## Returns
  - :ok if policy is valid
  - {:error, violations} if policy violates constraints
  """
  @callback validate_policy(policy_type(), policy_data()) :: :ok | {:error, list()}
  
  @doc """
  Calculate policy coherence across the system.
  
  ## Returns
  - {:ok, coherence_score} float between 0.0 and 1.0
  - {:error, reason} on calculation failure
  """
  @callback calculate_policy_coherence() :: {:ok, float()} | {:error, term()}
  
  @doc """
  Check for policy violations in the system.
  
  ## Parameters
  - current_state: Current system state
  - context: Additional context for violation checking
  
  ## Returns
  - {:ok, violations} list of current violations
  - {:error, reason} on failure
  """
  @callback check_policy_violations(map(), map()) :: {:ok, list()} | {:error, term()}
  
  @doc """
  Get policy performance metrics.
  
  ## Returns
  - {:ok, metrics} policy performance data
  - {:error, reason} on failure
  """
  @callback get_policy_metrics() :: {:ok, policy_metrics()} | {:error, term()}
  
  @doc """
  Apply constraints to a policy configuration.
  
  ## Parameters
  - policy_data: Base policy configuration
  - constraints: Constraints to apply
  
  ## Returns
  - {:ok, constrained_policy} policy with constraints applied
  - {:error, reason} if constraints cannot be applied
  """
  @callback apply_policy_constraints(policy_data(), constraints()) :: {:ok, policy_data()} | {:error, term()}
  
  @doc """
  Propagate policy changes to dependent systems.
  
  ## Parameters
  - policy_type: Type of policy that changed
  - policy_data: New policy configuration
  
  ## Returns
  - :ok on successful propagation
  - {:error, reason} on propagation failure
  """
  @callback propagate_policy_change(policy_type(), policy_data()) :: :ok | {:error, term()}
  
  @optional_callbacks [
    get_policy: 1,
    validate_policy: 2,
    apply_policy_constraints: 2,
    propagate_policy_change: 2
  ]
end