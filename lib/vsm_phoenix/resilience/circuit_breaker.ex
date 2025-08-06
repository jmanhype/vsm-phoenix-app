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
            # Configuration
            failure_threshold: 5,
            success_threshold: 3,
            # 30 seconds
            timeout: 30_000,
            # 1 minute
            reset_timeout: 60_000,
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
    config = DynamicConfig.get_component(:circuit_breaker)
    
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

        new_state = %{state | state: :closed, failure_count: 0, success_count: 0}
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

    Logger.warning(
      "⚠️  Circuit breaker #{state.name} failure #{new_failure_count}/#{state.failure_threshold}: #{inspect(error)}"
    )

    new_state =
      if new_failure_count >= state.failure_threshold or from_state == :half_open do
        # Open the circuit
        Logger.error(
          "🚨 Circuit breaker #{state.name} opening after #{new_failure_count} failures"
        )

        opened_state = %{
          state
          | state: :open,
            failure_count: new_failure_count,
            last_failure_time: now
        }

        # Schedule timeout check
        Process.send_after(self(), :check_timeout, state.timeout)

        notify_state_change(opened_state, from_state)
        opened_state
      else
        # Still closed, increment failure count
        updated_state = %{state | failure_count: new_failure_count, last_failure_time: now}

        # Schedule failure count reset
        Process.send_after(self(), :reset_failure_count, state.reset_timeout)

        updated_state
      end

    {:reply, {:error, error}, new_state}
  end

  defp notify_state_change(%{on_state_change: nil}, _), do: :ok

  defp notify_state_change(%{on_state_change: callback} = state, old_state)
       when is_function(callback, 3) do
    callback.(state.name, old_state, state.state)
  end
end
