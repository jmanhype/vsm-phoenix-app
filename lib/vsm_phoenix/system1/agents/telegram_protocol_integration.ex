defmodule VsmPhoenix.System1.Agents.TelegramProtocolIntegration do
  @moduledoc """
  Integration layer connecting Telegram Agent with Advanced aMCP Protocol Extensions.
  
  Enables the Telegram bot to:
  - Announce itself via Discovery protocol
  - Participate in consensus decisions
  - Use network optimization for message batching
  - Leverage secure distributed coordination
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.AMQP.{Discovery, Consensus, ProtocolIntegration, NetworkOptimizer}
  alias VsmPhoenix.System1.Agents.TelegramAgent
  
  @agent_capabilities [:telegram_bot, :user_interface, :alert_handler, :command_processor]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Initialize Telegram agent with protocol extensions
  """
  def initialize_telegram_with_protocol(telegram_agent_id, bot_username) do
    GenServer.call(__MODULE__, {:initialize_telegram, telegram_agent_id, bot_username})
  end
  
  @doc """
  Handle incoming Telegram command with consensus
  """
  def handle_command_with_consensus(command, chat_id, user_info) do
    GenServer.call(__MODULE__, {:handle_command, command, chat_id, user_info}, 10_000)
  end
  
  @doc """
  Send alert through optimized network
  """
  def send_optimized_alert(chat_ids, alert_message, priority \\ :normal) do
    GenServer.cast(__MODULE__, {:send_alert, chat_ids, alert_message, priority})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🔌 Telegram Protocol Integration initializing...")
    
    state = %{
      telegram_agents: %{},
      active_commands: %{},
      metrics: %{
        announcements: 0,
        consensus_commands: 0,
        optimized_messages: 0,
        distributed_operations: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:initialize_telegram, agent_id, bot_username}, _from, state) do
    Logger.info("🤖 Initializing Telegram agent #{agent_id} with protocol extensions")
    
    # Announce the Telegram agent via Discovery protocol
    metadata = %{
      bot_username: bot_username,
      agent_type: :telegram,
      started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      protocol_version: "2.0"
    }
    
    Discovery.announce(agent_id, @agent_capabilities, metadata)
    
    # Register agent in state
    agent_info = %{
      id: agent_id,
      username: bot_username,
      capabilities: @agent_capabilities,
      announced_at: DateTime.utc_now()
    }
    
    new_agents = Map.put(state.telegram_agents, agent_id, agent_info)
    new_metrics = Map.update!(state.metrics, :announcements, &(&1 + 1))
    
    # Subscribe to coordination events for this agent
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "protocol:telegram:#{agent_id}")
    
    {:reply, :ok, %{state | 
      telegram_agents: new_agents,
      metrics: new_metrics
    }}
  end
  
  @impl true
  def handle_call({:handle_command, command, chat_id, user_info}, from, state) do
    Logger.info("⚡ Processing command with consensus: #{command}")
    
    command_id = generate_command_id()
    
    # Store command context
    command_context = %{
      id: command_id,
      command: command,
      chat_id: chat_id,
      user_info: user_info,
      from: from,
      started_at: DateTime.utc_now()
    }
    
    new_commands = Map.put(state.active_commands, command_id, command_context)
    
    # Determine if command requires consensus
    if requires_consensus?(command) do
      # Use ProtocolIntegration for coordinated action
      spawn(fn ->
        result = ProtocolIntegration.coordinate_action(
          "telegram_bot",
          :execute_command,
          %{
            command: command,
            user: user_info,
            context: %{chat_id: chat_id}
          },
          timeout: 5_000,
          quorum: determine_quorum(command),
          urgency: determine_urgency(command)
        )
        
        GenServer.cast(__MODULE__, {:consensus_result, command_id, result})
      end)
      
      new_metrics = Map.update!(state.metrics, :consensus_commands, &(&1 + 1))
      
      {:noreply, %{state | 
        active_commands: new_commands,
        metrics: new_metrics
      }}
    else
      # Execute immediately without consensus
      result = execute_command_directly(command, command_context)
      new_metrics = Map.update!(state.metrics, :distributed_operations, &(&1 + 1))
      
      {:reply, result, %{state | metrics: new_metrics}}
    end
  end
  
  @impl true
  def handle_cast({:send_alert, chat_ids, alert_message, priority}, state) do
    Logger.info("📢 Sending optimized alert to #{length(chat_ids)} chats")
    
    # Use NetworkOptimizer for efficient delivery
    Enum.each(chat_ids, fn chat_id ->
      message = %{
        type: :telegram_alert,
        chat_id: chat_id,
        text: alert_message,
        priority: priority,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      # Get channel from pool
      {:ok, channel} = VsmPhoenix.AMQP.ChannelPool.checkout(:telegram_alerts)
      
      NetworkOptimizer.send_optimized(
        channel,
        "vsm.telegram.alerts",
        "alert.#{priority}",
        message,
        immediate: priority == :critical
      )
      
      # Return channel to pool
      VsmPhoenix.AMQP.ChannelPool.checkin(:telegram_alerts, channel)
    end)
    
    new_metrics = Map.update!(state.metrics, :optimized_messages, &(&1 + length(chat_ids)))
    
    {:noreply, %{state | metrics: new_metrics}}
  end
  
  @impl true
  def handle_cast({:consensus_result, command_id, result}, state) do
    case Map.get(state.active_commands, command_id) do
      %{from: from} = context ->
        # Reply to original caller with consensus result
        case result do
          {:ok, :committed, _} ->
            Logger.info("✅ Command #{command_id} approved by consensus")
            response = execute_command_directly(context.command, context)
            GenServer.reply(from, {:ok, response})
            
          {:error, reason} ->
            Logger.warning("❌ Command #{command_id} rejected: #{inspect(reason)}")
            GenServer.reply(from, {:error, :consensus_rejected})
        end
        
        # Clean up
        new_commands = Map.delete(state.active_commands, command_id)
        {:noreply, %{state | active_commands: new_commands}}
        
      nil ->
        Logger.warning("Received consensus result for unknown command: #{command_id}")
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info({:discovered_agent, agent_info}, state) do
    # Handle discovered Telegram agents for coordination
    if :telegram_bot in agent_info.capabilities do
      Logger.info("🔍 Discovered fellow Telegram agent: #{agent_info.id}")
      
      # Could coordinate with other Telegram bots here
      # For example, load balancing or failover
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp requires_consensus?(command) do
    # Commands that modify system state require consensus
    command_type = parse_command_type(command)
    
    command_type in [
      :restart_service,
      :modify_config,
      :emergency_shutdown,
      :deploy_update,
      :change_policy,
      :alter_resources
    ]
  end
  
  defp determine_quorum(command) do
    # Critical commands need more agreement
    case parse_command_type(command) do
      :emergency_shutdown -> :all
      :deploy_update -> :majority
      :modify_config -> :majority
      _ -> 2
    end
  end
  
  defp determine_urgency(command) do
    case parse_command_type(command) do
      :emergency_shutdown -> :critical
      :restart_service -> :high
      _ -> :normal
    end
  end
  
  defp parse_command_type(command) do
    cond do
      String.contains?(command, ["shutdown", "stop"]) -> :emergency_shutdown
      String.contains?(command, ["restart", "reboot"]) -> :restart_service
      String.contains?(command, ["config", "setting"]) -> :modify_config
      String.contains?(command, ["deploy", "update"]) -> :deploy_update
      String.contains?(command, ["policy", "rule"]) -> :change_policy
      String.contains?(command, ["resource", "allocate"]) -> :alter_resources
      String.contains?(command, ["status", "info"]) -> :read_only
      true -> :unknown
    end
  end
  
  defp execute_command_directly(command, context) do
    # Execute the command
    # In a real implementation, this would route to appropriate handlers
    Logger.info("Executing command: #{command} for chat #{context.chat_id}")
    
    %{
      success: true,
      command: command,
      executed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      response: "Command executed successfully"
    }
  end
  
  defp generate_command_id do
    "CMD-#{:erlang.unique_integer([:positive])}-#{:erlang.system_time(:millisecond)}"
  end
end