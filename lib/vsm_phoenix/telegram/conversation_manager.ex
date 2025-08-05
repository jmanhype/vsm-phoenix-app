defmodule VsmPhoenix.Telegram.ConversationManager do
  @moduledoc """
  Manages multi-turn conversations for the Telegram bot.
  
  Maintains conversation state, context preservation, and user preference learning
  to provide more intelligent and contextual responses.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.LLM.Service, as: LLMService
  
  @conversation_timeout :timer.minutes(30)
  @max_context_messages 10
  
  defmodule Conversation do
    @moduledoc false
    defstruct [
      :chat_id,
      :user_id,
      :username,
      :started_at,
      :last_activity,
      :context,
      :messages,
      :user_preferences,
      :active_flow,
      :flow_state,
      :pending_confirmations
    ]
  end
  
  defmodule Message do
    @moduledoc false
    defstruct [
      :role,  # :user or :assistant
      :content,
      :intent,
      :entities,
      :timestamp
    ]
  end
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Start or continue a conversation for a user.
  """
  def start_conversation(chat_id, user_info) do
    GenServer.call(__MODULE__, {:start_conversation, chat_id, user_info})
  end
  
  @doc """
  Add a message to the conversation and get context.
  """
  def add_message(chat_id, role, content, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:add_message, chat_id, role, content, metadata})
  end
  
  @doc """
  Get the current conversation context.
  """
  def get_context(chat_id) do
    GenServer.call(__MODULE__, {:get_context, chat_id})
  end
  
  @doc """
  Update user preferences based on interactions.
  """
  def update_preferences(chat_id, preferences) do
    GenServer.cast(__MODULE__, {:update_preferences, chat_id, preferences})
  end
  
  @doc """
  Set an active conversation flow (e.g., multi-step configuration).
  """
  def set_active_flow(chat_id, flow_type, initial_state \\ %{}) do
    GenServer.call(__MODULE__, {:set_active_flow, chat_id, flow_type, initial_state})
  end
  
  @doc """
  Update flow state during multi-step interactions.
  """
  def update_flow_state(chat_id, updates) do
    GenServer.call(__MODULE__, {:update_flow_state, chat_id, updates})
  end
  
  @doc """
  Complete the active flow.
  """
  def complete_flow(chat_id) do
    GenServer.call(__MODULE__, {:complete_flow, chat_id})
  end
  
  @doc """
  Check if there's an active flow for the chat.
  """
  def has_active_flow?(chat_id) do
    GenServer.call(__MODULE__, {:has_active_flow?, chat_id})
  end
  
  @doc """
  Store a pending confirmation.
  """
  def add_pending_confirmation(chat_id, confirmation_type, data) do
    GenServer.call(__MODULE__, {:add_pending_confirmation, chat_id, confirmation_type, data})
  end
  
  @doc """
  Get and remove a pending confirmation.
  """
  def get_pending_confirmation(chat_id, confirmation_type) do
    GenServer.call(__MODULE__, {:get_pending_confirmation, chat_id, confirmation_type})
  end
  
  @doc """
  Generate a contextual response using conversation history.
  """
  def generate_contextual_response(chat_id, prompt, options \\ %{}) do
    GenServer.call(__MODULE__, {:generate_contextual_response, chat_id, prompt, options}, 15_000)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Schedule cleanup of inactive conversations
    schedule_cleanup()
    
    state = %{
      conversations: %{},
      user_preferences_db: %{},  # In production, this would be persisted
      flow_definitions: load_flow_definitions()
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:start_conversation, chat_id, user_info}, _from, state) do
    conversation = case Map.get(state.conversations, chat_id) do
      nil ->
        # New conversation
        %Conversation{
          chat_id: chat_id,
          user_id: user_info[:user_id],
          username: user_info[:username],
          started_at: DateTime.utc_now(),
          last_activity: DateTime.utc_now(),
          context: %{
            user_role: user_info[:role] || "user",
            timezone: user_info[:timezone] || "UTC",
            language: user_info[:language] || "en"
          },
          messages: [],
          user_preferences: load_user_preferences(state, user_info[:user_id]),
          active_flow: nil,
          flow_state: %{},
          pending_confirmations: %{}
        }
        
      existing ->
        # Continue existing conversation
        %{existing | last_activity: DateTime.utc_now()}
    end
    
    new_state = put_in(state.conversations[chat_id], conversation)
    {:reply, {:ok, conversation}, new_state}
  end
  
  @impl true
  def handle_call({:add_message, chat_id, role, content, metadata}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        message = %Message{
          role: role,
          content: content,
          intent: metadata[:intent],
          entities: metadata[:entities],
          timestamp: DateTime.utc_now()
        }
        
        # Keep only recent messages for context
        messages = [message | conversation.messages]
                  |> Enum.take(@max_context_messages)
        
        updated_conversation = %{conversation | 
          messages: messages,
          last_activity: DateTime.utc_now()
        }
        
        # Learn from user preferences if this is a user message
        new_state = if role == :user do
          learn_from_message(state, chat_id, content, metadata)
        else
          state
        end
        
        new_state = put_in(new_state.conversations[chat_id], updated_conversation)
        {:reply, {:ok, updated_conversation}, new_state}
    end
  end
  
  @impl true
  def handle_call({:get_context, chat_id}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        context = build_context(conversation)
        {:reply, {:ok, context}, state}
    end
  end
  
  @impl true
  def handle_call({:set_active_flow, chat_id, flow_type, initial_state}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        flow_def = Map.get(state.flow_definitions, flow_type)
        
        if flow_def do
          updated_conversation = %{conversation |
            active_flow: flow_type,
            flow_state: Map.merge(flow_def.initial_state, initial_state)
          }
          
          new_state = put_in(state.conversations[chat_id], updated_conversation)
          {:reply, {:ok, flow_def}, new_state}
        else
          {:reply, {:error, :unknown_flow}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:update_flow_state, chat_id, updates}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        updated_flow_state = Map.merge(conversation.flow_state, updates)
        updated_conversation = %{conversation | flow_state: updated_flow_state}
        
        new_state = put_in(state.conversations[chat_id], updated_conversation)
        {:reply, {:ok, updated_flow_state}, new_state}
    end
  end
  
  @impl true
  def handle_call({:complete_flow, chat_id}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        flow_result = conversation.flow_state
        updated_conversation = %{conversation |
          active_flow: nil,
          flow_state: %{}
        }
        
        new_state = put_in(state.conversations[chat_id], updated_conversation)
        {:reply, {:ok, flow_result}, new_state}
    end
  end
  
  @impl true
  def handle_call({:has_active_flow?, chat_id}, _from, state) do
    result = case Map.get(state.conversations, chat_id) do
      nil -> false
      conversation -> conversation.active_flow != nil
    end
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:add_pending_confirmation, chat_id, confirmation_type, data}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        confirmations = Map.put(conversation.pending_confirmations, confirmation_type, data)
        updated_conversation = %{conversation | pending_confirmations: confirmations}
        
        new_state = put_in(state.conversations[chat_id], updated_conversation)
        {:reply, :ok, new_state}
    end
  end
  
  @impl true
  def handle_call({:get_pending_confirmation, chat_id, confirmation_type}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        {data, confirmations} = Map.pop(conversation.pending_confirmations, confirmation_type)
        updated_conversation = %{conversation | pending_confirmations: confirmations}
        
        new_state = put_in(state.conversations[chat_id], updated_conversation)
        {:reply, {:ok, data}, new_state}
    end
  end
  
  @impl true
  def handle_call({:generate_contextual_response, chat_id, prompt, options}, _from, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:reply, {:error, :no_conversation}, state}
        
      conversation ->
        response = generate_response_with_context(conversation, prompt, options)
        {:reply, response, state}
    end
  end
  
  @impl true
  def handle_cast({:update_preferences, chat_id, preferences}, state) do
    case Map.get(state.conversations, chat_id) do
      nil ->
        {:noreply, state}
        
      conversation ->
        current_prefs = conversation.user_preferences
        updated_prefs = Map.merge(current_prefs, preferences)
        
        updated_conversation = %{conversation | user_preferences: updated_prefs}
        new_state = put_in(state.conversations[chat_id], updated_conversation)
        
        # Also update the persistent preferences
        user_id = conversation.user_id
        if user_id do
          new_state = put_in(new_state.user_preferences_db[user_id], updated_prefs)
        end
        
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info(:cleanup_inactive, state) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@conversation_timeout, :millisecond)
    
    active_conversations = state.conversations
    |> Enum.filter(fn {_chat_id, conv} ->
      DateTime.compare(conv.last_activity, cutoff_time) == :gt
    end)
    |> Enum.into(%{})
    
    removed_count = map_size(state.conversations) - map_size(active_conversations)
    if removed_count > 0 do
      Logger.info("Cleaned up #{removed_count} inactive conversations")
    end
    
    schedule_cleanup()
    {:noreply, %{state | conversations: active_conversations}}
  end
  
  # Private Functions
  
  defp build_context(conversation) do
    %{
      user_id: conversation.user_id,
      username: conversation.username,
      conversation_length: length(conversation.messages),
      last_messages: format_recent_messages(conversation.messages),
      user_preferences: conversation.user_preferences,
      active_flow: conversation.active_flow,
      flow_state: conversation.flow_state,
      context_metadata: conversation.context
    }
  end
  
  defp format_recent_messages(messages) do
    messages
    |> Enum.take(5)
    |> Enum.reverse()
    |> Enum.map(fn msg ->
      %{
        role: msg.role,
        content: msg.content,
        intent: msg.intent
      }
    end)
  end
  
  defp load_user_preferences(state, user_id) when is_binary(user_id) do
    Map.get(state.user_preferences_db, user_id, %{
      preferred_detail_level: "medium",
      notification_preferences: %{
        critical_alerts: true,
        status_updates: true,
        vsm_events: false
      },
      command_shortcuts: %{},
      frequently_used_commands: [],
      response_format: "standard"
    })
  end
  defp load_user_preferences(_state, _user_id), do: %{}
  
  defp learn_from_message(state, chat_id, content, metadata) do
    conversation = state.conversations[chat_id]
    
    # Learn command usage patterns
    if metadata[:intent] && metadata[:intent] != :unknown do
      freq_commands = conversation.user_preferences[:frequently_used_commands] || []
      updated_commands = [metadata[:intent] | freq_commands]
                        |> Enum.take(10)
                        |> Enum.uniq()
      
      preferences = put_in(
        conversation.user_preferences[:frequently_used_commands],
        updated_commands
      )
      
      put_in(state.conversations[chat_id].user_preferences, preferences)
    else
      state
    end
  end
  
  defp generate_response_with_context(conversation, prompt, options) do
    context_prompt = build_contextual_prompt(conversation, prompt, options)
    
    llm_options = %{
      temperature: options[:temperature] || 0.7,
      provider: options[:provider] || :openai,
      model: options[:model] || "gpt-4"
    }
    
    case LLMService.generate(context_prompt, llm_options) do
      {:ok, response} ->
        {:ok, post_process_response(response, conversation)}
        
      error ->
        error
    end
  end
  
  defp build_contextual_prompt(conversation, prompt, options) do
    """
    You are a helpful VSM (Viable System Model) assistant engaged in a conversation.
    
    User Information:
    - Username: #{conversation.username || "User"}
    - Preferences: #{inspect(conversation.user_preferences)}
    - Active Flow: #{conversation.active_flow || "none"}
    
    Recent Conversation:
    #{format_conversation_history(conversation.messages)}
    
    Current Context:
    #{prompt}
    
    Instructions:
    - Be conversational and helpful
    - Reference previous context when relevant
    - Adapt responses based on user preferences
    - If in an active flow, guide the user through the next steps
    #{options[:additional_instructions] || ""}
    
    Response:
    """
  end
  
  defp format_conversation_history(messages) do
    messages
    |> Enum.take(5)
    |> Enum.reverse()
    |> Enum.map_join("\n", fn msg ->
      role = if msg.role == :user, do: "User", else: "Assistant"
      "#{role}: #{msg.content}"
    end)
  end
  
  defp post_process_response(response, conversation) do
    # Apply user preferences to response formatting
    case conversation.user_preferences[:response_format] do
      "brief" -> summarize_response(response)
      "detailed" -> enhance_response(response)
      _ -> response
    end
  end
  
  defp summarize_response(response) do
    # In a real implementation, this could use an LLM to summarize
    if String.length(response) > 200 do
      String.slice(response, 0, 200) <> "..."
    else
      response
    end
  end
  
  defp enhance_response(response) do
    # Add formatting and structure for detailed responses
    response
  end
  
  defp load_flow_definitions do
    %{
      vsm_configuration: %{
        initial_state: %{
          step: 1,
          vsm_type: nil,
          agent_count: nil,
          subsystems: []
        },
        steps: [
          %{
            step: 1,
            prompt: "What type of VSM would you like to create? (standard/recursive/federated)",
            field: :vsm_type,
            validation: [:required, {:in, ["standard", "recursive", "federated"]}]
          },
          %{
            step: 2,
            prompt: "How many agents should the VSM have? (1-20)",
            field: :agent_count,
            validation: [:required, {:range, 1, 20}]
          },
          %{
            step: 3,
            prompt: "Which subsystems should be enabled? (s1,s2,s3,s4,s5 or 'all')",
            field: :subsystems,
            validation: [:required]
          }
        ]
      },
      
      alert_configuration: %{
        initial_state: %{
          step: 1,
          alert_level: nil,
          alert_message: nil,
          target_chats: nil
        },
        steps: [
          %{
            step: 1,
            prompt: "What level of alert? (info/warning/critical)",
            field: :alert_level,
            validation: [:required, {:in, ["info", "warning", "critical"]}]
          },
          %{
            step: 2,
            prompt: "What's the alert message?",
            field: :alert_message,
            validation: [:required, {:min_length, 5}]
          },
          %{
            step: 3,
            prompt: "Send to all admins? (yes/no)",
            field: :target_chats,
            validation: [:required]
          }
        ]
      }
    }
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_inactive, :timer.minutes(5))
  end
end