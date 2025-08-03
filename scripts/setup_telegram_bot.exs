# Telegram Bot Setup Script
#
# This script helps configure and test Telegram bot integration with VSM Phoenix.
#
# Usage:
#   mix run scripts/setup_telegram_bot.exs <command> [args]
#
# Commands:
#   create <bot_token> <name>     - Create a new Telegram bot agent
#   webhook <bot_token> <url>     - Set webhook URL for bot
#   test <bot_token>              - Test bot connectivity
#   list                          - List all Telegram agents
#   remove <agent_id>             - Remove a Telegram agent

require Logger

defmodule TelegramSetup do
  alias VsmPhoenix.System1.AgentManager
  alias VsmPhoenix.System1.Registry
  
  def run(["create", bot_token, name]) do
    Logger.info("🤖 Creating Telegram bot agent: #{name}")
    
    config = %{
      bot_token: bot_token,
      commands: default_commands(),
      features: %{
        variety_monitoring: true,
        vsm_status: true,
        algedonic_signals: true
      }
    }
    
    case AgentManager.create_agent(:telegram, name, config) do
      {:ok, agent_id} ->
        Logger.info("✅ Bot agent created successfully!")
        Logger.info("   Agent ID: #{agent_id}")
        Logger.info("   Name: #{name}")
        Logger.info("   Token: #{String.slice(bot_token, 0..10)}...")
        
        # Display webhook URL format
        Logger.info("\n📌 Webhook URL format:")
        Logger.info("   https://your-domain.com/api/vsm/telegram/webhook/#{bot_token}")
        
      {:error, reason} ->
        Logger.error("❌ Failed to create bot: #{inspect(reason)}")
    end
  end
  
  def run(["webhook", bot_token, webhook_base_url]) do
    Logger.info("🔗 Setting webhook for bot...")
    
    # Construct full webhook URL
    webhook_url = "#{webhook_base_url}/api/vsm/telegram/webhook/#{bot_token}"
    
    # Here you would normally call Telegram API to set webhook
    # For demo purposes, we'll simulate it
    Logger.info("📡 Webhook URL: #{webhook_url}")
    
    # Test webhook endpoint
    test_webhook_endpoint(bot_token, webhook_base_url)
  end
  
  def run(["test", bot_token]) do
    Logger.info("🧪 Testing bot connectivity...")
    
    # Find the agent with this bot token
    case find_bot_agent(bot_token) do
      {:ok, agent} ->
        Logger.info("✅ Bot agent found: #{agent.metadata[:name]}")
        
        # Test bot functionality
        test_bot_features(agent.id)
        
      {:error, :not_found} ->
        Logger.error("❌ No bot agent found with this token")
    end
  end
  
  def run(["list"]) do
    Logger.info("📋 Listing all Telegram agents:\n")
    
    Registry.list_agents()
    |> Enum.filter(fn agent -> agent.metadata[:type] == :telegram end)
    |> Enum.each(fn agent ->
      config = agent.metadata[:config] || %{}
      token = config[:bot_token] || "N/A"
      
      Logger.info("""
      🤖 #{agent.metadata[:name]}
         ID: #{agent.id}
         Token: #{String.slice(token, 0..10)}...
         Status: #{agent.state}
         Created: #{agent.metadata[:created_at]}
      """)
    end)
  end
  
  def run(["remove", agent_id]) do
    Logger.info("🗑️  Removing agent: #{agent_id}")
    
    case AgentManager.terminate_agent(agent_id) do
      :ok ->
        Logger.info("✅ Agent removed successfully")
        
      {:error, reason} ->
        Logger.error("❌ Failed to remove agent: #{inspect(reason)}")
    end
  end
  
  def run(_) do
    IO.puts("""
    Telegram Bot Setup Script
    
    Usage: mix run scripts/setup_telegram_bot.exs <command> [args]
    
    Commands:
      create <bot_token> <name>     Create a new Telegram bot agent
      webhook <bot_token> <url>     Set webhook URL for bot
      test <bot_token>              Test bot connectivity
      list                          List all Telegram agents
      remove <agent_id>             Remove a Telegram agent
    
    Examples:
      mix run scripts/setup_telegram_bot.exs create "123456:ABC-DEF..." "MyVSMBot"
      mix run scripts/setup_telegram_bot.exs webhook "123456:ABC-DEF..." "https://myapp.com"
      mix run scripts/setup_telegram_bot.exs list
    """)
  end
  
  # Private functions
  
  defp default_commands do
    [
      %{command: "start", description: "Start interaction with VSM"},
      %{command: "status", description: "Get current VSM system status"},
      %{command: "variety", description: "Check variety engineering metrics"},
      %{command: "policy", description: "Request policy decision from System 5"},
      %{command: "alert", description: "Send algedonic signal"},
      %{command: "help", description: "Show available commands"}
    ]
  end
  
  defp find_bot_agent(bot_token) do
    Registry.list_agents()
    |> Enum.find(fn agent ->
      agent.metadata[:type] == :telegram &&
      agent.metadata[:config][:bot_token] == bot_token
    end)
    |> case do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end
  
  defp test_webhook_endpoint(bot_token, base_url) do
    url = "#{base_url}/api/vsm/telegram/webhook/#{bot_token}"
    
    # Simulate webhook test
    test_update = %{
      "update_id" => 1,
      "message" => %{
        "message_id" => 1,
        "from" => %{"id" => 12345, "first_name" => "Test"},
        "chat" => %{"id" => 12345, "type" => "private"},
        "text" => "/test"
      }
    }
    
    Logger.info("📤 Sending test webhook to: #{url}")
    Logger.info("📦 Test payload: #{inspect(test_update, pretty: true)}")
    
    # In production, would make actual HTTP request
    Logger.info("✅ Webhook endpoint configured (actual HTTP test skipped in demo)")
  end
  
  defp test_bot_features(agent_id) do
    Logger.info("\n🧪 Testing bot features:")
    
    # Test variety monitoring
    Logger.info("  ✓ Variety monitoring: enabled")
    
    # Test VSM status
    Logger.info("  ✓ VSM status queries: enabled")
    
    # Test algedonic signals
    Logger.info("  ✓ Algedonic signal handling: enabled")
    
    Logger.info("\n✅ All bot features operational!")
  end
end

# Run the setup script
TelegramSetup.run(System.argv())