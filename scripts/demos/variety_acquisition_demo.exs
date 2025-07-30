#!/usr/bin/env elixir

# Variety Acquisition Demo
# Consolidates multiple variety acquisition demos into one configurable script

defmodule VarietyAcquisitionDemo do
  @moduledoc """
  Demonstrates VSM's cybernetic variety acquisition capabilities.
  
  Modes:
  - simple: Basic conceptual demonstration
  - live: Interactive step-by-step walkthrough
  - full: Complete demo with real MCP integration attempts
  """
  
  def run(mode \\ :simple) do
    IO.puts """
    🔄 VSM Variety Acquisition Demo
    ===============================
    Mode: #{mode}
    
    """
    
    case mode do
      :simple -> run_simple_demo()
      :live -> run_live_demo()
      :full -> run_full_demo()
      _ -> IO.puts "Invalid mode. Use: simple, live, or full"
    end
  end
  
  defp run_simple_demo do
    IO.puts "📊 Simple Variety Acquisition Concept"
    IO.puts "------------------------------------"
    
    # Simulate variety gap detection
    variety_gaps = [
      %{type: "data_processing", priority: :high, source: :system1},
      %{type: "natural_language", priority: :medium, source: :system4},
      %{type: "quantum_simulation", priority: :low, source: :system5}
    ]
    
    IO.puts "1️⃣ Detected Variety Gaps:"
    Enum.each(variety_gaps, fn gap ->
      IO.puts "   - #{gap.type} (priority: #{gap.priority})"
    end)
    
    IO.puts "\n2️⃣ Discovering MCP Servers..."
    Process.sleep(500)
    
    servers = [
      "filesystem-server (local files)",
      "sqlite-server (database queries)",
      "github-server (code analysis)"
    ]
    
    Enum.each(servers, fn server ->
      IO.puts "   ✓ Found: #{server}"
      Process.sleep(200)
    end)
    
    IO.puts "\n3️⃣ Matching Capabilities to Gaps..."
    IO.puts "   ✓ filesystem-server → data_processing gap"
    IO.puts "   ✓ github-server → natural_language gap"
    
    IO.puts "\n✅ Variety Acquisition Complete!"
    IO.puts "   System variety increased by 40%"
  end
  
  defp run_live_demo do
    IO.puts "🎮 Interactive Variety Acquisition Demo"
    IO.puts "--------------------------------------"
    
    steps = [
      {"System 1 reports operational stress", "😰 Pain signal detected!"},
      {"System 3 analyzes resource constraints", "📊 Current variety: 45/100"},
      {"System 4 scans for external variety", "🔍 Scanning MCP ecosystem..."},
      {"Discovering available MCP servers", "🌐 Found 15 compatible servers"},
      {"Analyzing capability matches", "🎯 3 servers match our gaps"},
      {"Initiating variety acquisition", "🔄 Integrating new capabilities..."},
      {"Variety successfully acquired", "✅ System variety: 75/100 (+30)"}
    ]
    
    Enum.each(steps, fn {description, output} ->
      IO.puts "\n#{description}..."
      Process.sleep(1000)
      IO.puts "   #{output}"
    end)
    
    IO.puts "\n🎉 Demo complete! The VSM has evolved."
  end
  
  defp run_full_demo do
    IO.puts "🚀 Full Variety Acquisition Demo with Real Integration"
    IO.puts "----------------------------------------------------"
    
    # Check current variety metrics
    IO.puts "\n📊 Current System Metrics:"
    current_variety = %{
      available_tools: 8,
      capability_coverage: 0.45,
      external_connections: 0
    }
    IO.inspect(current_variety, label: "Before acquisition")
    
    # Attempt real MCP discovery
    IO.puts "\n🔍 Attempting Real MCP Discovery..."
    
    case System.cmd("npm", ["search", "@modelcontextprotocol", "--json"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts "   ✅ Found MCP packages on NPM!"
        
        # Try to parse and show some results
        case Jason.decode(output) do
          {:ok, packages} when is_list(packages) ->
            packages
            |> Enum.take(3)
            |> Enum.each(fn pkg ->
              IO.puts "   - #{Map.get(pkg, "name", "unknown")}"
            end)
          _ ->
            IO.puts "   (Could not parse package list)"
        end
        
      {_, _} ->
        IO.puts "   ⚠️  NPM search failed (npm might not be installed)"
    end
    
    # Simulate integration
    IO.puts "\n🔧 Simulating MCP Server Integration..."
    
    new_capabilities = [
      "filesystem: Read/write any file",
      "sqlite: Query databases",
      "github: Analyze repositories"
    ]
    
    Enum.each(new_capabilities, fn cap ->
      Process.sleep(500)
      IO.puts "   + Adding: #{cap}"
    end)
    
    # Show improved metrics
    IO.puts "\n📊 Updated System Metrics:"
    updated_variety = %{
      available_tools: 11,  # 8 + 3
      capability_coverage: 0.75,  # Improved
      external_connections: 3
    }
    IO.inspect(updated_variety, label: "After acquisition")
    
    improvement = (0.75 - 0.45) * 100
    IO.puts "\n✅ Variety Improvement: +#{round(improvement)}%"
    IO.puts "🧬 The VSM has successfully evolved through variety acquisition!"
  end
end

# Parse command line arguments
mode = case System.argv() do
  ["--mode", mode_str] -> String.to_atom(mode_str)
  [] -> :simple
  _ -> 
    IO.puts "Usage: #{__ENV__.file} [--mode simple|live|full]"
    System.halt(1)
end

# Run the demo
VarietyAcquisitionDemo.run(mode)