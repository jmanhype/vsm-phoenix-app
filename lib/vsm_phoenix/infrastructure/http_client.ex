defmodule VsmPhoenix.Infrastructure.HTTPClient do
  @moduledoc """
  Abstraction layer for HTTP operations with configurable endpoints.
  Provides a unified interface for all VSM systems to make HTTP requests.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.Infrastructure.ServiceRegistry
  alias VsmPhoenix.Infrastructure.HTTPConfig

  @default_timeout 30_000
  @default_retry_count 3
  @retry_delay 1_000

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Make an HTTP GET request to a service.
  """
  def get(service_key, path, opts \\ []) do
    request(:get, service_key, path, nil, opts)
  end

  @doc """
  Make an HTTP POST request to a service.
  """
  def post(service_key, path, body, opts \\ []) do
    request(:post, service_key, path, body, opts)
  end

  @doc """
  Make an HTTP PUT request to a service.
  """
  def put(service_key, path, body, opts \\ []) do
    request(:put, service_key, path, body, opts)
  end

  @doc """
  Make an HTTP DELETE request to a service.
  """
  def delete(service_key, path, opts \\ []) do
    request(:delete, service_key, path, nil, opts)
  end

  @doc """
  Make a generic HTTP request.
  """
  def request(method, service_key, path, body, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:request, method, service_key, path, body, opts},
      opts[:timeout] || @default_timeout + 5_000
    )
  end

  @doc """
  Get the base URL for a service.
  """
  def get_service_url(service_key) do
    ServiceRegistry.get_service_url(service_key)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      config: opts[:config] || HTTPConfig.load_config(),
      client: opts[:client] || :hackney,
      retry_config: %{
        max_retries: opts[:max_retries] || @default_retry_count,
        retry_delay: opts[:retry_delay] || @retry_delay
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:request, method, service_key, path, body, opts}, _from, state) do
    result = execute_request(method, service_key, path, body, opts, state)
    {:reply, result, state}
  end

  # Private Functions

  defp execute_request(method, service_key, path, body, opts, state) do
    with {:ok, base_url} <- ServiceRegistry.get_service_url(service_key),
         {:ok, headers} <- build_headers(service_key, opts),
         {:ok, url} <- build_url(base_url, path),
         {:ok, request_body} <- prepare_body(body) do
      retry_request(method, url, headers, request_body, opts, state, 0)
    else
      {:error, {:unknown_service, _}} -> {:error, :unknown_service}
      {:error, reason} -> {:error, reason}
    end
  end

  defp retry_request(method, url, headers, body, opts, state, attempt) do
    timeout = opts[:timeout] || @default_timeout

    case make_request(state.client, method, url, headers, body, timeout) do
      {:ok, status, response_headers, response_body} when status >= 200 and status < 300 ->
        {:ok,
         %{
           status: status,
           headers: response_headers,
           body: decode_body(response_body, response_headers)
         }}

      {:ok, status, response_headers, response_body}
      when status >= 500 and attempt < state.retry_config.max_retries ->
        Logger.warning(
          "HTTP request failed with status #{status}, retrying (attempt #{attempt + 1})"
        )

        Process.sleep(state.retry_config.retry_delay * (attempt + 1))
        retry_request(method, url, headers, body, opts, state, attempt + 1)

      {:ok, status, response_headers, response_body} ->
        {:error,
         %{
           status: status,
           headers: response_headers,
           body: decode_body(response_body, response_headers)
         }}

      {:error, reason} when attempt < state.retry_config.max_retries ->
        Logger.warning(
          "HTTP request failed with error: #{inspect(reason)}, retrying (attempt #{attempt + 1})"
        )

        Process.sleep(state.retry_config.retry_delay * (attempt + 1))
        retry_request(method, url, headers, body, opts, state, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_request(:hackney, method, url, headers, body, timeout) do
    options = [:with_body, {:timeout, timeout}]

    case :hackney.request(method, url, headers, body || "", options) do
      {:ok, status, headers, body} ->
        {:ok, status, headers, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_headers(service_key, opts) do
    base_headers = HTTPConfig.get_default_headers(service_key)
    custom_headers = opts[:headers] || []

    headers = Enum.into(custom_headers, base_headers)

    # Add authentication if configured
    headers =
      case HTTPConfig.get_auth_config(service_key) do
        {:api_key, key_name, key_value} ->
          [{key_name, key_value} | headers]

        {:bearer, token} ->
          [{"Authorization", "Bearer #{token}"} | headers]

        nil ->
          headers
      end

    {:ok, headers}
  end

  defp build_url(base_url, path) do
    url = String.trim_trailing(base_url, "/") <> "/" <> String.trim_leading(path, "/")
    {:ok, url}
  end

  defp prepare_body(nil), do: {:ok, nil}
  defp prepare_body(body) when is_binary(body), do: {:ok, body}

  defp prepare_body(body) do
    case Jason.encode(body) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, {:encoding_error, reason}}
    end
  end

  defp decode_body(body, headers) do
    content_type = get_header(headers, "content-type", "")

    cond do
      String.contains?(content_type, "application/json") ->
        case Jason.decode(body) do
          {:ok, decoded} -> decoded
          {:error, _} -> body
        end

      true ->
        body
    end
  end

  defp get_header(headers, key, default \\ nil) do
    headers
    |> Enum.find(fn {k, _} -> String.downcase(k) == String.downcase(key) end)
    |> case do
      {_, value} -> value
      nil -> default
    end
  end
end
