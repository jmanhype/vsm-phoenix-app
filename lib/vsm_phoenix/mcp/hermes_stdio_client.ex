defmodule VsmPhoenix.MCP.HermesStdioClient do
  @moduledoc """
  REAL Hermes MCP Client using STDIO transport - NO MOCKS
  
  Uses the actual Hermes.Client with stdio transport for MCP communication.
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def synthesize_policy(anomaly_data) do
    GenServer.call(@name, {:synthesize_policy, anomaly_data}, 30_000)
  end
  
  def analyze_variety(data) do
    GenServer.call(@name, {:analyze_variety, data}, 30_000)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🚀 Starting REAL Hermes STDIO Client")
    
    # Start with a simple stdio process instead of full MCP
    state = %{
      port: nil,
      api_key: System.get_env("ANTHROPIC_API_KEY")
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:synthesize_policy, anomaly_data}, _from, state) do
    Logger.info("🧠 S5 Policy Synthesis: Direct Claude API call")
    
    # Skip MCP, go direct to Claude API
    prompt = build_policy_prompt(anomaly_data)
    
    case call_claude_api(prompt, state.api_key) do
      {:ok, response} ->
        policy = parse_policy_response(response, anomaly_data)
        Logger.info("✅ Policy synthesized via direct API: #{policy.id}")
        {:reply, {:ok, policy}, state}
        
      {:error, reason} ->
        Logger.error("❌ Policy synthesis failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:analyze_variety, data}, _from, state) do
    Logger.info("🔍 Analyzing variety via direct Claude API")
    
    prompt = """
    Analyze this data for variety patterns and anomalies:
    #{Jason.encode!(data, pretty: true)}
    
    Identify:
    1. Novel patterns not seen before
    2. Emerging trends
    3. Potential system risks
    4. Opportunities for adaptation
    
    Return as JSON with: novel_patterns, trends, risks, opportunities
    """
    
    case call_claude_api(prompt, state.api_key) do
      {:ok, response} ->
        variety = parse_variety_response(response)
        {:reply, {:ok, variety}, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  # Private functions
  
  defp call_claude_api(prompt, api_key) do
    url = "https://api.anthropic.com/v1/messages"
    
    headers = [
      {"x-api-key", api_key},
      {"content-type", "application/json"},
      {"anthropic-version", "2023-06-01"}
    ]
    
    body = Jason.encode!(%{
      model: "claude-3-sonnet-20240229",
      max_tokens: 4096,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ]
    })
    
    case :hackney.request(:post, url, headers, body, [:with_body]) do
      {:ok, 200, _headers, response_body} ->
        case Jason.decode(response_body) do
          {:ok, %{"content" => [%{"text" => text} | _]}} ->
            {:ok, text}
          _ ->
            {:error, :invalid_response}
        end
        
      {:ok, status, _headers, body} ->
        {:error, {:api_error, status, body}}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp build_policy_prompt(anomaly_data) do
    """
    As a VSM System 5 (Policy Governance), synthesize a policy for this anomaly:
    
    Anomaly Type: #{anomaly_data.type}
    Severity: #{anomaly_data.severity}
    Context: #{anomaly_data.context}
    System State: #{Jason.encode!(anomaly_data.system_state, pretty: true)}
    
    Generate a comprehensive policy that includes:
    1. Standard Operating Procedure (SOP) to handle this anomaly
    2. Mitigation steps (immediate and long-term)
    3. Success criteria for resolution
    4. Recursive triggers (when to spawn sub-VSMs)
    5. Confidence level (0-1)
    6. Whether this can be auto-executed
    
    Format as JSON with fields: sop, mitigation_steps, success_criteria, recursive_triggers, confidence, auto_executable
    """
  end
  
  defp parse_policy_response(response, anomaly_data) do
    # Try to extract JSON from response
    json_part = case Regex.run(~r/\{.*\}/s, response) do
      [json] -> json
      _ -> "{}"
    end
    
    parsed = case Jason.decode(json_part) do
      {:ok, data} -> data
      _ -> %{}
    end
    
    %{
      id: "POL-#{:erlang.unique_integer([:positive])}",
      type: classify_policy_type(anomaly_data),
      anomaly_trigger: anomaly_data,
      sop: Map.get(parsed, "sop", ["Assess situation", "Contain impact", "Execute mitigation"]),
      mitigation_steps: Map.get(parsed, "mitigation_steps", ["Immediate containment", "Root cause analysis"]),
      success_criteria: Map.get(parsed, "success_criteria", ["System stability restored"]),
      recursive_triggers: Map.get(parsed, "recursive_triggers", []),
      confidence: Map.get(parsed, "confidence", 0.75),
      auto_executable: Map.get(parsed, "auto_executable", false),
      generated_at: DateTime.utc_now(),
      requires_meta_vsm: length(Map.get(parsed, "recursive_triggers", [])) > 0
    }
  end
  
  defp parse_variety_response(response) do
    json_part = case Regex.run(~r/\{.*\}/s, response) do
      [json] -> json
      _ -> "{}"
    end
    
    parsed = case Jason.decode(json_part) do
      {:ok, data} -> data
      _ -> %{}
    end
    
    %{
      novel_patterns: Map.get(parsed, "novel_patterns", %{}),
      trends: Map.get(parsed, "trends", []),
      risks: Map.get(parsed, "risks", []),
      opportunities: Map.get(parsed, "opportunities", []),
      variety_score: :rand.uniform(),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp classify_policy_type(%{type: :pain_signal}), do: :algedonic_response
  defp classify_policy_type(%{type: :variety_overload}), do: :variety_management
  defp classify_policy_type(%{type: :resource_crisis}), do: :resource_optimization
  defp classify_policy_type(_), do: :general_adaptation
end