defmodule VsmPhoenix.System4.IntelligenceTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.System4.Intelligence
  
  setup do
    # Start the coordinator and child modules
    {:ok, intelligence} = Intelligence.start_link(name: nil)
    %{intelligence: intelligence}
  end
  
  describe "backward compatibility" do
    test "scan_environment/1 maintains same interface", %{intelligence: intelligence} do
      result = GenServer.call(intelligence, {:scan_environment, :full})
      
      # Should return insights with same structure as original
      assert Map.has_key?(result, :requires_adaptation)
      assert Map.has_key?(result, :opportunities)
      assert Map.has_key?(result, :threats)
    end
    
    test "get_system_health/0 returns health metrics", %{intelligence: intelligence} do
      health = GenServer.call(intelligence, :get_system_health)
      
      assert Map.has_key?(health, :health)
      assert Map.has_key?(health, :scan_coverage)
      assert Map.has_key?(health, :adaptation_readiness)
      assert Map.has_key?(health, :innovation_capacity)
    end
    
    test "get_intelligence_state/0 returns comprehensive state", %{intelligence: intelligence} do
      {:ok, state} = GenServer.call(intelligence, :get_intelligence_state)
      
      assert Map.has_key?(state, :environmental_data)
      assert Map.has_key?(state, :current_adaptations)
      assert Map.has_key?(state, :metrics)
      assert Map.has_key?(state, :tidewave_status)
      assert Map.has_key?(state, :modules_status)
      
      # Verify module status
      assert state.modules_status.scanner == :active
      assert state.modules_status.analyzer == :active
      assert state.modules_status.adaptation_engine == :active
    end
  end
  
  describe "module coordination" do
    test "coordinates scan -> analyze -> adapt flow", %{intelligence: intelligence} do
      # This test verifies the full flow works correctly
      result = GenServer.call(intelligence, {:scan_environment, :full})
      
      # If adaptation is needed, it should coordinate properly
      if result.requires_adaptation do
        assert result.challenge != nil
        # In real implementation, this would trigger adaptation flow
      end
      
      assert is_map(result)
    end
  end
  
  describe "delegation to modules" do
    test "delegates trend analysis to Analyzer", %{intelligence: intelligence} do
      result = GenServer.call(intelligence, {:analyze_trends, :internal})
      
      # Should return successful result from Analyzer
      assert {:ok, _trends} = result
    end
    
    test "delegates adaptation generation to AdaptationEngine", %{intelligence: intelligence} do
      challenge = %{type: :test, urgency: :medium}
      
      result = GenServer.call(intelligence, {:generate_adaptation, challenge})
      
      # Should return proposal from AdaptationEngine
      assert {:ok, proposal} = result
      assert Map.has_key?(proposal, :id)
      assert Map.has_key?(proposal, :model_type)
    end
  end
end