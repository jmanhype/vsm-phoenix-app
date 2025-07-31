defmodule VsmPhoenixWeb.MCPControllerTest do
  use VsmPhoenixWeb.ConnCase
  
  describe "MCP endpoints" do
    test "GET /mcp/health returns MCP service health", %{conn: conn} do
      conn = get(conn, ~p"/mcp/health")
      
      assert json_response(conn, 200)
      assert response = json_response(conn, 200)
      assert response["status"] == "healthy"
      assert response["protocol"] == "mcp/1.0"
      assert response["transport"] == "http"
      assert response["capabilities"]["json_rpc"] == "2.0"
    end
    
    test "OPTIONS /mcp/rpc returns CORS headers", %{conn: conn} do
      conn = options(conn, ~p"/mcp/rpc")
      
      assert response(conn, 204)
      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
      assert get_resp_header(conn, "access-control-allow-methods") == ["GET, POST, OPTIONS"]
    end
    
    test "POST /mcp/rpc with initialize method", %{conn: conn} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{}
      }
      
      conn = 
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mcp/rpc", request)
      
      assert response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert response["result"]["protocolVersion"] == "1.0"
      assert response["result"]["capabilities"]["tools"]["enabled"] == true
      assert response["result"]["serverInfo"]["name"] == "vsm-phoenix-mcp"
    end
    
    test "POST /mcp/rpc with ping method", %{conn: conn} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "ping",
        "params" => %{}
      }
      
      conn = 
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mcp/rpc", request)
      
      assert response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 2
      assert response["result"]["pong"] == true
    end
    
    test "POST /mcp/rpc with list_tools method", %{conn: conn} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 3,
        "method" => "list_tools",
        "params" => %{}
      }
      
      conn = 
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mcp/rpc", request)
      
      assert response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 3
      assert tools = response["result"]["tools"]
      assert is_list(tools)
      
      # Check for VSM-specific tools
      tool_names = Enum.map(tools, & &1["name"])
      assert "vsm_status" in tool_names
      assert "queen_decision" in tool_names
      assert "algedonic_signal" in tool_names
    end
    
    test "POST /mcp/rpc with invalid JSON returns parse error", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mcp/rpc", "invalid json")
      
      assert response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["error"]["code"] == -32700
      assert response["error"]["message"] == "Parse error"
    end
    
    test "POST /mcp/rpc with invalid method returns method not found", %{conn: conn} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "invalid_method",
        "params" => %{}
      }
      
      conn = 
        conn
        |> put_req_header("content-type", "application/json")
        |> post(~p"/mcp/rpc", request)
      
      assert response = json_response(conn, 200)
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 4
      assert response["error"]["code"] == -32601
      assert response["error"]["message"] == "Method not found"
    end
  end
end