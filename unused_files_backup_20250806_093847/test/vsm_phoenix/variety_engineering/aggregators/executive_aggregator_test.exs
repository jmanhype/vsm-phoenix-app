defmodule VsmPhoenix.VarietyEngineering.Aggregators.ExecutiveAggregatorTest do
  @moduledoc """
  Test suite for Executive Aggregator (S4→S5).
  Tests executive summaries, KPI aggregation, and decision support preparation.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Aggregators.ExecutiveAggregator
  
  describe "executive dashboard preparation" do
    test "creates comprehensive executive dashboard" do
      # Multi-level metrics from S4
      s4_data = %{
        timestamp: ~U[2024-01-15 00:00:00Z],
        period: "2024-Q1",
        business_metrics: %{
          revenue: %{
            total: 5_000_000,
            growth_rate: 0.25,
            by_region: %{
              "north_america" => 2_500_000,
              "europe" => 1_500_000,
              "asia" => 1_000_000
            }
          },
          users: %{
            total: 1_000_000,
            active: 650_000,
            new_this_quarter: 150_000,
            churn_rate: 0.05
          },
          costs: %{
            infrastructure: 500_000,
            personnel: 1_500_000,
            marketing: 300_000
          }
        },
        operational_metrics: %{
          system_reliability: 0.9995,
          average_response_time: 150,  # ms
          error_rate: 0.001,
          deployment_frequency: 25  # per month
        },
        strategic_indicators: %{
          market_share: 0.15,
          customer_satisfaction: 4.5,  # out of 5
          employee_satisfaction: 4.2,
          innovation_index: 0.75
        }
      }
      
      aggregator = ExecutiveAggregator.new(
        dashboard_type: :comprehensive,
        visualizations: [:kpi_cards, :trend_charts, :heat_maps]
      )
      
      dashboard = ExecutiveAggregator.create_dashboard(aggregator, s4_data)
      
      # Should have KPI cards
      assert length(dashboard.kpi_cards) >= 6
      
      revenue_card = Enum.find(dashboard.kpi_cards, &(&1.metric == :revenue))
      assert revenue_card.value == "$5.0M"
      assert revenue_card.change == "+25%"
      assert revenue_card.status == :positive
      
      # Should have trend visualizations
      assert dashboard.trend_charts.revenue != nil
      assert dashboard.trend_charts.user_growth != nil
      
      # Should have regional heat map
      assert dashboard.heat_maps.revenue_by_region != nil
      assert dashboard.heat_maps.revenue_by_region.highest == "north_america"
      
      # Should include health indicators
      assert dashboard.health_score > 0.8
      assert dashboard.risk_indicators == []  # No major risks
    end
    
    test "generates focused executive briefings" do
      metrics_history = for month <- 1..12 do
        %{
          month: month,
          revenue: 400_000 + month * 20_000 + :rand.uniform() * 50_000,
          costs: 300_000 + month * 5_000 + :rand.uniform() * 20_000,
          users: 80_000 + month * 5_000 + :rand.uniform() * 2_000,
          nps_score: 40 + :rand.uniform() * 20  # Net Promoter Score
        }
      end
      
      current_issues = [
        %{type: :cost_overrun, department: "engineering", impact: 50_000},
        %{type: :customer_complaints, category: "performance", count: 150}
      ]
      
      aggregator = ExecutiveAggregator.new(
        briefing_style: :exception_based,
        max_items: 5
      )
      
      briefing = ExecutiveAggregator.generate_briefing(
        aggregator,
        metrics_history,
        current_issues
      )
      
      # Should highlight exceptions
      assert length(briefing.key_points) <= 5
      assert Enum.any?(briefing.key_points, &(&1.type == :cost_overrun))
      
      # Should show trend summary
      assert briefing.trends.revenue == :growing
      assert briefing.trends.profitability == :improving
      
      # Should provide recommendations
      assert length(briefing.recommended_actions) > 0
      assert Enum.any?(briefing.recommended_actions, fn action ->
        action.category == :cost_control
      end)
    end
  end
  
  describe "KPI aggregation and scoring" do
    test "calculates balanced scorecard metrics" do
      quarterly_data = %{
        financial: %{
          revenue_growth: 0.20,
          profit_margin: 0.15,
          cash_flow: 2_000_000,
          roi: 1.25
        },
        customer: %{
          satisfaction_score: 4.3,
          retention_rate: 0.90,
          acquisition_cost: 150,
          lifetime_value: 2000
        },
        internal_process: %{
          cycle_time: 5,  # days
          defect_rate: 0.02,
          automation_level: 0.65,
          innovation_rate: 0.30
        },
        learning_growth: %{
          employee_retention: 0.85,
          training_hours: 40,
          skill_coverage: 0.80,
          knowledge_sharing_index: 0.70
        }
      }
      
      aggregator = ExecutiveAggregator.new(
        scorecard_enabled: true,
        weighting: %{
          financial: 0.30,
          customer: 0.30,
          internal_process: 0.20,
          learning_growth: 0.20
        }
      )
      
      scorecard = ExecutiveAggregator.calculate_balanced_scorecard(
        aggregator,
        quarterly_data
      )
      
      # Should calculate perspective scores
      assert scorecard.perspectives.financial.score > 0.7
      assert scorecard.perspectives.customer.score > 0.8
      assert scorecard.perspectives.internal_process.score > 0.6
      assert scorecard.perspectives.learning_growth.score > 0.7
      
      # Should provide overall score
      assert scorecard.overall_score > 0.7
      assert scorecard.overall_rating == :good
      
      # Should identify strengths and weaknesses
      assert scorecard.strengths == [:customer, :financial]
      assert scorecard.improvement_areas == [:internal_process]
    end
    
    test "tracks KPI trends and trajectories" do
      # 12 months of KPI data
      kpi_history = for month <- 1..12 do
        %{
          month: month,
          kpis: %{
            revenue_per_employee: 50_000 + month * 1_000,
            customer_acquisition_cost: 200 - month * 5,
            time_to_market: 30 - month * 0.5,  # days
            system_uptime: 0.995 + :rand.uniform() * 0.004
          }
        }
      end
      
      targets = %{
        revenue_per_employee: 65_000,
        customer_acquisition_cost: 150,
        time_to_market: 20,
        system_uptime: 0.999
      }
      
      aggregator = ExecutiveAggregator.new(
        trend_analysis: true,
        projection_months: 6
      )
      
      kpi_analysis = ExecutiveAggregator.analyze_kpi_trends(
        aggregator,
        kpi_history,
        targets
      )
      
      # Should identify trajectory toward targets
      assert kpi_analysis.on_track_kpis == [
        :revenue_per_employee,
        :customer_acquisition_cost,
        :time_to_market
      ]
      
      assert kpi_analysis.at_risk_kpis == [:system_uptime]
      
      # Should project achievement dates
      assert kpi_analysis.target_achievement.revenue_per_employee.months_to_target < 6
      assert kpi_analysis.target_achievement.customer_acquisition_cost.will_achieve == true
      
      # Should provide improvement recommendations
      uptime_recommendation = Enum.find(
        kpi_analysis.recommendations,
        &(&1.kpi == :system_uptime)
      )
      assert uptime_recommendation != nil
      assert uptime_recommendation.action =~ "reliability"
    end
  end
  
  describe "strategic alerts and notifications" do
    test "generates executive alerts for critical changes" do
      previous_period = %{
        revenue: 1_000_000,
        costs: 800_000,
        customer_satisfaction: 4.2,
        market_share: 0.15
      }
      
      current_period = %{
        revenue: 950_000,      # 5% decrease
        costs: 850_000,        # 6.25% increase
        customer_satisfaction: 3.8,  # Significant drop
        market_share: 0.14     # Lost market share
      }
      
      thresholds = %{
        revenue_change: 0.03,         # Alert if > 3% change
        cost_change: 0.05,           # Alert if > 5% change
        satisfaction_change: 0.2,     # Alert if > 0.2 point change
        market_share_change: 0.005    # Alert if > 0.5% change
      }
      
      aggregator = ExecutiveAggregator.new(
        alert_thresholds: thresholds,
        alert_severity_levels: [:info, :warning, :critical]
      )
      
      alerts = ExecutiveAggregator.generate_alerts(
        aggregator,
        previous_period,
        current_period
      )
      
      # Should generate multiple alerts
      assert length(alerts) >= 3
      
      # Revenue decrease alert
      revenue_alert = Enum.find(alerts, &(&1.metric == :revenue))
      assert revenue_alert.severity == :critical
      assert revenue_alert.change_percentage == -5.0
      
      # Customer satisfaction alert
      satisfaction_alert = Enum.find(alerts, &(&1.metric == :customer_satisfaction))
      assert satisfaction_alert.severity == :critical
      assert satisfaction_alert.impact_assessment =~ "retention"
      
      # Should prioritize alerts
      assert hd(alerts).metric == :customer_satisfaction  # Most critical
    end
  end
  
  describe "board meeting preparation" do
    test "prepares comprehensive board package" do
      quarterly_results = %{
        financials: %{
          revenue: 5_000_000,
          ebitda: 1_000_000,
          cash_position: 10_000_000,
          burn_rate: 400_000
        },
        key_achievements: [
          "Launched product in 3 new markets",
          "Achieved SOC2 compliance",
          "Reduced customer churn by 25%"
        ],
        challenges: [
          "Increased competition in core market",
          "Supply chain disruptions",
          "Talent acquisition in engineering"
        ],
        strategic_initiatives: [
          %{
            name: "International expansion",
            status: :on_track,
            completion: 0.60,
            budget_used: 0.55
          },
          %{
            name: "Platform modernization",
            status: :at_risk,
            completion: 0.40,
            budget_used: 0.65
          }
        ]
      }
      
      aggregator = ExecutiveAggregator.new(
        board_package: true,
        include_sections: [
          :executive_summary,
          :financial_performance,
          :strategic_progress,
          :risk_assessment,
          :forward_outlook
        ]
      )
      
      board_package = ExecutiveAggregator.prepare_board_package(
        aggregator,
        quarterly_results
      )
      
      # Should have executive summary
      assert board_package.executive_summary != nil
      assert String.length(board_package.executive_summary) < 1000
      assert board_package.executive_summary =~ "revenue"
      
      # Should have financial section
      assert board_package.financial_performance.revenue_analysis != nil
      assert board_package.financial_performance.runway_months == 25
      
      # Should track strategic initiatives
      assert length(board_package.strategic_progress.initiatives) == 2
      at_risk = Enum.find(
        board_package.strategic_progress.initiatives,
        &(&1.status == :at_risk)
      )
      assert at_risk.mitigation_plan != nil
      
      # Should include forward-looking statements
      assert board_package.forward_outlook.next_quarter_priorities != []
      assert board_package.forward_outlook.growth_projections != nil
    end
  end
  
  describe "competitive intelligence aggregation" do
    test "aggregates competitive landscape analysis" do
      market_data = %{
        our_metrics: %{
          market_share: 0.15,
          growth_rate: 0.25,
          customer_satisfaction: 4.3,
          pricing_index: 1.0  # Baseline
        },
        competitors: [
          %{
            name: "Competitor A",
            market_share: 0.30,
            growth_rate: 0.15,
            customer_satisfaction: 4.1,
            pricing_index: 0.9,
            recent_moves: ["Acquired startup X", "Launched feature Y"]
          },
          %{
            name: "Competitor B",
            market_share: 0.20,
            growth_rate: 0.35,
            customer_satisfaction: 4.4,
            pricing_index: 1.1,
            recent_moves: ["Expanded to Asia", "Raised $50M funding"]
          }
        ],
        market_trends: [
          "Shift toward subscription pricing",
          "Increased demand for AI features",
          "Consolidation among smaller players"
        ]
      }
      
      aggregator = ExecutiveAggregator.new(
        competitive_analysis: true,
        swot_enabled: true
      )
      
      competitive_intel = ExecutiveAggregator.analyze_competitive_landscape(
        aggregator,
        market_data
      )
      
      # Should provide positioning analysis
      assert competitive_intel.market_position == :challenger
      assert competitive_intel.competitive_advantages == [:growth_rate, :pricing]
      assert competitive_intel.competitive_gaps == [:market_share, :customer_satisfaction]
      
      # Should identify threats and opportunities
      assert Enum.any?(competitive_intel.threats, &(&1.source == "Competitor B"))
      assert Enum.any?(competitive_intel.opportunities, &(&1.type == :market_trend))
      
      # Should provide strategic recommendations
      assert length(competitive_intel.strategic_options) > 0
      assert Enum.any?(competitive_intel.strategic_options, fn option ->
        option.type == :differentiation
      end)
    end
  end
  
  describe "decision support matrices" do
    test "creates decision support matrix for strategic choices" do
      strategic_options = [
        %{
          id: :expand_internationally,
          investment_required: 2_000_000,
          time_to_implement: 12,  # months
          expected_roi: 2.5,
          risk_level: :high,
          strategic_fit: 0.85
        },
        %{
          id: :acquire_competitor,
          investment_required: 5_000_000,
          time_to_implement: 6,
          expected_roi: 1.8,
          risk_level: :very_high,
          strategic_fit: 0.70
        },
        %{
          id: :develop_new_product,
          investment_required: 1_000_000,
          time_to_implement: 9,
          expected_roi: 3.0,
          risk_level: :medium,
          strategic_fit: 0.90
        }
      ]
      
      constraints = %{
        max_investment: 3_000_000,
        max_risk_tolerance: :high,
        min_roi: 1.5,
        time_horizon: 18  # months
      }
      
      aggregator = ExecutiveAggregator.new(
        decision_matrix: true,
        scoring_method: :weighted
      )
      
      decision_matrix = ExecutiveAggregator.create_decision_matrix(
        aggregator,
        strategic_options,
        constraints
      )
      
      # Should evaluate all options
      assert length(decision_matrix.evaluated_options) == 3
      
      # Should rank options
      assert hd(decision_matrix.ranked_options).id == :develop_new_product
      assert decision_matrix.ranked_options |> Enum.at(1) |> Map.get(:id) == :expand_internationally
      
      # Should identify constraint violations
      assert decision_matrix.infeasible_options == [:acquire_competitor]
      assert decision_matrix.infeasibility_reasons.acquire_competitor == [
        :exceeds_budget,
        :exceeds_risk_tolerance
      ]
      
      # Should provide recommendation
      assert decision_matrix.recommendation.primary_choice == :develop_new_product
      assert decision_matrix.recommendation.rationale =~ "ROI"
    end
  end
  
  describe "real-time executive monitoring" do
    test "provides real-time business health monitoring" do
      real_time_metrics = %{
        timestamp: ~U[2024-01-15 14:30:00Z],
        current_values: %{
          active_users: 45_234,
          transactions_per_minute: 892,
          revenue_run_rate: 156_000,  # daily
          system_load: 0.72,
          error_rate: 0.0012
        },
        baselines: %{
          active_users: 42_000,
          transactions_per_minute: 850,
          revenue_run_rate: 150_000,
          system_load: 0.65,
          error_rate: 0.0010
        },
        thresholds: %{
          active_users: %{min: 35_000, max: 60_000},
          transactions_per_minute: %{min: 500, max: 1_500},
          revenue_run_rate: %{min: 120_000, max: 200_000},
          system_load: %{min: 0.0, max: 0.85},
          error_rate: %{min: 0.0, max: 0.005}
        }
      }
      
      aggregator = ExecutiveAggregator.new(
        real_time_monitoring: true,
        alert_channels: [:dashboard, :mobile, :email]
      )
      
      health_status = ExecutiveAggregator.monitor_business_health(
        aggregator,
        real_time_metrics
      )
      
      # Should calculate health score
      assert health_status.overall_health > 0.8
      assert health_status.status == :healthy
      
      # Should identify positive trends
      assert health_status.positive_indicators == [
        :active_users,
        :revenue_run_rate
      ]
      
      # Should monitor system stress
      assert health_status.stress_indicators.system_load == :elevated
      assert health_status.capacity_remaining.system_load < 0.2
      
      # Should provide pulse summary
      assert health_status.executive_pulse =~ "performing well"
      assert health_status.attention_needed == []
    end
  end
  
  describe "executive communication optimization" do
    test "optimizes message delivery for executive consumption" do
      raw_insights = [
        %{
          source: :financial_analysis,
          finding: "Revenue grew 23% YoY driven primarily by expansion in enterprise segment",
          confidence: 0.95,
          impact: :high
        },
        %{
          source: :operational_metrics,
          finding: "System reliability improved to 99.95% uptime",
          confidence: 0.99,
          impact: :medium
        },
        %{
          source: :market_research,
          finding: "Competitor X is planning major product launch in Q2",
          confidence: 0.75,
          impact: :high
        },
        %{
          source: :customer_analytics,
          finding: "NPS score increased by 15 points to 72",
          confidence: 0.90,
          impact: :medium
        },
        %{
          source: :technical_metrics,
          finding: "Database query performance improved by 40%",
          confidence: 0.98,
          impact: :low
        }
      ]
      
      executive_preferences = %{
        max_items: 3,
        preferred_topics: [:revenue, :competition, :customer],
        detail_level: :summary,
        include_actions: true
      }
      
      aggregator = ExecutiveAggregator.new(
        message_optimization: true,
        personalization: executive_preferences
      )
      
      optimized_brief = ExecutiveAggregator.optimize_executive_communication(
        aggregator,
        raw_insights
      )
      
      # Should select most relevant insights
      assert length(optimized_brief.key_insights) == 3
      assert Enum.all?(optimized_brief.key_insights, &(&1.impact == :high))
      
      # Should format for executive consumption
      assert Enum.all?(optimized_brief.key_insights, fn insight ->
        String.length(insight.summary) < 100
      end)
      
      # Should include actionable items
      assert optimized_brief.recommended_actions != []
      assert Enum.any?(optimized_brief.recommended_actions, &(&1.topic == :competition))
      
      # Should provide one-line summary
      assert optimized_brief.headline =~ "Revenue growth"
      assert String.length(optimized_brief.headline) < 80
    end
  end
  
  describe "performance" do
    test "handles large-scale executive data efficiently" do
      # Generate comprehensive business data
      large_dataset = %{
        daily_metrics: for(d <- 1..365, do: {d, :rand.uniform() * 100_000}),
        customer_segments: for(s <- 1..50, do: {s, :rand.uniform() * 10_000}),
        product_lines: for(p <- 1..20, do: {p, :rand.uniform() * 500_000}),
        regional_data: for(r <- 1..15, do: {r, :rand.uniform() * 1_000_000})
      }
      
      aggregator = ExecutiveAggregator.new(
        performance_mode: true,
        caching_enabled: true
      )
      
      {time, summary} = :timer.tc(fn ->
        ExecutiveAggregator.process_comprehensive_data(aggregator, large_dataset)
      end)
      
      # Should complete quickly despite data volume
      assert time < 1_000_000  # Under 1 second
      
      # Should provide complete summary
      assert summary.annual_revenue != nil
      assert summary.top_segments != []
      assert summary.regional_performance != nil
      
      # Should maintain executive-level abstraction
      assert map_size(summary) < 20  # Concise output
    end
  end
end