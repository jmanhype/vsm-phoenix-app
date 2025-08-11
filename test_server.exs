#!/usr/bin/env elixir

# Test script to verify server components
IO.puts("VSM Phoenix Server Integration Test")
IO.puts("===================================")

# Check which components are running
components = [
  {"Phoenix Endpoint", VsmPhoenixWeb.Endpoint},
  {"CRDT ContextStore", VsmPhoenix.CRDT.ContextStore},
  {"Queen (System 5)", VsmPhoenix.System5.Queen},
  {"Intelligence (System 4)", VsmPhoenix.System4.Intelligence},
  {"Control (System 3)", VsmPhoenix.System3.Control},
  {"Coordinator (System 2)", VsmPhoenix.System2.Coordinator},
  {"CorticalAttentionEngine", VsmPhoenix.System2.CorticalAttentionEngine},
  {"Operations (System 1)", VsmPhoenix.System1.Operations},
  {"Telegram Agent", {:global, :telegram_bot}}
]

IO.puts("\nChecking component status:")
for {name, process} <- components do
  status = case process do
    {:global, name} -> if :global.whereis_name(name) != :undefined, do: "✅ Running", else: "❌ Not running"
    name -> if Process.whereis(name), do: "✅ Running", else: "❌ Not running"
  end
  IO.puts("#{String.pad_trailing(name <> ":", 30)} #{status}")
end

# Check if Telegram agent is registered in System1 Registry
IO.puts("\nSystem1 Agent Registry:")
case Registry.lookup(VsmPhoenix.System1.Registry, :agents) do
  [] -> IO.puts("No agents registered")
  agents -> 
    for {pid, value} <- agents do
      IO.puts("  Agent PID: #{inspect(pid)}, Value: #{inspect(value)}")
    end
end

# Check Telemetry status
IO.puts("\nTelemetry Components:")
telemetry_modules = [
  {"SignalProcessor", VsmPhoenix.Telemetry.SignalProcessor},
  {"PatternDetector", VsmPhoenix.Telemetry.PatternDetector},
  {"TelegramIntegration", VsmPhoenix.Telemetry.TelegramIntegration}
]

for {name, module} <- telemetry_modules do
  status = if Process.whereis(module), do: "✅ Running", else: "❌ Not running"
  IO.puts("#{String.pad_trailing(name <> ":", 30)} #{status}")
end

IO.puts("\n✅ Test complete!")