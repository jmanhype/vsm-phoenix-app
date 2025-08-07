defmodule VsmPhoenix.Infrastructure.TelegramService do
  @moduledoc """
  Service configuration for Telegram Bot API integration.
  Registers Telegram endpoints with the ServiceRegistry.
  """

  alias VsmPhoenix.Infrastructure.ServiceRegistry

  @telegram_paths %{
    get_me: "/bot{token}/getMe",
    send_message: "/bot{token}/sendMessage",
    answer_callback_query: "/bot{token}/answerCallbackQuery",
    set_webhook: "/bot{token}/setWebhook",
    delete_webhook: "/bot{token}/deleteWebhook",
    get_updates: "/bot{token}/getUpdates"
  }

  @doc """
  Register Telegram service with the registry.
  """
  def register_service(bot_token) do
    ServiceRegistry.register_service(:telegram, %{
      url: "https://api.telegram.org",
      paths: @telegram_paths,
      auth: {:path_param, :token, bot_token}
    })
  end

  @doc """
  Get URL for a specific Telegram API method.
  """
  def get_api_url(method, bot_token) do
    ServiceRegistry.get_service_path_url(:telegram, method, %{token: bot_token})
  end
end
