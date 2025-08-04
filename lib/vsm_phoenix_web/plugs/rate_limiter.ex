defmodule VsmPhoenixWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer with different limits for different endpoints.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  def init(opts), do: opts
  
  def call(conn, opts \\ []) do
    identifier = get_rate_limit_identifier(conn)
    limits = get_rate_limits(conn, opts)
    
    case check_rate_limits(identifier, limits) do
      :allowed ->
        conn
        
      {:denied, retry_after} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_resp_header("x-ratelimit-limit", to_string(limits.limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> put_resp_header("x-ratelimit-reset", to_string(retry_after))
        |> json(%{
          error: "Rate limit exceeded",
          retry_after: retry_after,
          limit: limits.limit,
          window: limits.window
        })
        |> halt()
    end
  end
  
  defp get_rate_limit_identifier(conn) do
    cond do
      user = conn.assigns[:current_user] ->
        "user:#{user.id}"
      
      api_key = get_req_header(conn, "x-api-key") |> List.first() ->
        "api_key:#{hash_api_key(api_key)}"
      
      true ->
        "ip:#{get_client_ip(conn)}"
    end
  end
  
  defp get_rate_limits(conn, opts) do
    # Default limits
    default_limits = %{
      limit: 1000,  # requests per window
      window: 3600  # window in seconds (1 hour)
    }
    
    # Path-specific limits
    path_limits = get_path_specific_limits(conn.request_path)
    
    # User role-based limits
    user_limits = get_user_role_limits(conn.assigns[:current_user])
    
    # Merge limits (most specific wins)
    default_limits
    |> Map.merge(Keyword.get(opts, :limits, %{}))
    |> Map.merge(path_limits)
    |> Map.merge(user_limits)
  end
  
  defp get_path_specific_limits(path) do
    cond do
      String.starts_with?(path, "/api/auth/login") ->
        %{limit: 5, window: 300}  # 5 attempts per 5 minutes
      
      String.starts_with?(path, "/api/auth/") ->
        %{limit: 50, window: 3600}  # 50 requests per hour for auth endpoints
      
      String.starts_with?(path, "/api/chaos/") ->
        %{limit: 10, window: 3600}  # Limited chaos engineering calls
      
      String.starts_with?(path, "/api/quantum/") ->
        %{limit: 100, window: 3600}  # Quantum operations
      
      String.starts_with?(path, "/api/ml/") ->
        %{limit: 200, window: 3600}  # ML endpoints
      
      String.starts_with?(path, "/api/v2/") ->
        %{limit: 500, window: 3600}  # Enhanced API endpoints
      
      String.starts_with?(path, "/api/") ->
        %{limit: 1000, window: 3600}  # General API endpoints
      
      true ->
        %{}  # Use defaults
    end
  end
  
  defp get_user_role_limits(nil), do: %{}
  defp get_user_role_limits(user) do
    case user.role do
      :admin ->
        %{limit: 10000, window: 3600}  # Higher limits for admins
      
      :operator ->
        %{limit: 5000, window: 3600}  # Higher limits for operators
      
      :premium ->
        %{limit: 2000, window: 3600}  # Higher limits for premium users
      
      _ ->
        %{}  # Use defaults for regular users
    end
  end
  
  defp check_rate_limits(identifier, limits) do
    bucket_name = "api:#{identifier}"
    window_ms = limits.window * 1000
    
    case Hammer.check_rate(bucket_name, window_ms, limits.limit) do
      {:allow, count} ->
        # Log rate limit usage
        log_rate_limit_usage(identifier, count, limits)
        :allowed
        
      {:deny, _limit} ->
        # Calculate retry-after time
        retry_after = calculate_retry_after(bucket_name, window_ms)
        log_rate_limit_exceeded(identifier, limits)
        {:denied, retry_after}
    end
  end
  
  defp calculate_retry_after(bucket_name, window_ms) do
    case Hammer.inspect_bucket(bucket_name, window_ms, 1) do
      {:ok, {_count, _count_remaining, ms_to_next_bucket, _created_at, _updated_at}} ->
        ceil(ms_to_next_bucket / 1000)
      
      _ ->
        60  # Default to 1 minute if we can't calculate
    end
  end
  
  defp hash_api_key(api_key) do
    :crypto.hash(:sha256, api_key) |> Base.encode16() |> String.slice(0, 16)
  end
  
  defp get_client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [ip_list] ->
        ip_list
        |> String.split(",")
        |> List.first()
        |> String.trim()
        
      [] ->
        case get_req_header(conn, "x-real-ip") do
          [ip] -> ip
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end
  
  defp log_rate_limit_usage(identifier, count, limits) do
    :telemetry.execute([:vsm_phoenix, :rate_limit, :usage], %{
      count: count,
      limit: limits.limit,
      remaining: limits.limit - count
    }, %{
      identifier: identifier,
      window: limits.window
    })
  end
  
  defp log_rate_limit_exceeded(identifier, limits) do
    :telemetry.execute([:vsm_phoenix, :rate_limit, :exceeded], %{count: 1}, %{
      identifier: identifier,
      limit: limits.limit,
      window: limits.window
    })
  end
end