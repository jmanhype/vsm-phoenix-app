defmodule VsmPhoenix.System4.Intelligence.AnalyzerTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.System4.Intelligence.Analyzer
  
  setup do
    {:ok, analyzer} = Analyzer.start_link(name: nil)
    %{analyzer: analyzer}
  end
  
  describe "analyze_scan_data/1" do
    test "analyzes scan data and returns insights", %{analyzer: analyzer} do
      scan_data = %{
        market_signals: [
          %{signal: "increased_demand", strength: 0.8, source: "sales_data"},
          %{signal: "price_pressure", strength: 0.3, source: "market_analysis"}
        ],
        technology_trends: [
          %{trend: "ai_adoption", impact: :high, timeline: "6_months"}
        ],
        regulatory_updates: [],
        competitive_moves: [
          %{competitor: "comp_a", action: "new_product", threat_level: :medium}
        ],
        timestamp: DateTime.utc_now()
      }
      
      {:ok, insights} = GenServer.call(analyzer, {:analyze_scan_data, scan_data})
      
      assert Map.has_key?(insights, :requires_adaptation)
      assert Map.has_key?(insights, :challenge)
      assert Map.has_key?(insights, :opportunities)
      assert Map.has_key?(insights, :threats)
      assert Map.has_key?(insights, :patterns)
      assert Map.has_key?(insights, :anomalies)
      
      # Should require adaptation due to high strength signal
      assert insights.requires_adaptation == true
      assert insights.challenge.type == :market_shift
    end
    
    test "does not require adaptation for low strength signals", %{analyzer: analyzer} do
      scan_data = %{
        market_signals: [
          %{signal: "small_change", strength: 0.2, source: "internal"}
        ],
        technology_trends: [],
        regulatory_updates: [],
        competitive_moves: [],
        timestamp: DateTime.utc_now()
      }
      
      {:ok, insights} = GenServer.call(analyzer, {:analyze_scan_data, scan_data})
      
      assert insights.requires_adaptation == false
      assert insights.challenge == nil
    end
  end
  
  describe "detect_anomalies/1" do
    test "detects variety explosion anomalies", %{analyzer: analyzer} do
      scan_data = %{
        llm_variety: %{
          novel_patterns: Enum.into(1..15, %{}, fn i -> {i, "pattern_#{i}"} end)
        }
      }
      
      {:ok, anomalies} = GenServer.call(analyzer, {:detect_anomalies, scan_data})
      
      variety_anomaly = Enum.find(anomalies, &(&1.type == :variety_explosion))
      assert variety_anomaly != nil
      assert variety_anomaly.recommended_action == :spawn_meta_vsm
    end
    
    test "detects market anomalies", %{analyzer: analyzer} do
      scan_data = %{
        market_signals: [
          %{signal: "extreme_demand", strength: 0.95, source: "sales_data"}
        ]
      }
      
      {:ok, anomalies} = GenServer.call(analyzer, {:detect_anomalies, scan_data})
      
      market_anomaly = Enum.find(anomalies, &(&1.type == :market_anomaly))
      assert market_anomaly != nil
      assert market_anomaly.severity == 0.95
    end
  end
  
  describe "analyze_variety_patterns/2" do
    test "analyzes variety patterns", %{analyzer: analyzer} do
      variety_data = %{
        novel_patterns: %{pattern1: "data1", pattern2: "data2"},
        recursive_potential: ["meta1", "meta2"],
        emergent_properties: %{prop1: "value1"}
      }
      
      {:ok, analysis} = GenServer.call(analyzer, {:analyze_variety_patterns, variety_data, :full})
      
      assert analysis.pattern_count == 2
      assert analysis.emergence_level == :low
      assert analysis.variety_score > 0
    end
  end
end