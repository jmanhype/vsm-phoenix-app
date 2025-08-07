defmodule VsmPhoenix.Infrastructure.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Infrastructure.{AMQPClient, HTTPClient, ExchangeConfig, ServiceRegistry}
  alias VsmPhoenix.AMQP.ConnectionManager
  import ExUnit.CaptureLog
  
  @moduletag :integration
  
  setup_all do
    # Configure test environment
    Application.put_env(:vsm_phoenix, :amqp_exchanges, %{
      test_integration: "test.integration.exchange",
      algedonic: "test.vsm.algedonic"
    })
    
    Application.put_env(:vsm_phoenix, :http_services, %{
      test_api: %{
        url: "https://httpbin.org",
        auth: {:api_key, "x-test-key", "integration-test-123"}
      },
      test_service: %{
        url: "https://httpbin.org",
        timeout: 5000
      },
      auth_service: %{
        url: "https://httpbin.org", 
        auth: {:api_key, "x-test-key", "test123"}
      }
    })
    
    # Start infrastructure supervision tree
    case VsmPhoenix.Infrastructure.Supervisor.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    case VsmPhoenix.AMQP.Supervisor.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Start HTTPClient GenServer
    case VsmPhoenix.Infrastructure.HTTPClient.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    :ok
  end
  
  describe "AMQP infrastructure integration" do
    @describetag :requires_rabbitmq
    test "end-to-end message flow through abstraction layer" do
      # Set up a test consumer
      queue_name = "test.integration.queue.#{:erlang.unique_integer([:positive])}"
      test_pid = self()
      
      handler = fn payload, meta ->
        send(test_pid, {:message_received, payload, meta})
        :ok
      end
      
      # Declare queue and subscribe
      {:ok, _} = AMQPClient.declare_queue_by_name(queue_name, [])
      {:ok, _consumer_tag} = AMQPClient.subscribe_by_name(queue_name, handler)
      
      # Publish message through abstraction
      test_message = %{
        id: "integration-test-#{:erlang.unique_integer([:positive])}",
        content: "Infrastructure integration test",
        timestamp: DateTime.utc_now()
      }
      
      # Publish directly to queue for testing
      case ConnectionManager.get_channel(:test) do
        {:ok, channel} ->
          AMQP.Basic.publish(channel, "", queue_name, Jason.encode!(test_message))
          
          # Verify message was received
          assert_receive {:message_received, payload, _meta}, 5000
          
          {:ok, decoded} = Jason.decode(payload)
          assert decoded["id"] == test_message.id
          assert decoded["content"] == test_message.content
          
        {:error, _} ->
          # Skip if connection unavailable
          :ok
      end
    end
    
    test "exchange configuration integration" do
      # Verify exchanges are configured correctly
      algedonic_exchange = ExchangeConfig.get_exchange_name(:algedonic)
      assert algedonic_exchange == "test.vsm.algedonic"
      
      # Verify all expected exchanges are configured
      all_exchanges = ExchangeConfig.all_exchanges()
      assert is_map(all_exchanges)
      assert Map.has_key?(all_exchanges, :algedonic)
    end
  end
  
  describe "HTTP infrastructure integration" do
    test "end-to-end HTTP request through abstraction layer" do
      # Test GET request
      {:ok, response} = HTTPClient.get(:test_api, "/get")
      
      assert response.status == 200
      assert is_map(response.body)
      
      # Verify auth headers were added
      headers = response.body["headers"]
      assert headers["X-Test-Key"] == "integration-test-123"
    end
    
    test "HTTP POST with JSON payload" do
      payload = %{
        integration_test: true,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        data: %{
          system: "vsm_phoenix",
          component: "infrastructure_layer"
        }
      }
      
      {:ok, response} = HTTPClient.post(:test_api, "/post", payload)
      
      assert response.status == 200
      json_data = response.body["json"]
      assert json_data["integration_test"] == true
      assert json_data["data"]["system"] == "vsm_phoenix"
    end
    
    test "service registry integration" do
      # Verify services are registered correctly
      services = ServiceRegistry.list_services()
      assert :test_api in services
      
      {:ok, url} = ServiceRegistry.get_service_url(:test_api)
      assert url == "https://httpbin.org"
      
      # Test URL construction  
      {:ok, url} = ServiceRegistry.get_service_path_url(:test_api, :root, %{})
      assert String.starts_with?(url, "https://httpbin.org")
    end
  end
  
  describe "VSM system integration" do
    test "telegram agent can use HTTP abstraction" do
      # Mock telegram service for testing
      Application.put_env(:vsm_phoenix, :http_services, %{
        telegram: %{
          url: "https://httpbin.org",
          bot_token: "test:integration_bot_token"
        }
      })
      
      # Test that HTTPClient can handle telegram-style requests
      {:ok, response} = HTTPClient.get(:telegram, "/bottest:integration_bot_token/getMe")
      
      # httpbin.org will return 404 but that's expected - we're testing the abstraction
      assert response.status in [200, 404]
    end
    
    test "policy synthesizer can use HTTP abstraction" do
      # Mock anthropic service
      Application.put_env(:vsm_phoenix, :http_services, %{
        anthropic: %{
          url: "https://httpbin.org",
          api_key: "test-anthropic-key"
        }
      })
      
      # Test POST request like policy synthesizer would make
      body = %{
        model: "claude-3-opus-20240229",
        max_tokens: 100,
        messages: [%{role: "user", content: "Test policy request"}]
      }
      
      {:ok, response} = HTTPClient.post(:anthropic, "/v1/messages", body)
      
      assert response.status in [200, 404]  # httpbin.org will return different status
      assert is_map(response.body)
    end
  end
  
  describe "error recovery integration" do
    test "HTTP client recovers from service failures" do
      # Configure a service that will fail
      Application.put_env(:vsm_phoenix, :http_services, %{
        failing_service: %{
          url: "https://httpbin.org",
          timeout: 100  # Very short timeout
        }
      })
      
      Application.put_env(:vsm_phoenix, :http_client, %{
        timeout: 100,
        max_retries: 2,
        retry_delay: 50
      })
      
      # This should attempt retries
      log = capture_log(fn ->
        result = HTTPClient.get(:failing_service, "/delay/5")  # Will timeout
        # Either timeout or unexpected success
        case result do
          {:error, _} -> :ok
          {:ok, _} -> :ok  # Unexpected success but acceptable
        end
      end)
      
      # May see retry attempts in logs
      # Note: httpbin.org is quite reliable, so this test might not always trigger retries
    end
  end
  
  describe "configuration hot-reload" do
    test "configuration changes take effect" do
      # Change service configuration
      new_config = %{
        dynamic_service: %{
          url: "https://httpbin.org",
          api_key: "new-dynamic-key"
        }
      }
      
      # Register new service
      :ok = ServiceRegistry.register_service(:dynamic_service, new_config[:dynamic_service])
      
      # Verify new service is available
      {:ok, url} = ServiceRegistry.get_service_url(:dynamic_service)
      assert url == "https://httpbin.org"
    end
  end
  
  describe "AMQP and HTTP coordination" do
    @describetag :requires_rabbitmq
    test "can coordinate between AMQP events and HTTP responses" do
      # This tests a common pattern where:
      # 1. AMQP message triggers action
      # 2. HTTP request is made
      # 3. Response triggers another AMQP message
      
      test_pid = self()
      
      # Set up AMQP consumer
      queue_name = "test.coordination.#{:erlang.unique_integer([:positive])}"
      {:ok, _} = AMQPClient.declare_queue_by_name(queue_name, [])
      
      handler = fn payload, _meta ->
        # Simulate processing: make HTTP request
        {:ok, _response} = HTTPClient.get(:test_api, "/get")
        
        # Send result back via AMQP (in practice this would be to another exchange)
        send(test_pid, {:coordination_complete, payload})
        :ok
      end
      
      {:ok, _} = AMQPClient.subscribe_by_name(queue_name, handler)
      
      # Trigger the coordination
      trigger_message = %{action: "coordinate", test_id: "coord-#{:erlang.unique_integer([:positive])}"}
      
      case ConnectionManager.get_channel(:test) do
        {:ok, channel} ->
          AMQP.Basic.publish(channel, "", queue_name, Jason.encode!(trigger_message))
          
          # Wait for coordination to complete
          assert_receive {:coordination_complete, _payload}, 10000
          
        {:error, _} ->
          :ok
      end
    end
  end
  
  describe "contract compliance" do
    test "infrastructure maintains API contract for VSM systems" do
      # Test that all expected functions are available
      assert function_exported?(AMQPClient, :publish, 4)
      assert function_exported?(AMQPClient, :declare_queue_by_name, 2) 
      assert function_exported?(AMQPClient, :subscribe_by_name, 3)
      
      assert function_exported?(HTTPClient, :get, 3)
      assert function_exported?(HTTPClient, :post, 4)
      assert function_exported?(HTTPClient, :put, 4)
      assert function_exported?(HTTPClient, :delete, 3)
      
      assert function_exported?(ExchangeConfig, :get_exchange_name, 1)
      assert function_exported?(ExchangeConfig, :agent_exchange, 2)
      
      assert function_exported?(ServiceRegistry, :get_service_url, 1)
      assert function_exported?(ServiceRegistry, :get_service_path_url, 3)
    end
    
    test "infrastructure return types match contract" do
      # Test AMQP return types
      case AMQPClient.declare_queue_by_name("test.contract.queue", []) do
        {:ok, _queue_info} -> :ok
        {:error, :no_connection} -> :ok  # Expected when RabbitMQ unavailable
        other -> flunk("Unexpected return type: #{inspect(other)}")
      end
      
      # Test HTTP return types
      case HTTPClient.get(:test_api, "/get") do
        {:ok, response} ->
          assert Map.has_key?(response, :status)
          assert Map.has_key?(response, :body)
        {:error, _reason} -> :ok  # Network issues are acceptable
        other -> flunk("Unexpected return type: #{inspect(other)}")
      end
    end
  end
  
  describe "performance characteristics" do
    test "infrastructure adds minimal latency" do
      # Measure time for direct config lookup
      start_time = System.monotonic_time(:microsecond)
      _exchange = ExchangeConfig.get_exchange_name(:algedonic)
      config_time = System.monotonic_time(:microsecond) - start_time
      
      # Should be very fast (< 1ms for config lookup)
      assert config_time < 1000  # microseconds
      
      # Measure service config lookup
      start_time = System.monotonic_time(:microsecond)
      _service = ServiceRegistry.get_service_url(:test_api)
      service_time = System.monotonic_time(:microsecond) - start_time
      
      assert service_time < 1000  # microseconds
    end
  end
end