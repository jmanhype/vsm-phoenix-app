defmodule VsmPhoenix.TelegramBot.TelegramAgentCRDTFunctions do
  @moduledoc """
  Drop-in replacement functions for telegram_agent.ex to enable CRDT conversation persistence.
  
  Copy these functions into telegram_agent.ex to fix the context persistence issue.
  """
  
  alias VsmPhoenix.TelegramBot.ContextPersistencePatch
  require Logger
  
  # Add this alias to telegram_agent.ex:
  # alias VsmPhoenix.TelegramBot.ContextPersistencePatch
  
  @doc """
  REPLACE the get_conversation_state/2 function in telegram_agent.ex with this:
  """
  def get_conversation_state(chat_id, state) do
    # Use CRDT persistence instead of ETS
    ContextPersistencePatch.get_conversation_crdt(chat_id, state)
  end
  
  @doc """
  REPLACE the update_conversation_state/3 function in telegram_agent.ex with this:
  """
  def update_conversation_state(chat_id, new_state, state) do
    # Store in CRDT for persistence across restarts
    ContextPersistencePatch.store_conversation_crdt(chat_id, new_state, state.agent_id)
  end
  
  @doc """
  ADD this function to init/1 in telegram_agent.ex INSTEAD of creating ETS tables:
  """
  def initialize_persistence(agent_id) do
    # Initialize CRDT persistence instead of ETS tables
    ContextPersistencePatch.initialize_crdt_persistence(agent_id)
    
    # Return dummy table names for backward compatibility
    %{
      conversation_table: :crdt_backed,
      user_profiles_table: :crdt_backed,
      context_blocks_table: :crdt_backed,
      semantic_relationships_table: :crdt_backed,
      performance_tracking_table: :crdt_backed
    }
  end
  
  @doc """
  REPLACE the store_message_history/3 function with this:
  """
  def store_message_history(chat_id, message, state) do
    ContextPersistencePatch.store_message_history_crdt(chat_id, message, state.agent_id)
  end
  
  @doc """
  REPLACE the build_conversation_context/2 function with this enhanced version:
  """
  def build_conversation_context(chat_id, state) do
    # Get persistent conversation history from CRDT
    history = ContextPersistencePatch.get_message_history_crdt(chat_id, 10)
    
    # Get rich context from ConversationManager
    context = case VsmPhoenix.TelegramBot.ConversationManager.get_conversation_context(chat_id) do
      {:ok, ctx} -> ctx
      _ -> %{}
    end
    
    conversation_text = if history != [] do
      messages = Enum.map(history, fn msg ->
        role = if msg["from"]["is_bot"], do: "Bot", else: "User"
        text = msg["text"] || "[media]"
        "#{role}: #{text}"
      end)
      
      """
      Recent conversation:
      #{Enum.join(messages, "\n")}
      
      User preferences: #{inspect(context[:user_preferences] || %{})}
      Conversation topics: #{inspect(context[:conversation_topics] || [])}
      """
    else
      "No previous conversation history."
    end
    
    conversation_text
  end
  
  @doc """
  Example of how to modify init/1 in telegram_agent.ex:
  """
  def example_init_modification do
    """
    # In telegram_agent.ex init/1, replace ETS table creation with:
    
    # OLD CODE (REMOVE):
    conversation_table = :"telegram_conversations_\#{agent_id}"
    :ets.new(conversation_table, [:set, :public, :named_table, {:read_concurrency, true}])
    
    # NEW CODE (ADD):
    # Initialize CRDT persistence
    ContextPersistencePatch.initialize_crdt_persistence(agent_id)
    
    # For backward compatibility, set dummy values
    conversation_table = :crdt_backed
    user_profiles_table = :crdt_backed
    context_blocks_table = :crdt_backed
    semantic_relationships_table = :crdt_backed
    performance_tracking_table = :crdt_backed
    """
  end
  
  @doc """
  Test function to verify CRDT persistence is working
  """
  def test_persistence(chat_id, agent_id) do
    Logger.info("🧪 Testing CRDT persistence for chat #{chat_id}")
    
    # Store test conversation
    test_state = %{
      messages: [
        %{"text" => "Test message 1", "from" => %{"id" => 123, "is_bot" => false}},
        %{"text" => "Bot response 1", "from" => %{"id" => 0, "is_bot" => true}},
        %{"text" => "Test message 2", "from" => %{"id" => 123, "is_bot" => false}}
      ],
      context: %{
        test_time: System.system_time(:millisecond),
        agent: agent_id
      }
    }
    
    # Store it
    ContextPersistencePatch.store_conversation_crdt(chat_id, test_state, agent_id)
    
    # Retrieve it
    retrieved = ContextPersistencePatch.get_conversation_crdt(chat_id, %{})
    
    if retrieved.messages == test_state.messages do
      Logger.info("✅ CRDT persistence test PASSED!")
      :ok
    else
      Logger.error("❌ CRDT persistence test FAILED!")
      Logger.error("Expected: #{inspect(test_state.messages)}")
      Logger.error("Got: #{inspect(retrieved.messages)}")
      :error
    end
  end
end