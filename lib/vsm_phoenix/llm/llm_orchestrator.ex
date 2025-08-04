defmodule VsmPhoenix.LLM.LLMOrchestrator do
  @moduledoc """
  LLM Orchestrator that intelligently routes requests between OpenAI and Anthropic
  based on task requirements, availability, and cost optimization.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.LLM.{OpenAIClient, AnthropicClient, TokenTracker, ResponseCache}
  
  @provider_weights %{
    openai: 1.0,
    anthropic: 1.0
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def complete(prompt, opts \\ []) do
    GenServer.call(__MODULE__, {:complete, prompt, opts}, 60_000)
  end
  
  def analyze_variety(data, opts \\ []) do
    # Route to best provider for variety analysis
    provider = select_provider(:variety_analysis, opts)
    
    case provider do
      :openai -> OpenAIClient.analyze_variety(data, opts)
      :anthropic -> AnthropicClient.analyze_complexity(data, opts)
      :auto -> auto_route_variety_analysis(data, opts)
    end
  end
  
  def environmental_scan(scan_data, opts \\ []) do
    # OpenAI is typically better for real-time data analysis
    OpenAIClient.environmental_scan(scan_data, opts)
  end
  
  def synthesize_policy(anomaly_data, opts \\ []) do
    # Claude excels at policy reasoning
    case AnthropicClient.meta_system_reasoning(anomaly_data, opts) do
      {:ok, response} -> {:ok, response}
      {:error, _} -> OpenAIClient.synthesize_policy(anomaly_data, opts)
    end
  end
  
  def detect_emergence(patterns, opts \\ []) do
    # Use Claude for emergent pattern detection
    AnthropicClient.emergent_pattern_detection(patterns, opts)
  end
  
  def conversational_ai(message, context \\ %{}, opts \\ []) do
    # Route based on conversation complexity
    provider = if String.length(message) > 500 or map_size(context) > 10 do
      :anthropic
    else
      :openai
    end
    
    case provider do
      :openai -> OpenAIClient.parse_intent(message, opts)
      :anthropic -> AnthropicClient.conversational_ai(message, context, opts)
    end
  end
  
  def get_provider_stats do
    GenServer.call(__MODULE__, :get_provider_stats)
  end
  
  def set_provider_preference(provider, weight) do
    GenServer.cast(__MODULE__, {:set_preference, provider, weight})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🎭 LLM Orchestrator initialized")
    
    state = %{
      provider_weights: @provider_weights,
      request_counts: %{openai: 0, anthropic: 0},
      error_counts: %{openai: 0, anthropic: 0},
      response_times: %{openai: [], anthropic: []},
      cost_tracking: %{openai: 0.0, anthropic: 0.0}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:complete, prompt, opts}, _from, state) do
    provider = select_provider(:general, opts)
    start_time = System.monotonic_time(:millisecond)
    
    result = case provider do
      :openai -> 
        OpenAIClient.complete(prompt, opts)
      :anthropic -> 
        AnthropicClient.complete(prompt, opts)
      :auto ->
        auto_route_completion(prompt, opts)
    end
    
    end_time = System.monotonic_time(:millisecond)
    response_time = end_time - start_time
    
    # Update stats
    new_state = update_provider_stats(state, provider, result, response_time)
    
    {:reply, result, new_state}
  end
  
  @impl true
  def handle_call(:get_provider_stats, _from, state) do
    stats = %{
      weights: state.provider_weights,
      requests: state.request_counts,
      errors: state.error_counts,
      avg_response_times: calculate_avg_response_times(state.response_times),
      cost_estimates: state.cost_tracking,
      recommendations: generate_provider_recommendations(state)
    }
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_cast({:set_preference, provider, weight}, state) do
    new_weights = Map.put(state.provider_weights, provider, weight)
    Logger.info("🎭 Updated provider preference: #{provider} -> #{weight}")
    
    {:noreply, %{state | provider_weights: new_weights}}
  end
  
  # Private Functions
  
  defp select_provider(task_type, opts) do
    case Keyword.get(opts, :provider) do
      nil -> auto_select_provider(task_type)
      :auto -> auto_select_provider(task_type)
      provider -> provider
    end
  end
  
  defp auto_select_provider(task_type) do
    case task_type do
      :variety_analysis -> :anthropic  # Claude better for complex analysis
      :environmental_scan -> :openai   # GPT-4 good for real-time data
      :policy_synthesis -> :anthropic  # Claude excels at reasoning
      :pattern_detection -> :anthropic # Claude's strength
      :intent_parsing -> :openai       # Fast and accurate
      :conversation -> :anthropic      # More natural conversation
      :general -> :openai              # Default to OpenAI
      _ -> :openai
    end
  end
  
  defp auto_route_variety_analysis(data, opts) do
    # Try Anthropic first for complex analysis, fallback to OpenAI
    case AnthropicClient.analyze_complexity(data, opts) do
      {:ok, response} -> 
        {:ok, Map.put(response, :routed_provider, :anthropic)}
      {:error, _} ->
        case OpenAIClient.analyze_variety(data, opts) do
          {:ok, response} -> 
            {:ok, Map.put(response, :routed_provider, :openai)}
          error -> error
        end
    end
  end
  
  defp auto_route_completion(prompt, opts) do
    # Load balance based on current performance
    primary_provider = if :rand.uniform() < 0.7, do: :openai, else: :anthropic
    
    case route_to_provider(prompt, opts, primary_provider) do
      {:ok, response} -> 
        {:ok, Map.put(response, :routed_provider, primary_provider)}
      {:error, _} ->
        # Fallback to other provider
        fallback_provider = if primary_provider == :openai, do: :anthropic, else: :openai
        case route_to_provider(prompt, opts, fallback_provider) do
          {:ok, response} -> 
            {:ok, Map.put(response, :routed_provider, fallback_provider)}
          error -> error
        end
    end
  end
  
  defp route_to_provider(prompt, opts, :openai) do
    OpenAIClient.complete(prompt, opts)
  end
  
  defp route_to_provider(prompt, opts, :anthropic) do
    AnthropicClient.complete(prompt, opts)
  end
  
  defp update_provider_stats(state, provider, result, response_time) do
    # Update request count
    new_requests = Map.update(state.request_counts, provider, 1, &(&1 + 1))
    
    # Update response times
    current_times = Map.get(state.response_times, provider, [])
    new_times = [response_time | Enum.take(current_times, 19)]  # Keep last 20
    new_response_times = Map.put(state.response_times, provider, new_times)
    
    # Update error count and cost tracking
    {new_errors, new_costs} = case result do
      {:ok, response} ->
        # Success - update cost tracking
        cost_delta = estimate_cost(response, provider)
        current_cost = Map.get(state.cost_tracking, provider, 0.0)
        
        {state.error_counts, Map.put(state.cost_tracking, provider, current_cost + cost_delta)}
        
      {:error, _} ->
        # Error - increment error count
        new_error_count = Map.update(state.error_counts, provider, 1, &(&1 + 1))
        {new_error_count, state.cost_tracking}
    end
    
    %{state |
      request_counts: new_requests,
      response_times: new_response_times,
      error_counts: new_errors,
      cost_tracking: new_costs
    }
  end
  
  defp estimate_cost(response, provider) do
    tokens = case response.usage do
      %{"total_tokens" => total} -> total
      %{"input_tokens" => input, "output_tokens" => output} -> input + output
      _ -> 1000  # Default estimate
    end
    
    case provider do
      :openai -> (tokens / 1000) * 0.045    # ~$0.045 per 1K tokens
      :anthropic -> (tokens / 1_000_000) * 30.0  # ~$30 per 1M tokens
      _ -> 0.0
    end
  end
  
  defp calculate_avg_response_times(response_times) do
    Map.new(response_times, fn {provider, times} ->
      avg = if length(times) > 0 do
        Enum.sum(times) / length(times)
      else
        0.0
      end
      {provider, avg}
    end)
  end
  
  defp generate_provider_recommendations(state) do
    openai_error_rate = safe_divide(state.error_counts[:openai] || 0, state.request_counts[:openai] || 1)
    anthropic_error_rate = safe_divide(state.error_counts[:anthropic] || 0, state.request_counts[:anthropic] || 1)
    
    openai_avg_time = calculate_avg_response_times(state.response_times)[:openai] || 0
    anthropic_avg_time = calculate_avg_response_times(state.response_times)[:anthropic] || 0
    
    recommendations = []
    
    recommendations = if openai_error_rate > 0.1 do
      ["Consider reducing OpenAI usage due to high error rate (#{Float.round(openai_error_rate * 100, 1)}%)" | recommendations]
    else
      recommendations
    end
    
    recommendations = if anthropic_error_rate > 0.1 do
      ["Consider reducing Anthropic usage due to high error rate (#{Float.round(anthropic_error_rate * 100, 1)}%)" | recommendations]
    else
      recommendations
    end
    
    recommendations = if openai_avg_time > anthropic_avg_time + 1000 do
      ["OpenAI responses are significantly slower than Anthropic" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["Both providers performing well"]
    else
      recommendations
    end
  end
  
  defp safe_divide(_, 0), do: 0.0
  defp safe_divide(numerator, denominator), do: numerator / denominator
end