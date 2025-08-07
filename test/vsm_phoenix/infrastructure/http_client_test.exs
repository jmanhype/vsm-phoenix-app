defmodule VsmPhoenix.Infrastructure.HTTPClientTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Infrastructure.HTTPClient
  import ExUnit.CaptureLog
  
  setup do
    # Configure test services
    Application.put_env(:vsm_phoenix, :http_services, %{
      test_service: %{
        url: "https://httpbin.org",
        timeout: 5000
      },
      auth_service: %{
        url: "https://httpbin.org",
        auth: {:api_key, "x-test-key", "test123"}
      }
    })
    
    # Configure HTTP client settings
    Application.put_env(:vsm_phoenix, :http_client, %{
      timeout: 5000,
      max_retries: 2,
      retry_delay: 100,
      circuit_breaker: %{
        enabled: false,  # Disable for unit tests
        failure_threshold: 3,
        reset_timeout: 1000,
        half_open_requests: 1
      }
    })
    
    # Start HTTPClient GenServer if not already started
    case HTTPClient.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    :ok
  end
  
  describe "get/3" do
    test "makes successful GET request" do
      {:ok, response} = HTTPClient.get(:test_service, "/get")
      
      assert response.status == 200
      assert is_map(response.body)
    end
    
    test "includes authentication headers when configured" do
      {:ok, response} = HTTPClient.get(:auth_service, "/headers")
      
      assert response.status == 200
      headers = response.body["headers"]
      assert headers["X-Test-Key"] == "test123"
    end
    
    test "handles 404 responses" do
      {:ok, response} = HTTPClient.get(:test_service, "/status/404")
      
      assert response.status == 404
    end
    
    test "handles network timeouts" do
      # Use a service that will timeout
      Application.put_env(:vsm_phoenix, :http_services, %{
        timeout_service: %{
          url: "https://httpbin.org",
          timeout: 1  # Very short timeout
        }
      })
      
      Application.put_env(:vsm_phoenix, :http_client, %{
        timeout: 1,
        max_retries: 1,
        retry_delay: 10
      })
      
      result = HTTPClient.get(:timeout_service, "/delay/5")
      assert {:error, _} = result
    end
  end
  
  describe "post/4" do
    test "makes successful POST request with JSON body" do
      body = %{test: "data", number: 42}
      
      {:ok, response} = HTTPClient.post(:test_service, "/post", body)
      
      assert response.status == 200
      assert is_map(response.body)
      
      # httpbin.org echoes back the JSON data
      json_data = response.body["json"]
      assert json_data["test"] == "data"
      assert json_data["number"] == 42
    end
    
    test "includes custom headers" do
      body = %{test: "data"}
      headers = [{"x-custom-header", "custom-value"}]
      
      {:ok, response} = HTTPClient.post(:test_service, "/post", body, headers: headers)
      
      assert response.status == 200
      request_headers = response.body["headers"]
      assert request_headers["X-Custom-Header"] == "custom-value"
    end
  end
  
  describe "put/4" do
    test "makes successful PUT request" do
      body = %{updated: "data"}
      
      {:ok, response} = HTTPClient.put(:test_service, "/put", body)
      
      assert response.status == 200
      assert response.body["json"]["updated"] == "data"
    end
  end
  
  describe "delete/3" do
    test "makes successful DELETE request" do
      {:ok, response} = HTTPClient.delete(:test_service, "/delete")
      
      assert response.status == 200
    end
  end
  
  describe "retry logic" do
    test "retries on 5xx errors" do
      # Configure short retry delay for faster tests
      Application.put_env(:vsm_phoenix, :http_client, %{
        timeout: 5000,
        max_retries: 2,
        retry_delay: 50
      })
      
      # httpbin returns 500 status
      log = capture_log(fn ->
        {:ok, response} = HTTPClient.get(:test_service, "/status/500")
        assert response.status == 500
      end)
      
      # Should see retry attempts in logs
      assert log =~ "Retrying HTTP request"
    end
    
    test "does not retry on 4xx errors" do
      log = capture_log(fn ->
        {:ok, response} = HTTPClient.get(:test_service, "/status/404")
        assert response.status == 404
      end)
      
      # Should not see retry attempts for 4xx
      refute log =~ "Retrying HTTP request"
    end
  end
  
  describe "error handling" do
    test "handles unknown service" do
      result = HTTPClient.get(:unknown_service, "/test")
      assert {:error, :unknown_service} = result
    end
    
    test "handles malformed URLs" do
      Application.put_env(:vsm_phoenix, :http_services, %{
        bad_service: %{url: "not-a-url"}
      })
      
      result = HTTPClient.get(:bad_service, "/test")
      assert {:error, _reason} = result
    end
  end
  
  describe "request/5 core function" do
    test "builds correct request parameters" do
      body = %{test: "data"}
      headers = [{"content-type", "application/json"}]
      
      {:ok, response} = HTTPClient.post(:test_service, "/post", body, headers: headers)
      
      assert response.status == 200
      request_headers = response.body["headers"]
      assert request_headers["Content-Type"] == "application/json"
    end
  end
  
  describe "configuration validation" do
    test "validates service configuration on startup" do
      # Test with invalid configuration
      invalid_config = %{
        invalid_service: %{
          # Missing required url field
          api_key: "test"
        }
      }
      
      Application.put_env(:vsm_phoenix, :http_services, invalid_config)
      
      result = HTTPClient.get(:invalid_service, "/test")
      assert {:error, _} = result
    end
  end
end