#!/usr/bin/env elixir

Mix.install([
  {:jason, "~> 1.4"},
  {:plug_cowboy, "~> 2.5"},
  {:plug, "~> 1.14"}
])

defmodule McpHttpProxy do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  post "/mcp" do
    Logger.info("Received MCP request: #{inspect(conn.body_params)}")
    
    # Forward request to MCP server via stdio
    mcp_request = Jason.encode!(conn.body_params)
    
    # Start MCP server process and send request
    port = Port.open({:spawn, "./start_vsm_mcp_server.exs"}, [:binary, :exit_status])
    Port.command(port, mcp_request <> "\n")
    
    # Wait for response
    response = receive do
      {^port, {:data, data}} -> 
        Logger.info("MCP response: #{String.trim(data)}")
        case Jason.decode(String.trim(data)) do
          {:ok, json} -> json
          {:error, _} -> %{error: "Invalid JSON response"}
        end
      {^port, {:exit_status, _}} ->
        %{error: "MCP server exited"}
    after
      10_000 ->
        %{error: "Timeout waiting for MCP response"}
    end
    
    Port.close(port)
    
    conn = put_resp_content_type(conn, "application/json")
    send_resp(conn, 200, Jason.encode!(response))
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end

# Start HTTP server
{:ok, _} = Plug.Cowboy.http(McpHttpProxy, [])
Logger.info("🚀 MCP HTTP Proxy started on http://localhost:4000")
Logger.info("📡 Forwarding HTTP requests to MCP stdio server")
Logger.info("🧪 Ready for curl commands!")

Process.sleep(:infinity)