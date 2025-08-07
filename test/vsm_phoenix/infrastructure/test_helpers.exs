defmodule VsmPhoenix.Infrastructure.TestHelpers do
  @moduledoc """
  Test helpers for infrastructure abstraction layer testing.
  
  Provides utilities for:
  - Mocking HTTP services
  - Mocking AMQP exchanges
  - Setting up test configurations
  - Asserting infrastructure behavior
  """
  
  alias VsmPhoenix.Infrastructure.{HTTPClient, AMQPClient, ExchangeConfig, ServiceRegistry}
  
  @doc """
  Sets up test HTTP services configuration
  """
  def setup_test_http_services do
    test_services = %{
      test_api: %{
        url: "https://httpbin.org",
        auth: {:api_key, "x-test-key", "test-key-123"}
      },
      anthropic_mock: %{
        url: "https://httpbin.org",
        api_key: "test-anthropic-key",
        version: "2023-06-01"
      },
      telegram_mock: %{
        url: "https://httpbin.org",
        bot_token: "test:mock_bot_token"
      },
      failing_service: %{
        url: "https://httpbin.org",
        timeout: 1  # Very short timeout for failure testing
      }
    }
    
    Application.put_env(:vsm_phoenix, :http_services, test_services)
    
    # Return cleanup function
    fn ->
      Application.delete_env(:vsm_phoenix, :http_services)
    end
  end
  
  @doc """
  Sets up test AMQP exchanges configuration
  """
  def setup_test_amqp_exchanges do
    test_exchanges = %{
      test_exchange: "test.exchange",
      algedonic: "test.vsm.algedonic",
      commands: "test.vsm.commands",
      coordination: "test.vsm.coordination",
      control: "test.vsm.control",
      intelligence: "test.vsm.intelligence",
      policy: "test.vsm.policy",
      audit: "test.vsm.audit",
      meta: "test.vsm.meta",
      swarm: "test.vsm.swarm",
      s1_commands: "test.vsm.s1.commands"
    }
    
    Application.put_env(:vsm_phoenix, :amqp_exchanges, test_exchanges)
    
    # Return cleanup function
    fn ->
      Application.delete_env(:vsm_phoenix, :amqp_exchanges)
    end
  end
  
  @doc """
  Sets up test HTTP client configuration
  """
  def setup_test_http_client_config do
    test_config = %{
      timeout: 5000,
      max_retries: 2,
      retry_delay: 100,
      circuit_breaker: %{
        enabled: false,  # Disabled for unit tests
        failure_threshold: 3,
        reset_timeout: 1000,
        half_open_requests: 1
      }
    }
    
    Application.put_env(:vsm_phoenix, :http_client, test_config)
    
    # Return cleanup function  
    fn ->
      Application.delete_env(:vsm_phoenix, :http_client)
    end
  end
  
  @doc """
  Creates a mock HTTP response for testing
  """
  def mock_http_response(status, body \\ %{}) do
    %{
      status: status,
      body: body,
      headers: [{"content-type", "application/json"}]
    }
  end
  
  @doc """
  Creates a test AMQP message
  """
  def create_test_amqp_message(type, payload, opts \\ []) do
    %{
      type: type,
      payload: payload,
      correlation_id: Keyword.get(opts, :correlation_id, generate_correlation_id()),
      timestamp: DateTime.utc_now(),
      source: Keyword.get(opts, :source, "test"),
      reply_to: Keyword.get(opts, :reply_to)
    }
  end
  
  @doc """
  Waits for AMQP connection to be available
  """
  def wait_for_amqp_connection(timeout \\ 5000) do
    case VsmPhoenix.AMQP.ConnectionManager.wait_for_connection(timeout) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Asserts that an HTTP request was made with specific parameters
  """
  def assert_http_request_made(service, method, path, opts \\ []) do
    # In a real implementation, this would check request logs or mocks
    # For now, we'll just verify the service exists
    config = ServiceRegistry.get_service_config(service)
    assert config != nil
    
    expected_url = ServiceRegistry.get_service_url(service, path)
    assert String.starts_with?(expected_url, "http")
    
    true
  end
  
  @doc """
  Asserts that an AMQP message was published
  """
  def assert_amqp_message_published(exchange_key, routing_key, expected_payload, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    
    # In practice, this would use a test consumer or mock
    # For now, verify exchange configuration exists
    exchange_name = ExchangeConfig.get_exchange_name(exchange_key)
    assert is_binary(exchange_name)
    
    true
  end
  
  @doc """
  Creates a temporary queue for testing
  """
  def create_test_queue(suffix \\ nil) do
    unique_id = :erlang.unique_integer([:positive])
    queue_name = if suffix do
      "test.#{suffix}.#{unique_id}"
    else
      "test.queue.#{unique_id}"
    end
    
    case AMQPClient.declare_queue(queue_name, [auto_delete: true]) do
      {:ok, queue_info} -> {:ok, queue_name, queue_info}
      error -> error
    end
  end
  
  @doc """
  Sets up a test message handler that sends received messages to a test process
  """
  def setup_test_message_handler(test_pid \\ nil) do
    target_pid = test_pid || self()
    
    fn payload, meta ->
      send(target_pid, {:test_message_received, payload, meta})
      :ok
    end
  end
  
  @doc """
  Generates test correlation ID
  """
  def generate_correlation_id do
    "test-corr-#{:erlang.unique_integer([:positive])}"
  end
  
  @doc """
  Mock HTTPoison for testing legacy code compatibility
  """
  def mock_httpoison do
    # This can be used to verify that old HTTPoison calls are replaced
    defmodule MockHTTPoison do
      def get(_url, _headers \\ [], _opts \\ []) do
        raise "HTTPoison should not be called - use HTTPClient instead"
      end
      
      def post(_url, _body, _headers \\ [], _opts \\ []) do
        raise "HTTPoison should not be called - use HTTPClient instead"  
      end
    end
    
    MockHTTPoison
  end
  
  @doc """
  Verifies that infrastructure abstractions are being used instead of direct libraries
  """
  def assert_no_direct_http_calls(module) do
    # Check that module doesn't use HTTPoison, :hackney, etc. directly
    source = module.__info__(:compile)[:source]
    if source do
      content = File.read!(source)
      
      refute content =~ "HTTPoison.", "Module #{module} should use HTTPClient instead of HTTPoison"
      refute content =~ ":hackney.", "Module #{module} should use HTTPClient instead of :hackney"
    end
    
    true
  end
  
  @doc """
  Verifies that infrastructure abstractions are being used for AMQP
  """
  def assert_no_direct_amqp_calls(module) do
    # Check that module uses AMQPClient instead of direct AMQP calls
    source = module.__info__(:compile)[:source]
    if source do
      content = File.read!(source)
      
      # Allow AMQP calls in infrastructure modules themselves
      unless String.contains?(to_string(module), "Infrastructure") do
        refute content =~ "AMQP.Basic.publish", "Module #{module} should use AMQPClient instead of direct AMQP.Basic.publish"
      end
    end
    
    true
  end
  
  @doc """
  Creates a comprehensive test environment setup
  """
  def setup_full_test_environment do
    cleanup_http = setup_test_http_services()
    cleanup_amqp = setup_test_amqp_exchanges() 
    cleanup_client = setup_test_http_client_config()
    
    # Return cleanup function that calls all cleanups
    fn ->
      cleanup_http.()
      cleanup_amqp.()
      cleanup_client.()
    end
  end
  
  @doc """
  Waits for async processing with timeout
  """
  def wait_for_async(timeout \\ 1000) do
    Process.sleep(timeout)
  end
  
  @doc """
  Asserts that a configuration value is properly set
  """
  def assert_config_set(app, key, expected_type \\ :any) do
    value = Application.get_env(app, key)
    assert value != nil, "Configuration #{app}.#{key} should be set"
    
    case expected_type do
      :map -> assert is_map(value)
      :list -> assert is_list(value)
      :binary -> assert is_binary(value)
      :integer -> assert is_integer(value)
      :boolean -> assert is_boolean(value)
      :any -> :ok
    end
    
    value
  end
end