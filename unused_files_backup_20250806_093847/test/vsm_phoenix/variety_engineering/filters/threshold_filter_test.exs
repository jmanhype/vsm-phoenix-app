defmodule VsmPhoenix.VarietyEngineering.Filters.ThresholdFilterTest do
  @moduledoc """
  Test suite for Threshold Filter (S3→S2).
  Tests aggregation thresholds, anomaly detection, and critical event filtering.
  """
  
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias VsmPhoenix.VarietyEngineering.Filters.ThresholdFilter
  
  describe "basic threshold filtering" do
    test "filters numeric values above threshold" do
      messages = [
        %{id: 1, metric: "cpu_usage", value: 45.2},
        %{id: 2, metric: "cpu_usage", value: 89.7},
        %{id: 3, metric: "cpu_usage", value: 67.3},
        %{id: 4, metric: "memory_usage", value: 92.1},
        %{id: 5, metric: "memory_usage", value: 54.8}
      ]
      
      # Filter for values above 70
      filter = ThresholdFilter.new(
        threshold: 70,
        operator: :greater_than
      )
      
      filtered = ThresholdFilter.apply(filter, messages)
      
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn msg -> msg.value > 70 end)
    end
    
    test "filters with multiple threshold conditions" do
      messages = [
        %{id: 1, cpu: 80, memory: 60, disk: 40},
        %{id: 2, cpu: 50, memory: 90, disk: 70},
        %{id: 3, cpu: 95, memory: 85, disk: 80},
        %{id: 4, cpu: 30, memory: 40, disk: 50},
        %{id: 5, cpu: 70, memory: 75, disk: 90}
      ]
      
      # Filter for any metric above 85
      filter = ThresholdFilter.new(
        thresholds: %{
          cpu: 85,
          memory: 85,
          disk: 85
        },
        condition: :any
      )
      
      filtered = ThresholdFilter.apply(filter, messages)
      
      assert length(filtered) == 3
      assert Enum.map(filtered, & &1.id) == [2, 3, 5]
    end
    
    test "compound threshold conditions" do
      messages = [
        %{id: 1, temperature: 75, humidity: 80},
        %{id: 2, temperature: 85, humidity: 60},
        %{id: 3, temperature: 70, humidity: 65},
        %{id: 4, temperature: 90, humidity: 85},
        %{id: 5, temperature: 68, humidity: 55}
      ]
      
      # Filter for high temp AND high humidity
      filter = ThresholdFilter.new(
        thresholds: %{
          temperature: 80,
          humidity: 70
        },
        condition: :all
      )
      
      filtered = ThresholdFilter.apply(filter, messages)
      
      assert length(filtered) == 1
      assert hd(filtered).id == 4
    end
  end
  
  describe "anomaly detection" do
    test "detects statistical anomalies" do
      # Normal distribution with outliers
      normal_values = for _ <- 1..95, do: 50 + :rand.normal() * 10
      outliers = [150, -20, 180, 0, 200]
      
      messages = (normal_values ++ outliers)
      |> Enum.with_index(1)
      |> Enum.map(fn {value, id} ->
        %{id: id, value: value, timestamp: id}
      end)
      
      filter = ThresholdFilter.new(
        anomaly_detection: true,
        method: :zscore,
        threshold: 2.5  # 2.5 standard deviations
      )
      
      anomalies = ThresholdFilter.detect_anomalies(filter, messages)
      
      # Should detect most outliers
      assert length(anomalies) >= 3
      assert Enum.all?(anomalies, fn msg ->
        msg.value > 100 or msg.value < 10
      end)
    end
    
    test "moving average anomaly detection" do
      # Generate time series with sudden spike
      messages = for i <- 1..100 do
        value = if i >= 50 and i <= 55 do
          100 + :rand.uniform() * 20  # Spike
        else
          50 + :rand.uniform() * 10   # Normal
        end
        
        %{
          id: i,
          timestamp: i * 1000,
          value: value
        }
      end
      
      filter = ThresholdFilter.new(
        anomaly_detection: true,
        method: :moving_average,
        window_size: 10,
        threshold_multiplier: 1.5
      )
      
      anomalies = ThresholdFilter.detect_anomalies(filter, messages)
      
      # Should detect the spike period
      spike_ids = Enum.map(anomalies, & &1.id)
      assert Enum.any?(50..55, fn id -> id in spike_ids end)
    end
    
    test "rate of change detection" do
      messages = [
        %{id: 1, timestamp: 1000, value: 50},
        %{id: 2, timestamp: 2000, value: 52},
        %{id: 3, timestamp: 3000, value: 54},
        %{id: 4, timestamp: 4000, value: 85},  # Sudden jump
        %{id: 5, timestamp: 5000, value: 87},
        %{id: 6, timestamp: 6000, value: 45},  # Sudden drop
        %{id: 7, timestamp: 7000, value: 47}
      ]
      
      filter = ThresholdFilter.new(
        rate_of_change: true,
        max_change_per_second: 0.01  # 1% per second
      )
      
      anomalies = ThresholdFilter.detect_rate_anomalies(filter, messages)
      
      assert length(anomalies) == 2
      assert Enum.find(anomalies, &(&1.id == 4))  # Jump
      assert Enum.find(anomalies, &(&1.id == 6))  # Drop
    end
  end
  
  describe "pattern-based thresholds" do
    test "time-based threshold patterns" do
      # Generate 24 hours of data
      messages = for hour <- 0..23, minute <- [0, 30] do
        # Higher values during business hours (9-17)
        base_value = if hour >= 9 and hour <= 17, do: 70, else: 30
        value = base_value + :rand.uniform() * 20
        
        %{
          id: hour * 2 + div(minute, 30),
          timestamp: DateTime.new!(~D[2024-01-15], ~T[00:00:00])
                    |> DateTime.add(hour * 3600 + minute * 60, :second),
          value: value,
          hour: hour
        }
      end
      
      # Different thresholds for business vs off hours
      filter = ThresholdFilter.new(
        time_based_thresholds: %{
          business_hours: {9, 17, 80},  # 9am-5pm, threshold 80
          off_hours: {18, 8, 50}        # 6pm-8am, threshold 50
        }
      )
      
      filtered = ThresholdFilter.apply(filter, messages)
      
      # Should catch high values relative to time of day
      assert length(filtered) > 0
      assert length(filtered) < length(messages)
    end
    
    test "adaptive thresholds" do
      # Gradually increasing baseline
      messages = for i <- 1..100 do
        baseline = 20 + i * 0.5  # Gradual increase
        noise = :rand.uniform() * 10
        spike = if rem(i, 20) == 0, do: 30, else: 0
        
        %{
          id: i,
          timestamp: i * 1000,
          value: baseline + noise + spike
        }
      end
      
      filter = ThresholdFilter.new(
        adaptive: true,
        learning_rate: 0.1,
        initial_threshold: 40
      )
      
      # Process with adaptive threshold
      {filtered, adapted_filter} = ThresholdFilter.apply_adaptive(filter, messages)
      
      # Should adapt to increasing baseline
      final_threshold = ThresholdFilter.get_current_threshold(adapted_filter)
      assert final_threshold > 40  # Should have increased
      
      # Should still catch spikes
      spike_ids = [20, 40, 60, 80, 100]
      caught_spikes = Enum.filter(filtered, fn msg ->
        msg.id in spike_ids
      end)
      assert length(caught_spikes) >= 3
    end
  end
  
  describe "critical event detection" do
    test "escalates critical combinations" do
      messages = [
        %{id: 1, cpu: 85, memory: 80, errors_per_min: 2},
        %{id: 2, cpu: 90, memory: 85, errors_per_min: 5},
        %{id: 3, cpu: 95, memory: 92, errors_per_min: 10},  # Critical
        %{id: 4, cpu: 60, memory: 50, errors_per_min: 0},
        %{id: 5, cpu: 98, memory: 95, errors_per_min: 15}   # Critical
      ]
      
      filter = ThresholdFilter.new(
        critical_rules: [
          # CPU > 90 AND Memory > 90
          {:all, [cpu: 90, memory: 90]},
          # Errors > 8
          {:any, [errors_per_min: 8]}
        ]
      )
      
      critical = ThresholdFilter.detect_critical(filter, messages)
      
      assert length(critical) == 2
      assert Enum.map(critical, & &1.id) == [3, 5]
      assert Enum.all?(critical, fn msg ->
        msg[:critical_level] == :high
      end)
    end
    
    test "cascade failure detection" do
      # Simulate cascading system failure
      messages = [
        %{id: 1, service: "api", status: :healthy, deps_failing: 0},
        %{id: 2, service: "database", status: :degraded, deps_failing: 0},
        %{id: 3, service: "cache", status: :failing, deps_failing: 1},
        %{id: 4, service: "api", status: :degraded, deps_failing: 2},
        %{id: 5, service: "web", status: :failing, deps_failing: 3}
      ]
      
      filter = ThresholdFilter.new(
        cascade_detection: true,
        cascade_threshold: 2  # 2 or more dependent failures
      )
      
      cascading = ThresholdFilter.detect_cascade(filter, messages)
      
      assert length(cascading) >= 2
      assert Enum.any?(cascading, &(&1.service == "web"))
    end
  end
  
  describe "aggregation with S2" do
    test "aggregates metrics for S2 coordination" do
      # Simulate metrics from multiple S1 agents
      messages = for agent <- 1..5, metric <- 1..10 do
        %{
          agent_id: "agent_#{agent}",
          timestamp: metric * 60_000,  # Every minute
          cpu: 40 + :rand.uniform() * 40,
          memory: 50 + :rand.uniform() * 30,
          requests_per_sec: 100 + :rand.uniform() * 200
        }
      end
      
      filter = ThresholdFilter.new(
        aggregation_mode: :s2_coordination,
        aggregate_by: :agent_id,
        thresholds: %{
          avg_cpu: 70,
          avg_memory: 75,
          total_requests_per_sec: 1000
        }
      )
      
      coordination_events = ThresholdFilter.aggregate_for_s2(filter, messages)
      
      # Should produce aggregated alerts for S2
      assert length(coordination_events) > 0
      
      Enum.each(coordination_events, fn event ->
        assert event.level in [:warning, :critical]
        assert event.scope == :multi_agent
        assert is_list(event.affected_agents)
      end)
    end
  end
  
  describe "performance and scalability" do
    property "efficiently handles large message volumes" do
      check all message_count <- integer(1000..50_000),
                threshold <- integer(20..80),
                max_runs: 5 do
        
        messages = for i <- 1..message_count do
          %{
            id: i,
            value: :rand.uniform() * 100,
            timestamp: i
          }
        end
        
        filter = ThresholdFilter.new(
          threshold: threshold,
          operator: :greater_than
        )
        
        {time, filtered} = :timer.tc(fn ->
          ThresholdFilter.apply(filter, messages)
        end)
        
        # Should be very fast
        time_per_message = time / message_count
        assert time_per_message < 5  # Less than 5 microseconds per message
        
        # Results should be correct
        assert Enum.all?(filtered, fn msg -> msg.value > threshold end)
      end
    end
    
    test "memory efficient for streaming data" do
      # Simulate streaming data processing
      filter = ThresholdFilter.new(
        threshold: 75,
        streaming_mode: true,
        window_size: 1000
      )
      
      # Process 1M messages in batches
      total_filtered = Enum.reduce(1..1000, 0, fn batch, acc ->
        messages = for i <- 1..1000 do
          %{
            id: batch * 1000 + i,
            value: :rand.uniform() * 100
          }
        end
        
        filtered = ThresholdFilter.apply_streaming(filter, messages)
        acc + length(filtered)
      end)
      
      # Should have filtered approximately 25% (values > 75)
      assert total_filtered > 200_000
      assert total_filtered < 300_000
    end
  end
end