defmodule VsmPhoenix.Resilience.RecoveryTemplates do
  @moduledoc """
  Claude Code-inspired resilience-aware prompt templates for system recovery scenarios.
  
  Provides structured templates that help systems recover from failures by following
  Claude's proven patterns of systematic evaluation, context preservation, and 
  intelligent retry strategies.
  """

  require Logger

  @doc """
  Generate a recovery prompt template for circuit breaker failures
  """
  def circuit_breaker_recovery_template(service_name, failure_context, recovery_options \\ []) do
    """
    ## Circuit Breaker Recovery for #{service_name}
    
    **Current Status**: Circuit is OPEN due to repeated failures
    **Failure Context**: #{format_failure_context(failure_context)}
    
    ### Recovery Strategy (Claude-inspired systematic approach):
    
    1. **Assess Current State**:
       - Service health indicators: #{get_health_indicators(service_name)}
       - Recent error patterns: #{analyze_error_patterns(failure_context)}
       - System resource availability: #{check_resource_status()}
    
    2. **Incremental Recovery Steps**:
       - Phase 1: Basic connectivity test (low impact)
       - Phase 2: Limited functionality verification  
       - Phase 3: Gradual load increase with monitoring
    
    3. **Success Criteria**:
       - #{format_success_criteria(recovery_options)}
    
    4. **Rollback Conditions**:
       - #{format_rollback_conditions(recovery_options)}
    
    **Recommended Action**: #{determine_next_action(service_name, failure_context)}
    
    *Generated using Claude-inspired resilience patterns at #{DateTime.utc_now()}*
    """
  end

  @doc """
  Generate a graceful degradation template when services are under stress
  """
  def graceful_degradation_template(service_name, stress_indicators, degradation_options \\ []) do
    """
    ## Graceful Degradation Plan for #{service_name}
    
    **Stress Indicators**: #{format_stress_indicators(stress_indicators)}
    **Current Load**: #{get_current_load(service_name)}
    
    ### Claude-inspired Context Management Approach:
    
    1. **Preserve Core Functionality**:
       - Critical path operations: #{identify_critical_paths(service_name)}
       - Essential data consistency requirements
       - User experience priorities
    
    2. **Progressive Service Reduction**:
       - Level 1: Reduce non-essential features (#{get_non_essential_features(service_name)})
       - Level 2: Increase response caching, reduce real-time updates
       - Level 3: Activate read-only mode for data-heavy operations
       - Level 4: Emergency mode - core functions only
    
    3. **Resource Reallocation**:
       - #{format_resource_reallocation(degradation_options)}
    
    4. **Recovery Monitoring**:
       - Success metrics: #{get_recovery_metrics(service_name)}
       - Auto-scaling triggers: #{get_scaling_conditions()}
    
    **Current Recommendation**: #{determine_degradation_level(stress_indicators)}
    
    *Graceful degradation strategy based on Claude's context window management patterns*
    """
  end

  @doc """
  Generate an error analysis template for intelligent retry decisions
  """
  def error_analysis_template(error_details, retry_history, context \\ %{}) do
    """
    ## Intelligent Error Analysis & Retry Strategy
    
    **Error Details**: #{format_error_details(error_details)}
    **Retry History**: #{format_retry_history(retry_history)}
    **Context**: #{inspect(context, limit: :infinity, printable_limit: :infinity)}
    
    ### Claude-style Error Pattern Analysis:
    
    1. **Error Classification**:
       - Type: #{classify_error_type(error_details)}
       - Severity: #{assess_error_severity(error_details)}
       - Pattern: #{identify_error_pattern(retry_history)}
    
    2. **Success Probability Assessment**:
       - Based on similar patterns: #{calculate_success_probability(retry_history)}
       - Environmental factors: #{assess_environmental_factors(context)}
       - Resource availability: #{check_resource_constraints()}
    
    3. **Adaptive Retry Recommendation**:
       - Recommended strategy: #{recommend_retry_strategy(error_details, retry_history)}
       - Optimal backoff: #{calculate_optimal_backoff(error_details, retry_history)}
       - Max attempts adjustment: #{recommend_max_attempts(retry_history)}
    
    4. **Alternative Approaches**:
       - #{suggest_alternative_approaches(error_details, context)}
    
    **Decision**: #{make_retry_decision(error_details, retry_history, context)}
    
    *Analysis generated using Claude Code's self-correction methodology*
    """
  end

  @doc """
  Generate a workflow reliability template for multi-step operations
  """
  def workflow_reliability_template(workflow_name, steps, current_step, failure_info \\ nil) do
    """
    ## Workflow Reliability Assessment: #{workflow_name}
    
    **Progress**: Step #{current_step} of #{length(steps)}
    **Current Step**: #{Enum.at(steps, current_step - 1, "Unknown")}
    #{if failure_info, do: "**Failure Info**: #{inspect(failure_info)}", else: ""}
    
    ### Claude Code Multi-Section Workflow Approach:
    
    1. **Completed Steps** (✅):
       #{format_completed_steps(steps, current_step)}
    
    2. **Current Step Analysis**:
       - Step: #{Enum.at(steps, current_step - 1, "N/A")}
       - Dependencies: #{analyze_step_dependencies(steps, current_step)}
       - Risk factors: #{assess_step_risks(steps, current_step)}
    
    3. **Remaining Steps** (⏳):
       #{format_remaining_steps(steps, current_step)}
    
    4. **Resilience Reinforcement**:
       - Checkpoint intervals: #{determine_checkpoint_strategy(steps)}
       - Rollback points: #{identify_rollback_points(steps, current_step)}
       - Parallel execution opportunities: #{find_parallel_opportunities(steps)}
    
    5. **Recovery Strategy**:
       #{if failure_info do
         "- Current failure: #{format_failure_recovery_strategy(failure_info)}
         - Resume strategy: #{determine_resume_strategy(workflow_name, current_step, failure_info)}"
       else
         "- Preventive measures: #{suggest_preventive_measures(workflow_name, steps, current_step)}"
       end}
    
    **Recommended Action**: #{recommend_workflow_action(workflow_name, current_step, failure_info)}
    
    *Workflow analysis using Claude's proven reiterated workflow patterns*
    """
  end

  # Private helper functions for template generation

  defp format_failure_context(%{error_patterns: patterns, last_error_time: time}) do
    recent_patterns = patterns
                     |> Enum.map(fn {type, %{count: count}} -> "#{type}: #{count} occurrences" end)
                     |> Enum.join(", ")
    
    "Recent patterns: #{recent_patterns}. Last failure: #{format_timestamp(time)}"
  end
  defp format_failure_context(context), do: inspect(context)

  defp get_health_indicators(service_name) do
    # In real implementation, this would check actual service health
    "Checking #{service_name} health endpoints, process status, and resource utilization"
  end

  defp analyze_error_patterns(%{error_patterns: patterns}) do
    patterns
    |> Enum.map(fn {type, %{count: count}} -> "#{type} (#{count}x)" end)
    |> Enum.join(", ")
  end
  defp analyze_error_patterns(_), do: "No pattern data available"

  defp check_resource_status() do
    "Memory: available, CPU: within limits, Network: responsive"
  end

  defp format_success_criteria(options) do
    Keyword.get(options, :success_criteria, "3 consecutive successful operations")
  end

  defp format_rollback_conditions(options) do
    Keyword.get(options, :rollback_conditions, "2 failures within 30 seconds")
  end

  defp determine_next_action(service_name, _failure_context) do
    "Initiate half-open state testing for #{service_name} with minimal load"
  end

  defp format_stress_indicators(indicators) when is_list(indicators) do
    Enum.join(indicators, ", ")
  end
  defp format_stress_indicators(indicators), do: inspect(indicators)

  defp get_current_load(service_name) do
    "#{service_name} current load metrics would be displayed here"
  end

  defp identify_critical_paths(service_name) do
    "Core #{service_name} operations: authentication, data persistence, critical API endpoints"
  end

  defp get_non_essential_features(service_name) do
    "#{service_name} non-essential: analytics, detailed logging, background jobs"
  end

  defp format_resource_reallocation(options) do
    Keyword.get(options, :reallocation_strategy, "Redirect resources from background tasks to critical operations")
  end

  defp get_recovery_metrics(service_name) do
    "#{service_name} recovery indicators: response time < 200ms, error rate < 1%, availability > 99%"
  end

  defp get_scaling_conditions() do
    "CPU < 70%, Memory < 80%, Response time < 100ms for 5 consecutive minutes"
  end

  defp determine_degradation_level(stress_indicators) do
    if length(stress_indicators) > 3 do
      "Level 2 degradation recommended"
    else
      "Level 1 degradation sufficient"
    end
  end

  defp format_error_details({error_type, error_info}) do
    "Type: #{error_type}, Details: #{inspect(error_info)}"
  end
  defp format_error_details(error), do: inspect(error)

  defp format_retry_history(history) when is_list(history) do
    history
    |> Enum.with_index(1)
    |> Enum.map(fn {error, attempt} -> "Attempt #{attempt}: #{inspect(error)}" end)
    |> Enum.join("\n       ")
  end
  defp format_retry_history(history), do: inspect(history)

  defp classify_error_type({:timeout, _}), do: "Network/Timeout"
  defp classify_error_type({:exit, _}), do: "Process/System"
  defp classify_error_type({:error, _}), do: "Application/Logic"
  defp classify_error_type(_), do: "Unknown"

  defp assess_error_severity({:exit, :kill}), do: "Critical"
  defp assess_error_severity({:timeout, _}), do: "Medium"
  defp assess_error_severity(_), do: "Low-Medium"

  defp identify_error_pattern(history) when length(history) > 2 do
    "Recurring pattern detected"
  end
  defp identify_error_pattern(_), do: "Insufficient data"

  defp calculate_success_probability(history) do
    if length(history) > 5, do: "Low (15%)", else: "Medium (60%)"
  end

  defp assess_environmental_factors(%{load: :high}), do: "High system load detected"
  defp assess_environmental_factors(_), do: "Normal environmental conditions"

  defp check_resource_constraints() do
    "Resources available for retry attempts"
  end

  defp recommend_retry_strategy({:timeout, _}, _history), do: "Exponential backoff with longer delays"
  defp recommend_retry_strategy({:exit, _}, _history), do: "Immediate retry with process restart"
  defp recommend_retry_strategy(_, _), do: "Standard exponential backoff"

  defp calculate_optimal_backoff({:timeout, _}, _), do: "1.5x standard backoff"
  defp calculate_optimal_backoff({:exit, _}, _), do: "0.7x standard backoff"
  defp calculate_optimal_backoff(_, _), do: "Standard backoff calculation"

  defp recommend_max_attempts(history) when length(history) > 3, do: "Reduce to 3 attempts"
  defp recommend_max_attempts(_), do: "Standard 5 attempts"

  defp suggest_alternative_approaches({:timeout, _}, _context) do
    "Consider circuit breaker, async processing, or caching"
  end
  defp suggest_alternative_approaches(_, _), do: "Evaluate alternative service endpoints or fallback mechanisms"

  defp make_retry_decision(_error, history, _context) when length(history) > 5 do
    "🛑 STOP - Pattern indicates systemic issue requiring manual intervention"
  end
  defp make_retry_decision({:timeout, _}, _, %{load: :high}) do
    "⏸️  PAUSE - Wait for system load to decrease before retrying"
  end
  defp make_retry_decision(_, _, _) do
    "🔄 RETRY - Conditions favorable for retry attempt"
  end

  defp format_completed_steps(steps, current_step) do
    steps
    |> Enum.with_index(1)
    |> Enum.take(current_step - 1)
    |> Enum.map(fn {step, idx} -> "       #{idx}. #{step}" end)
    |> Enum.join("\n")
  end

  defp analyze_step_dependencies(_steps, current_step) do
    "Step #{current_step} dependencies: previous steps completed successfully"
  end

  defp assess_step_risks(_steps, current_step) do
    "Step #{current_step} risk assessment: standard operational risk"
  end

  defp format_remaining_steps(steps, current_step) do
    steps
    |> Enum.with_index(1)
    |> Enum.drop(current_step)
    |> Enum.map(fn {step, idx} -> "       #{idx}. #{step}" end)
    |> Enum.join("\n")
  end

  defp determine_checkpoint_strategy(steps) when length(steps) > 5 do
    "Every 2 steps with state persistence"
  end
  defp determine_checkpoint_strategy(_), do: "Every step completion"

  defp identify_rollback_points(_steps, current_step) do
    "Can rollback to step #{max(1, current_step - 1)}"
  end

  defp find_parallel_opportunities(steps) when length(steps) > 3 do
    "Steps #{length(steps) - 1} and #{length(steps)} can run in parallel"
  end
  defp find_parallel_opportunities(_), do: "No parallel execution opportunities"

  defp format_failure_recovery_strategy(failure_info) do
    "Address #{inspect(failure_info)} through targeted retry with exponential backoff"
  end

  defp determine_resume_strategy(workflow_name, current_step, _failure_info) do
    "Resume #{workflow_name} from step #{current_step} after addressing failure conditions"
  end

  defp suggest_preventive_measures(workflow_name, _steps, current_step) do
    "For #{workflow_name} step #{current_step}: add validation checkpoints, resource monitoring"
  end

  defp recommend_workflow_action(_workflow_name, _current_step, nil) do
    "Continue to next step with enhanced monitoring"
  end
  defp recommend_workflow_action(workflow_name, current_step, _failure_info) do
    "Pause #{workflow_name}, address failure, then resume from step #{current_step}"
  end

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
    |> DateTime.to_iso8601()
  end
  defp format_timestamp(timestamp), do: inspect(timestamp)
end