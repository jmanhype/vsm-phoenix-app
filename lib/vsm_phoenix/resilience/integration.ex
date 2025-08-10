defmodule VsmPhoenix.Resilience.Integration do
  @moduledoc """
  Integration module for resilience patterns with VSM systems.
  
  Provides helper functions and macros to easily integrate circuit breakers
  and bulkheads into existing VSM components.
  """
  
  require Logger
  
  @doc """
  Executes an LLM API call with circuit breaker protection.
  """
  def with_llm_circuit_breaker(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    
    VsmPhoenix.Resilience.CircuitBreaker.call(
      :llm_api_breaker,
      fun,
      timeout
    )
  end
  
  @doc """
  Executes an AMQP operation with circuit breaker protection.
  """
  def with_amqp_circuit_breaker(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    
    VsmPhoenix.Resilience.CircuitBreaker.call(
      :amqp_breaker,
      fun,
      timeout
    )
  end
  
  @doc """
  Executes an external API call with circuit breaker protection.
  """
  def with_external_api_circuit_breaker(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 15_000)
    
    VsmPhoenix.Resilience.CircuitBreaker.call(
      :external_api_breaker,
      fun,
      timeout
    )
  end
  
  @doc """
  Executes a database operation with circuit breaker protection.
  """
  def with_database_circuit_breaker(fun, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 10_000)
    
    VsmPhoenix.Resilience.CircuitBreaker.call(
      :database_breaker,
      fun,
      timeout
    )
  end
  
  @doc """
  Executes work in a bulkhead-isolated worker pool.
  """
  def with_worker_pool(fun, opts \\ []) do
    VsmPhoenix.Resilience.Bulkhead.with_resource(
      :worker_agent_pool,
      fun,
      Keyword.get(opts, :timeout, 5_000)
    )
  end
  
  @doc """
  Executes LLM work in an isolated pool with rate limiting.
  """
  def with_llm_worker_pool(fun, opts \\ []) do
    VsmPhoenix.Resilience.Bulkhead.with_resource(
      :llm_worker_pool,
      fun,
      Keyword.get(opts, :timeout, 30_000)
    )
  end
  
  @doc """
  Executes sensor operations in an isolated pool.
  """
  def with_sensor_pool(fun, opts \\ []) do
    VsmPhoenix.Resilience.Bulkhead.with_resource(
      :sensor_agent_pool,
      fun,
      Keyword.get(opts, :timeout, 3_000)
    )
  end
  
  @doc """
  Executes API operations in an isolated pool.
  """
  def with_api_pool(fun, opts \\ []) do
    VsmPhoenix.Resilience.Bulkhead.with_resource(
      :api_agent_pool,
      fun,
      Keyword.get(opts, :timeout, 10_000)
    )
  end
  
  @doc """
  Executes Telegram bot operations in an isolated pool.
  """
  def with_telegram_pool(fun, opts \\ []) do
    VsmPhoenix.Resilience.Bulkhead.with_resource(
      :telegram_bot_pool,
      fun,
      Keyword.get(opts, :timeout, 10_000)
    )
  end
  
  @doc """
  Macro for adding resilience to a function.
  
  ## Example
  
      use VsmPhoenix.Resilience.Integration
      
      resilient :llm_api do
        def generate_response(prompt) do
          # LLM API call
        end
      end
  """
  defmacro resilient(type, do: block) do
    quote do
      unquote(block)
      |> then(fn ast ->
        case unquote(type) do
          :llm_api ->
            quote do
              def unquote(ast.name)(unquote_splicing(ast.args)) do
                VsmPhoenix.Resilience.Integration.with_llm_circuit_breaker(fn ->
                  unquote(ast.body)
                end)
              end
            end
          
          :amqp ->
            quote do
              def unquote(ast.name)(unquote_splicing(ast.args)) do
                VsmPhoenix.Resilience.Integration.with_amqp_circuit_breaker(fn ->
                  unquote(ast.body)
                end)
              end
            end
          
          :external_api ->
            quote do
              def unquote(ast.name)(unquote_splicing(ast.args)) do
                VsmPhoenix.Resilience.Integration.with_external_api_circuit_breaker(fn ->
                  unquote(ast.body)
                end)
              end
            end
          
          _ ->
            ast
        end
      end)
    end
  end
  
  @doc """
  Helper for implementing exponential backoff with jitter.
  """
  def with_backoff(fun, service \\ :default, opts \\ []) do
    config = VsmPhoenix.Resilience.Config.backoff_config(service)
    max_retries = Keyword.get(opts, :max_retries, 3)
    
    do_with_backoff(fun, config, 0, max_retries)
  end
  
  defp do_with_backoff(fun, _config, attempt, max_retries) when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end
  
  defp do_with_backoff(fun, config, attempt, max_retries) do
    case fun.() do
      {:ok, _} = success ->
        success
      
      {:error, reason} = error ->
        if retryable_error?(reason) do
          delay = calculate_backoff_delay(config, attempt)
          Logger.info("Retrying after #{delay}ms delay (attempt #{attempt + 1}/#{max_retries})")
          
          Process.sleep(delay)
          do_with_backoff(fun, config, attempt + 1, max_retries)
        else
          error
        end
    end
  end
  
  defp retryable_error?(reason) do
    case reason do
      :timeout -> true
      :circuit_open -> false
      {:http_error, status} when status >= 500 -> true
      {:http_error, 429} -> true  # Rate limited
      _ -> false
    end
  end
  
  defp calculate_backoff_delay(config, attempt) do
    base_delay = config.initial_delay * :math.pow(config.multiplier, attempt)
    capped_delay = min(base_delay, config.max_delay)
    
    # Add jitter
    jitter_range = capped_delay * config.randomization_factor
    jitter = :rand.uniform() * jitter_range * 2 - jitter_range
    
    round(capped_delay + jitter)
  end
  
  @doc """
  Health check helper for resilience components.
  """
  def check_resilience_health do
    %{
      circuit_breakers: check_circuit_breaker_health(),
      bulkheads: check_bulkhead_health(),
      overall: calculate_overall_health()
    }
  end
  
  defp check_circuit_breaker_health do
    [:llm_api_breaker, :amqp_breaker, :external_api_breaker, :database_breaker]
    |> Enum.map(fn breaker ->
      state = VsmPhoenix.Resilience.CircuitBreaker.get_state(breaker)
      {breaker, state}
    end)
    |> Map.new()
  end
  
  defp check_bulkhead_health do
    [:worker_agent_pool, :llm_worker_pool, :sensor_agent_pool, :api_agent_pool, :telegram_bot_pool]
    |> Enum.map(fn pool ->
      state = VsmPhoenix.Resilience.Bulkhead.get_state(pool)
      {pool, state}
    end)
    |> Map.new()
  end
  
  defp calculate_overall_health do
    cb_health = check_circuit_breaker_health()
    bh_health = check_bulkhead_health()
    
    open_circuits = Enum.count(cb_health, fn {_, %{state: state}} -> state == :open end)
    full_bulkheads = Enum.count(bh_health, fn {_, %{available: 0, waiting: w}} -> w > 0 end)
    
    cond do
      open_circuits == 0 and full_bulkheads == 0 -> :healthy
      open_circuits <= 1 and full_bulkheads <= 1 -> :degraded
      true -> :unhealthy
    end
  end
end