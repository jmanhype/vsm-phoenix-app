#!/usr/bin/env elixir

# MAGG Integration Demo for VSM Phoenix
# 
# This script demonstrates how VSM uses MAGG to discover and integrate
# external MCP servers for autonomous variety acquisition.
#
# Prerequisites:
# 1. Install MAGG: npm install -g magg
# 2. Start VSM Phoenix: iex -S mix phx.server

require Logger

defmodule MaggIntegrationDemo do
  alias VsmPhoenix.MCP.{MaggWrapper, MaggIntegration, ExternalClient}
  
  def run do
    IO.puts("\n🚀 VSM MAGG Integration Demo")
    IO.puts("="^50)
    
    # Step 1: Check MAGG availability
    check_magg_availability()
    
    # Step 2: Discover MCP servers
    discover_servers()
    
    # Step 3: Demonstrate variety acquisition
    acquire_variety()
    
    # Step 4: Execute external tools
    execute_external_tools()
    
    # Step 5: List connected servers
    list_connected_servers()
    
    IO.puts("\n✅ Demo Complete!")
  end
  
  defp check_magg_availability do
    IO.puts("\n📍 Step 1: Checking MAGG CLI availability...")
    
    case MaggWrapper.check_availability() do
      {:ok, info} ->
        IO.puts("✅ MAGG CLI found:")
        IO.puts("   Binary: #{info.binary}")
        IO.puts("   Version: #{info.version}")
      
      {:error, message} ->
        IO.puts("❌ MAGG CLI not found!")
        IO.puts("   #{message}")
        IO.puts("\n⚠️  Please install MAGG before continuing.")
        System.halt(1)
    end
  end
  
  defp discover_servers do
    IO.puts("\n📍 Step 2: Discovering MCP servers...")
    
    capabilities = [
      "weather data",
      "database operations",
      "file system access",
      "git repository management",
      "API testing"
    ]
    
    Enum.each(capabilities, fn capability ->
      IO.puts("\n🔍 Searching for: #{capability}")
      
      case MaggIntegration.discover_servers(capability) do
        {:ok, servers} when length(servers) > 0 ->
          IO.puts("   Found #{length(servers)} servers:")
          
          Enum.take(servers, 3)
          |> Enum.each(fn server ->
            tools = server["tools"] || []
            IO.puts("   - #{server["name"]}")
            IO.puts("     #{server["description"] || "No description"}")
            if length(tools) > 0 do
              IO.puts("     Tools: #{Enum.join(tools, ", ")}")
            end
          end)
        
        {:ok, []} ->
          IO.puts("   No servers found for this capability")
        
        {:error, reason} ->
          IO.puts("   Error: #{inspect(reason)}")
      end
    end)
  end
  
  defp acquire_variety do
    IO.puts("\n📍 Step 3: Demonstrating autonomous variety acquisition...")
    
    # Simulate a capability gap
    capability_need = "weather forecasting API"
    
    IO.puts("\n🎯 VSM detected capability gap: #{capability_need}")
    IO.puts("🔄 Initiating autonomous variety acquisition...")
    
    case MaggIntegration.acquire_variety_for_capability(capability_need) do
      {:ok, result} ->
        IO.puts("\n✅ Successfully acquired variety!")
        IO.puts("   Server: #{result.server["server"]}")
        IO.puts("   Status: #{result.server["status"]}")
        IO.puts("   Available tools: #{Enum.join(result.tools || [], ", ")}")
      
      {:error, reason} ->
        IO.puts("\n❌ Failed to acquire variety: #{inspect(reason)}")
    end
  end
  
  defp execute_external_tools do
    IO.puts("\n📍 Step 4: Executing tools on external MCP servers...")
    
    # Try to execute a tool if we have any connected servers
    case MaggIntegration.list_connected_servers() do
      servers when length(servers) > 0 ->
        server = hd(servers)
        
        if length(server["tools"]) > 0 do
          tool_name = hd(server["tools"])
          IO.puts("\n🔧 Executing tool '#{tool_name}' on #{server["server"]}")
          
          case MaggIntegration.execute_external_tool(
            server["server"], 
            tool_name, 
            %{"test" => "parameter"}
          ) do
            {:ok, result} ->
              IO.puts("✅ Tool execution successful!")
              IO.puts("   Result: #{inspect(result)}")
            
            {:error, reason} ->
              IO.puts("❌ Tool execution failed: #{inspect(reason)}")
          end
        else
          IO.puts("\n⚠️  No tools available on connected servers")
        end
      
      [] ->
        IO.puts("\n⚠️  No servers connected yet")
    end
  end
  
  defp list_connected_servers do
    IO.puts("\n📍 Step 5: Listing all connected external MCP servers...")
    
    servers = MaggIntegration.list_connected_servers()
    
    if length(servers) > 0 do
      IO.puts("\n📊 Connected Servers:")
      
      Enum.each(servers, fn server ->
        IO.puts("\n   #{server["server"]}")
        IO.puts("   Status: #{server["status"]}")
        IO.puts("   Transport: #{server["transport"]}")
        IO.puts("   Tools: #{length(server["tools"])}")
        
        if length(server["tools"]) > 0 do
          IO.puts("   Available: #{Enum.join(Enum.take(server["tools"], 3), ", ")}...")
        end
      end)
    else
      IO.puts("\n   No external servers currently connected")
    end
  end
end

# Run the demo
MaggIntegrationDemo.run()