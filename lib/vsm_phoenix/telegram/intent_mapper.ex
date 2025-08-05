defmodule VsmPhoenix.Telegram.IntentMapper do
  @moduledoc """
  Maps NLU intents to Telegram bot commands and provides fallback handling.
  
  Translates natural language intents into executable commands while
  maintaining backward compatibility with existing command structure.
  """
  
  require Logger
  
  @intent_command_mappings %{
    get_status: %{
      command: "/status",
      handler: :handle_status_command,
      required_entities: [],
      optional_entities: [:subsystem, :time_range]
    },
    spawn_vsm: %{
      command: "/vsm spawn",
      handler: :handle_vsm_command,
      required_entities: [],
      optional_entities: [:type, :agent_count, :config]
    },
    list_vsms: %{
      command: "/vsm list",
      handler: :handle_vsm_command,
      required_entities: [],
      optional_entities: []
    },
    send_alert: %{
      command: "/alert",
      handler: :handle_alert_command,
      required_entities: [:level, :message],
      optional_entities: [:target_chats]
    },
    help: %{
      command: "/help",
      handler: :handle_help_command,
      required_entities: [],
      optional_entities: [:topic]
    },
    authorize: %{
      command: "/authorize",
      handler: :handle_authorize_command,
      required_entities: [:chat_id],
      optional_entities: []
    },
    get_metrics: %{
      command: "/metrics",
      handler: :handle_metrics_command,
      required_entities: [],
      optional_entities: [:component, :time_range]
    },
    explain_vsm: %{
      command: nil,  # No direct command mapping
      handler: :handle_explanation,
      required_entities: [],
      optional_entities: [:topic]
    },
    control_system: %{
      command: nil,
      handler: :handle_system_control,
      required_entities: [:action, :target],
      optional_entities: [:parameters]
    },
    query_data: %{
      command: nil,
      handler: :handle_data_query,
      required_entities: [:query_type],
      optional_entities: [:filters, :time_range]
    },
    configure: %{
      command: nil,
      handler: :handle_configuration,
      required_entities: [:config_type],
      optional_entities: [:settings]
    }
  }
  
  @doc """
  Map an intent to a command structure.
  
  Returns:
    {:ok, %{
      command: string,
      args: list,
      handler: atom,
      context: map
    }}
    
    or
    
    {:error, reason}
  """
  def map_intent_to_command(intent, entities, context \\ %{}) do
    case Map.get(@intent_command_mappings, intent) do
      nil ->
        {:error, :unknown_intent}
        
      mapping ->
        validate_and_build_command(intent, mapping, entities, context)
    end
  end
  
  @doc """
  Get command suggestions for a partial input.
  """
  def get_command_suggestions(partial_input, context \\ %{}) do
    normalized_input = String.downcase(String.trim(partial_input))
    
    # Find matching commands
    suggestions = @intent_command_mappings
    |> Enum.filter(fn {_intent, mapping} ->
      mapping.command && String.contains?(mapping.command, normalized_input)
    end)
    |> Enum.map(fn {intent, mapping} ->
      %{
        command: mapping.command,
        intent: intent,
        description: get_intent_description(intent),
        example: get_command_example(intent)
      }
    end)
    |> Enum.take(5)
    
    # Add contextual suggestions
    add_contextual_suggestions(suggestions, context)
  end
  
  @doc """
  Handle fallback when no intent is recognized.
  """
  def handle_fallback(message, context) do
    cond do
      # Check if it's a yes/no response to a pending confirmation
      String.match?(message, ~r/^(yes|no|y|n)$/i) ->
        {:confirmation_response, parse_boolean(message)}
        
      # Check if it's a number response to a flow
      String.match?(message, ~r/^\d+$/) ->
        {:numeric_response, String.to_integer(message)}
        
      # Check if it's a selection from options
      String.match?(message, ~r/^[a-z]$/i) ->
        {:option_selection, message}
        
      # Default fallback
      true ->
        suggest_similar_commands(message, context)
    end
  end
  
  @doc """
  Build a natural language response for a command result.
  """
  def format_command_response(intent, result, entities) do
    case intent do
      :get_status ->
        format_status_response(result)
        
      :spawn_vsm ->
        format_vsm_spawn_response(result, entities)
        
      :list_vsms ->
        format_vsm_list_response(result)
        
      :send_alert ->
        format_alert_response(result, entities)
        
      :explain_vsm ->
        format_explanation_response(result, entities)
        
      _ ->
        format_generic_response(result)
    end
  end
  
  @doc """
  Get contextual help for an intent.
  """
  def get_intent_help(intent) do
    case Map.get(@intent_command_mappings, intent) do
      nil ->
        "I don't have information about that intent."
        
      mapping ->
        build_intent_help(intent, mapping)
    end
  end
  
  # Private Functions
  
  defp validate_and_build_command(intent, mapping, entities, context) do
    # Check required entities
    missing_entities = Enum.filter(mapping.required_entities, fn entity ->
      !Map.has_key?(entities, entity)
    end)
    
    if Enum.empty?(missing_entities) do
      {:ok, build_command_structure(intent, mapping, entities, context)}
    else
      {:error, {:missing_entities, missing_entities}}
    end
  end
  
  defp build_command_structure(intent, mapping, entities, context) do
    # Build command args based on intent
    args = case intent do
      :get_status ->
        build_status_args(entities)
        
      :spawn_vsm ->
        ["spawn" | build_vsm_config_args(entities)]
        
      :list_vsms ->
        ["list"]
        
      :send_alert ->
        [entities.level, entities.message]
        
      :authorize ->
        [to_string(entities.chat_id)]
        
      _ ->
        []
    end
    
    %{
      command: mapping.command,
      args: args,
      handler: mapping.handler,
      intent: intent,
      entities: entities,
      context: context
    }
  end
  
  defp build_status_args(entities) do
    args = []
    
    args = if entities[:subsystem] do
      args ++ ["--subsystem", entities.subsystem]
    else
      args
    end
    
    if entities[:time_range] do
      args ++ ["--range", entities.time_range]
    else
      args
    end
  end
  
  defp build_vsm_config_args(entities) do
    config_parts = []
    
    config_parts = if entities[:type] do
      config_parts ++ ["type:#{entities.type}"]
    else
      config_parts
    end
    
    config_parts = if entities[:agent_count] do
      config_parts ++ ["agents:#{entities.agent_count}"]
    else
      config_parts
    end
    
    if Enum.empty?(config_parts) do
      []
    else
      [Enum.join(config_parts, " ")]
    end
  end
  
  defp get_intent_description(intent) do
    descriptions = %{
      get_status: "Check system health and status",
      spawn_vsm: "Create a new VSM instance",
      list_vsms: "List all active VSM instances",
      send_alert: "Send an alert message",
      help: "Get help and command information",
      authorize: "Authorize a user or chat",
      get_metrics: "View system metrics",
      explain_vsm: "Get explanations about VSM concepts",
      control_system: "Control system operations",
      query_data: "Query system data",
      configure: "Configure system settings"
    }
    
    Map.get(descriptions, intent, "Perform #{intent} operation")
  end
  
  defp get_command_example(intent) do
    examples = %{
      get_status: "/status",
      spawn_vsm: "/vsm spawn type:recursive agents:5",
      list_vsms: "/vsm list",
      send_alert: "/alert critical Database connection lost",
      help: "/help",
      authorize: "/authorize 123456789",
      get_metrics: "/metrics --component s1 --range 1h"
    }
    
    Map.get(examples, intent, "")
  end
  
  defp add_contextual_suggestions(suggestions, context) do
    # Add frequently used commands
    freq_commands = context[:user_preferences][:frequently_used_commands] || []
    
    frequent_suggestions = freq_commands
    |> Enum.take(3)
    |> Enum.map(fn intent ->
      case Map.get(@intent_command_mappings, intent) do
        nil -> nil
        mapping ->
          %{
            command: mapping.command,
            intent: intent,
            description: "Frequently used: #{get_intent_description(intent)}",
            example: get_command_example(intent)
          }
      end
    end)
    |> Enum.filter(& &1)
    
    (frequent_suggestions ++ suggestions)
    |> Enum.uniq_by(& &1.intent)
    |> Enum.take(5)
  end
  
  defp parse_boolean(input) do
    String.downcase(input) in ["yes", "y"]
  end
  
  defp suggest_similar_commands(message, _context) do
    # Simple similarity check - in production, use proper string distance algorithms
    normalized = String.downcase(message)
    
    suggestions = @intent_command_mappings
    |> Enum.filter(fn {_intent, mapping} -> mapping.command != nil end)
    |> Enum.map(fn {intent, mapping} ->
      similarity = calculate_similarity(normalized, String.downcase(mapping.command))
      {intent, mapping.command, similarity}
    end)
    |> Enum.filter(fn {_intent, _cmd, sim} -> sim > 0.3 end)
    |> Enum.sort_by(fn {_intent, _cmd, sim} -> -sim end)
    |> Enum.take(3)
    |> Enum.map(fn {intent, cmd, _sim} ->
      %{
        command: cmd,
        description: get_intent_description(intent)
      }
    end)
    
    {:suggestions, suggestions}
  end
  
  defp calculate_similarity(str1, str2) do
    # Simple character overlap similarity
    chars1 = String.graphemes(str1) |> MapSet.new()
    chars2 = String.graphemes(str2) |> MapSet.new()
    
    intersection = MapSet.intersection(chars1, chars2) |> MapSet.size()
    union = MapSet.union(chars1, chars2) |> MapSet.size()
    
    if union == 0, do: 0.0, else: intersection / union
  end
  
  # Response Formatting Functions
  
  defp format_status_response(%{status: status_data}) do
    """
    Based on my analysis, here's the current system status:
    
    #{format_system_health(status_data)}
    
    Everything appears to be #{overall_health(status_data)}.
    """
  end
  
  defp format_system_health(status_data) do
    status_data
    |> Enum.map(fn {system, info} ->
      emoji = health_emoji(info.status)
      "#{emoji} **#{format_system_name(system)}**: #{info.status}"
    end)
    |> Enum.join("\n")
  end
  
  defp format_system_name(system) do
    case system do
      :s1 -> "System 1 (Operations)"
      :s2 -> "System 2 (Coordination)"
      :s3 -> "System 3 (Control)"
      :s4 -> "System 4 (Intelligence)"
      :s5 -> "System 5 (Policy)"
      other -> to_string(other)
    end
  end
  
  defp health_emoji("healthy"), do: "✅"
  defp health_emoji("warning"), do: "⚠️"
  defp health_emoji("error"), do: "❌"
  defp health_emoji(_), do: "❓"
  
  defp overall_health(status_data) do
    statuses = Enum.map(status_data, fn {_sys, info} -> info.status end)
    
    cond do
      Enum.any?(statuses, & &1 == "error") -> "experiencing some issues"
      Enum.any?(statuses, & &1 == "warning") -> "running with some warnings"
      true -> "running smoothly"
    end
  end
  
  defp format_vsm_spawn_response({:ok, vsm_id}, entities) do
    type = entities[:type] || "standard"
    agents = entities[:agent_count] || "default"
    
    """
    Great! I've successfully created a new #{type} VSM instance.
    
    🚀 **VSM ID**: `#{vsm_id}`
    📋 **Type**: #{String.capitalize(type)}
    🤖 **Agents**: #{agents}
    
    The system is now initializing. You can check its status with "show me the status of #{vsm_id}".
    """
  end
  
  defp format_vsm_spawn_response({:error, reason}, _entities) do
    """
    I couldn't create the VSM instance. Error: #{inspect(reason)}
    
    Would you like me to try with different parameters?
    """
  end
  
  defp format_vsm_list_response(vsms) when is_list(vsms) do
    if Enum.empty?(vsms) do
      """
      There are currently no active VSM instances.
      
      Would you like me to create one for you?
      """
    else
      """
      Here are the active VSM instances:
      
      #{format_vsm_list_items(vsms)}
      
      You can interact with any of these by mentioning their ID.
      """
    end
  end
  
  defp format_vsm_list_items(vsms) do
    vsms
    |> Enum.map(fn vsm ->
      "• **#{vsm.id}** (#{vsm.type}) - Status: #{vsm.status}"
    end)
    |> Enum.join("\n")
  end
  
  defp format_alert_response({:ok, _}, entities) do
    """
    ✅ I've sent out a #{entities.level} alert with your message.
    
    The alert has been distributed to all relevant channels.
    """
  end
  
  defp format_alert_response({:error, reason}, _entities) do
    """
    I couldn't send the alert. Error: #{inspect(reason)}
    
    Please check the alert configuration and try again.
    """
  end
  
  defp format_explanation_response(explanation, entities) do
    topic = entities[:topic] || "general"
    
    """
    #{get_topic_emoji(topic)} **Understanding #{format_topic_name(topic)}**
    
    #{explanation}
    
    Would you like to know more about any specific aspect?
    """
  end
  
  defp get_topic_emoji("vsm"), do: "🏗️"
  defp get_topic_emoji("system1"), do: "⚙️"
  defp get_topic_emoji("system2"), do: "🔄"
  defp get_topic_emoji("system3"), do: "📊"
  defp get_topic_emoji("system4"), do: "🔍"
  defp get_topic_emoji("system5"), do: "🎯"
  defp get_topic_emoji("cybernetics"), do: "🤖"
  defp get_topic_emoji(_), do: "📚"
  
  defp format_topic_name(topic) do
    case topic do
      "vsm" -> "VSM (Viable System Model)"
      "system1" -> "System 1 - Operations"
      "system2" -> "System 2 - Coordination"
      "system3" -> "System 3 - Control"
      "system4" -> "System 4 - Intelligence"
      "system5" -> "System 5 - Policy"
      "cybernetics" -> "Cybernetics"
      "recursion" -> "VSM Recursion"
      _ -> String.capitalize(topic)
    end
  end
  
  defp format_generic_response({:ok, data}) do
    """
    ✅ Operation completed successfully.
    
    #{inspect(data, pretty: true)}
    """
  end
  
  defp format_generic_response({:error, reason}) do
    """
    ❌ Operation failed: #{inspect(reason)}
    
    Please try again or ask for help if you need assistance.
    """
  end
  
  defp build_intent_help(intent, mapping) do
    """
    **#{String.capitalize(to_string(intent))}**
    
    #{get_intent_description(intent)}
    
    #{if mapping.command do
      "Command: `#{mapping.command}`\n"
    else
      "This is handled through natural language.\n"
    end}
    
    #{if not Enum.empty?(mapping.required_entities) do
      "Required information: #{Enum.join(mapping.required_entities, ", ")}\n"
    else
      ""
    end}
    
    #{if not Enum.empty?(mapping.optional_entities) do
      "Optional information: #{Enum.join(mapping.optional_entities, ", ")}\n"
    else
      ""
    end}
    
    Example: #{get_command_example(intent)}
    """
  end
end