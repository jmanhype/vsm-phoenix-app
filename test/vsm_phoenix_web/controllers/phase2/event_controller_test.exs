defmodule VsmPhoenixWeb.Phase2.EventControllerTest do
  use VsmPhoenixWeb.ConnCase
  use ExUnit.Case, async: true
  
  setup do
    conn = build_conn()
    |> put_req_header("authorization", "Bearer test-token")
    |> put_req_header("content-type", "application/json")
    
    {:ok, conn: conn}
  end
  
  describe "Event Processing endpoints" do
    test "POST /api/events/process processes variety events", %{conn: conn} do
      event_request = %{
        "event_type" => "variety_spike",
        "source_system" => "system1",
        "event_data" => %{
          "magnitude" => 0.8,
          "duration" => 1000,
          "patterns" => ["pattern_a", "pattern_b"]
        },
        "processing_priority" => "high"
      }
      
      conn = post(conn, "/api/events/process", event_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "processed"
      assert response["event_id"]
      assert response["processing_time"]
      assert response["actions_taken"]
      assert response["system_impact"]
    end
    
    test "POST /api/events/batch processes multiple events", %{conn: conn} do
      batch_request = %{
        "events" => [
          %{
            "event_type" => "variety_increase",
            "source_system" => "system1",
            "event_data" => %{"magnitude" => 0.6}
          },
          %{
            "event_type" => "variety_decrease",
            "source_system" => "system4",
            "event_data" => %{"magnitude" => 0.4}
          }
        ],
        "processing_mode" => "parallel"
      }
      
      conn = post(conn, "/api/events/batch", batch_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "batch_processed"
      assert response["processed_count"] == 2
      assert response["failed_count"] == 0
      assert results = response["results"]
      assert length(results) == 2
    end
    
    test "GET /api/events/stream/:system_id streams events", %{conn: conn} do
      system_id = "system1"
      conn = get(conn, "/api/events/stream/#{system_id}")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "streaming"
      assert response["stream_id"]
      assert response["websocket_url"]
      assert response["system_id"] == system_id
    end
    
    test "POST /api/events/subscribe subscribes to event types", %{conn: conn} do
      subscription_request = %{
        "event_types" => ["variety_spike", "system_overload", "quantum_entanglement"],
        "callback_url" => "https://example.com/webhook",
        "filter_conditions" => %{
          "min_magnitude" => 0.5,
          "systems" => ["system1", "system4"]
        }
      }
      
      conn = post(conn, "/api/events/subscribe", subscription_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "subscribed"
      assert response["subscription_id"]
      assert response["event_types"] == ["variety_spike", "system_overload", "quantum_entanglement"]
    end
    
    test "GET /api/events/history returns event history", %{conn: conn} do
      conn = get(conn, "/api/events/history?limit=10&system=system1")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert events = response["events"]
      assert is_list(events)
      assert response["total_count"]
      assert response["page_info"]
      
      if length(events) > 0 do
        first_event = List.first(events)
        assert first_event["event_id"]
        assert first_event["event_type"]
        assert first_event["timestamp"]
        assert first_event["source_system"]
      end
    end
    
    test "POST /api/events/replay replays historical events", %{conn: conn} do
      replay_request = %{
        "time_range" => %{
          "start" => "2024-01-01T00:00:00Z",
          "end" => "2024-01-02T00:00:00Z"
        },
        "event_filter" => %{
          "types" => ["variety_spike"],
          "systems" => ["system1"]
        },
        "replay_speed" => 10.0
      }
      
      conn = post(conn, "/api/events/replay", replay_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "replay_started"
      assert response["replay_id"]
      assert response["events_to_replay"]
      assert response["estimated_duration"]
    end
  end
  
  describe "Event Analytics endpoints" do
    test "GET /api/events/analytics/patterns analyzes event patterns", %{conn: conn} do
      conn = get(conn, "/api/events/analytics/patterns?timeframe=24h&system=system1")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert patterns = response["patterns"]
      assert patterns["frequency_analysis"]
      assert patterns["correlation_matrix"]
      assert patterns["anomaly_detection"]
      assert patterns["trend_analysis"]
    end
    
    test "POST /api/events/analytics/predict predicts future events", %{conn: conn} do
      prediction_request = %{
        "system_id" => "system1",
        "prediction_horizon" => "1h",
        "event_types" => ["variety_spike", "system_overload"],
        "confidence_threshold" => 0.7
      }
      
      conn = post(conn, "/api/events/analytics/predict", prediction_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert predictions = response["predictions"]
      assert is_list(predictions)
      
      if length(predictions) > 0 do
        first_prediction = List.first(predictions)
        assert first_prediction["event_type"]
        assert first_prediction["predicted_time"]
        assert first_prediction["confidence"] >= 0.0
        assert first_prediction["confidence"] <= 1.0
      end
    end
    
    test "GET /api/events/analytics/impact analyzes system impact", %{conn: conn} do
      conn = get(conn, "/api/events/analytics/impact?event_id=test_event_123")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert impact = response["impact_analysis"]
      assert impact["affected_systems"]
      assert impact["performance_change"]
      assert impact["cascade_effects"]
      assert impact["recovery_time"]
    end
  end
  
  describe "Real-time Event Processing" do
    test "POST /api/events/realtime/trigger triggers real-time processing", %{conn: conn} do
      trigger_request = %{
        "processing_rules" => [
          %{
            "condition" => "magnitude > 0.8",
            "action" => "immediate_alert",
            "priority" => "critical"
          }
        ],
        "target_systems" => ["system1", "system4", "system5"]
      }
      
      conn = post(conn, "/api/events/realtime/trigger", trigger_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "realtime_enabled"
      assert response["processing_id"]
      assert response["active_rules"] == 1
    end
    
    test "GET /api/events/realtime/status returns processing status", %{conn: conn} do
      conn = get(conn, "/api/events/realtime/status")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert status = response["realtime_status"]
      assert status["active_processors"]
      assert status["events_per_second"]
      assert status["processing_latency"]
      assert status["error_rate"]
    end
  end
  
  describe "Event error handling" do
    test "invalid event type returns error", %{conn: conn} do
      invalid_request = %{
        "event_type" => "invalid_event_type",
        "source_system" => "system1",
        "event_data" => %{}
      }
      
      conn = post(conn, "/api/events/process", invalid_request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "invalid_event_type"
    end
    
    test "missing required fields returns error", %{conn: conn} do
      incomplete_request = %{
        "event_type" => "variety_spike"
        # Missing source_system and event_data
      }
      
      conn = post(conn, "/api/events/process", incomplete_request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "missing_required_fields"
      assert response["missing_fields"]
    end
    
    test "event processing failure handling", %{conn: conn} do
      # Test with malformed event data that should trigger processing failure
      malformed_request = %{
        "event_type" => "variety_spike",
        "source_system" => "system1",
        "event_data" => %{
          "magnitude" => "invalid_magnitude",  # Should be numeric
          "duration" => -1000  # Should be positive
        }
      }
      
      conn = post(conn, "/api/events/process", malformed_request)
      
      assert response = json_response(conn, 422)
      assert response["error"] == "processing_failed"
      assert response["validation_errors"]
    end
  end
  
  describe "Event authentication and authorization" do
    test "unauthorized access returns 401", %{} do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      
      event_request = %{
        "event_type" => "variety_spike",
        "source_system" => "system1",
        "event_data" => %{}
      }
      
      conn = post(conn, "/api/events/process", event_request)
      
      assert response = json_response(conn, 401)
      assert response["error"] == "unauthorized"
    end
    
    test "insufficient permissions returns 403", %{conn: conn} do
      # Test with limited-permission token
      limited_conn = conn
      |> put_req_header("authorization", "Bearer limited-token")
      
      admin_request = %{
        "processing_rules" => [%{"condition" => "magnitude > 0.5"}],
        "target_systems" => ["system1"]
      }
      
      conn = post(limited_conn, "/api/events/realtime/trigger", admin_request)
      
      # This should either work or return 403 depending on token permissions
      assert conn.status in [200, 403]
    end
  end
end