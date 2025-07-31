defmodule VsmMcpImplementationTest do
  @moduledoc """
  Tests for VSM MCP implementation that verify:
  - HiveMindServer is the primary MCP server
  - MCPController handles HTTP requests
  - MCP tools are properly exposed
  - Routes are configured for /mcp/*
  """
  
  use ExUnit.Case, async: true
  
  describe "VSM MCP Server Implementation" do
    test "HiveMindServer module exists and is the primary MCP server" do
      assert Code.ensure_loaded?(VsmPhoenix.MCP.HiveMindServer)
      
      # Verify it's a GenServer
      assert function_exported?(VsmPhoenix.MCP.HiveMindServer, :start_link, 1)
      assert function_exported?(VsmPhoenix.MCP.HiveMindServer, :init, 1)
    end
    
    test "MCPController exists and handles JSON-RPC" do
      assert Code.ensure_loaded?(VsmPhoenixWeb.MCPController)
      
      # Check for expected controller actions
      exports = VsmPhoenixWeb.MCPController.__info__(:functions)
      assert {:handle, 2} in exports
      assert {:health, 2} in exports
      assert {:options, 2} in exports
    end
  end
  
  describe "MCP Tools" do
    test "VSM tools are available through MCPController" do
      # The tools are defined within MCPController, not as separate modules
      # We verify they exist by checking the controller handles them
      assert function_exported?(VsmPhoenixWeb.MCPController, :handle_list_tools, 2)
      assert function_exported?(VsmPhoenixWeb.MCPController, :handle_call_tool, 2)
    end
  end
  
  describe "MCP Routes" do
    test "MCP routes are configured in router" do
      routes = VsmPhoenixWeb.Router.__routes__()
      mcp_routes = Enum.filter(routes, fn route -> 
        String.starts_with?(route.path, "/mcp")
      end)
      
      # Verify essential MCP routes exist
      paths = Enum.map(mcp_routes, & &1.path)
      assert "/mcp" in paths
      assert "/mcp/health" in paths
      assert "/mcp/:path" in paths or "/mcp/*path" in paths
    end
  end
end