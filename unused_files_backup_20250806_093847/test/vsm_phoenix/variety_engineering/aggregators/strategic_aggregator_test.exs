defmodule VsmPhoenix.VarietyEngineering.Aggregators.StrategicAggregatorTest do
  @moduledoc """
  Test suite for Strategic Aggregator (S3→S4).
  Tests system-wide trends, strategic insights, and long-term pattern aggregation.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Aggregators.StrategicAggregator
  
  describe "system-wide trend analysis" do
    test "aggregates trends across multiple subsystems" do
      # Trends from different subsystems over 30 days
      subsystem_data = []
      
      # API subsystem - growing traffic
      for day <- 0..29 do
        subsystem_data = subsystem_data ++ [%{
          subsystem: "api",
          day: day,
          metrics: %{
            requests_per_second: 1000 + day * 50 + :rand.uniform() * 100,
            error_rate: 0.01 + :rand.uniform() * 0.005,
            latency_p99: 200 + :rand.uniform() * 50
          }
        }]
      end
      
      # Database subsystem - increasing load
      for day <- 0..29 do
        subsystem_data = subsystem_data ++ [%{
          subsystem: "database",
          day: day,
          metrics: %{
            query_volume: 5000 + day * 100 + :rand.uniform() * 200,
            connection_pool_usage: 0.4 + day * 0.01 + :rand.uniform() * 0.1,
            replication_lag_ms: 50 + :rand.uniform() * 20
          }
        }]
      end
      
      # Cache subsystem - stable
      for day <- 0..29 do
        subsystem_data = subsystem_data ++ [%{
          subsystem: "cache",
          day: day,
          metrics: %{
            hit_rate: 0.85 + :rand.uniform() * 0.05,
            memory_usage: 0.6 + :rand.uniform() * 0.1,
            eviction_rate: 0.05 + :rand.uniform() * 0.02
          }
        }]
      end
      
      aggregator = StrategicAggregator.new(
        analysis_window: 30,  # days
        trend_detection: true,
        correlation_analysis: true
      )
      
      strategic_insights = StrategicAggregator.analyze_system_trends(
        aggregator,
        subsystem_data
      )
      
      # Should identify growth trends
      assert strategic_insights.growth_trends.api.requests_per_second > 0
      assert strategic_insights.growth_trends.database.query_volume > 0
      
      # Should identify stable subsystems
      assert strategic_insights.stable_subsystems == ["cache"]
      
      # Should predict capacity needs
      assert strategic_insights.capacity_projections.api.days_until_limit < 60
      assert strategic_insights.capacity_projections.database.connection_pool_warning == true
    end
    
    test "detects cross-system correlations" do
      # Generate correlated system metrics
      data = for hour <- 0..167 do  # 1 week of hourly data
        user_traffic = 1000 + :math.sin(hour * 0.1) * 500  # Daily pattern
        
        %{
          hour: hour,
          timestamp: hour * 3600 * 1000,
          metrics: %{
            user_traffic: user_traffic,
            api_calls: user_traffic * 2.5 + :rand.uniform() * 100,
            db_queries: user_traffic * 1.8 + :rand.uniform() * 50,
            cache_requests: user_traffic * 3.2 + :rand.uniform() * 150,
            revenue: user_traffic * 0.05 + :rand.uniform() * 10  # Business metric
          }
        }
      end
      
      aggregator = StrategicAggregator.new(
        correlation_window: 168,  # hours
        business_metrics: [:revenue],
        lag_analysis: true
      )
      
      correlations = StrategicAggregator.analyze_correlations(aggregator, data)
      
      # Should find strong correlations
      assert correlations.matrix["user_traffic"]["api_calls"] > 0.9
      assert correlations.matrix["user_traffic"]["revenue"] > 0.8
      
      # Should identify leading indicators
      assert correlations.leading_indicators.revenue == [:user_traffic]
      assert correlations.lag_times["user_traffic"]["revenue"] == 0  # Immediate correlation
    end
  end
  
  describe "strategic pattern recognition" do
    test "identifies long-term business patterns" do
      # Simulate 1 year of business metrics
      business_data = for day <- 0..364 do
        month = div(day, 30)
        day_of_week = rem(day, 7)
        
        # Seasonal pattern (higher in Q4)
        seasonal_factor = if month in [9, 10, 11], do: 1.5, else: 1.0
        
        # Weekly pattern (lower on weekends)
        weekly_factor = if day_of_week in [0, 6], do: 0.7, else: 1.0
        
        # Growth trend
        growth_factor = 1 + (day / 365) * 0.3
        
        %{
          day: day,
          date: Date.add(~D[2023-01-01], day),
          metrics: %{
            revenue: 10000 * seasonal_factor * weekly_factor * growth_factor *
                    (1 + :rand.uniform() * 0.1),
            user_signups: 100 * seasonal_factor * growth_factor *
                         (1 + :rand.uniform() * 0.2),
            churn_rate: 0.05 / growth_factor * (1 + :rand.uniform() * 0.02)
          }
        }
      end
      
      aggregator = StrategicAggregator.new(
        pattern_types: [:seasonal, :weekly, :growth],
        business_intelligence: true
      )
      
      patterns = StrategicAggregator.identify_strategic_patterns(
        aggregator,
        business_data
      )
      
      # Should identify seasonal pattern
      assert patterns.seasonal.detected == true
      assert patterns.seasonal.peak_period == :q4
      assert patterns.seasonal.impact_on_revenue > 1.3
      
      # Should identify weekly pattern
      assert patterns.weekly.detected == true
      assert patterns.weekly.weekend_impact < 0.8
      
      # Should identify growth trend
      assert patterns.growth.annual_rate > 0.25
      assert patterns.growth.type == :linear
    end
  end
  
  describe "predictive analytics" do
    test "forecasts strategic metrics" do
      # Historical data with trend and seasonality
      historical = for week <- 0..51 do
        base = 1000
        trend = week * 20
        seasonal = :math.sin(week * 2 * :math.pi() / 52) * 200
        noise = :rand.normal() * 50
        
        %{
          week: week,
          value: base + trend + seasonal + noise,
          timestamp: week * 7 * 24 * 3600 * 1000
        }
      end
      
      aggregator = StrategicAggregator.new(
        forecasting_enabled: true,
        forecast_horizon: 12,  # weeks
        confidence_intervals: [0.80, 0.95]
      )
      
      forecast = StrategicAggregator.forecast(aggregator, historical)
      
      # Should provide point forecasts
      assert length(forecast.predictions) == 12
      
      # Should show continuing trend
      assert List.last(forecast.predictions).value > List.first(forecast.predictions).value
      
      # Should include confidence intervals
      assert forecast.confidence_intervals."80%" != nil
      assert forecast.confidence_intervals."95%" != nil
      
      # Should include forecast quality metrics
      assert forecast.quality.method == :arima
      assert forecast.quality.mape < 10  # Mean absolute percentage error < 10%
    end
    
    test "scenario planning and what-if analysis" do
      current_state = %{
        users: 100_000,
        revenue_per_user: 50,
        infrastructure_cost: 100_000,
        growth_rate: 0.1  # 10% monthly
      }
      
      scenarios = [
        %{
          name: :aggressive_growth,
          changes: %{growth_rate: 0.2, infrastructure_cost_multiplier: 1.5}
        },
        %{
          name: :conservative,
          changes: %{growth_rate: 0.05, infrastructure_cost_multiplier: 1.1}
        },
        %{
          name: :market_downturn,
          changes: %{growth_rate: -0.05, revenue_per_user: 40}
        }
      ]
      
      aggregator = StrategicAggregator.new(
        scenario_planning: true,
        projection_months: 12
      )
      
      projections = StrategicAggregator.run_scenarios(
        aggregator,
        current_state,
        scenarios
      )
      
      # Should project each scenario
      assert length(projections) == 3
      
      aggressive = Enum.find(projections, &(&1.scenario == :aggressive_growth))
      assert aggressive.final_users > 300_000
      assert aggressive.profitability == true
      assert aggressive.break_even_month < 12
      
      downturn = Enum.find(projections, &(&1.scenario == :market_downturn))
      assert downturn.final_users < 100_000
      assert downturn.profitability == false
      assert downturn.risks == [:negative_growth, :revenue_decline]
    end
  end
  
  describe "resource optimization insights" do
    test "identifies optimization opportunities" do
      # Resource usage data across services
      usage_data = for day <- 0..29, service <- ["api", "db", "cache", "queue"] do
        # Some services are over-provisioned
        avg_usage = case service do
          "api" -> 0.75     # Well utilized
          "db" -> 0.30      # Under-utilized
          "cache" -> 0.85   # Near capacity
          "queue" -> 0.15   # Very under-utilized
        end
        
        %{
          day: day,
          service: service,
          metrics: %{
            cpu_usage: avg_usage + :rand.uniform() * 0.1,
            memory_usage: avg_usage + :rand.uniform() * 0.05,
            cost_per_day: 100 * (1 + avg_usage),
            performance_score: 0.9 - (avg_usage - 0.5) * 0.2
          }
        }
      end
      
      aggregator = StrategicAggregator.new(
        optimization_analysis: true,
        cost_awareness: true
      )
      
      optimizations = StrategicAggregator.analyze_optimization_opportunities(
        aggregator,
        usage_data
      )
      
      # Should identify under-utilized resources
      assert optimizations.under_utilized == ["db", "queue"]
      assert optimizations.potential_savings.db > 0.4  # 40% cost reduction possible
      
      # Should identify resources near capacity
      assert optimizations.capacity_risks == ["cache"]
      assert optimizations.scaling_recommendations.cache == :vertical_scale
      
      # Should provide optimization plan
      assert length(optimizations.action_plan) > 0
      assert Enum.any?(optimizations.action_plan, &(&1.service == "db" and &1.action == :downsize))
    end
  end
  
  describe "anomaly correlation across time scales" do
    test "correlates anomalies across different time scales" do
      # Anomalies at different scales
      anomalies = [
        # Minute-level anomalies (from S1)
        %{level: :s1, time: ~U[2024-01-15 10:05:23Z], type: :cpu_spike, severity: 0.6},
        %{level: :s1, time: ~U[2024-01-15 10:05:45Z], type: :memory_spike, severity: 0.7},
        %{level: :s1, time: ~U[2024-01-15 10:06:12Z], type: :cpu_spike, severity: 0.8},
        
        # Hour-level anomalies (from S2)
        %{level: :s2, time: ~U[2024-01-15 10:00:00Z], type: :traffic_surge, severity: 0.8},
        %{level: :s2, time: ~U[2024-01-15 11:00:00Z], type: :error_rate_increase, severity: 0.6},
        
        # Day-level anomalies (from S3)
        %{level: :s3, time: ~U[2024-01-15 00:00:00Z], type: :unusual_pattern, severity: 0.7},
        
        # Week-level context (from S4)
        %{level: :s4, time: ~U[2024-01-08 00:00:00Z], type: :capacity_trending_high, severity: 0.5}
      ]
      
      aggregator = StrategicAggregator.new(
        multi_scale_correlation: true,
        correlation_window: %{
          s1_to_s2: 3600,      # 1 hour
          s2_to_s3: 86400,     # 1 day
          s3_to_s4: 604800     # 1 week
        }
      )
      
      correlations = StrategicAggregator.correlate_multi_scale_anomalies(
        aggregator,
        anomalies
      )
      
      # Should link minute-level spikes to hour-level surge
      assert correlations.causal_chains != []
      
      traffic_surge_chain = Enum.find(correlations.causal_chains, fn chain ->
        chain.root_cause.type == :traffic_surge
      end)
      
      assert traffic_surge_chain != nil
      assert length(traffic_surge_chain.consequences) >= 2
      assert Enum.any?(traffic_surge_chain.consequences, &(&1.type == :cpu_spike))
      
      # Should identify systemic issues
      assert correlations.systemic_issues != []
      assert hd(correlations.systemic_issues).description =~ "capacity"
    end
  end
  
  describe "strategic decision support" do
    test "provides actionable strategic recommendations" do
      # Current system state and trends
      system_analysis = %{
        current_state: %{
          total_users: 1_000_000,
          daily_active_users: 300_000,
          infrastructure_cost: 50_000,
          revenue: 150_000,
          growth_rate: 0.15
        },
        trends: %{
          user_growth: :accelerating,
          cost_trend: :linear,
          revenue_per_user: :declining,
          technical_debt: :increasing
        },
        predictions: %{
          users_in_6_months: 2_000_000,
          infrastructure_needs: %{
            compute: 2.5,  # 2.5x current
            storage: 3.0,  # 3x current
            bandwidth: 2.2 # 2.2x current
          }
        }
      }
      
      aggregator = StrategicAggregator.new(
        decision_support: true,
        risk_assessment: true,
        recommendation_horizon: 6  # months
      )
      
      recommendations = StrategicAggregator.generate_strategic_recommendations(
        aggregator,
        system_analysis
      )
      
      # Should identify strategic priorities
      assert recommendations.priorities != []
      assert hd(recommendations.priorities).category == :infrastructure_scaling
      assert hd(recommendations.priorities).urgency == :high
      
      # Should provide specific actions
      assert length(recommendations.action_items) > 0
      
      scaling_action = Enum.find(recommendations.action_items, fn action ->
        action.type == :infrastructure_scaling
      end)
      
      assert scaling_action != nil
      assert scaling_action.timeline == "1-2 months"
      assert scaling_action.estimated_cost > 0
      assert scaling_action.expected_roi > 1.5
      
      # Should assess risks
      assert recommendations.risk_assessment.primary_risks != []
      assert Enum.any?(recommendations.risk_assessment.primary_risks, fn risk ->
        risk.type == :capacity_shortage
      end)
      
      # Should provide success metrics
      assert recommendations.success_metrics != []
      assert Enum.any?(recommendations.success_metrics, fn metric ->
        metric.name == :cost_per_user and metric.target < 0.05
      end)
    end
  end
  
  describe "S5 preparation" do
    test "prepares executive-level insights for S5" do
      # Aggregated strategic data
      strategic_data = %{
        time_period: "Q1 2024",
        kpis: %{
          revenue_growth: 0.25,
          user_retention: 0.85,
          system_reliability: 0.999,
          cost_efficiency: 0.78
        },
        trends: %{
          market_position: :strengthening,
          competitive_landscape: :intensifying,
          technology_debt: :manageable
        },
        opportunities: [
          %{type: :new_market, potential_revenue: 5_000_000, confidence: 0.7},
          %{type: :cost_optimization, potential_savings: 500_000, confidence: 0.9}
        ],
        risks: [
          %{type: :competitor_threat, impact: :high, probability: 0.6},
          %{type: :technology_obsolescence, impact: :medium, probability: 0.3}
        ]
      }
      
      aggregator = StrategicAggregator.new(
        executive_summary: true,
        visualization_ready: true
      )
      
      executive_brief = StrategicAggregator.prepare_executive_summary(
        aggregator,
        strategic_data
      )
      
      # Should provide high-level summary
      assert executive_brief.summary != nil
      assert String.length(executive_brief.summary) < 500  # Concise
      
      # Should highlight key metrics
      assert executive_brief.key_metrics != []
      assert length(executive_brief.key_metrics) <= 5  # Only most important
      
      # Should provide strategic options
      assert executive_brief.strategic_options != []
      assert Enum.all?(executive_brief.strategic_options, fn option ->
        option.description != nil and
        option.pros != [] and
        option.cons != [] and
        option.recommendation != nil
      end)
      
      # Should be visualization-ready
      assert executive_brief.dashboard_data != nil
      assert Map.has_key?(executive_brief.dashboard_data, :charts)
      assert Map.has_key?(executive_brief.dashboard_data, :scorecards)
    end
  end
  
  describe "performance and scalability" do
    test "efficiently processes large-scale strategic data" do
      # Generate 1 year of daily metrics for 100 services
      large_dataset = for day <- 0..364, service <- 1..100 do
        %{
          date: Date.add(~D[2023-01-01], day),
          service_id: "service_#{service}",
          metrics: %{
            requests: :rand.uniform() * 10000,
            errors: :rand.uniform() * 100,
            revenue: :rand.uniform() * 1000,
            cost: :rand.uniform() * 500
          }
        }
      end
      
      aggregator = StrategicAggregator.new(
        parallel_processing: true,
        sampling_strategy: :intelligent
      )
      
      {time, analysis} = :timer.tc(fn ->
        StrategicAggregator.analyze_large_scale(aggregator, large_dataset)
      end)
      
      # Should complete in reasonable time
      assert time < 5_000_000  # Less than 5 seconds for 36,500 records
      
      # Should still provide accurate insights
      assert analysis.service_rankings != nil
      assert length(analysis.service_rankings) == 100
      assert analysis.overall_trends != nil
      assert analysis.data_quality_score > 0.9
    end
  end
end