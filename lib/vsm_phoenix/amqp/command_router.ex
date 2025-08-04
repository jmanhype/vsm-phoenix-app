defmodule VsmPhoenix.AMQP.CommandRouter do
  @moduledoc """
  Implements bidirectional AMQP communication with RPC pattern for VSM commands.
  
  ## Architecture:
  - Upward flow (S1→S5): Events use fan-out exchanges for broadcasting
  - Downward flow (S5→S1): Commands use RPC pattern for direct responses
  - Direct-reply-to pattern for efficient RPC without declaring response queues
  
  ## Command Flow:
  1. S5/S4/S3 issues command with correlation_id
  2. Command sent to specific system queue (e.g., vsm.system1.commands)
  3. Target system processes and replies to 'amq.rabbitmq.reply-to'
  4. CommandRPC.call/2 blocks until response received
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.ConnectionManager
  alias AMQP
  
  @command_exchange "vsm.commands"
  @event_exchanges %{
    algedonic: "vsm.algedonic",
    coordination: "vsm.coordination", 
    control: "vsm.control",
    intelligence: "vsm.intelligence",
    policy: "vsm.policy"
  }
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Routes an event upward through fan-out exchanges
  """
  def publish_event(event_type, payload) when is_atom(event_type) do
    GenServer.cast(__MODULE__, {:publish_event, event_type, payload})
  end
  
  @doc """
  Routes a command downward to a specific system
  """
  def send_command(target_system, command, timeout \\ 5000) do
    GenServer.call(__MODULE__, {:send_command, target_system, command, timeout}, timeout + 1000)
  end
  
  @doc """
  Registers a command handler for a specific system
  """
  def register_handler(system, handler_fn) when is_function(handler_fn, 2) do
    GenServer.call(__MODULE__, {:register_handler, system, handler_fn})
  end
  
  # Server implementation
  
  def init(_opts) do
    Logger.info("🎯 Initializing Command Router with RPC support")
    
    # Get or create channel for routing
    case ConnectionManager.get_channel(:command_router) do
      {:ok, channel} ->
        setup_topology(channel)
        
        state = %{
          channel: channel,
          handlers: %{},
          pending_rpcs: %{},
          consumer_tags: %{}
        }
        
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("Failed to get channel: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  def handle_cast({:publish_event, event_type, payload}, state) do
    exchange = Map.get(@event_exchanges, event_type)
    
    if exchange do
      message = Jason.encode!(%{
        type: "event",
        event_type: event_type,
        payload: payload,
        timestamp: DateTime.utc_now(),
        source: node()
      })
      
      # Fan-out exchanges don't use routing keys
      AMQP.Basic.publish(state.channel, exchange, "", message)
      Logger.debug("📤 Published #{event_type} event to #{exchange}")
    else
      Logger.warn("Unknown event type: #{event_type}")
    end
    
    {:noreply, state}
  end
  
  def handle_call({:send_command, target_system, command, timeout}, from, state) do
    # Use separate channel for RPC to avoid conflicts
    case ConnectionManager.get_channel(:rpc) do
      {:ok, rpc_channel} ->
        correlation_id = generate_correlation_id()
        
        # Declare callback queue with Direct-reply-to
        # This is a special RabbitMQ feature for efficient RPC
        reply_queue = "amq.rabbitmq.reply-to"
        
        # Start consuming from reply queue if not already
        state = ensure_reply_consumer(state, rpc_channel, reply_queue)
        
        # Build command message
        message = Jason.encode!(%{
          type: "command",
          command: command,
          correlation_id: correlation_id,
          reply_to: reply_queue,
          timestamp: DateTime.utc_now(),
          source: node()
        })
        
        # Send command to target system's command queue
        target_queue = "vsm.#{target_system}.commands"
        
        # Store pending RPC info
        new_state = put_in(state.pending_rpcs[correlation_id], %{
          from: from,
          timeout_ref: Process.send_after(self(), {:rpc_timeout, correlation_id}, timeout)
        })
        
        # Publish command
        AMQP.Basic.publish(rpc_channel, "", target_queue, message,
          reply_to: reply_queue,
          correlation_id: correlation_id
        )
        
        Logger.debug("📮 Sent RPC command to #{target_queue} with correlation_id: #{correlation_id}")
        
        {:noreply, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:register_handler, system, handler_fn}, _from, state) do
    # Set up command queue for this system
    queue_name = "vsm.#{system}.commands"
    
    case AMQP.Queue.declare(state.channel, queue_name, durable: true) do
      {:ok, _} ->
        # Start consuming from command queue
        {:ok, consumer_tag} = AMQP.Basic.consume(state.channel, queue_name)
        
        new_state = state
        |> put_in([:handlers, system], handler_fn)
        |> put_in([:consumer_tags, queue_name], consumer_tag)
        
        Logger.info("✅ Registered command handler for #{system}")
        
        {:reply, :ok, new_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  # Handle incoming commands (for systems that registered handlers)
  def handle_info({:basic_deliver, payload, meta}, state) do
    with {:ok, message} <- Jason.decode(payload),
         %{"type" => "command"} <- message do
      
      # Extract system from queue name
      system = extract_system_from_queue(meta.routing_key)
      
      case Map.get(state.handlers, system) do
        nil ->
          Logger.warn("No handler registered for system: #{system}")
          
        handler_fn ->
          # Execute handler and send response
          Task.start(fn ->
            try do
              result = handler_fn.(message["command"], message)
              send_command_response(state.channel, message, {:ok, result})
            rescue
              e ->
                send_command_response(state.channel, message, {:error, Exception.message(e)})
            end
          end)
      end
    end
    
    {:noreply, state}
  end
  
  # Handle RPC responses
  def handle_info({:basic_deliver, payload, %{correlation_id: correlation_id} = meta}, state) do
    case Map.pop(state.pending_rpcs, correlation_id) do
      {nil, _} ->
        Logger.warn("Received response for unknown correlation_id: #{correlation_id}")
        {:noreply, state}
        
      {rpc_info, new_pending} ->
        # Cancel timeout
        Process.cancel_timer(rpc_info.timeout_ref)
        
        # Parse response
        response = case Jason.decode(payload) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:ok, %{"error" => error}} -> {:error, error}
          {:error, reason} -> {:error, {:decode_error, reason}}
        end
        
        # Reply to waiting caller
        GenServer.reply(rpc_info.from, response)
        
        {:noreply, %{state | pending_rpcs: new_pending}}
    end
  end
  
  # Handle RPC timeouts
  def handle_info({:rpc_timeout, correlation_id}, state) do
    case Map.pop(state.pending_rpcs, correlation_id) do
      {nil, _} ->
        {:noreply, state}
        
      {rpc_info, new_pending} ->
        GenServer.reply(rpc_info.from, {:error, :timeout})
        {:noreply, %{state | pending_rpcs: new_pending}}
    end
  end
  
  # Private functions
  
  defp setup_topology(channel) do
    # Declare command exchange (topic routing to match existing)
    AMQP.Exchange.declare(channel, @command_exchange, :direct, durable: true)
    
    # Event exchanges are already declared in ConnectionManager
    Logger.info("📋 Command routing topology ready")
  end
  
  defp ensure_reply_consumer(state, channel, reply_queue) do
    case Map.get(state.consumer_tags, reply_queue) do
      nil ->
        # Start consuming from reply queue
        {:ok, consumer_tag} = AMQP.Basic.consume(channel, reply_queue, no_ack: true)
        put_in(state.consumer_tags[reply_queue], consumer_tag)
        
      _ ->
        state
    end
  end
  
  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end
  
  defp extract_system_from_queue(queue_name) do
    case String.split(queue_name, ".") do
      ["vsm", system, "commands"] -> String.to_atom(system)
      _ -> nil
    end
  end
  
  defp send_command_response(channel, command_message, response) do
    reply_to = command_message["reply_to"]
    correlation_id = command_message["correlation_id"]
    
    response_payload = case response do
      {:ok, result} ->
        %{status: "success", result: result, correlation_id: correlation_id}
        
      {:error, error} ->
        %{status: "error", error: error, correlation_id: correlation_id}
    end
    
    message = Jason.encode!(response_payload)
    
    AMQP.Basic.publish(channel, "", reply_to, message,
      correlation_id: correlation_id
    )
  end
end