defmodule VsmPhoenix.VarietyEngineering.Aggregators.TemporalAggregatorTest do
  @moduledoc """
  Test suite for Temporal Aggregator (S1→S2).
  Tests time-window aggregation, event correlation, and temporal pattern detection.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Aggregators.TemporalAggregator
  
  describe "time window aggregation" do
    test "aggregates events within fixed time windows" do
      events = [
        %{id: 1, timestamp: 1000, type: :error, service: "api"},
        %{id: 2, timestamp: 1500, type: :warning, service: "api"},
        %{id: 3, timestamp: 2000, type: :error, service: "db"},
        %{id: 4, timestamp: 5500, type: :info, service: "api"},
        %{id: 5, timestamp: 6000, type: :error, service: "api"}
      ]
      
      aggregator = TemporalAggregator.new(
        window_size: 5000,  # 5 second windows
        aggregation_fn: :count_by_type
      )
      
      windows = TemporalAggregator.aggregate(aggregator, events)
      
      assert length(windows) == 2
      
      # First window (0-5000ms)
      first_window = hd(windows)
      assert first_window.window_start == 0
      assert first_window.window_end == 5000
      assert first_window.counts.error == 2
      assert first_window.counts.warning == 1
      
      # Second window (5000-10000ms)
      second_window = List.last(windows)
      assert second_window.window_start == 5000
      assert second_window.counts.error == 1
      assert second_window.counts.info == 1
    end
    
    test "sliding window aggregation" do
      # Generate continuous event stream
      events = for i <- 0..99 do
        %{
          id: i,
          timestamp: i * 100,  # Event every 100ms
          value: :rand.uniform() * 100
        }
      end
      
      aggregator = TemporalAggregator.new(
        window_size: 1000,     # 1 second window
        slide_interval: 500,   # Slide every 500ms
        aggregation_fn: :average
      )
      
      sliding_windows = TemporalAggregator.sliding_aggregate(aggregator, events)
      
      # Should have overlapping windows
      assert length(sliding_windows) > 10
      
      # Windows should overlap
      Enum.chunk_every(sliding_windows, 2, 1, :discard)
      |> Enum.each(fn [w1, w2] ->
        assert w2.window_start == w1.window_start + 500
        assert w2.window_start < w1.window_end  # Overlap
      end)
    end
    
    test "tumbling vs hopping windows" do
      events = for i <- 0..19, do: %{id: i, timestamp: i * 500, value: i}
      
      # Tumbling windows (no overlap)
      tumbling = TemporalAggregator.new(
        window_size: 2000,
        window_type: :tumbling
      )
      
      tumbling_result = TemporalAggregator.aggregate(tumbling, events)
      
      # Should have non-overlapping windows
      assert length(tumbling_result) == 5
      Enum.chunk_every(tumbling_result, 2, 1, :discard)
      |> Enum.each(fn [w1, w2] ->
        assert w1.window_end == w2.window_start
      end)
      
      # Hopping windows (with overlap)
      hopping = TemporalAggregator.new(
        window_size: 2000,
        hop_size: 1000,
        window_type: :hopping
      )
      
      hopping_result = TemporalAggregator.aggregate(hopping, events)
      
      # Should have more windows due to overlap
      assert length(hopping_result) > length(tumbling_result)
    end
  end
  
  describe "event correlation" do
    test "correlates events within time proximity" do
      events = [
        %{id: 1, timestamp: 1000, type: :api_error, correlation_id: nil},
        %{id: 2, timestamp: 1100, type: :db_timeout, correlation_id: nil},
        %{id: 3, timestamp: 1200, type: :cache_miss, correlation_id: nil},
        %{id: 4, timestamp: 5000, type: :api_error, correlation_id: nil},
        %{id: 5, timestamp: 8000, type: :network_error, correlation_id: nil}
      ]
      
      aggregator = TemporalAggregator.new(
        correlation_window: 500,  # Events within 500ms are correlated
        correlation_rules: [
          {:cascade, [:api_error, :db_timeout]},
          {:related, [:cache_miss], 1000}  # Cache miss within 1s of other events
        ]
      )
      
      correlated = TemporalAggregator.correlate_events(aggregator, events)
      
      # Events 1, 2, 3 should be correlated
      assert correlated[1].correlation_id == correlated[2].correlation_id
      assert correlated[2].correlation_id == correlated[3].correlation_id
      
      # Events 4 and 5 should be independent
      assert correlated[4].correlation_id != correlated[1].correlation_id
      assert correlated[5].correlation_id != correlated[1].correlation_id
    end
    
    test "detects event patterns and sequences" do
      # Login attempt pattern
      events = [
        %{id: 1, timestamp: 1000, type: :login_attempt, user: "alice", success: false},
        %{id: 2, timestamp: 2000, type: :login_attempt, user: "alice", success: false},
        %{id: 3, timestamp: 3000, type: :login_attempt, user: "alice", success: false},
        %{id: 4, timestamp: 4000, type: :account_locked, user: "alice"},
        %{id: 5, timestamp: 5000, type: :login_attempt, user: "bob", success: true}
      ]
      
      aggregator = TemporalAggregator.new(
        pattern_detection: true,
        patterns: [
          %{
            name: :brute_force,
            sequence: [:login_attempt, :login_attempt, :login_attempt],
            window: 5000,
            conditions: [{:all, :success, false}]
          }
        ]
      )
      
      detected_patterns = TemporalAggregator.detect_patterns(aggregator, events)
      
      assert length(detected_patterns) == 1
      assert hd(detected_patterns).pattern == :brute_force
      assert hd(detected_patterns).user == "alice"
      assert hd(detected_patterns).event_ids == [1, 2, 3]
    end
  end
  
  describe "temporal statistics" do
    test "calculates time-based statistics" do
      # Generate events with varying rates
      events = []
      # Burst period (high rate)
      events = events ++ for i <- 0..49, do: %{
        id: i, 
        timestamp: 1000 + i * 20,  # 50 events/second
        type: :request
      }
      # Normal period
      events = events ++ for i <- 50..99, do: %{
        id: i,
        timestamp: 3000 + (i - 50) * 100,  # 10 events/second
        type: :request
      }
      # Quiet period
      events = events ++ for i <- 100..109, do: %{
        id: i,
        timestamp: 10000 + (i - 100) * 1000,  # 1 event/second
        type: :request
      }
      
      aggregator = TemporalAggregator.new(
        window_size: 1000,
        statistics: [:rate, :burst_detection, :periodicity]
      )
      
      stats = TemporalAggregator.calculate_statistics(aggregator, events)
      
      # Should detect rate changes
      assert length(stats.rate_changes) >= 2
      
      # Should detect burst period
      assert stats.burst_periods != []
      burst = hd(stats.burst_periods)
      assert burst.start_time >= 1000 and burst.start_time <= 2000
      assert burst.rate > 30  # events/second
      
      # Should calculate overall statistics
      assert stats.avg_rate > 0
      assert stats.peak_rate > stats.avg_rate
    end
    
    test "detects periodicity and cycles" do
      # Generate events with daily pattern
      events = for day <- 0..6, hour <- 0..23 do
        # Higher rate during business hours
        rate = if hour >= 9 and hour <= 17, do: 10, else: 2
        
        for i <- 0..rate do
          %{
            id: "#{day}_#{hour}_#{i}",
            timestamp: (day * 24 + hour) * 3600 * 1000 + i * 60000,
            type: :transaction
          }
        end
      end
      |> List.flatten()
      
      aggregator = TemporalAggregator.new(
        window_size: 3600 * 1000,  # 1 hour windows
        detect_cycles: true,
        min_cycle_length: 12  # hours
      )
      
      cycles = TemporalAggregator.detect_cycles(aggregator, events)
      
      # Should detect daily cycle
      assert length(cycles) > 0
      daily_cycle = Enum.find(cycles, &(&1.period_hours == 24))
      assert daily_cycle != nil
      assert daily_cycle.confidence > 0.8
    end
  end
  
  describe "multi-stream aggregation" do
    test "aggregates multiple event streams" do
      # Three different service streams
      api_events = for i <- 0..19, do: %{
        id: "api_#{i}",
        timestamp: i * 500,
        service: "api",
        latency: 100 + :rand.uniform() * 50
      }
      
      db_events = for i <- 0..19, do: %{
        id: "db_#{i}",
        timestamp: i * 500 + 100,  # Slightly offset
        service: "database",
        latency: 20 + :rand.uniform() * 10
      }
      
      cache_events = for i <- 0..19, do: %{
        id: "cache_#{i}",
        timestamp: i * 500 + 200,
        service: "cache",
        latency: 5 + :rand.uniform() * 3
      }
      
      all_events = api_events ++ db_events ++ cache_events
      
      aggregator = TemporalAggregator.new(
        window_size: 2000,
        group_by: :service,
        aggregation_fn: :percentiles
      )
      
      aggregated = TemporalAggregator.aggregate_streams(aggregator, all_events)
      
      # Should have windows with all services
      assert length(aggregated) > 0
      
      first_window = hd(aggregated)
      assert Map.has_key?(first_window.services, "api")
      assert Map.has_key?(first_window.services, "database")
      assert Map.has_key?(first_window.services, "cache")
      
      # Should calculate percentiles per service
      assert first_window.services["api"].p50 > 100
      assert first_window.services["database"].p50 > 20
      assert first_window.services["cache"].p50 > 5
    end
  end
  
  describe "temporal anomaly detection" do
    test "detects time-based anomalies" do
      # Normal events with temporal anomaly
      events = for i <- 0..99 do
        if i >= 40 and i <= 45 do
          # Events arriving out of order / time jump
          %{
            id: i,
            timestamp: 1000 + i * 100 - 5000,  # 5 second jump back
            type: :sensor_reading,
            value: 50 + :rand.uniform() * 10
          }
        else
          %{
            id: i,
            timestamp: 1000 + i * 100,
            type: :sensor_reading,
            value: 50 + :rand.uniform() * 10
          }
        end
      end
      
      aggregator = TemporalAggregator.new(
        detect_temporal_anomalies: true,
        max_time_drift: 1000  # 1 second max drift
      )
      
      anomalies = TemporalAggregator.detect_temporal_anomalies(aggregator, events)
      
      # Should detect the time jump
      assert length(anomalies) > 0
      assert Enum.any?(anomalies, &(&1.type == :time_jump))
      
      time_jump = Enum.find(anomalies, &(&1.type == :time_jump))
      assert time_jump.affected_events >= 5
    end
  end
  
  describe "coordination preparation" do
    test "prepares aggregated data for S2 coordination" do
      # Simulate events from multiple S1 agents
      events = for agent <- 1..3, i <- 0..29 do
        %{
          id: "#{agent}_#{i}",
          timestamp: i * 1000,
          agent_id: "agent_#{agent}",
          metrics: %{
            cpu: 40 + :rand.uniform() * 30,
            memory: 50 + :rand.uniform() * 20,
            requests: 100 + :rand.uniform() * 50
          }
        }
      end
      
      aggregator = TemporalAggregator.new(
        window_size: 10000,  # 10 second windows
        coordination_mode: true,
        summary_stats: [:mean, :max, :trend]
      )
      
      coordination_data = TemporalAggregator.prepare_for_coordination(
        aggregator,
        events
      )
      
      # Should have summary for S2
      assert length(coordination_data) == 3  # 3 windows
      
      first_window = hd(coordination_data)
      assert first_window.agent_count == 3
      assert first_window.total_events == 30
      assert Map.has_key?(first_window.aggregated_metrics, :cpu)
      assert first_window.aggregated_metrics.cpu.mean > 40
      assert first_window.aggregated_metrics.cpu.max > 60
      
      # Should identify trends
      assert first_window.trends != nil
    end
  end
  
  describe "performance optimization" do
    test "handles high-frequency event streams" do
      # 100k events over 10 seconds (10k events/second)
      events = for i <- 0..99_999 do
        %{
          id: i,
          timestamp: div(i, 10),  # 10 events per ms
          value: :rand.uniform()
        }
      end
      
      aggregator = TemporalAggregator.new(
        window_size: 1000,  # 1 second windows
        high_frequency_mode: true,
        pre_aggregation: true
      )
      
      {time, result} = :timer.tc(fn ->
        TemporalAggregator.aggregate(aggregator, events)
      end)
      
      # Should complete quickly despite volume
      assert time < 1_000_000  # Under 1 second
      assert length(result) == 10  # 10 windows
      
      # Each window should have aggregated ~10k events
      assert hd(result).event_count >= 9000
    end
    
    test "memory-efficient streaming aggregation" do
      # Simulate continuous stream
      aggregator = TemporalAggregator.new(
        window_size: 5000,
        streaming_mode: true
      )
      
      {:ok, stream_pid} = TemporalAggregator.start_stream(aggregator)
      
      # Feed events in batches
      for batch <- 0..99 do
        events = for i <- 0..99 do
          %{
            id: batch * 100 + i,
            timestamp: batch * 50 + i,
            value: :rand.uniform() * 100
          }
        end
        
        TemporalAggregator.add_to_stream(stream_pid, events)
      end
      
      # Get windows emitted so far
      windows = TemporalAggregator.get_completed_windows(stream_pid)
      
      # Should have emitted windows without storing all events
      assert length(windows) > 0
      
      # Check memory usage is bounded
      {:memory, memory_bytes} = Process.info(stream_pid, :memory)
      assert memory_bytes < 1_000_000  # Less than 1MB
      
      TemporalAggregator.stop_stream(stream_pid)
    end
  end
end