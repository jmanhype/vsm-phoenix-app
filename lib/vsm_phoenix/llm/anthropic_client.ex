defmodule VsmPhoenix.LLM.AnthropicClient do
  @moduledoc """
  Production-ready Anthropic Claude API Client with:
  - Real Claude API integration
  - Advanced reasoning capabilities
  - Error handling and retries
  - Token tracking and cost management
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.LLM.{TokenTracker, ResponseCache}
  
  @base_url "https://api.anthropic.com/v1"
  @default_model "claude-3-opus-20240229"
  @max_retries 3
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def complete(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:complete, prompt, opts}, 60_000)
  end
  
  def analyze_complexity(data, opts \\ []) do
    prompt = build_complexity_analysis_prompt(data)
    complete(prompt, Keyword.merge([temperature: 0.4, max_tokens: 2048], opts))
  end
  
  def emergent_pattern_detection(patterns, opts \\ []) do
    prompt = build_pattern_detection_prompt(patterns)
    complete(prompt, Keyword.merge([temperature: 0.5, max_tokens: 1500], opts))
  end
  
  def meta_system_reasoning(context, opts \\ []) do
    prompt = build_meta_reasoning_prompt(context)
    complete(prompt, Keyword.merge([temperature: 0.6, max_tokens: 2000], opts))
  end
  
  def conversational_ai(message, context \\ %{}, opts \\ []) do
    prompt = build_conversation_prompt(message, context)
    complete(prompt, Keyword.merge([temperature: 0.7, max_tokens: 1024], opts))
  end
  
  def get_usage_stats do
    GenServer.call(__MODULE__, :get_usage_stats)
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    api_key = get_api_key()
    
    if api_key do
      Logger.info("🧠 Anthropic Claude Client initialized")
      
      state = %{
        api_key: api_key,
        base_url: Application.get_env(:vsm_phoenix, :anthropic)[:base_url] || @base_url,
        default_model: Application.get_env(:vsm_phoenix, :anthropic)[:model] || @default_model,
        request_count: 0,
        total_tokens: 0
      }
      
      {:ok, state}
    else
      Logger.error("❌ Anthropic API key not found. Set ANTHROPIC_API_KEY environment variable.")
      {:stop, :no_api_key}
    end
  end
  
  @impl true
  def handle_call({:complete, prompt, opts}, _from, state) do
    case make_completion_request(prompt, opts, state) do
      {:ok, response} ->
        new_state = update_usage_stats(state, response)
        {:reply, {:ok, response}, new_state}
        
      {:error, reason} = error ->
        Logger.error("❌ Anthropic API call failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call(:get_usage_stats, _from, state) do
    stats = %{
      request_count: state.request_count,
      total_tokens: state.total_tokens,
      cost_estimate: calculate_cost_estimate(state.total_tokens)
    }
    
    {:reply, stats, state}
  end
  
  # Private Functions
  
  defp get_api_key do
    Application.get_env(:vsm_phoenix, :anthropic)[:api_key] ||
    System.get_env("ANTHROPIC_API_KEY")
  end
  
  defp make_completion_request(prompt, opts, state) do
    Retry.retry with: Retry.exponential(1000, 2) |> Retry.take(@max_retries) do
      perform_completion_request(prompt, opts, state)
    end
  end
  
  defp perform_completion_request(prompt, opts, state) do
    model = Keyword.get(opts, :model, state.default_model)
    max_tokens = Keyword.get(opts, :max_tokens, 1024)
    temperature = Keyword.get(opts, :temperature, 0.7)
    
    headers = [
      {"x-api-key", state.api_key},
      {"Content-Type", "application/json"},
      {"anthropic-version", "2023-06-01"},
      {"User-Agent", "VsmPhoenix/1.0"}
    ]
    
    body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: [
        %{
          role: "user",
          content: prompt
        }
      ],
      system: "You are Claude, integrated into a Viable System Model (VSM) cybernetic organization. You excel at complex reasoning, pattern recognition, and adaptive intelligence. Provide thoughtful, nuanced responses that support system viability and evolution."
    }
    
    case Req.post("#{state.base_url}/messages",
                  json: body,
                  headers: headers,
                  retry: false,
                  receive_timeout: 60_000) do
      {:ok, %{status: 200, body: response}} ->
        content = extract_content(response)
        usage = Map.get(response, "usage", %{})
        
        formatted_response = %{
          content: content,
          model: model,
          usage: usage,
          timestamp: DateTime.utc_now(),
          provider: :anthropic
        }
        
        Logger.info("✅ Claude completion successful (#{get_token_count(usage)} tokens)")
        {:ok, formatted_response}
        
      {:ok, %{status: status, body: body}} ->
        error_msg = get_in(body, ["error", "message"]) || "Unknown API error"
        Logger.error("❌ Anthropic API error #{status}: #{error_msg}")
        {:error, {:api_error, status, error_msg}}
        
      {:error, reason} ->
        Logger.error("❌ Anthropic request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end
  
  defp extract_content(response) do
    case get_in(response, ["content"]) do
      [%{"text" => text} | _] -> text
      %{"text" => text} -> text
      text when is_binary(text) -> text
      _ -> ""
    end
  end
  
  defp get_token_count(usage) do
    (Map.get(usage, "input_tokens", 0) + Map.get(usage, "output_tokens", 0))
  end
  
  defp update_usage_stats(state, response) do
    tokens = get_token_count(response.usage)
    
    %{state |
      request_count: state.request_count + 1,
      total_tokens: state.total_tokens + tokens
    }
  end
  
  defp calculate_cost_estimate(total_tokens) do
    # Claude pricing: ~$15 per 1M input tokens, $75 per 1M output tokens
    # Rough estimate: $30 per 1M tokens average
    (total_tokens / 1_000_000) * 30.0
  end
  
  # Specialized Prompt Builders
  
  defp build_complexity_analysis_prompt(data) do
    """
    Analyze this complex system data for emergent patterns and recursive structures:

    Data: #{inspect(data)}

    As Claude integrated into a VSM cybernetic system, identify:

    1. **Complexity Layers**: Map the hierarchical complexity levels
    2. **Emergent Properties**: Detect properties that emerge from interactions
    3. **Recursive Patterns**: Identify self-similar structures across scales
    4. **Meta-System Indicators**: Signs that a higher-order system is needed
    5. **Adaptation Strategies**: How the system should evolve

    Provide deep, nuanced analysis that captures system dynamics and evolutionary potential.
    """
  end
  
  defp build_pattern_detection_prompt(patterns) do
    """
    Detect emergent patterns in this variety data using advanced pattern recognition:

    Patterns: #{inspect(patterns)}

    Apply sophisticated analysis to identify:

    1. **Hidden Relationships**: Connections not immediately apparent
    2. **Temporal Dynamics**: How patterns evolve over time
    3. **Phase Transitions**: Critical points where system behavior changes
    4. **Attractor States**: Stable configurations the system tends toward
    5. **Intervention Points**: Where small changes could have large effects

    Use your advanced reasoning to reveal deeper systemic insights.
    """
  end
  
  defp build_meta_reasoning_prompt(context) do
    """
    Engage in meta-level reasoning about this VSM system context:

    Context: #{inspect(context)}

    Apply recursive thinking to analyze:

    1. **System-of-Systems**: How this system relates to larger contexts
    2. **Self-Reference**: How the system observes and modifies itself
    3. **Recursive Improvement**: Opportunities for self-enhancement
    4. **Meta-Policies**: Rules about making rules
    5. **Evolutionary Trajectory**: Long-term development pathways

    Provide sophisticated meta-analysis that supports recursive system evolution.
    """
  end
  
  defp build_conversation_prompt(message, context) do
    """
    Engage in natural conversation while maintaining VSM system awareness:

    User Message: "#{message}"
    Context: #{inspect(context)}

    Respond as Claude integrated into a VSM organization:
    - Be helpful and conversational
    - Reference VSM concepts when relevant
    - Provide actionable insights
    - Maintain system perspective
    - Support user goals within VSM framework

    Balance natural conversation with intelligent system integration.
    """
  end
end