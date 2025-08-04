defmodule VsmPhoenix.Mocks.LLMMock do
  @moduledoc """
  Mock implementation for LLM services during testing.
  """
  
  @behaviour VsmPhoenix.LLM.ClientBehaviour
  
  def chat_completion(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "mock-model")
    
    case get_mock_response(messages, model) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
  
  def stream_completion(messages, callback, opts \\ []) do
    response = get_mock_response(messages, Keyword.get(opts, :model, "mock-model"))
    
    case response do
      {:ok, %{content: content}} ->
        # Simulate streaming by sending chunks
        chunks = String.split(content, " ")
        
        Enum.each(chunks, fn chunk ->
          callback.({:chunk, chunk <> " "})
          Process.sleep(10)  # Small delay to simulate real streaming
        end)
        
        callback.({:done, %{usage: %{total_tokens: length(chunks)}}})
        :ok
      
      {:error, reason} ->
        callback.({:error, reason})
        {:error, reason}
    end
  end
  
  def embeddings(texts, opts \\ []) do
    model = Keyword.get(opts, :model, "mock-embedding-model")
    
    embeddings = Enum.map(texts, fn text ->
      # Generate deterministic mock embeddings based on text hash
      hash = :crypto.hash(:md5, text) |> Base.encode16()
      
      # Convert hash to normalized vector
      hash
      |> String.to_charlist()
      |> Enum.take(256)
      |> Enum.map(&(&1 / 255.0))
    end)
    
    {:ok, %{
      model: model,
      embeddings: embeddings,
      usage: %{total_tokens: length(texts) * 10}
    }}
  end
  
  def moderate_content(text, opts \\ []) do
    # Simple mock moderation based on keywords
    flagged_words = ["spam", "hate", "violence", "illegal"]
    
    flagged = Enum.any?(flagged_words, fn word ->
      String.contains?(String.downcase(text), word)
    end)
    
    {:ok, %{
      flagged: flagged,
      categories: if(flagged, do: ["inappropriate_content"], else: []),
      category_scores: %{
        inappropriate_content: if(flagged, do: 0.9, else: 0.1)
      }
    }}
  end
  
  defp get_mock_response(messages, model) do
    last_message = List.last(messages)
    user_content = get_content(last_message)
    
    cond do
      String.contains?(user_content, "error") ->
        {:error, "Mock error for testing"}
      
      String.contains?(user_content, "policy") ->
        {:ok, create_policy_response(model)}
      
      String.contains?(user_content, "variety") ->
        {:ok, create_variety_response(model)}
      
      String.contains?(user_content, "viability") ->
        {:ok, create_viability_response(model)}
      
      String.contains?(user_content, "chaos") ->
        {:ok, create_chaos_response(model)}
      
      String.contains?(user_content, "quantum") ->
        {:ok, create_quantum_response(model)}
      
      true ->
        {:ok, create_default_response(model, user_content)}
    end
  end
  
  defp get_content(%{content: content}), do: content
  defp get_content(%{"content" => content}), do: content
  defp get_content(_), do: ""
  
  defp create_policy_response(model) do
    %{
      model: model,
      content: "Mock VSM policy synthesis: Increase system resilience by 15% through adaptive resource allocation and enhanced monitoring protocols.",
      usage: %{
        prompt_tokens: 50,
        completion_tokens: 25,
        total_tokens: 75
      },
      finish_reason: "stop"
    }
  end
  
  defp create_variety_response(model) do
    %{
      model: model,
      content: "Detected variety level: HIGH. Environmental complexity increased by 23%. Recommend spawning meta-system for enhanced adaptation capacity.",
      usage: %{
        prompt_tokens: 40,
        completion_tokens: 30,
        total_tokens: 70
      },
      finish_reason: "stop"
    }
  end
  
  defp create_viability_response(model) do
    %{
      model: model,
      content: "System viability: 0.87. All subsystems operational. Minor performance optimization recommended for System 3 resource allocation.",
      usage: %{
        prompt_tokens: 35,
        completion_tokens: 28,
        total_tokens: 63
      },
      finish_reason: "stop"
    }
  end
  
  defp create_chaos_response(model) do
    %{
      model: model,
      content: "Chaos experiment impact: System resilience improved by 12%. Fault injection revealed latency bottleneck in database layer.",
      usage: %{
        prompt_tokens: 45,
        completion_tokens: 32,
        total_tokens: 77
      },
      finish_reason: "stop"
    }
  end
  
  defp create_quantum_response(model) do
    %{
      model: model,
      content: "Quantum state measured: Superposition collapsed to definite state. Entanglement maintained with 94% fidelity.",
      usage: %{
        prompt_tokens: 38,
        completion_tokens: 26,
        total_tokens: 64
      },
      finish_reason: "stop"
    }
  end
  
  defp create_default_response(model, user_content) do
    %{
      model: model,
      content: "Mock LLM response to: #{String.slice(user_content, 0, 50)}...",
      usage: %{
        prompt_tokens: String.length(user_content) |> div(4),
        completion_tokens: 20,
        total_tokens: String.length(user_content) |> div(4) |> Kernel.+(20)
      },
      finish_reason: "stop"
    }
  end
  
  # Test helper functions
  
  def set_response_mode(mode) do
    Process.put(:llm_mock_mode, mode)
  end
  
  def get_response_mode do
    Process.get(:llm_mock_mode, :normal)
  end
  
  def set_custom_response(response) do
    Process.put(:llm_mock_custom_response, response)
  end
  
  def clear_custom_response do
    Process.delete(:llm_mock_custom_response)
  end
  
  def simulate_latency(ms) do
    Process.put(:llm_mock_latency, ms)
  end
  
  def clear_latency do
    Process.delete(:llm_mock_latency)
  end
end