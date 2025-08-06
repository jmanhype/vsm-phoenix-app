defmodule VsmPhoenix.Infrastructure.HTTPConfig do
  @moduledoc """
  Configuration module for HTTP client settings.
  Manages headers, authentication, and other HTTP client configurations.
  """

  @default_headers [
    {"content-type", "application/json"},
    {"accept", "application/json"},
    {"user-agent", "VSM-Phoenix/1.0"}
  ]

  @doc """
  Load HTTP configuration from environment.
  """
  def load_config do
    %{
      default_timeout: get_env_int("VSM_HTTP_TIMEOUT", 30_000),
      max_retries: get_env_int("VSM_HTTP_MAX_RETRIES", 3),
      retry_delay: get_env_int("VSM_HTTP_RETRY_DELAY", 1_000),
      pool_size: get_env_int("VSM_HTTP_POOL_SIZE", 10)
    }
  end

  @doc """
  Get default headers for a service.
  """
  def get_default_headers(service_key) do
    service_headers =
      case service_key do
        :anthropic ->
          [{"anthropic-version", "2023-06-01"} | @default_headers]

        :telegram ->
          @default_headers

        _ ->
          @default_headers
      end

    # Add any custom headers from environment
    custom_headers = get_env_headers(service_key)
    Enum.uniq_by(custom_headers ++ service_headers, fn {key, _} -> String.downcase(key) end)
  end

  @doc """
  Get authentication configuration for a service.
  """
  def get_auth_config(service_key) do
    # First check Application environment (used by tests)
    case get_app_auth_config(service_key) do
      nil ->
        case service_key do
          :anthropic ->
            if api_key = System.get_env("ANTHROPIC_API_KEY") do
              {:api_key, "x-api-key", api_key}
            else
              nil
            end

          :telegram ->
            # Telegram uses token in URL, not headers
            nil

          _ ->
            # Check for generic auth config
            get_generic_auth_config(service_key)
        end

      auth_config ->
        auth_config
    end
  end

  @doc """
  Get circuit breaker configuration.
  """
  def get_circuit_breaker_config do
    %{
      enabled: get_env_bool("VSM_HTTP_CIRCUIT_BREAKER_ENABLED", true),
      failure_threshold: get_env_int("VSM_HTTP_CIRCUIT_BREAKER_THRESHOLD", 5),
      reset_timeout: get_env_int("VSM_HTTP_CIRCUIT_BREAKER_RESET", 60_000),
      half_open_requests: get_env_int("VSM_HTTP_CIRCUIT_BREAKER_HALF_OPEN", 3)
    }
  end

  @doc """
  Get telemetry configuration.
  """
  def get_telemetry_config do
    %{
      enabled: get_env_bool("VSM_HTTP_TELEMETRY_ENABLED", true),
      log_requests: get_env_bool("VSM_HTTP_LOG_REQUESTS", false),
      log_responses: get_env_bool("VSM_HTTP_LOG_RESPONSES", false),
      metrics_prefix: System.get_env("VSM_HTTP_METRICS_PREFIX", "vsm.http")
    }
  end

  # Private Functions

  defp get_env_int(key, default) do
    case System.get_env(key) do
      nil -> default
      value -> String.to_integer(value)
    end
  end

  defp get_env_bool(key, default) do
    case System.get_env(key) do
      nil -> default
      "true" -> true
      "false" -> false
      _ -> default
    end
  end

  defp get_env_headers(service_key) do
    prefix = "VSM_SERVICE_#{String.upcase(to_string(service_key))}_HEADER_"

    System.get_env()
    |> Enum.filter(fn {key, _} -> String.starts_with?(key, prefix) end)
    |> Enum.map(fn {key, value} ->
      header_name =
        key
        |> String.replace(prefix, "")
        |> String.downcase()
        |> String.replace("_", "-")

      {header_name, value}
    end)
  end

  defp get_generic_auth_config(service_key) do
    prefix = "VSM_SERVICE_#{String.upcase(to_string(service_key))}"

    cond do
      api_key = System.get_env("#{prefix}_API_KEY") ->
        key_header = System.get_env("#{prefix}_API_KEY_HEADER", "x-api-key")
        {:api_key, key_header, api_key}

      bearer_token = System.get_env("#{prefix}_BEARER_TOKEN") ->
        {:bearer, bearer_token}

      true ->
        nil
    end
  end

  defp get_app_auth_config(service_key) do
    http_services = Application.get_env(:vsm_phoenix, :http_services, %{})

    case Map.get(http_services, service_key) do
      %{auth: auth_config} -> auth_config
      _ -> nil
    end
  end
end
