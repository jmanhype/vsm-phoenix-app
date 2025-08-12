defmodule VsmPhoenix.System1.TelegramInit do
  @moduledoc """
  Automatically spawns Telegram agent on startup if configured.
  """
  
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Schedule initialization after system is ready
    Process.send_after(self(), :spawn_telegram, 5_000)
    {:ok, %{}}
  end
  
  @impl true
  def handle_info(:spawn_telegram, state) do
    # Check if bot already exists before spawning
    case Process.whereis(:telegram_agent_telegram_main) do
      nil ->
        # Bot doesn't exist, spawn it
        spawn_telegram_bot(state)
      pid when is_pid(pid) ->
        Logger.info("✅ Telegram bot already running: #{inspect(pid)}")
    end
    
    {:noreply, state}
  end
  
  defp spawn_telegram_bot(state) do
    # Check if Telegram bot token is configured
    telegram_config = Application.get_env(:vsm_phoenix, :vsm)[:telegram]
    
    # Try to get token from config or environment
    bot_token = case telegram_config do
      nil -> System.get_env("TELEGRAM_BOT_TOKEN") || "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
      config -> config[:bot_token] || System.get_env("TELEGRAM_BOT_TOKEN") || "7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
    end
    
    if bot_token do
      Logger.info("🤖 Auto-spawning Telegram bot with token...")
      
      case VsmPhoenix.System1.Supervisor.spawn_agent(:telegram, 
        %{
          id: "telegram_main",
          bot_token: bot_token,
          webhook_mode: false,
          authorized_chats: [],
          admin_chats: []
        }
      ) do
        {:ok, agent} ->
          Logger.info("✅ Telegram bot spawned: #{inspect(agent)}")
        {:error, {:already_started, pid}} ->
          Logger.info("✅ Telegram bot already started: #{inspect(pid)}")
        {:error, reason} ->
          Logger.error("❌ Failed to spawn Telegram bot: #{inspect(reason)}")
          # Retry after 30 seconds
          Process.send_after(self(), :spawn_telegram, 30_000)
      end
    else
      Logger.info("📵 No Telegram bot token configured, skipping auto-spawn")
    end
  end
end