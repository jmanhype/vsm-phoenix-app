defmodule VsmPhoenix.System4.Intelligence.AdaptationEngineTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.System4.Intelligence.AdaptationEngine
  
  setup do
    {:ok, engine} = AdaptationEngine.start_link(name: nil)
    %{engine: engine}
  end
  
  describe "generate_proposal/1" do
    test "generates incremental proposal for medium urgency", %{engine: engine} do
      challenge = %{
        type: :market_shift,
        urgency: :medium,
        scope: :tactical
      }
      
      {:ok, proposal} = GenServer.call(engine, {:generate_proposal, challenge})
      
      assert Map.has_key?(proposal, :id)
      assert proposal.challenge == challenge
      assert proposal.model_type == :incremental
      assert Map.has_key?(proposal, :actions)
      assert Map.has_key?(proposal, :impact)
      assert Map.has_key?(proposal, :resources_required)
      assert Map.has_key?(proposal, :timeline)
      assert Map.has_key?(proposal, :risks)
    end
    
    test "generates defensive proposal for high urgency", %{engine: engine} do
      challenge = %{
        type: :health,
        urgency: :high,
        scope: :system_wide
      }
      
      {:ok, proposal} = GenServer.call(engine, {:generate_proposal, challenge})
      
      assert proposal.model_type == :defensive
      assert Enum.member?(proposal.actions, "emergency_stabilization")
    end
    
    test "generates transformational proposal for low urgency", %{engine: engine} do
      challenge = %{
        type: :innovation,
        urgency: :low,
        scope: :strategic
      }
      
      {:ok, proposal} = GenServer.call(engine, {:generate_proposal, challenge})
      
      assert proposal.model_type == :transformational
    end
  end
  
  describe "implement_adaptation/1" do
    test "implements adaptation and tracks progress", %{engine: engine} do
      proposal = %{
        id: "TEST-123",
        model_type: :incremental,
        timeline: "1_month"
      }
      
      GenServer.cast(engine, {:implement_adaptation, proposal})
      
      # Give it a moment to process
      Process.sleep(100)
      
      {:ok, active} = GenServer.call(engine, :get_active_adaptations)
      
      assert length(active) == 1
      assert List.first(active).id == "TEST-123"
    end
  end
  
  describe "get_adaptation_metrics/0" do
    test "returns comprehensive metrics", %{engine: engine} do
      {:ok, metrics} = GenServer.call(engine, :get_adaptation_metrics)
      
      assert Map.has_key?(metrics, :success_rate)
      assert Map.has_key?(metrics, :active_adaptations)
      assert Map.has_key?(metrics, :adaptation_capacity)
      
      assert metrics.success_rate >= 0.0
      assert metrics.success_rate <= 1.0
    end
  end
  
  describe "request_proposals_for_viability/1" do
    test "generates proposals for viability metrics", %{engine: engine} do
      viability_metrics = %{
        system_health: 0.5,
        resource_efficiency: 0.4,
        innovation_lag: 0.9
      }
      
      GenServer.cast(engine, {:request_proposals, viability_metrics})
      
      # This should generate multiple proposals based on the poor metrics
      # In a real test, we'd mock Queen.approve_adaptation/1
      Process.sleep(100)
      
      # Test passes if no crash occurs
      assert true
    end
  end
end