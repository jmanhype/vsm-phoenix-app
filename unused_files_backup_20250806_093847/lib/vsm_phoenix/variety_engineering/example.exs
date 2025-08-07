defmodule VsmPhoenix.VarietyEngineering.Example do
  @moduledoc """
  Example demonstrating how variety engineering works in the VSM Phoenix system.
  
  This module shows how messages flow through filters and amplifiers,
  implementing Ashby's Law of Requisite Variety.
  """
  
  def demonstrate_variety_flow do
    IO.puts("\n=== VSM Variety Engineering Demonstration ===\n")
    
    # 1. Generate high-variety S1 events
    IO.puts("1. Generating S1 operational events...")
    s1_events = generate_s1_events(100)
    IO.puts("   Generated #{length(s1_events)} S1 events")
    
    # 2. S1→S2 Filter reduces variety through aggregation
    IO.puts("\n2. S1→S2 Filter (Event Aggregation)...")
    # In reality, this happens automatically via PubSub
    # The filter aggregates similar events into patterns
    s2_patterns = [
      %{pattern_type: :resource_pattern, event_count: 23, significance: 0.8},
      %{pattern_type: :anomaly_pattern, event_count: 5, significance: 0.9},
      %{pattern_type: :operational_pattern, event_count: 72, significance: 0.6}
    ]
    IO.puts("   Reduced to #{length(s2_patterns)} coordination patterns")
    
    # 3. S2→S3 Filter for resource allocation
    IO.puts("\n3. S2→S3 Filter (Resource Prioritization)...")
    s3_resource_needs = [
      %{type: :resource_allocation, urgency: :high, pattern: :anomaly_pattern},
      %{type: :performance_trend, trend: :degrading, action_required: true}
    ]
    IO.puts("   Reduced to #{length(s3_resource_needs)} resource decisions")
    
    # 4. S3→S4 Filter for strategic trends
    IO.puts("\n4. S3→S4 Filter (Strategic Trends)...")
    s4_strategic_info = [
      %{type: :environmental_change, impact: :significant, timeframe: :medium_term}
    ]
    IO.puts("   Reduced to #{length(s4_strategic_info)} strategic insights")
    
    # 5. S4→S5 Filter for policy relevance
    IO.puts("\n5. S4→S5 Filter (Policy Relevance)...")
    s5_policy_input = [
      %{type: :adaptation_required, scope: :system_wide, urgency: :high}
    ]
    IO.puts("   Reduced to #{length(s5_policy_input)} policy decision(s)")
    
    IO.puts("\n=== VARIETY REDUCTION: 100 → 3 → 2 → 1 → 1 ===")
    
    # Now demonstrate amplification going down
    IO.puts("\n=== Policy Amplification (Downward) ===\n")
    
    # 6. S5→S4 Amplifier expands policy
    IO.puts("6. S5→S4 Amplifier (Policy Expansion)...")
    s4_directives = [
      %{type: :scan_compliance, priority: :high},
      %{type: :scan_opportunities, priority: :medium},
      %{type: :monitor_thresholds, priority: :high}
    ]
    IO.puts("   Expanded to #{length(s4_directives)} intelligence directives")
    
    # 7. S4→S3 Amplifier for resource planning
    IO.puts("\n7. S4→S3 Amplifier (Resource Planning)...")
    s3_plans = [
      %{type: :allocate_scanning_resources, amount: "20%"},
      %{type: :establish_monitoring_budget, amount: "15%"},
      %{type: :reserve_adaptation_capacity, amount: "10%"}
    ]
    IO.puts("   Expanded to #{length(s3_plans)} resource plans")
    
    # 8. S3→S2 Amplifier for coordination rules
    IO.puts("\n8. S3→S2 Amplifier (Coordination Rules)...")
    s2_rules = List.duplicate(%{type: :coordination_rule}, 9)
    IO.puts("   Expanded to #{length(s2_rules)} coordination rules")
    
    # 9. S2→S1 Amplifier for operational tasks
    IO.puts("\n9. S2→S1 Amplifier (Operational Tasks)...")
    s1_tasks = List.duplicate(%{type: :operational_task}, 45)
    IO.puts("   Expanded to #{length(s1_tasks)} operational tasks")
    
    IO.puts("\n=== VARIETY AMPLIFICATION: 1 → 3 → 3 → 9 → 45 ===")
    
    # Show variety balance
    IO.puts("\n=== Variety Balance Check ===")
    IO.puts("Environmental Variety (S1 input): 100")
    IO.puts("Management Variety (S1 output): 45")
    IO.puts("Variety Ratio: #{Float.round(45/100, 2)}")
    IO.puts("\nStatus: System needs more management variety to match environment!")
    IO.puts("Action: Balance Monitor would trigger increased amplification")
  end
  
  defp generate_s1_events(count) do
    for i <- 1..count do
      %{
        id: i,
        type: Enum.random([:sensor_reading, :user_action, :system_event, :external_input]),
        timestamp: DateTime.utc_now(),
        source: "agent_#{rem(i, 10)}"
      }
    end
  end
  
  def show_configuration do
    IO.puts("\n=== Current Variety Engineering Configuration ===\n")
    
    config = Application.get_env(:vsm_phoenix, :variety_engineering, %{})
    
    IO.puts("Filters:")
    IO.inspect(config[:filters], pretty: true)
    
    IO.puts("\nAmplifiers:")
    IO.inspect(config[:amplifiers], pretty: true)
    
    IO.puts("\nBalance Monitor:")
    IO.inspect(config[:balance_monitor], pretty: true)
  end
  
  def check_live_metrics do
    IO.puts("\n=== Live Variety Metrics ===\n")
    
    # This would show real metrics from the running system
    metrics = VsmPhoenix.VarietyEngineering.Supervisor.get_variety_metrics()
    IO.inspect(metrics, pretty: true)
    
    IO.puts("\n=== Balance Status ===\n")
    balance = VsmPhoenix.VarietyEngineering.Supervisor.get_balance_status()
    IO.inspect(balance, pretty: true)
  end
end

# To run the demonstration:
# VsmPhoenix.VarietyEngineering.Example.demonstrate_variety_flow()