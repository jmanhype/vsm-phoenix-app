defmodule VsmPhoenix.Goldrush.PatternEngineTest do
  use ExUnit.Case
  
  alias VsmPhoenix.Goldrush.{PatternEngine, EventAggregator, Manager}
  
  setup do
    # Start required processes if not already started
    ensure_started(Manager)
    ensure_started(PatternEngine)
    ensure_started(EventAggregator)
    
    :ok
  end
  
  describe "Pattern Registration and Matching" do
    test "registers a simple pattern and matches events" do
      # Register a pattern
      pattern = %{
        id: "test_cpu_high",
        name: "Test High CPU",
        conditions: [
          %{field: "cpu_usage", operator: ">", value: 80}
        ],
        logic: "AND",
        actions: ["log_event"]
      }
      
      assert {:ok, _} = PatternEngine.register_pattern(pattern)
      
      # Submit matching event
      event = %{
        type: :system_metrics,
        cpu_usage: 85,
        timestamp: System.system_time(:second)
      }
      
      PatternEngine.process_event(event)
      
      # Give it time to process
      Process.sleep(100)
      
      # Check statistics
      stats = PatternEngine.get_statistics()
      assert stats.total_events > 0
    end
    
    test "handles complex AND conditions" do
      pattern = %{
        id: "test_complex_and",
        name: "Complex AND Pattern",
        conditions: [
          %{field: "cpu_usage", operator: ">", value: 70},
          %{field: "memory_usage", operator: ">", value: 80},
          %{field: "response_time", operator: "<", value: 1000}
        ],
        logic: "AND",
        actions: ["send_alert"]
      }
      
      assert {:ok, _} = PatternEngine.register_pattern(pattern)
      
      # Non-matching event (response_time too high)
      event1 = %{
        cpu_usage: 75,
        memory_usage: 85,
        response_time: 2000
      }
      PatternEngine.process_event(event1)
      
      # Matching event
      event2 = %{
        cpu_usage: 75,
        memory_usage: 85,
        response_time: 500
      }
      PatternEngine.process_event(event2)
      
      Process.sleep(100)
    end
    
    test "handles time window conditions" do
      pattern = %{
        id: "test_sustained_load",
        name: "Sustained Load Pattern",
        conditions: [
          %{field: "cpu_usage", operator: ">", value: 90}
        ],
        time_window: %{duration: 2, unit: :seconds},
        logic: "AND",
        actions: ["scale_resources"]
      }
      
      assert {:ok, _} = PatternEngine.register_pattern(pattern)
      
      # Send multiple high CPU events
      for _ <- 1..5 do
        event = %{cpu_usage: 95}
        PatternEngine.process_event(event)
        Process.sleep(500)
      end
      
      # Pattern should trigger after 2 seconds
      Process.sleep(100)
    end
  end
  
  describe "Event Aggregation" do
    test "aggregates events over time windows" do
      # Send multiple events
      for i <- 1..10 do
        event = %{
          type: :test_metric,
          value: i * 10,
          timestamp: System.system_time(:second)
        }
        EventAggregator.add_event(event)
      end
      
      # Get aggregates
      {:ok, aggregates} = EventAggregator.get_window_aggregates(
        event_type: :test_metric,
        window_size: 60,
        aggregations: [:count, :avg, :min, :max]
      )
      
      assert aggregates[:count] == 10
      assert aggregates[:avg] == 55.0
      assert aggregates[:min] == 10
      assert aggregates[:max] == 100
    end
    
    test "finds correlated events" do
      # Send correlated events
      for i <- 1..5 do
        EventAggregator.add_event(%{
          type: :event_a,
          value: i,
          timestamp: System.system_time(:second) + i
        })
        
        EventAggregator.add_event(%{
          type: :event_b,
          value: i * 2,
          timestamp: System.system_time(:second) + i + 1
        })
      end
      
      {:ok, correlations} = EventAggregator.get_correlated_events(
        [:event_a, :event_b],
        60
      )
      
      assert correlations.event_counts[:event_a] == 5
      assert correlations.event_counts[:event_b] == 5
    end
    
    test "creates hierarchical events" do
      child_events = [
        %{type: :child1, value: 10},
        %{type: :child2, value: 20},
        %{type: :child3, value: 30}
      ]
      
      {:ok, parent} = EventAggregator.create_hierarchical_event(
        :parent_event,
        child_events,
        %{reason: "test aggregation"}
      )
      
      assert parent.type == :parent_event
      assert parent.child_count == 3
      assert parent.hierarchical == true
    end
  end
  
  describe "Complex Pattern Scenarios" do
    test "variety explosion detection" do
      pattern = %{
        id: "variety_explosion",
        name: "Variety Explosion",
        conditions: [
          %{field: "metrics.variety_index", operator: ">", value: 0.8},
          %{field: "metrics.variety_rate", operator: ">", value: 0.2}
        ],
        logic: "AND",
        actions: ["spawn_meta_vsm", "update_policy"]
      }
      
      assert {:ok, _} = PatternEngine.register_pattern(pattern)
      
      # Simulate variety explosion
      event = %{
        type: :variety_measurement,
        metrics: %{
          variety_index: 0.85,
          variety_rate: 0.25
        }
      }
      
      Manager.submit_event(event)
      Process.sleep(100)
    end
    
    test "algedonic signal pattern" do
      pattern = %{
        id: "algedonic_pain",
        name: "Pain Signal Detection",
        conditions: [
          %{field: "signal.type", operator: "==", value: "pain"},
          %{field: "signal.intensity", operator: ">", value: 0.7}
        ],
        logic: "AND",
        actions: ["trigger_algedonic", "notify_system3"]
      }
      
      assert {:ok, _} = PatternEngine.register_pattern(pattern)
      
      # Simulate pain signal
      event = %{
        type: :algedonic_signal,
        signal: %{
          type: "pain",
          intensity: 0.9,
          source: "system1"
        }
      }
      
      Manager.submit_event(event)
      Process.sleep(100)
    end
  end
  
  # Helper functions
  
  defp ensure_started(module) do
    case Process.whereis(module) do
      nil ->
        {:ok, _} = module.start_link()
      _pid ->
        :ok
    end
  end
end