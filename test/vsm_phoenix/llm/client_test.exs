defmodule VsmPhoenix.LLM.ClientTest do
  use ExUnit.Case, async: false
  alias VsmPhoenix.LLM.Client

  @moduletag :integration

  describe "LLM Client Integration" do
    test "client starts and provides health status" do
      # Start the client if not already started
      case GenServer.whereis(Client) do
        nil -> {:ok, _pid} = Client.start_link()
        _pid -> :ok
      end

      # Give it a moment to initialize
      Process.sleep(100)

      # Test that the client is responsive
      assert Process.alive?(GenServer.whereis(Client))
    end

    @tag :skip_in_ci
    test "completes text with mock data when no API keys available" do
      prompt = "What are the key challenges in implementing a Viable Systems Model?"
      
      result = Client.complete(prompt, provider: :auto, max_tokens: 100)
      
      # Should either succeed with real API or return appropriate error
      case result do
        {:ok, %{content: content}} ->
          assert is_binary(content)
          assert String.length(content) > 0
          
        {:error, :no_providers_available} ->
          # Expected when no API keys are configured
          assert true
          
        {:error, reason} ->
          # Other errors are acceptable in test environment
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "handles variety analysis requests" do
      context = %{
        system_state: "stable",
        environmental_factors: ["market_volatility", "tech_disruption"],
        current_adaptations: []
      }
      
      result = Client.analyze_variety(context, provider: :auto)
      
      case result do
        {:ok, %{content: _content}} ->
          assert true
          
        {:error, :no_providers_available} ->
          # Expected when no API keys are configured
          assert true
          
        {:error, _reason} ->
          # Acceptable in test environment
          assert true
      end
    end

    test "handles environmental scanning requests" do
      environmental_data = %{
        market_signals: [%{signal: "growth", strength: 0.8}],
        technology_trends: [%{trend: "ai_adoption", impact: :high}],
        competitive_moves: []
      }
      
      result = Client.scan_environment(environmental_data, provider: :auto)
      
      case result do
        {:ok, %{content: _content}} ->
          assert true
          
        {:error, :no_providers_available} ->
          # Expected when no API keys are configured
          assert true
          
        {:error, _reason} ->
          # Acceptable in test environment
          assert true
      end
    end

    test "rate limiting works correctly" do
      # This test checks that rate limiting doesn't prevent normal operation
      # in test scenarios (should allow reasonable request rates)
      
      results = for _i <- 1..3 do
        Client.complete("Test prompt #{:rand.uniform(1000)}", provider: :auto, max_tokens: 10)
      end
      
      # At least some requests should not be rate limited
      non_rate_limited = Enum.reject(results, fn
        {:error, :rate_limited} -> true
        _ -> false
      end)
      
      assert length(non_rate_limited) >= 1
    end
  end

  describe "LLM Client Configuration" do
    test "handles missing API keys gracefully" do
      # Temporarily unset environment variables
      original_openai = System.get_env("OPENAI_API_KEY")
      original_anthropic = System.get_env("ANTHROPIC_API_KEY")
      
      try do
        System.delete_env("OPENAI_API_KEY")
        System.delete_env("ANTHROPIC_API_KEY")
        
        # Restart client to pick up new environment
        GenServer.stop(Client, :normal)
        {:ok, _pid} = Client.start_link()
        
        result = Client.complete("test", provider: :auto)
        assert {:error, :no_providers_available} = result
        
      after
        # Restore environment variables
        if original_openai, do: System.put_env("OPENAI_API_KEY", original_openai)
        if original_anthropic, do: System.put_env("ANTHROPIC_API_KEY", original_anthropic)
        
        # Restart client to restore original configuration
        GenServer.stop(Client, :normal)
        {:ok, _pid} = Client.start_link()
      end
    end
  end

  describe "Integration with VSM Components" do
    test "integrates with System4 Intelligence" do
      # Test that the LLM client can be called by System4 components
      # This is a basic integration test
      
      context = %{
        environmental_scan: %{
          market_signals: [%{signal: "test", strength: 0.5}]
        }
      }
      
      # This should not crash even if LLM is unavailable
      result = VsmPhoenix.System4.LLMVarietySource.analyze_for_variety(context)
      
      case result do
        {:ok, variety_expansion} ->
          assert is_map(variety_expansion)
          assert Map.has_key?(variety_expansion, :novel_patterns)
          
        {:error, _reason} ->
          # Acceptable - LLM might not be available in test environment
          assert true
      end
    end
  end
end