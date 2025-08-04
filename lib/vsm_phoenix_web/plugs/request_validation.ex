defmodule VsmPhoenixWeb.Plugs.RequestValidation do
  @moduledoc """
  Request validation plug for enhanced API security.
  Validates request structure, content, and security headers.
  """
  
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  
  def init(opts), do: opts
  
  def call(conn, opts \\ []) do
    conn
    |> validate_content_type(opts)
    |> validate_request_size(opts)
    |> validate_security_headers(opts)
    |> validate_request_structure(opts)
    |> log_request_validation()
  end
  
  defp validate_content_type(conn, opts) do
    if conn.method in ["POST", "PUT", "PATCH"] do
      allowed_types = Keyword.get(opts, :allowed_content_types, [
        "application/json",
        "application/x-www-form-urlencoded",
        "multipart/form-data"
      ])
      
      content_type = get_content_type(conn)
      
      if content_type in allowed_types do
        conn
      else
        conn
        |> put_status(:unsupported_media_type)
        |> json(%{
          error: "Unsupported content type",
          allowed_types: allowed_types,
          received: content_type
        })
        |> halt()
      end
    else
      conn
    end
  end
  
  defp validate_request_size(conn, opts) do
    max_size = Keyword.get(opts, :max_request_size, 16 * 1024 * 1024)  # 16MB default
    
    case get_req_header(conn, "content-length") do
      [size_str] ->
        case Integer.parse(size_str) do
          {size, _} when size > max_size ->
            conn
            |> put_status(:request_entity_too_large)
            |> json(%{
              error: "Request entity too large",
              max_size: max_size,
              received_size: size
            })
            |> halt()
          
          _ ->
            conn
        end
      
      [] ->
        conn  # No content-length header
    end
  end
  
  defp validate_security_headers(conn, opts) do
    required_headers = Keyword.get(opts, :required_headers, [])
    
    missing_headers = Enum.filter(required_headers, fn header ->
      get_req_header(conn, header) == []
    end)
    
    if missing_headers == [] do
      conn
    else
      conn
      |> put_status(:bad_request)
      |> json(%{
        error: "Missing required headers",
        missing_headers: missing_headers
      })
      |> halt()
    end
  end
  
  defp validate_request_structure(conn, opts) do
    if conn.method in ["POST", "PUT", "PATCH"] and validate_json?(conn, opts) do
      case Jason.decode(conn.assigns[:raw_body] || "") do
        {:ok, _json} ->
          conn
        
        {:error, %Jason.DecodeError{}} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid JSON in request body"})
          |> halt()
      end
    else
      conn
    end
  end
  
  defp validate_json?(conn, opts) do
    Keyword.get(opts, :validate_json, true) and 
    get_content_type(conn) == "application/json"
  end
  
  defp get_content_type(conn) do
    case get_req_header(conn, "content-type") do
      [content_type] ->
        content_type
        |> String.split(";")
        |> List.first()
        |> String.trim()
      
      [] ->
        nil
    end
  end
  
  defp log_request_validation(conn) do
    :telemetry.execute([:vsm_phoenix, :request, :validated], %{count: 1}, %{
      method: conn.method,
      path: conn.request_path,
      content_type: get_content_type(conn),
      remote_ip: get_client_ip(conn)
    })
    
    conn
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