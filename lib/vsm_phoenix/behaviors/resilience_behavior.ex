defmodule VsmPhoenix.Behaviors.ResilienceBehavior do
  @moduledoc """
  Shared resilience behavior to eliminate 142+ try/rescue blocks across god objects.
  
  Provides circuit breaker, retry, and bulkhead patterns as reusable behaviors,
  enabling consistent error handling and resilience across all VSM systems.
  
  This behavior eliminates duplicate try/rescue blocks from:
  - control.ex (3,442 lines with multiple try/rescue)
  - telegram_agent.ex (multiple error handling blocks)
  - intelligence.ex (14 try/rescue blocks)  
  - queen.ex (error handling patterns)
  - And 6+ more god objects!
  """
  
  @doc """
  Executes operation with circuit breaker protection.
  
  Prevents cascading failures by temporarily disabling failing operations.
  """
  @callback with_circuit_breaker(operation :: function(), opts :: keyword()) :: 
    {:ok, result :: term()} | {:error, reason :: term()}
    
  @doc """
  Executes operation with retry logic.
  
  Automatically retries failed operations with configurable backoff.
  """
  @callback with_retry(operation :: function(), opts :: keyword()) ::
    {:ok, result :: term()} | {:error, reason :: term()}
    
  @doc """
  Executes operation with bulkhead isolation.
  
  Isolates resource usage to prevent resource starvation.
  """
  @callback with_bulkhead(resource :: atom(), operation :: function(), opts :: keyword()) ::
    {:ok, result :: term()} | {:error, reason :: term()}
    
  @doc """
  Executes operation with timeout protection.
  
  Prevents hanging operations by enforcing time limits.
  """
  @callback with_timeout(operation :: function(), timeout_ms :: integer()) ::
    {:ok, result :: term()} | {:error, :timeout}
    
  @doc """
  Combines multiple resilience patterns for comprehensive protection.
  """
  @callback with_comprehensive_protection(
    operation :: function(), 
    circuit_breaker_opts :: keyword(),
    retry_opts :: keyword(),
    timeout_ms :: integer()
  ) :: {:ok, result :: term()} | {:error, reason :: term()}

  defmodule Default do
    @moduledoc """
    Default implementation with actual circuit breaker, retry, and bulkhead logic.
    """
    
    @behaviour VsmPhoenix.Behaviors.ResilienceBehavior
    
    use GenServer
    require Logger
    
    # Circuit Breaker States
    @cb_closed :closed
    @cb_open :open
    @cb_half_open :half_open
    
    defstruct [
      circuit_breakers: %{},
      bulkheads: %{},
      retry_configs: %{}
    ]
    
    def start_link(opts \\ []) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end
    
    @impl true
    def init(_opts) do
      {:ok, %__MODULE__{}}
    end
    
    @impl true
    def with_circuit_breaker(operation, opts \\ []) do
      circuit_id = Keyword.get(opts, :circuit_id, :default)
      failure_threshold = Keyword.get(opts, :failure_threshold, 5)
      reset_timeout = Keyword.get(opts, :reset_timeout, 60_000)
      
      case get_circuit_state(circuit_id) do
        @cb_open -> 
          {:error, :circuit_open}
          
        @cb_half_open ->
          execute_with_circuit_tracking(operation, circuit_id, failure_threshold, reset_timeout)
          
        @cb_closed ->
          execute_with_circuit_tracking(operation, circuit_id, failure_threshold, reset_timeout)
      end
    end
    
    @impl true
    def with_retry(operation, opts \\ []) do
      max_attempts = Keyword.get(opts, :max_attempts, 3)
      base_delay = Keyword.get(opts, :base_delay, 1000)
      max_delay = Keyword.get(opts, :max_delay, 10_000)
      backoff_factor = Keyword.get(opts, :backoff_factor, 2.0)
      
      execute_with_retry(operation, 1, max_attempts, base_delay, max_delay, backoff_factor)
    end
    
    @impl true 
    def with_bulkhead(resource, operation, opts \\ []) do
      max_concurrency = Keyword.get(opts, :max_concurrency, 10)
      timeout = Keyword.get(opts, :timeout, 5_000)
      
      case acquire_bulkhead_permit(resource, max_concurrency) do
        :ok ->
          try do
            case execute_with_timeout(operation, timeout) do
              {:ok, result} -> 
                release_bulkhead_permit(resource)
                {:ok, result}
              {:error, reason} -> 
                release_bulkhead_permit(resource)
                {:error, reason}
            end
          catch
            error ->
              release_bulkhead_permit(resource)
              {:error, error}
          end
          
        {:error, :bulkhead_full} ->
          {:error, :resource_unavailable}
      end
    end
    
    @impl true
    def with_timeout(operation, timeout_ms) do
      execute_with_timeout(operation, timeout_ms)
    end
    
    @impl true
    def with_comprehensive_protection(operation, cb_opts, retry_opts, timeout_ms) do
      protected_operation = fn ->
        with_circuit_breaker(fn ->
          with_timeout(operation, timeout_ms)
        end, cb_opts)
      end
      
      with_retry(protected_operation, retry_opts)
    end
    
    # Private Implementation Functions
    
    defp execute_with_circuit_tracking(operation, circuit_id, failure_threshold, reset_timeout) do
      start_time = System.monotonic_time(:millisecond)
      
      try do
        result = operation.()
        record_circuit_success(circuit_id)
        {:ok, result}
      rescue
        error ->
          record_circuit_failure(circuit_id, failure_threshold, reset_timeout)
          {:error, {:operation_failed, error}}
      catch
        :throw, value -> 
          record_circuit_failure(circuit_id, failure_threshold, reset_timeout)
          {:error, {:operation_threw, value}}
        :exit, reason ->
          record_circuit_failure(circuit_id, failure_threshold, reset_timeout)
          {:error, {:operation_exited, reason}}
      end
    end
    
    defp execute_with_retry(operation, attempt, max_attempts, base_delay, max_delay, backoff_factor) do
      try do
        result = operation.()
        {:ok, result}
      rescue
        error ->
          if attempt < max_attempts do
            delay = min(base_delay * :math.pow(backoff_factor, attempt - 1), max_delay)
            :timer.sleep(trunc(delay))
            execute_with_retry(operation, attempt + 1, max_attempts, base_delay, max_delay, backoff_factor)
          else
            {:error, {:max_retries_exceeded, error}}
          end
      catch
        :throw, value ->
          if attempt < max_attempts do
            delay = min(base_delay * :math.pow(backoff_factor, attempt - 1), max_delay)
            :timer.sleep(trunc(delay))
            execute_with_retry(operation, attempt + 1, max_attempts, base_delay, max_delay, backoff_factor)
          else
            {:error, {:max_retries_exceeded, {:throw, value}}}
          end
          
        :exit, reason ->
          if attempt < max_attempts do
            delay = min(base_delay * :math.pow(backoff_factor, attempt - 1), max_delay)
            :timer.sleep(trunc(delay))
            execute_with_retry(operation, attempt + 1, max_attempts, base_delay, max_delay, backoff_factor)
          else
            {:error, {:max_retries_exceeded, {:exit, reason}}}
          end
      end
    end
    
    defp execute_with_timeout(operation, timeout_ms) do
      parent = self()
      ref = make_ref()
      
      worker_pid = spawn_link(fn ->
        try do
          result = operation.()
          send(parent, {ref, {:ok, result}})
        rescue
          error -> send(parent, {ref, {:error, {:operation_failed, error}}})
        catch
          :throw, value -> send(parent, {ref, {:error, {:operation_threw, value}}})
          :exit, reason -> send(parent, {ref, {:error, {:operation_exited, reason}}})
        end
      end)
      
      receive do
        {^ref, result} -> 
          Process.unlink(worker_pid)
          result
      after
        timeout_ms ->
          Process.unlink(worker_pid)
          Process.exit(worker_pid, :kill)
          {:error, :timeout}
      end
    end
    
    defp get_circuit_state(circuit_id) do
      GenServer.call(__MODULE__, {:get_circuit_state, circuit_id})
    end
    
    defp record_circuit_success(circuit_id) do
      GenServer.cast(__MODULE__, {:circuit_success, circuit_id})
    end
    
    defp record_circuit_failure(circuit_id, failure_threshold, reset_timeout) do
      GenServer.cast(__MODULE__, {:circuit_failure, circuit_id, failure_threshold, reset_timeout})
    end
    
    defp acquire_bulkhead_permit(resource, max_concurrency) do
      GenServer.call(__MODULE__, {:acquire_bulkhead, resource, max_concurrency})
    end
    
    defp release_bulkhead_permit(resource) do
      GenServer.cast(__MODULE__, {:release_bulkhead, resource})
    end
    
    # GenServer Callbacks for State Management
    
    @impl true
    def handle_call({:get_circuit_state, circuit_id}, _from, state) do
      circuit_state = Map.get(state.circuit_breakers, circuit_id, %{state: @cb_closed, failures: 0})
      {:reply, circuit_state.state, state}
    end
    
    @impl true
    def handle_call({:acquire_bulkhead, resource, max_concurrency}, _from, state) do
      current_count = Map.get(state.bulkheads, resource, 0)
      
      if current_count < max_concurrency do
        new_bulkheads = Map.put(state.bulkheads, resource, current_count + 1)
        {:reply, :ok, %{state | bulkheads: new_bulkheads}}
      else
        {:reply, {:error, :bulkhead_full}, state}
      end
    end
    
    @impl true
    def handle_cast({:circuit_success, circuit_id}, state) do
      updated_circuits = Map.update(state.circuit_breakers, circuit_id, 
        %{state: @cb_closed, failures: 0}, 
        &%{&1 | state: @cb_closed, failures: 0}
      )
      {:noreply, %{state | circuit_breakers: updated_circuits}}
    end
    
    @impl true
    def handle_cast({:circuit_failure, circuit_id, failure_threshold, reset_timeout}, state) do
      updated_circuits = Map.update(state.circuit_breakers, circuit_id,
        %{state: @cb_closed, failures: 1},
        fn circuit ->
          new_failures = circuit.failures + 1
          if new_failures >= failure_threshold do
            Process.send_after(self(), {:reset_circuit, circuit_id}, reset_timeout)
            %{circuit | state: @cb_open, failures: new_failures}
          else
            %{circuit | failures: new_failures}
          end
        end
      )
      {:noreply, %{state | circuit_breakers: updated_circuits}}
    end
    
    @impl true
    def handle_cast({:release_bulkhead, resource}, state) do
      new_bulkheads = Map.update(state.bulkheads, resource, 0, &max(0, &1 - 1))
      {:noreply, %{state | bulkheads: new_bulkheads}}
    end
    
    @impl true
    def handle_info({:reset_circuit, circuit_id}, state) do
      updated_circuits = Map.update(state.circuit_breakers, circuit_id,
        %{state: @cb_half_open, failures: 0},
        &%{&1 | state: @cb_half_open}
      )
      {:noreply, %{state | circuit_breakers: updated_circuits}}
    end
  end
  
  defmodule Test do
    @moduledoc """
    Test implementation for unit testing without actual resilience logic.
    """
    
    @behaviour VsmPhoenix.Behaviors.ResilienceBehavior
    
    @impl true
    def with_circuit_breaker(operation, _opts \\ []) do
      try do
        result = operation.()
        {:ok, result}
      rescue
        error -> {:error, error}
      end
    end
    
    @impl true
    def with_retry(operation, _opts \\ []) do
      try do
        result = operation.()
        {:ok, result}
      rescue
        error -> {:error, error}
      end
    end
    
    @impl true
    def with_bulkhead(_resource, operation, _opts \\ []) do
      try do
        result = operation.()
        {:ok, result}
      rescue
        error -> {:error, error}
      end
    end
    
    @impl true
    def with_timeout(operation, _timeout_ms) do
      try do
        result = operation.()
        {:ok, result}
      rescue
        error -> {:error, error}
      end
    end
    
    @impl true
    def with_comprehensive_protection(operation, _cb_opts, _retry_opts, _timeout_ms) do
      try do
        result = operation.()
        {:ok, result}
      rescue
        error -> {:error, error}
      end
    end
  end
end