defmodule VsmPhoenix.MCP.ExampleUsage do
  @moduledoc """
  Example usage of the Autonomous MCP Acquisition System.
  
  This module demonstrates how the system autonomously identifies variety gaps
  and acquires MCP servers to fill those gaps.
  """
  
  alias VsmPhoenix.MCP.{AutonomousAcquisition, AcquisitionSupervisor, AcquisitionMonitor}
  
  @doc """
  Start the autonomous acquisition system and watch it work.
  """
  def demo_autonomous_acquisition do
    IO.puts("\n🤖 Starting Autonomous MCP Acquisition Demo...\n")
    
    # The system is already started by the application supervisor
    # but we can trigger immediate actions
    
    # Force an immediate variety gap scan
    IO.puts("🔍 Forcing variety gap scan...")
    AcquisitionSupervisor.force_scan()
    
    # Give it a moment to scan
    Process.sleep(2000)
    
    # Check current metrics
    IO.puts("\n📊 Current System Metrics:")
    metrics = AcquisitionMonitor.get_metrics()
    print_metrics(metrics)
    
    # Check acquisition supervisor status
    IO.puts("\n🔧 Acquisition System Status:")
    status = AcquisitionSupervisor.status()
    print_status(status)
    
    # Get overall statistics
    IO.puts("\n📈 System Statistics:")
    stats = AcquisitionSupervisor.get_stats()
    print_stats(stats)
    
    # Check for any alerts
    IO.puts("\n⚠️  Active Alerts:")
    alerts = AcquisitionMonitor.get_alerts()
    print_alerts(alerts)
    
    IO.puts("\n✅ Demo complete! The system continues to run autonomously.")
  end
  
  @doc """
  Manually evaluate a specific MCP server for acquisition.
  """
  def evaluate_server(server_id, server_name, capabilities) do
    server = %{
      id: server_id,
      name: server_name,
      description: "Manually evaluated server",
      capabilities: Enum.map(capabilities, fn cap ->
        %{type: cap, description: "#{cap} capability"}
      end),
      dependencies: [],
      source: {:manual, "user"}
    }
    
    IO.puts("\n🔍 Evaluating #{server_name}...")
    
    result = AutonomousAcquisition.evaluate_cost_benefit(server)
    
    IO.puts("\n📊 Cost-Benefit Analysis:")
    IO.puts("  Score: #{Float.round(result.score, 3)}")
    IO.puts("  Recommendation: #{if result.recommendation, do: "✅ ACQUIRE", else: "❌ SKIP"}")
    IO.puts("\n  Reasoning: #{result.reasoning}")
    
    IO.puts("\n  Detailed Analysis:")
    Enum.each(result.analysis, fn {factor, value} ->
      IO.puts("    #{factor}: #{Float.round(value, 3)}")
    end)
    
    result
  end
  
  @doc """
  Inject a simulated variety gap to trigger autonomous acquisition.
  """
  def inject_variety_gap(gap_type, severity \\ 0.8) do
    IO.puts("\n💉 Injecting variety gap: #{gap_type} (severity: #{severity})")
    
    # This would normally come from System1/2/3 identifying real gaps
    # For demo purposes, we'll simulate by triggering a scan
    AcquisitionSupervisor.force_scan()
    
    IO.puts("  Gap injected! The autonomous system will address it shortly.")
  end
  
  @doc """
  Monitor the acquisition loop in real-time.
  """
  def monitor_realtime(duration_seconds \\ 30) do
    IO.puts("\n📡 Monitoring autonomous acquisition for #{duration_seconds} seconds...\n")
    
    end_time = System.monotonic_time(:second) + duration_seconds
    
    monitor_loop(end_time)
  end
  
  # Private helper functions
  
  defp monitor_loop(end_time) do
    if System.monotonic_time(:second) < end_time do
      # Get recent events
      events = AcquisitionMonitor.get_events(5)
      
      if length(events) > 0 do
        IO.puts("\n🔄 Recent Activity:")
        Enum.each(events, &print_event/1)
      end
      
      Process.sleep(5000)
      monitor_loop(end_time)
    else
      IO.puts("\n✅ Monitoring complete!")
    end
  end
  
  defp print_metrics(metrics) do
    IO.puts("  Acquisitions Attempted: #{metrics.acquisitions_attempted}")
    IO.puts("  Acquisitions Successful: #{metrics.acquisitions_successful}")
    IO.puts("  Acquisitions Failed: #{metrics.acquisitions_failed}")
    IO.puts("  Success Rate: #{Float.round(metrics.success_rate * 100, 1)}%")
    IO.puts("  Variety Gaps Identified: #{metrics.variety_gaps_identified}")
    IO.puts("  Variety Gaps Resolved: #{metrics.variety_gaps_resolved}")
    IO.puts("  Gap Resolution Rate: #{Float.round(metrics.gap_resolution_rate * 100, 1)}%")
    IO.puts("  Average Acquisition Time: #{Float.round(metrics.average_acquisition_time / 1000, 1)}s")
    IO.puts("  Decision Accuracy: #{Float.round(metrics.decision_accuracy * 100, 1)}%")
    IO.puts("  System Health: #{Float.round(metrics.system_health * 100, 1)}%")
    IO.puts("  Efficiency Score: #{Float.round(metrics.efficiency_score * 100, 1)}%")
  end
  
  defp print_status(status) do
    Enum.each(status, fn component ->
      alive_emoji = if component.alive?, do: "✅", else: "❌"
      IO.puts("  #{alive_emoji} #{component.component} (#{component.type})")
    end)
  end
  
  defp print_stats(stats) do
    IO.puts("\n  Acquisition Stats:")
    print_map_indented(stats.acquisition, 4)
    
    IO.puts("\n  Registry Stats:")
    print_map_indented(stats.registry, 4)
    
    IO.puts("\n  Integration Stats:")
    print_map_indented(stats.integration, 4)
    
    IO.puts("\n  Monitor Metrics:")
    print_map_indented(stats.monitor, 4)
  end
  
  defp print_map_indented(map, indent) do
    spaces = String.duplicate(" ", indent)
    Enum.each(map, fn {k, v} ->
      IO.puts("#{spaces}#{k}: #{inspect(v)}")
    end)
  end
  
  defp print_alerts(alerts) do
    if Enum.empty?(alerts) do
      IO.puts("  ✅ No active alerts")
    else
      Enum.each(alerts, fn alert ->
        emoji = case alert.severity do
          :error -> "🔴"
          :warning -> "🟡"
          :info -> "🔵"
          _ -> "⚪"
        end
        
        IO.puts("  #{emoji} #{alert.message} (#{alert.type})")
        IO.puts("      Created: #{alert.created_at}")
      end)
    end
  end
  
  defp print_event(event) do
    timestamp = Calendar.strftime(event.timestamp, "%H:%M:%S")
    
    case event.type do
      :acquisition ->
        outcome_emoji = if match?(:success, event.outcome), do: "✅", else: "❌"
        IO.puts("  [#{timestamp}] #{outcome_emoji} Acquisition: #{event.server_id} (#{event.duration}ms)")
        
      :variety_gap ->
        action_emoji = if event.action == :identified, do: "🔍", else: "✅"
        IO.puts("  [#{timestamp}] #{action_emoji} Gap #{event.action}: #{event.gap.type}")
        
      _ ->
        IO.puts("  [#{timestamp}] #{event.type}: #{inspect(event)}")
    end
  end
end