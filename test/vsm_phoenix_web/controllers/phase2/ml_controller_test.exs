defmodule VsmPhoenixWeb.Phase2.MLControllerTest do
  use VsmPhoenixWeb.ConnCase
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.EmergentIntelligence.SwarmMind
  alias VsmPhoenix.EmergentIntelligence.CollectiveLearning
  
  setup do
    conn = build_conn()
    |> put_req_header("authorization", "Bearer test-token")
    |> put_req_header("content-type", "application/json")
    
    {:ok, conn: conn}
  end
  
  describe "ML Model endpoints" do
    test "POST /api/ml/train initiates model training", %{conn: conn} do
      training_request = %{
        "model_type" => "variety_predictor",
        "training_data" => %{
          "features" => [[1.0, 2.0, 3.0], [2.0, 3.0, 4.0]],
          "labels" => [0.8, 0.9],
          "metadata" => %{"source" => "vsm_system1"}
        },
        "hyperparameters" => %{
          "learning_rate" => 0.001,
          "epochs" => 100,
          "batch_size" => 32
        }
      }
      
      conn = post(conn, "/api/ml/train", training_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "training_started"
      assert response["training_id"]
      assert response["model_type"] == "variety_predictor"
      assert response["estimated_completion"]
    end
    
    test "POST /api/ml/predict performs model inference", %{conn: conn} do
      prediction_request = %{
        "model_id" => "variety_predictor_v1",
        "input_data" => [1.5, 2.5, 3.5],
        "return_confidence" => true
      }
      
      conn = post(conn, "/api/ml/predict", prediction_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["prediction"]
      assert response["confidence"] >= 0.0 and response["confidence"] <= 1.0
      assert response["model_version"]
      assert response["inference_time"]
    end
    
    test "GET /api/ml/models lists available models", %{conn: conn} do
      conn = get(conn, "/api/ml/models")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert models = response["models"]
      assert is_list(models)
      
      if length(models) > 0 do
        first_model = List.first(models)
        assert first_model["id"]
        assert first_model["type"]
        assert first_model["status"]
        assert first_model["accuracy"]
        assert first_model["created_at"]
      end
    end
    
    test "GET /api/ml/training/:id returns training status", %{conn: conn} do
      training_id = "test_training_123"
      conn = get(conn, "/api/ml/training/#{training_id}")
      
      assert response = json_response(conn, 200)
      assert response["training_id"] == training_id
      assert response["status"] in ["pending", "running", "completed", "failed"]
      assert response["progress"] >= 0.0 and response["progress"] <= 1.0
      assert response["metrics"]
    end
    
    test "POST /api/ml/evaluate evaluates model performance", %{conn: conn} do
      evaluation_request = %{
        "model_id" => "variety_predictor_v1",
        "test_data" => %{
          "features" => [[1.0, 2.0, 3.0], [2.0, 3.0, 4.0]],
          "labels" => [0.8, 0.9]
        },
        "metrics" => ["accuracy", "precision", "recall", "f1"]
      }
      
      conn = post(conn, "/api/ml/evaluate", evaluation_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert metrics = response["metrics"]
      assert metrics["accuracy"] >= 0.0 and metrics["accuracy"] <= 1.0
      assert metrics["precision"]
      assert metrics["recall"]
      assert metrics["f1"]
    end
  end
  
  describe "Emergent Intelligence endpoints" do
    test "POST /api/ml/swarm/create creates swarm mind instance", %{conn: conn} do
      swarm_request = %{
        "swarm_type" => "variety_collective",
        "agents" => [
          %{"id" => "agent1", "type" => "analyzer", "capabilities" => ["pattern_recognition"]},
          %{"id" => "agent2", "type" => "predictor", "capabilities" => ["forecasting"]}
        ],
        "collective_goal" => "optimize_variety_flow"
      }
      
      conn = post(conn, "/api/ml/swarm/create", swarm_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["swarm_id"]
      assert response["swarm_type"] == "variety_collective"
      assert response["agent_count"] == 2
      assert response["collective_iq"]
    end
    
    test "POST /api/ml/swarm/:id/learn performs collective learning", %{conn: conn} do
      swarm_id = "test_swarm_123"
      learning_request = %{
        "experience_data" => %{
          "scenario" => "high_variety_flow",
          "actions" => ["filter_application", "aggregation"],
          "outcome" => "improved_performance",
          "reward" => 0.8
        },
        "learning_type" => "reinforcement"
      }
      
      conn = post(conn, "/api/ml/swarm/#{swarm_id}/learn", learning_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["learning_applied"] == true
      assert response["collective_knowledge_updated"] == true
      assert response["new_collective_iq"]
    end
    
    test "GET /api/ml/swarm/:id/behavior analyzes emergent behavior", %{conn: conn} do
      swarm_id = "test_swarm_123"
      conn = get(conn, "/api/ml/swarm/#{swarm_id}/behavior")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert behavior = response["emergent_behavior"]
      assert behavior["complexity_level"]
      assert behavior["cooperation_index"]
      assert behavior["innovation_rate"]
      assert behavior["self_organization_score"]
    end
    
    test "POST /api/ml/collective/decision makes collective decision", %{conn: conn} do
      decision_request = %{
        "decision_context" => %{
          "situation" => "variety_overload",
          "available_actions" => ["increase_filtering", "parallel_processing", "defer_processing"],
          "constraints" => %{"time_limit" => 5000, "resource_limit" => 0.8}
        },
        "voting_mechanism" => "weighted_consensus"
      }
      
      conn = post(conn, "/api/ml/collective/decision", decision_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["decision"] in ["increase_filtering", "parallel_processing", "defer_processing"]
      assert response["confidence"] >= 0.0 and response["confidence"] <= 1.0
      assert response["consensus_level"]
      assert response["dissenting_votes"]
    end
  end
  
  describe "Self-Organization endpoints" do
    test "POST /api/ml/self-organize triggers self-organization", %{conn: conn} do
      organization_request = %{
        "system_state" => %{
          "variety_flow" => 0.8,
          "processing_efficiency" => 0.6,
          "error_rate" => 0.1
        },
        "optimization_target" => "maximize_throughput"
      }
      
      conn = post(conn, "/api/ml/self-organize", organization_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["reorganization_applied"] == true
      assert response["new_structure"]
      assert response["expected_improvement"]
    end
    
    test "GET /api/ml/adaptation/history returns adaptation history", %{conn: conn} do
      conn = get(conn, "/api/ml/adaptation/history")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert adaptations = response["adaptations"]
      assert is_list(adaptations)
      
      if length(adaptations) > 0 do
        first_adaptation = List.first(adaptations)
        assert first_adaptation["timestamp"]
        assert first_adaptation["trigger"]
        assert first_adaptation["changes_made"]
        assert first_adaptation["performance_impact"]
      end
    end
  end
  
  describe "ML error handling" do
    test "invalid model ID returns error", %{conn: conn} do
      prediction_request = %{
        "model_id" => "nonexistent_model",
        "input_data" => [1.0, 2.0, 3.0]
      }
      
      conn = post(conn, "/api/ml/predict", prediction_request)
      
      assert response = json_response(conn, 404)
      assert response["error"] == "model_not_found"
    end
    
    test "invalid input data returns error", %{conn: conn} do
      prediction_request = %{
        "model_id" => "variety_predictor_v1",
        "input_data" => "invalid_data_format"
      }
      
      conn = post(conn, "/api/ml/predict", prediction_request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "invalid_input_format"
    end
    
    test "model training with insufficient data returns error", %{conn: conn} do
      training_request = %{
        "model_type" => "variety_predictor",
        "training_data" => %{
          "features" => [[1.0]],  # Insufficient data
          "labels" => [0.8]
        }
      }
      
      conn = post(conn, "/api/ml/train", training_request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "insufficient_training_data"
    end
  end
end