#!/usr/bin/env elixir

# Test script to verify resilience integration with refactored architectures

Mix.install([
  {:vsm_phoenix, path: ".", runtime: false}
])

# Ensure application is started
Application.ensure_all_started(:vsm_phoenix)

IO.puts("\n=== Testing Resilience Integration ===\n")

# Test 1: CRDT-backed circuit breaker
IO.puts("1. Testing CRDT-backed Circuit Breaker...")
try do
  result = VsmPhoenix.Resilience.Integration.with_crdt_circuit_breaker(
    "test_circuit", 
    fn -> {:ok, "Success!"} end
  )
  IO.puts("   ✓ Circuit breaker executed: #{inspect(result)}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 2: Attention-priority execution
IO.puts("\n2. Testing Attention-Priority Execution...")
try do
  high_priority_task = %{
    id: "high_priority_test",
    priority: 1.0,
    operation: fn -> {:ok, "High priority executed!"} end
  }
  
  result = VsmPhoenix.Resilience.Integration.execute_with_attention_priority(
    high_priority_task
  )
  IO.puts("   ✓ High priority task executed: #{inspect(result)}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 3: Telemetry-monitored resilience
IO.puts("\n3. Testing Telemetry-Monitored Resilience...")
try do
  result = VsmPhoenix.Resilience.Integration.with_telemetry_monitoring(
    "test_operation",
    fn -> {:ok, "Monitored operation complete!"} end
  )
  IO.puts("   ✓ Monitored operation executed: #{inspect(result)}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 4: aMCP secure communication
IO.puts("\n4. Testing aMCP Secure Communication...")
try do
  result = VsmPhoenix.Resilience.Integration.send_secure_amcp_message(
    "test_recipient",
    %{message: "Test message"},
    %{encryption: :aes256}
  )
  IO.puts("   ✓ Secure message sent: #{inspect(result)}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 5: Circuit breaker with all integrations
IO.puts("\n5. Testing Full Integration (Circuit Breaker + CRDT + Telemetry + Attention)...")
try do
  # Define a test module that uses the circuit breaker behavior
  defmodule TestModule do
    use VsmPhoenix.Resilience.CircuitBreakerBehavior,
      circuit_name: "integration_test",
      failure_threshold: 3,
      timeout_ms: 5000,
      reset_timeout_ms: 10000
      
    def test_operation do
      with_circuit_breaker do
        # Simulate an operation
        Process.sleep(100)
        {:ok, "Operation completed successfully!"}
      end
    end
  end
  
  result = TestModule.test_operation()
  IO.puts("   ✓ Full integration test passed: #{inspect(result)}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

IO.puts("\n=== Integration Tests Complete ===\n")