defmodule VsmPhoenixWeb.TelegramController do
  @moduledoc """
  Controller for handling Telegram webhook requests.
  
  This controller receives webhook updates from Telegram and
  forwards them to the appropriate TelegramAgent.
  """
  
  use VsmPhoenixWeb, :controller
  require Logger
  
  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.System1.Agents.TelegramAgent
  
  @doc """
  Handle incoming webhook updates from Telegram.
  
  The webhook URL should be configured as:
  https://yourdomain.com/api/telegram/webhook/:agent_id
  """
  def webhook(conn, %{"agent_id" => agent_id, "update_id" => _} = params) do
    Logger.info("Received Telegram webhook for agent: #{agent_id}")
    
    # Find the agent
    case Registry.lookup(agent_id) do
      {:ok, _pid, metadata} when metadata.type == :telegram ->
        # Forward update to the agent
        TelegramAgent.handle_update(agent_id, params)
        
        # Return success to Telegram
        conn
        |> put_status(:ok)
        |> json(%{ok: true})
        
      {:ok, _, _} ->
        Logger.error("Agent #{agent_id} is not a Telegram agent")
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid agent type"})
        
      {:error, :not_found} ->
        Logger.error("Telegram agent not found: #{agent_id}")
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})
    end
  end
  
  def webhook(conn, %{"agent_id" => agent_id}) do
    Logger.warning("Invalid webhook payload for agent: #{agent_id}")
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid update format"})
  end
  
  @doc """
  Health check endpoint for Telegram webhook.
  """
  def health(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{
      status: "healthy",
      service: "telegram_webhook",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
  
  @doc """
  Set webhook for a specific agent.
  This is a convenience endpoint for testing.
  """
  def set_webhook(conn, %{"agent_id" => agent_id, "webhook_url" => webhook_url}) do
    case Registry.lookup(agent_id) do
      {:ok, _pid, metadata} when metadata.type == :telegram ->
        case TelegramAgent.set_webhook(agent_id, webhook_url) do
          {:ok, _} ->
            conn
            |> put_status(:ok)
            |> json(%{ok: true, message: "Webhook set successfully"})
            
          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: reason})
        end
        
      {:ok, _, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid agent type"})
        
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Agent not found"})
    end
  end
end