defmodule VsmPhoenix.Infrastructure.ServiceRegistry do
  @moduledoc """
  Service registry for managing HTTP service endpoints.
  Maps logical service names to environment-specific URLs.
  """

  @default_services %{
    # External APIs
    anthropic: %{
      url: "https://api.anthropic.com",
      paths: %{
        messages: "/v1/messages"
      }
    },
    telegram: %{
      url: "https://api.telegram.org",
      paths: %{
        bot: "/bot{token}"
      }
    },

    # Internal services
    mcp_registry: %{
      url: "https://mcp-registry.anthropic.com",
      paths: %{
        root: "/"
      }
    },

    # Configurable local services
    mcp_local: %{
      url: "http://localhost:3000",
      paths: %{
        root: "/"
      }
    },
    mcp_http: %{
      url: "http://localhost:8080",
      paths: %{
        root: "/"
      }
    }
  }

  @doc """
  Get the base URL for a service.
  """
  def get_service_url(service_key) when is_atom(service_key) do
    service_config = get_service_config(service_key)

    case service_config do
      %{url: url} -> {:ok, url}
      nil -> {:error, {:unknown_service, service_key}}
    end
  end

  @doc """
  Get the full URL for a service path.
  """
  def get_service_path_url(service_key, path_key, params \\ %{}) do
    with {:ok, base_url} <- get_service_url(service_key),
         {:ok, path} <- get_service_path(service_key, path_key) do
      # Replace path parameters
      full_path =
        Enum.reduce(params, path, fn {key, value}, acc ->
          String.replace(acc, "{#{key}}", to_string(value))
        end)

      {:ok, base_url <> full_path}
    end
  end

  @doc """
  Get a specific path for a service.
  """
  def get_service_path(service_key, path_key) do
    service_config = get_service_config(service_key)

    case service_config do
      %{paths: paths} ->
        case Map.get(paths, path_key) do
          nil -> {:error, {:unknown_path, service_key, path_key}}
          path -> {:ok, path}
        end

      _ ->
        {:error, {:unknown_service, service_key}}
    end
  end

  @doc """
  Register a new service or update an existing one.
  """
  def register_service(service_key, config) do
    :persistent_term.put({__MODULE__, service_key}, config)
    :ok
  end

  @doc """
  List all registered services.
  """
  def list_services do
    # Get default services
    default_keys = Map.keys(@default_services)

    # Get dynamically registered services
    dynamic_keys =
      try do
        :persistent_term.get()
        |> Enum.filter(fn
          {{module, _key}, _value} when module == __MODULE__ -> true
          _ -> false
        end)
        |> Enum.map(fn {{_module, key}, _value} -> key end)
      rescue
        _ -> []
      end

    # Get Application environment services
    app_keys =
      Application.get_env(:vsm_phoenix, :http_services, %{})
      |> Map.keys()

    Enum.uniq(default_keys ++ dynamic_keys ++ app_keys)
  end

  # Private Functions

  defp get_service_config(service_key) do
    # Check environment variables first
    env_url = System.get_env("VSM_SERVICE_#{String.upcase(to_string(service_key))}_URL")

    cond do
      env_url ->
        %{url: env_url, paths: get_default_paths(service_key)}

      config = :persistent_term.get({__MODULE__, service_key}, nil) ->
        config

      # Check application environment (used by tests)
      app_config = get_app_service_config(service_key) ->
        app_config

      true ->
        Map.get(@default_services, service_key)
    end
  end

  defp get_default_paths(service_key) do
    case Map.get(@default_services, service_key) do
      %{paths: paths} -> paths
      _ -> %{}
    end
  end

  defp get_app_service_config(service_key) do
    http_services = Application.get_env(:vsm_phoenix, :http_services, %{})
    Map.get(http_services, service_key)
  end
end
