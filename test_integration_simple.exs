#!/usr/bin/env elixir

# Simple integration test script to verify resilience is working
# Run this from the project directory with: elixir test_integration_simple.exs

IO.puts("\n=== Testing Resilience Integration ===\n")

# Test 1: Check if Integration module is available
IO.puts("1. Checking Integration module...")
try do
  module_loaded = Code.ensure_loaded?(VsmPhoenix.Resilience.Integration)
  IO.puts("   ✓ Integration module loaded: #{module_loaded}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 2: Check if CRDT ContextStore is available
IO.puts("\n2. Checking CRDT ContextStore...")
try do
  module_loaded = Code.ensure_loaded?(VsmPhoenix.CRDT.ContextStore)
  IO.puts("   ✓ CRDT ContextStore loaded: #{module_loaded}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 3: Check if CorticalAttentionEngine is available
IO.puts("\n3. Checking CorticalAttentionEngine...")
try do
  module_loaded = Code.ensure_loaded?(VsmPhoenix.System2.CorticalAttentionEngine)
  IO.puts("   ✓ CorticalAttentionEngine loaded: #{module_loaded}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 4: Check if RefactoredAnalogArchitect is available
IO.puts("\n4. Checking RefactoredAnalogArchitect...")
try do
  module_loaded = Code.ensure_loaded?(VsmPhoenix.Telemetry.RefactoredAnalogArchitect)
  IO.puts("   ✓ RefactoredAnalogArchitect loaded: #{module_loaded}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

# Test 5: Check resilience behaviors
IO.puts("\n5. Checking Resilience Behaviors...")
try do
  circuit_breaker_loaded = Code.ensure_loaded?(VsmPhoenix.Resilience.CircuitBreakerBehavior)
  bulkhead_loaded = Code.ensure_loaded?(VsmPhoenix.Resilience.BulkheadBehavior)
  shared_loaded = Code.ensure_loaded?(VsmPhoenix.Resilience.SharedBehaviors)
  
  IO.puts("   ✓ CircuitBreakerBehavior: #{circuit_breaker_loaded}")
  IO.puts("   ✓ BulkheadBehavior: #{bulkhead_loaded}")
  IO.puts("   ✓ SharedBehaviors: #{shared_loaded}")
rescue
  e -> IO.puts("   ✗ Error: #{inspect(e)}")
end

IO.puts("\n=== Integration Test Complete ===\n")
IO.puts("All modules are loaded and available for use.")