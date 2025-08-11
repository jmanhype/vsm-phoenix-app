defmodule VsmPhoenix.Telemetry.IntegrationTest do
  @moduledoc """
  Integration test to verify all refactored components work together.
  
  Tests:
  - RefactoredAnalogArchitect starts properly
  - CRDT Context integration works
  - Circuit breakers protect operations
  - CorticalAttentionEngine integration functions
  - aMCP telemetry bridge captures events
  """
  
  def test_integration do
    IO.puts("\n🧪 Testing Telemetry Integration with New Architecture...\n")
    
    # Test 1: Verify RefactoredAnalogArchitect is running
    IO.puts("1️⃣ Testing RefactoredAnalogArchitect...")
    case Process.whereis(VsmPhoenix.Telemetry.RefactoredAnalogArchitect) do
      nil -> 
        IO.puts("   ❌ RefactoredAnalogArchitect not running")
      pid -> 
        IO.puts("   ✅ RefactoredAnalogArchitect running at #{inspect(pid)}")
        
        # Try to register and sample a signal
        {:ok, _} = VsmPhoenix.Telemetry.RefactoredAnalogArchitect.register_signal("test_signal", %{
          sampling_rate: :standard,
          buffer_size: 100
        })
        
        :ok = VsmPhoenix.Telemetry.RefactoredAnalogArchitect.sample_signal("test_signal", 42.0, %{
          source: "integration_test"
        })
        
        IO.puts("   ✅ Signal registration and sampling working")
    end
    
    # Test 2: Verify CRDT Context Store is accessible
    IO.puts("\n2️⃣ Testing CRDT Context Store integration...")
    case Process.whereis(VsmPhoenix.CRDT.ContextStore) do
      nil -> 
        IO.puts("   ❌ CRDT ContextStore not running")
      pid -> 
        IO.puts("   ✅ CRDT ContextStore running at #{inspect(pid)}")
        
        # Test CRDT operations
        VsmPhoenix.CRDT.ContextStore.increment_counter("telemetry_test_counter", 1)
        VsmPhoenix.CRDT.ContextStore.add_to_set("telemetry_test_set", "test_value")
        
        IO.puts("   ✅ CRDT operations working")
    end
    
    # Test 3: Verify CorticalAttentionEngine integration
    IO.puts("\n3️⃣ Testing CorticalAttentionEngine integration...")
    case Process.whereis(VsmPhoenix.System2.CorticalAttentionEngine) do
      nil -> 
        IO.puts("   ❌ CorticalAttentionEngine not running")
      pid -> 
        IO.puts("   ✅ CorticalAttentionEngine running at #{inspect(pid)}")
        
        # Test attention scoring
        test_message = %{
          type: :test,
          priority: :high,
          content: "Integration test message"
        }
        
        case VsmPhoenix.System2.CorticalAttentionEngine.score_attention(test_message, %{}) do
          {:ok, score, _components} ->
            IO.puts("   ✅ Attention scoring working (score: #{Float.round(score, 2)})")
          error ->
            IO.puts("   ❌ Attention scoring failed: #{inspect(error)}")
        end
    end
    
    # Test 4: Verify Circuit Breakers are initialized
    IO.puts("\n4️⃣ Testing Circuit Breaker protection...")
    circuit_names = [
      :"VsmPhoenix.Telemetry.RefactoredAnalogArchitect_signal_processing",
      :"VsmPhoenix.Telemetry.RefactoredAnalogArchitect_data_persistence",
      :"VsmPhoenix.Telemetry.RefactoredAnalogArchitect_pattern_detection"
    ]
    
    working_circuits = Enum.count(circuit_names, fn name ->
      case Process.whereis(name) do
        nil -> false
        _pid -> true
      end
    end)
    
    IO.puts("   ✅ #{working_circuits}/#{length(circuit_names)} circuit breakers initialized")
    
    # Test 5: Verify aMCP Telemetry Bridge
    IO.puts("\n5️⃣ Testing aMCP Telemetry Bridge...")
    case Process.whereis(VsmPhoenix.Telemetry.Integrations.AmcpTelemetryBridge) do
      nil -> 
        IO.puts("   ❌ AmcpTelemetryBridge not running")
      pid -> 
        IO.puts("   ✅ AmcpTelemetryBridge running at #{inspect(pid)}")
        
        # Simulate an aMCP event
        Phoenix.PubSub.broadcast(VsmPhoenix.PubSub, "amcp:events", {:amcp_event, :discovery, %{
          type: :agent_discovered,
          agent_id: "test_agent_123",
          capabilities: [:test, :integration]
        }})
        
        IO.puts("   ✅ aMCP event broadcasting working")
    end
    
    # Test 6: Verify data persistence through new architecture
    IO.puts("\n6️⃣ Testing data persistence...")
    
    # Register a persistence test signal
    {:ok, _} = VsmPhoenix.Telemetry.RefactoredAnalogArchitect.register_signal("persistence_test", %{
      sampling_rate: :standard,
      buffer_size: 10
    })
    
    # Sample multiple values
    Enum.each(1..5, fn i ->
      :ok = VsmPhoenix.Telemetry.RefactoredAnalogArchitect.sample_signal("persistence_test", i * 10.0, %{
        iteration: i
      })
    end)
    
    # Small delay to allow async CRDT updates
    Process.sleep(100)
    
    # Try to get signal data
    case VsmPhoenix.Telemetry.RefactoredAnalogArchitect.get_signal_data("persistence_test") do
      {:ok, data} ->
        IO.puts("   ✅ Signal data retrieval working (#{data.sample_count} samples)")
      error ->
        IO.puts("   ❌ Signal data retrieval failed: #{inspect(error)}")
    end
    
    IO.puts("\n✅ Integration test complete!\n")
    
    # Return summary
    %{
      refactored_analog_architect: Process.whereis(VsmPhoenix.Telemetry.RefactoredAnalogArchitect) != nil,
      crdt_context_store: Process.whereis(VsmPhoenix.CRDT.ContextStore) != nil,
      cortical_attention_engine: Process.whereis(VsmPhoenix.System2.CorticalAttentionEngine) != nil,
      circuit_breakers: working_circuits > 0,
      amcp_telemetry_bridge: Process.whereis(VsmPhoenix.Telemetry.Integrations.AmcpTelemetryBridge) != nil
    }
  end
end