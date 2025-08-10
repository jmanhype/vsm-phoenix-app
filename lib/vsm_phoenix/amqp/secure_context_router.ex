defmodule VsmPhoenix.AMQP.SecureContextRouter do
  @moduledoc """
  Secure Context Router combining CRDT persistence with cryptographic security.
  
  This module provides a secure, distributed communication layer for VSM agents:
  - CRDT-based distributed state synchronization
  - Cryptographic message security with replay protection
  - Automatic context persistence across agent restarts
  - Secure command routing with authentication
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.CRDT.ContextStore
  alias VsmPhoenix.Security.CryptoLayer
  alias VsmPhoenix.Infrastructure.Security
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @name __MODULE__
  @secure_exchange "vsm.secure.context"
  @command_exchange "vsm.secure.commands"
  
  # Message types
  @context_sync "context.sync"
  @secure_command "secure.command"
  @context_update "context.update"
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Send a secure command with context
  """
  def send_secure_command(agent_id, command, context \\ %{}) do
    GenServer.call(@name, {:send_command, agent_id, command, context})
  end
  
  @doc """
  Update shared context using CRDT
  """
  def update_context(key, value, crdt_type \\ :lww) do
    GenServer.call(@name, {:update_context, key, value, crdt_type})
  end
  
  @doc """
  Get current context value
  """
  def get_context(key) do
    GenServer.call(@name, {:get_context, key})
  end
  
  @doc """
  Establish secure channel between agents
  """
  def establish_agent_channel(agent_a, agent_b) do
    GenServer.call(@name, {:establish_channel, agent_a, agent_b})
  end
  
  @doc """
  Get router metrics
  """
  def get_metrics do
    GenServer.call(@name, :get_metrics)
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("🔐🔄 Initializing Secure Context Router")
    
    node_id = opts[:node_id] || node()
    
    # Initialize crypto layer for this node
    {:ok, _} = CryptoLayer.initialize_node_security(node_id)
    
    state = %{
      node_id: node_id,
      channel: nil,
      agents: %{},
      metrics: %{
        commands_sent: 0,
        commands_received: 0,
        context_updates: 0,
        security_errors: 0,
        channels_established: 0
      }
    }
    
    # Set up AMQP
    send(self(), :setup_amqp)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:send_command, agent_id, command, context}, _from, state) do
    Logger.debug("📤 Sending secure command to agent: #{agent_id}")
    
    # Update context in CRDT
    update_command_context(command, context)
    
    # Prepare command payload
    payload = %{
      command: command,
      context: context,
      sender: state.node_id,
      timestamp: :erlang.system_time(:millisecond)
    }
    
    # Encrypt the payload
    case CryptoLayer.encrypt_message(Jason.encode!(payload), agent_id, sender_id: state.node_id) do
      {:ok, encrypted_envelope} ->
        # Wrap with security layer
        case Security.wrap_secure_message(Jason.encode!(encrypted_envelope), get_agent_key(agent_id)) do
          secure_message when is_map(secure_message) ->
            # Publish to AMQP
            routing_key = "agent.#{agent_id}.command"
            
            if state.channel do
              AMQP.Basic.publish(
                state.channel,
                @command_exchange,
                routing_key,
                Jason.encode!(secure_message),
                persistent: true,
                content_type: "application/json"
              )
              
              new_state = update_metrics(state, :commands_sent)
              {:reply, :ok, new_state}
            else
              {:reply, {:error, :no_channel}, state}
            end
            
          error ->
            new_state = update_metrics(state, :security_errors)
            {:reply, {:error, error}, new_state}
        end
        
      {:error, reason} ->
        new_state = update_metrics(state, :security_errors)
        {:reply, {:error, reason}, new_state}
    end
  end
  
  @impl true
  def handle_call({:update_context, key, value, crdt_type}, _from, state) do
    result = case crdt_type do
      :lww ->
        ContextStore.set_lww(key, value)
      :counter ->
        ContextStore.increment_counter(key, value)
      :pn_counter ->
        ContextStore.update_pn_counter(key, value)
      :set ->
        ContextStore.add_to_set(key, value)
      _ ->
        {:error, :unsupported_crdt_type}
    end
    
    case result do
      {:ok, _} ->
        new_state = update_metrics(state, :context_updates)
        
        # Broadcast context update
        broadcast_context_update(key, value, crdt_type, state)
        
        {:reply, :ok, new_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:get_context, key}, _from, state) do
    result = ContextStore.get(key)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:establish_channel, agent_a, agent_b}, _from, state) do
    case CryptoLayer.establish_secure_channel(agent_a, agent_b) do
      {:ok, channel_info} ->
        # Store channel info
        new_agents = state.agents
        |> Map.update(agent_a, %{channels: [agent_b]}, fn a ->
          %{a | channels: Enum.uniq([agent_b | a.channels])}
        end)
        |> Map.update(agent_b, %{channels: [agent_a]}, fn b ->
          %{b | channels: Enum.uniq([agent_a | b.channels])}
        end)
        
        new_state = %{state | 
          agents: new_agents,
          metrics: Map.update!(state.metrics, :channels_established, &(&1 + 1))
        }
        
        {:reply, {:ok, channel_info}, new_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_metrics, _from, state) do
    # Combine metrics from all layers
    {:ok, crypto_metrics} = CryptoLayer.get_security_metrics()
    {:ok, crdt_state} = ContextStore.get_state()
    
    combined_metrics = %{
      router: state.metrics,
      crypto: crypto_metrics,
      context_items: map_size(crdt_state.gcounters) + 
                     map_size(crdt_state.pncounters) + 
                     map_size(crdt_state.orsets) + 
                     map_size(crdt_state.lww_sets),
      active_agents: map_size(state.agents)
    }
    
    {:reply, {:ok, combined_metrics}, state}
  end
  
  @impl true
  def handle_info(:setup_amqp, state) do
    case ConnectionManager.get_channel(:secure_context) do
      {:ok, channel} ->
        # Set up exchanges
        :ok = AMQP.Exchange.declare(channel, @secure_exchange, :topic, durable: true)
        :ok = AMQP.Exchange.declare(channel, @command_exchange, :topic, durable: true)
        
        # Set up queue for this node
        queue = "vsm.secure.#{state.node_id}"
        {:ok, _} = AMQP.Queue.declare(channel, queue, durable: true)
        
        # Bind to receive commands for this node
        :ok = AMQP.Queue.bind(channel, queue, @command_exchange, 
          routing_key: "agent.#{state.node_id}.#"
        )
        
        # Bind to receive context updates
        :ok = AMQP.Queue.bind(channel, queue, @secure_exchange,
          routing_key: "context.#"
        )
        
        # Start consuming
        {:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue)
        
        Logger.info("✅ Secure Context Router AMQP setup complete")
        
        {:noreply, %{state | channel: channel}}
        
      {:error, reason} ->
        Logger.error("Failed to setup AMQP: #{inspect(reason)}")
        Process.send_after(self(), :setup_amqp, 5_000)
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    routing_key = meta.routing_key
    
    case String.split(routing_key, ".") do
      ["agent", _agent_id, "command"] ->
        handle_secure_command(payload, state)
        
      ["context", "update"] ->
        handle_context_update(payload, state)
        
      _ ->
        Logger.debug("Unknown routing key: #{routing_key}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    {:noreply, state}
  end
  
  # Private Functions
  
  defp handle_secure_command(payload, state) do
    with {:ok, wrapped} <- Jason.decode(payload),
         {:ok, envelope_json} <- Security.unwrap_secure_message(wrapped, get_node_key()),
         {:ok, encrypted_envelope} <- Jason.decode(envelope_json),
         {:ok, decrypted} <- CryptoLayer.decrypt_message(encrypted_envelope, encrypted_envelope.sender_id),
         {:ok, command_data} <- Jason.decode(decrypted) do
      
      Logger.info("🔐 Received secure command: #{command_data["command"]}")
      
      # Process the command
      process_secure_command(command_data, state)
      
      new_state = update_metrics(state, :commands_received)
      {:noreply, new_state}
    else
      {:error, reason} ->
        Logger.error("Failed to process secure command: #{inspect(reason)}")
        new_state = update_metrics(state, :security_errors)
        {:noreply, new_state}
    end
  end
  
  defp handle_context_update(payload, state) do
    with {:ok, update} <- Jason.decode(payload) do
      # Apply CRDT update
      apply_context_update(update)
      
      new_state = update_metrics(state, :context_updates)
      {:noreply, new_state}
    else
      _ ->
        {:noreply, state}
    end
  end
  
  defp process_secure_command(command_data, state) do
    # Extract command and context
    command = command_data["command"]
    context = command_data["context"] || %{}
    sender = command_data["sender"]
    
    # Update agent info
    new_agents = Map.update(state.agents, sender, %{last_seen: :erlang.system_time(:millisecond)}, fn agent ->
      %{agent | last_seen: :erlang.system_time(:millisecond)}
    end)
    
    # Broadcast command event
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:secure:commands",
      {:secure_command, command, context, sender}
    )
    
    %{state | agents: new_agents}
  end
  
  defp update_command_context(command, context) do
    # Store command context in CRDT
    ContextStore.set_lww("last_command:#{command}", context)
    ContextStore.increment_counter("command_count:#{command}")
  end
  
  defp broadcast_context_update(key, value, crdt_type, state) do
    if state.channel do
      update = %{
        type: @context_update,
        key: key,
        value: value,
        crdt_type: crdt_type,
        node_id: state.node_id,
        timestamp: :erlang.system_time(:millisecond)
      }
      
      AMQP.Basic.publish(
        state.channel,
        @secure_exchange,
        "context.update",
        Jason.encode!(update)
      )
    end
  end
  
  defp apply_context_update(update) do
    case update["crdt_type"] do
      "lww" ->
        ContextStore.set_lww(update["key"], update["value"])
      "counter" ->
        ContextStore.increment_counter(update["key"], update["value"])
      "pn_counter" ->
        ContextStore.update_pn_counter(update["key"], update["value"])
      "set" ->
        ContextStore.add_to_set(update["key"], update["value"])
      _ ->
        Logger.warning("Unknown CRDT type: #{update["crdt_type"]}")
    end
  end
  
  defp get_agent_key(agent_id) do
    # In production, this would retrieve the agent's specific key
    # For now, use a derived key
    Application.get_env(:vsm_phoenix, :agent_secret_key, "default_agent_key_#{agent_id}")
  end
  
  defp get_node_key do
    # In production, this would retrieve the node's specific key
    Application.get_env(:vsm_phoenix, :node_secret_key, "default_node_key")
  end
  
  defp update_metrics(state, metric) do
    %{state |
      metrics: Map.update!(state.metrics, metric, &(&1 + 1))
    }
  end
end