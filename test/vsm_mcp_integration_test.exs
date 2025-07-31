defmodule VsmMcpIntegrationTest do
  @moduledoc """
  Integration tests for VSM MCP (Model Context Protocol) implementation.
  
  Tests verify:
  - HiveMindServer is running in supervision tree
  - MCP endpoints respond at /mcp/*
  - Tools can be called via HTTP
  - JSON-RPC protocol works correctly
  """
  
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  require Logger
  
  # Set up the endpoint for ConnTest
  @endpoint VsmPhoenixWeb.Endpoint
  
  # Test configuration
  @test_timeout 10_000
  @mcp_base_path "/mcp"
  
  setup do
    # Enable MCP servers for testing
    Application.put_env(:vsm_phoenix, :disable_mcp_servers, false)
    Application.put_env(:vsm_phoenix, :disable_magg, true)
    
    # Ensure the application is started
    {:ok, _} = Application.ensure_all_started(:vsm_phoenix)
    
    # Wait for processes to start
    Process.sleep(100)
    
    # Build base URL for HTTP requests
    port = Application.get_env(:vsm_phoenix, VsmPhoenixWeb.Endpoint)[:http][:port] || 4000
    base_url = "http://localhost:#{port}"
    
    on_exit(fn ->
      # Reset to test defaults
      Application.put_env(:vsm_phoenix, :disable_mcp_servers, true)
    end)
    
    {:ok, base_url: base_url}
  end
  
  describe "MCP Server Supervision" do
    test "HiveMindServer is running in supervision tree" do
      # Check if the server is registered
      assert Process.whereis(VsmPhoenix.MCP.HiveMindServer) != nil,
             "HiveMindServer should be registered and running"
      
      # Verify it's supervised
      children = Supervisor.which_children(VsmPhoenix.Supervisor)
      hive_mind_child = Enum.find(children, fn
        {VsmPhoenix.MCP.HiveMindServer, _, _, _} -> true
        _ -> false
      end)
      
      assert hive_mind_child != nil, "HiveMindServer should be in supervision tree"
      {_, pid, _, _} = hive_mind_child
      assert is_pid(pid) and Process.alive?(pid)
    end
  end
  
  describe "MCP HTTP Endpoints" do
    test "GET /mcp/health returns health status" do
      conn = build_conn()
      |> get("/mcp/health")
      
      assert json_response(conn, 200)
      assert conn.resp_body =~ "healthy"
      assert conn.resp_body =~ "mcp/1.0"
    end
    
    test "POST /mcp handles JSON-RPC list_tools request" do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "method" => "mcp/list_tools",
        "params" => %{},
        "id" => 1
      })
      
      response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert is_map(response["result"])
      assert is_list(response["result"]["tools"])
      
      # Verify expected tools
      tool_names = Enum.map(response["result"]["tools"], & &1["name"])
      assert "vsm_status" in tool_names
      assert "queen_decision" in tool_names
      assert "algedonic_signal" in tool_names
    end
    
    test "POST /mcp handles JSON-RPC call_tool request" do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "method" => "mcp/call_tool",
        "params" => %{
          "name" => "vsm_status",
          "arguments" => %{"system_level" => 5}
        },
        "id" => 2
      })
      
      response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 2
      assert is_map(response["result"])
      assert is_list(response["result"]["content"])
      
      # Verify the response contains status information
      content = hd(response["result"]["content"])
      assert content["type"] == "text"
      assert content["text"] =~ "running"
    end
    
    test "POST /mcp returns error for invalid method" do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "method" => "invalid_method",
        "params" => %{},
        "id" => 3
      })
      
      response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 3
      assert is_map(response["error"])
      assert response["error"]["code"] == -32601  # Method not found
    end
    
    test "OPTIONS /mcp returns CORS headers" do
      conn = build_conn()
      |> options("/mcp")
      
      assert conn.status == 204
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, OPTIONS"]
    end
  end
  
  describe "MCP Tools Integration" do
    test "vsm_status tool returns system information" do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "method" => "mcp/call_tool",
        "params" => %{
          "name" => "vsm_status",
          "arguments" => %{"system_level" => 3}
        },
        "id" => 4
      })
      
      response = json_response(conn, 200)
      content_text = hd(response["result"]["content"])["text"]
      status_data = Jason.decode!(content_text)
      
      assert status_data["status"] == "running"
      assert is_map(status_data["details"])
      assert status_data["details"]["type"] =~ "Control"
    end
    
    test "algedonic_signal tool processes signals" do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", %{
        "jsonrpc" => "2.0",
        "method" => "mcp/call_tool",
        "params" => %{
          "name" => "algedonic_signal",
          "arguments" => %{
            "signal" => "pleasure",
            "intensity" => 0.7,
            "context" => "Test signal"
          }
        },
        "id" => 5
      })
      
      response = json_response(conn, 200)
      content_text = hd(response["result"]["content"])["text"]
      signal_data = Jason.decode!(content_text)
      
      assert signal_data["status"] == "pleasure_signal_sent"
      assert signal_data["intensity"] == 0.7
    end
  end
end