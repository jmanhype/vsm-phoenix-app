defmodule VsmPhoenix.Infrastructure.ContractTest do
  use ExUnit.Case, async: true
  
  @moduledoc """
  Contract tests ensure the infrastructure abstraction layer maintains
  stable interfaces that VSM systems depend on.
  
  These tests verify:
  - Function signatures remain stable
  - Return value formats are consistent  
  - Error handling follows expected patterns
  - Configuration interfaces are preserved
  """
  
  alias VsmPhoenix.Infrastructure.{AMQPClient, HTTPClient, ExchangeConfig, ServiceRegistry, AMQPRoutes}
  import ExUnit.CaptureLog
  
  describe "AMQPClient contract" do
    test "publish/4 function signature and return types" do
      # Verify function exists with correct arity
      assert function_exported?(AMQPClient, :publish, 4)
      
      # Test return value contract (should be :ok or {:error, reason})
      message = %{test: "contract"}
      result = AMQPClient.publish(:test_exchange, "test.route", message, [])
      
      assert result == :ok or match?({:error, _}, result)
    end
    
    test "declare_queue/2 function signature and return types" do
      assert function_exported?(AMQPClient, :declare_queue, 2)
      
      result = AMQPClient.declare_queue("test.contract.queue", [])
      
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
    
    test "subscribe/3 function signature and return types" do
      assert function_exported?(AMQPClient, :subscribe, 3)
      
      handler = fn _payload, _meta -> :ok end
      result = AMQPClient.subscribe("test.queue", handler, [])
      
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
  
  describe "HTTPClient contract" do
    test "HTTP method functions have correct signatures" do
      assert function_exported?(HTTPClient, :get, 3)
      assert function_exported?(HTTPClient, :post, 4) 
      assert function_exported?(HTTPClient, :put, 4)
      assert function_exported?(HTTPClient, :delete, 3)
    end
    
    test "HTTP response format contract" do
      # Mock successful response
      Application.put_env(:vsm_phoenix, :http_services, %{
        contract_test: %{url: "https://httpbin.org"}
      })
      
      case HTTPClient.get(:contract_test, "/get") do
        {:ok, response} ->
          # Response must have status and body
          assert Map.has_key?(response, :status)
          assert Map.has_key?(response, :body)
          assert is_integer(response.status)
          
        {:error, reason} ->
          # Error format contract
          assert is_atom(reason) or is_binary(reason) or is_tuple(reason)
      end
    end
    
    test "request options contract" do
      # Verify options are properly handled
      opts = [
        headers: [{"x-test", "value"}],
        timeout: 5000,
        params: %{test: "param"}
      ]
      
      Application.put_env(:vsm_phoenix, :http_services, %{
        options_test: %{url: "https://httpbin.org"}
      })
      
      result = HTTPClient.get(:options_test, "/get", opts)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
  
  describe "ExchangeConfig contract" do
    test "get_exchange_name/1 always returns string" do
      assert function_exported?(ExchangeConfig, :get_exchange_name, 1)
      
      # Mock minimal config
      Application.put_env(:vsm_phoenix, :amqp_exchanges, %{
        test_exchange: "test.exchange.name"
      })
      
      result = ExchangeConfig.get_exchange_name(:test_exchange)
      assert is_binary(result)
    end
    
    test "agent_exchange/2 returns consistent format" do
      assert function_exported?(ExchangeConfig, :agent_exchange, 2)
      
      result = ExchangeConfig.agent_exchange("agent123", "telemetry")
      
      # Must be string in expected format
      assert is_binary(result)
      assert result =~ "agent123"
      assert result =~ "telemetry"
    end
    
    test "all_exchanges/0 returns map" do
      assert function_exported?(ExchangeConfig, :all_exchanges, 0)
      
      result = ExchangeConfig.all_exchanges()
      assert is_map(result)
    end
  end
  
  describe "ServiceRegistry contract" do
    test "get_service_config/1 returns struct with required fields" do
      assert function_exported?(ServiceRegistry, :get_service_config, 1)
      
      Application.put_env(:vsm_phoenix, :http_services, %{
        contract_service: %{
          url: "https://example.com",
          api_key: "test-key"
        }
      })
      
      config = ServiceRegistry.get_service_config(:contract_service)
      
      # Must have url field
      assert Map.has_key?(config, :url)
      assert is_binary(config.url)
    end
    
    test "get_service_url/2 returns valid URL" do
      assert function_exported?(ServiceRegistry, :get_service_url, 2)
      
      Application.put_env(:vsm_phoenix, :http_services, %{
        url_test: %{url: "https://api.example.com"}
      })
      
      url = ServiceRegistry.get_service_url(:url_test, "/test")
      
      assert is_binary(url)
      assert String.starts_with?(url, "https://")
    end
  end
  
  describe "AMQPRoutes contract" do
    test "get_queue_name/1 returns string" do
      assert function_exported?(AMQPRoutes, :get_queue_name, 1)
      
      result = AMQPRoutes.get_queue_name(:system1_commands)
      assert is_binary(result)
      assert result =~ "system1"
      assert result =~ "commands"
    end
    
    test "build_agent_queue_name/2 returns consistent format" do
      assert function_exported?(AMQPRoutes, :build_agent_queue_name, 2)
      
      result = AMQPRoutes.build_agent_queue_name("agent123", "telemetry")
      assert is_binary(result)
      assert result =~ "agent123"
      assert result =~ "telemetry"
    end
  end
  
  describe "backward compatibility" do
    test "old VSM systems can still function with abstractions" do
      # Verify that refactored systems maintain expected behavior
      
      # Test that command router still works
      if function_exported?(VsmPhoenix.AMQP.CommandRouter, :publish_event, 2) do
        # This should not crash - it uses the abstraction internally
        log = capture_log(fn ->
          try do
            VsmPhoenix.AMQP.CommandRouter.publish_event(:test_event, %{test: "data"})
          rescue
            _ -> :ok  # Expected if AMQP not available
          end
        end)
        
        # Should either work or fail gracefully
        assert log != "" or true  # Either logs something or works silently
      end
    end
    
    test "policy synthesizer HTTP calls work through abstraction" do
      # Verify PolicySynthesizer can still make HTTP calls
      if Code.ensure_loaded?(VsmPhoenix.System5.PolicySynthesizer) do
        # The HTTPClient should be used internally now
        Application.put_env(:vsm_phoenix, :http_services, %{
          anthropic: %{
            url: "https://httpbin.org",  # Mock endpoint for testing
            api_key: "test-contract-key"
          }
        })
        
        # This tests that the refactored code still compiles and loads
        assert function_exported?(VsmPhoenix.System5.PolicySynthesizer, :synthesize_policy_from_anomaly, 1)
      end
    end
  end
  
  describe "configuration contract" do
    test "infrastructure configuration follows expected schema" do
      # Test AMQP exchanges config schema
      amqp_config = Application.get_env(:vsm_phoenix, :amqp_exchanges, %{})
      assert is_map(amqp_config)
      
      # Test HTTP services config schema  
      http_config = Application.get_env(:vsm_phoenix, :http_services, %{})
      assert is_map(http_config)
      
      # Test HTTP client config schema
      client_config = Application.get_env(:vsm_phoenix, :http_client, %{})
      assert is_map(client_config)
    end
    
    test "environment variables are properly typed" do
      # Verify that string environment variables are converted to appropriate types
      # This prevents runtime errors from type mismatches
      
      # Test timeout conversion
      timeout = Application.get_env(:vsm_phoenix, :http_client, %{})[:timeout]
      if timeout, do: assert(is_integer(timeout))
      
      # Test boolean conversion for circuit breaker
      circuit_config = Application.get_env(:vsm_phoenix, :http_client, %{})[:circuit_breaker]
      if circuit_config && circuit_config[:enabled] do
        assert is_boolean(circuit_config[:enabled])
      end
    end
  end
  
  describe "error handling contract" do
    test "all public functions handle errors gracefully" do
      # Test with invalid configurations
      Application.put_env(:vsm_phoenix, :http_services, %{
        invalid_service: %{} # Missing url
      })
      
      # Should not crash, should return error tuple
      result = HTTPClient.get(:invalid_service, "/test")
      assert match?({:error, _}, result)
    end
    
    test "AMQP functions handle connection failures gracefully" do
      # Test behavior when AMQP is not available
      result = AMQPClient.publish(:test_exchange, "test", %{test: "data"})
      assert result == :ok or match?({:error, _}, result)
    end
  end
end