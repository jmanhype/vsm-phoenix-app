defmodule VsmPhoenix.VarietyEngineering.Filters.AnomalyFilterTest do
  @moduledoc """
  Test suite for Anomaly Filter (S2→S1).
  Tests critical anomaly detection, pattern deviation, and alert generation.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Filters.AnomalyFilter
  
  describe "multi-metric anomaly detection" do
    test "detects correlated anomalies across metrics" do
      # Normal baseline with correlated spike
      messages = for i <- 1..100 do
        if i >= 50 and i <= 55 do
          # Correlated anomaly period
          %{
            id: i,
            timestamp: i * 1000,
            cpu: 85 + :rand.uniform() * 10,
            memory: 90 + :rand.uniform() * 8,
            disk_io: 95 + :rand.uniform() * 5,
            network: 88 + :rand.uniform() * 10,
            errors: 50 + :rand.uniform() * 20
          }
        else
          # Normal operation
          %{
            id: i,
            timestamp: i * 1000,
            cpu: 45 + :rand.uniform() * 10,
            memory: 50 + :rand.uniform() * 10,
            disk_io: 30 + :rand.uniform() * 10,
            network: 40 + :rand.uniform() * 10,
            errors: 2 + :rand.uniform() * 3
          }
        end
      end
      
      filter = AnomalyFilter.new(
        correlation_threshold: 0.8,
        min_affected_metrics: 3
      )
      
      anomalies = AnomalyFilter.detect_correlated(filter, messages)
      
      # Should detect the correlated spike period
      assert length(anomalies) >= 4
      assert Enum.all?(anomalies, fn anomaly ->
        anomaly.id >= 50 and anomaly.id <= 55
      end)
      
      # Should identify it as a system-wide anomaly
      assert hd(anomalies).anomaly_type == :system_wide
    end
    
    test "seasonal pattern deviation detection" do
      # Generate data with daily pattern
      messages = for day <- 0..6, hour <- 0..23 do
        # Normal daily pattern: high during day, low at night
        base_value = if hour >= 9 and hour <= 17 do
          70
        else
          30
        end
        
        # Add anomaly on day 4, hour 14
        value = if day == 4 and hour == 14 do
          20  # Unusually low during peak hours
        else
          base_value + :rand.uniform() * 10
        end
        
        %{
          id: day * 24 + hour,
          timestamp: DateTime.new!(~D[2024-01-01], ~T[00:00:00])
                    |> DateTime.add((day * 24 + hour) * 3600, :second),
          value: value,
          hour: hour,
          day: day
        }
      end
      
      filter = AnomalyFilter.new(
        pattern_learning: true,
        seasonality: :daily,
        deviation_threshold: 2.0  # 2 standard deviations
      )
      
      # Learn pattern from first few days
      trained_filter = AnomalyFilter.train_pattern(filter, Enum.take(messages, 72))
      
      # Detect anomalies in remaining data
      anomalies = AnomalyFilter.detect_pattern_deviations(
        trained_filter,
        Enum.drop(messages, 72)
      )
      
      # Should detect the unusual low during peak hours
      assert length(anomalies) >= 1
      assert Enum.any?(anomalies, fn a ->
        a.hour == 14 and a.day == 4
      end)
    end
  end
  
  describe "predictive anomaly detection" do
    test "predicts future anomalies based on trends" do
      # Generate trending data heading toward anomaly
      messages = for i <- 1..50 do
        %{
          id: i,
          timestamp: i * 60_000,  # Every minute
          cpu: 40 + i * 0.8,      # Gradual increase
          memory: 45 + i * 0.6,   # Gradual increase
          queue_depth: i * 2      # Linear growth
        }
      end
      
      filter = AnomalyFilter.new(
        predictive_mode: true,
        prediction_window: 10,  # 10 minutes ahead
        critical_thresholds: %{
          cpu: 85,
          memory: 80,
          queue_depth: 100
        }
      )
      
      predictions = AnomalyFilter.predict_anomalies(filter, messages)
      
      # Should predict upcoming threshold breaches
      assert length(predictions) > 0
      
      Enum.each(predictions, fn pred ->
        assert pred.predicted_time > 50 * 60_000
        assert pred.confidence > 0.7
        assert pred.affected_metrics != []
      end)
    end
  end
  
  describe "intelligent anomaly classification" do
    test "classifies anomaly types and severity" do
      anomalies = [
        %{
          metrics: %{cpu: 95, memory: 50, disk: 40},
          duration_ms: 5000,
          pattern: :spike
        },
        %{
          metrics: %{cpu: 85, memory: 88, disk: 92},
          duration_ms: 300_000,  # 5 minutes
          pattern: :sustained
        },
        %{
          metrics: %{response_time: 5000, error_rate: 0.4},
          duration_ms: 60_000,
          pattern: :degradation
        },
        %{
          metrics: %{all_services: "down"},
          duration_ms: 1000,
          pattern: :outage
        }
      ]
      
      filter = AnomalyFilter.new(classification_enabled: true)
      
      classified = Enum.map(anomalies, fn anomaly ->
        AnomalyFilter.classify_anomaly(filter, anomaly)
      end)
      
      # First: Resource spike
      assert Enum.at(classified, 0).type == :resource_spike
      assert Enum.at(classified, 0).severity == :medium
      
      # Second: Resource exhaustion
      assert Enum.at(classified, 1).type == :resource_exhaustion
      assert Enum.at(classified, 1).severity == :high
      
      # Third: Performance degradation
      assert Enum.at(classified, 2).type == :performance_degradation
      assert Enum.at(classified, 2).severity == :high
      
      # Fourth: System outage
      assert Enum.at(classified, 3).type == :system_outage
      assert Enum.at(classified, 3).severity == :critical
    end
  end
  
  describe "root cause analysis" do
    test "identifies potential root causes" do
      # Sequence of events leading to anomaly
      events = [
        %{id: 1, time: 1000, type: :deployment, service: "api", version: "2.0"},
        %{id: 2, time: 2000, type: :config_change, service: "database", param: "pool_size", value: 10},
        %{id: 3, time: 3000, type: :metric, service: "api", cpu: 60},
        %{id: 4, time: 4000, type: :metric, service: "api", cpu: 85, errors: 10},
        %{id: 5, time: 5000, type: :metric, service: "database", connections: 10, queue: 50},
        %{id: 6, time: 6000, type: :anomaly, service: "api", cpu: 95, errors: 100}
      ]
      
      filter = AnomalyFilter.new(
        root_cause_analysis: true,
        lookback_window: 5000  # 5 seconds
      )
      
      root_causes = AnomalyFilter.analyze_root_cause(filter, events, 6)
      
      # Should identify deployment and config change as potential causes
      assert length(root_causes) >= 2
      
      deployment_cause = Enum.find(root_causes, &(&1.type == :deployment))
      assert deployment_cause != nil
      assert deployment_cause.correlation_score > 0.7
      
      config_cause = Enum.find(root_causes, &(&1.type == :config_change))
      assert config_cause != nil
      assert config_cause.impact == :database_bottleneck
    end
  end
  
  describe "alert generation and management" do
    test "generates contextual alerts with remediation" do
      anomaly = %{
        id: "anom_123",
        timestamp: ~U[2024-01-15 14:30:00Z],
        type: :resource_exhaustion,
        severity: :high,
        metrics: %{
          cpu: 92,
          memory: 88,
          affected_services: ["api", "worker"],
          duration_minutes: 5
        },
        root_cause: %{
          type: :traffic_spike,
          source: "marketing_campaign"
        }
      }
      
      filter = AnomalyFilter.new(
        alert_enrichment: true,
        include_remediation: true
      )
      
      alert = AnomalyFilter.generate_alert(filter, anomaly)
      
      assert alert.title =~ "Resource Exhaustion"
      assert alert.severity == :high
      assert alert.affected_services == ["api", "worker"]
      
      # Should include remediation steps
      assert length(alert.remediation_steps) > 0
      assert Enum.any?(alert.remediation_steps, &(&1 =~ "scale"))
      
      # Should include context
      assert alert.context.root_cause == "traffic_spike"
      assert alert.context.trigger == "marketing_campaign"
    end
    
    test "deduplicates similar alerts" do
      alerts = [
        %{service: "api", type: :high_cpu, value: 91, time: 1000},
        %{service: "api", type: :high_cpu, value: 92, time: 2000},
        %{service: "api", type: :high_cpu, value: 93, time: 3000},
        %{service: "database", type: :high_cpu, value: 88, time: 2000},
        %{service: "api", type: :high_memory, value: 85, time: 2500}
      ]
      
      filter = AnomalyFilter.new(
        deduplication_window: 5000,
        similarity_threshold: 0.9
      )
      
      deduplicated = AnomalyFilter.deduplicate_alerts(filter, alerts)
      
      # Should combine similar API CPU alerts
      assert length(deduplicated) == 3
      
      # Should have one combined API CPU alert
      api_cpu_alert = Enum.find(deduplicated, fn a ->
        a.service == "api" and a.type == :high_cpu
      end)
      assert api_cpu_alert.count == 3
      assert api_cpu_alert.max_value == 93
    end
  end
  
  describe "learning and adaptation" do
    test "learns from false positives" do
      # Historical anomalies with feedback
      history = [
        %{pattern: %{cpu: 90, memory: 50}, feedback: :false_positive, context: "scheduled_job"},
        %{pattern: %{cpu: 85, memory: 45}, feedback: :false_positive, context: "scheduled_job"},
        %{pattern: %{cpu: 95, memory: 90}, feedback: :true_positive, context: "real_issue"},
        %{pattern: %{cpu: 88, memory: 48}, feedback: :false_positive, context: "scheduled_job"}
      ]
      
      filter = AnomalyFilter.new(
        learning_enabled: true,
        initial_sensitivity: 0.8
      )
      
      # Train on historical feedback
      adapted_filter = AnomalyFilter.learn_from_feedback(filter, history)
      
      # Test with similar patterns
      test_cases = [
        %{cpu: 89, memory: 49, context: "scheduled_job"},  # Should not alert
        %{cpu: 94, memory: 88, context: "unknown"}         # Should alert
      ]
      
      results = Enum.map(test_cases, fn test ->
        AnomalyFilter.is_anomaly?(adapted_filter, test)
      end)
      
      assert Enum.at(results, 0) == false  # Learned to ignore scheduled job pattern
      assert Enum.at(results, 1) == true   # Still detects real anomalies
    end
  end
  
  describe "integration with coordination" do
    test "prioritizes alerts for S1 action" do
      anomalies = [
        %{id: 1, severity: :low, scope: :single_metric, business_impact: :minimal},
        %{id: 2, severity: :critical, scope: :system_wide, business_impact: :severe},
        %{id: 3, severity: :high, scope: :service_group, business_impact: :moderate},
        %{id: 4, severity: :medium, scope: :single_service, business_impact: :low},
        %{id: 5, severity: :critical, scope: :customer_facing, business_impact: :severe}
      ]
      
      filter = AnomalyFilter.new(
        prioritization_enabled: true,
        max_concurrent_alerts: 2
      )
      
      prioritized = AnomalyFilter.prioritize_for_action(filter, anomalies)
      
      # Should prioritize critical, customer-facing anomalies
      assert length(prioritized) == 2
      assert Enum.map(prioritized, & &1.id) == [5, 2]
      
      # Should include action recommendations
      assert hd(prioritized).recommended_action != nil
      assert hd(prioritized).escalation_level == :immediate
    end
  end
  
  describe "performance under load" do
    test "handles high-velocity anomaly streams" do
      # Generate 10k messages with 1% anomalies
      messages = for i <- 1..10_000 do
        is_anomaly = :rand.uniform() < 0.01
        
        %{
          id: i,
          timestamp: i * 100,  # 100ms intervals
          metrics: if is_anomaly do
            %{cpu: 95, memory: 92, errors: 100}
          else
            %{cpu: 50 + :rand.uniform() * 20, memory: 40 + :rand.uniform() * 20, errors: :rand.uniform(5)}
          end
        }
      end
      
      filter = AnomalyFilter.new(
        streaming_mode: true,
        batch_size: 100
      )
      
      {time, detected} = :timer.tc(fn ->
        AnomalyFilter.process_stream(filter, messages)
      end)
      
      # Should detect most anomalies
      assert length(detected) >= 80  # At least 80% detection rate
      assert length(detected) <= 120  # Not too many false positives
      
      # Should be fast (< 100ms for 10k messages)
      assert time < 100_000
    end
  end
end