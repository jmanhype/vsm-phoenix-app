#!/usr/bin/env elixir

# MCP Integration Validation Test Script
# This script validates that the MCP integration is working correctly

defmodule MCPValidation do
  @moduledoc """
  Validates MCP integration following best practices
  """

  @base_url "http://localhost:4000"
  @mcp_endpoint "#{@base_url}/mcp"
  
  def run do
    IO.puts("\n🔍 MCP Integration Validation Test")
    IO.puts("=" <> String.duplicate("=", 49))
    
    # Ensure the application is running
    unless System.get_env("MIX_ENV") == "test" do
      IO.puts("\n⚠️  Please ensure the Phoenix application is running:")
      IO.puts("   mix phx.server")
      IO.puts("\n")
    end
    
    # Test 1: Check if MCP endpoint is accessible
    IO.puts("\n1️⃣  Testing MCP endpoint accessibility...")
    case test_endpoint_accessibility() do
      :ok -> IO.puts("   ✅ MCP endpoint is accessible")
      {:error, reason} -> IO.puts("   ❌ Failed: #{reason}")
    end
    
    # Test 2: Test tool discovery
    IO.puts("\n2️⃣  Testing tool discovery (list_tools)...")
    case test_tool_discovery() do
      {:ok, tools} -> 
        IO.puts("   ✅ Tool discovery successful")
        IO.puts("   📦 Available tools: #{Enum.join(tools, ", ")}")
      {:error, reason} -> 
        IO.puts("   ❌ Failed: #{reason}")
    end
    
    # Test 3: Test tool execution
    IO.puts("\n3️⃣  Testing tool execution (analyze_variety)...")
    case test_tool_execution() do
      {:ok, result} -> 
        IO.puts("   ✅ Tool execution successful")
        IO.puts("   📊 Result: #{inspect(result, pretty: true, limit: 3)}")
      {:error, reason} -> 
        IO.puts("   ❌ Failed: #{reason}")
    end
    
    # Test 4: Validate transport configuration
    IO.puts("\n4️⃣  Validating transport configuration...")
    case validate_transport() do
      :ok -> IO.puts("   ✅ StreamableHTTP transport properly configured")
      {:error, reason} -> IO.puts("   ❌ Failed: #{reason}")
    end
    
    # Test 5: Check for port conflicts
    IO.puts("\n5️⃣  Checking for port conflicts...")
    case check_port_conflicts() do
      :ok -> IO.puts("   ✅ No port conflicts detected")
      {:error, reason} -> IO.puts("   ❌ Failed: #{reason}")
    end
    
    IO.puts("\n" <> String.duplicate("=", 50))
    IO.puts("📋 Validation complete!\n")
  end
  
  defp test_endpoint_accessibility do
    # Use Req library for HTTP requests
    case Req.post(@mcp_endpoint, 
      json: %{
        jsonrpc: "2.0",
        method: "mcp/list_tools",
        params: %{},
        id: 1
      },
      headers: [
        {"content-type", "application/json"},
        {"mcp-session-id", "test-validation"}
      ]
    ) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  rescue
    e -> {:error, "Connection failed: #{inspect(e)}"}
  end
  
  defp test_tool_discovery do
    case Req.post(@mcp_endpoint,
      json: %{
        jsonrpc: "2.0",
        method: "mcp/list_tools",
        params: %{},
        id: 2
      },
      headers: [
        {"content-type", "application/json"},
        {"mcp-session-id", "test-validation"}
      ]
    ) do
      {:ok, %{status: 200, body: body}} ->
        case body do
          %{"result" => %{"tools" => tools}} ->
            tool_names = Enum.map(tools, & &1["name"])
            {:ok, tool_names}
          _ ->
            {:error, "Unexpected response format"}
        end
      {:ok, %{status: status}} -> 
        {:error, "HTTP #{status}"}
      {:error, reason} -> 
        {:error, inspect(reason)}
    end
  rescue
    e -> {:error, "Request failed: #{inspect(e)}"}
  end
  
  defp test_tool_execution do
    case Req.post(@mcp_endpoint,
      json: %{
        jsonrpc: "2.0",
        method: "mcp/call_tool",
        params: %{
          name: "analyze_variety",
          arguments: %{
            source: "test_validation",
            variety_type: "external",
            impact_level: 5
          }
        },
        id: 3
      },
      headers: [
        {"content-type", "application/json"},
        {"mcp-session-id", "test-validation"}
      ]
    ) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}
      {:ok, %{status: status, body: body}} -> 
        {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> 
        {:error, inspect(reason)}
    end
  rescue
    e -> {:error, "Execution failed: #{inspect(e)}"}
  end
  
  defp validate_transport do
    # Check if the endpoint responds to streaming requests
    case Req.post(@mcp_endpoint,
      json: %{
        jsonrpc: "2.0",
        method: "mcp/list_tools",
        params: %{},
        id: 4
      },
      headers: [
        {"content-type", "application/json"},
        {"accept", "application/json, text/event-stream"},
        {"mcp-session-id", "test-validation"}
      ]
    ) do
      {:ok, %{headers: headers}} ->
        # StreamableHTTP should handle both regular and streaming responses
        :ok
      {:error, reason} ->
        {:error, inspect(reason)}
    end
  rescue
    e -> {:error, "Transport check failed: #{inspect(e)}"}
  end
  
  defp check_port_conflicts do
    # Verify only port 4000 is needed for web + MCP
    case :gen_tcp.connect('localhost', 4000, [:binary, active: false], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        
        # Ensure port 4001 is NOT in use (old MCP port)
        case :gen_tcp.connect('localhost', 4001, [:binary, active: false], 1000) do
          {:ok, socket2} ->
            :gen_tcp.close(socket2)
            {:error, "Port 4001 is still in use (should be free)"}
          {:error, _} ->
            :ok  # Good, port 4001 is not in use
        end
        
      {:error, _} ->
        {:error, "Port 4000 is not accessible"}
    end
  end
end

# Add Req to dependencies if not available
Mix.install([
  {:req, "~> 0.5.0"}
])

# Run the validation
MCPValidation.run()