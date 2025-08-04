defmodule VsmPhoenixWeb.Phase2.QuantumControllerTest do
  use VsmPhoenixWeb.ConnCase
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.QuantumVariety.QuantumVarietyManager
  alias VsmPhoenix.QuantumVariety.QuantumState
  
  setup do
    conn = build_conn()
    |> put_req_header("authorization", "Bearer test-token")
    |> put_req_header("content-type", "application/json")
    
    {:ok, conn: conn}
  end
  
  describe "Quantum Variety endpoints" do
    test "POST /api/quantum/entangle creates quantum entanglement", %{conn: conn} do
      entangle_request = %{
        "systems" => ["system1", "system4", "system5"],
        "entanglement_type" => "variety_coupling",
        "strength" => 0.8
      }
      
      conn = post(conn, "/api/quantum/entangle", entangle_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["entanglement_id"]
      assert response["systems"] == ["system1", "system4", "system5"]
      assert response["quantum_state"]["coherence"] >= 0.0
      assert response["quantum_state"]["entropy"]
    end
    
    test "GET /api/quantum/state/:system_id returns quantum state", %{conn: conn} do
      system_id = "system1"
      conn = get(conn, "/api/quantum/state/#{system_id}")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["system_id"] == system_id
      assert state = response["quantum_state"]
      assert state["amplitude"]
      assert state["phase"]
      assert state["coherence"] >= 0.0 and state["coherence"] <= 1.0
      assert state["entanglements"]
    end
    
    test "POST /api/quantum/tunnel creates quantum tunnel", %{conn: conn} do
      tunnel_request = %{
        "source_system" => "system1",
        "target_system" => "system5",
        "variety_data" => %{
          "complexity" => 0.7,
          "entropy" => 2.1,
          "patterns" => ["pattern1", "pattern2"]
        }
      }
      
      conn = post(conn, "/api/quantum/tunnel", tunnel_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["tunnel_id"]
      assert response["transmission_probability"] >= 0.0
      assert response["transmission_probability"] <= 1.0
      assert response["variety_preserved"]
    end
    
    test "POST /api/quantum/superposition creates superposition state", %{conn: conn} do
      superposition_request = %{
        "states" => [
          %{"system" => "system1", "amplitude" => 0.6, "phase" => 0.0},
          %{"system" => "system4", "amplitude" => 0.8, "phase" => 1.57}
        ],
        "normalization" => true
      }
      
      conn = post(conn, "/api/quantum/superposition", superposition_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["superposition_id"]
      assert response["normalized"] == true
      assert response["total_probability"] == 1.0
    end
    
    test "POST /api/quantum/measure performs quantum measurement", %{conn: conn} do
      measure_request = %{
        "system_id" => "system1",
        "observable" => "variety_magnitude",
        "basis" => "computational"
      }
      
      conn = post(conn, "/api/quantum/measure", measure_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["measurement_result"]
      assert response["collapse_probability"] >= 0.0
      assert response["post_measurement_state"]
    end
    
    test "GET /api/quantum/entanglements lists active entanglements", %{conn: conn} do
      conn = get(conn, "/api/quantum/entanglements")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert entanglements = response["entanglements"]
      assert is_list(entanglements)
      
      if length(entanglements) > 0 do
        first_entanglement = List.first(entanglements)
        assert first_entanglement["id"]
        assert first_entanglement["systems"]
        assert first_entanglement["strength"]
        assert first_entanglement["created_at"]
      end
    end
    
    test "DELETE /api/quantum/entanglement/:id breaks entanglement", %{conn: conn} do
      # First create an entanglement
      entangle_request = %{
        "systems" => ["system1", "system4"],
        "entanglement_type" => "test",
        "strength" => 0.5
      }
      
      create_conn = post(conn, "/api/quantum/entangle", entangle_request)
      create_response = json_response(create_conn, 200)
      entanglement_id = create_response["entanglement_id"]
      
      # Then break it
      conn = delete(conn, "/api/quantum/entanglement/#{entanglement_id}")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["disentangled"] == true
    end
  end
  
  describe "Quantum error handling" do
    test "invalid system IDs return error", %{conn: conn} do
      conn = get(conn, "/api/quantum/state/invalid_system")
      
      assert response = json_response(conn, 404)
      assert response["error"] == "system_not_found"
    end
    
    test "invalid entanglement parameters return error", %{conn: conn} do
      invalid_request = %{
        "systems" => ["system1"], # Need at least 2 systems
        "strength" => 1.5 # Invalid strength > 1.0
      }
      
      conn = post(conn, "/api/quantum/entangle", invalid_request)
      
      assert response = json_response(conn, 400)
      assert response["error"] in ["insufficient_systems", "invalid_strength"]
    end
    
    test "quantum decoherence handling", %{conn: conn} do
      # Test decoherence effects on quantum states
      decoherence_request = %{
        "system_id" => "system1",
        "decoherence_rate" => 0.1,
        "time_evolution" => 10.0
      }
      
      conn = post(conn, "/api/quantum/decoherence", decoherence_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["final_coherence"] < response["initial_coherence"]
    end
  end
  
  describe "Quantum variety analysis" do
    test "POST /api/quantum/analyze performs quantum variety analysis", %{conn: conn} do
      analysis_request = %{
        "variety_data" => %{
          "patterns" => ["pattern1", "pattern2", "pattern3"],
          "complexity" => 0.8,
          "entropy" => 2.5
        },
        "analysis_type" => "quantum_superposition"
      }
      
      conn = post(conn, "/api/quantum/analyze", analysis_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert analysis = response["analysis"]
      assert analysis["quantum_complexity"]
      assert analysis["variety_coherence"]
      assert analysis["entanglement_potential"]
    end
  end
end