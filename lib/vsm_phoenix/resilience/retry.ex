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
    retry_on: [:error, :exit, :timeout]
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

    if attempt >= max_attempts do
      duration = System.monotonic_time(:millisecond) - start_time
      Logger.error("❌ Retry failed after #{attempt} attempts (#{duration}ms): #{inspect(error)}")
      {:error, {:max_attempts_reached, error}}
    else
      if should_retry?(error_type, retry_on) do
        wait_time = calculate_backoff(attempt, opts)

        Logger.warning(
          "⚠️  Retry attempt #{attempt}/#{max_attempts} failed: #{inspect(error)}. Waiting #{wait_time}ms..."
        )

        # Call on_retry callback if provided
        if on_retry = opts[:on_retry] do
          on_retry.(attempt, error, wait_time)
        end

        # Emit telemetry event
        :telemetry.execute(
          [:vsm_phoenix, :resilience, :retry],
          %{attempt: attempt, wait_time: wait_time},
          %{error: error}
        )

        Process.sleep(wait_time)
        do_retry(fun, attempt + 1, opts)
      else
        # Non-retryable errors logged via telemetry events
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

  @doc """
  Create a retry wrapper function with pre-configured options
  """
  def create_retry_fn(opts \\ []) do
    fn fun ->
      with_retry(fun, opts)
    end
  end
end
