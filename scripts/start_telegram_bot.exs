# Example script to start a Telegram bot agent
# Run with: mix run scripts/start_telegram_bot.exs

# Ensure the application is started
{:ok, _} = Application.ensure_all_started(:vsm_phoenix)

# Configuration from environment or defaults
bot_token = System.get_env("TELEGRAM_BOT_TOKEN")
unless bot_token do
  IO.puts("❌ Error: TELEGRAM_BOT_TOKEN environment variable not set!")
  IO.puts("Please set it with: export TELEGRAM_BOT_TOKEN='your-bot-token'")
  System.halt(1)
end

# Parse authorized and admin chats from environment
authorized_chats = case System.get_env("TELEGRAM_AUTHORIZED_CHATS") do
  nil -> []
  "" -> []
  chats -> 
    chats
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
end

admin_chats = case System.get_env("TELEGRAM_ADMIN_CHATS") do
  nil -> []
  "" -> []
  chats -> 
    chats
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
end

webhook_mode = System.get_env("TELEGRAM_WEBHOOK_MODE") == "true"
webhook_url = System.get_env("TELEGRAM_WEBHOOK_URL")

# Spawn the Telegram agent
IO.puts("🚀 Starting Telegram Bot Agent...")
IO.puts("   Mode: #{if webhook_mode, do: "Webhook", else: "Polling"}")
IO.puts("   Authorized chats: #{inspect(authorized_chats)}")
IO.puts("   Admin chats: #{inspect(admin_chats)}")

case VsmPhoenix.System1.Supervisor.spawn_agent(:telegram,
  id: "telegram_bot_main",
  config: %{
    bot_token: bot_token,
    webhook_mode: webhook_mode,
    webhook_url: webhook_url,
    authorized_chats: authorized_chats,
    admin_chats: admin_chats
  }
) do
  {:ok, agent} ->
    IO.puts("✅ Telegram Bot Agent started successfully!")
    IO.puts("   Agent ID: #{agent.id}")
    IO.puts("   PID: #{inspect(agent.pid)}")
    IO.puts("")
    IO.puts("📱 Bot is now running! Send /start to your bot on Telegram.")
    IO.puts("")
    IO.puts("To authorize your chat:")
    IO.puts("1. Send /start to the bot")
    IO.puts("2. Note your chat ID from the response")
    IO.puts("3. Add it to TELEGRAM_AUTHORIZED_CHATS environment variable")
    IO.puts("")
    IO.puts("Press Ctrl+C to stop...")
    
    # Keep the script running
    Process.sleep(:infinity)
    
  {:error, reason} ->
    IO.puts("❌ Failed to start Telegram Bot Agent: #{inspect(reason)}")
    System.halt(1)
end