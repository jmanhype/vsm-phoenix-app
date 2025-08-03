# Telegram Integration Demo
# 
# This script demonstrates how to integrate Telegram with the VSM system.
# It spawns a TelegramAgent that can receive commands and send alerts.
#
# Prerequisites:
# 1. Set TELEGRAM_BOT_TOKEN environment variable
# 2. Optionally set TELEGRAM_WEBHOOK_URL for webhook mode
#
# Usage:
#   TELEGRAM_BOT_TOKEN=your_bot_token mix run examples/telegram_integration_demo.exs

require Logger

defmodule TelegramIntegrationDemo do
  alias VsmPhoenix.System1.Supervisor, as: S1Supervisor
  alias VsmPhoenix.System1.Agents.TelegramAgent
  alias VsmPhoenix.System1.Registry
  
  def run do
    Logger.info("🤖 Telegram Integration Demo Starting...")
    
    # Check for bot token
    bot_token = System.get_env("TELEGRAM_BOT_TOKEN")
    unless bot_token do
      Logger.error("❌ TELEGRAM_BOT_TOKEN environment variable not set!")
      Logger.info("Please set it and run again:")
      Logger.info("  TELEGRAM_BOT_TOKEN=your_bot_token mix run #{__ENV__.file}")
      System.halt(1)
    end
    
    webhook_url = System.get_env("TELEGRAM_WEBHOOK_URL")
    webhook_mode = webhook_url != nil
    
    # Configuration
    config = %{
      bot_token: bot_token,
      webhook_mode: webhook_mode,
      webhook_url: webhook_url,
      # Add your chat ID here to authorize it by default
      authorized_chats: parse_chat_ids(System.get_env("TELEGRAM_AUTHORIZED_CHATS", "")),
      admin_chats: parse_chat_ids(System.get_env("TELEGRAM_ADMIN_CHATS", ""))
    }
    
    Logger.info("📋 Configuration:")
    Logger.info("  Mode: #{if webhook_mode, do: "Webhook", else: "Polling"}")
    if webhook_mode, do: Logger.info("  Webhook URL: #{webhook_url}")
    Logger.info("  Authorized chats: #{inspect(config.authorized_chats)}")
    Logger.info("  Admin chats: #{inspect(config.admin_chats)}")
    
    # Spawn TelegramAgent
    Logger.info("\n🚀 Spawning TelegramAgent...")
    case S1Supervisor.spawn_agent(:telegram, config: config) do
      {:ok, agent_info} ->
        Logger.info("✅ TelegramAgent spawned successfully!")
        Logger.info("  Agent ID: #{agent_info.id}")
        Logger.info("  PID: #{inspect(agent_info.pid)}")
        
        # Wait for bot to initialize
        Process.sleep(2000)
        
        # Demo: Send a welcome message if admin chat is configured
        if admin_chat = List.first(config.admin_chats) do
          Logger.info("\n📨 Sending welcome message to admin chat...")
          
          message = """
          🎉 *VSM Telegram Bot Initialized!*
          
          I'm now connected to the Viable System Model and ready to serve.
          
          Try these commands:
          • /help - See available commands
          • /status - Check system status
          • /vsm list - List active VSM instances
          
          _Agent: #{agent_info.id}_
          _Mode: #{if webhook_mode, do: "Webhook", else: "Polling"}_
          """
          
          case TelegramAgent.send_message(agent_info.id, admin_chat, message) do
            {:ok, _} ->
              Logger.info("✅ Welcome message sent!")
            {:error, reason} ->
              Logger.error("❌ Failed to send message: #{inspect(reason)}")
          end
        end
        
        # Demo: Simulate an alert
        Logger.info("\n🚨 Simulating a critical alert...")
        Phoenix.PubSub.broadcast(
          VsmPhoenix.PubSub,
          "vsm:alerts:critical",
          {:pubsub, :alert, %{
            level: "critical",
            source: "demo",
            message: "This is a test alert from the Telegram integration demo!",
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }}
        )
        
        # Show instructions
        Logger.info("\n📱 Bot is now running!")
        Logger.info("Open Telegram and send /start to your bot")
        if webhook_mode do
          Logger.info("Webhook is active at: #{webhook_url}")
        else
          Logger.info("Bot is polling for updates...")
        end
        
        Logger.info("\n⌨️  Available commands:")
        Logger.info("  /start - Initialize conversation")
        Logger.info("  /help - Show help")
        Logger.info("  /status - System status")
        Logger.info("  /vsm list - List VSM instances")
        Logger.info("  /vsm spawn <config> - Spawn new VSM")
        
        if Enum.any?(config.admin_chats) do
          Logger.info("\n👮 Admin commands:")
          Logger.info("  /alert <level> <message> - Broadcast alert")
          Logger.info("  /authorize <chat_id> - Authorize new chat")
        end
        
        # Keep the demo running
        Logger.info("\n⏸️  Press Ctrl+C to stop the demo...")
        
        # Monitor metrics
        spawn(fn ->
          monitor_loop(agent_info.id)
        end)
        
        # Keep process alive
        Process.sleep(:infinity)
        
      {:error, reason} ->
        Logger.error("❌ Failed to spawn TelegramAgent: #{inspect(reason)}")
        System.halt(1)
    end
  end
  
  defp parse_chat_ids(nil), do: []
  defp parse_chat_ids(""), do: []
  defp parse_chat_ids(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
    |> Enum.into(MapSet.new())
    |> MapSet.to_list()
  end
  
  defp monitor_loop(agent_id) do
    Process.sleep(30_000)  # Every 30 seconds
    
    case TelegramAgent.get_telegram_metrics(agent_id) do
      {:ok, metrics} ->
        if metrics.total_messages > 0 do
          Logger.info("\n📊 Telegram Bot Metrics:")
          Logger.info("  Messages received: #{metrics.messages_received}")
          Logger.info("  Messages sent: #{metrics.messages_sent}")
          Logger.info("  Commands processed: #{metrics.commands_processed}")
          Logger.info("  Message rate: #{metrics.message_rate}/min")
          
          if map_size(metrics.command_breakdown) > 0 do
            Logger.info("  Command breakdown:")
            Enum.each(metrics.command_breakdown, fn {cmd, count} ->
              Logger.info("    /#{cmd}: #{count}")
            end)
          end
        end
        
      _ ->
        :ok
    end
    
    monitor_loop(agent_id)
  end
end

# Run the demo
TelegramIntegrationDemo.run()