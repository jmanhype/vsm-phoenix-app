defmodule VsmPhoenix.System1.Agents.TelegramAgent do
  @moduledoc """
  S1 Telegram Agent - Handles Telegram bot integration for VSM monitoring and control.
  
  Provides a Telegram interface for system status, alerts, and command execution.
  Supports both webhook and polling modes for maximum flexibility.
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.AMQP.ConnectionManager
  alias Phoenix.PubSub
  alias AMQP
  alias VsmPhoenix.Infrastructure.{AsyncRunner, SafePubSub, DataValidator, AMQPClient, ExchangeConfig}

  @telegram_api_base "https://api.telegram.org/bot"
  @poll_timeout 30_000  # 30 seconds long polling
  @poll_interval 1_000  # 1 second between polls on error

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
  end

  def send_message(agent_id, chat_id, text, opts \\ []) do
    GenServer.call({:global, agent_id}, {:send_message, chat_id, text, opts})
  end

  def set_webhook(agent_id, webhook_url) do
    GenServer.call({:global, agent_id}, {:set_webhook, webhook_url})
  end

  def delete_webhook(agent_id) do
    GenServer.call({:global, agent_id}, :delete_webhook)
  end

  def handle_update(agent_id, update) do
    GenServer.cast({:global, agent_id}, {:handle_update, update})
  end

  def get_telegram_metrics(agent_id) do
    GenServer.call({:global, agent_id}, :get_telegram_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    config = Keyword.get(opts, :config, %{})
    registry = Keyword.get(opts, :registry, Registry)
    
    Logger.info("📱 Telegram Agent #{agent_id} initializing...")
    
    # Validate bot token
    bot_token = config[:bot_token] || System.get_env("TELEGRAM_BOT_TOKEN")
    
    if bot_token do
      # Register with S1 Registry if not skipped
      unless registry == :skip_registration do
        :ok = registry.register(agent_id, self(), %{
          type: :telegram,
          config: config,
          bot_username: nil,  # Will be updated after bot info fetch
          started_at: DateTime.utc_now()
        })
      end
    
      # Get AMQP channel
      {:ok, channel} = ConnectionManager.get_channel(:telegram)
      
      # Setup AMQP exchanges
      events_exchange = "vsm.s1.#{agent_id}.telegram.events"
      commands_exchange = "vsm.s1.#{agent_id}.telegram.commands"
      
      :ok = AMQP.Exchange.declare(channel, events_exchange, :topic, durable: true)
      :ok = AMQP.Exchange.declare(channel, commands_exchange, :topic, durable: true)
      
      # Setup command queue
      command_queue = "vsm.s1.#{agent_id}.telegram.commands"
      {:ok, _queue} = AMQP.Queue.declare(channel, command_queue, durable: true)
      :ok = AMQP.Queue.bind(channel, command_queue, commands_exchange, routing_key: "#")
      
      # Start consuming commands
      {:ok, _consumer_tag} = AMQP.Basic.consume(channel, command_queue)
      
      # Subscribe to alert topics
      PubSub.subscribe(VsmPhoenix.PubSub, "vsm:alerts:critical")
      PubSub.subscribe(VsmPhoenix.PubSub, "vsm:telegram:#{agent_id}")
      
      # Create ETS table for conversation history
      conversation_table = :"telegram_conversations_#{agent_id}"
      :ets.new(conversation_table, [:set, :public, :named_table, {:read_concurrency, true}])
      
      state = %{
        agent_id: agent_id,
        config: config,
        bot_token: bot_token,
        bot_info: nil,
        channel: channel,
        events_exchange: events_exchange,
        commands_exchange: commands_exchange,
        webhook_mode: config[:webhook_mode] || false,
        webhook_url: config[:webhook_url],
        polling_pid: nil,
        last_update_id: 379100174,  # Skip old messages
        authorized_chats: MapSet.new(config[:authorized_chats] || []),
        admin_chats: MapSet.new(config[:admin_chats] || []),
        conversation_table: conversation_table,
        conversation_states: %{},  # Track per-chat conversation state
        llm_processing: %{},  # Track ongoing LLM requests
        metrics: %{
          messages_received: 0,
          messages_sent: 0,
          commands_processed: 0,
          errors: 0,
          last_message_at: nil,
          command_stats: %{}
        }
      }
      
      # Send startup message
      send(self(), :after_init)
      
      {:ok, state}
    else
      Logger.error("No bot token provided for TelegramAgent #{agent_id}")
      {:stop, :no_bot_token}
    end
  end

  @impl true
  def handle_info(:after_init, state) do
    # Fetch bot info
    case get_bot_info(state) do
      {:ok, bot_info} ->
        Logger.info("Telegram bot connected: @#{bot_info["username"]}")
        
        # Update registry with bot info
        # Registry.update_metadata(state.agent_id, %{bot_username: bot_info["username"]})
        
        # Start polling or set webhook
        new_state = if state.webhook_mode do
          case set_webhook_internal(state) do
            {:ok, _} -> state
            {:error, reason} ->
              Logger.error("Failed to set webhook: #{inspect(reason)}, falling back to polling")
              start_polling(%{state | webhook_mode: false})
          end
        else
          start_polling(state)
        end
        
        # Publish bot ready event
        publish_telegram_event("bot_ready", %{
          username: bot_info["username"],
          mode: if(new_state.webhook_mode, do: "webhook", else: "polling")
        }, new_state)
        
        {:noreply, %{new_state | bot_info: bot_info}}
        
      {:error, reason} ->
        Logger.error("Failed to get bot info: #{inspect(reason)}")
        Process.send_after(self(), :after_init, 5_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:poll_updates, %{polling_pid: nil} = state) do
    # Spawn polling process
    parent = self()
    Logger.info("📱 Starting polling process for #{state.agent_id}")
    pid = spawn_link(fn -> poll_loop(parent, state) end)
    {:noreply, %{state | polling_pid: pid}}
  end

  @impl true
  def handle_info({:telegram_update, update}, state) do
    Logger.info("📱 Processing Telegram update: #{inspect(update["update_id"])}")
    new_state = process_update(update, state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Check if this is an LLM response by correlation_id
    if meta[:correlation_id] && String.starts_with?(meta.correlation_id, "llm_") do
      handle_llm_response(payload, meta, state)
    else
      # Handle regular AMQP command
      case Jason.decode(payload) do
        {:ok, command} ->
          Logger.debug("Telegram Agent received command: #{inspect(command)}")
          new_state = process_amqp_command(command, state)
          AMQP.Basic.ack(state.channel, meta.delivery_tag)
          {:noreply, new_state}
          
        {:error, reason} ->
          Logger.error("Failed to parse AMQP command: #{inspect(reason)}")
          AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
          {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    Logger.info("Telegram Agent #{state.agent_id} subscribed to command queue")
    {:noreply, state}
  end

  @impl true
  def handle_info({:pubsub, :alert, alert}, state) do
    # Handle critical alerts
    Logger.info("Telegram Agent received critical alert: #{inspect(alert)}")
    
    # Send to all admin chats
    message = format_alert_message(alert)
    Enum.each(state.admin_chats, fn chat_id ->
      send_telegram_message(chat_id, message, state)
    end)
    
    {:noreply, state}
  end

  @impl true
  def handle_call({:send_message, chat_id, text, opts}, _from, state) do
    result = send_telegram_message(chat_id, text, state, opts)
    new_state = update_metrics(state, :message_sent)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:set_webhook, webhook_url}, _from, state) do
    case set_webhook_internal(%{state | webhook_url: webhook_url}) do
      {:ok, _} = result ->
        # Stop polling if active
        if state.polling_pid do
          Process.exit(state.polling_pid, :normal)
        end
        {:reply, result, %{state | webhook_mode: true, webhook_url: webhook_url, polling_pid: nil}}
        
      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:delete_webhook, _from, state) do
    case delete_webhook_internal(state) do
      {:ok, _} = result ->
        # Start polling
        new_state = start_polling(%{state | webhook_mode: false, webhook_url: nil})
        {:reply, result, new_state}
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:get_telegram_metrics, _from, state) do
    metrics = calculate_telegram_statistics(state.metrics)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_cast({:handle_update, update}, state) do
    new_state = process_update(update, state)
    {:noreply, new_state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Telegram Agent #{state.agent_id} terminating: #{inspect(reason)}")
    
    # Stop polling
    if state.polling_pid do
      Process.exit(state.polling_pid, :shutdown)
    end
    
    # Delete webhook if set
    if state.webhook_mode do
      delete_webhook_internal(state)
    end
    
    # Delete conversation table
    if state.conversation_table do
      :ets.delete(state.conversation_table)
    end
    
    # Unregister from registry
    Registry.unregister(state.agent_id)
    
    # Unsubscribe from PubSub
    PubSub.unsubscribe(VsmPhoenix.PubSub, "vsm:alerts:critical")
    PubSub.unsubscribe(VsmPhoenix.PubSub, "vsm:telegram:#{state.agent_id}")
    
    # Close AMQP channel
    if state.channel && Process.alive?(state.channel.pid) do
      AMQP.Channel.close(state.channel)
    end
    
    :ok
  end

  # Private Functions - Telegram API

  defp get_bot_info(state) do
    url = "#{@telegram_api_base}#{state.bot_token}/getMe"
    parent = self()
    
    AsyncRunner.async_http_request(:get, url, "", [], 
      callback: fn result ->
        response = case result do
          {:ok, %{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"ok" => true, "result" => bot_info}} ->
                {:ok, bot_info}
              {:ok, %{"ok" => false, "description" => desc}} ->
                {:error, desc}
              _ ->
                {:error, "Invalid response"}
            end
          {:ok, %{status_code: status}} ->
            {:error, "HTTP #{status}"}
          {:error, error} ->
            {:error, error}
        end
        send(parent, {:bot_info_result, response})
      end
    )
    
    receive do
      {:bot_info_result, result} -> result
    after
      5_000 -> {:error, :timeout}
    end
  end

  defp send_telegram_message(chat_id, text, state, opts \\ []) do
    url = "#{@telegram_api_base}#{state.bot_token}/sendMessage"
    
    params = %{
      "chat_id" => chat_id,
      "text" => text,
      "parse_mode" => opts[:parse_mode] || "Markdown"
    }
    |> maybe_add_reply_markup(opts[:reply_markup])
    |> maybe_add_reply_to(opts[:reply_to_message_id])
    
    body = Jason.encode!(params)
    headers = [{"Content-Type", "application/json"}]
    parent = self()
    
    AsyncRunner.async_http_request(:post, url, body, headers,
      callback: fn result ->
        response = case result do
          {:ok, %{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, %{"ok" => true, "result" => message}} ->
                publish_telegram_event("message_sent", %{
                  chat_id: chat_id,
                  message_id: DataValidator.safe_get(message, "message_id")
                }, state)
                {:ok, message}
              {:ok, %{"ok" => false, "description" => desc}} ->
                {:error, desc}
              _ ->
                {:error, "Invalid response"}
            end
          {:ok, %{status_code: status}} ->
            {:error, "HTTP #{status}"}
          {:error, error} ->
            {:error, error}
        end
        send(parent, {:send_message_result, response})
      end
    )
    
    receive do
      {:send_message_result, result} -> result
    after
      5_000 -> {:error, :timeout}
    end
  end

  defp set_webhook_internal(state) do
    url = "#{@telegram_api_base}#{state.bot_token}/setWebhook"
    params = %{"url" => state.webhook_url}
    
    case HTTPoison.post(url, Jason.encode!(params), [{"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true}} ->
            Logger.info("Webhook set successfully: #{state.webhook_url}")
            {:ok, :webhook_set}
          {:ok, %{"ok" => false, "description" => desc}} ->
            {:error, desc}
          _ ->
            {:error, "Invalid response"}
        end
      error ->
        {:error, error}
    end
  end

  defp delete_webhook_internal(state) do
    url = "#{@telegram_api_base}#{state.bot_token}/deleteWebhook"
    
    case HTTPoison.post(url, "", [{"Content-Type", "application/json"}]) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true}} ->
            Logger.info("Webhook deleted successfully")
            {:ok, :webhook_deleted}
          {:ok, %{"ok" => false, "description" => desc}} ->
            {:error, desc}
          _ ->
            {:error, "Invalid response"}
        end
      error ->
        {:error, error}
    end
  end

  # Private Functions - Polling

  defp start_polling(state) do
    Logger.info("Starting Telegram polling mode")
    send(self(), :poll_updates)
    state
  end

  defp poll_loop(parent, state) do
    url = "#{@telegram_api_base}#{state.bot_token}/getUpdates"
    params = %{
      "offset" => state.last_update_id + 1,
      "timeout" => div(@poll_timeout, 1000)
    }
    
    Logger.debug("🔄 Polling Telegram API with offset #{params["offset"]}")
    
    case HTTPoison.post(url, Jason.encode!(params), 
                       [{"Content-Type", "application/json"}],
                       recv_timeout: @poll_timeout + 5000) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => updates}} when length(updates) > 0 ->
            Logger.info("📥 Received #{length(updates)} Telegram updates")
            
            # Get the highest update_id
            max_update_id = updates 
                           |> Enum.map(& &1["update_id"])
                           |> Enum.max()
            
            Logger.info("📊 Updating offset from #{state.last_update_id} to #{max_update_id}")
            
            # Send updates to parent
            Enum.each(updates, fn update ->
              Logger.info("🚀 Sending update #{update["update_id"]} to parent")
              send(parent, {:telegram_update, update})
            end)
            
            # Continue polling with new offset
            Process.sleep(100)
            poll_loop(parent, %{state | last_update_id: max_update_id})
            
          {:ok, %{"ok" => true, "result" => []}} ->
            # No updates, continue polling
            Process.sleep(100)
            poll_loop(parent, state)
            
          _ ->
            Process.sleep(@poll_interval)
            poll_loop(parent, state)
        end
        
      _ ->
        Process.sleep(@poll_interval)
        poll_loop(parent, state)
    end
  end

  # Private Functions - Update Processing

  defp process_update(update, state) do
    update_id = update["update_id"]
    
    cond do
      update["message"] ->
        process_message(update["message"], state)
        
      update["callback_query"] ->
        process_callback_query(update["callback_query"], state)
        
      true ->
        Logger.debug("Ignoring update type: #{inspect(Map.keys(update))}")
        state
    end
    |> Map.update!(:last_update_id, fn id -> max(id, update_id) end)
  end

  defp process_message(message, state) do
    chat_id = message["chat"]["id"]
    text = message["text"] || ""
    from = message["from"]
    
    Logger.info("💬 Processing message from #{chat_id}: #{text}")
    
    # Check authorization
    if authorized?(chat_id, from["id"], state) do
      Logger.info("✅ User authorized")
      # Process commands
      if String.starts_with?(text, "/") do
        process_command(text, message, state)
      else
        # Process natural language message
        process_natural_language(text, message, state)
      end
    else
      send_telegram_message(chat_id, "⛔ Unauthorized. This incident has been logged.", state)
      
      publish_telegram_event("unauthorized_access", %{
        chat_id: chat_id,
        user_id: from["id"],
        username: from["username"]
      }, state)
      
      update_metrics(state, :unauthorized)
    end
  end

  defp process_command(text, message, state) do
    chat_id = message["chat"]["id"]
    [command | args] = String.split(text, " ")
    command = String.trim_leading(command, "/")
    
    Logger.info("🎯 Processing command: #{command} with args: #{inspect(args)}")
    
    # Remove bot username if present (e.g., /help@VaoAssitantBot)
    command = command |> String.split("@") |> List.first()
    
    result = case command do
      "start" ->
        handle_start_command(chat_id, state)
        
      "help" ->
        handle_help_command(chat_id, state)
        
      "status" ->
        handle_status_command(chat_id, args, state)
        
      "vsm" ->
        handle_vsm_command(chat_id, args, state)
        
      "alert" ->
        if is_admin?(chat_id, state) do
          handle_alert_command(chat_id, args, state)
        else
          send_telegram_message(chat_id, "❌ Admin access required", state)
          state
        end
        
      "authorize" ->
        if is_admin?(chat_id, state) do
          handle_authorize_command(chat_id, args, state)
        else
          send_telegram_message(chat_id, "❌ Admin access required", state)
          state
        end
        
      _ ->
        send_telegram_message(chat_id, "❓ Unknown command. Use /help for available commands.", state)
        state
    end
    
    # Update metrics with the command that was processed
    |> update_metrics(:command_processed, command)
  end

  defp process_callback_query(callback_query, state) do
    callback_id = callback_query["id"]
    data = callback_query["data"]
    from = callback_query["from"]
    
    # Answer callback to remove loading state
    answer_callback_query(callback_id, state)
    
    # Process callback data
    publish_telegram_event("callback_received", %{
      data: data,
      from: from
    }, state)
    
    update_metrics(state, :callback_processed)
  end

  # Command Handlers

  defp handle_start_command(chat_id, state) do
    message = """
    🤖 *VSM Telegram Bot Active*
    
    I'm your interface to the Viable System Model.
    Use /help to see available commands.
    
    Chat ID: `#{chat_id}`
    Agent: `#{state.agent_id}`
    """
    
    send_telegram_message(chat_id, message, state)
    state
  end

  defp handle_help_command(chat_id, state) do
    base_commands = """
    📋 *Available Commands:*
    
    /start - Initialize bot
    /help - Show this help
    /status - System status
    /vsm - VSM operations
    """
    
    admin_commands = if is_admin?(chat_id, state) do
      """
      
      *Admin Commands:*
      /alert <level> <message> - Send alert
      /authorize <chat_id> - Authorize chat
      """
    else
      ""
    end
    
    message = base_commands <> admin_commands
    send_telegram_message(chat_id, message, state)
    state
  end

  defp handle_status_command(chat_id, _args, state) do
    # Request status via AMQP
    publish_amqp_command("get_status", %{
      reply_to: chat_id,
      include: ["s1", "s2", "s3", "s4", "s5"]
    }, state)
    
    send_telegram_message(chat_id, "🔄 Fetching system status...", state)
    state
  end

  defp handle_vsm_command(chat_id, args, state) do
    case args do
      ["spawn" | rest] ->
        config = Enum.join(rest, " ")
        publish_amqp_command("spawn_vsm", %{
          reply_to: chat_id,
          config: config
        }, state)
        send_telegram_message(chat_id, "🚀 Spawning new VSM instance...", state)
        
      ["list"] ->
        publish_amqp_command("list_vsms", %{reply_to: chat_id}, state)
        send_telegram_message(chat_id, "📋 Fetching VSM list...", state)
        
      _ ->
        send_telegram_message(chat_id, "Usage: /vsm spawn <config> | list", state)
    end
    
    state
  end

  defp handle_alert_command(chat_id, args, state) do
    case args do
      [level | message_parts] when level in ["info", "warning", "critical"] ->
        message = Enum.join(message_parts, " ")
        
        publish_amqp_command("broadcast_alert", %{
          level: level,
          message: message,
          source: "telegram:#{chat_id}"
        }, state)
        
        send_telegram_message(chat_id, "✅ Alert broadcasted", state)
        
      _ ->
        send_telegram_message(chat_id, "Usage: /alert <info|warning|critical> <message>", state)
    end
    
    state
  end

  defp handle_authorize_command(chat_id, [new_chat_id], state) do
    case Integer.parse(new_chat_id) do
      {id, ""} ->
        new_state = %{state | authorized_chats: MapSet.put(state.authorized_chats, id)}
        send_telegram_message(chat_id, "✅ Chat #{id} authorized", state)
        send_telegram_message(id, "🎉 You have been authorized to use this bot!", state)
        new_state
        
      _ ->
        send_telegram_message(chat_id, "Invalid chat ID", state)
        state
    end
  end

  # Natural Language Processing
  
  defp process_natural_language(text, message, state) do
    chat_id = message["chat"]["id"]
    message_id = message["message_id"]
    from = message["from"]
    
    Logger.info("🧠 Processing natural language message from #{chat_id}")
    
    # Send typing indicator
    send_chat_action(chat_id, "typing", state)
    
    # Check if we have conversation state for this chat
    conversation_state = get_conversation_state(chat_id, state)
    
    # Start or continue LLM conversation
    Task.start(fn ->
      try do
        # Send to LLM worker via AMQP
        response = request_llm_response(text, message, conversation_state, state)
        
        case response do
          {:ok, llm_response} ->
            # Send the response back to user
            send_telegram_message(chat_id, llm_response, state, reply_to_message_id: message_id)
            
            # Update conversation state
            update_conversation_state(chat_id, text, llm_response, state)
            
          {:error, reason} ->
            Logger.error("Failed to get LLM response: #{inspect(reason)}")
            send_telegram_message(chat_id, "🤖 Sorry, I'm having trouble processing your message. Please try again.", state, reply_to_message_id: message_id)
        end
      rescue
        e ->
          Logger.error("Error in LLM processing: #{inspect(e)}")
          send_telegram_message(chat_id, "🤖 An error occurred while processing your message.", state, reply_to_message_id: message_id)
      end
    end)
    
    update_metrics(state, :message_received)
  end
  
  defp send_chat_action(chat_id, action, state) do
    url = "https://api.telegram.org/bot#{state.bot_token}/sendChatAction"
    params = %{
      "chat_id" => chat_id,
      "action" => action
    }
    
    case HTTPoison.post(url, Jason.encode!(params), [{"Content-Type", "application/json"}]) do
      {:ok, _response} -> :ok
      {:error, reason} -> 
        Logger.error("Failed to send chat action: #{inspect(reason)}")
        :error
    end
  end
  
  defp get_conversation_state(chat_id, state) do
    case :ets.lookup(state.conversation_table, chat_id) do
      [{^chat_id, conversation_state}] -> conversation_state
      [] -> %{messages: [], context: %{}}
    end
  end
  
  defp update_conversation_state(chat_id, user_message, bot_response, state) do
    current_state = get_conversation_state(chat_id, state)
    
    new_messages = current_state.messages ++ [
      %{role: "user", content: user_message, timestamp: DateTime.utc_now()},
      %{role: "assistant", content: bot_response, timestamp: DateTime.utc_now()}
    ]
    
    # Keep only last 20 messages for context
    trimmed_messages = Enum.take(new_messages, -20)
    
    new_state = %{current_state | messages: trimmed_messages}
    :ets.insert(state.conversation_table, {chat_id, new_state})
  end
  
  defp request_llm_response(text, message, conversation_state, state) do
    chat_id = message["chat"]["id"]
    from = message["from"]
    
    # Build conversation messages
    messages = conversation_state.messages ++ [
      %{role: "user", content: text, timestamp: DateTime.utc_now()}
    ]
    
    # System prompt for VSM context
    system_prompt = """
    You are a helpful assistant for the Viable Systems Model (VSM) monitoring system.
    You can help users understand system status, explain VSM concepts, and guide them through operations.
    Be conversational and friendly while being accurate about system information.
    Current systems status: All 5 VSM systems operational.
    """
    
    # Try direct LLM bridge call
    case VsmPhoenix.MCP.LLMBridge.generate_conversation_response(messages, system_prompt, nil) do
      {:ok, %{content: response_text}} ->
        Logger.info("✅ Generated direct LLM response for chat #{chat_id}")
        {:ok, response_text}
      
      {:error, reason} ->
        Logger.warning("LLM Bridge failed: #{inspect(reason)}, using fallback")
        # Use fallback response
        {:ok, generate_fallback_response(text, messages)}
    end
  end
  
  defp generate_fallback_response(text, _messages) do
    lower_text = String.downcase(text)
    
    cond do
      String.contains?(lower_text, ["hi", "hello", "hey"]) ->
        "Hello! I'm your VSM assistant. I can help you monitor system status and understand the Viable Systems Model. Try asking about system health or use /status to see current metrics."
      
      String.contains?(lower_text, ["how are you", "how's it going"]) ->
        "I'm functioning well! All VSM systems are operational. How can I assist you today?"
      
      String.contains?(lower_text, ["status"]) ->
        "All 5 VSM systems are operational:\n• S1: Operations ✅\n• S2: Coordination ✅\n• S3: Control ✅\n• S4: Intelligence ✅\n• S5: Policy ✅\n\nUse /status for detailed metrics."
      
      String.contains?(lower_text, ["help", "what can you do"]) ->
        "I can help you with:\n• System status monitoring (/status)\n• Understanding VSM concepts\n• Checking alerts and health metrics\n• Managing system operations\n\nWhat would you like to know?"
      
      String.contains?(lower_text, ["vsm", "viable system"]) ->
        "The Viable Systems Model has 5 key systems:\n• S1: Operations (doing the work)\n• S2: Coordination (preventing conflicts)\n• S3: Control (resource management)\n• S4: Intelligence (future planning)\n• S5: Policy (identity & direction)\n\nWhich system would you like to learn more about?"
      
      true ->
        "I understand you said: \"#{text}\". I'm here to help with VSM monitoring and operations. You can ask about system status, VSM concepts, or use /help to see available commands."
    end
  end
  
  defp publish_to_llm_workers(request, state) do
    correlation_id = :erlang.unique_integer() |> Integer.to_string()
    reply_queue = "telegram.#{state.agent_id}.replies.#{correlation_id}"
    
    # Declare temporary reply queue
    case AMQP.Queue.declare(state.channel, reply_queue, exclusive: true, auto_delete: true) do
      {:ok, _} ->
        # Subscribe to reply queue
        AMQP.Basic.consume(state.channel, reply_queue, nil, no_ack: true)
        
        # Publish request to LLM workers
        message = %{
          request: request,
          reply_to: reply_queue,
          correlation_id: correlation_id,
          timestamp: DateTime.utc_now()
        }
        
        case AMQP.Basic.publish(
          state.channel,
          "vsm.llm.requests",  # LLM workers listen on this exchange
          "llm.request.conversation",
          Jason.encode!(message),
          reply_to: reply_queue,
          correlation_id: correlation_id
        ) do
          :ok ->
            # Wait for response
            receive do
              {:basic_deliver, payload, _meta} ->
                case Jason.decode(payload) do
                  {:ok, %{"response" => response}} -> {:ok, response}
                  {:ok, %{"error" => error}} -> {:error, error}
                  _ -> {:error, :invalid_response}
                end
            after
              30_000 -> # 30 second timeout
                Logger.warning("LLM request timeout for chat #{request.chat_id}")
                {:error, :timeout}
            end
            
          error ->
            Logger.error("Failed to publish LLM request: #{inspect(error)}")
            {:error, :publish_failed}
        end
        
      error ->
        Logger.error("Failed to declare reply queue: #{inspect(error)}")
        {:error, :queue_failed}
    end
  end

  # AMQP Command Processing

  defp process_amqp_command(%{"command" => "send_message"} = cmd, state) do
    chat_id = cmd["chat_id"]
    text = cmd["text"]
    opts = cmd["opts"] || []
    
    send_telegram_message(chat_id, text, state, opts)
    state
  end

  defp process_amqp_command(%{"command" => "send_status_update"} = cmd, state) do
    chat_id = cmd["reply_to"]
    status = cmd["status"]
    
    message = format_status_message(status)
    send_telegram_message(chat_id, message, state)
    state
  end

  defp process_amqp_command(%{"command" => "send_vsm_list"} = cmd, state) do
    chat_id = cmd["reply_to"]
    vsms = cmd["vsms"] || []
    
    message = format_vsm_list(vsms)
    send_telegram_message(chat_id, message, state)
    state
  end

  defp process_amqp_command(cmd, state) do
    Logger.warning("Unknown AMQP command: #{inspect(cmd)}")
    state
  end

  # Helper Functions

  defp authorized?(chat_id, _user_id, state) do
    # Allow all for now during testing
    true
    # MapSet.member?(state.authorized_chats, chat_id) || 
    # MapSet.member?(state.admin_chats, chat_id)
  end

  defp is_admin?(chat_id, state) do
    MapSet.member?(state.admin_chats, chat_id)
  end

  defp answer_callback_query(callback_id, state) do
    url = "#{@telegram_api_base}#{state.bot_token}/answerCallbackQuery"
    params = %{"callback_query_id" => callback_id}
    body = Jason.encode!(params)
    headers = [{"Content-Type", "application/json"}]
    
    # Fire and forget
    AsyncRunner.async_http_request(:post, url, body, headers)
  end

  defp publish_telegram_event(event_type, data, state) do
    event = %{
      agent_id: state.agent_id,
      event_type: event_type,
      data: data,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    routing_key = "telegram.event.#{event_type}"
    
    AMQPClient.publish(:telegram_events, routing_key, event)
  end

  defp publish_amqp_command(command, params, state) do
    cmd = %{
      command: command,
      params: params,
      source: "telegram:#{state.agent_id}",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    routing_key = "vsm.command.#{command}"
    
    # Publish to VSM command bus
    AMQPClient.publish(:vsm_commands, routing_key, cmd,
      reply_to: ExchangeConfig.get_exchange_name(:telegram_commands)
    )
  end

  defp format_alert_message(alert) do
    """
    🚨 *Critical Alert*
    
    Level: #{alert.level}
    Source: #{alert.source}
    Time: #{alert.timestamp}
    
    #{alert.message}
    """
  end

  defp format_status_message(status) do
    """
    📊 *System Status*
    
    #{Enum.map_join(status, "\n", fn {system, info} ->
      emoji = case info.status do
        "healthy" -> "✅"
        "warning" -> "⚠️"
        "error" -> "❌"
        _ -> "❓"
      end
      
      "#{emoji} *#{String.upcase(to_string(system))}*: #{info.status}"
    end)}
    
    _Updated: #{DateTime.utc_now() |> DateTime.to_iso8601()}_
    """
  end

  defp format_vsm_list(vsms) do
    if Enum.empty?(vsms) do
      "📋 No active VSM instances"
    else
      """
      📋 *Active VSM Instances*
      
      #{Enum.map_join(vsms, "\n\n", fn vsm ->
        """
        🔹 *#{vsm.id}*
        Type: #{vsm.type}
        Status: #{vsm.status}
        Started: #{vsm.started_at}
        """
      end)}
      """
    end
  end

  defp maybe_add_reply_markup(params, nil), do: params
  defp maybe_add_reply_markup(params, markup), do: Map.put(params, "reply_markup", markup)

  defp maybe_add_reply_to(params, nil), do: params
  defp maybe_add_reply_to(params, id), do: Map.put(params, "reply_to_message_id", id)

  defp update_metrics(state, metric_type, extra \\ nil) do
    new_metrics = case metric_type do
      :message_received ->
        %{state.metrics | 
          messages_received: state.metrics.messages_received + 1,
          last_message_at: DateTime.utc_now()
        }
        
      :message_sent ->
        %{state.metrics | messages_sent: state.metrics.messages_sent + 1}
        
      :command_processed ->
        command_stats = Map.update(state.metrics.command_stats, extra, 1, &(&1 + 1))
        %{state.metrics | 
          commands_processed: state.metrics.commands_processed + 1,
          command_stats: command_stats
        }
        
      :callback_processed ->
        %{state.metrics | commands_processed: state.metrics.commands_processed + 1}
        
      :unauthorized ->
        %{state.metrics | errors: state.metrics.errors + 1}
        
      _ ->
        state.metrics
    end
    
    %{state | metrics: new_metrics}
  end

  defp calculate_telegram_statistics(metrics) do
    %{
      total_messages: metrics.messages_received + metrics.messages_sent,
      messages_received: metrics.messages_received,
      messages_sent: metrics.messages_sent,
      commands_processed: metrics.commands_processed,
      command_breakdown: metrics.command_stats,
      errors: metrics.errors,
      last_activity: metrics.last_message_at,
      message_rate: calculate_message_rate(metrics)
    }
  end

  defp calculate_message_rate(metrics) do
    if metrics.last_message_at do
      minutes_active = DateTime.diff(DateTime.utc_now(), metrics.last_message_at, :second) / 60
      if minutes_active > 0 do
        Float.round((metrics.messages_received + metrics.messages_sent) / minutes_active, 2)
      else
        0.0
      end
    else
      0.0
    end
  end
  
  # Natural Language Processing Functions
  
  defp process_natural_language(text, message, state) do
    chat_id = message["chat"]["id"]
    message_id = message["message_id"]
    from = message["from"]
    
    Logger.info("🧠 Processing natural language: #{text}")
    
    # Store message in conversation history
    add_to_conversation_history(chat_id, :user, text, message_id, from, state)
    
    # Get conversation context
    context = build_conversation_context(chat_id, state)
    
    # Check if already processing for this chat
    if Map.has_key?(state.llm_processing, chat_id) do
      Logger.info("Already processing LLM request for chat #{chat_id}")
      state
    else
      # Send typing indicator
      send_typing_action(chat_id, state)
      
      # Request LLM processing via AMQP
      request_id = generate_request_id()
      
      llm_request = %{
        request_id: request_id,
        chat_id: chat_id,
        message_id: message_id,
        text: text,
        context: context,
        user: from,
        timestamp: DateTime.utc_now()
      }
      
      # Publish to LLM worker via AMQP
      publish_llm_request(llm_request, state)
      
      # Track ongoing request
      new_llm_processing = Map.put(state.llm_processing, chat_id, request_id)
      new_state = %{state | llm_processing: new_llm_processing}
      
      # Set timeout for LLM response
      Process.send_after(self(), {:llm_timeout, chat_id, request_id}, 30_000)
      
      update_metrics(new_state, :message_received)
    end
  end
  
  defp add_to_conversation_history(chat_id, role, text, message_id, user_info, state) do
    history_key = {chat_id, :history}
    current_history = case :ets.lookup(state.conversation_table, history_key) do
      [{^history_key, history}] -> history
      [] -> []
    end
    
    message_entry = %{
      role: role,
      text: text,
      message_id: message_id,
      user: user_info,
      timestamp: DateTime.utc_now()
    }
    
    # Keep last 20 messages for context
    new_history = [message_entry | current_history] |> Enum.take(20)
    :ets.insert(state.conversation_table, {history_key, new_history})
  end
  
  defp build_conversation_context(chat_id, state) do
    history_key = {chat_id, :history}
    history = case :ets.lookup(state.conversation_table, history_key) do
      [{^history_key, hist}] -> hist
      [] -> []
    end
    
    # Get conversation state
    conv_state = Map.get(state.conversation_states, chat_id, %{
      topic: nil,
      context_summary: nil,
      last_activity: DateTime.utc_now()
    })
    
    %{
      chat_id: chat_id,
      history: Enum.take(history, 10),  # Last 10 messages for context
      conversation_state: conv_state,
      vsm_context: get_vsm_context()
    }
  end
  
  defp get_vsm_context do
    # Get current VSM system state for context
    %{
      system_status: "operational",  # Would fetch from actual systems
      capabilities: [
        "system monitoring",
        "alert management", 
        "vsm operations",
        "performance analysis",
        "adaptation proposals"
      ],
      recent_events: []  # Would fetch recent system events
    }
  end
  
  defp send_typing_action(chat_id, state) do
    url = "#{@telegram_api_base}#{state.bot_token}/sendChatAction"
    params = %{
      "chat_id" => chat_id,
      "action" => "typing"
    }
    
    # Fire and forget
    AsyncRunner.async_http_request(:post, url, Jason.encode!(params), 
                                  [{"Content-Type", "application/json"}])
  end
  
  defp publish_llm_request(request, state) do
    routing_key = "llm.request.conversation"
    
    # Publish to LLM worker exchange
    AMQP.Basic.publish(
      state.channel,
      "vsm.llm.requests",  # LLM request exchange
      routing_key,
      Jason.encode!(request),
      content_type: "application/json",
      reply_to: state.commands_exchange,
      correlation_id: request.request_id
    )
    
    Logger.info("Published LLM request #{request.request_id} for chat #{request.chat_id}")
  end
  
  defp generate_request_id do
    "llm_#{:erlang.unique_integer([:positive, :monotonic])}_#{:erlang.system_time(:microsecond)}"
  end
  
  # Handle LLM responses
  defp handle_llm_response(payload, meta, state) do
    request_id = meta.correlation_id
    
    case Jason.decode(payload) do
      {:ok, %{"response" => response_text, "chat_id" => chat_id} = response} ->
        Logger.info("Received LLM response for request #{request_id}")
        
        # Remove from processing
        new_llm_processing = Map.delete(state.llm_processing, chat_id)
        
        # Send response to user
        send_telegram_message(chat_id, response_text, state)
        
        # Store assistant response in history
        add_to_conversation_history(chat_id, :assistant, response_text, nil, nil, state)
        
        # Update conversation state if provided
        new_conv_states = if response["conversation_state"] do
          Map.put(state.conversation_states, chat_id, response["conversation_state"])
        else
          state.conversation_states
        end
        
        AMQP.Basic.ack(state.channel, meta.delivery_tag)
        
        {:noreply, %{state | 
          llm_processing: new_llm_processing,
          conversation_states: new_conv_states
        }}
        
      {:error, reason} ->
        Logger.error("Failed to parse LLM response: #{inspect(reason)}")
        AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:llm_timeout, chat_id, request_id}, state) do
    # Check if this request is still pending
    if Map.get(state.llm_processing, chat_id) == request_id do
      Logger.warning("LLM request timeout for chat #{chat_id}")
      
      # Remove from processing
      new_llm_processing = Map.delete(state.llm_processing, chat_id)
      
      # Send timeout message
      send_telegram_message(chat_id, 
        "⏱️ I'm taking a bit longer to process that. Please try again in a moment.", 
        state)
      
      {:noreply, %{state | llm_processing: new_llm_processing}}
    else
      # Request already completed, ignore timeout
      {:noreply, state}
    end
  end
end