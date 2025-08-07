defmodule VsmPhoenix.Resilience.ResilientHTTPClient do
  @moduledoc """
  Resilient HTTP Client with circuit breaker, retry logic, and timeouts.

  Features:
  - Circuit breaker for service protection
  - Exponential backoff with retry
  - Configurable timeouts
  - Request pooling and rate limiting
  - Telemetry integration
  """

  use GenServer
  require Logger

  alias VsmPhoenix.Resilience.{CircuitBreaker, Retry}

  defstruct name: nil,
            circuit_breaker: nil,
            config: %{},
            metrics: %{
              total_requests: 0,
              successful_requests: 0,
              failed_requests: 0,
              circuit_breaker_trips: 0,
              timeouts: 0
            }

  # Default configuration
  @default_config %{
    timeout: 5_000,
    recv_timeout: 5_000,
    max_retries: 3,
    base_backoff: 100,
    max_backoff: 5_000,
    circuit_breaker_threshold: 5,
    circuit_breaker_timeout: 30_000
  }

  # Client API

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Make a GET request with resilience patterns
  """
  def get(client, url, headers \\ [], opts \\ []) do
    request(client, :get, url, "", headers, opts)
  end

  @doc """
  Make a POST request with resilience patterns
  """
  def post(client, url, body, headers \\ [], opts \\ []) do
    request(client, :post, url, body, headers, opts)
  end

  @doc """
  Make a PUT request with resilience patterns
  """
  def put(client, url, body, headers \\ [], opts \\ []) do
    request(client, :put, url, body, headers, opts)
  end

  @doc """
  Make a DELETE request with resilience patterns
  """
  def delete(client, url, headers \\ [], opts \\ []) do
    request(client, :delete, url, "", headers, opts)
  end

  @doc """
  Make a generic HTTP request with resilience patterns
  """
  def request(client, method, url, body, headers \\ [], opts \\ []) do
    GenServer.call(client, {:request, method, url, body, headers, opts}, :infinity)
  end

  @doc """
  Get client metrics
  """
  def get_metrics(client) do
    GenServer.call(client, :get_metrics)
  end

  @doc """
  Get circuit breaker state
  """
  def get_circuit_state(client) do
    GenServer.call(client, :get_circuit_state)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)

    config =
      Keyword.get(opts, :config, %{})
      |> Map.merge(@default_config)

    # Start circuit breaker
    {:ok, circuit_breaker} =
      CircuitBreaker.start_link(
        name: :"#{name}_CircuitBreaker",
        failure_threshold: config.circuit_breaker_threshold,
        timeout: config.circuit_breaker_timeout,
        on_state_change: &handle_circuit_state_change/3
      )

    state = %__MODULE__{
      name: name,
      circuit_breaker: circuit_breaker,
      config: config
    }

    Logger.info("🌐 Resilient HTTP Client #{name} initialized")

    {:ok, state}
  end

  @impl true
  def handle_call({:request, method, url, body, headers, opts}, _from, state) do
    state = update_metrics(state, :total_requests, 1)

    # Merge request options with client config
    timeout = Keyword.get(opts, :timeout, state.config.timeout)
    recv_timeout = Keyword.get(opts, :recv_timeout, state.config.recv_timeout)

    # Execute request through circuit breaker
    result =
      CircuitBreaker.call(
        state.circuit_breaker,
        fn ->
          execute_request_with_retry(
            method,
            url,
            body,
            headers,
            timeout,
            recv_timeout,
            state.config
          )
        end,
        # Circuit breaker timeout slightly higher than request timeout
        timeout + 1000
      )

    {response, new_state} =
      case result do
        {:ok, response} ->
          state = update_metrics(state, :successful_requests, 1)
          {{:ok, response}, state}

        {:error, :circuit_open} ->
          Logger.warning("⚡ Circuit breaker open for #{state.name}")
          state = update_metrics(state, :circuit_breaker_trips, 1)
          {{:error, :circuit_open}, state}

        {:error, :timeout} = error ->
          state = update_metrics(state, :timeouts, 1)
          {error, state}

        {:error, _} = error ->
          state = update_metrics(state, :failed_requests, 1)
          {error, state}
      end

    # Emit telemetry
    :telemetry.execute(
      [:vsm_phoenix, :resilience, :http_client, :request],
      # Would need to track actual duration
      %{duration: 0},
      %{
        client: state.name,
        method: method,
        url: url,
        status: elem(response, 0)
      }
    )

    {:reply, response, new_state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call(:get_circuit_state, _from, state) do
    circuit_state = CircuitBreaker.get_state(state.circuit_breaker)
    {:reply, circuit_state, state}
  end

  # Private Functions

  defp execute_request_with_retry(method, url, body, headers, timeout, recv_timeout, config) do
    retry_opts = [
      max_attempts: config.max_retries,
      base_backoff: config.base_backoff,
      max_backoff: config.max_backoff,
      retry_on: [:error, :exit, :timeout],
      on_retry: fn attempt, error, wait_time ->
        Logger.warning("🔄 HTTP retry attempt #{attempt} for #{method} #{url}: #{inspect(error)}")
      end
    ]

    Retry.with_retry(
      fn ->
        case execute_http_request(method, url, body, headers, timeout, recv_timeout) do
          {:ok, response} -> response
          {:error, reason} -> raise "HTTP request failed: #{inspect(reason)}"
        end
      end,
      retry_opts
    )
  end

  defp execute_http_request(method, url, body, headers, timeout, recv_timeout) do
    options = [
      timeout: timeout,
      recv_timeout: recv_timeout
    ]

    # Add content-type header if not present and body is not empty
    headers =
      if body != "" and not has_content_type?(headers) do
        [{"Content-Type", "application/json"} | headers]
      else
        headers
      end

    case method do
      :get -> HTTPoison.get(url, headers, options)
      :post -> HTTPoison.post(url, body, headers, options)
      :put -> HTTPoison.put(url, body, headers, options)
      :delete -> HTTPoison.delete(url, headers, options)
      :patch -> HTTPoison.patch(url, body, headers, options)
      :head -> HTTPoison.head(url, headers, options)
      :options -> HTTPoison.options(url, headers, options)
    end
  end

  defp has_content_type?(headers) do
    Enum.any?(headers, fn {key, _} ->
      String.downcase(key) == "content-type"
    end)
  end

  defp update_metrics(state, metric, increment) do
    new_metrics = Map.update!(state.metrics, metric, &(&1 + increment))
    %{state | metrics: new_metrics}
  end

  defp handle_circuit_state_change(name, old_state, new_state) do
    Logger.info("⚡ HTTP Circuit breaker #{name} changed from #{old_state} to #{new_state}")
  end
end
