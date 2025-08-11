defmodule VsmPhoenix.Telegram.ApiClient do
  @moduledoc """
  SOLID: Single Responsibility - ONLY handles Telegram API communication
  DRY: Centralizes all Telegram API calls in one place
  """
  
  use VsmPhoenix.Behaviors.Loggable, prefix: "📱 TelegramAPI:"
  use VsmPhoenix.Behaviors.Resilient, max_retries: 3
  
  @base_url "https://api.telegram.org/bot"
  
  # DRY: Single configuration source
  defstruct [:bot_token, :timeout]
  
  def new(bot_token) do
    %__MODULE__{
      bot_token: bot_token,
      timeout: 30_000
    }
  end
  
  # DRY: Generic API call method - eliminates duplicate HTTP code
  defp call_api(client, method, params \\ %{}) do
    url = "#{@base_url}#{client.bot_token}/#{method}"
    
    with_resilience("telegram_api", fn ->
      case HTTPoison.post(url, Jason.encode!(params), 
                          [{"Content-Type", "application/json"}],
                          recv_timeout: client.timeout) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"ok" => true, "result" => result}} -> 
              {:ok, result}
            {:ok, %{"ok" => false, "description" => desc}} -> 
              {:error, desc}
            error -> 
              error
          end
        {:ok, %{status_code: code}} ->
          {:error, "HTTP #{code}"}
        error ->
          error
      end
    end)
  end
  
  # Clean API methods - each does ONE thing
  def send_message(client, chat_id, text, opts \\ []) do
    params = Map.merge(%{chat_id: chat_id, text: text}, Map.new(opts))
    call_api(client, "sendMessage", params)
  end
  
  def get_updates(client, offset \\ nil, timeout \\ 30) do
    params = %{timeout: timeout}
    params = if offset, do: Map.put(params, :offset, offset), else: params
    call_api(client, "getUpdates", params)
  end
  
  def set_webhook(client, url) do
    call_api(client, "setWebhook", %{url: url})
  end
  
  def delete_webhook(client) do
    call_api(client, "deleteWebhook")
  end
  
  def get_me(client) do
    call_api(client, "getMe")
  end
  
  def answer_callback_query(client, callback_id, opts \\ []) do
    params = Map.merge(%{callback_query_id: callback_id}, Map.new(opts))
    call_api(client, "answerCallbackQuery", params)
  end
  
  def edit_message(client, chat_id, message_id, text, opts \\ []) do
    params = Map.merge(%{
      chat_id: chat_id, 
      message_id: message_id,
      text: text
    }, Map.new(opts))
    call_api(client, "editMessageText", params)
  end
end