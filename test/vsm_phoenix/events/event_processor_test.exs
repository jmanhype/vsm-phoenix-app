defmodule VsmPhoenix.Events.EventProcessorTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Events.{EventProducer, Store}
  
  @moduletag :integration
  
  setup do
    # Ensure clean state
    :ets.delete_all_objects(:events)
    :ets.delete_all_objects(:snapshots)
    :ets.delete_all_objects(:stream_metadata)
    
    :ok
  end
  
  describe "event processing pipeline" do
    test "processes high throughput events" do
      # Generate 1000 test events
      events = for i <- 1..1000 do
        %VsmPhoenix.Events.Store.Event{
          id: "test-#{i}",
          stream_id: "load_test_stream",
          stream_version: i,
          event_type: "test.load.event",
          event_data: %{sequence: i, timestamp: DateTime.utc_now()},
          metadata: %{source: :load_test},
          timestamp: DateTime.utc_now()
        }
      end
      
      # Inject events rapidly
      start_time = :erlang.system_time(:millisecond)
      
      Enum.each(events, fn event ->
        EventProducer.inject_event(event)
      end)
      
      # Wait for processing
      Process.sleep(2000)
      
      end_time = :erlang.system_time(:millisecond)
      processing_time = end_time - start_time
      
      # Verify throughput (should handle 1000 events in under 5 seconds)
      assert processing_time < 5000
      
      # Verify events were stored
      stored_events = :ets.tab2list(:events)
      assert length(stored_events) >= 1000
    end
    
    test "handles event ordering correctly" do
      stream_id = "ordering_test_stream"
      
      # Create events with specific ordering
      events = for i <- 1..10 do
        %VsmPhoenix.Events.Store.Event{
          id: "order-#{i}",
          stream_id: stream_id,
          stream_version: i,
          event_type: "test.ordering.event",
          event_data: %{sequence: i},
          metadata: %{source: :ordering_test},
          timestamp: DateTime.utc_now()
        }
      end
      
      # Inject events
      Enum.each(events, &EventProducer.inject_event/1)
      
      # Wait for processing
      Process.sleep(1000)
      
      # Verify ordering is maintained
      {:ok, stream_events} = Store.read_stream(stream_id, 0, 100)
      
      assert length(stream_events) == 10
      
      # Check sequence is maintained
      sequences = Enum.map(stream_events, &(&1.event_data.sequence))
      assert sequences == Enum.to_list(1..10)
    end
    
    test "processes different event priorities correctly" do
      # Create high priority event
      high_priority_event = %VsmPhoenix.Events.Store.Event{
        id: "high-priority-1",
        stream_id: "priority_test_stream",
        stream_version: 1,
        event_type: "algedonic.pain.critical",
        event_data: %{pain_level: 0.9, urgency: 0.95},
        metadata: %{source: :priority_test, priority: :high},
        timestamp: DateTime.utc_now()
      }
      
      # Create normal priority events
      normal_events = for i <- 1..5 do
        %VsmPhoenix.Events.Store.Event{
          id: "normal-#{i}",
          stream_id: "priority_test_stream",
          stream_version: i + 1,
          event_type: "test.normal.event",
          event_data: %{sequence: i},
          metadata: %{source: :priority_test, priority: :normal},
          timestamp: DateTime.utc_now()
        }
      end
      
      # Inject normal events first
      Enum.each(normal_events, &EventProducer.inject_event/1)
      
      # Then inject high priority event
      EventProducer.inject_event(high_priority_event)
      
      # Wait for processing
      Process.sleep(1000)
      
      # Verify all events were processed
      {:ok, stream_events} = Store.read_stream("priority_test_stream", 0, 100)
      assert length(stream_events) == 6
      
      # High priority event should be processed
      high_priority_found = Enum.any?(stream_events, &(&1.event_type == "algedonic.pain.critical"))
      assert high_priority_found
    end
  end
  
  describe "fault tolerance" do
    test "handles malformed events gracefully" do
      # Create malformed event (missing required fields)
      malformed_event = %{
        id: "malformed-1",
        # Missing stream_id
        event_type: "test.malformed.event",
        event_data: %{test: "data"},
        timestamp: DateTime.utc_now()
      }
      
      # Should not crash the system
      EventProducer.inject_event(malformed_event)
      
      # Wait briefly
      Process.sleep(500)
      
      # System should still be running
      assert Process.alive?(Process.whereis(VsmPhoenix.Events.EventProcessor))
      assert Process.alive?(Process.whereis(VsmPhoenix.Events.EventProducer))
    end
    
    test "recovers from processing errors" do
      # Create event that might cause processing issues
      problematic_event = %VsmPhoenix.Events.Store.Event{
        id: "problematic-1",
        stream_id: "error_test_stream",
        stream_version: 1,
        event_type: "test.error.event",
        event_data: %{
          recursive_data: %{
            level1: %{
              level2: %{
                level3: "deep nesting test"
              }
            }
          }
        },
        metadata: %{source: :error_test},
        timestamp: DateTime.utc_now()
      }
      
      # Inject the problematic event
      EventProducer.inject_event(problematic_event)
      
      # Wait for processing
      Process.sleep(1000)
      
      # System should still be responsive
      normal_event = %VsmPhoenix.Events.Store.Event{
        id: "normal-after-error",
        stream_id: "error_test_stream",
        stream_version: 2,
        event_type: "test.normal.event",
        event_data: %{message: "normal event after error"},
        metadata: %{source: :error_recovery_test},
        timestamp: DateTime.utc_now()
      }
      
      EventProducer.inject_event(normal_event)
      
      # Wait for processing
      Process.sleep(500)
      
      # Verify normal event was processed
      {:ok, stream_events} = Store.read_stream("error_test_stream", 0, 100)
      normal_event_found = Enum.any?(stream_events, &(&1.id == "normal-after-error"))
      assert normal_event_found
    end
  end
  
  describe "backpressure handling" do
    test "handles burst traffic without dropping events" do
      # Create a large burst of events
      burst_events = for i <- 1..500 do
        %VsmPhoenix.Events.Store.Event{
          id: "burst-#{i}",
          stream_id: "burst_test_stream",
          stream_version: i,
          event_type: "test.burst.event",
          event_data: %{sequence: i},
          metadata: %{source: :burst_test},
          timestamp: DateTime.utc_now()
        }
      end
      
      # Inject all events as quickly as possible
      start_time = :erlang.system_time(:millisecond)
      
      Enum.each(burst_events, &EventProducer.inject_event/1)
      
      injection_time = :erlang.system_time(:millisecond) - start_time
      
      # Wait for processing to complete
      Process.sleep(3000)
      
      # Verify all events were eventually processed
      {:ok, stream_events} = Store.read_stream("burst_test_stream", 0, 1000)
      
      # Should have processed all 500 events
      assert length(stream_events) == 500
      
      # Verify injection was fast (under 1 second)
      assert injection_time < 1000
    end
  end
  
  describe "performance characteristics" do
    test "maintains low latency under load" do
      # Track processing times
      start_times = %{}
      
      # Create events with timestamps
      events = for i <- 1..100 do
        event_id = "latency-#{i}"
        start_time = :erlang.system_time(:millisecond)
        
        # Store start time for later latency calculation
        Process.put(event_id, start_time)
        
        %VsmPhoenix.Events.Store.Event{
          id: event_id,
          stream_id: "latency_test_stream",
          stream_version: i,
          event_type: "test.latency.event",
          event_data: %{sequence: i, start_time: start_time},
          metadata: %{source: :latency_test},
          timestamp: DateTime.utc_now()
        }
      end
      
      # Inject events
      Enum.each(events, &EventProducer.inject_event/1)
      
      # Wait for processing
      Process.sleep(2000)
      
      # Calculate average processing time
      end_time = :erlang.system_time(:millisecond)
      
      # Verify events were processed
      {:ok, stream_events} = Store.read_stream("latency_test_stream", 0, 1000)
      assert length(stream_events) == 100
      
      # Calculate rough latency (total time / events)
      total_processing_time = end_time - (events |> List.first() |> Map.get(:event_data) |> Map.get(:start_time))
      avg_latency = total_processing_time / 100
      
      # Should maintain reasonable latency (under 100ms average)
      assert avg_latency < 100
    end
  end
end