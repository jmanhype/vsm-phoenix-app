defmodule VsmPhoenix.LLM.Client do
  @moduledoc """
  Unified LLM client abstraction for multiple providers.
  Supports OpenAI and Anthropic Claude with automatic fallback,
  rate limiting, retry logic, and cost optimization.
  """
  
  require Logger
  
  @openai_base_url "https://api.openai.com/v1"
  @anthropic_base_url "https://api.anthropic.com/v1"
  
  # Initialize ETS tables on module load
  def __init__ do
    :ets.new(:llm_rate_limits, [:set, :public, :named_table])
    :ets.new(:llm_usage, [:set, :public, :named_table])
  end
  
  # Rate limiting configuration
  @max_requests_per_minute 60
  @max_retries 3
  @base_delay 1000  # milliseconds
  
  # Cost tracking
  @token_costs %{
    # OpenAI pricing per 1K tokens
    "gpt-4" => %{input: 0.03, output: 0.06},
    "gpt-4-turbo" => %{input: 0.01, output: 0.03},
    "gpt-3.5-turbo" => %{input: 0.0005, output: 0.0015},
    # Anthropic pricing per 1K tokens
    "claude-3-opus" => %{input: 0.015, output: 0.075},
    "claude-3-sonnet" => %{input: 0.003, output: 0.015},
    "claude-3-haiku" => %{input: 0.0025, output: 0.0125},
    "claude-2.1" => %{input: 0.008, output: 0.024}
  }
  
  @doc """
  Sends a completion request to the specified LLM provider.
  
  Options:
    - provider: :openai or :anthropic (defaults to :openai)
    - model: specific model to use (defaults to provider's default)
    - max_tokens: maximum tokens in response
    - temperature: 0.0 to 1.0 (defaults to 0.7)
    - system_prompt: system message (for models that support it)
    - cache_key: optional key for response caching
    - fallback: whether to try other provider on failure (defaults to true)
  """
  def completion(prompt, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    
    with :ok <- check_rate_limit(provider),
         {:ok, response} <- try_completion(provider, prompt, opts),
         :ok <- track_usage(provider, response) do
      {:ok, response}
    else
      {:error, :rate_limited} ->
        Logger.warning("LLM rate limit reached for #{provider}")
        if Keyword.get(opts, :fallback, true) do
          fallback_provider = if provider == :openai, do: :anthropic, else: :openai
          completion(prompt, Keyword.put(opts, :provider, fallback_provider))
        else
          {:error, :rate_limited}
        end
        
      {:error, reason} = error ->
        Logger.error("LLM completion failed: #{inspect(reason)}")
        if Keyword.get(opts, :fallback, true) do
          fallback_provider = if provider == :openai, do: :anthropic, else: :openai
          completion(prompt, Keyword.put(opts, :provider, fallback_provider))
        else
          error
        end
    end
  end
  
  @doc """
  Sends a streaming completion request.
  Returns a stream of response chunks.
  """
  def stream_completion(prompt, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    
    Stream.resource(
      fn -> init_stream(provider, prompt, opts) end,
      fn state -> handle_stream_chunk(state) end,
      fn state -> cleanup_stream(state) end
    )
  end
  
  @doc """
  Analyzes text for embeddings using the specified provider.
  """
  def embeddings(text, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    model = Keyword.get(opts, :model, default_embedding_model(provider))
    
    with :ok <- check_rate_limit(provider),
         {:ok, response} <- try_embeddings(provider, text, model),
         :ok <- track_usage(provider, response) do
      {:ok, response}
    else
      error -> error
    end
  end
  
  @doc """
  Gets current usage statistics and costs.
  """
  def get_usage_stats do
    %{
      requests: get_request_counts(),
      tokens: get_token_usage(),
      costs: calculate_costs(),
      rate_limits: get_rate_limit_status()
    }
  end
  
  # Private functions
  
  defp try_completion(:openai, prompt, opts) do
    model = Keyword.get(opts, :model, "gpt-4-turbo")
    max_tokens = Keyword.get(opts, :max_tokens, 1000)
    temperature = Keyword.get(opts, :temperature, 0.7)
    system_prompt = Keyword.get(opts, :system_prompt)
    
    messages = build_messages(prompt, system_prompt)
    
    body = %{
      model: model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }
    
    headers = [
      {"Authorization", "Bearer #{openai_api_key()}"},
      {"Content-Type", "application/json"}
    ]
    
    retry_request(
      :post,
      "#{@openai_base_url}/chat/completions",
      Jason.encode!(body),
      headers,
      &parse_openai_response/1
    )
  end
  
  defp try_completion(:anthropic, prompt, opts) do
    model = Keyword.get(opts, :model, "claude-3-sonnet")
    max_tokens = Keyword.get(opts, :max_tokens, 1000)
    temperature = Keyword.get(opts, :temperature, 0.7)
    system_prompt = Keyword.get(opts, :system_prompt)
    
    body = %{
      model: model,
      messages: [%{role: "user", content: prompt}],
      max_tokens: max_tokens,
      temperature: temperature
    }
    
    body = if system_prompt, do: Map.put(body, :system, system_prompt), else: body
    
    headers = [
      {"x-api-key", anthropic_api_key()},
      {"anthropic-version", "2023-06-01"},
      {"Content-Type", "application/json"}
    ]
    
    retry_request(
      :post,
      "#{@anthropic_base_url}/messages",
      Jason.encode!(body),
      headers,
      &parse_anthropic_response/1
    )
  end
  
  defp try_embeddings(:openai, text, model) do
    body = %{
      model: model,
      input: text
    }
    
    headers = [
      {"Authorization", "Bearer #{openai_api_key()}"},
      {"Content-Type", "application/json"}
    ]
    
    retry_request(
      :post,
      "#{@openai_base_url}/embeddings",
      Jason.encode!(body),
      headers,
      &parse_openai_embeddings/1
    )
  end
  
  defp retry_request(method, url, body, headers, parser, attempt \\ 1) do
    case HTTPoison.request(method, url, body, headers) do
      {:ok, %{status_code: 200, body: resp_body}} ->
        parser.(resp_body)
        
      {:ok, %{status_code: 429}} when attempt < @max_retries ->
        delay = @base_delay * :math.pow(2, attempt - 1) |> round()
        Logger.info("Rate limited, retrying in #{delay}ms (attempt #{attempt}/#{@max_retries})")
        Process.sleep(delay)
        retry_request(method, url, body, headers, parser, attempt + 1)
        
      {:ok, %{status_code: status, body: error_body}} ->
        {:error, {:http_error, status, error_body}}
        
      {:error, reason} when attempt < @max_retries ->
        delay = @base_delay * :math.pow(2, attempt - 1) |> round()
        Logger.info("Request failed, retrying in #{delay}ms (attempt #{attempt}/#{@max_retries})")
        Process.sleep(delay)
        retry_request(method, url, body, headers, parser, attempt + 1)
        
      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
  end
  
  defp parse_openai_response(body) do
    case Jason.decode(body) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]} = response} ->
        {:ok, %{
          content: content,
          model: response["model"],
          usage: response["usage"],
          provider: :openai
        }}
        
      {:ok, data} ->
        {:error, {:invalid_response, data}}
        
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
  
  defp parse_anthropic_response(body) do
    case Jason.decode(body) do
      {:ok, %{"content" => [%{"text" => text} | _]} = response} ->
        {:ok, %{
          content: text,
          model: response["model"],
          usage: %{
            "prompt_tokens" => response["usage"]["input_tokens"],
            "completion_tokens" => response["usage"]["output_tokens"],
            "total_tokens" => response["usage"]["input_tokens"] + response["usage"]["output_tokens"]
          },
          provider: :anthropic
        }}
        
      {:ok, data} ->
        {:error, {:invalid_response, data}}
        
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
  
  defp parse_openai_embeddings(body) do
    case Jason.decode(body) do
      {:ok, %{"data" => [%{"embedding" => embedding} | _]} = response} ->
        {:ok, %{
          embedding: embedding,
          model: response["model"],
          usage: response["usage"],
          provider: :openai
        }}
        
      {:ok, data} ->
        {:error, {:invalid_response, data}}
        
      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end
  
  defp build_messages(prompt, nil) do
    [%{role: "user", content: prompt}]
  end
  
  defp build_messages(prompt, system_prompt) do
    [
      %{role: "system", content: system_prompt},
      %{role: "user", content: prompt}
    ]
  end
  
  defp check_rate_limit(provider) do
    key = "llm_rate_limit:#{provider}"
    current_minute = System.system_time(:second) |> div(60)
    
    case :ets.lookup(:llm_rate_limits, {key, current_minute}) do
      [{_, count}] when count >= @max_requests_per_minute ->
        {:error, :rate_limited}
        
      [{_, count}] ->
        :ets.update_counter(:llm_rate_limits, {key, current_minute}, 1)
        :ok
        
      [] ->
        :ets.insert(:llm_rate_limits, {{key, current_minute}, 1})
        # Clean up old entries
        cleanup_rate_limits()
        :ok
    end
  end
  
  defp track_usage(provider, response) do
    if response[:usage] do
      key = "llm_usage:#{provider}:#{Date.utc_today()}"
      
      :ets.update_counter(:llm_usage, {key, :requests}, 1, {{key, :requests}, 0})
      :ets.update_counter(:llm_usage, {key, :prompt_tokens}, 
        response.usage["prompt_tokens"] || 0, {{key, :prompt_tokens}, 0})
      :ets.update_counter(:llm_usage, {key, :completion_tokens}, 
        response.usage["completion_tokens"] || 0, {{key, :completion_tokens}, 0})
    end
    
    :ok
  end
  
  defp cleanup_rate_limits do
    current_minute = System.system_time(:second) |> div(60)
    cutoff = current_minute - 2  # Keep last 2 minutes
    
    :ets.select_delete(:llm_rate_limits, [
      {{{:_, :"$1"}, :_}, [{:<, :"$1", cutoff}], [true]}
    ])
  end
  
  defp get_request_counts do
    today = Date.utc_today()
    
    [:openai, :anthropic]
    |> Enum.map(fn provider ->
      key = "llm_usage:#{provider}:#{today}"
      requests = case :ets.lookup(:llm_usage, {key, :requests}) do
        [{_, count}] -> count
        [] -> 0
      end
      {provider, requests}
    end)
    |> Map.new()
  end
  
  defp get_token_usage do
    today = Date.utc_today()
    
    [:openai, :anthropic]
    |> Enum.map(fn provider ->
      key = "llm_usage:#{provider}:#{today}"
      
      prompt_tokens = case :ets.lookup(:llm_usage, {key, :prompt_tokens}) do
        [{_, count}] -> count
        [] -> 0
      end
      
      completion_tokens = case :ets.lookup(:llm_usage, {key, :completion_tokens}) do
        [{_, count}] -> count
        [] -> 0
      end
      
      {provider, %{
        prompt_tokens: prompt_tokens,
        completion_tokens: completion_tokens,
        total_tokens: prompt_tokens + completion_tokens
      }}
    end)
    |> Map.new()
  end
  
  defp calculate_costs do
    usage = get_token_usage()
    
    Enum.map(usage, fn {provider, tokens} ->
      # Estimate costs based on default models
      model = if provider == :openai, do: "gpt-4-turbo", else: "claude-3-sonnet"
      
      if costs = @token_costs[model] do
        input_cost = (tokens.prompt_tokens / 1000) * costs.input
        output_cost = (tokens.completion_tokens / 1000) * costs.output
        total_cost = input_cost + output_cost
        
        {provider, %{
          input_cost: Float.round(input_cost, 4),
          output_cost: Float.round(output_cost, 4),
          total_cost: Float.round(total_cost, 4)
        }}
      else
        {provider, %{input_cost: 0.0, output_cost: 0.0, total_cost: 0.0}}
      end
    end)
    |> Map.new()
  end
  
  defp get_rate_limit_status do
    current_minute = System.system_time(:second) |> div(60)
    
    [:openai, :anthropic]
    |> Enum.map(fn provider ->
      key = "llm_rate_limit:#{provider}"
      count = case :ets.lookup(:llm_rate_limits, {key, current_minute}) do
        [{_, c}] -> c
        [] -> 0
      end
      
      {provider, %{
        current_requests: count,
        max_requests: @max_requests_per_minute,
        remaining: @max_requests_per_minute - count
      }}
    end)
    |> Map.new()
  end
  
  defp default_embedding_model(:openai), do: "text-embedding-3-small"
  defp default_embedding_model(:anthropic), do: "claude-3-haiku"  # Anthropic doesn't have dedicated embedding models
  
  defp openai_api_key do
    System.get_env("OPENAI_API_KEY") || 
      Application.get_env(:vsm_phoenix, :openai_api_key) ||
      raise "OpenAI API key not configured"
  end
  
  defp anthropic_api_key do
    System.get_env("ANTHROPIC_API_KEY") || 
      Application.get_env(:vsm_phoenix, :anthropic_api_key) ||
      raise "Anthropic API key not configured"
  end
  
  # Streaming support
  
  defp init_stream(provider, prompt, opts) do
    # Initialize streaming state
    %{
      provider: provider,
      prompt: prompt,
      opts: opts,
      buffer: "",
      done: false
    }
  end
  
  defp handle_stream_chunk(%{done: true} = state) do
    {:halt, state}
  end
  
  defp handle_stream_chunk(state) do
    # This would implement actual streaming logic
    # For now, return a simple non-streaming response
    case try_completion(state.provider, state.prompt, state.opts) do
      {:ok, response} ->
        {[response.content], %{state | done: true}}
        
      {:error, _reason} ->
        {:halt, state}
    end
  end
  
  defp cleanup_stream(_state) do
    # Cleanup streaming resources
    :ok
  end
end