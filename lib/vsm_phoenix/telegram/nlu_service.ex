defmodule VsmPhoenix.Telegram.NLUService do
  @moduledoc """
  Natural Language Understanding Service for Telegram Bot.
  
  Provides LLM-based intent recognition, entity extraction, and confidence scoring
  for natural language messages received through Telegram.
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.LLM.Service, as: LLMService
  
  # Intent types recognized by the system
  @intents [
    :get_status,
    :spawn_vsm,
    :list_vsms,
    :send_alert,
    :help,
    :authorize,
    :get_metrics,
    :explain_vsm,
    :control_system,
    :query_data,
    :configure,
    :unknown
  ]
  
  # Client API
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Analyze a natural language message and extract intent and entities.
  
  Returns:
    {:ok, %{
      intent: atom(),
      confidence: float(),
      entities: map(),
      suggested_command: string() | nil
    }}
  """
  def analyze_message(text, context \\ %{}) do
    GenServer.call(__MODULE__, {:analyze_message, text, context}, 10_000)
  end
  
  @doc """
  Get confidence threshold for intent recognition.
  """
  def get_confidence_threshold do
    GenServer.call(__MODULE__, :get_confidence_threshold)
  end
  
  @doc """
  Update confidence threshold.
  """
  def set_confidence_threshold(threshold) when threshold >= 0.0 and threshold <= 1.0 do
    GenServer.call(__MODULE__, {:set_confidence_threshold, threshold})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      confidence_threshold: 0.7,
      llm_provider: :openai,  # Can be :openai, :anthropic, or :ollama
      model: "gpt-4",
      temperature: 0.3,
      intent_examples: load_intent_examples(),
      entity_patterns: compile_entity_patterns()
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:analyze_message, text, context}, _from, state) do
    result = perform_nlu_analysis(text, context, state)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call(:get_confidence_threshold, _from, state) do
    {:reply, state.confidence_threshold, state}
  end
  
  @impl true
  def handle_call({:set_confidence_threshold, threshold}, _from, state) do
    {:reply, :ok, %{state | confidence_threshold: threshold}}
  end
  
  # Private Functions
  
  defp perform_nlu_analysis(text, context, state) do
    # First try rule-based extraction for common patterns
    case try_rule_based_extraction(text, state) do
      {:ok, result} when result.confidence >= state.confidence_threshold ->
        {:ok, result}
        
      _ ->
        # Fall back to LLM-based analysis
        perform_llm_analysis(text, context, state)
    end
  end
  
  defp try_rule_based_extraction(text, state) do
    normalized_text = String.downcase(String.trim(text))
    
    # Check for direct command patterns
    cond do
      String.contains?(normalized_text, ["status", "health", "how are you", "how's the system"]) ->
        {:ok, %{
          intent: :get_status,
          confidence: 0.9,
          entities: extract_status_entities(text),
          suggested_command: "/status"
        }}
        
      String.contains?(normalized_text, ["spawn", "create", "new vsm", "start vsm"]) ->
        {:ok, %{
          intent: :spawn_vsm,
          confidence: 0.85,
          entities: extract_vsm_config(text),
          suggested_command: "/vsm spawn"
        }}
        
      String.contains?(normalized_text, ["list", "show", "all vsm", "vsm instances"]) ->
        {:ok, %{
          intent: :list_vsms,
          confidence: 0.9,
          entities: %{},
          suggested_command: "/vsm list"
        }}
        
      String.contains?(normalized_text, ["help", "what can you do", "commands", "how to"]) ->
        {:ok, %{
          intent: :help,
          confidence: 0.95,
          entities: %{},
          suggested_command: "/help"
        }}
        
      String.contains?(normalized_text, ["alert", "notify", "warning", "critical"]) ->
        extract_alert_intent(text)
        
      String.contains?(normalized_text, ["explain", "what is", "tell me about"]) ->
        {:ok, %{
          intent: :explain_vsm,
          confidence: 0.8,
          entities: extract_explanation_topic(text),
          suggested_command: nil
        }}
        
      true ->
        {:error, :no_match}
    end
  end
  
  defp perform_llm_analysis(text, context, state) do
    prompt = build_nlu_prompt(text, context, state)
    
    case LLMService.generate(prompt, %{
      temperature: state.temperature,
      provider: state.llm_provider,
      model: state.model,
      response_format: "json"
    }) do
      {:ok, response} ->
        parse_llm_response(response, state)
        
      {:error, reason} ->
        Logger.error("LLM analysis failed: #{inspect(reason)}")
        # Fallback to unknown intent
        {:ok, %{
          intent: :unknown,
          confidence: 0.0,
          entities: %{},
          suggested_command: nil
        }}
    end
  end
  
  defp build_nlu_prompt(text, context, state) do
    """
    You are an NLU system for a VSM (Viable System Model) monitoring bot. Analyze the following message and extract the intent and entities.
    
    Available intents:
    #{Enum.map_join(@intents, "\n", fn intent -> "- #{intent}" end)}
    
    Context:
    - Previous intent: #{context[:previous_intent] || "none"}
    - User role: #{context[:user_role] || "user"}
    - Active VSM: #{context[:active_vsm] || "none"}
    
    Examples:
    #{format_intent_examples(state.intent_examples)}
    
    Message: "#{text}"
    
    Respond in JSON format:
    {
      "intent": "intent_name",
      "confidence": 0.0-1.0,
      "entities": {
        "entity_name": "value"
      },
      "reasoning": "brief explanation",
      "suggested_command": "/command if applicable or null"
    }
    """
  end
  
  defp parse_llm_response(response, state) do
    case Jason.decode(response) do
      {:ok, data} ->
        intent = String.to_existing_atom(data["intent"])
        confidence = Float.parse(to_string(data["confidence"])) |> elem(0)
        
        result = %{
          intent: intent,
          confidence: confidence,
          entities: data["entities"] || %{},
          suggested_command: data["suggested_command"]
        }
        
        # Log low confidence results for improvement
        if confidence < state.confidence_threshold do
          Logger.info("Low confidence NLU result: #{inspect(result)}")
        end
        
        {:ok, result}
        
      {:error, _} ->
        Logger.error("Failed to parse LLM response: #{response}")
        {:ok, %{
          intent: :unknown,
          confidence: 0.0,
          entities: %{},
          suggested_command: nil
        }}
    end
  end
  
  # Entity Extraction Functions
  
  defp extract_status_entities(text) do
    entities = %{}
    
    # Check for specific subsystems
    entities = if String.contains?(text, ["s1", "system 1", "operations"]) do
      Map.put(entities, :subsystem, "s1")
    else
      entities
    end
    
    entities = if String.contains?(text, ["s2", "system 2", "coordination"]) do
      Map.put(entities, :subsystem, "s2")
    else
      entities
    end
    
    # Check for time range
    entities = if String.contains?(text, ["last hour", "past hour"]) do
      Map.put(entities, :time_range, "1h")
    else
      entities
    end
    
    entities
  end
  
  defp extract_vsm_config(text) do
    entities = %{}
    
    # Extract VSM type
    entities = cond do
      String.contains?(text, "recursive") ->
        Map.put(entities, :type, "recursive")
      String.contains?(text, "federated") ->
        Map.put(entities, :type, "federated")
      String.contains?(text, "standard") ->
        Map.put(entities, :type, "standard")
      true ->
        entities
    end
    
    # Extract agent count
    case Regex.run(~r/(\d+)\s*agents?/i, text) do
      [_, count] ->
        Map.put(entities, :agent_count, String.to_integer(count))
      _ ->
        entities
    end
  end
  
  defp extract_alert_intent(text) do
    level = cond do
      String.contains?(text, "critical") -> "critical"
      String.contains?(text, "warning") -> "warning"
      true -> "info"
    end
    
    # Extract the alert message
    message = text
    |> String.replace(~r/(send\s+)?(an?\s+)?alert/i, "")
    |> String.replace(~r/^(critical|warning|info)\s+/i, "")
    |> String.trim()
    
    {:ok, %{
      intent: :send_alert,
      confidence: 0.85,
      entities: %{
        level: level,
        message: message
      },
      suggested_command: "/alert #{level} #{message}"
    }}
  end
  
  defp extract_explanation_topic(text) do
    topic = cond do
      String.contains?(text, ["vsm", "viable system"]) -> "vsm"
      String.contains?(text, ["s1", "system 1"]) -> "system1"
      String.contains?(text, ["s2", "system 2"]) -> "system2"
      String.contains?(text, ["s3", "system 3"]) -> "system3"
      String.contains?(text, ["s4", "system 4"]) -> "system4"
      String.contains?(text, ["s5", "system 5"]) -> "system5"
      String.contains?(text, ["recursion", "recursive"]) -> "recursion"
      String.contains?(text, ["cybernetics"]) -> "cybernetics"
      true -> "general"
    end
    
    %{topic: topic}
  end
  
  defp compile_entity_patterns do
    %{
      time_ranges: ~r/(last|past)\s+(\d+)\s+(hour|day|week|month)s?/i,
      numbers: ~r/\b\d+\b/,
      vsm_ids: ~r/vsm[-_]?\w+/i,
      levels: ~r/\b(critical|warning|info|error)\b/i
    }
  end
  
  defp load_intent_examples do
    %{
      get_status: [
        "What's the system status?",
        "How is the VSM doing?",
        "Show me the health of S1"
      ],
      spawn_vsm: [
        "Create a new VSM with 5 agents",
        "Spawn a recursive VSM",
        "Start a new system"
      ],
      list_vsms: [
        "Show all VSMs",
        "List active instances",
        "What VSMs are running?"
      ],
      send_alert: [
        "Send a critical alert about database issues",
        "Alert warning low memory",
        "Notify team about deployment"
      ],
      explain_vsm: [
        "What is System 2?",
        "Explain VSM recursion",
        "Tell me about cybernetics"
      ]
    }
  end
  
  defp format_intent_examples(examples) do
    examples
    |> Enum.map(fn {intent, msgs} ->
      sample = Enum.take(msgs, 2) |> Enum.join(", ")
      "#{intent}: #{sample}"
    end)
    |> Enum.join("\n")
  end
end