defmodule VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior do
  @moduledoc """
  Shared Resilience Behavior - Error Handling Consolidation
  
  Eliminates the 142+ duplicated try/rescue blocks throughout the codebase
  by providing consistent, reusable error handling patterns.
  
  Features:
  - Circuit breaker integration
  - Automatic retry with exponential backoff
  - Graceful degradation
  - Error recovery strategies
  - Performance monitoring of failures
  """

  alias VsmPhoenix.Telemetry.Behaviors.SharedLogging
  
  @default_retry_attempts 3
  @default_backoff_base 100  # milliseconds
  @default_timeout 5000      # milliseconds

  @doc """
  Execute operation with automatic resilience patterns
  """
  def resilient_operation(component, operation, fun, opts \\ []) do
    config = build_resilience_config(opts)
    
    SharedLogging.log_telemetry_event(:debug, component, 
      "Starting resilient operation: #{operation}", %{operation: operation})
    
    case config.strategy do
      :simple -> simple_safe_operation(component, operation, fun)
      :with_retry -> retry_operation(component, operation, fun, config)
      :with_circuit_breaker -> circuit_breaker_operation(component, operation, fun, config)
      :with_timeout -> timeout_operation(component, operation, fun, config)
      :full_resilience -> full_resilience_operation(component, operation, fun, config)
    end
  end

  @doc """
  Simple safe operation with logging
  """
  def simple_safe_operation(component, operation, fun) do
    try do
      result = fun.()
      SharedLogging.log_telemetry_event(:debug, component,
        "Operation #{operation} completed successfully")
      {:ok, result}
    rescue
      error ->
        SharedLogging.log_error_event(component, operation, error)
        {:error, error}
    end
  end

  @doc """
  Operation with automatic retry logic
  """
  def retry_operation(component, operation, fun, config) do
    do_retry(component, operation, fun, config.retry_attempts, 1, config.backoff_base)
  end

  @doc """
  Operation with circuit breaker protection
  """
  def circuit_breaker_operation(component, operation, fun, config) do
    circuit_breaker_name = config.circuit_breaker || :"#{component}_circuit_breaker"
    
    case VsmPhoenix.Resilience.CircuitBreaker.call(circuit_breaker_name, fun) do
      {:ok, result} -> {:ok, result}
      {:error, :circuit_open} -> 
        SharedLogging.log_telemetry_event(:warning, component,
          "Circuit breaker is open for #{operation}")
        {:error, :circuit_open}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Operation with timeout protection
  """
  def timeout_operation(component, operation, fun, config) do
    timeout = config.timeout || @default_timeout
    
    try do
      task = Task.async(fun)
      case Task.await(task, timeout) do
        result -> 
          SharedLogging.log_telemetry_event(:debug, component,
            "Operation #{operation} completed within timeout")
          {:ok, result}
      end
    catch
      :exit, {:timeout, _} ->
        SharedLogging.log_telemetry_event(:warning, component,
          "Operation #{operation} timed out after #{timeout}ms")
        {:error, :timeout}
    rescue
      error ->
        SharedLogging.log_error_event(component, operation, error)
        {:error, error}
    end
  end

  @doc """
  Full resilience with retry, circuit breaker, timeout, and monitoring
  """
  def full_resilience_operation(component, operation, fun, config) do
    start_time = System.monotonic_time(:microsecond)
    
    result = resilient_operation_with_monitoring(component, operation, fun, config)
    
    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time
    
    # Log performance and outcome
    SharedLogging.log_performance_event(component, operation, duration, %{
      result: elem(result, 0),
      resilience_strategy: :full_resilience
    })
    
    result
  end

  @doc """
  Health check operation with automatic degradation
  """
  def health_checked_operation(component, operation, fun, health_check_fun) do
    case health_check_fun.() do
      :healthy -> 
        simple_safe_operation(component, operation, fun)
      
      :degraded ->
        SharedLogging.log_telemetry_event(:warning, component,
          "Operating in degraded mode for #{operation}")
        simple_safe_operation(component, operation, fun)
      
      :critical ->
        SharedLogging.log_telemetry_event(:error, component,
          "System critical, skipping #{operation}")
        {:error, :system_critical}
    end
  end

  @doc """
  Bulk operation with individual error isolation
  """
  def bulk_resilient_operation(component, operation, items, item_processor_fun, opts \\ []) do
    config = build_resilience_config(opts)
    
    results = items
    |> Task.async_stream(fn item ->
      resilient_operation(component, "#{operation}_item", fn -> 
        item_processor_fun.(item) 
      end, strategy: config.strategy)
    end, timeout: config.timeout || @default_timeout)
    |> Enum.to_list()
    
    {successes, failures} = partition_results(results)
    
    SharedLogging.log_telemetry_event(:info, component,
      "Bulk #{operation}: #{length(successes)} successes, #{length(failures)} failures")
    
    %{
      successes: successes,
      failures: failures,
      success_rate: length(successes) / length(items)
    }
  end

  @doc """
  Macro for easy integration into modules
  """
  defmacro __using__(_opts) do
    quote do
      import VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior
      
      # Convenience functions for the importing module
      defp safe_operation(operation, fun) do
        VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior.simple_safe_operation(
          __MODULE__, operation, fun)
      end
      
      defp resilient(operation, fun, opts \\ []) do
        VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior.resilient_operation(
          __MODULE__, operation, fun, opts)
      end
      
      defp with_retry(operation, fun, attempts \\ 3) do
        VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior.retry_operation(
          __MODULE__, operation, fun, %{retry_attempts: attempts, backoff_base: 100})
      end
      
      defp with_timeout(operation, fun, timeout \\ 5000) do
        VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior.timeout_operation(
          __MODULE__, operation, fun, %{timeout: timeout})
      end
      
      defp bulk_safe(operation, items, processor_fun) do
        VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior.bulk_resilient_operation(
          __MODULE__, operation, items, processor_fun)
      end
    end
  end

  # Private Helper Functions

  defp build_resilience_config(opts) do
    %{
      strategy: Keyword.get(opts, :strategy, :simple),
      retry_attempts: Keyword.get(opts, :retry_attempts, @default_retry_attempts),
      backoff_base: Keyword.get(opts, :backoff_base, @default_backoff_base),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      circuit_breaker: Keyword.get(opts, :circuit_breaker)
    }
  end

  defp do_retry(component, operation, fun, 0, attempt, _backoff) do
    SharedLogging.log_telemetry_event(:error, component,
      "Operation #{operation} failed after #{attempt - 1} attempts")
    {:error, :max_retries_exceeded}
  end

  defp do_retry(component, operation, fun, attempts_left, current_attempt, backoff_base) do
    try do
      result = fun.()
      
      if current_attempt > 1 do
        SharedLogging.log_telemetry_event(:info, component,
          "Operation #{operation} succeeded on attempt #{current_attempt}")
      end
      
      {:ok, result}
    rescue
      error ->
        if attempts_left > 1 do
          backoff_time = calculate_backoff(current_attempt, backoff_base)
          
          SharedLogging.log_telemetry_event(:warning, component,
            "Operation #{operation} failed on attempt #{current_attempt}, retrying in #{backoff_time}ms",
            %{attempt: current_attempt, error: inspect(error)})
          
          Process.sleep(backoff_time)
          do_retry(component, operation, fun, attempts_left - 1, current_attempt + 1, backoff_base)
        else
          SharedLogging.log_error_event(component, operation, error,
            %{final_attempt: current_attempt})
          {:error, error}
        end
    end
  end

  defp resilient_operation_with_monitoring(component, operation, fun, config) do
    # Combine multiple resilience strategies
    wrapped_fun = fn ->
      case config.circuit_breaker do
        nil -> fun.()
        cb_name -> 
          case VsmPhoenix.Resilience.CircuitBreaker.call(cb_name, fun) do
            {:ok, result} -> result
            {:error, reason} -> throw({:circuit_breaker_error, reason})
          end
      end
    end
    
    # Apply timeout if configured
    timed_fun = if config.timeout do
      fn -> timeout_operation(component, operation, wrapped_fun, config) end
    else
      wrapped_fun
    end
    
    # Apply retry logic
    if config.retry_attempts > 1 do
      retry_operation(component, operation, timed_fun, config)
    else
      simple_safe_operation(component, operation, timed_fun)
    end
  end

  defp calculate_backoff(attempt, base) do
    # Exponential backoff with jitter
    base_delay = base * :math.pow(2, attempt - 1)
    jitter = :rand.uniform() * base_delay * 0.1
    round(base_delay + jitter)
  end

  defp partition_results(results) do
    Enum.reduce(results, {[], []}, fn
      {:ok, {:ok, result}}, {successes, failures} ->
        {[result | successes], failures}
      {:ok, {:error, error}}, {successes, failures} ->
        {successes, [error | failures]}
      {:error, reason}, {successes, failures} ->
        {successes, [reason | failures]}
    end)
  end
end