defmodule VsmPhoenixWeb.Phase2ApiTest do
  use VsmPhoenixWeb.ConnCase, async: true
  
  @moduletag :integration

  describe "Chaos Engineering API" do
    @chaos_experiment_params %{
      "name" => "Network Resilience Test",
      "duration" => 300,
      "fault_types" => ["latency", "timeout"],
      "target_systems" => ["s1", "s2"],
      "description" => "Testing network resilience under stress"
    }

    test "POST /api/v2/chaos/experiments creates experiment", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/chaos/experiments", @chaos_experiment_params)

      assert %{
        "success" => true,
        "experiment_id" => experiment_id,
        "message" => "Chaos experiment created successfully"
      } = json_response(conn, 201)
      
      assert is_binary(experiment_id)
    end

    test "POST /api/v2/chaos/experiments with invalid params returns error", %{conn: conn} do
      invalid_params = Map.delete(@chaos_experiment_params, "name")
      
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/chaos/experiments", invalid_params)

      assert %{
        "success" => false,
        "error" => "Invalid experiment parameters"
      } = json_response(conn, 400)
    end

    test "GET /api/v2/chaos/experiments/:id returns experiment details", %{conn: conn} do
      # First create an experiment
      create_conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/chaos/experiments", @chaos_experiment_params)
      
      %{"experiment_id" => experiment_id} = json_response(create_conn, 201)

      # Then retrieve it
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/chaos/experiments/#{experiment_id}")

      assert %{
        "success" => true,
        "experiment" => experiment
      } = json_response(conn, 200)
      
      assert experiment["id"] == experiment_id
    end

    test "POST /api/v2/chaos/faults/:type injects specific fault", %{conn: conn} do
      fault_params = %{
        "target_system" => "s1",
        "severity" => "medium",
        "duration" => 60,
        "description" => "Latency injection test"
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/chaos/faults/latency", fault_params)

      assert %{
        "success" => true,
        "fault_id" => fault_id
      } = json_response(conn, 201)
      
      assert is_binary(fault_id)
    end

    test "POST /api/v2/chaos/scenarios executes chaos scenario", %{conn: conn} do
      scenario_params = %{
        "scenario_name" => "Network Failure Cascade",
        "steps" => [
          %{"action" => "inject_fault", "target" => "s1", "fault_type" => "network_partition"},
          %{"action" => "delay", "duration" => 30},
          %{"action" => "assert_metric", "metric" => "system_resilience", "threshold" => 0.8}
        ],
        "execution_mode" => "sequential"
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/chaos/scenarios", scenario_params)

      assert %{
        "success" => true,
        "scenario_id" => scenario_id
      } = json_response(conn, 201)
      
      assert is_binary(scenario_id)
    end
  end

  describe "Quantum Logic API" do
    @superposition_params %{
      "states" => ["|0⟩", "|1⟩"],
      "amplitudes" => [0.7071, 0.7071],
      "coherence_time" => 1000,
      "description" => "Bell state superposition"
    }

    test "POST /api/v2/quantum/superposition creates quantum superposition", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/quantum/superposition", @superposition_params)

      assert %{
        "success" => true,
        "state_id" => state_id,
        "message" => "Superposition state created successfully"
      } = json_response(conn, 201)
      
      assert is_binary(state_id)
    end

    test "POST /api/v2/quantum/entangle creates quantum entanglement", %{conn: conn} do
      # First create two superposition states
      conn1 = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/quantum/superposition", @superposition_params)
      
      %{"state_id" => state_id1} = json_response(conn1, 201)

      conn2 = 
        conn
        |> put_req_header("authorization", "Bearer valid_token") 
        |> post("/api/v2/quantum/superposition", @superposition_params)
      
      %{"state_id" => state_id2} = json_response(conn2, 201)

      # Now entangle them
      entanglement_params = %{
        "state_ids" => [state_id1, state_id2],
        "entanglement_type" => "bell",
        "correlation_strength" => 1.0
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/quantum/entangle", entanglement_params)

      assert %{
        "success" => true,
        "entanglement_id" => entanglement_id
      } = json_response(conn, 201)
      
      assert is_binary(entanglement_id)
    end

    test "POST /api/v2/quantum/tunnel performs quantum tunneling", %{conn: conn} do
      tunneling_params = %{
        "barrier_height" => 5.0,
        "particle_energy" => 3.0,
        "barrier_width" => 1.0,
        "particle_mass" => 1.0
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/quantum/tunnel", tunneling_params)

      assert %{
        "success" => true,
        "tunnel_id" => tunnel_id
      } = json_response(conn, 201)
      
      assert is_binary(tunnel_id)
    end

    test "GET /api/v2/quantum/states lists quantum states", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/quantum/states")

      assert %{
        "success" => true,
        "states" => states,
        "count" => count
      } = json_response(conn, 200)
      
      assert is_list(states)
      assert is_integer(count)
    end

    test "GET /api/v2/quantum/metrics returns quantum system metrics", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/quantum/metrics")

      assert %{
        "success" => true,
        "metrics" => metrics
      } = json_response(conn, 200)
      
      assert Map.has_key?(metrics, "active_states")
      assert Map.has_key?(metrics, "coherence_time_avg")
    end
  end

  describe "Emergent Intelligence API" do
    @swarm_params %{
      "agent_count" => 100,
      "behavior_rules" => ["flock", "avoid_obstacles", "seek_food"],
      "interaction_radius" => 5.0,
      "learning_rate" => 0.1,
      "description" => "Flocking behavior swarm"
    }

    test "POST /api/v2/emergent/swarm initializes swarm intelligence", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/emergent/swarm", @swarm_params)

      assert %{
        "success" => true,
        "swarm_id" => swarm_id,
        "message" => "Swarm intelligence initialized successfully"
      } = json_response(conn, 201)
      
      assert is_binary(swarm_id)
    end

    test "GET /api/v2/emergent/patterns detects emergent patterns", %{conn: conn} do
      pattern_params = %{
        "data_source" => "swarm_behavior_logs",
        "pattern_types" => ["temporal", "spatial"],
        "confidence_threshold" => 0.7
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/emergent/patterns", pattern_params)

      assert %{
        "success" => true,
        "patterns" => patterns,
        "count" => count
      } = json_response(conn, 200)
      
      assert is_list(patterns)
      assert is_integer(count)
    end

    test "GET /api/v2/emergent/consciousness returns consciousness assessment", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/emergent/consciousness")

      assert %{
        "success" => true,
        "consciousness" => consciousness_data
      } = json_response(conn, 200)
      
      assert Map.has_key?(consciousness_data, "consciousness_level")
      assert Map.has_key?(consciousness_data, "consciousness_indicators")
    end

    test "POST /api/v2/emergent/evolve performs evolution step", %{conn: conn} do
      # First create a swarm
      create_conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/emergent/swarm", @swarm_params)
      
      %{"swarm_id" => swarm_id} = json_response(create_conn, 201)

      evolution_params = %{
        "swarm_id" => swarm_id,
        "evolution_type" => "genetic",
        "selection_pressure" => 1.5,
        "mutation_rate" => 0.1,
        "generations" => 10
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/emergent/evolve", evolution_params)

      assert %{
        "success" => true,
        "evolution_id" => evolution_id
      } = json_response(conn, 201)
      
      assert is_binary(evolution_id)
    end
  end

  describe "Meta-VSM API" do
    @spawn_params %{
      "genetic_template" => %{
        "traits" => ["adaptive", "resilient"],
        "capabilities" => ["learning", "self_repair"]
      },
      "recursion_depth" => 2,
      "autonomous_behavior" => true,
      "description" => "Adaptive recursive VSM"
    }

    test "POST /api/v2/meta-vsm/spawn creates recursive VSM", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")  # Enterprise required
        |> post("/api/v2/meta-vsm/spawn", @spawn_params)

      assert %{
        "success" => true,
        "meta_vsm_id" => vsm_id,
        "message" => "Recursive VSM spawned successfully"
      } = json_response(conn, 201)
      
      assert is_binary(vsm_id)
    end

    test "GET /api/v2/meta-vsm/hierarchy returns VSM hierarchy", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")
        |> get("/api/v2/meta-vsm/hierarchy")

      assert %{
        "success" => true,
        "hierarchy" => hierarchy
      } = json_response(conn, 200)
      
      assert is_map(hierarchy)
    end

    test "GET /api/v2/meta-vsm/lineage returns VSM lineage", %{conn: conn} do
      # First create a VSM
      create_conn = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")
        |> post("/api/v2/meta-vsm/spawn", @spawn_params)
      
      %{"meta_vsm_id" => vsm_id} = json_response(create_conn, 201)

      conn = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")
        |> get("/api/v2/meta-vsm/lineage?vsm_id=#{vsm_id}")

      assert %{
        "success" => true,
        "lineage" => lineage,
        "vsm_id" => ^vsm_id
      } = json_response(conn, 200)
      
      assert is_map(lineage)
    end

    test "POST /api/v2/meta-vsm/merge merges VSM instances", %{conn: conn} do
      # Create two VSMs first
      create_conn1 = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")
        |> post("/api/v2/meta-vsm/spawn", @spawn_params)
      
      %{"meta_vsm_id" => vsm_id1} = json_response(create_conn1, 201)

      create_conn2 = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")
        |> post("/api/v2/meta-vsm/spawn", @spawn_params)
      
      %{"meta_vsm_id" => vsm_id2} = json_response(create_conn2, 201)

      merge_params = %{
        "source_vsms" => [vsm_id1, vsm_id2],
        "merge_strategy" => "genetic_crossover",
        "preserve_individuality" => false,
        "name" => "Merged Adaptive VSM"
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer ent_valid_token")
        |> post("/api/v2/meta-vsm/merge", merge_params)

      assert %{
        "success" => true,
        "merged_vsm_id" => merged_id
      } = json_response(conn, 201)
      
      assert is_binary(merged_id)
    end
  end

  describe "Algedonic System API" do
    @pain_signal_params %{
      "source_system" => "s1",
      "severity" => "high",
      "description" => "Resource depletion detected",
      "pain_type" => "resource_exhaustion"
    }

    @pleasure_signal_params %{
      "source_system" => "s2",
      "intensity" => "high",
      "reward_context" => "successful_adaptation",
      "behavior_to_reinforce" => "efficient_resource_usage"
    }

    test "POST /api/v2/algedonic/pain sends pain signal", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/algedonic/pain", @pain_signal_params)

      assert %{
        "success" => true,
        "signal_id" => signal_id,
        "message" => "Pain signal sent successfully"
      } = json_response(conn, 201)
      
      assert is_binary(signal_id)
    end

    test "POST /api/v2/algedonic/pleasure sends pleasure signal", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/algedonic/pleasure", @pleasure_signal_params)

      assert %{
        "success" => true,
        "signal_id" => signal_id,
        "message" => "Pleasure signal sent successfully"
      } = json_response(conn, 201)
      
      assert is_binary(signal_id)
    end

    test "GET /api/v2/algedonic/autonomic returns autonomic responses", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/algedonic/autonomic")

      assert %{
        "success" => true,
        "autonomic_responses" => responses,
        "count" => count
      } = json_response(conn, 200)
      
      assert is_list(responses)
      assert is_integer(count)
    end

    test "POST /api/v2/algedonic/bypass creates S1→S5 bypass", %{conn: conn} do
      bypass_params = %{
        "bypass_type" => "emergency",
        "priority" => "critical",
        "urgency_level" => "immediate",
        "duration" => 300,
        "description" => "Emergency system failure bypass"
      }

      conn = 
        conn
        |> put_req_header("authorization", "Bearer sys_admin_token")  # System admin required
        |> post("/api/v2/algedonic/bypass", bypass_params)

      assert %{
        "success" => true,
        "bypass_id" => bypass_id,
        "message" => "S1→S5 algedonic bypass established successfully"
      } = json_response(conn, 201)
      
      assert is_binary(bypass_id)
    end
  end

  describe "Authentication and Authorization" do
    test "requests without authentication return 401", %{conn: conn} do
      conn = post(conn, "/api/v2/chaos/experiments", %{})

      assert %{
        "error" => "Authentication required"
      } = json_response(conn, 401)
    end

    test "requests with invalid token return 401", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> post("/api/v2/chaos/experiments", %{})

      assert %{
        "error" => "Invalid authentication token"
      } = json_response(conn, 401)
    end

    test "enterprise endpoints require enterprise auth", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer standard_token")
        |> post("/api/v2/meta-vsm/spawn", @spawn_params)

      assert %{
        "error" => "Insufficient permissions"
      } = json_response(conn, 401)
    end
  end

  describe "Rate Limiting" do
    test "rate limiting headers are present", %{conn: conn} do
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/quantum/states")

      json_response(conn, 200)
      
      assert get_resp_header(conn, "x-rate-limit-limit") != []
      assert get_resp_header(conn, "x-rate-limit-remaining") != []
      assert get_resp_header(conn, "x-rate-limit-reset") != []
    end
  end

  describe "Error Handling" do
    test "validation errors return structured response", %{conn: conn} do
      invalid_params = %{"invalid" => "data"}
      
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> post("/api/v2/chaos/experiments", invalid_params)

      assert %{
        "success" => false,
        "error" => _error_message,
        "timestamp" => _timestamp
      } = json_response(conn, 400)
    end

    test "system errors return proper error response", %{conn: conn} do
      # This would trigger a system error in a real scenario
      conn = 
        conn
        |> put_req_header("authorization", "Bearer valid_token")
        |> get("/api/v2/nonexistent/endpoint")

      assert json_response(conn, 404)
    end
  end

  # Helper functions for test setup
  defp valid_jwt_token do
    # In real tests, this would create a valid JWT token
    "valid_test_token"
  end

  defp enterprise_jwt_token do
    # In real tests, this would create an enterprise-level JWT token
    "enterprise_test_token"
  end
end