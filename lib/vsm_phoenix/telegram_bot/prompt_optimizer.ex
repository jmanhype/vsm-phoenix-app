defmodule VsmPhoenix.TelegramBot.PromptOptimizer do
  @moduledoc """
  XML-Formatted Prompt Optimization for Telegram Bot Interactions.
  
  Replaces basic string-based prompts with sophisticated XML-structured prompts
  optimized for different model families and conversation contexts. Integrates
  with GEPA framework for 35x efficiency targeting.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.PromptArchitecture
  alias VsmPhoenix.GEPAFramework
  alias VsmPhoenix.ContextManager
  alias VsmPhoenix.TelegramBot.ConversationManager
  alias VsmPhoenix.Security.CryptoLayer
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Generate sophisticated XML-structured prompt for Telegram interaction.
  
  ## Examples:
  
      PromptOptimizer.generate_telegram_prompt(
        "How is the system status?",
        %{chat_id: 123456, user: %{"first_name" => "Alice"}},
        :claude
      )
  """
  def generate_telegram_prompt(user_message, chat_context, model_family \\ :claude) do
    GenServer.call(__MODULE__, {:generate_prompt, user_message, chat_context, model_family}, 15_000)
  end
  
  @doc """
  Generate command-specific prompts with XML structure and domain expertise.
  """
  def generate_command_prompt(command, args, chat_context, model_family \\ :claude) do
    GenServer.call(__MODULE__, {:generate_command_prompt, command, args, chat_context, model_family})
  end
  
  @doc """
  Optimize prompts based on chat history and user interaction patterns.
  """
  def optimize_for_chat_patterns(chat_id) do
    GenServer.call(__MODULE__, {:optimize_patterns, chat_id})
  end
  
  @doc """
  Get prompt generation statistics and performance metrics.
  """
  def get_optimization_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  # Server Callbacks
  
  def init(opts) do
    Logger.info("🎨 Starting XML Prompt Optimizer for Telegram interactions")
    
    # Initialize prompt templates cache
    templates_cache = initialize_prompt_templates()
    
    {:ok, %{
      opts: opts,
      templates_cache: templates_cache,
      optimization_stats: %{
        prompts_generated: 0,
        avg_generation_time: 0.0,
        model_usage: %{claude: 0, gpt: 0, gemini: 0, llama: 0},
        efficiency_improvements: []
      }
    }}
  end
  
  def handle_call({:generate_prompt, user_message, chat_context, model_family}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    # Get comprehensive conversation context
    conversation_history = get_conversation_summary(chat_context.chat_id)
    system_context = build_system_context(chat_context)
    
    # Analyze user intent and message complexity
    intent = analyze_message_intent(user_message)
    complexity = assess_message_complexity(user_message, conversation_history)
    
    # Generate model-optimized base prompt
    case generate_base_prompt(model_family, user_message, chat_context, intent, complexity) do
      {:ok, base_prompt} ->
        # Enhance with Telegram-specific optimizations
        enhanced_prompt = enhance_telegram_prompt(base_prompt, chat_context, system_context)
        
        # Add cryptographic integrity if required
        signed_prompt = if chat_context[:security_level] == :high do
          add_cryptographic_integrity(enhanced_prompt, chat_context[:agent_id])
        else
          enhanced_prompt
        end
        
        # Update statistics
        end_time = System.monotonic_time(:millisecond)
        generation_time = end_time - start_time
        new_state = update_optimization_stats(state, model_family, generation_time)
        
        {:reply, {:ok, signed_prompt}, new_state}
        
      {:error, reason} ->
        # Fallback to basic prompt
        fallback_prompt = generate_fallback_prompt(user_message, chat_context)
        Logger.warning("Using fallback prompt due to: #{inspect(reason)}")
        
        {:reply, {:ok, fallback_prompt}, state}
    end
  end
  
  def handle_call({:generate_command_prompt, command, args, chat_context, model_family}, _from, state) do
    # Generate specialized command prompts with domain expertise
    command_context = build_command_context(command, args, chat_context)
    
    # Determine command domain and required expertise
    {domain, expertise_level} = determine_command_domain(command, args)
    
    # Generate domain-specific prompt with XML structure
    case GEPAFramework.generate_system_prompt(model_family, domain, command_context) do
      {:ok, base_prompt} ->
        enhanced_prompt = enhance_command_prompt(base_prompt, command, args, chat_context, expertise_level)
        
        # Update command-specific statistics
        new_model_usage = Map.update(state.optimization_stats.model_usage, model_family, 1, &(&1 + 1))
        new_stats = %{state.optimization_stats | model_usage: new_model_usage}
        
        {:reply, {:ok, enhanced_prompt}, %{state | optimization_stats: new_stats}}
        
      {:error, reason} ->
        Logger.warning("Command prompt generation failed: #{inspect(reason)}")
        fallback_prompt = generate_command_fallback(command, args, chat_context)
        {:reply, {:ok, fallback_prompt}, state}
    end
  end
  
  def handle_call({:optimize_patterns, chat_id}, _from, state) do
    # Analyze chat history to determine optimal model family and prompt patterns
    case analyze_chat_preferences(chat_id) do
      {:ok, preferences} ->
        optimal_model = determine_optimal_model_family(preferences)
        optimization_suggestions = generate_optimization_suggestions(preferences)
        
        result = %{
          optimal_model: optimal_model,
          preferences: preferences,
          suggestions: optimization_suggestions
        }
        
        {:reply, {:ok, result}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call(:get_stats, _from, state) do
    {:reply, {:ok, state.optimization_stats}, state}
  end
  
  # Private Functions
  
  defp initialize_prompt_templates do
    %{
      telegram_base: load_telegram_base_template(),
      command_templates: load_command_templates(),
      model_optimizations: load_model_optimizations(),
      system_contexts: load_system_contexts()
    }
  end
  
  defp generate_base_prompt(model_family, user_message, chat_context, intent, complexity) do
    # Use GEPA framework for sophisticated prompt generation
    prompt_params = %{
      user_message: user_message,
      chat_context: chat_context,
      intent: intent,
      complexity: complexity,
      interaction_type: :telegram,
      efficiency_target: 35.0
    }
    
    case GEPAFramework.generate_system_prompt(model_family, :telegram_interaction, prompt_params) do
      {:ok, prompt} -> {:ok, prompt}
      error -> error
    end
  end
  
  defp enhance_telegram_prompt(base_prompt, chat_context, system_context) do
    user = chat_context[:user] || %{}
    conversation_stats = get_conversation_stats(chat_context[:chat_id])
    
    """
    <system>
    You are the VSM Phoenix Telegram Bot, an advanced distributed systems interface powered by CRDT synchronization, cryptographic security, and intelligent sub-agent orchestration.
    
    ## Core Architecture:
    <architecture>
    🏗️ **Distributed Systems**: CRDT-synchronized state across multiple nodes with mathematical consistency guarantees
    🔒 **Cryptographic Security**: AES-256-GCM encryption with HMAC signatures for all sensitive operations
    🤖 **Sub-Agent Orchestration**: Specialized domain experts for complex task delegation and parallel processing
    ⚡ **Performance Optimization**: 35x efficiency targeting through GEPA framework optimization
    🔄 **Consensus Coordination**: Byzantine fault-tolerant protocols for critical system operations
    </architecture>
    
    ## Current Context:
    <context>
    💬 **Chat**: #{chat_context[:chat_id]} (#{conversation_stats.message_count} messages)
    👤 **User**: #{user["first_name"]} (@#{user["username"] || "unknown"})
    🆔 **Agent**: #{chat_context[:agent_id] || "telegram_agent"}
    🔐 **Security**: #{chat_context[:security_level] || "standard"} level
    📍 **Node**: #{system_context.node_id}
    ⏰ **Time**: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    </context>
    
    ## System Capabilities:
    <capabilities>
    📊 **System Monitoring**: Real-time status, health checks, performance metrics
    🔄 **VSM Operations**: Recursive spawning, system coordination, distributed consensus
    🛡️ **Security Management**: Cryptographic operations, audit trails, access control
    📈 **Performance Analysis**: Bottleneck detection, optimization recommendations
    🤝 **Coordination Protocols**: Multi-node synchronization, conflict resolution
    💾 **Data Management**: CRDT operations, distributed storage, backup/recovery
    </capabilities>
    
    ## Response Guidelines:
    <guidelines>
    ✅ **Format**: Use Telegram markdown (*bold*, `code`, _italic_) with appropriate emojis
    📏 **Length**: Maximum 4096 characters (Telegram limit)
    🎯 **Accuracy**: Provide precise information about VSM Phoenix capabilities and status
    💡 **Helpful**: Suggest relevant commands and next steps when applicable
    🔍 **Context-Aware**: Reference conversation history and user preferences
    ⚡ **Efficient**: Aim for clear, concise responses that maximize information density
    </guidelines>
    
    ## Integration Points:
    <integration>
    🔗 **CRDT Sync**: Query distributed state via ContextManager for real-time data
    🔐 **Security Layer**: All operations verified through cryptographic signatures
    🎯 **Sub-Agents**: Delegate complex operations to specialized domain experts
    📊 **Telemetry**: Access performance metrics and system health indicators
    🤖 **AI Optimization**: Model-family specific prompt optimization for efficiency
    </integration>
    
    #{base_prompt}
    
    ## System Reminders:
    #{ContextManager.generate_system_reminders([:telegram, :vsm, :security])}
    </system>
    
    <user_context>
    Message Count: #{conversation_stats.message_count}
    User Preferences: #{format_user_preferences(chat_context)}
    Conversation Topics: #{extract_conversation_topics(chat_context)}
    Interaction Style: #{determine_interaction_style(chat_context)}
    </user_context>
    
    <user_message>
    #{chat_context[:user_message] || "User interaction"}
    </user_message>
    """
  end
  
  defp enhance_command_prompt(base_prompt, command, args, chat_context, expertise_level) do
    command_metadata = get_command_metadata(command, args)
    security_requirements = determine_security_requirements(command, args)
    
    """
    <system>
    You are executing a specialized VSM Phoenix Telegram command with #{expertise_level} level expertise.
    
    ## Command Context:
    <command>
    🔧 **Command**: /#{command} #{Enum.join(args, " ")}
    👤 **User**: #{get_in(chat_context, [:user, "first_name"]) || "User"}
    💬 **Chat**: #{chat_context[:chat_id]}
    🔐 **Security**: #{security_requirements.level}
    ⚡ **Priority**: #{command_metadata.priority}
    🎯 **Domain**: #{command_metadata.domain}
    </command>
    
    ## VSM System Integration:
    <vsm_integration>
    📊 **System Status**: Query CRDT-synchronized telemetry for real-time metrics
    🔄 **Coordination**: Use consensus protocols for distributed operations
    🛡️ **Security**: All operations require cryptographic verification
    🎯 **Sub-Agents**: Delegate to specialized agents (#{Enum.join(command_metadata.suggested_agents, ", ")})
    📈 **Performance**: Target 35x efficiency improvement through optimization
    </vsm_integration>
    
    ## Command Specifications:
    <specifications>
    #{generate_command_specifications(command, args, command_metadata)}
    </specifications>
    
    ## Safety Protocols:
    <safety>
    #{generate_safety_protocols(command, security_requirements)}
    </safety>
    
    #{base_prompt}
    
    ## Expected Output Format:
    <output_format>
    📤 **Format**: Telegram markdown with emojis
    📏 **Length**: Maximum 4096 characters
    ✅ **Success**: Clear status indicators and next steps
    ❌ **Errors**: Detailed error messages with recovery suggestions
    📊 **Data**: Structured data presentation with proper formatting
    </output_format>
    </system>
    
    <command_execution>
    Execute: /#{command} #{Enum.join(args, " ")}
    Context: #{inspect(chat_context, limit: :infinity)}
    </command_execution>
    """
  end
  
  defp add_cryptographic_integrity(prompt, agent_id) do
    # Sign the prompt for integrity verification
    timestamp = System.system_time(:millisecond)
    prompt_hash = :crypto.hash(:sha256, prompt) |> Base.encode16(case: :lower)
    
    signature = CryptoLayer.sign_message(%{
      prompt_hash: prompt_hash,
      timestamp: timestamp,
      agent_id: agent_id
    }, agent_id)
    
    """
    <prompt_integrity>
    Hash: #{prompt_hash}
    Timestamp: #{timestamp}
    Signature: #{signature}
    Agent: #{agent_id}
    </prompt_integrity>
    
    #{prompt}
    """
  end
  
  defp get_conversation_summary(chat_id) do
    case ConversationManager.get_conversation_history(chat_id, limit: 10, include_context: true) do
      {:ok, history} -> history
      _ -> []
    end
  end
  
  defp build_system_context(chat_context) do
    %{
      node_id: node(),
      timestamp: System.system_time(:millisecond),
      system_health: get_system_health(),
      active_agents: get_active_agents_count(),
      crdt_sync_status: get_crdt_sync_status(),
      security_status: get_security_status()
    }
  end
  
  defp analyze_message_intent(user_message) when is_binary(user_message) do
    text_lower = String.downcase(user_message)
    
    cond do
      String.contains?(text_lower, ["status", "health", "system"]) ->
        :system_inquiry
      String.contains?(text_lower, ["help", "how", "what", "?"]) ->
        :help_seeking
      String.contains?(text_lower, ["spawn", "create", "start"]) ->
        :creation_request
      String.contains?(text_lower, ["sync", "coordinate", "update"]) ->
        :coordination_request
      String.contains?(text_lower, ["security", "encrypt", "sign"]) ->
        :security_operation
      String.contains?(text_lower, ["performance", "optimize", "improve"]) ->
        :performance_inquiry
      true ->
        :general_conversation
    end
  end
  
  defp analyze_message_intent(_), do: :unknown
  
  defp assess_message_complexity(user_message, conversation_history) do
    complexity_score = 0
    
    # Length-based complexity
    complexity_score = complexity_score + min(String.length(user_message) / 100, 1.0)
    
    # Technical term complexity
    technical_terms = ["crdt", "sync", "consensus", "byzantine", "cryptographic", "distributed"]
    tech_count = Enum.count(technical_terms, &String.contains?(String.downcase(user_message), &1))
    complexity_score = complexity_score + min(tech_count / 3, 1.0)
    
    # Conversation context complexity
    if length(conversation_history) > 5 do
      complexity_score = complexity_score + 0.5
    end
    
    cond do
      complexity_score < 0.3 -> :simple
      complexity_score < 0.7 -> :medium
      true -> :complex
    end
  end
  
  defp build_command_context(command, args, chat_context) do
    %{
      command: command,
      args: args,
      chat_context: chat_context,
      command_type: determine_command_type(command),
      requires_admin: requires_admin_privileges?(command),
      execution_context: :telegram,
      security_level: determine_command_security_level(command)
    }
  end
  
  defp determine_command_domain(command, args) do
    case command do
      "status" -> {:system_monitoring, :intermediate}
      "vsm" -> 
        vsm_op = if length(args) > 0, do: hd(args), else: "general"
        case vsm_op do
          "spawn" -> {:recursive_systems, :expert}
          "sync" -> {:distributed_coordination, :expert}
          _ -> {:system_operations, :intermediate}
        end
      "security" -> {:cryptographic_security, :expert}
      "coordinate" -> {:distributed_coordination, :expert}
      "performance" -> {:performance_analysis, :intermediate}
      "help" -> {:documentation, :basic}
      _ -> {:general_assistance, :basic}
    end
  end
  
  defp analyze_chat_preferences(chat_id) do
    case ConversationManager.get_conversation_context(chat_id) do
      {:ok, context} ->
        preferences = %{
          prefers_detailed: analyze_detail_preference(context),
          technical_user: analyze_technical_level(context),
          response_style: analyze_response_style(context),
          interaction_frequency: analyze_interaction_frequency(context),
          command_usage: analyze_command_patterns(context)
        }
        {:ok, preferences}
        
      error -> error
    end
  end
  
  defp determine_optimal_model_family(preferences) do
    cond do
      preferences.technical_user and preferences.prefers_detailed ->
        :claude # Best for detailed technical explanations
        
      preferences.response_style == :concise ->
        :gpt # Good for concise, direct responses
        
      preferences.interaction_frequency == :high ->
        :claude # Best for contextual conversations
        
      true ->
        :claude # Default for VSM operations
    end
  end
  
  defp generate_optimization_suggestions(preferences) do
    suggestions = []
    
    suggestions = if preferences.prefers_detailed do
      ["Enable detailed response mode", "Include technical explanations" | suggestions]
    else
      ["Use concise response format", "Focus on key information" | suggestions]
    end
    
    suggestions = if preferences.technical_user do
      ["Include system internals", "Show command examples" | suggestions]
    else
      ["Use simplified explanations", "Provide step-by-step guides" | suggestions]
    end
    
    suggestions
  end
  
  defp generate_fallback_prompt(user_message, chat_context) do
    """
    You are the VSM Phoenix Telegram Bot. Respond helpfully to: #{user_message}
    
    Chat ID: #{chat_context[:chat_id]}
    User: #{get_in(chat_context, [:user, "first_name"]) || "User"}
    
    Use Telegram markdown and keep responses under 4096 characters.
    """
  end
  
  defp generate_command_fallback(command, args, chat_context) do
    """
    Execute Telegram command: /#{command} #{Enum.join(args, " ")}
    
    For chat: #{chat_context[:chat_id]}
    User: #{get_in(chat_context, [:user, "first_name"]) || "User"}
    
    Provide helpful response with appropriate formatting.
    """
  end
  
  # Helper functions for template loading and context building
  
  defp load_telegram_base_template, do: %{}
  defp load_command_templates, do: %{}
  defp load_model_optimizations, do: %{}
  defp load_system_contexts, do: %{}
  
  defp get_conversation_stats(chat_id) do
    case ConversationManager.get_conversation_context(chat_id) do
      {:ok, context} -> 
        %{message_count: context.message_count || 0}
      _ -> 
        %{message_count: 0}
    end
  end
  
  defp format_user_preferences(chat_context) do
    prefs = chat_context[:user_preferences] || %{}
    
    prefs
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join(", ")
  end
  
  defp extract_conversation_topics(chat_context) do
    chat_context[:conversation_topics] || []
    |> Enum.take(3)
    |> Enum.join(", ")
  end
  
  defp determine_interaction_style(chat_context) do
    chat_context[:user_preferences][:interaction_style] || :standard
  end
  
  defp get_command_metadata(command, args) do
    %{
      priority: determine_command_priority(command),
      domain: determine_command_domain(command, args) |> elem(0),
      suggested_agents: get_suggested_agents(command),
      estimated_duration: estimate_command_duration(command, args)
    }
  end
  
  defp determine_security_requirements(command, _args) do
    case command do
      cmd when cmd in ["vsm", "security", "coordinate", "admin"] ->
        %{level: :high, requires_auth: true}
      cmd when cmd in ["status", "performance"] ->
        %{level: :medium, requires_auth: false}
      _ ->
        %{level: :standard, requires_auth: false}
    end
  end
  
  defp generate_command_specifications(command, args, metadata) do
    """
    Command: #{command}
    Arguments: #{inspect(args)}
    Domain: #{metadata.domain}
    Estimated Duration: #{metadata.estimated_duration}ms
    Required Agents: #{Enum.join(metadata.suggested_agents, ", ")}
    """
  end
  
  defp generate_safety_protocols(command, security_requirements) do
    protocols = ["Verify user authorization", "Log all operations"]
    
    protocols = if security_requirements.level == :high do
      ["Require cryptographic verification", "Create audit trail" | protocols]
    else
      protocols
    end
    
    Enum.join(protocols, "\n- ")
  end
  
  # Placeholder implementations for missing functions
  defp get_system_health, do: :healthy
  defp get_active_agents_count, do: 5
  defp get_crdt_sync_status, do: :synchronized
  defp get_security_status, do: :secure
  
  defp determine_command_type(_command), do: :system
  defp requires_admin_privileges?(command), do: command in ["vsm", "security", "admin"]
  defp determine_command_security_level(command) do
    if command in ["vsm", "security"], do: :high, else: :standard
  end
  
  defp analyze_detail_preference(_context), do: true
  defp analyze_technical_level(_context), do: true
  defp analyze_response_style(_context), do: :detailed
  defp analyze_interaction_frequency(_context), do: :medium
  defp analyze_command_patterns(_context), do: %{}
  
  defp determine_command_priority(command) do
    case command do
      cmd when cmd in ["vsm", "security"] -> :high
      cmd when cmd in ["status", "coordinate"] -> :medium
      _ -> :standard
    end
  end
  
  defp get_suggested_agents(command) do
    case command do
      "status" -> ["analysis_specialist"]
      "vsm" -> ["recursive_spawner", "crdt_specialist"]
      "security" -> ["security_specialist"]
      "coordinate" -> ["coordination_specialist"]
      _ -> ["general_assistant"]
    end
  end
  
  defp estimate_command_duration(command, args) do
    base_time = 1000 # 1 second base
    complexity_multiplier = length(args) * 500 # 500ms per arg
    
    command_multiplier = case command do
      "vsm" -> 3
      "coordinate" -> 2
      "security" -> 2
      _ -> 1
    end
    
    base_time + complexity_multiplier * command_multiplier
  end
  
  defp update_optimization_stats(state, model_family, generation_time) do
    current_stats = state.optimization_stats
    
    # Update counters
    new_prompts_count = current_stats.prompts_generated + 1
    
    # Update average generation time
    current_avg = current_stats.avg_generation_time
    new_avg = if new_prompts_count > 1 do
      (current_avg * (new_prompts_count - 1) + generation_time) / new_prompts_count
    else
      generation_time
    end
    
    # Update model usage
    new_model_usage = Map.update(current_stats.model_usage, model_family, 1, &(&1 + 1))
    
    # Record efficiency improvement
    efficiency_record = %{
      timestamp: System.system_time(:millisecond),
      model_family: model_family,
      generation_time: generation_time
    }
    new_efficiency_improvements = [efficiency_record | Enum.take(current_stats.efficiency_improvements, 99)]
    
    new_stats = %{
      current_stats |
      prompts_generated: new_prompts_count,
      avg_generation_time: new_avg,
      model_usage: new_model_usage,
      efficiency_improvements: new_efficiency_improvements
    }
    
    %{state | optimization_stats: new_stats}
  end
end