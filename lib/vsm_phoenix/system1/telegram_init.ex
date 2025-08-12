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
    # Check if Telegram bot token is configured
    telegram_config = Application.get_env(:vsm_phoenix, :vsm)[:telegram]
    
    if telegram_config && telegram_config[:bot_token] do
      Logger.info("🤖 Auto-spawning Telegram bot...")
      
      case VsmPhoenix.System1.Supervisor.spawn_agent(:telegram, 
        %{
          id: "telegram_main",
          bot_token: telegram_config[:bot_token],
          webhook_mode: telegram_config[:webhook_mode] || false,
          authorized_chats: telegram_config[:authorized_chats] || [],
          admin_chats: telegram_config[:admin_chats] || []
        }
      ) do
        {:ok, agent} ->
          Logger.info("✅ Telegram bot spawned: #{inspect(agent)}")
        {:error, reason} ->
          Logger.error("❌ Failed to spawn Telegram bot: #{inspect(reason)}")
          # Retry after 30 seconds
          Process.send_after(self(), :spawn_telegram, 30_000)
      end
    else
      Logger.info("📵 No Telegram bot token configured, skipping auto-spawn")
    end
    
    {:noreply, state}
  end
end