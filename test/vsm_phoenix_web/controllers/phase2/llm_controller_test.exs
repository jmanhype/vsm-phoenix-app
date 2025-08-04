defmodule VsmPhoenixWeb.Phase2.LLMControllerTest do
  use VsmPhoenixWeb.ConnCase
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.MCP.LLMBridge
  
  setup do
    # Mock authentication
    conn = build_conn()
    |> put_req_header("authorization", "Bearer test-token")
    |> put_req_header("content-type", "application/json")
    
    {:ok, conn: conn}
  end
  
  describe "LLM Bridge endpoints" do
    test "POST /api/llm/query processes text query", %{conn: conn} do
      query_request = %{
        "prompt" => "Analyze system variety",
        "model" => "gpt-4",
        "context" => %{
          "system" => "vsm",
          "component" => "variety_analysis"
        }
      }
      
      conn = post(conn, "/api/llm/query", query_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert response["result"]["analysis"]
      assert response["result"]["confidence"] >= 0.0
      assert response["result"]["confidence"] <= 1.0
      assert response["metadata"]["model"] == "gpt-4"
      assert response["metadata"]["tokens_used"]
    end
    
    test "POST /api/llm/batch processes multiple queries", %{conn: conn} do
      batch_request = %{
        "queries" => [
          %{"prompt" => "Query 1", "model" => "gpt-3.5-turbo"},
          %{"prompt" => "Query 2", "model" => "gpt-4"}
        ],
        "parallel" => true
      }
      
      conn = post(conn, "/api/llm/batch", batch_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert length(response["results"]) == 2
      assert response["metadata"]["processed_count"] == 2
      assert response["metadata"]["total_tokens"]
    end
    
    test "GET /api/llm/models returns available models", %{conn: conn} do
      conn = get(conn, "/api/llm/models")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert models = response["models"]
      assert is_list(models)
      
      # Check model structure
      first_model = List.first(models)
      assert first_model["name"]
      assert first_model["provider"]
      assert first_model["capabilities"]
      assert first_model["max_tokens"]
    end
    
    test "POST /api/llm/embedding generates embeddings", %{conn: conn} do
      embedding_request = %{
        "text" => "VSM variety engineering",
        "model" => "text-embedding-ada-002"
      }
      
      conn = post(conn, "/api/llm/embedding", embedding_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "success"
      assert embedding = response["embedding"]
      assert is_list(embedding)
      assert length(embedding) > 0
      assert Enum.all?(embedding, &is_number/1)
    end
    
    test "POST /api/llm/query with invalid model returns error", %{conn: conn} do
      invalid_request = %{
        "prompt" => "Test",
        "model" => "invalid-model"
      }
      
      conn = post(conn, "/api/llm/query", invalid_request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "invalid_model"
      assert response["message"]
    end
    
    test "POST /api/llm/query without authentication returns unauthorized", %{} do
      conn = build_conn()
      |> put_req_header("content-type", "application/json")
      
      query_request = %{"prompt" => "Test", "model" => "gpt-4"}
      
      conn = post(conn, "/api/llm/query", query_request)
      
      assert response = json_response(conn, 401)
      assert response["error"] == "unauthorized"
    end
    
    test "POST /api/llm/query with rate limiting", %{conn: conn} do
      query_request = %{"prompt" => "Test", "model" => "gpt-4"}
      
      # Make multiple requests quickly
      responses = Enum.map(1..10, fn _ ->
        post(conn, "/api/llm/query", query_request)
      end)
      
      # Should get rate limited after some requests
      status_codes = Enum.map(responses, &(&1.status))
      assert 429 in status_codes or Enum.count(status_codes, &(&1 == 200)) <= 5
    end
    
    test "GET /api/llm/health returns service health", %{conn: conn} do
      conn = get(conn, "/api/llm/health")
      
      assert response = json_response(conn, 200)
      assert response["status"] == "healthy"
      assert response["services"]["openai"]
      assert response["services"]["anthropic"]
      assert response["uptime"]
      assert response["version"]
    end
  end
  
  describe "LLM streaming endpoints" do
    test "POST /api/llm/stream initiates streaming response", %{conn: conn} do
      stream_request = %{
        "prompt" => "Generate a long analysis",
        "model" => "gpt-4",
        "stream" => true
      }
      
      conn = post(conn, "/api/llm/stream", stream_request)
      
      assert response = json_response(conn, 200)
      assert response["status"] == "streaming"
      assert response["stream_id"]
      assert response["websocket_url"]
    end
  end
  
  describe "input validation" do
    test "validates prompt length", %{conn: conn} do
      long_prompt = String.duplicate("x", 100_000)
      
      request = %{"prompt" => long_prompt, "model" => "gpt-4"}
      conn = post(conn, "/api/llm/query", request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "prompt_too_long"
    end
    
    test "validates required fields", %{conn: conn} do
      request = %{"model" => "gpt-4"} # missing prompt
      conn = post(conn, "/api/llm/query", request)
      
      assert response = json_response(conn, 400)
      assert response["error"] == "missing_required_field"
      assert response["field"] == "prompt"
    end
  end
end