defmodule VsmPhoenix.Resilience.CircuitBreaker do
  @moduledoc """
  Circuit Breaker implementation for VSM Phoenix resilience patterns.

  States:
  - :closed - Normal operation, requests pass through
  - :open - Circuit is open, requests fail immediately
  - :half_open - Testing if service has recovered

  Configuration:
  - failure_threshold: Number of failures before opening circuit
  - success_threshold: Number of successes in half_open before closing
  - timeout: Time in milliseconds before moving from open to half_open
  - reset_timeout: Time to reset failure count in closed state
  """

  use GenServer
  require Logger

  defstruct name: nil,
            state: :closed,
            failure_count: 0,
            success_count: 0,
            last_failure_time: nil,
            # Adaptive configuration
            base_failure_threshold: 5,
            failure_threshold: 5,
            success_threshold: 3,
            # 30 seconds
            timeout: 30_000,
            # 1 minute
            reset_timeout: 60_000,
            # Claude-inspired self-correction patterns
            adaptive_enabled: true,
            error_patterns: %{},
            recovery_success_rate: 1.0,
            last_adaptation_time: nil,
            adaptation_window: 300_000,  # 5 minutes
            # Callbacks
            on_state_change: nil

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Execute a function through the circuit breaker
  """
  def call(breaker, fun, timeout \\ 5000) do
    GenServer.call(breaker, {:call, fun}, timeout)
  end

  @doc """
  Get current circuit breaker state
  """
  def get_state(breaker) do
    GenServer.call(breaker, :get_state)
  end

  @doc """
  Reset the circuit breaker
  """
  def reset(breaker) do
    GenServer.cast(breaker, :reset)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Get dynamic configuration
    config = VsmPhoenix.Infrastructure.DynamicConfig.get_component(:circuit_breaker)
    
    # Merge dynamic config with opts
    merged_opts = Keyword.merge([
      failure_threshold: config[:failure_threshold] || 5,
      success_threshold: config[:half_open_tries] || 3,
      timeout: config[:reset_timeout] || 30_000,
      reset_timeout: config[:window_size] || 60_000
    ], opts)
    
    state = struct(__MODULE__, merged_opts)
    Logger.info("⚡ Circuit breaker #{state.name} initialized in :closed state")
    {:ok, state}
  end

  @impl true
  def handle_call({:call, fun}, _from, state) do
    case state.state do
      :closed ->
        handle_closed_call(fun, state)

      :open ->
        handle_open_call(fun, state)

      :half_open ->
        handle_half_open_call(fun, state)
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    info = %{
      state: state.state,
      failure_count: state.failure_count,
      success_count: state.success_count,
      last_failure_time: state.last_failure_time
    }

    {:reply, info, state}
  end

  @impl true
  def handle_cast(:reset, state) do
    Logger.info("🔄 Resetting circuit breaker #{state.name}")

    new_state = %{
      state
      | state: :closed,
        failure_count: 0,
        success_count: 0,
        last_failure_time: nil
    }

    notify_state_change(new_state, state.state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_timeout, %{state: :open} = state) do
    # Move from open to half_open after timeout
    Logger.info("⏰ Circuit breaker #{state.name} timeout expired, moving to :half_open")
    new_state = %{state | state: :half_open, success_count: 0}
    notify_state_change(new_state, :open)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:reset_failure_count, %{state: :closed} = state) do
    # Reset failure count after reset_timeout in closed state
    new_state = %{state | failure_count: 0}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # Private Functions

  defp handle_closed_call(fun, state) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      result = fun.()
      
      # Report success metrics
      recovery_time = System.monotonic_time(:millisecond) - start_time
      DynamicConfig.report_metric(:circuit_breaker, :recovery_time, recovery_time)
      DynamicConfig.report_outcome(:circuit_breaker, state.name, :success)

      # Reset failure count on success if we had failures
      new_state =
        if state.failure_count > 0 do
          %{state | failure_count: 0}
        else
          state
        end

      {:reply, {:ok, result}, new_state}
    rescue
      error ->
        DynamicConfig.report_outcome(:circuit_breaker, state.name, :failure)
        handle_failure(state, error, :closed)
    catch
      :exit, reason ->
        DynamicConfig.report_outcome(:circuit_breaker, state.name, :failure)
        handle_failure(state, {:exit, reason}, :closed)
    end
  end

  defp handle_open_call(_fun, state) do
    now = System.monotonic_time(:millisecond)
    time_since_failure = now - (state.last_failure_time || now)

    if time_since_failure >= state.timeout do
      # Timeout expired, transition to half_open
      Process.send(self(), :check_timeout, [])
      {:reply, {:error, :circuit_open}, state}
    else
      # Still in cooldown
      DynamicConfig.report_outcome(:circuit_breaker, state.name, :rejected_open)
      {:reply, {:error, :circuit_open}, state}
    end
  end

  defp handle_half_open_call(fun, state) do
    try do
      result = fun.()

      # Success in half_open state
      new_success_count = state.success_count + 1

      if new_success_count >= state.success_threshold do
        # Enough successes, close the circuit
        Logger.info(
          "✅ Circuit breaker #{state.name} closing after #{new_success_count} successes"
        )

        # Calculate recovery success rate for adaptive learning
        total_attempts = state.success_count + 1
        recovery_rate = (state.success_count + 1) / total_attempts
        
        new_state = %{state | 
          state: :closed, 
          failure_count: 0, 
          success_count: 0,
          recovery_success_rate: recovery_rate
        }
        notify_state_change(new_state, :half_open)
        {:reply, {:ok, result}, new_state}
      else
        # Need more successes
        new_state = %{state | success_count: new_success_count}
        {:reply, {:ok, result}, new_state}
      end
    rescue
      error ->
        handle_failure(state, error, :half_open)
    catch
      :exit, reason ->
        handle_failure(state, {:exit, reason}, :half_open)
    end
  end

  defp handle_failure(state, error, from_state) do
    new_failure_count = state.failure_count + 1
    now = System.monotonic_time(:millisecond)

    # Claude-inspired error pattern analysis
    updated_state = analyze_and_adapt_thresholds(state, error, now)

    Logger.warning(
      "⚠️  Circuit breaker #{updated_state.name} failure #{new_failure_count}/#{updated_state.failure_threshold}: #{inspect(error)}"
    )

    new_state =
      if new_failure_count >= updated_state.failure_threshold or from_state == :half_open do
        # Open the circuit
        Logger.error(
          "🚨 Circuit breaker #{updated_state.name} opening after #{new_failure_count} failures"
        )

        opened_state = %{
          updated_state
          | state: :open,
            failure_count: new_failure_count,
            last_failure_time: now
        }

        # Schedule timeout check
        Process.send_after(self(), :check_timeout, updated_state.timeout)

        notify_state_change(opened_state, from_state)
        opened_state
      else
        # Still closed, increment failure count
        final_state = %{updated_state | failure_count: new_failure_count, last_failure_time: now}

        # Schedule failure count reset
        Process.send_after(self(), :reset_failure_count, updated_state.reset_timeout)

        final_state
      end

    {:reply, {:error, error}, new_state}
  end

  defp notify_state_change(%{on_state_change: nil}, _), do: :ok

  defp notify_state_change(%{on_state_change: callback} = state, old_state)
       when is_function(callback, 3) do
    callback.(state.name, old_state, state.state)
  end

  # Claude-inspired adaptive threshold management
  defp analyze_and_adapt_thresholds(state, error, current_time) do
    if not state.adaptive_enabled do
      state
    else
      # Track error patterns similar to Claude's self-correction
      error_type = classify_error(error)
      updated_patterns = update_error_patterns(state.error_patterns, error_type, current_time)
      
      # Adapt thresholds based on error frequency and recovery patterns
      adapted_state = maybe_adjust_thresholds(state, updated_patterns, current_time)
      
      %{adapted_state | error_patterns: updated_patterns}
    end
  end

  defp classify_error(error) do
    case error do
      %{__struct__: module} -> module
      {:timeout, _} -> :timeout
      {:noproc, _} -> :process_down
      {:exit, :timeout} -> :timeout
      {:exit, :normal} -> :normal_exit
      _ -> :unknown
    end
  end

  defp update_error_patterns(patterns, error_type, current_time) do
    current_count = Map.get(patterns, error_type, %{count: 0, last_seen: 0})
    
    Map.put(patterns, error_type, %{
      count: current_count.count + 1,
      last_seen: current_time
    })
  end

  defp maybe_adjust_thresholds(state, patterns, current_time) do
    # Only adapt once per adaptation window (Claude's patience approach)
    time_since_last_adaptation = 
      if state.last_adaptation_time, 
        do: current_time - state.last_adaptation_time, 
        else: state.adaptation_window + 1

    if time_since_last_adaptation >= state.adaptation_window do
      adjust_failure_threshold(state, patterns, current_time)
    else
      state
    end
  end

  defp adjust_failure_threshold(state, patterns, current_time) do
    # Calculate error frequency over adaptation window
    recent_errors = patterns
                   |> Enum.filter(fn {_type, %{last_seen: last_seen}} -> 
                        current_time - last_seen <= state.adaptation_window 
                      end)
                   |> Enum.map(fn {_type, %{count: count}} -> count end)
                   |> Enum.sum()

    # Claude-style adaptive adjustment based on recent performance
    new_threshold = cond do
      # High error rate - be more sensitive (lower threshold)
      recent_errors > state.base_failure_threshold * 2 ->
        max(2, round(state.base_failure_threshold * 0.7))
      
      # Low error rate and good recovery - be more tolerant (higher threshold)
      recent_errors == 0 and state.recovery_success_rate > 0.9 ->
        min(state.base_failure_threshold * 2, round(state.base_failure_threshold * 1.3))
      
      # Default - return to base threshold
      true ->
        state.base_failure_threshold
    end

    if new_threshold != state.failure_threshold do
      Logger.info("🔧 Circuit breaker #{state.name} adapting threshold: #{state.failure_threshold} → #{new_threshold}")
      
      %{state | 
        failure_threshold: new_threshold, 
        last_adaptation_time: current_time
      }
    else
      %{state | last_adaptation_time: current_time}
    end
  end
end
