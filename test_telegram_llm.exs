#!/usr/bin/env elixir

# Test script for Telegram-LLM integration
# Run with: mix run test_telegram_llm.exs

defmodule TelegramLLMTest do
  require Logger
  
  @telegram_api "https://api.telegram.org/bot7747520054:AAFNts5iJn8mYZezAG9uQF2_slvuztEScZI"
  
  def run do
    Logger.info("🧪 Starting Telegram-LLM integration test...")
    
    # First, get bot info
    case get_bot_info() do
      {:ok, bot_info} ->
        Logger.info("✅ Bot connected: @#{bot_info["username"]}")
        
        # Get recent messages to find a chat_id
        case get_updates() do
          {:ok, updates} when length(updates) > 0 ->
            # Find a chat to test with
            chat_id = get_test_chat_id(updates)
            if chat_id do
              Logger.info("📱 Using chat_id: #{chat_id}")
              run_conversation_test(chat_id)
            else
              Logger.error("❌ No suitable chat found for testing")
              Logger.info("💡 Send a message to the bot first, then run this test")
            end
            
          _ ->
            Logger.error("❌ No updates found")
            Logger.info("💡 Send a message to the bot first, then run this test")
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to connect to bot: #{inspect(reason)}")
    end
  end
  
  defp get_bot_info do
    case HTTPoison.get("#{@telegram_api}/getMe") do
      {:ok, %{status_code: 200, body: body}} ->
        %{"ok" => true, "result" => result} = Jason.decode!(body)
        {:ok, result}
      error ->
        {:error, error}
    end
  end
  
  defp get_updates do
    case HTTPoison.get("#{@telegram_api}/getUpdates") do
      {:ok, %{status_code: 200, body: body}} ->
        %{"ok" => true, "result" => updates} = Jason.decode!(body)
        {:ok, updates}
      error ->
        {:error, error}
    end
  end
  
  defp get_test_chat_id(updates) do
    # Find the most recent message with a chat_id
    updates
    |> Enum.reverse()
    |> Enum.find_value(fn update ->
      case update do
        %{"message" => %{"chat" => %{"id" => chat_id}}} -> chat_id
        _ -> nil
      end
    end)
  end
  
  defp run_conversation_test(chat_id) do
    Logger.info("🚀 Starting conversation test...")
    
    # Test messages
    test_messages = [
      "Hello! Testing the VSM system.",
      "What is the current system status?",
      "Show me the active agents",
      "What can you help me with?",
      "Testing multiple messages in sequence"
    ]
    
    # Send test messages
    Enum.each(test_messages, fn message ->
      Logger.info("📤 Sending: #{message}")
      send_message(chat_id, message)
      
      # Wait a bit between messages
      Process.sleep(2000)
    end)
    
    Logger.info("✅ Test messages sent!")
    Logger.info("📱 Check your Telegram chat for responses")
    
    # Monitor for a bit to see responses
    monitor_responses(chat_id, 30)
  end
  
  defp send_message(chat_id, text) do
    body = Jason.encode!(%{
      "chat_id" => chat_id,
      "text" => text
    })
    
    HTTPoison.post(
      "#{@telegram_api}/sendMessage",
      body,
      [{"Content-Type", "application/json"}]
    )
  end
  
  defp monitor_responses(chat_id, seconds) do
    Logger.info("👀 Monitoring for responses for #{seconds} seconds...")
    
    start_time = System.monotonic_time(:second)
    last_update_id = get_latest_update_id()
    
    monitor_loop(chat_id, start_time, seconds, last_update_id)
  end
  
  defp monitor_loop(chat_id, start_time, max_seconds, last_update_id) do
    elapsed = System.monotonic_time(:second) - start_time
    
    if elapsed < max_seconds do
      # Get new updates
      case get_updates_after(last_update_id) do
        {:ok, updates} when length(updates) > 0 ->
          # Process new messages
          new_last_id = process_updates(updates, chat_id, last_update_id)
          Process.sleep(1000)
          monitor_loop(chat_id, start_time, max_seconds, new_last_id)
          
        _ ->
          Process.sleep(1000)
          monitor_loop(chat_id, start_time, max_seconds, last_update_id)
      end
    else
      Logger.info("⏱️  Monitoring complete")
    end
  end
  
  defp get_latest_update_id do
    case get_updates() do
      {:ok, updates} when length(updates) > 0 ->
        List.last(updates)["update_id"]
      _ ->
        0
    end
  end
  
  defp get_updates_after(update_id) do
    offset = update_id + 1
    case HTTPoison.get("#{@telegram_api}/getUpdates?offset=#{offset}") do
      {:ok, %{status_code: 200, body: body}} ->
        %{"ok" => true, "result" => updates} = Jason.decode!(body)
        {:ok, updates}
      error ->
        {:error, error}
    end
  end
  
  defp process_updates(updates, chat_id, last_id) do
    updates
    |> Enum.filter(fn update ->
      update["update_id"] > last_id and
      get_in(update, ["message", "chat", "id"]) == chat_id
    end)
    |> Enum.each(fn update ->
      if message = update["message"] do
        from = message["from"]["username"] || "Bot"
        text = message["text"] || "[No text]"
        Logger.info("📨 #{from}: #{text}")
      end
    end)
    
    # Return the latest update_id
    case List.last(updates) do
      %{"update_id" => id} -> id
      _ -> last_id
    end
  end
end

# Run the test
TelegramLLMTest.run()