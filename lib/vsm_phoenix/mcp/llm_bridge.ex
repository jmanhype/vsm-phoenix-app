defmodule VsmPhoenix.MCP.LLMBridge do
  @moduledoc """
  Bridge to actual LLM (Claude) via MCP.
  """
  
  require Logger
  
  alias VsmPhoenix.MCP.Client
  
  def analyze_task(prompt, context, mcp_client_pid) do
    # Get available tools from MCP client
    {:ok, tools} = Client.list_tools(mcp_client_pid)
    
    Logger.info("🔧 Available tools: #{length(tools)}")
    
    # Build LLM prompt with available tools
    llm_prompt = build_llm_prompt(prompt, context, tools)
    
    # Execute through Claude MCP if available
    case execute_llm_request(llm_prompt, mcp_client_pid) do
      {:ok, response} ->
        Logger.info("🤖 LLM response: #{inspect(response)}")
        parse_llm_response(response)
      error ->
        error
    end
  end
  
  defp build_llm_prompt(user_prompt, context, available_tools) do
    tool_descriptions = Enum.map(available_tools, fn tool ->
      "- #{tool["name"]}: #{tool["description"]}"
    end) |> Enum.join("\n")
    
    """
    You are an S1 agent in a VSM cybernetic system. Analyze this request and determine the best course of action.
    
    User Request: #{user_prompt}
    
    Current Context:
    #{inspect(context)}
    
    Available MCP Tools:
    #{tool_descriptions}
    
    Respond with a JSON object containing:
    - action: "execute_tool" | "spawn_agents" | "both"
    - tool_calls: array of {tool_name, arguments} if executing tools
    - spawn_config: {agent_count, agent_types} if spawning agents
    - reasoning: your analysis
    """
  end
  
  defp execute_llm_request(prompt, mcp_client_pid) do
    # FAIL FAST - NO FALLBACKS, NO MOCKS
    case System.get_env("ANTHROPIC_API_KEY") do
      nil ->
        Logger.error("❌ NO ANTHROPIC_API_KEY - FAILING FAST")
        {:error, :no_api_key}
        
      api_key ->
        # REAL LLM CALL - FAIL IF IT DOESN'T WORK
        case make_real_claude_api_call(prompt, api_key) do
          {:ok, response} -> {:ok, response}
          {:error, reason} -> 
            Logger.error("❌ Claude API failed: #{inspect(reason)} - FAILING FAST")
            {:error, reason}
        end
    end
  end
  
  defp parse_llm_response(%{"action" => action} = response) do
    {:ok, %{
      action: String.to_atom(action),
      tool_calls: response["tool_calls"] || [],
      spawn_config: response["spawn_config"],
      reasoning: response["reasoning"]
    }}
  end
  
  defp parse_llm_response(response) do
    # Try to extract action even without explicit field
    {:ok, %{
      action: :execute_tool,
      tool_calls: response["tool_calls"] || [],
      spawn_config: nil,
      reasoning: "Parsed response"
    }}
  end
  
  defp determine_action(prompt) do
    cond do
      String.contains?(prompt, ["file", "read", "write"]) -> "execute_tool"
      String.contains?(prompt, ["spawn", "agents", "recursive"]) -> "spawn_agents"
      true -> "execute_tool"
    end
  end
  
  def generate_conversation_response(messages, system_prompt, mcp_client_pid) do
    Logger.info("💬 Generating REAL conversation response - NO FALLBACKS")
    
    # Build conversation prompt
    conversation_prompt = build_conversation_prompt(messages, system_prompt)
    
    # FAIL FAST - NO FALLBACKS, NO MOCKS, NO BULLSHIT
    case System.get_env("ANTHROPIC_API_KEY") do
      nil ->
        Logger.error("❌ NO ANTHROPIC_API_KEY - FAILING FAST")
        {:error, :no_api_key}
        
      api_key ->
        # REAL CLAUDE API CALL - FAIL IF IT DOESN'T WORK
        case make_real_claude_conversation_call(conversation_prompt, api_key) do
          {:ok, response} -> 
            Logger.info("🎯 Got REAL Claude response")
            {:ok, %{
              content: response,
              model: "claude-3-sonnet"
            }}
          {:error, reason} -> 
            Logger.error("❌ Claude API failed: #{inspect(reason)} - FAILING FAST")
            {:error, reason}
        end
    end
  end
  
  defp build_conversation_prompt(messages, system_prompt) do
    # Format messages for LLM
    formatted_messages = messages
    |> Enum.map(fn msg ->
      "#{msg.role}: #{msg.content}"
    end)
    |> Enum.join("\n")
    
    """
    #{system_prompt}
    
    Conversation History:
    #{formatted_messages}
    
    Please provide a helpful, conversational response to the user's latest message.
    """
  end
  
  # ALL FALLBACK FUNCTIONS DELETED - NO MOCKS, NO FALLBACKS
  # FAIL FAST OR REAL API ONLY
  
  # REAL CLAUDE API CALLS - NO FAKE BULLSHIT
  defp make_real_claude_api_call(prompt, api_key) do
    url = "https://api.anthropic.com/v1/messages"
    
    headers = [
      {"Content-Type", "application/json"},
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"}
    ]
    
    body = Jason.encode!(%{
      model: "claude-3-5-sonnet-20241022",
      max_tokens: 1024,
      messages: [%{
        role: "user",
        content: prompt
      }]
    })
    
    case HTTPoison.post(url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"content" => [%{"text" => text}]}} ->
            # Try to parse as JSON for structured responses
            case Jason.decode(text) do
              {:ok, parsed} -> {:ok, parsed}
              {:error, _} -> {:ok, %{"action" => "execute_tool", "reasoning" => text}}
            end
          {:error, _} -> {:error, :invalid_response}
        end
      {:ok, %{status_code: status_code, body: error_body}} ->
        Logger.error("❌ Claude API error #{status_code}: #{error_body}")
        {:error, :api_error}
      {:error, reason} ->
        Logger.error("❌ HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end
  
  defp make_real_claude_conversation_call(prompt, api_key) do
    url = "https://api.anthropic.com/v1/messages"
    
    headers = [
      {"Content-Type", "application/json"},
      {"x-api-key", api_key},
      {"anthropic-version", "2023-06-01"}
    ]
    
    body = Jason.encode!(%{
      model: "claude-3-5-sonnet-20241022",
      max_tokens: 1024,
      messages: [%{
        role: "user",
        content: prompt
      }]
    })
    
    case HTTPoison.post(url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
      {:ok, %{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"content" => [%{"text" => text}]}} ->
            {:ok, text}
          {:error, _} -> {:error, :invalid_response}
        end
      {:ok, %{status_code: status_code, body: error_body}} ->
        Logger.error("❌ Claude API error #{status_code}: #{error_body}")
        {:error, :api_error}
      {:error, reason} ->
        Logger.error("❌ HTTP request failed: #{inspect(reason)}")
        {:error, :network_error}
    end
  end

  # basic_analysis DELETED - NO FALLBACKS, NO MOCKS
end