defmodule VsmPhoenixWeb.Plugs.APIAuthentication do
  @moduledoc """
  Authentication plug for API endpoints with multiple authentication methods.
  Supports JWT tokens, API keys, and session-based authentication.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  alias VsmPhoenix.Accounts
  alias VsmPhoenix.Auth.Guardian
  alias VsmPhoenixWeb.AuthPipeline
  
  def init(opts), do: opts
  
  def call(conn, opts \\ []) do
    conn
    |> try_jwt_authentication()
    |> try_api_key_authentication()
    |> try_session_authentication()
    |> handle_authentication_result(opts)
  end
  
  # Try JWT token authentication first
  defp try_jwt_authentication(conn) do
    case get_bearer_token(conn) do
      nil ->
        conn
      
      token ->
        case Guardian.decode_and_verify(token) do
          {:ok, claims} ->
            case Guardian.resource_from_claims(claims) do
              {:ok, user} ->
                conn
                |> assign(:current_user, user)
                |> assign(:auth_method, :jwt)
                |> assign(:authenticated, true)
                
              {:error, _reason} ->
                conn
                |> assign(:auth_error, :invalid_token)
            end
            
          {:error, reason} ->
            conn
            |> assign(:auth_error, reason)
        end
    end
  end
  
  # Try API key authentication
  defp try_api_key_authentication(%{assigns: %{authenticated: true}} = conn), do: conn
  defp try_api_key_authentication(conn) do
    case get_api_key(conn) do
      nil ->
        conn
      
      api_key ->
        case Accounts.authenticate_api_key(api_key) do
          {:ok, user} ->
            conn
            |> assign(:current_user, user)
            |> assign(:auth_method, :api_key)
            |> assign(:authenticated, true)
            
          {:error, _reason} ->
            conn
            |> assign(:auth_error, :invalid_api_key)
        end
    end
  end
  
  # Try session-based authentication
  defp try_session_authentication(%{assigns: %{authenticated: true}} = conn), do: conn
  defp try_session_authentication(conn) do
    case get_session(conn, :user_id) do
      nil ->
        conn
      
      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> assign(:auth_error, :session_invalid)
          
          user ->
            conn
            |> assign(:current_user, user)
            |> assign(:auth_method, :session)
            |> assign(:authenticated, true)
        end
    end
  end
  
  # Handle the final authentication result
  defp handle_authentication_result(%{assigns: %{authenticated: true}} = conn, _opts) do
    # Log successful authentication
    log_authentication_success(conn)
    conn
  end
  
  defp handle_authentication_result(conn, opts) do
    required = Keyword.get(opts, :required, true)
    
    if required do
      error = Map.get(conn.assigns, :auth_error, :unauthenticated)
      
      conn
      |> put_status(:unauthorized)
      |> json(%{error: format_auth_error(error)})
      |> halt()
    else
      # Optional authentication - continue without user
      conn
      |> assign(:current_user, nil)
      |> assign(:authenticated, false)
    end
  end
  
  # Helper functions
  
  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
  
  defp get_api_key(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key] -> api_key
      _ -> nil
    end
  end
  
  defp format_auth_error(:invalid_token), do: "Invalid or expired authentication token"
  defp format_auth_error(:invalid_api_key), do: "Invalid API key"
  defp format_auth_error(:session_invalid), do: "Invalid session"
  defp format_auth_error(:unauthenticated), do: "Authentication required"
  defp format_auth_error(_), do: "Authentication failed"
  
  defp log_authentication_success(conn) do
    user = conn.assigns.current_user
    method = conn.assigns.auth_method
    ip = get_client_ip(conn)
    
    :telemetry.execute([:vsm_phoenix, :auth, :success], %{count: 1}, %{
      user_id: user.id,
      method: method,
      ip: ip,
      path: conn.request_path
    })
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
end