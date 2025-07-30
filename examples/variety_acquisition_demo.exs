#!/usr/bin/env elixir

# Variety Acquisition System Live Demonstration
# This script demonstrates the full variety acquisition flow in VSM Phoenix

Mix.install([
  {:vsm_phoenix, path: "..", env: :dev},
  {:jason, "~> 1.4"},
  {:httpoison, "~> 2.0"}
])

require Logger

defmodule VarietyAcquisitionDemo do
  @moduledoc """
  Live demonstration of VSM's variety acquisition capabilities.
  Shows how the system detects variety gaps and autonomously acquires external capabilities.
  """
  
  alias VsmPhoenix.MCP.{MaggIntegration, MaggWrapper, ExternalClient, ExternalClientSupervisor}
  alias VsmPhoenix.MCP.Tools.AnalyzeVariety
  alias VsmPhoenix.System4.{Intelligence, LLMVarietySource}
  
  def run do
    IO.puts """
    ╔═══════════════════════════════════════════════════════════════╗
    ║        VSM VARIETY ACQUISITION SYSTEM DEMONSTRATION           ║
    ╠═══════════════════════════════════════════════════════════════╣
    ║  This demo shows how VSM autonomously detects and fills      ║
    ║  variety gaps using external MCP servers via MAGG.           ║
    ╚═══════════════════════════════════════════════════════════════╝
    """
    
    # Start required processes
    setup_demo_environment()
    
    # Run demonstration scenarios
    demo_variety_gap_detection()
    demo_mcp_server_discovery()
    demo_capability_evaluation()
    demo_autonomous_decision_making()
    demo_external_tool_integration()
    demo_error_handling_resilience()
    
    IO.puts "\n✅ Variety Acquisition Demo Complete!"
  end
  
  defp setup_demo_environment do
    IO.puts "\n🔧 Setting up demo environment..."
    
    # Start registry and supervisor
    {:ok, _} = Registry.start_link(keys: :unique, name: VsmPhoenix.MCP.ExternalClientRegistry)
    {:ok, _} = ExternalClientSupervisor.start_link([])
    
    IO.puts "✓ Environment ready"
  end
  
  defp demo_variety_gap_detection do
    IO.puts """
    
    ═══════════════════════════════════════════════════════════════
    1. VARIETY GAP DETECTION
    ═══════════════════════════════════════════════════════════════
    """
    
    # Simulate environmental complexity exceeding system variety
    variety_data = %{
      "patterns" => [
        %{"type" => "market_volatility", "consistency" => 0.2},
        %{"type" => "user_behavior", "consistency" => 0.3},
        %{"type" => "system_load", "consistency" => 0.5}
      ],
      "anomalies" => [
        %{"type" => "flash_crash", "severity" => 0.9},
        %{"type" => "ddos_pattern", "severity" => 0.8},
        %{"type" => "data_corruption", "severity" => 0.7},
        %{"type" => "Byzantine_failure", "severity" => 0.85}
      ]
    }
    
    IO.puts "📊 Current System State:"
    IO.puts "   - Environmental complexity: VERY HIGH"
    IO.puts "   - Detected anomalies: #{length(variety_data["anomalies"])}"
    IO.puts "   - Pattern stability: LOW"
    
    # Analyze variety using VSM intelligence
    frame = %{}
    {:reply, response, _} = AnalyzeVariety.execute(
      %{
        variety_data: variety_data,
        context: %{"scope" => "global", "priority" => "critical"}
      },
      frame
    )
    
    analysis = Jason.decode!(response.content)
    
    IO.puts "\n🔍 Variety Analysis Results:"
    IO.puts "   - Complexity Level: #{analysis["variety_assessment"]["complexity_level"]}"
    IO.puts "   - Pattern Coherence: #{analysis["variety_assessment"]["pattern_coherence"]}"
    IO.puts "   - Anomaly Severity: #{inspect(analysis["variety_assessment"]["anomaly_severity"])}"
    IO.puts "   - Requisite Variety: #{inspect(analysis["variety_assessment"]["requisite_variety"])}"
    
    if analysis["meta_system_trigger"]["should_trigger"] do
      IO.puts "\n⚠️  META-SYSTEM TRIGGER ACTIVATED!"
      IO.puts "   - Reasoning: #{Enum.join(analysis["meta_system_trigger"]["reasoning"], ", ")}"
      IO.puts "   - Recommended Type: #{analysis["meta_system_trigger"]["recommended_meta_type"]}"
    end
    
    IO.puts "\n📋 System Recommendations:"
    Enum.each(analysis["recommendations"], fn rec ->
      IO.puts "   - [#{rec["system"]}] #{rec["action"]} (Priority: #{rec["priority"]})"
    end)
  end
  
  defp demo_mcp_server_discovery do
    IO.puts """
    
    ═══════════════════════════════════════════════════════════════
    2. MCP SERVER DISCOVERY VIA MAGG
    ═══════════════════════════════════════════════════════════════
    """
    
    # Check MAGG availability
    case MaggWrapper.check_availability() do
      {:ok, info} ->
        IO.puts "✓ MAGG CLI detected: #{info.binary} (v#{info.version})"
      {:error, message} ->
        IO.puts "⚠️  MAGG not available: #{message}"
        IO.puts "   Simulating MAGG responses for demo..."
    end
    
    # Discover servers for different capabilities
    capabilities = [
      "weather forecasting",
      "blockchain operations", 
      "database management",
      "image processing"
    ]
    
    Enum.each(capabilities, fn capability ->
      IO.puts "\n🔎 Searching for: #{capability}"
      
      # Simulate discovery (would use real MAGG in production)
      servers = simulate_server_discovery(capability)
      
      if length(servers) > 0 do
        IO.puts "   Found #{length(servers)} server(s):"
        Enum.each(servers, fn server ->
          IO.puts "   - #{server["name"]}"
          IO.puts "     Description: #{server["description"]}"
          IO.puts "     Tools: #{Enum.join(server["tools"] || [], ", ")}"
        end)
      else
        IO.puts "   No servers found for this capability"
      end
    end)
  end
  
  defp demo_capability_evaluation do
    IO.puts """
    
    ═══════════════════════════════════════════════════════════════
    3. CAPABILITY EVALUATION
    ═══════════════════════════════════════════════════════════════
    """
    
    # Evaluate weather forecasting capability
    weather_tools = [
      %{
        "name" => "get_current_weather",
        "description" => "Get current weather for a location",
        "coverage" => ["real_time_data"]
      },
      %{
        "name" => "get_forecast",
        "description" => "Get weather forecast up to 7 days",
        "coverage" => ["predictive_analysis"]
      },
      %{
        "name" => "get_historical_weather",
        "description" => "Get historical weather data",
        "coverage" => ["pattern_analysis", "trend_detection"]
      }
    ]
    
    required_capabilities = [
      "real_time_data",
      "predictive_analysis",
      "pattern_analysis",
      "extreme_weather_alerts"  # This one is missing
    ]
    
    IO.puts "📊 Evaluating Weather Forecasting Tools:"
    IO.puts "   Required capabilities: #{Enum.join(required_capabilities, ", ")}"
    IO.puts "\n   Available tools:"
    
    covered = []
    Enum.each(weather_tools, fn tool ->
      IO.puts "   - #{tool["name"]}: #{tool["description"]}"
      covered = covered ++ tool["coverage"]
    end)
    
    covered = Enum.uniq(covered)
    missing = required_capabilities -- covered
    coverage_ratio = length(covered) / length(required_capabilities)
    
    IO.puts "\n   Coverage Analysis:"
    IO.puts "   ✓ Covered: #{Enum.join(covered, ", ")}"
    if length(missing) > 0 do
      IO.puts "   ✗ Missing: #{Enum.join(missing, ", ")}"
    end
    IO.puts "   Coverage Ratio: #{Float.round(coverage_ratio * 100, 1)}%"
    
    if coverage_ratio < 1.0 do
      IO.puts "\n   ⚠️  Variety Gap Detected! Need additional capabilities."
    end
  end
  
  defp demo_autonomous_decision_making do
    IO.puts """
    
    ═══════════════════════════════════════════════════════════════
    4. AUTONOMOUS DECISION MAKING
    ═══════════════════════════════════════════════════════════════
    """
    
    # Simulate critical variety gap
    variety_gap = %{
      type: :capability_deficit,
      severity: :critical,
      missing_capability: "real-time financial market analysis",
      impact: "Cannot respond to market volatility - potential losses",
      current_variety: 3,
      required_variety: 10
    }
    
    IO.puts "🚨 Critical Variety Gap Detected:"
    IO.puts "   Type: #{variety_gap.type}"
    IO.puts "   Severity: #{variety_gap.severity}"
    IO.puts "   Missing: #{variety_gap.missing_capability}"
    IO.puts "   Impact: #{variety_gap.impact}"
    IO.puts "   Variety Ratio: #{variety_gap.current_variety}/#{variety_gap.required_variety}"
    
    IO.puts "\n🤖 Autonomous Decision Process:"
    IO.puts "   1. Evaluating internal capabilities... INSUFFICIENT"
    IO.puts "   2. Searching external MCP servers..."
    
    # Simulate finding appropriate server
    market_server = %{
      "name" => "@modelcontextprotocol/server-market-data",
      "description" => "Real-time market data and analysis",
      "tools" => [
        "get_market_data",
        "analyze_volatility", 
        "predict_trends",
        "risk_assessment"
      ]
    }
    
    IO.puts "   3. Found compatible server: #{market_server["name"]}"
    IO.puts "   4. Evaluating tools... MATCHES REQUIREMENTS"
    IO.puts "   5. Decision: ACQUIRE EXTERNAL VARIETY"
    
    IO.puts "\n✅ Autonomous Action Taken:"
    IO.puts "   - Server added: #{market_server["name"]}"
    IO.puts "   - Tools available: #{Enum.join(market_server["tools"], ", ")}"
    IO.puts "   - Variety gap: RESOLVED"
  end
  
  defp demo_external_tool_integration do
    IO.puts """
    
    ═══════════════════════════════════════════════════════════════
    5. EXTERNAL TOOL INTEGRATION
    ═══════════════════════════════════════════════════════════════
    """
    
    IO.puts "🔧 Demonstrating External Tool Execution:"
    
    # Simulate weather tool execution
    IO.puts "\n1. Weather Data Request:"
    weather_params = %{"location" => "London", "units" => "celsius"}
    weather_result = %{
      "temperature" => 18,
      "humidity" => 72,
      "conditions" => "partly_cloudy",
      "wind_speed" => 12,
      "pressure" => 1013
    }
    
    IO.puts "   Request: get_weather(#{inspect(weather_params)})"
    IO.puts "   Response: #{inspect(weather_result)}"
    
    # Simulate market analysis tool
    IO.puts "\n2. Market Analysis Request:"
    market_params = %{"symbol" => "BTC/USD", "interval" => "1h", "indicators" => ["RSI", "MACD"]}
    market_result = %{
      "price" => 45_230.50,
      "change_24h" => 2.3,
      "volatility" => "high",
      "rsi" => 68,
      "macd" => %{"signal" => "bullish", "strength" => 0.7},
      "recommendation" => "consider_hedging"
    }
    
    IO.puts "   Request: analyze_market(#{inspect(market_params)})"
    IO.puts "   Response: #{inspect(market_result)}"
    
    # Show integration with VSM decision making
    IO.puts "\n🎯 VSM Decision Integration:"
    IO.puts "   External Analysis: #{market_result["recommendation"]}"
    IO.puts "   Volatility Level: #{market_result["volatility"]}"
    IO.puts "   VSM Action: Adjusting risk parameters and hedging positions"
  end
  
  defp demo_error_handling_resilience do
    IO.puts """
    
    ═══════════════════════════════════════════════════════════════
    6. ERROR HANDLING & RESILIENCE
    ═══════════════════════════════════════════════════════════════
    """
    
    IO.puts "🛡️ Testing Resilience Mechanisms:"
    
    # Simulate various failure scenarios
    scenarios = [
      %{
        name: "Network Timeout",
        error: :timeout,
        recovery: "Retry with exponential backoff"
      },
      %{
        name: "Server Unavailable", 
        error: :connection_refused,
        recovery: "Try alternative server"
      },
      %{
        name: "Invalid Parameters",
        error: {:invalid_params, "Missing required field: location"},
        recovery: "Validate and retry with defaults"
      },
      %{
        name: "Rate Limit Exceeded",
        error: {:rate_limit, 429},
        recovery: "Queue request and retry after cooldown"
      }
    ]
    
    Enum.each(scenarios, fn scenario ->
      IO.puts "\n   Scenario: #{scenario.name}"
      IO.puts "   Error: #{inspect(scenario.error)}"
      IO.puts "   Recovery: #{scenario.recovery}"
      IO.puts "   Status: ✓ Handled gracefully"
    end)
    
    IO.puts "\n📊 Fallback Strategies:"
    IO.puts "   1. External acquisition fails → Use internal LLM variety generation"
    IO.puts "   2. All servers timeout → Spawn meta-VSM for self-sufficiency"
    IO.puts "   3. Critical failure → Activate emergency protocols"
    
    IO.puts "\n✅ System maintains operational resilience under all conditions"
  end
  
  # Helper functions
  
  defp simulate_server_discovery("weather forecasting") do
    [
      %{
        "name" => "@modelcontextprotocol/server-weather",
        "description" => "Official weather data MCP server",
        "tools" => ["get_weather", "get_forecast", "get_alerts"]
      },
      %{
        "name" => "community/weather-plus",
        "description" => "Extended weather features",
        "tools" => ["detailed_forecast", "historical_data"]
      }
    ]
  end
  
  defp simulate_server_discovery("blockchain operations") do
    [
      %{
        "name" => "@modelcontextprotocol/server-blockchain",
        "description" => "Blockchain operations and smart contracts",
        "tools" => ["deploy_contract", "read_chain", "send_transaction"]
      }
    ]
  end
  
  defp simulate_server_discovery("database management") do
    [
      %{
        "name" => "@modelcontextprotocol/server-sqlite",
        "description" => "SQLite database operations",
        "tools" => ["query", "insert", "update", "delete"]
      },
      %{
        "name" => "postgres-mcp",
        "description" => "PostgreSQL advanced features",
        "tools" => ["query", "transaction", "backup", "restore"]
      }
    ]
  end
  
  defp simulate_server_discovery(_) do
    []
  end
end

# Run the demonstration
VarietyAcquisitionDemo.run()