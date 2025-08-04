defmodule VsmPhoenix.LLM.Client do
  @moduledoc """
  Unified LLM client supporting multiple providers:
  - OpenAI GPT-4 integration
  - Anthropic Claude integration
  - Configurable API keys and error handling
  - Rate limiting and retries
  """

  require Logger
  use GenServer

  @openai_base_url "https://api.openai.com/v1"
  @anthropic_base_url "https://api.anthropic.com/v1"
  
  # Rate limiting: max 50 requests per minute per provider
  @rate_limit_window 60_000
  @max_requests_per_window 50
  
  # Retry configuration
  @max_retries 3
  @retry_delay 1000

  defstruct [
    :openai_key,
    :anthropic_key,
    :rate_limiter,
    :request_history
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      openai_key: get_openai_key(),
      anthropic_key: get_anthropic_key(),
      rate_limiter: %{
        openai: %{requests: [], window_start: System.monotonic_time(:millisecond)},
        anthropic: %{requests: [], window_start: System.monotonic_time(:millisecond)}
      },
      request_history: []
    }
    
    Logger.info("🤖 LLM Client initialized with available providers: #{available_providers(state)}")
    
    {:ok, state}
  end

  # Public API

  def complete(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:complete, prompt, opts}, 30_000)
  end

  def stream_complete(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:stream_complete, prompt, opts}, 30_000)
  end

  def analyze_variety(context, opts \\ []) do
    prompt = build_variety_analysis_prompt(context)
    complete(prompt, Keyword.put(opts, :provider, :claude))
  end

  def generate_patterns(data, opts \\ []) do
    prompt = build_pattern_generation_prompt(data)
    complete(prompt, Keyword.put(opts, :provider, :gpt4))
  end

  def synthesize_policy(requirements, context, opts \\ []) do
    prompt = build_policy_synthesis_prompt(requirements, context)
    complete(prompt, Keyword.put(opts, :provider, :claude))
  end

  def scan_environment(environmental_data, opts \\ []) do
    prompt = build_environmental_scan_prompt(environmental_data)
    complete(prompt, Keyword.put(opts, :provider, :gpt4))
  end

  # GenServer callbacks

  @impl true
  def handle_call({:complete, prompt, opts}, _from, state) do
    provider = Keyword.get(opts, :provider, :auto)
    model = Keyword.get(opts, :model)
    max_tokens = Keyword.get(opts, :max_tokens, 2048)
    temperature = Keyword.get(opts, :temperature, 0.7)
    
    case select_provider(provider, state) do
      {:ok, selected_provider} ->
        case check_rate_limit(selected_provider, state) do
          {:ok, new_state} ->
            result = execute_completion(
              selected_provider,
              prompt,
              model,
              max_tokens,
              temperature,
              new_state
            )
            
            updated_state = record_request(selected_provider, new_state)
            {:reply, result, updated_state}
            
          {:error, :rate_limited} ->
            {:reply, {:error, :rate_limited}, state}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:stream_complete, prompt, opts}, from, state) do
    # For streaming, we'll implement a simple async pattern
    Task.start(fn ->
      result = handle_call({:complete, prompt, opts}, from, state)
      GenServer.reply(from, result)
    end)
    
    {:noreply, state}
  end

  # Private functions

  defp get_openai_key do
    case System.get_env("OPENAI_API_KEY") do
      nil -> 
        Logger.warn("⚠️  OPENAI_API_KEY not found in environment")
        nil
      key when byte_size(key) > 0 -> key
      _ -> nil
    end
  end

  defp get_anthropic_key do
    case System.get_env("ANTHROPIC_API_KEY") do
      nil -> 
        Logger.warn("⚠️  ANTHROPIC_API_KEY not found in environment")
        nil
      key when byte_size(key) > 0 -> key
      _ -> nil
    end
  end

  defp available_providers(state) do
    providers = []
    providers = if state.openai_key, do: ["OpenAI" | providers], else: providers
    providers = if state.anthropic_key, do: ["Anthropic" | providers], else: providers
    
    case providers do
      [] -> "none"
      list -> Enum.join(list, ", ")
    end
  end

  defp select_provider(:auto, state) do
    cond do
      state.anthropic_key -> {:ok, :anthropic}
      state.openai_key -> {:ok, :openai}
      true -> {:error, :no_providers_available}
    end
  end

  defp select_provider(:claude, state) when not is_nil(state.anthropic_key) do
    {:ok, :anthropic}
  end

  defp select_provider(:gpt4, state) when not is_nil(state.openai_key) do
    {:ok, :openai}
  end

  defp select_provider(:openai, state) when not is_nil(state.openai_key) do
    {:ok, :openai}
  end

  defp select_provider(:anthropic, state) when not is_nil(state.anthropic_key) do
    {:ok, :anthropic}
  end

  defp select_provider(provider, _state) do
    {:error, "Provider #{provider} not available or not configured"}
  end

  defp check_rate_limit(provider, state) do
    now = System.monotonic_time(:millisecond)
    provider_limits = Map.get(state.rate_limiter, provider)
    
    # Clean old requests outside the window
    window_start = now - @rate_limit_window
    recent_requests = Enum.filter(provider_limits.requests, &(&1 > window_start))
    
    if length(recent_requests) >= @max_requests_per_window do
      Logger.warn("⚠️  Rate limit exceeded for #{provider}")
      {:error, :rate_limited}
    else
      new_rate_limiter = Map.put(
        state.rate_limiter,
        provider,
        %{requests: recent_requests, window_start: window_start}
      )
      
      {:ok, %{state | rate_limiter: new_rate_limiter}}
    end
  end

  defp execute_completion(provider, prompt, model, max_tokens, temperature, state) do
    case provider do
      :openai ->
        execute_openai_completion(prompt, model, max_tokens, temperature, state)
      :anthropic ->
        execute_anthropic_completion(prompt, model, max_tokens, temperature, state)
    end
  end

  defp execute_openai_completion(prompt, model, max_tokens, temperature, state) do
    model = model || "gpt-4-turbo-preview"
    
    headers = [
      {"Authorization", "Bearer #{state.openai_key}"},
      {"Content-Type", "application/json"}
    ]
    
    body = %{
      model: model,
      messages: [
        %{role: "user", content: prompt}
      ],
      max_tokens: max_tokens,
      temperature: temperature
    }
    
    url = "#{@openai_base_url}/chat/completions"
    
    case make_request_with_retry(url, headers, body, 0) do
      {:ok, response} ->
        case Jason.decode(response.body) do
          {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
            Logger.info("✅ OpenAI completion successful (#{String.length(content)} chars)")
            {:ok, %{
              content: content,
              provider: :openai,
              model: model,
              usage: Map.get(response, "usage", %{})
            }}
            
          {:ok, %{"error" => error}} ->
            Logger.error("❌ OpenAI API error: #{inspect(error)}")
            {:error, error}
            
          {:error, decode_error} ->
            Logger.error("❌ Failed to decode OpenAI response: #{inspect(decode_error)}")
            {:error, :decode_error}
        end
        
      {:error, reason} ->
        Logger.error("❌ OpenAI request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_anthropic_completion(prompt, model, max_tokens, temperature, state) do
    model = model || "claude-3-opus-20240229"
    
    headers = [
      {"x-api-key", state.anthropic_key},
      {"anthropic-version", "2023-06-01"},
      {"content-type", "application/json"}
    ]
    
    body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: [
        %{role: "user", content: prompt}
      ]
    }
    
    url = "#{@anthropic_base_url}/messages"
    
    case make_request_with_retry(url, headers, body, 0) do
      {:ok, response} ->
        case Jason.decode(response.body) do
          {:ok, %{"content" => [%{"text" => content} | _]}} ->
            Logger.info("✅ Anthropic completion successful (#{String.length(content)} chars)")
            {:ok, %{
              content: content,
              provider: :anthropic,
              model: model,
              usage: Map.get(response, "usage", %{})
            }}
            
          {:ok, %{"error" => error}} ->
            Logger.error("❌ Anthropic API error: #{inspect(error)}")
            {:error, error}
            
          {:error, decode_error} ->
            Logger.error("❌ Failed to decode Anthropic response: #{inspect(decode_error)}")
            {:error, :decode_error}
        end
        
      {:error, reason} ->
        Logger.error("❌ Anthropic request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_request_with_retry(url, headers, body, retry_count) when retry_count < @max_retries do
    json_body = Jason.encode!(body)
    
    case HTTPoison.post(url, json_body, headers, timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200} = response} ->
        {:ok, response}
        
      {:ok, %HTTPoison.Response{status_code: status_code} = response} when status_code >= 500 ->
        Logger.warn("⚠️  Server error #{status_code}, retrying... (attempt #{retry_count + 1})")
        Process.sleep(@retry_delay * (retry_count + 1))
        make_request_with_retry(url, headers, body, retry_count + 1)
        
      {:ok, %HTTPoison.Response{} = response} ->
        {:ok, response}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.warn("⚠️  Request failed: #{reason}, retrying... (attempt #{retry_count + 1})")
        Process.sleep(@retry_delay * (retry_count + 1))
        make_request_with_retry(url, headers, body, retry_count + 1)
    end
  end

  defp make_request_with_retry(_url, _headers, _body, _retry_count) do
    {:error, :max_retries_exceeded}
  end

  defp record_request(provider, state) do
    now = System.monotonic_time(:millisecond)
    provider_limits = Map.get(state.rate_limiter, provider)
    
    new_requests = [now | provider_limits.requests]
    new_provider_limits = %{provider_limits | requests: new_requests}
    new_rate_limiter = Map.put(state.rate_limiter, provider, new_provider_limits)
    
    %{state | rate_limiter: new_rate_limiter}
  end

  # Specialized prompt builders

  defp build_variety_analysis_prompt(context) do
    """
    You are analyzing a Viable System Model (VSM) for variety and recursive potential.
    
    Current system context: #{inspect(context)}
    
    Please analyze and identify:
    
    1. **Novel Patterns**: What new behavioral, structural, or temporal patterns are emerging?
    2. **Emergent Properties**: What capabilities emerge from component interactions?
    3. **Recursive Opportunities**: Where could systems-within-systems be beneficial?
    4. **Variety Amplification**: How can we increase system variety to handle complexity?
    5. **Environmental Coupling**: What external connections could enhance adaptation?
    
    Focus on actionable insights that can guide system evolution and adaptation.
    
    Return your analysis in JSON format with these keys:
    - novel_patterns: object with behavioral, structural, temporal, emergent sub-categories
    - emergent_properties: object describing new capabilities
    - recursive_potential: array of opportunities
    - variety_amplification: object with recommendations
    - environmental_coupling: object with external connection opportunities
    """
  end

  defp build_pattern_generation_prompt(data) do
    """
    You are a pattern recognition expert analyzing system data for the Viable System Model.
    
    Data to analyze: #{inspect(data)}
    
    Generate insights about:
    
    1. **Behavioral Patterns**: How does the system behave under different conditions?
    2. **Performance Patterns**: What performance characteristics are emerging?
    3. **Communication Patterns**: How do system components communicate?
    4. **Adaptation Patterns**: How does the system learn and adapt?
    5. **Failure Patterns**: What failure modes and recovery patterns exist?
    
    Provide actionable pattern insights that can improve system design and operation.
    
    Return your analysis in JSON format with clear categories and specific recommendations.
    """
  end

  defp build_policy_synthesis_prompt(requirements, context) do
    """
    You are a policy synthesis expert for a Viable System Model (VSM).
    
    Requirements: #{inspect(requirements)}
    System Context: #{inspect(context)}
    
    Synthesize policies that:
    
    1. **Governance Policies**: How should the system govern itself?
    2. **Resource Allocation**: How should resources be distributed?
    3. **Performance Standards**: What performance standards should be maintained?
    4. **Adaptation Rules**: When and how should the system adapt?
    5. **Intervention Criteria**: When should higher-level systems intervene?
    
    Consider variety, recursion, and viability principles in your policy recommendations.
    
    Return policies in JSON format with clear implementation guidelines.
    """
  end

  defp build_environmental_scan_prompt(environmental_data) do
    """
    You are conducting an environmental scan for a Viable System Model (VSM).
    
    Environmental data: #{inspect(environmental_data)}
    
    Analyze:
    
    1. **Threats**: What environmental threats could affect system viability?
    2. **Opportunities**: What opportunities exist for system enhancement?
    3. **Trends**: What long-term trends should influence system design?
    4. **Uncertainties**: What uncertainties require system adaptation capabilities?
    5. **Variety Sources**: What external variety sources could benefit the system?
    
    Focus on actionable intelligence that can guide strategic system decisions.
    
    Return your scan in JSON format with prioritized recommendations.
    """
  end
end