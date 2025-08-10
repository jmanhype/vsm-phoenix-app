defmodule VsmPhoenix.TelegramBot.CommandOrchestrator do
  @moduledoc """
  Sub-Agent Command Orchestrator for Telegram Bot.
  
  Replaces monolithic command handlers with intelligent sub-agent delegation,
  enabling parallel processing, specialized handling, and hierarchical task breakdown
  for complex Telegram bot operations.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.SubAgentOrchestrator
  alias VsmPhoenix.ContextManager
  alias VsmPhoenix.TelegramBot.{ConversationManager, SecurityLayer}
  alias VsmPhoenix.PromptArchitecture
  alias VsmPhoenix.GEPAFramework
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Process Telegram command through intelligent sub-agent delegation.
  
  ## Examples:
  
      CommandOrchestrator.process_command(
        "/status detailed",
        %{"chat" => %{"id" => 123456}},
        %{agent_id: "telegram_agent_1"}
      )
  """
  def process_command(text, message, state) do
    GenServer.call(__MODULE__, {:process_command, text, message, state}, 30_000)
  end
  
  @doc """
  Handle complex multi-step commands through hierarchical delegation.
  """
  def process_complex_command(command_chain, chat_id, state) do
    GenServer.cast(__MODULE__, {:process_complex, command_chain, chat_id, state})
  end
  
  @doc """
  Get command processing statistics and active delegations.
  """
  def get_command_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  # Server Callbacks
  
  def init(opts) do
    Logger.info("🎯 Starting Telegram Command Orchestrator with sub-agent delegation")
    
    {:ok, %{
      opts: opts,
      active_delegations: %{},
      command_stats: %{
        commands_processed: 0,
        delegations_created: 0,
        avg_response_time: 0.0
      }
    }}
  end
  
  def handle_call({:process_command, text, message, state}, from, server_state) do
    start_time = System.monotonic_time(:millisecond)
    chat_id = message["chat"]["id"]
    
    # Parse command and arguments
    [command | args] = String.split(text, " ")
    command = String.trim_leading(command, "/")
    
    Logger.debug("🎯 Processing command '#{command}' with #{length(args)} args")
    
    # Security verification
    case SecurityLayer.verify_incoming_message(message, state.agent_id) do
      {:ok, _verification} ->
        # Determine optimal sub-agent and task description
        {agent_type, task_description, delegation_config} = determine_command_agent(command, args, message)
        
        # Build rich context for sub-agent
        command_context = build_command_context(command, args, message, state)
        
        # Store delegation info
        delegation_id = generate_delegation_id(chat_id, command)
        delegation_record = %{
          id: delegation_id,
          command: command,
          args: args,
          chat_id: chat_id,
          agent_type: agent_type,
          started_at: start_time,
          from: from,
          state: state
        }
        
        # Spawn async delegation task
        task = Task.async(fn ->
          delegate_command_to_agent(task_description, command_context, delegation_config)
        end)
        
        # Update server state
        new_active_delegations = Map.put(server_state.active_delegations, delegation_id, {task, delegation_record})
        new_stats = %{
          server_state.command_stats |
          commands_processed: server_state.command_stats.commands_processed + 1,
          delegations_created: server_state.command_stats.delegations_created + 1
        }
        
        # Return immediate acknowledgment
        {:reply, {:ok, :delegated, delegation_id}, %{
          server_state |
          active_delegations: new_active_delegations,
          command_stats: new_stats
        }}
        
      {:error, reason} ->
        Logger.warning("❌ Command security verification failed: #{inspect(reason)}")
        {:reply, {:error, :security_violation, reason}, server_state}
    end
  end
  
  def handle_call(:get_stats, _from, state) do
    # Include active delegation count
    stats_with_active = Map.put(state.command_stats, :active_delegations, map_size(state.active_delegations))
    {:reply, {:ok, stats_with_active}, state}
  end
  
  def handle_cast({:process_complex, command_chain, chat_id, state}, server_state) do
    Logger.info("🔗 Processing complex command chain: #{command_chain}")
    
    # Parse complex command chain
    # Example: "/vsm spawn config=high-availability then status then notify admin"
    task_description = """
    Execute complex Telegram command sequence for chat #{chat_id}:
    #{command_chain}
    
    Break down into hierarchical subtasks:
    1. Parse command chain into individual operations
    2. Execute operations in sequence with dependency management
    3. Report progress to Telegram chat after each major step
    4. Handle failures gracefully with rollback capabilities
    5. Provide final comprehensive report
    """
    
    context = %{
      command_chain: command_chain,
      chat_id: chat_id,
      telegram_agent_id: state.agent_id,
      progress_reporting: true,
      security_level: determine_security_level("complex", %{}),
      execution_mode: :hierarchical
    }
    
    # Spawn long-running hierarchical task
    Task.start(fn ->
      case SubAgentOrchestrator.hierarchical_execute(
        %{description: task_description, context: context},
        5 # max depth for complex chains
      ) do
        {:ok, result} ->
          formatted_result = format_complex_result(result, command_chain)
          send_telegram_response(chat_id, formatted_result, state)
          
        {:error, reason} ->
          error_msg = """
          ❌ *Complex Command Failed*
          
          Chain: `#{command_chain}`
          Error: #{inspect(reason)}
          
          Please try breaking the command into smaller steps.
          """
          send_telegram_response(chat_id, error_msg, state)
      end
    end)
    
    # Send immediate acknowledgment
    ack_msg = """
    🔄 *Processing Complex Command*
    
    Command Chain: `#{command_chain}`
    Status: Delegated to hierarchical sub-agents
    
    I'll report progress as each step completes...
    """
    send_telegram_response(chat_id, ack_msg, state)
    
    {:noreply, server_state}
  end
  
  def handle_info({ref, result}, state) when is_reference(ref) do
    # Handle completed delegation task
    case find_delegation_by_task_ref(ref, state.active_delegations) do
      {delegation_id, delegation_record} ->
        # Calculate response time
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - delegation_record.started_at
        
        # Process delegation result
        process_delegation_result(result, delegation_record, response_time)
        
        # Update statistics
        current_avg = state.command_stats.avg_response_time
        command_count = state.command_stats.commands_processed
        new_avg = if command_count > 1 do
          (current_avg * (command_count - 1) + response_time) / command_count
        else
          response_time
        end
        
        new_stats = %{state.command_stats | avg_response_time: new_avg}
        
        # Remove from active delegations
        new_active_delegations = Map.delete(state.active_delegations, delegation_id)
        
        # Reply to original caller
        GenServer.reply(delegation_record.from, result)
        
        {:noreply, %{
          state |
          active_delegations: new_active_delegations,
          command_stats: new_stats
        }}
        
      nil ->
        # Unknown task reference, ignore
        {:noreply, state}
    end
  end
  
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # Handle failed delegation task
    case find_delegation_by_task_ref(ref, state.active_delegations) do
      {delegation_id, delegation_record} ->
        Logger.error("❌ Delegation task failed for command: #{delegation_record.command}")
        
        # Send error response
        error_result = {:error, :delegation_failed}
        GenServer.reply(delegation_record.from, error_result)
        
        # Remove from active delegations
        new_active_delegations = Map.delete(state.active_delegations, delegation_id)
        
        {:noreply, %{state | active_delegations: new_active_delegations}}
        
      nil ->
        {:noreply, state}
    end
  end
  
  # Private Functions
  
  defp determine_command_agent(command, args, message) do
    chat_id = message["chat"]["id"]
    user_context = get_user_context(chat_id)
    
    case command do
      "start" ->
        {:telegram_specialist, 
         "Welcome new Telegram user with VSM system introduction and capability overview",
         %{priority: :standard, timeout: 10_000}}
      
      "help" ->
        {:documentation_specialist,
         "Provide comprehensive help documentation for VSM Telegram bot commands and features",
         %{priority: :standard, timeout: 15_000}}
      
      "status" ->
        detail_level = if "detailed" in args, do: :comprehensive, else: :summary
        {:analysis_specialist,
         "Analyze and report VSM system status with #{detail_level} level detail including CRDT sync, security status, and performance metrics",
         %{priority: :high, timeout: 20_000, detail_level: detail_level}}
      
      "vsm" when length(args) > 0 ->
        vsm_operation = hd(args)
        case vsm_operation do
          "spawn" ->
            {:recursive_spawner,
             "Execute VSM recursive spawning with configuration: #{Enum.join(args, " ")}. Ensure CRDT coordination and security verification.",
             %{priority: :high, timeout: 60_000, requires_admin: true}}
          
          "sync" ->
            {:crdt_specialist,
             "Perform CRDT synchronization across all VSM nodes with conflict resolution and integrity verification",
             %{priority: :high, timeout: 30_000}}
          
          "health" ->
            {:monitoring_specialist,
             "Execute comprehensive VSM health check including distributed systems, security, and performance monitoring",
             %{priority: :medium, timeout: 25_000}}
          
          _ ->
            {:analysis_specialist,
             "Handle general VSM operation: #{vsm_operation} with parameters: #{inspect(Enum.drop(args, 1))}",
             %{priority: :medium, timeout: 20_000}}
        end
      
      "security" ->
        security_operation = if length(args) > 0, do: hd(args), else: "status"
        {:security_specialist,
         "Handle security operation: #{security_operation} with cryptographic verification and audit trail creation",
         %{priority: :high, timeout: 20_000, requires_admin: true}}
      
      "coordinate" ->
        {:coordination_specialist,
         "Execute distributed coordination protocols: #{Enum.join(args, " ")} with consensus-based decision making",
         %{priority: :high, timeout: 45_000}}
      
      "performance" ->
        {:performance_specialist,
         "Analyze system performance metrics and provide optimization recommendations: #{Enum.join(args, " ")}",
         %{priority: :medium, timeout: 15_000}}
      
      "admin" ->
        if is_admin_user?(message["from"], user_context) do
          {:admin_specialist,
           "Execute administrative operation: #{Enum.join(args, " ")} with full system privileges and audit logging",
           %{priority: :critical, timeout: 30_000, requires_admin: true}}
        else
          {:security_specialist,
           "Reject unauthorized admin access attempt and log security event",
           %{priority: :high, timeout: 5_000}}
        end
      
      _ ->
        # Unknown command - delegate to analysis specialist for interpretation
        {:analysis_specialist,
         "Interpret and respond to unknown Telegram command: #{command} with args: #{inspect(args)}. Provide helpful suggestions.",
         %{priority: :standard, timeout: 15_000}}
    end
  end
  
  defp build_command_context(command, args, message, state) do
    chat_id = message["chat"]["id"]
    
    # Get conversation history for context
    {:ok, history} = ConversationManager.get_conversation_history(chat_id, limit: 5)
    
    # Get user preferences
    {:ok, conversation_context} = ConversationManager.get_conversation_context(chat_id)
    
    %{
      # Command details
      command: command,
      args: args,
      raw_text: "/#{command} #{Enum.join(args, " ")}",
      
      # Chat context
      chat_id: chat_id,
      user: message["from"],
      chat_type: message["chat"]["type"],
      
      # System context
      telegram_agent_id: state.agent_id,
      node_id: node(),
      timestamp: System.system_time(:millisecond),
      
      # Conversation context
      conversation_history: history,
      conversation_context: conversation_context,
      user_preferences: conversation_context.user_preferences,
      
      # Security context
      security_level: determine_security_level(command, message),
      is_admin: is_admin_user?(message["from"], conversation_context),
      
      # Processing hints
      response_format: :telegram_markdown,
      max_response_length: 4096,
      include_emojis: true,
      model_optimization: determine_optimal_model(command, conversation_context)
    }
  end
  
  defp delegate_command_to_agent(task_description, context, config) do
    Logger.debug("🎯 Delegating to #{config[:priority]} priority agent: #{String.slice(task_description, 0, 50)}...")
    
    # Generate optimized prompt for the specific model
    optimized_prompt = generate_command_prompt(task_description, context)
    enhanced_context = Map.put(context, :optimized_prompt, optimized_prompt)
    
    # Delegate with timeout and configuration
    case SubAgentOrchestrator.delegate_task(task_description, enhanced_context) do
      {:ok, result} ->
        # Process and format result for Telegram
        telegram_result = format_telegram_response(result, context)
        
        # Send response to Telegram
        send_telegram_response(context.chat_id, telegram_result, %{agent_id: context.telegram_agent_id})
        
        # Store interaction in conversation history
        ConversationManager.store_message(
          context.chat_id,
          %{
            "text" => telegram_result,
            "from" => %{"id" => "vsm_bot", "first_name" => "VSM"},
            "date" => System.system_time(:second),
            "message_id" => :rand.uniform(1000000)
          },
          context.telegram_agent_id
        )
        
        {:ok, telegram_result}
        
      {:error, reason} ->
        error_msg = format_error_response(reason, context)
        send_telegram_response(context.chat_id, error_msg, %{agent_id: context.telegram_agent_id})
        {:error, reason}
    end
  end
  
  defp generate_command_prompt(task_description, context) do
    # Use GEPA framework for model-optimized prompts
    model_family = context.model_optimization || :claude
    
    case GEPAFramework.generate_system_prompt(model_family, :telegram_command, %{
      task: task_description,
      command: context.command,
      args: context.args,
      user_context: context.user_preferences,
      conversation_context: context.conversation_context,
      security_level: context.security_level
    }) do
      {:ok, optimized_prompt} ->
        enhance_telegram_command_prompt(optimized_prompt, context)
        
      {:error, _reason} ->
        # Fallback to basic prompt architecture
        PromptArchitecture.generate_system_prompt(:telegram_command, %{
          command: context.command,
          args: context.args,
          context: context
        })
    end
  end
  
  defp enhance_telegram_command_prompt(base_prompt, context) do
    """
    <system>
    You are executing a specialized Telegram bot command through the VSM Phoenix distributed architecture.
    
    ## Command Context:
    <command>
    Command: /#{context.command} #{Enum.join(context.args, " ")}
    Chat ID: #{context.chat_id}
    User: #{context.user["first_name"]} (@#{context.user["username"] || "unknown"})
    Security Level: #{context.security_level}
    Admin Status: #{context.is_admin}
    </command>
    
    ## System Architecture:
    <architecture>
    - CRDT-synchronized distributed state across all nodes
    - AES-256-GCM cryptographic security with audit trails
    - Sub-agent orchestration with specialized domain experts
    - Real-time performance monitoring with 35x efficiency targeting
    - Consensus-based coordination for critical operations
    </architecture>
    
    ## Response Requirements:
    <response_format>
    - Use Telegram markdown formatting (*bold*, `code`, _italic_)
    - Include relevant emojis (🤖 system, ⚡ performance, 🔒 security, ✅ success, ❌ error)
    - Maximum length: #{context.max_response_length} characters
    - Provide actionable information and next steps
    - Reference VSM capabilities when relevant
    </response_format>
    
    #{base_prompt}
    
    ## Current Context:
    User has #{length(context.conversation_history)} messages in history.
    Recent conversation topics: #{extract_topics(context.conversation_context)}
    User interaction style: #{context.user_preferences.interaction_style || :standard}
    </system>
    
    <user_command>
    /#{context.command} #{Enum.join(context.args, " ")}
    </user_command>
    """
  end
  
  defp format_telegram_response(result, context) do
    # Format sub-agent result for Telegram display
    case result do
      %{response: response, metadata: metadata} when is_binary(response) ->
        if String.length(response) > context.max_response_length do
          truncated = String.slice(response, 0, context.max_response_length - 100)
          "#{truncated}...\n\n_Response truncated due to length._"
        else
          response
        end
        
      %{error: error_msg} ->
        "❌ *Command Error*\n\n#{error_msg}"
        
      response when is_binary(response) ->
        response
        
      _ ->
        "✅ Command completed successfully."
    end
  end
  
  defp format_error_response(reason, context) do
    """
    ❌ *Command Processing Failed*
    
    Command: `/#{context.command}`
    Error: #{inspect(reason)}
    
    Please try again or use `/help` for available commands.
    """
  end
  
  defp format_complex_result(result, command_chain) do
    """
    ✅ *Complex Command Completed*
    
    Chain: `#{command_chain}`
    
    #{format_hierarchical_result(result)}
    
    _All operations completed successfully._
    """
  end
  
  defp format_hierarchical_result(result) do
    case result do
      %{steps: steps} when is_list(steps) ->
        steps
        |> Enum.with_index(1)
        |> Enum.map(fn {step, index} ->
          "#{index}. #{step[:description] || "Step completed"} ✅"
        end)
        |> Enum.join("\n")
        
      %{response: response} when is_binary(response) ->
        response
        
      _ ->
        "All hierarchical operations completed successfully."
    end
  end
  
  defp send_telegram_response(chat_id, text, state) do
    # This would integrate with the existing telegram send function
    # For now, just log the response
    Logger.info("📤 Sending to chat #{chat_id}: #{String.slice(text, 0, 100)}...")
  end
  
  defp determine_security_level(command, message) do
    admin_commands = ["vsm", "security", "coordinate", "admin"]
    sensitive_commands = ["spawn", "sync", "rotate-keys"]
    
    cond do
      command in admin_commands -> :high
      Enum.any?(sensitive_commands, &String.contains?(command, &1)) -> :high
      true -> :standard
    end
  end
  
  defp determine_optimal_model(command, conversation_context) do
    # Analyze command type and user preferences to select optimal model
    user_prefs = conversation_context.user_preferences || %{}
    
    cond do
      command in ["status", "health", "performance"] and user_prefs[:prefers_detailed_responses] ->
        :claude # Best for detailed technical analysis
        
      command in ["help", "start"] ->
        :gpt # Good for conversational help
        
      String.contains?(command, "visual") or String.contains?(command, "diagram") ->
        :gemini # Best for multimodal content
        
      true ->
        :claude # Default for VSM operations
    end
  end
  
  defp is_admin_user?(user, conversation_context) do
    # Check if user has admin privileges based on conversation context
    admin_users = conversation_context[:admin_users] || []
    user["id"] in admin_users
  end
  
  defp get_user_context(chat_id) do
    # Get user context from conversation manager
    case ConversationManager.get_conversation_context(chat_id) do
      {:ok, context} -> context
      _ -> %{}
    end
  end
  
  defp extract_topics(conversation_context) do
    conversation_context[:conversation_topics] || []
    |> Enum.take(3)
    |> Enum.join(", ")
  end
  
  defp generate_delegation_id(chat_id, command) do
    timestamp = System.system_time(:millisecond)
    "delegation_#{chat_id}_#{command}_#{timestamp}"
  end
  
  defp find_delegation_by_task_ref(ref, active_delegations) do
    Enum.find_value(active_delegations, fn {delegation_id, {task, record}} ->
      if task.ref == ref, do: {delegation_id, record}, else: nil
    end)
  end
  
  defp process_delegation_result(result, delegation_record, response_time) do
    Logger.info("✅ Command '#{delegation_record.command}' completed in #{response_time}ms")
    
    # Log to security audit trail
    SecurityLayer.log_security_event(:command_completed, %{
      command: delegation_record.command,
      chat_id: delegation_record.chat_id,
      response_time: response_time,
      agent_type: delegation_record.agent_type
    }, delegation_record.state.agent_id)
  end
end