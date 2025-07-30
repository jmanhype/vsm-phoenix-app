# Test script to check if GenServers are returning real data
IO.puts("\n=== Testing VSM Dashboard Data Sources ===\n")

# Test Queen
IO.puts("1. Testing System 5 (Queen):")
try do
  result = VsmPhoenix.System5.Queen.get_identity_metrics()
  IO.inspect(result, label: "Queen metrics")
rescue
  e -> IO.puts("ERROR: #{inspect(e)}")
end

# Test Intelligence
IO.puts("\n2. Testing System 4 (Intelligence):")
try do
  result = VsmPhoenix.System4.Intelligence.get_system_health()
  IO.inspect(result, label: "Intelligence health")
rescue
  e -> IO.puts("ERROR: #{inspect(e)}")
end

# Test Control
IO.puts("\n3. Testing System 3 (Control):")
try do
  result = VsmPhoenix.System3.Control.get_resource_metrics()
  IO.inspect(result, label: "Control metrics")
rescue
  e -> IO.puts("ERROR: #{inspect(e)}")
end

# Test Coordinator
IO.puts("\n4. Testing System 2 (Coordinator):")
try do
  result = VsmPhoenix.System2.Coordinator.get_coordination_status()
  IO.inspect(result, label: "Coordinator status")
rescue
  e -> IO.puts("ERROR: #{inspect(e)}")
end

# Test Operations
IO.puts("\n5. Testing System 1 (Operations):")
try do
  result = VsmPhoenix.System1.Operations.get_operations_health()
  IO.inspect(result, label: "Operations health")
rescue
  e -> IO.puts("ERROR: #{inspect(e)}")
end

IO.puts("\n=== Test Complete ===")