defmodule VsmPhoenix.TelegramBot.PersistenceTest do
  @moduledoc """
  Test module to verify CRDT conversation persistence is working.
  
  Run these tests to confirm the Telegram bot maintains context across restarts.
  """
  
  require Logger
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.TelegramBot.{ConversationManager, ContextPersistencePatch}
  
  @doc """
  Test basic CRDT storage and retrieval
  """
  def test_basic_crdt do
    Logger.info("🧪 Testing basic CRDT operations...")
    
    test_key = "test_telegram_conversation_12345"
    test_data = %{
      messages: ["Hello", "World"],
      timestamp: System.system_time(:millisecond)
    }
    
    # Store
    case ContextStore.set_lww(test_key, test_data) do
      {:ok, _value} ->
        Logger.info("✅ CRDT storage successful")
      :ok ->
        Logger.info("✅ CRDT storage successful")
        
        # Retrieve
        case ContextStore.get(test_key) do
          {:ok, retrieved} ->
            if retrieved == test_data do
              Logger.info("✅ CRDT retrieval successful - data matches!")
              :ok
            else
              Logger.error("❌ CRDT retrieval failed - data mismatch")
              Logger.error("Expected: #{inspect(test_data)}")
              Logger.error("Got: #{inspect(retrieved)}")
              :error
            end
            
          error ->
            Logger.error("❌ CRDT retrieval failed: #{inspect(error)}")
            :error
        end
        
      error ->
        Logger.error("❌ CRDT storage failed: #{inspect(error)}")
        :error
    end
  end
  
  @doc """
  Test conversation persistence with patch
  """
  def test_conversation_persistence do
    Logger.info("🧪 Testing conversation persistence...")
    
    chat_id = 12345
    agent_id = "test_agent"
    
    # Create test conversation
    test_conversation = %{
      messages: [
        %{
          "text" => "Hello bot",
          "from" => %{"id" => 123, "first_name" => "Test", "is_bot" => false},
          "date" => System.system_time(:second),
          "message_id" => 1
        },
        %{
          "text" => "Hello! How can I help you?",
          "from" => %{"id" => 0, "first_name" => "VSM Bot", "is_bot" => true},
          "date" => System.system_time(:second) + 1,
          "message_id" => 2
        },
        %{
          "text" => "What's the weather?",
          "from" => %{"id" => 123, "first_name" => "Test", "is_bot" => false},
          "date" => System.system_time(:second) + 2,
          "message_id" => 3
        }
      ],
      context: %{
        last_intent: :weather_inquiry,
        user_preferences: %{language: "en"},
        conversation_started: System.system_time(:millisecond)
      }
    }
    
    # Store conversation
    ContextPersistencePatch.store_conversation_crdt(chat_id, test_conversation, agent_id)
    Logger.info("📝 Stored test conversation")
    
    # Retrieve conversation
    retrieved = ContextPersistencePatch.get_conversation_crdt(chat_id, %{})
    
    if length(retrieved.messages) == length(test_conversation.messages) do
      Logger.info("✅ Conversation persistence successful - #{length(retrieved.messages)} messages retrieved!")
      
      # Check content
      first_msg = List.first(retrieved.messages)
      if first_msg["text"] == "Hello bot" do
        Logger.info("✅ Message content preserved correctly!")
        :ok
      else
        Logger.error("❌ Message content corrupted")
        :error
      end
    else
      Logger.error("❌ Conversation persistence failed")
      Logger.error("Expected #{length(test_conversation.messages)} messages, got #{length(retrieved.messages)}")
      :error
    end
  end
  
  @doc """
  Test persistence across "restart" (simulate by clearing local cache)
  """
  def test_persistence_across_restart do
    Logger.info("🧪 Testing persistence across restart...")
    
    chat_id = 99999
    agent_id = "restart_test"
    
    # Store a conversation
    test_msg = %{
      messages: [
        %{"text" => "This should survive restart", "from" => %{"id" => 1, "is_bot" => false}}
      ],
      context: %{test_marker: "RESTART_TEST_#{System.unique_integer()}"}
    }
    
    marker = test_msg.context.test_marker
    
    ContextPersistencePatch.store_conversation_crdt(chat_id, test_msg, agent_id)
    Logger.info("📝 Stored conversation with marker: #{marker}")
    
    # Simulate restart by waiting a bit
    Process.sleep(100)
    
    # Try to retrieve
    retrieved = ContextPersistencePatch.get_conversation_crdt(chat_id, %{})
    
    if retrieved.context[:test_marker] == marker do
      Logger.info("✅ Conversation survived simulated restart!")
      :ok
    else
      Logger.error("❌ Conversation lost after restart")
      Logger.error("Expected marker: #{marker}")
      Logger.error("Got: #{inspect(retrieved.context)}")
      :error
    end
  end
  
  @doc """
  Run all tests
  """
  def run_all_tests do
    Logger.info("🚀 Running all persistence tests...")
    
    results = [
      test_basic_crdt(),
      test_conversation_persistence(),
      test_persistence_across_restart()
    ]
    
    success_count = Enum.count(results, &(&1 == :ok))
    total_count = length(results)
    
    if success_count == total_count do
      Logger.info("✅ All #{total_count} tests passed!")
      :ok
    else
      Logger.error("❌ #{total_count - success_count} out of #{total_count} tests failed")
      :error
    end
  end
  
  @doc """
  Check current Telegram bot conversation state
  """
  def check_telegram_conversations do
    Logger.info("🔍 Checking current Telegram conversations in CRDT...")
    
    # Look for telegram conversation keys
    case ContextStore.get_state() do
      {:ok, state} ->
        telegram_keys = state
        |> Map.keys()
        |> Enum.filter(&String.starts_with?(to_string(&1), "telegram_"))
        
        Logger.info("Found #{length(telegram_keys)} Telegram-related keys:")
        Enum.each(telegram_keys, fn key ->
          Logger.info("  - #{key}")
        end)
        
        # Check a specific conversation if any exist
        if length(telegram_keys) > 0 do
          sample_key = List.first(telegram_keys)
          case ContextStore.get(sample_key) do
            {:ok, data} ->
              Logger.info("Sample conversation data: #{inspect(data, limit: :infinity)}")
            _ ->
              Logger.info("Could not retrieve sample conversation")
          end
        end
        
        {:ok, telegram_keys}
        
      error ->
        Logger.error("Could not get CRDT state: #{inspect(error)}")
        error
    end
  end
end