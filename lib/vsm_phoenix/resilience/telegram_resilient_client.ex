defmodule VsmPhoenix.Resilience.TelegramResilientClient do
  @moduledoc """
  Resilient Telegram API client with circuit breaker and retry logic.

  Wraps all Telegram HTTP operations with resilience patterns:
  - Circuit breaker for API protection
  - Exponential backoff retry
  - Rate limiting via bulkhead
  - Comprehensive error handling
  """

  require Logger
  alias VsmPhoenix.Resilience.IntegrationAdapter

  @telegram_base_url "https://api.telegram.org"

  @doc """
  Get bot information with resilience
  """
  def get_bot_info(bot_token) do
    path = "/bot#{bot_token}/getMe"

    case resilient_telegram_request(:get, path) do
      {:ok, %{"ok" => true, "result" => bot_info}} ->
        {:ok, bot_info}

      {:ok, %{"ok" => false, "description" => desc}} ->
        {:error, desc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Send message with resilience
  """
  def send_message(bot_token, chat_id, text, opts \\ []) do
    params =
      %{
        "chat_id" => chat_id,
        "text" => text,
        "parse_mode" => opts[:parse_mode] || "Markdown"
      }
      |> maybe_add_reply_markup(opts[:reply_markup])
      |> maybe_add_reply_to(opts[:reply_to_message_id])

    path = "/bot#{bot_token}/sendMessage"
    body = Jason.encode!(params)

    case resilient_telegram_request(:post, path, body) do
      {:ok, %{"ok" => true, "result" => message}} ->
        {:ok, message}

      {:ok, %{"ok" => false, "description" => desc}} ->
        {:error, desc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Set webhook with resilience
  """
  def set_webhook(bot_token, webhook_url) do
    params = %{"url" => webhook_url}
    path = "/bot#{bot_token}/setWebhook"
    body = Jason.encode!(params)

    case resilient_telegram_request(:post, path, body) do
      {:ok, %{"ok" => true}} ->
        {:ok, :webhook_set}

      {:ok, %{"ok" => false, "description" => desc}} ->
        {:error, desc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete webhook with resilience
  """
  def delete_webhook(bot_token) do
    path = "/bot#{bot_token}/deleteWebhook"
    body = Jason.encode!(%{})

    case resilient_telegram_request(:post, path, body) do
      {:ok, %{"ok" => true}} ->
        {:ok, :webhook_deleted}

      {:ok, %{"ok" => false, "description" => desc}} ->
        {:error, desc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get updates with resilience (for polling)
  """
  def get_updates(bot_token, offset \\ 0, limit \\ 100, timeout \\ 30) do
    params = %{
      "offset" => offset,
      "limit" => limit,
      "timeout" => timeout
    }

    path = "/bot#{bot_token}/getUpdates?" <> URI.encode_query(params)

    # Use longer timeout for polling requests
    case resilient_telegram_request(:get, path, "", [], timeout: (timeout + 5) * 1000) do
      {:ok, %{"ok" => true, "result" => updates}} ->
        {:ok, updates}

      {:ok, %{"ok" => false, "description" => desc}} ->
        {:error, desc}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions

  defp resilient_telegram_request(method, path, body \\ "", headers \\ [], opts \\ []) do
    url = @telegram_base_url <> path

    # Use bulkhead for rate limiting Telegram requests
    IntegrationAdapter.resilient_http_request(
      :external_api_client,
      method,
      url,
      body,
      [{"Content-Type", "application/json"} | headers],
      Keyword.merge(
        [
          timeout: 10_000,
          # Telegram polling can be slow
          recv_timeout: 35_000
        ],
        opts
      )
    )
    |> case do
      {:ok, {:ok, %{status: 200, body: response_body}}} ->
        {:ok, response_body}

      {:ok, {:ok, %{status: status, body: body}}} ->
        Logger.warning("Telegram API HTTP #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:error, :circuit_open} ->
        Logger.warning("⚡ Telegram API circuit breaker is open")
        {:error, :circuit_open}

      {:error, :bulkhead_full} ->
        Logger.warning("🛡️  Telegram API bulkhead is full")
        {:error, :rate_limited}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_reply_markup(params, nil), do: params
  defp maybe_add_reply_markup(params, markup), do: Map.put(params, "reply_markup", markup)

  defp maybe_add_reply_to(params, nil), do: params

  defp maybe_add_reply_to(params, message_id),
    do: Map.put(params, "reply_to_message_id", message_id)
end
