defmodule VsmPhoenix.System5.Persistence.VarietyMetricsStoreTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.System5.Persistence.VarietyMetricsStore
  
  setup do
    # Ensure VarietyMetricsStore is started fresh for each test
    case GenServer.whereis(VarietyMetricsStore) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
    
    {:ok, _pid} = VarietyMetricsStore.start_link()
    :ok
  end
  
  describe "record_variety_measurement/2" do
    test "records variety measurement for a source" do
      source = :system
      measurement = %{
        variety: 150.5,
        capacity: 200.0,
        metadata: %{
          component_count: 10,
          active_policies: 5
        }
      }
      
      assert :ok = VarietyMetricsStore.record_variety_measurement(source, measurement)
      
      {:ok, current} = VarietyMetricsStore.get_current_variety(source)
      assert current.variety == 150.5
      assert current.capacity == 200.0
      assert current.metadata.component_count == 10
    end
    
    test "creates time series entries" do
      source = :environment
      
      # Record multiple measurements
      for i <- 1..3 do
        measurement = %{variety: 100.0 + i * 10}
        :ok = VarietyMetricsStore.record_variety_measurement(source, measurement)
        Process.sleep(10)  # Ensure different timestamps
      end
      
      {:ok, history} = VarietyMetricsStore.get_variety_history(source, :hour)
      assert length(history) == 3
      assert [latest | _] = history
      assert latest.variety == 130.0  # Last measurement
    end
  end
  
  describe "calculate_variety_gap/2" do
    test "calculates variety gap correctly" do
      environmental_variety = 200.0
      system_variety = 150.0
      
      {:ok, analysis} = VarietyMetricsStore.calculate_variety_gap(
        environmental_variety, 
        system_variety
      )
      
      assert analysis.environmental_variety == 200.0
      assert analysis.system_variety == 150.0
      assert analysis.variety_gap == 50.0
      assert analysis.gap_ratio == 200.0 / 150.0
      assert analysis.requisite_variety_met == false
      assert analysis.deficit == 50.0
    end
    
    test "handles requisite variety met case" do
      environmental_variety = 100.0
      system_variety = 120.0
      
      {:ok, analysis} = VarietyMetricsStore.calculate_variety_gap(
        environmental_variety, 
        system_variety
      )
      
      assert analysis.variety_gap == -20.0
      assert analysis.requisite_variety_met == true
      assert analysis.deficit == 0
    end
  end
  
  describe "amplification and attenuation" do
    test "records variety amplification" do
      amplifier_id = "amp_test_1"
      input_variety = 100.0
      output_variety = 250.0
      
      {:ok, factor} = VarietyMetricsStore.record_amplification(
        amplifier_id, 
        input_variety, 
        output_variety
      )
      
      assert factor == 2.5
    end
    
    test "records variety attenuation" do
      attenuator_id = "att_test_1"
      input_variety = 200.0
      output_variety = 50.0
      
      {:ok, factor} = VarietyMetricsStore.record_attenuation(
        attenuator_id, 
        input_variety, 
        output_variety
      )
      
      assert factor == 0.25
    end
  end
  
  describe "analyze_variety_trends/1" do
    test "analyzes trends across sources" do
      # Create trend data
      for i <- 1..5 do
        VarietyMetricsStore.record_variety_measurement(:system, %{
          variety: 100.0 + i * 5  # Increasing trend
        })
        VarietyMetricsStore.record_variety_measurement(:environment, %{
          variety: 200.0 - i * 3  # Decreasing trend
        })
        Process.sleep(10)
      end
      
      {:ok, analysis} = VarietyMetricsStore.analyze_variety_trends(:hour)
      
      assert Map.has_key?(analysis.trends, :system)
      assert Map.has_key?(analysis.trends, :environment)
      
      system_trend = analysis.trends[:system]
      env_trend = analysis.trends[:environment]
      
      assert system_trend.trend == :increasing
      assert env_trend.trend == :decreasing
    end
    
    test "identifies critical sources" do
      # Create rapidly increasing variety
      for i <- 1..5 do
        VarietyMetricsStore.record_variety_measurement(:critical_source, %{
          variety: 100.0 * i  # Rapid increase
        })
        Process.sleep(10)
      end
      
      {:ok, analysis} = VarietyMetricsStore.analyze_variety_trends(:hour)
      
      assert :critical_source in analysis.critical_sources
    end
  end
  
  describe "get_requisite_variety_status/0" do
    test "calculates overall requisite variety status" do
      # Set up environmental and system varieties
      VarietyMetricsStore.record_variety_measurement(:environment, %{variety: 300.0})
      VarietyMetricsStore.record_variety_measurement(:external, %{variety: 100.0})
      
      VarietyMetricsStore.record_variety_measurement(:system1, %{variety: 150.0})
      VarietyMetricsStore.record_variety_measurement(:system2, %{variety: 200.0})
      
      {:ok, status} = VarietyMetricsStore.get_requisite_variety_status()
      
      assert status.environmental_variety == 400.0  # 300 + 100
      assert status.system_variety == 350.0  # 150 + 200
      assert status.variety_gap == 50.0
      assert status.requisite_variety_met == false
      assert status.coverage_ratio < 1.0
    end
  end
  
  describe "set_variety_threshold/2" do
    test "sets threshold and triggers warnings when exceeded" do
      source = :test_source
      threshold = 150.0
      
      assert :ok = VarietyMetricsStore.set_variety_threshold(source, threshold)
      
      # Record measurement below threshold - no warning
      VarietyMetricsStore.record_variety_measurement(source, %{variety: 140.0})
      
      # Record measurement above threshold - should trigger warning
      # In real implementation, this would broadcast a message
      VarietyMetricsStore.record_variety_measurement(source, %{variety: 160.0})
    end
  end
  
  describe "variety history" do
    test "retrieves variety history for different time ranges" do
      source = :history_test
      
      # Record measurements
      for i <- 1..10 do
        VarietyMetricsStore.record_variety_measurement(source, %{
          variety: 100.0 + i
        })
        Process.sleep(10)
      end
      
      {:ok, minute_history} = VarietyMetricsStore.get_variety_history(source, :minute)
      {:ok, hour_history} = VarietyMetricsStore.get_variety_history(source, :hour)
      
      assert length(minute_history) == 10
      assert length(hour_history) == 10
      assert minute_history == hour_history  # All within both ranges
    end
  end
end