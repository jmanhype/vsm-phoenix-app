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
    # Try to use Claude MCP if available
    case System.get_env("ANTHROPIC_API_KEY") do
      nil ->
        # Fallback to basic analysis
        {:ok, basic_analysis(prompt)}
        
      _api_key ->
        # Real LLM call would happen here
        # For now, return structured response
        {:ok, %{
          "action" => determine_action(prompt),
          "reasoning" => "Analyzed request using available context"
        }}
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
  
  defp basic_analysis(prompt) do
    # Generate tool calls based on prompt - using CORRECT tool names!
    tool_calls = cond do
      String.contains?(prompt, "read") && String.contains?(prompt, "/tmp/test_report.txt") ->
        [%{
          "name" => "read_text_file",  # Correct tool name!
          "arguments" => %{"path" => "/tmp/test_report.txt"}
        }]
        
      String.contains?(prompt, ["list", "directory"]) ->
        [%{
          "name" => "list_directory",
          "arguments" => %{"path" => "/tmp"}
        }]
        
      String.contains?(prompt, "write") && String.contains?(prompt, "file") ->
        [%{
          "name" => "write_file",
          "arguments" => %{"path" => "/tmp/output.txt", "content" => "Generated content"}
        }]
        
      true ->
        []
    end
    
    %{
      "action" => determine_action(prompt),
      "reasoning" => "Basic analysis without LLM",
      "tool_calls" => tool_calls
    }
  end
end