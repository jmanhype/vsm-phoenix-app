defmodule VsmPhoenixWeb.HealthController do
  @moduledoc """
  Health check and system status controller for monitoring and load balancer integration.
  """
  
  use VsmPhoenixWeb, :controller
  
  alias VsmPhoenix.HealthChecker
  
  @doc """
  Basic health check endpoint.
  Returns 200 OK if the application is running.
  """
  def health(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{
      status: "healthy",
      timestamp: DateTime.utc_now(),
      version: Application.spec(:vsm_phoenix, :vsn),
      uptime: get_uptime()
    })
  end
  
  @doc """
  Readiness check endpoint for Kubernetes.
  Performs deeper health checks including database and external services.
  """
  def ready(conn, _params) do
    case HealthChecker.run_readiness_check() do
      {:ok, results} ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "ready",
          timestamp: DateTime.utc_now(),
          checks: results,
          version: Application.spec(:vsm_phoenix, :vsn)
        })
      
      {:error, failed_checks} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "not_ready",
          timestamp: DateTime.utc_now(),
          failed_checks: failed_checks,
          version: Application.spec(:vsm_phoenix, :vsn)
        })
    end
  end
  
  @doc """
  Liveness check endpoint for Kubernetes.
  Returns 200 if the application should continue running.
  """
  def live(conn, _params) do
    case HealthChecker.run_liveness_check() do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{
          status: "alive",
          timestamp: DateTime.utc_now()
        })
      
      {:error, reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          status: "unhealthy",
          timestamp: DateTime.utc_now(),
          reason: reason
        })
    end
  end
  
  @doc """
  Detailed system status including VSM components.
  """
  def status(conn, _params) do
    case HealthChecker.get_system_status() do
      {:ok, status} ->
        conn
        |> put_status(:ok)
        |> json(status)
      
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to get system status",
          reason: reason
        })
    end
  end
  
  # Private helper functions
  
  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms
  end
end