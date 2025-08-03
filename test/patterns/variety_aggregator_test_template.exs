defmodule VsmPhoenix.VarietyEngineering.AggregatorTest do
  @moduledoc """
  Test suite for Variety Engineering Aggregators.
  Tests time/count-based aggregation, statistical operations, and state management.
  """
  
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias VsmPhoenix.VarietyEngineering.Aggregator
  alias VsmPhoenix.VarietyEngineering.TimeWindowAggregator
  alias VsmPhoenix.VarietyEngineering.CountBasedAggregator
  alias VsmPhoenix.MCP.VarietyAnalyzer
  
  describe "Time-window aggregation" do
    test "aggregates messages within time window" do
      # Create 5-second window aggregator
      aggregator = TimeWindowAggregator.new(:five_sec, 5_000, :avg)
      
      # Simulate messages over time
      now = System.monotonic_time(:millisecond)
      
      messages = [
        %{timestamp: now - 6000, value: 10},      # Outside window
        %{timestamp: now - 4000, value: 20},      # Inside window
        %{timestamp: now - 3000, value: 30},      # Inside window
        %{timestamp: now - 2000, value: 40},      # Inside window
        %{timestamp: now - 1000, value: 50},      # Inside window
        %{timestamp: now, value: 60}              # Inside window
      ]
      
      result = TimeWindowAggregator.aggregate(aggregator, messages, now)
      
      assert result.window_start == now - 5000
      assert result.window_end == now
      assert result.count == 5
      assert result.aggregate_value == 40.0  # avg of 20,30,40,50,60
    end
    
    test "sliding window aggregation" do
      aggregator = TimeWindowAggregator.new(:sliding, 1_000, :sum)
      
      # Generate continuous stream
      base_time = System.monotonic_time(:millisecond)
      stream = for i <- 0..99, do: %{
        timestamp: base_time + i * 100,  # One message every 100ms
        value: i + 1
      }
      
      # Take snapshots at different times
      snapshots = for offset <- [0, 500, 1000, 1500, 2000] do
        window_time = base_time + offset
        TimeWindowAggregator.aggregate(aggregator, stream, window_time)
      end
      
      # Verify sliding window behavior
      assert length(snapshots) == 5
      
      # Each snapshot should cover ~10 messages (1 second / 100ms per message)
      Enum.each(snapshots, fn snapshot ->
        assert snapshot.count >= 9 and snapshot.count <= 11
      end)
    end
    
    test "handles empty windows gracefully" do
      aggregator = TimeWindowAggregator.new(:empty_test, 1_000, :avg)
      now = System.monotonic_time(:millisecond)
      
      # All messages outside window
      old_messages = for i <- 1..10, do: %{
        timestamp: now - 10_000 - i * 100,
        value: i
      }
      
      result = TimeWindowAggregator.aggregate(aggregator, old_messages, now)
      
      assert result.count == 0
      assert result.aggregate_value == nil
    end
  end
  
  describe "Count-based aggregation" do
    test "aggregates fixed number of messages" do
      aggregator = CountBasedAggregator.new(:batch_10, 10, :sum)
      
      messages = for i <- 1..25, do: %{id: i, value: i}
      
      batches = CountBasedAggregator.aggregate_batches(aggregator, messages)
      
      assert length(batches) == 3  # 10 + 10 + 5
      
      # First batch: sum of 1..10 = 55
      assert hd(batches).aggregate_value == 55
      assert hd(batches).count == 10
      
      # Second batch: sum of 11..20 = 155
      assert Enum.at(batches, 1).aggregate_value == 155
      
      # Third batch: sum of 21..25 = 115
      assert List.last(batches).aggregate_value == 115
      assert List.last(batches).count == 5
    end
    
    test "streaming aggregation with state" do
      {:ok, agg_pid} = CountBasedAggregator.start_link(
        name: :stream_test,
        batch_size: 5,
        operation: :avg
      )
      
      # Stream messages one by one
      for i <- 1..12 do
        message = %{id: i, value: i * 10}
        batch = CountBasedAggregator.add_message(agg_pid, message)
        
        # Should emit batch every 5 messages
        case i do
          5 -> 
            assert batch.aggregate_value == 30.0  # avg of 10,20,30,40,50
            assert batch.count == 5
          10 ->
            assert batch.aggregate_value == 80.0  # avg of 60,70,80,90,100
            assert batch.count == 5
          _ ->
            assert batch == nil  # No batch emitted yet
        end
      end
      
      # Get incomplete batch
      partial = CountBasedAggregator.get_partial_batch(agg_pid)
      assert partial.count == 2  # Messages 11 and 12
      assert partial.aggregate_value == 115.0  # avg of 110,120
    end
  end
  
  describe "Statistical aggregations" do
    test "calculates various statistics" do
      messages = for i <- 1..100, do: %{value: :rand.normal() * 10 + 50}
      
      operations = [:avg, :min, :max, :sum, :std_dev, :median, :p95]
      
      results = Enum.map(operations, fn op ->
        agg = Aggregator.new(:stats, op)
        {op, Aggregator.aggregate(agg, messages)}
      end)
      
      results_map = Map.new(results)
      
      # Basic sanity checks
      assert results_map[:min] < results_map[:avg]
      assert results_map[:avg] < results_map[:max]
      assert results_map[:median] != nil
      assert results_map[:p95] > results_map[:median]
      assert results_map[:std_dev] > 0
      assert_in_delta results_map[:avg], 50, 5  # Should be close to 50
    end
    
    test "percentile calculations" do
      # Generate known distribution
      messages = for i <- 1..100, do: %{value: i}
      
      percentiles = [
        {:p50, 50.5},   # Median
        {:p90, 90.5},   # 90th percentile
        {:p95, 95.5},   # 95th percentile
        {:p99, 99.5}    # 99th percentile
      ]
      
      Enum.each(percentiles, fn {op, expected} ->
        agg = Aggregator.new(:percentile, op)
        result = Aggregator.aggregate(agg, messages)
        assert_in_delta result, expected, 1.0
      end)
    end
    
    test "histogram aggregation" do
      # Generate bimodal distribution
      messages = 
        (for _ <- 1..50, do: %{value: :rand.normal() * 5 + 25}) ++
        (for _ <- 1..50, do: %{value: :rand.normal() * 5 + 75})
      
      hist_agg = Aggregator.new(:histogram, {:histogram, 10})  # 10 bins
      histogram = Aggregator.aggregate(hist_agg, messages)
      
      assert map_size(histogram) == 10
      assert Enum.sum(Map.values(histogram)) == 100
      
      # Should see two peaks around bins for 25 and 75
      low_bins = Enum.filter(histogram, fn {k, _v} -> k < 50 end)
      high_bins = Enum.filter(histogram, fn {k, _v} -> k >= 50 end)
      
      assert Enum.sum(Enum.map(low_bins, fn {_, v} -> v end)) > 40
      assert Enum.sum(Enum.map(high_bins, fn {_, v} -> v end)) > 40
    end
  end
  
  describe "Variety reduction through aggregation" do
    test "reduces message variety through aggregation" do
      # Generate high-variety messages
      messages = for i <- 1..1000 do
        %{
          id: i,
          type: Enum.random([:telemetry, :metric, :status]),
          source: "sensor_#{rem(i, 50)}",
          value: :rand.uniform() * 100,
          timestamp: System.monotonic_time(:millisecond) + i
        }
      end
      
      # Measure initial variety
      initial_variety = VarietyAnalyzer.calculate_message_variety(messages)
      
      # Aggregate by type and time window
      aggregated = messages
      |> Enum.group_by(& &1.type)
      |> Enum.flat_map(fn {type, msgs} ->
        aggregator = TimeWindowAggregator.new(type, 10_000, :avg)
        
        # Create aggregated messages for each window
        msgs
        |> Enum.chunk_by(fn msg -> div(msg.timestamp, 10_000) end)
        |> Enum.map(fn chunk ->
          %{
            type: type,
            source: "aggregated",
            count: length(chunk),
            avg_value: Enum.sum(Enum.map(chunk, & &1.value)) / length(chunk),
            window: div(hd(chunk).timestamp, 10_000)
          }
        end)
      end)
      
      # Measure reduced variety
      reduced_variety = VarietyAnalyzer.calculate_message_variety(aggregated)
      
      # Verify significant variety reduction
      assert length(aggregated) < length(messages) / 10
      assert reduced_variety < initial_variety / 2
    end
  end
  
  describe "Multi-dimensional aggregation" do
    test "aggregates across multiple dimensions" do
      # Messages with multiple attributes
      messages = for i <- 1..200 do
        %{
          timestamp: System.monotonic_time(:millisecond) + i * 100,
          source: "agent_#{rem(i, 5)}",
          type: Enum.random([:cpu, :memory, :disk]),
          value: :rand.uniform() * 100,
          region: Enum.random([:us_east, :us_west, :eu])
        }
      end
      
      # Group by source and type, then aggregate
      multi_dim_result = messages
      |> Enum.group_by(fn msg -> {msg.source, msg.type} end)
      |> Enum.map(fn {{source, type}, msgs} ->
        %{
          source: source,
          type: type,
          count: length(msgs),
          avg: Enum.sum(Enum.map(msgs, & &1.value)) / length(msgs),
          regions: msgs |> Enum.map(& &1.region) |> Enum.uniq() |> length()
        }
      end)
      
      # Should have aggregates for each source-type combination
      assert length(multi_dim_result) <= 5 * 3  # 5 sources * 3 types
      
      # Each aggregate should have meaningful data
      Enum.each(multi_dim_result, fn agg ->
        assert agg.count > 0
        assert agg.avg >= 0 and agg.avg <= 100
        assert agg.regions > 0 and agg.regions <= 3
      end)
    end
  end
  
  describe "Integration with System 2 Coordinator" do
    test "aggregates telemetry for coordination decisions" do
      # Simulate telemetry stream from multiple S1 agents
      now = System.monotonic_time(:millisecond)
      
      telemetry_stream = for agent <- 1..10, reading <- 1..20 do
        %{
          agent_id: "agent_#{agent}",
          timestamp: now - (20 - reading) * 1000,  # Last 20 seconds
          type: :performance,
          cpu: 20 + :rand.uniform() * 60,
          memory: 30 + :rand.uniform() * 50,
          throughput: 100 + :rand.uniform() * 200
        }
      end
      
      # S2 aggregates to detect coordination needs
      coordination_aggregator = %{
        window: 5_000,  # 5-second windows
        thresholds: %{
          cpu: 70,      # Alert if avg CPU > 70%
          memory: 60,   # Alert if avg memory > 60%
          throughput: 150  # Alert if throughput < 150
        }
      }
      
      # Process stream and identify coordination events
      coordination_events = telemetry_stream
      |> Enum.group_by(& &1.agent_id)
      |> Enum.flat_map(fn {agent_id, agent_msgs} ->
        # Get recent messages (last 5 seconds)
        recent = Enum.filter(agent_msgs, fn msg ->
          msg.timestamp > now - coordination_aggregator.window
        end)
        
        if length(recent) > 0 do
          avg_cpu = Enum.sum(Enum.map(recent, & &1.cpu)) / length(recent)
          avg_memory = Enum.sum(Enum.map(recent, & &1.memory)) / length(recent)
          avg_throughput = Enum.sum(Enum.map(recent, & &1.throughput)) / length(recent)
          
          alerts = []
          alerts = if avg_cpu > coordination_aggregator.thresholds.cpu,
            do: [{agent_id, :high_cpu, avg_cpu} | alerts], else: alerts
          alerts = if avg_memory > coordination_aggregator.thresholds.memory,
            do: [{agent_id, :high_memory, avg_memory} | alerts], else: alerts
          alerts = if avg_throughput < coordination_aggregator.thresholds.throughput,
            do: [{agent_id, :low_throughput, avg_throughput} | alerts], else: alerts
          
          alerts
        else
          []
        end
      end)
      
      # Should detect some coordination events
      assert length(coordination_events) > 0
      
      # Verify event structure
      Enum.each(coordination_events, fn {agent_id, alert_type, value} ->
        assert String.starts_with?(agent_id, "agent_")
        assert alert_type in [:high_cpu, :high_memory, :low_throughput]
        assert is_float(value)
      end)
    end
  end
  
  describe "Aggregator performance" do
    property "aggregation time scales with message count" do
      check all message_count <- integer(100..10_000),
                window_ms <- integer(1_000..60_000),
                max_runs: 10 do
        
        messages = for i <- 1..message_count do
          %{
            timestamp: System.monotonic_time(:millisecond) - rem(i, window_ms),
            value: :rand.uniform()
          }
        end
        
        aggregator = TimeWindowAggregator.new(:perf_test, window_ms, :avg)
        
        {time, _result} = :timer.tc(fn ->
          TimeWindowAggregator.aggregate(aggregator, messages)
        end)
        
        # Should process quickly even with many messages
        assert time < message_count * 10  # Less than 10 microseconds per message
      end
    end
    
    test "memory-efficient streaming aggregation" do
      # Test that streaming aggregation doesn't accumulate memory
      {:ok, pid} = CountBasedAggregator.start_link(
        name: :memory_test,
        batch_size: 100,
        operation: :sum
      )
      
      initial_memory = :erlang.memory(:total)
      
      # Stream a large number of messages
      for i <- 1..100_000 do
        CountBasedAggregator.add_message(pid, %{value: i})
      end
      
      final_memory = :erlang.memory(:total)
      
      # Memory growth should be minimal (allowing for some overhead)
      memory_growth = final_memory - initial_memory
      assert memory_growth < 10_000_000  # Less than 10MB growth
      
      # Verify we processed all batches
      stats = CountBasedAggregator.get_stats(pid)
      assert stats.batches_emitted == 1000
      assert stats.messages_processed == 100_000
    end
  end
end