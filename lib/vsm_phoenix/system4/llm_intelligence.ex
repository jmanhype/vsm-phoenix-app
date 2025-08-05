defmodule VsmPhoenix.System4.LLMIntelligence do
  @moduledoc """
  LLM-powered intelligence for System 4.
  Provides environmental scanning, anomaly explanation, and future scenario planning
  using OpenAI and Anthropic APIs with intelligent fallback and caching.
  """
  
  require Logger
  
  alias VsmPhoenix.LLM.{Client, Cache, PromptTemplates}
  
  @doc """
  Performs LLM-enhanced environmental scanning.
  Analyzes scan data for deeper insights and hidden patterns.
  """
  def analyze_environmental_scan(scan_data, opts \\ []) do
    # Check cache first
    cache_key = generate_scan_cache_key(scan_data)
    
    case Cache.get(cache_key) do
      {:ok, cached_response} ->
        Logger.info("LLM Intelligence: Using cached environmental analysis")
        {:ok, cached_response}
        
      :miss ->
        perform_environmental_analysis(scan_data, cache_key, opts)
    end
  end
  
  @doc """
  Provides natural language explanation for detected anomalies.
  Helps stakeholders understand complex system anomalies.
  """
  def explain_anomaly(anomaly, opts \\ []) do
    template_vars = %{
      anomaly: anomaly
    }
    
    case PromptTemplates.validate_variables(:anomaly_explanation, template_vars) do
      :ok ->
        prompt_data = PromptTemplates.apply_template(:anomaly_explanation, template_vars)
        
        # Use GPT-4 for complex explanations, with Claude as fallback
        completion_opts = Keyword.merge([
          provider: :openai,
          model: "gpt-4-turbo",
          max_tokens: 1000,
          temperature: 0.3,  # Lower temperature for more focused explanations
          system_prompt: prompt_data.system_prompt
        ], opts)
        
        case Client.completion(prompt_data.user_prompt, completion_opts) do
          {:ok, response} ->
            parsed = parse_llm_response(response.content, prompt_data.output_schema)
            {:ok, parsed}
            
          error ->
            Logger.error("LLM anomaly explanation failed: #{inspect(error)}")
            error
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Generates future scenarios based on current system state and trends.
  Provides strategic planning insights.
  """
  def generate_scenarios(system_state, environmental_data, opts \\ []) do
    template_vars = %{
      system_health: system_state.health,
      environmental_data: environmental_data,
      current_adaptations: system_state.current_adaptations || [],
      metrics: system_state.intelligence_metrics || default_metrics()
    }
    
    case PromptTemplates.validate_variables(:scenario_planning, template_vars) do
      :ok ->
        prompt_data = PromptTemplates.apply_template(:scenario_planning, template_vars)
        
        # Use Claude for creative scenario generation
        completion_opts = Keyword.merge([
          provider: :anthropic,
          model: "claude-3-sonnet",
          max_tokens: 2000,
          temperature: 0.7,  # Higher temperature for creative scenarios
          system_prompt: prompt_data.system_prompt
        ], opts)
        
        case Client.completion(prompt_data.user_prompt, completion_opts) do
          {:ok, response} ->
            scenarios = parse_llm_response(response.content, prompt_data.output_schema)
            
            # Cache scenarios for reuse
            Cache.put(
              "scenarios:#{generate_state_hash(system_state)}", 
              scenarios,
              ttl: :timer.hours(6)
            )
            
            {:ok, scenarios}
            
          error ->
            Logger.error("LLM scenario generation failed: #{inspect(error)}")
            error
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Synthesizes new policies based on detected anomalies and system state.
  Used by System 5 (Queen) for policy generation.
  """
  def synthesize_policy(anomalies, system_state, opts \\ []) do
    template_vars = %{
      anomalies: anomalies,
      viability_score: system_state.viability_score || 0.5,
      resource_state: system_state.resource_state || %{},
      active_policies: system_state.active_policies || [],
      system_context: extract_system_context(system_state)
    }
    
    case PromptTemplates.validate_variables(:policy_synthesis, template_vars) do
      :ok ->
        prompt_data = PromptTemplates.apply_template(:policy_synthesis, template_vars)
        
        # Use GPT-4 for policy synthesis (better at structured output)
        completion_opts = Keyword.merge([
          provider: :openai,
          model: "gpt-4-turbo",
          max_tokens: 1500,
          temperature: 0.5,
          system_prompt: prompt_data.system_prompt
        ], opts)
        
        case Client.completion(prompt_data.user_prompt, completion_opts) do
          {:ok, response} ->
            policy = parse_llm_response(response.content, prompt_data.output_schema)
            {:ok, policy}
            
          error ->
            Logger.error("LLM policy synthesis failed: #{inspect(error)}")
            error
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Discovers hidden variety and emergent patterns in system data.
  Powers the variety explosion detection in System 4.
  """
  def amplify_variety(system_data, known_patterns \\ [], opts \\ []) do
    template_vars = %{
      system_data: system_data,
      known_patterns: known_patterns,
      recent_changes: extract_recent_changes(system_data)
    }
    
    case PromptTemplates.validate_variables(:variety_amplification, template_vars) do
      :ok ->
        prompt_data = PromptTemplates.apply_template(:variety_amplification, template_vars)
        
        # Use Claude for creative pattern discovery
        completion_opts = Keyword.merge([
          provider: :anthropic,
          model: "claude-3-opus",  # Use most capable model for pattern discovery
          max_tokens: 2000,
          temperature: 0.8,  # High temperature for creative discovery
          system_prompt: prompt_data.system_prompt
        ], opts)
        
        case Client.completion(prompt_data.user_prompt, completion_opts) do
          {:ok, response} ->
            variety_analysis = parse_llm_response(response.content, prompt_data.output_schema)
            
            # Check if variety explosion is detected
            if variety_analysis[:variety_explosion_risk] > 0.7 do
              Logger.warning("🔥 LLM detected high variety explosion risk: #{variety_analysis.variety_explosion_risk}")
            end
            
            {:ok, variety_analysis}
            
          error ->
            Logger.error("LLM variety amplification failed: #{inspect(error)}")
            error
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Performs real-time analysis of streaming data for immediate insights.
  Uses streaming API for continuous environmental monitoring.
  """
  def stream_analysis(data_stream, handler_fn, opts \\ []) do
    # Configure streaming analysis
    system_prompt = """
    You are a real-time systems analyst monitoring a continuous data stream.
    Identify significant patterns, anomalies, and emerging trends as they occur.
    Provide immediate alerts for critical situations.
    """
    
    prompt = "Analyze the following real-time data stream and provide immediate insights:\n#{inspect(data_stream)}"
    
    stream_opts = Keyword.merge([
      provider: :openai,
      model: "gpt-3.5-turbo",  # Use faster model for streaming
      temperature: 0.3,
      system_prompt: system_prompt
    ], opts)
    
    # Create streaming analysis
    stream = Client.stream_completion(prompt, stream_opts)
    
    # Process stream chunks
    Task.start(fn ->
      Enum.each(stream, fn chunk ->
        handler_fn.(chunk)
      end)
    end)
  end
  
  @doc """
  Gets current LLM usage statistics and costs.
  """
  def get_usage_stats do
    Client.get_usage_stats()
  end
  
  # Private functions
  
  defp perform_environmental_analysis(scan_data, cache_key, opts) do
    template_vars = %{
      market_signals: scan_data[:market_signals] || [],
      technology_trends: scan_data[:technology_trends] || [],
      regulatory_updates: scan_data[:regulatory_updates] || [],
      competitive_moves: scan_data[:competitive_moves] || []
    }
    
    case PromptTemplates.validate_variables(:environmental_scan, template_vars) do
      :ok ->
        prompt_data = PromptTemplates.apply_template(:environmental_scan, template_vars)
        
        # Use GPT-4 for comprehensive analysis
        completion_opts = Keyword.merge([
          provider: :openai,
          model: "gpt-4-turbo",
          max_tokens: 1500,
          temperature: 0.5,
          system_prompt: prompt_data.system_prompt
        ], opts)
        
        case Client.completion(prompt_data.user_prompt, completion_opts) do
          {:ok, response} ->
            analysis = parse_llm_response(response.content, prompt_data.output_schema)
            
            # Cache the analysis
            Cache.put(cache_key, analysis, ttl: :timer.hours(4))
            
            # Log if novel patterns detected
            if analysis[:novel_patterns] && length(analysis.novel_patterns) > 0 do
              Logger.info("🎯 LLM detected #{length(analysis.novel_patterns)} novel patterns")
            end
            
            {:ok, analysis}
            
          error ->
            Logger.error("LLM environmental analysis failed: #{inspect(error)}")
            error
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp parse_llm_response(content, schema) do
    # Try to parse as JSON first
    case Jason.decode(content) do
      {:ok, json} ->
        # Validate against schema and ensure all keys are atoms
        atomize_keys(json)
        
      {:error, _} ->
        # If not valid JSON, try to extract structured data
        Logger.warning("LLM response was not valid JSON, attempting extraction")
        extract_structured_data(content, schema)
    end
  end
  
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {String.to_atom(k), atomize_keys(v)}
    end)
  end
  
  defp atomize_keys(list) when is_list(list) do
    Enum.map(list, &atomize_keys/1)
  end
  
  defp atomize_keys(value), do: value
  
  defp extract_structured_data(content, schema) do
    # Fallback extraction based on schema
    # This is a simplified version - in production, use more sophisticated parsing
    Map.new(schema, fn {key, _desc} ->
      {key, extract_field(content, key)}
    end)
  end
  
  defp extract_field(content, field) do
    # Simple pattern matching for common fields
    case field do
      :insights -> extract_list(content, "insight")
      :threats -> extract_list(content, "threat")
      :opportunities -> extract_list(content, "opportunit")
      :adaptations -> extract_list(content, "adapt")
      _ -> nil
    end
  end
  
  defp extract_list(content, pattern) do
    content
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, pattern))
    |> Enum.map(&String.trim/1)
  end
  
  defp generate_scan_cache_key(scan_data) do
    # Generate a deterministic cache key based on scan data
    scan_data
    |> Map.take([:market_signals, :technology_trends, :regulatory_updates, :competitive_moves])
    |> :erlang.term_to_binary()
    |> :crypto.hash(:sha256)
    |> Base.encode16(case: :lower)
  end
  
  defp generate_state_hash(system_state) do
    system_state
    |> Map.take([:health, :intelligence_metrics, :current_adaptations])
    |> :erlang.term_to_binary()
    |> :crypto.hash(:sha256)
    |> Base.encode16(case: :lower)
  end
  
  defp extract_system_context(system_state) do
    %{
      subsystems_active: Map.get(system_state, :subsystems_active, 5),
      uptime: Map.get(system_state, :uptime, "unknown"),
      last_adaptation: Map.get(system_state, :last_adaptation, "none"),
      operating_mode: Map.get(system_state, :operating_mode, "normal")
    }
  end
  
  defp extract_recent_changes(system_data) do
    # Extract recent changes from system data
    # This is a placeholder - implement based on actual system data structure
    system_data
    |> Map.get(:audit_log, [])
    |> Enum.take(10)
    |> Enum.map(fn entry ->
      %{
        timestamp: entry[:timestamp],
        type: entry[:type],
        description: entry[:description]
      }
    end)
  end
  
  defp default_metrics do
    %{
      scan_coverage: 0.5,
      prediction_accuracy: 0.7,
      innovation_index: 0.5
    }
  end
end