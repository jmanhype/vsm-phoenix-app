defmodule VsmPhoenix.Resilience.Retry do
  @moduledoc """
  Retry logic with exponential backoff and jitter for VSM Phoenix.

  Features:
  - Exponential backoff with configurable base and multiplier
  - Jitter to prevent thundering herd
  - Maximum retry attempts
  - Customizable retry conditions
  - Telemetry integration for monitoring
  """

  require Logger

  @default_opts [
    max_attempts: 5,
    # Base backoff in ms
    base_backoff: 100,
    # Max backoff in ms
    max_backoff: 30_000,
    backoff_multiplier: 2,
    jitter: true,
    retry_on: [:error, :exit, :timeout],
    # Claude-inspired intelligent retry patterns
    adaptive_retry: true,
    error_pattern_analysis: true,
    failure_context: %{}
  ]

  @doc """
  Execute a function with retry logic

  Options:
  - max_attempts: Maximum number of attempts (default: 5)
  - base_backoff: Initial backoff in milliseconds (default: 100)
  - max_backoff: Maximum backoff in milliseconds (default: 30_000)
  - backoff_multiplier: Multiplier for exponential backoff (default: 2)
  - jitter: Add randomness to prevent thundering herd (default: true)
  - retry_on: List of error types to retry on (default: [:error, :exit, :timeout])
  - on_retry: Callback function called on each retry with (attempt, error, wait_time)
  """
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    opts = Keyword.merge(@default_opts, opts)
    do_retry(fun, 1, opts)
  end

  defp do_retry(fun, attempt, opts) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()

      # Log success after retries
      if attempt > 1 do
        duration = System.monotonic_time(:millisecond) - start_time
        Logger.info("✅ Retry succeeded on attempt #{attempt} after #{duration}ms")
      end

      {:ok, result}
    rescue
      error ->
        handle_error({:error, error}, attempt, fun, opts, start_time)
    catch
      :exit, reason ->
        handle_error({:exit, reason}, attempt, fun, opts, start_time)

      :throw, value ->
        handle_error({:throw, value}, attempt, fun, opts, start_time)
    end
  end

  defp handle_error({error_type, _} = error, attempt, fun, opts, start_time) do
    max_attempts = opts[:max_attempts]
    retry_on = opts[:retry_on]

    # Claude-inspired error analysis for intelligent retry decisions
    updated_opts = if opts[:error_pattern_analysis] do
      analyze_failure_context(opts, error, attempt)
    else
      opts
    end

    # Adaptive max attempts based on error patterns
    effective_max_attempts = if updated_opts[:adaptive_retry] do
      adapt_max_attempts(updated_opts, error_type, attempt)
    else
      max_attempts
    end

    if attempt >= effective_max_attempts do
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.error("❌ Retry failed after #{attempt} attempts (#{duration}ms): #{inspect(error)}")
      {:error, {:max_attempts_reached, error}}
    else
      if should_retry_intelligent?(error_type, retry_on, updated_opts, attempt) do
        wait_time = calculate_intelligent_backoff(attempt, updated_opts, error)

        Logger.warning(
          "⚠️  Intelligent retry #{attempt}/#{effective_max_attempts} failed: #{inspect(error)}. Waiting #{wait_time}ms..."
        )

        # Call on_retry callback if provided
        if on_retry = opts[:on_retry] do
          on_retry.(attempt, error, wait_time)
        end

        # Emit telemetry event with enhanced context
        :telemetry.execute(
          [:vsm_phoenix, :resilience, :retry],
          %{attempt: attempt, wait_time: wait_time, adaptive_decision: true},
          %{error: error, failure_context: updated_opts[:failure_context]}
        )

        Process.sleep(wait_time)
        do_retry(fun, attempt + 1, updated_opts)
      else
        # Non-retryable or intelligently determined as futile
        Logger.info("🧠 Intelligent retry analysis determined error non-retryable: #{inspect(error)}")
        {:error, error}
      end
    end
  end

  defp should_retry?(error_type, retry_on) do
    error_type in retry_on
  end

  defp calculate_backoff(attempt, opts) do
    base = opts[:base_backoff]
    multiplier = opts[:backoff_multiplier]
    max_backoff = opts[:max_backoff]

    # Calculate exponential backoff
    backoff =
      (base * :math.pow(multiplier, attempt - 1))
      |> round()
      |> min(max_backoff)

    # Add jitter if enabled
    if opts[:jitter] do
      add_jitter(backoff)
    else
      backoff
    end
  end

  defp add_jitter(backoff) do
    # Add random jitter between 0% and 20% of backoff time
    jitter_range = round(backoff * 0.2)
    backoff + :rand.uniform(jitter_range)
  end

  # Claude-inspired intelligent retry analysis functions
  defp analyze_failure_context(opts, {error_type, error_details} = _error, attempt) do
    current_context = opts[:failure_context] || %{}
    
    # Track error patterns over time (similar to Claude's self-correction)
    error_signature = create_error_signature(error_type, error_details)
    
    updated_context = current_context
                     |> Map.update(error_signature, %{count: 1, attempts: [attempt]}, fn existing ->
                          %{
                            count: existing.count + 1,
                            attempts: [attempt | existing.attempts] |> Enum.take(10)
                          }
                        end)
                     |> Map.put(:last_error_type, error_type)
                     |> Map.put(:total_attempts, attempt)

    Keyword.put(opts, :failure_context, updated_context)
  end

  defp create_error_signature(error_type, error_details) do
    case {error_type, error_details} do
      {:error, %{__struct__: module}} -> {error_type, module}
      {:exit, :timeout} -> {error_type, :timeout}
      {:exit, :noproc} -> {error_type, :process_down}
      {:error, :timeout} -> {error_type, :timeout}
      _ -> {error_type, :unknown}
    end
  end

  defp should_retry_intelligent?(error_type, retry_on, opts, current_attempt) do
    # Base retry eligibility
    base_should_retry = error_type in retry_on
    
    if not base_should_retry or not opts[:error_pattern_analysis] do
      base_should_retry
    else
      # Claude-style intelligent analysis
      context = opts[:failure_context] || %{}
      
      # Don't retry if same error pattern failed repeatedly in recent attempts
      recent_pattern_failures = context
                               |> Enum.filter(fn {_signature, %{attempts: attempts}} ->
                                    # Check if this error pattern occurred in last 3 attempts
                                    recent_attempts = Enum.take(attempts, 3)
                                    length(recent_attempts) >= 2 and Enum.max(recent_attempts) >= current_attempt - 2
                                  end)
                               |> length()

      # Be more conservative with retry if we see repeated pattern failures
      should_continue = recent_pattern_failures < 2
      
      if not should_continue do
        Logger.info("🧠 Intelligent retry: detected repeated error pattern, skipping retry")
      end
      
      should_continue
    end
  end

  defp adapt_max_attempts(opts, error_type, current_attempt) do
    base_max = opts[:max_attempts]
    context = opts[:failure_context] || %{}
    
    case error_type do
      # Network/timeout errors might recover - give more chances
      :timeout -> min(base_max + 2, 8)
      
      # Process errors might need immediate attention - reduce attempts  
      :exit -> max(base_max - 1, 2)
      
      # If we've seen this specific error pattern fail repeatedly, reduce attempts
      _ ->
        repeated_failures = context
                           |> Enum.count(fn {_sig, %{count: count}} -> count > 3 end)
        
        if repeated_failures > 0 do
          max(base_max - 1, 3)
        else
          base_max
        end
    end
  end

  defp calculate_intelligent_backoff(attempt, opts, {error_type, _error_details}) do
    # Start with standard backoff
    base_backoff = calculate_backoff(attempt, opts)
    
    # Adjust based on error type (Claude's contextual awareness approach)
    case error_type do
      # Network timeouts - longer backoff to let network recover
      :timeout -> round(base_backoff * 1.5)
      
      # Process errors - shorter backoff for faster recovery attempts
      :exit -> round(base_backoff * 0.7)
      
      # Default backoff
      _ -> base_backoff
    end
  end

  @doc """
  Create a retry wrapper function with pre-configured options
  """
  def create_retry_fn(opts \\ []) do
    fn fun ->
      with_retry(fun, opts)
    end
  end
end
