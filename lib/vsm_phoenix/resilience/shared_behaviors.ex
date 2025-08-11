defmodule VsmPhoenix.Resilience.SharedBehaviors do
  @moduledoc """
  Shared resilience behaviors to eliminate code duplication across god objects.
  
  This module provides consistent error handling, circuit breaking, bulkhead patterns,
  and retry strategies that can be used by all VSM systems to reduce the 142
  duplicate try/rescue blocks identified in the codebase.
  
  CRITICAL: This addresses architectural debt by providing unified resilience
  patterns for control.ex (3,442 lines), intelligence.ex (1,755 lines), 
  queen.ex (1,471 lines), and other god objects.
  """

  require Logger
  
  alias VsmPhoenix.Resilience.{CircuitBreaker, Bulkhead, Retry, Integration}
  alias VsmPhoenix.System5.Components.AlgedonicProcessor

  @doc """
  Execute a function with comprehensive resilience patterns.
  
  Combines circuit breaker, bulkhead, and retry patterns with consistent
  error handling and algedonic feedback.
  
  ## Options
  - `:circuit_breaker` - Circuit breaker name (default: caller module)
  - `:bulkhead_pool` - Bulkhead pool name (optional)
  - `:retry_config` - Retry configuration (default: standard exponential backoff)
  - `:error_handler` - Custom error handling function
  - `:algedonic_context` - Context for algedonic signals
  - `:timeout` - Operation timeout in milliseconds (default: 30_000)
  - `:fallback` - Fallback function when all resilience patterns fail
  
  ## Examples
  
      # Basic usage with circuit breaker and retry
      SharedBehaviors.with_resilience(fn ->
        ExternalAPI.call(params)
      end, circuit_breaker: :external_api)
      
      # Full resilience with bulkhead and custom error handling
      SharedBehaviors.with_resilience(fn ->
        HeavyComputation.process(data)
      end,
        circuit_breaker: :computation,
        bulkhead_pool: :cpu_intensive,
        retry_config: [max_attempts: 3, base_backoff: 1000],
        error_handler: &MyModule.handle_computation_error/2,
        algedonic_context: :computation_failure
      )
  """
  def with_resilience(operation_fn, opts \\ []) do
    circuit_breaker_name = Keyword.get(opts, :circuit_breaker, caller_module())
    bulkhead_pool = Keyword.get(opts, :bulkhead_pool)
    retry_config = Keyword.get(opts, :retry_config, default_retry_config())
    error_handler = Keyword.get(opts, :error_handler, &default_error_handler/2)
    algedonic_context = Keyword.get(opts, :algedonic_context, :operation_failure)
    timeout = Keyword.get(opts, :timeout, 30_000)
    fallback = Keyword.get(opts, :fallback)
    
    # Extract module and operation names from circuit_breaker_name
    {caller_module, operation_name} = case circuit_breaker_name do
      atom when is_atom(atom) -> 
        parts = atom |> Atom.to_string() |> String.split(".")
        {List.first(parts), List.last(parts)}
      str when is_binary(str) -> 
        parts = String.split(str, ".")
        {List.first(parts), List.last(parts)}
      _ -> {"unknown", "operation"}
    end
    
    try do
      result = if bulkhead_pool do
        with_bulkhead_and_circuit_breaker(operation_fn, bulkhead_pool, circuit_breaker_name, retry_config, timeout)
      else
        with_circuit_breaker_and_retry(operation_fn, circuit_breaker_name, retry_config, timeout)
      end
      
      case result do
        {:ok, _} = success ->
          # Emit pleasure signal for successful operation
          AlgedonicProcessor.send_pleasure_signal(0.6, %{
            source: "shared_behaviors",
            context: algedonic_context,
            module: caller_module,
            operation: operation_name
          })
          success
          
        {:error, reason} = error ->
          # Handle error with custom handler if provided
          handled_result = error_handler.(reason, opts)
          
          # Emit pain signal for operation failure
          AlgedonicProcessor.send_pain_signal(0.7, %{
            source: "shared_behaviors",
            context: algedonic_context,
            module: caller_module,
            operation: operation_name,
            error: error
          })
          
          # Try fallback if available
          if fallback do
            Logger.info("🔄 Executing fallback for #{circuit_breaker_name}")
            fallback.()
          else
            handled_result
          end
      end
    rescue
      error ->
        Logger.error("💥 Critical error in resilience wrapper for #{circuit_breaker_name}: #{inspect(error)}")
        
        # Emit critical pain signal
        AlgedonicProcessor.send_pain_signal(0.9, %{
          source: "shared_behaviors",
          context: :critical_resilience_failure,
          module: caller_module,
          operation: operation_name,
          error: error
        })
        
        # Use fallback if available, otherwise return structured error
        if fallback do
          fallback.()
        else
          {:error, {:resilience_wrapper_failure, error}}
        end
    end
  end

  @doc """
  Execute operation with circuit breaker protection only.
  Lighter-weight alternative when bulkhead isolation isn't needed.
  """
  def with_circuit_breaker(operation_fn, circuit_breaker_name, opts \\ []) do
    retry_config = Keyword.get(opts, :retry_config, default_retry_config())
    timeout = Keyword.get(opts, :timeout, 15_000)
    
    with_circuit_breaker_and_retry(operation_fn, circuit_breaker_name, retry_config, timeout)
  end

  @doc """
  Execute operation with bulkhead isolation only.
  Useful for CPU-intensive operations that need resource isolation.
  """
  def with_bulkhead(operation_fn, bulkhead_pool, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    case Bulkhead.with_pool(bulkhead_pool, operation_fn, timeout) do
      {:ok, result} -> {:ok, result}
      {:error, :bulkhead_full} = error ->
        Logger.warning("🚧 Bulkhead #{bulkhead_pool} is full")
        AlgedonicProcessor.send_pain_signal(0.5, %{
          source: "shared_behaviors",
          context: :resource_exhaustion,
          module: Keyword.get(opts, :module, "unknown"),
          bulkhead_pool: bulkhead_pool
        })
        error
      {:error, reason} = error ->
        Logger.error("💥 Bulkhead operation failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Execute operation with intelligent retry only.
  For scenarios where circuit breaking and bulkheads aren't needed.
  """
  def with_retry(operation_fn, opts \\ []) do
    retry_config = Keyword.get(opts, :retry_config, default_retry_config())
    
    Retry.with_retry(operation_fn, retry_config)
  end

  @doc """
  Standardized error logging with context.
  Reduces Logger call duplication across god objects.
  """
  def log_error(error, context, opts \\ []) do
    severity = Keyword.get(opts, :severity, :error)
    module_name = Keyword.get(opts, :module, caller_module())
    operation = Keyword.get(opts, :operation, "unknown")
    
    message = "💥 #{module_name}.#{operation} failed: #{format_error(error)} | Context: #{inspect(context)}"
    
    case severity do
      :debug -> Logger.debug(message)
      :info -> Logger.info(message)
      :warning -> Logger.warning(message)
      :error -> Logger.error(message)
      :critical -> 
        Logger.error(message)
        # Emit critical algedonic signal
        AlgedonicProcessor.send_pain_signal(0.9, %{
          source: "shared_behaviors",
          context: :critical_system_error,
          module: module_name,
          message: message
        })
    end
  end

  @doc """
  Standardized success logging with metrics.
  Reduces Logger call duplication and provides consistent success tracking.
  """
  def log_success(result, context, opts \\ []) do
    module_name = Keyword.get(opts, :module, caller_module())
    operation = Keyword.get(opts, :operation, "unknown")
    duration_ms = Keyword.get(opts, :duration_ms)
    
    base_message = "✅ #{module_name}.#{operation} succeeded"
    
    message = if duration_ms do
      "#{base_message} (#{duration_ms}ms) | Context: #{inspect(context)}"
    else
      "#{base_message} | Context: #{inspect(context)}"
    end
    
    Logger.info(message)
    
    # Emit pleasure signal for successful operation
    AlgedonicProcessor.send_pleasure_signal(0.5, %{
      source: "shared_behaviors",
      context: :operation_success,
      module: module_name,
      operation: operation
    })
    
    result
  end

  @doc """
  Execute operation with comprehensive monitoring and logging.
  Eliminates repetitive try/rescue + logging patterns.
  """
  def monitor_operation(operation_name, operation_fn, opts \\ []) do
    module_name = Keyword.get(opts, :module, caller_module())
    context = Keyword.get(opts, :context, %{})
    
    start_time = System.monotonic_time(:millisecond)
    
    Logger.debug("🚀 Starting #{module_name}.#{operation_name}")
    
    try do
      result = operation_fn.()
      duration_ms = System.monotonic_time(:millisecond) - start_time
      
      log_success(result, context, 
        module: module_name, 
        operation: operation_name, 
        duration_ms: duration_ms
      )
      
      {:ok, result}
    rescue
      error ->
        duration_ms = System.monotonic_time(:millisecond) - start_time
        
        log_error(error, Map.put(context, :duration_ms, duration_ms),
          module: module_name,
          operation: operation_name,
          severity: :error
        )
        
        {:error, error}
    catch
      :exit, reason ->
        log_error({:exit, reason}, context,
          module: module_name,
          operation: operation_name,
          severity: :critical
        )
        
        {:error, {:exit, reason}}
        
      :throw, value ->
        log_error({:throw, value}, context,
          module: module_name,
          operation: operation_name,
          severity: :warning
        )
        
        {:error, {:throw, value}}
    end
  end

  @doc """
  Batch operation with resilience patterns.
  Handles collections of operations with consistent error handling.
  """
  def batch_with_resilience(operations, opts \\ []) when is_list(operations) do
    circuit_breaker_name = Keyword.get(opts, :circuit_breaker, :batch_operations)
    bulkhead_pool = Keyword.get(opts, :bulkhead_pool)
    max_failures = Keyword.get(opts, :max_failures, length(operations))
    continue_on_error = Keyword.get(opts, :continue_on_error, true)
    
    {results, failures} = operations
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {operation_fn, index}, {results_acc, failures_acc} ->
      operation_opts = [
        circuit_breaker: :"#{circuit_breaker_name}_#{index}",
        bulkhead_pool: bulkhead_pool,
        algedonic_context: :batch_operation
      ]
      
      case with_resilience(operation_fn, operation_opts) do
        {:ok, result} ->
          {[{:ok, result, index} | results_acc], failures_acc}
          
        {:error, reason} = error ->
          new_failures = [{:error, reason, index} | failures_acc]
          
          if continue_on_error and length(new_failures) < max_failures do
            {[error | results_acc], new_failures}
          else
            # Stop processing if too many failures
            Logger.error("🚨 Batch operation stopped: #{length(new_failures)} failures reached threshold")
            {[error | results_acc], new_failures}
          end
      end
    end)
    
    success_count = Enum.count(results, fn
      {:ok, _, _} -> true
      _ -> false
    end)
    
    Logger.info("📊 Batch operation completed: #{success_count}/#{length(operations)} successful")
    
    if length(failures) > max_failures do
      {:error, {:batch_failure_threshold_exceeded, %{results: Enum.reverse(results), failures: Enum.reverse(failures)}}}
    else
      {:ok, %{results: Enum.reverse(results), failures: Enum.reverse(failures)}}
    end
  end

  # Private Functions

  defp with_circuit_breaker_and_retry(operation_fn, circuit_breaker_name, retry_config, timeout) do
    Integration.with_llm_circuit_breaker(fn ->
      Retry.with_retry(operation_fn, retry_config)
    end, circuit_breaker: circuit_breaker_name, timeout: timeout)
  end

  defp with_bulkhead_and_circuit_breaker(operation_fn, bulkhead_pool, circuit_breaker_name, retry_config, timeout) do
    Integration.with_llm_circuit_breaker(fn ->
      Bulkhead.with_pool(bulkhead_pool, fn _resource ->
        Retry.with_retry(operation_fn, retry_config)
      end, timeout)
    end, circuit_breaker: circuit_breaker_name, timeout: timeout)
  end

  defp default_retry_config do
    [
      adaptive_retry: true,
      max_attempts: 3,
      base_backoff: 500,
      error_pattern_analysis: true
    ]
  end

  defp default_error_handler(reason, _opts) do
    Logger.warning("🔧 Using default error handler for: #{inspect(reason)}")
    {:error, reason}
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error) when is_atom(error), do: Atom.to_string(error)
  defp format_error({type, details}), do: "#{type}: #{inspect(details)}"
  defp format_error(error), do: inspect(error)

  defp caller_module do
    # Get the calling module from the stack
    case Process.info(self(), :current_stacktrace) do
      {:current_stacktrace, [{_current, _, _, _}, {caller_module, _, _, _} | _]} ->
        caller_module
      _ ->
        __MODULE__
    end
  end
end