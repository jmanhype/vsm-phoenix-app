defmodule VsmPhoenix.TelegramBot.ContextPersistencePatch do
  @moduledoc """
  URGENT PATCH: Integrates CRDT-based conversation persistence into the Telegram bot.
  
  This module provides functions to replace ETS-based conversation storage
  with distributed CRDT persistence that survives restarts and works across nodes.
  """
  
  require Logger
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.TelegramBot.ConversationManager
  
  @doc """
  Store a conversation message using CRDT instead of ETS.
  This replaces the ETS insert operations in telegram_agent.ex
  """
  def store_conversation_crdt(chat_id, conversation_state, agent_id) do
    # Use CRDT for persistent storage
    crdt_key = "telegram_conversation_#{chat_id}"
    
    # Store full conversation state in CRDT
    case ContextStore.set_lww(crdt_key, conversation_state) do
      {:ok, _value} ->
        Logger.debug("💾 Stored conversation #{chat_id} in CRDT")
        :ok
      :ok ->
        Logger.debug("💾 Stored conversation #{chat_id} in CRDT")
        :ok
        
      error ->
        Logger.error("❌ Failed to store conversation in CRDT: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Retrieve conversation from CRDT instead of ETS.
  This replaces the ETS lookup operations in telegram_agent.ex
  """
  def get_conversation_crdt(chat_id, _state) do
    crdt_key = "telegram_conversation_#{chat_id}"
    
    case ContextStore.get(crdt_key) do
      {:ok, mapset} when is_struct(mapset, MapSet) ->
        # Extract the actual conversation data from the LWW MapSet
        # The MapSet contains tuples like {key, actual_data}
        if MapSet.size(mapset) > 0 do
          {_key, conversation_state} = mapset |> Enum.at(0)
          
          # Ensure required fields exist
          validated_state = Map.merge(%{messages: [], context: %{}}, conversation_state)
          Logger.debug("✅ Retrieved conversation #{chat_id} from CRDT: #{length(validated_state.messages)} messages")
          validated_state
        else
          Logger.debug("Empty MapSet in CRDT for #{chat_id}, returning default")
          %{messages: [], context: %{}}
        end
        
      {:ok, conversation_state} when is_map(conversation_state) ->
        # Fallback for direct map data
        validated_state = Map.merge(%{messages: [], context: %{}}, conversation_state)
        Logger.debug("✅ Retrieved conversation #{chat_id} from CRDT: #{length(validated_state.messages)} messages")
        validated_state
        
      _ ->
        Logger.debug("No conversation found in CRDT for #{chat_id}, returning default")
        # No conversation found, return default
        %{messages: [], context: %{}}
    end
  end
  
  @doc """
  Store message history using CRDT.
  This replaces the ETS-based history storage.
  """
  def store_message_history_crdt(chat_id, new_message, agent_id) do
    history_key = "telegram_history_#{chat_id}"
    
    # Get existing history from CRDT
    existing_history = case ContextStore.get(history_key) do
      {:ok, history} when is_list(history) -> history
      _ -> []
    end
    
    # Add new message and limit to last 200 messages
    updated_history = [new_message | existing_history]
    |> Enum.take(200)
    
    # Store back in CRDT
    case ContextStore.set_lww(history_key, updated_history) do
      :ok ->
        Logger.debug("📜 Updated message history for chat #{chat_id}")
        
        # Also update in ConversationManager
        ConversationManager.store_message(chat_id, new_message, agent_id)
        
        :ok
        
      error ->
        Logger.error("❌ Failed to store message history: #{inspect(error)}")
        error
    end
  end
  
  @doc """
  Get message history from CRDT.
  """
  def get_message_history_crdt(chat_id, limit \\ 50) do
    history_key = "telegram_history_#{chat_id}"
    
    base_history = case ContextStore.get(history_key) do
      {:ok, history} when is_list(history) -> 
        Enum.take(history, limit)
      _ -> 
        []
    end
    
    # Enrich with ConversationManager data
    case ConversationManager.get_conversation_history(chat_id, limit: limit) do
      {:ok, rich_history} when is_list(rich_history) ->
        merge_histories(base_history, rich_history)
      _ ->
        base_history
    end
  end
  
  @doc """
  Initialize CRDT persistence for a Telegram agent.
  Call this instead of creating ETS tables.
  """
  def initialize_crdt_persistence(agent_id) do
    Logger.info("🔄 Initializing CRDT persistence for Telegram agent #{agent_id}")
    
    # Register agent with ConversationManager
    agent_key = "telegram_agent_#{agent_id}"
    ContextStore.add_to_set("telegram_agents", agent_key)
    
    # Initialize agent metadata
    metadata = %{
      agent_id: agent_id,
      initialized_at: System.system_time(:millisecond),
      node: node(),
      status: :active
    }
    
    ContextStore.set_lww(agent_key, metadata)
    
    Logger.info("✅ CRDT persistence initialized for agent #{agent_id}")
    :ok
  end
  
  @doc """
  Apply this patch to integrate CRDT persistence into telegram_agent.ex
  
  Replace these patterns in telegram_agent.ex:
  
  1. ETS table creation:
     OLD: :ets.new(conversation_table, [:set, :public, :named_table, {:read_concurrency, true}])
     NEW: ContextPersistencePatch.initialize_crdt_persistence(agent_id)
  
  2. Conversation lookup:
     OLD: case :ets.lookup(state.conversation_table, chat_id) do
     NEW: conversation_state = ContextPersistencePatch.get_conversation_crdt(chat_id, state)
  
  3. Conversation storage:
     OLD: :ets.insert(state.conversation_table, {chat_id, new_state})
     NEW: ContextPersistencePatch.store_conversation_crdt(chat_id, new_state, state.agent_id)
  
  4. History storage:
     OLD: :ets.insert(state.conversation_table, {history_key, new_history})
     NEW: ContextPersistencePatch.store_message_history_crdt(chat_id, new_message, state.agent_id)
  """
  def integration_instructions do
    """
    INTEGRATION STEPS:
    
    1. Add alias to telegram_agent.ex:
       alias VsmPhoenix.TelegramBot.ContextPersistencePatch
    
    2. In init/1, replace ETS table creation with:
       ContextPersistencePatch.initialize_crdt_persistence(agent_id)
    
    3. Replace get_conversation_state/2:
       defp get_conversation_state(chat_id, state) do
         ContextPersistencePatch.get_conversation_crdt(chat_id, state)
       end
    
    4. Replace update_conversation_state/3:
       defp update_conversation_state(chat_id, new_state, state) do
         ContextPersistencePatch.store_conversation_crdt(chat_id, new_state, state.agent_id)
       end
    
    5. Test with:
       - Send multiple messages to bot
       - Restart server
       - Send another message - bot should remember previous conversation!
    """
  end
  
  # Private functions
  
  defp merge_message_history(ets_messages, crdt_history) do
    # Combine messages from both sources, removing duplicates
    all_messages = ets_messages ++ Enum.map(crdt_history, &extract_message_data/1)
    
    all_messages
    |> Enum.uniq_by(&message_key/1)
    |> Enum.sort_by(&message_timestamp/1)
    |> Enum.take(-100)  # Keep last 100 messages
  end
  
  defp merge_histories(base, enriched) do
    # Merge two history lists intelligently
    base_map = Map.new(base, &{message_key(&1), &1})
    enriched_map = Map.new(enriched, &{message_key(&1), &1})
    
    Map.merge(base_map, enriched_map)
    |> Map.values()
    |> Enum.sort_by(&message_timestamp/1)
  end
  
  defp extract_message_data(%{message: data}), do: data
  defp extract_message_data(data), do: data
  
  defp message_key(%{"message_id" => id, "chat" => %{"id" => chat_id}}), do: {chat_id, id}
  defp message_key(%{message_id: id, chat_id: chat_id}), do: {chat_id, id}
  defp message_key(_), do: {:unknown, System.unique_integer()}
  
  defp message_timestamp(%{"date" => date}) when is_integer(date), do: date
  defp message_timestamp(%{timestamp: ts}), do: ts
  defp message_timestamp(_), do: 0
end