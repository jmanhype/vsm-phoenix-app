# Integration Showcase Demo
# 
# This demo showcases the integration of Telegram bots with the VSM system
# and demonstrates variety engineering principles in action.
#
# Prerequisites:
# 1. VSM Phoenix application running
# 2. A Telegram bot token (get from @BotFather)
# 3. ngrok or similar for webhook URL (if testing locally)
#
# Usage:
#   mix run examples/integration_showcase_demo.exs <bot_token> [webhook_url]

require Logger

defmodule IntegrationShowcase do
  @moduledoc """
  Demonstrates Telegram integration and variety engineering working together.
  """
  
  alias VsmPhoenix.System1.AgentManager
  alias VsmPhoenix.VarietyEngineering.Monitor
  
  def run(bot_token, webhook_url \\ nil) do
    Logger.info("🚀 Starting Integration Showcase Demo")
    
    # Step 1: Create a Telegram Agent
    Logger.info("📱 Creating Telegram Agent...")
    {:ok, agent_id} = create_telegram_agent(bot_token, webhook_url)
    
    # Step 2: Monitor variety engineering metrics
    Logger.info("📊 Starting variety engineering monitoring...")
    start_variety_monitoring()
    
    # Step 3: Simulate message flow through VSM hierarchy
    Logger.info("🔄 Simulating message flow through VSM...")
    simulate_vsm_flow(agent_id)
    
    # Step 4: Display variety engineering analysis
    Logger.info("📈 Analyzing variety balance...")
    analyze_variety_balance()
    
    # Step 5: Test webhook endpoint
    if webhook_url do
      Logger.info("🌐 Testing webhook endpoint...")
      test_webhook(bot_token)
    end
    
    Logger.info("✅ Demo complete! Check the logs for detailed metrics.")
  end
  
  defp create_telegram_agent(bot_token, webhook_url) do
    config = %{
      bot_token: bot_token,
      webhook_url: webhook_url,
      commands: [
        %{command: "status", description: "Get VSM system status"},
        %{command: "variety", description: "Check variety engineering metrics"},
        %{command: "policy", description: "Request policy decision from System 5"}
      ]
    }
    
    case AgentManager.create_agent(:telegram, "telegram_demo", config) do
      {:ok, agent_id} ->
        Logger.info("✅ Telegram agent created: #{agent_id}")
        
        # Set webhook if URL provided
        if webhook_url do
          webhook_endpoint = "#{webhook_url}/api/vsm/telegram/webhook/#{bot_token}"
          Logger.info("🔗 Setting webhook: #{webhook_endpoint}")
          # In real implementation, this would call Telegram API
        end
        
        {:ok, agent_id}
        
      {:error, reason} ->
        Logger.error("❌ Failed to create agent: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp start_variety_monitoring do
    # Subscribe to variety engineering events
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "variety:metrics")
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "variety:balance")
    
    # Start monitoring task
    Task.async(fn ->
      Enum.each(1..10, fn _ ->
        Process.sleep(2000)
        metrics = Monitor.get_current_metrics()
        Logger.info("📊 Variety Metrics: #{inspect(metrics, pretty: true)}")
      end)
    end)
  end
  
  defp simulate_vsm_flow(agent_id) do
    # Simulate messages at different levels
    messages = [
      # S1 level - operational messages
      %{level: 1, type: :customer_query, content: "What's the system status?"},
      %{level: 1, type: :sensor_data, content: "Temperature: 25°C"},
      
      # S2 level - coordination messages
      %{level: 2, type: :conflict_detection, content: "Resource contention detected"},
      
      # S3 level - control messages
      %{level: 3, type: :resource_allocation, content: "Reallocate CPU to critical tasks"},
      
      # S4 level - intelligence messages
      %{level: 4, type: :trend_analysis, content: "Usage trending upward 15%"},
      
      # S5 level - policy messages
      %{level: 5, type: :policy_update, content: "Prioritize stability over performance"}
    ]
    
    Enum.each(messages, fn msg ->
      Logger.info("📤 Sending #{msg.type} message at S#{msg.level}")
      
      # Simulate message propagation
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:s#{msg.level}",
        {:message, msg}
      )
      
      Process.sleep(1000)
    end)
  end
  
  defp analyze_variety_balance do
    # Get variety metrics from all levels
    balance_report = %{
      s1_variety: calculate_variety(:s1),
      s2_variety: calculate_variety(:s2),
      s3_variety: calculate_variety(:s3),
      s4_variety: calculate_variety(:s4),
      s5_variety: calculate_variety(:s5),
      filters: get_filter_effectiveness(),
      amplifiers: get_amplifier_effectiveness()
    }
    
    Logger.info("""
    
    📊 VARIETY ENGINEERING ANALYSIS
    ================================
    
    System Level Variety:
    - S1 (Operations): #{balance_report.s1_variety} bits
    - S2 (Coordination): #{balance_report.s2_variety} bits
    - S3 (Control): #{balance_report.s3_variety} bits
    - S4 (Intelligence): #{balance_report.s4_variety} bits
    - S5 (Policy): #{balance_report.s5_variety} bits
    
    Filter Effectiveness:
    - S1→S2: #{balance_report.filters.s1_to_s2}%
    - S2→S3: #{balance_report.filters.s2_to_s3}%
    - S3→S4: #{balance_report.filters.s3_to_s4}%
    - S4→S5: #{balance_report.filters.s4_to_s5}%
    
    Amplifier Effectiveness:
    - S5→S4: #{balance_report.amplifiers.s5_to_s4}x
    - S4→S3: #{balance_report.amplifiers.s4_to_s3}x
    - S3→S2: #{balance_report.amplifiers.s3_to_s2}x
    - S2→S1: #{balance_report.amplifiers.s2_to_s1}x
    
    Balance Status: #{calculate_balance_status(balance_report)}
    """)
  end
  
  defp test_webhook(bot_token) do
    # Simulate a Telegram webhook update
    update = %{
      "update_id" => :rand.uniform(1_000_000),
      "message" => %{
        "message_id" => :rand.uniform(10_000),
        "from" => %{
          "id" => 123456789,
          "first_name" => "Demo",
          "username" => "demo_user"
        },
        "chat" => %{
          "id" => 123456789,
          "type" => "private"
        },
        "date" => System.system_time(:second),
        "text" => "/status"
      }
    }
    
    # Make HTTP request to webhook endpoint
    url = "http://localhost:4000/api/vsm/telegram/webhook/#{bot_token}"
    headers = [{"Content-Type", "application/json"}]
    body = Jason.encode!(update)
    
    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 200}} ->
        Logger.info("✅ Webhook test successful")
        
      {:ok, response} ->
        Logger.warning("⚠️  Webhook returned: #{response.status_code}")
        
      {:error, reason} ->
        Logger.error("❌ Webhook test failed: #{inspect(reason)}")
    end
  end
  
  # Helper functions
  
  defp calculate_variety(level) do
    # Simulate variety calculation (Shannon entropy)
    # In real implementation, this would analyze actual message diversity
    case level do
      :s1 -> :rand.uniform(100) + 900  # High variety at operational level
      :s2 -> :rand.uniform(50) + 400
      :s3 -> :rand.uniform(30) + 200
      :s4 -> :rand.uniform(20) + 100
      :s5 -> :rand.uniform(10) + 50    # Low variety at policy level
    end
  end
  
  defp get_filter_effectiveness do
    # Simulate filter effectiveness percentages
    %{
      s1_to_s2: 70 + :rand.uniform(20),
      s2_to_s3: 60 + :rand.uniform(20),
      s3_to_s4: 65 + :rand.uniform(20),
      s4_to_s5: 75 + :rand.uniform(20)
    }
  end
  
  defp get_amplifier_effectiveness do
    # Simulate amplifier factors
    %{
      s5_to_s4: 3 + :rand.uniform(2),
      s4_to_s3: 2 + :rand.uniform(2),
      s3_to_s2: 3 + :rand.uniform(3),
      s2_to_s1: 5 + :rand.uniform(5)
    }
  end
  
  defp calculate_balance_status(report) do
    # Simple balance check based on Ashby's Law
    # Variety should decrease as we go up the hierarchy
    if report.s1_variety > report.s2_variety &&
       report.s2_variety > report.s3_variety &&
       report.s3_variety > report.s4_variety &&
       report.s4_variety > report.s5_variety do
      "✅ BALANCED (Ashby's Law satisfied)"
    else
      "⚠️  IMBALANCED (Variety mismatch detected)"
    end
  end
end

# Run the demo
case System.argv() do
  [bot_token] ->
    IntegrationShowcase.run(bot_token)
    
  [bot_token, webhook_url] ->
    IntegrationShowcase.run(bot_token, webhook_url)
    
  _ ->
    IO.puts("""
    Usage: mix run examples/integration_showcase_demo.exs <bot_token> [webhook_url]
    
    Arguments:
      bot_token    - Your Telegram bot token from @BotFather
      webhook_url  - Optional: Public URL for webhook (e.g., from ngrok)
    
    Example:
      mix run examples/integration_showcase_demo.exs "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
      mix run examples/integration_showcase_demo.exs "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11" "https://abc123.ngrok.io"
    """)
end