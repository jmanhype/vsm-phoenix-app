defmodule VsmPhoenix.VarietyEngineering.Aggregators.PatternAggregatorTest do
  @moduledoc """
  Test suite for Pattern Aggregator (S2→S3).
  Tests pattern recognition, trend analysis, and behavioral aggregation.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Aggregators.PatternAggregator
  
  describe "pattern recognition" do
    test "identifies recurring patterns in data" do
      # Generate data with clear patterns
      data = []
      
      # Pattern 1: Spike every 10 intervals
      data = data ++ for i <- 0..99 do
        value = if rem(i, 10) == 0, do: 100, else: 50 + :rand.uniform() * 10
        %{id: i, timestamp: i * 1000, value: value, type: :metric}
      end
      
      aggregator = PatternAggregator.new(
        pattern_types: [:periodic, :spike, :trend],
        min_confidence: 0.7
      )
      
      patterns = PatternAggregator.find_patterns(aggregator, data)
      
      # Should find periodic spike pattern
      periodic = Enum.find(patterns, &(&1.type == :periodic))
      assert periodic != nil
      assert periodic.period == 10
      assert periodic.confidence > 0.8
      
      spike_pattern = Enum.find(patterns, &(&1.type == :spike))
      assert spike_pattern != nil
      assert length(spike_pattern.occurrences) == 10
    end
    
    test "detects complex behavioral patterns" do
      # User behavior pattern: browse -> add_to_cart -> checkout
      events = [
        # User 1 - complete pattern
        %{user: 1, action: :browse, time: 1000, product: "A"},
        %{user: 1, action: :browse, time: 1100, product: "B"},
        %{user: 1, action: :add_to_cart, time: 1200, product: "A"},
        %{user: 1, action: :checkout, time: 1300},
        
        # User 2 - incomplete pattern
        %{user: 2, action: :browse, time: 2000, product: "A"},
        %{user: 2, action: :add_to_cart, time: 2100, product: "A"},
        # No checkout
        
        # User 3 - complete pattern
        %{user: 3, action: :browse, time: 3000, product: "C"},
        %{user: 3, action: :add_to_cart, time: 3200, product: "C"},
        %{user: 3, action: :checkout, time: 3300},
        
        # User 4 - different pattern
        %{user: 4, action: :search, time: 4000, query: "shoes"},
        %{user: 4, action: :browse, time: 4100, product: "D"},
        %{user: 4, action: :wishlist, time: 4200, product: "D"}
      ]
      
      aggregator = PatternAggregator.new(
        behavioral_patterns: [
          %{
            name: :purchase_funnel,
            sequence: [:browse, :add_to_cart, :checkout],
            max_time_between: 1000
          },
          %{
            name: :window_shopping,
            sequence: [:browse, :wishlist],
            max_time_between: 500
          }
        ]
      )
      
      behavior_patterns = PatternAggregator.analyze_behavior(aggregator, events)
      
      # Should identify purchase funnel completions
      purchase_patterns = Enum.filter(behavior_patterns, &(&1.pattern == :purchase_funnel))
      assert length(purchase_patterns) == 2  # Users 1 and 3
      
      # Should identify incomplete funnels
      assert behavior_patterns[:incomplete_purchase_funnel] == [2]
      
      # Should identify alternative patterns
      window_shopping = Enum.find(behavior_patterns, &(&1.pattern == :window_shopping))
      assert window_shopping != nil
      assert window_shopping.users == [4]
    end
  end
  
  describe "trend analysis" do
    test "detects linear and non-linear trends" do
      # Generate trending data with noise
      data = for i <- 0..99 do
        linear_trend = i * 0.5
        exponential_component = :math.pow(1.02, i) - 1
        seasonal = :math.sin(i * 0.2) * 10
        noise = :rand.normal() * 5
        
        %{
          id: i,
          timestamp: i * 3600 * 1000,  # Hourly data
          value: 50 + linear_trend + exponential_component + seasonal + noise
        }
      end
      
      aggregator = PatternAggregator.new(
        trend_analysis: true,
        trend_types: [:linear, :exponential, :logarithmic, :seasonal]
      )
      
      trends = PatternAggregator.analyze_trends(aggregator, data)
      
      # Should detect multiple trend components
      assert trends.primary_trend == :exponential
      assert trends.trend_strength > 0.7
      
      # Should detect seasonal component
      assert trends.seasonal.detected == true
      assert_in_delta trends.seasonal.period, 31.4, 5  # ~2π/0.2
      
      # Should provide trend forecast
      assert trends.forecast != nil
      assert length(trends.forecast) > 0
    end
    
    test "identifies trend changes and inflection points" do
      # Data with clear trend change
      data = for i <- 0..99 do
        value = if i < 50 do
          # Upward trend
          50 + i * 0.8 + :rand.uniform() * 5
        else
          # Downward trend
          90 - (i - 50) * 0.6 + :rand.uniform() * 5
        end
        
        %{
          id: i,
          timestamp: i * 1000,
          value: value
        }
      end
      
      aggregator = PatternAggregator.new(
        change_detection: true,
        sensitivity: :high
      )
      
      changes = PatternAggregator.detect_trend_changes(aggregator, data)
      
      # Should detect the inflection point
      assert length(changes) >= 1
      
      inflection = hd(changes)
      assert inflection.type == :trend_reversal
      assert inflection.index >= 45 and inflection.index <= 55
      assert inflection.confidence > 0.8
      
      # Should identify trend directions
      assert inflection.before_trend == :increasing
      assert inflection.after_trend == :decreasing
    end
  end
  
  describe "multi-dimensional pattern analysis" do
    test "finds patterns across multiple metrics" do
      # Correlated metrics with patterns
      data = for i <- 0..99 do
        # When CPU is high, memory follows with delay
        cpu = 50 + :math.sin(i * 0.1) * 30 + :rand.uniform() * 10
        memory = 45 + :math.sin((i - 5) * 0.1) * 25 + :rand.uniform() * 8  # Lagged
        disk_io = if cpu > 70, do: 80 + :rand.uniform() * 15, else: 30 + :rand.uniform() * 10
        
        %{
          id: i,
          timestamp: i * 1000,
          metrics: %{
            cpu: cpu,
            memory: memory,
            disk_io: disk_io
          }
        }
      end
      
      aggregator = PatternAggregator.new(
        multi_dimensional: true,
        correlation_threshold: 0.6
      )
      
      patterns = PatternAggregator.analyze_multi_dimensional(aggregator, data)
      
      # Should find correlation between CPU and memory
      cpu_memory_correlation = patterns.correlations["cpu_memory"]
      assert cpu_memory_correlation != nil
      assert cpu_memory_correlation.coefficient > 0.7
      assert cpu_memory_correlation.lag == 5  # Memory lags CPU by 5 intervals
      
      # Should find conditional relationship with disk I/O
      conditional_patterns = patterns.conditional_relationships
      assert length(conditional_patterns) > 0
      
      disk_pattern = Enum.find(conditional_patterns, &(&1.dependent == :disk_io))
      assert disk_pattern != nil
      assert disk_pattern.condition == {:cpu, :>, 70}
    end
  end
  
  describe "anomaly patterns" do
    test "identifies anomalous pattern deviations" do
      # Normal pattern with anomalies
      data = for i <- 0..99 do
        # Normal: follows sine wave
        expected = 50 + :math.sin(i * 0.1) * 20
        
        # Add anomalies
        value = cond do
          i in [25, 26, 27] -> expected + 40  # Sustained anomaly
          i == 60 -> expected - 35             # Single point anomaly
          i in [80, 81] -> 50                  # Pattern break
          true -> expected + :rand.normal() * 3
        end
        
        %{
          id: i,
          timestamp: i * 1000,
          value: value
        }
      end
      
      aggregator = PatternAggregator.new(
        anomaly_detection: true,
        baseline_window: 20,
        deviation_threshold: 2.5
      )
      
      anomalies = PatternAggregator.detect_pattern_anomalies(aggregator, data)
      
      # Should detect different types of anomalies
      sustained = Enum.filter(anomalies, &(&1.type == :sustained_deviation))
      assert length(sustained) == 1
      assert hd(sustained).start_index >= 25
      assert hd(sustained).duration == 3
      
      point_anomalies = Enum.filter(anomalies, &(&1.type == :point_anomaly))
      assert Enum.any?(point_anomalies, &(&1.index == 60))
      
      pattern_breaks = Enum.filter(anomalies, &(&1.type == :pattern_break))
      assert length(pattern_breaks) > 0
    end
  end
  
  describe "pattern clustering" do
    test "clusters similar patterns together" do
      # Generate events with different patterns
      patterns_data = []
      
      # Pattern A: Morning spike (3 instances)
      for day <- [1, 8, 15] do
        for hour <- 0..23 do
          value = if hour in 6..9, do: 80 + :rand.uniform() * 10, else: 40 + :rand.uniform() * 10
          patterns_data = [{day, hour, value} | patterns_data]
        end
      end
      
      # Pattern B: Evening spike (3 instances)
      for day <- [2, 9, 16] do
        for hour <- 0..23 do
          value = if hour in 17..20, do: 75 + :rand.uniform() * 10, else: 35 + :rand.uniform() * 10
          patterns_data = [{day, hour, value} | patterns_data]
        end
      end
      
      # Pattern C: Constant high (2 instances)
      for day <- [3, 10] do
        for hour <- 0..23 do
          value = 70 + :rand.uniform() * 10
          patterns_data = [{day, hour, value} | patterns_data]
        end
      end
      
      data = patterns_data
      |> Enum.map(fn {day, hour, value} ->
        %{
          day: day,
          hour: hour,
          value: value,
          timestamp: (day * 24 + hour) * 3600 * 1000
        }
      end)
      |> Enum.sort_by(& &1.timestamp)
      
      aggregator = PatternAggregator.new(
        clustering_enabled: true,
        cluster_method: :kmeans,
        min_cluster_size: 2
      )
      
      clusters = PatternAggregator.cluster_patterns(aggregator, data, group_by: :day)
      
      # Should identify 3 distinct pattern clusters
      assert length(clusters) == 3
      
      # Each cluster should have the right days
      morning_cluster = Enum.find(clusters, fn c ->
        Enum.any?(c.patterns, &(&1.peak_hours == [6, 7, 8, 9]))
      end)
      assert morning_cluster != nil
      assert Enum.sort(morning_cluster.members) == [1, 8, 15]
      
      evening_cluster = Enum.find(clusters, fn c ->
        Enum.any?(c.patterns, &(&1.peak_hours == [17, 18, 19, 20]))
      end)
      assert evening_cluster != nil
      
      constant_cluster = Enum.find(clusters, fn c ->
        c.pattern_type == :constant_high
      end)
      assert constant_cluster != nil
      assert length(constant_cluster.members) == 2
    end
  end
  
  describe "pattern prediction" do
    test "predicts future pattern occurrences" do
      # Historical pattern data
      historical = for week <- 0..3, day <- 0..6, hour <- 0..23 do
        # Weekly pattern: high on weekdays during business hours
        is_weekday = day in 1..5
        is_business_hour = hour in 9..17
        
        base_value = case {is_weekday, is_business_hour} do
          {true, true} -> 80
          {true, false} -> 50
          {false, _} -> 30
        end
        
        %{
          week: week,
          day: day,
          hour: hour,
          timestamp: (week * 7 * 24 + day * 24 + hour) * 3600 * 1000,
          value: base_value + :rand.uniform() * 10
        }
      end
      
      aggregator = PatternAggregator.new(
        prediction_enabled: true,
        pattern_history: 4,  # weeks
        prediction_horizon: 7 * 24  # hours (1 week)
      )
      
      predictions = PatternAggregator.predict_patterns(aggregator, historical)
      
      # Should predict next week's pattern
      assert length(predictions) == 7 * 24
      
      # Should predict high values for weekday business hours
      weekday_business_predictions = predictions
      |> Enum.filter(fn p ->
        p.day in 1..5 and p.hour in 9..17
      end)
      |> Enum.map(& &1.predicted_value)
      
      avg_weekday_business = Enum.sum(weekday_business_predictions) / length(weekday_business_predictions)
      assert avg_weekday_business > 75
      
      # Should predict low values for weekends
      weekend_predictions = predictions
      |> Enum.filter(fn p -> p.day in [0, 6] end)
      |> Enum.map(& &1.predicted_value)
      
      avg_weekend = Enum.sum(weekend_predictions) / length(weekend_predictions)
      assert avg_weekend < 40
    end
  end
  
  describe "S3 coordination preparation" do
    test "aggregates patterns for S3 decision making" do
      # Patterns from multiple S2 coordinators
      s2_patterns = [
        %{
          coordinator_id: "s2_region_1",
          pattern_type: :capacity_strain,
          affected_services: ["api", "database"],
          severity: 0.8,
          predicted_duration: 3600
        },
        %{
          coordinator_id: "s2_region_2",
          pattern_type: :traffic_surge,
          affected_services: ["api", "cdn"],
          severity: 0.6,
          predicted_duration: 1800
        },
        %{
          coordinator_id: "s2_region_3",
          pattern_type: :normal_operation,
          affected_services: [],
          severity: 0.1,
          predicted_duration: 0
        }
      ]
      
      aggregator = PatternAggregator.new(
        s3_mode: true,
        decision_threshold: 0.7
      )
      
      s3_summary = PatternAggregator.prepare_for_s3(aggregator, s2_patterns)
      
      # Should identify cross-region patterns
      assert s3_summary.critical_patterns == [:capacity_strain]
      assert s3_summary.affected_regions == ["s2_region_1", "s2_region_2"]
      assert s3_summary.global_severity > 0.5
      
      # Should recommend coordination actions
      assert length(s3_summary.recommended_actions) > 0
      assert Enum.any?(s3_summary.recommended_actions, &(&1.type == :scale_resources))
    end
  end
  
  describe "performance" do
    test "efficiently processes large pattern datasets" do
      # Generate 100k data points with multiple patterns
      data = for i <- 0..99_999 do
        %{
          id: i,
          timestamp: i * 100,
          value: 50 + :math.sin(i * 0.01) * 20 +    # Slow oscillation
                      :math.sin(i * 0.1) * 10 +      # Fast oscillation
                      :rand.uniform() * 5,            # Noise
          category: rem(i, 5)  # 5 different categories
        }
      end
      
      aggregator = PatternAggregator.new(
        performance_mode: true,
        sampling_rate: 0.1  # Process 10% of points for pattern detection
      )
      
      {time, patterns} = :timer.tc(fn ->
        PatternAggregator.find_patterns(aggregator, data)
      end)
      
      # Should complete quickly
      assert time < 1_000_000  # Under 1 second for 100k points
      
      # Should still find major patterns despite sampling
      assert length(patterns) >= 2
      assert Enum.any?(patterns, &(&1.type == :periodic))
    end
  end
end