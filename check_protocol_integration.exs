#!/usr/bin/env elixir

# Script to check if Advanced aMCP Protocol Extensions are active

IO.puts("\n=== Checking Advanced aMCP Protocol Extensions ===\n")

# Check if TelegramProtocolIntegration is running
telegram_integration_pid = Process.whereis(VsmPhoenix.System1.Agents.TelegramProtocolIntegration)
IO.puts("1. TelegramProtocolIntegration Process:")
IO.puts("   PID: #{inspect(telegram_integration_pid)}")
IO.puts("   Status: #{if telegram_integration_pid, do: "✅ Running", else: "❌ Not Running"}")

# Check if Discovery module is running
discovery_pid = Process.whereis(VsmPhoenix.AMQP.Discovery)
IO.puts("\n2. Discovery Protocol:")
IO.puts("   PID: #{inspect(discovery_pid)}")
IO.puts("   Status: #{if discovery_pid, do: "✅ Running", else: "❌ Not Running"}")

# Check if Consensus module is running
consensus_pid = Process.whereis(VsmPhoenix.AMQP.Consensus)
IO.puts("\n3. Consensus Protocol:")
IO.puts("   PID: #{inspect(consensus_pid)}")
IO.puts("   Status: #{if consensus_pid, do: "✅ Running", else: "❌ Not Running"}")

# Check if NetworkOptimizer is running
optimizer_pid = Process.whereis(VsmPhoenix.AMQP.NetworkOptimizer)
IO.puts("\n4. Network Optimizer:")
IO.puts("   PID: #{inspect(optimizer_pid)}")
IO.puts("   Status: #{if optimizer_pid, do: "✅ Running", else: "❌ Not Running"}")

# Check if ProtocolIntegration is running
integration_pid = Process.whereis(VsmPhoenix.AMQP.ProtocolIntegration)
IO.puts("\n5. Protocol Integration Layer:")
IO.puts("   PID: #{inspect(integration_pid)}")
IO.puts("   Status: #{if integration_pid, do: "✅ Running", else: "❌ Not Running"}")

# Check Telegram agents
IO.puts("\n6. Telegram Agents:")
case VsmPhoenix.System1.Registry.list_agents() do
  agents when is_list(agents) ->
    telegram_agents = Enum.filter(agents, fn agent -> 
      Map.get(agent, :type) == :telegram
    end)
    
    IO.puts("   Total Telegram agents: #{length(telegram_agents)}")
    Enum.each(telegram_agents, fn agent ->
      IO.puts("   - #{agent.id}: #{if agent.alive, do: "✅ Active", else: "❌ Inactive"}")
    end)
    
  _ ->
    IO.puts("   Unable to retrieve agent list")
end

# Try to query discovered agents via Discovery protocol
if discovery_pid do
  IO.puts("\n7. Discovered Agents via Protocol:")
  try do
    case VsmPhoenix.AMQP.Discovery.query_agents([:telegram_bot]) do
      {:ok, agents} ->
        IO.puts("   Found #{length(agents)} Telegram agents via Discovery")
        Enum.each(agents, fn agent_info ->
          IO.puts("   - Agent: #{agent_info.id} at #{agent_info.node}")
          IO.puts("     Capabilities: #{inspect(agent_info.capabilities)}")
          IO.puts("     Last seen: #{agent_info.last_seen}")
        end)
      error ->
        IO.puts("   Error querying agents: #{inspect(error)}")
    end
  rescue
    e ->
      IO.puts("   Exception while querying: #{inspect(e)}")
  end
else
  IO.puts("\n7. Discovery protocol not running - cannot query agents")
end

# Check if any Telegram agents have been announced
if telegram_integration_pid do
  IO.puts("\n8. Protocol Integration Metrics:")
  try do
    # Get state from GenServer
    state = :sys.get_state(telegram_integration_pid)
    metrics = Map.get(state, :metrics, %{})
    
    IO.puts("   Announcements: #{Map.get(metrics, :announcements, 0)}")
    IO.puts("   Consensus Commands: #{Map.get(metrics, :consensus_commands, 0)}")
    IO.puts("   Optimized Messages: #{Map.get(metrics, :optimized_messages, 0)}")
    IO.puts("   Distributed Operations: #{Map.get(metrics, :distributed_operations, 0)}")
  rescue
    e ->
      IO.puts("   Unable to retrieve metrics: #{inspect(e)}")
  end
end

IO.puts("\n=== Summary ===")
all_running = telegram_integration_pid && discovery_pid && consensus_pid && optimizer_pid && integration_pid
if all_running do
  IO.puts("✅ All Advanced aMCP Protocol Extensions are running!")
  IO.puts("✅ Telegram bot IS using the new Phase 2 protocol extensions")
else
  IO.puts("⚠️  Some protocol extensions are not running")
  IO.puts("⚠️  Telegram bot may not be fully integrated with Phase 2 extensions")
end

IO.puts("\n")