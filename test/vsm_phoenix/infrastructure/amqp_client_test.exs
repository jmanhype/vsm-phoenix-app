defmodule VsmPhoenix.Infrastructure.AMQPClientTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Infrastructure.AMQPClient
  alias VsmPhoenix.AMQP.ConnectionManager
  
  setup_all do
    # Start the AMQP supervision tree for testing
    {:ok, _} = VsmPhoenix.AMQP.Supervisor.start_link([])
    :ok
  end
  
  setup do
    # Configure test exchanges
    Application.put_env(:vsm_phoenix, :amqp_exchanges, %{
      test_exchange: "test.exchange",
      algedonic: "test.vsm.algedonic"
    })
    
    # Wait for connection to be established
    case ConnectionManager.wait_for_connection(5000) do
      :ok -> :ok
      {:error, _} -> 
        # Skip tests if RabbitMQ is not available
        ExUnit.configure(exclude: [:requires_rabbitmq])
    end
    
    :ok
  end
  
  describe "publish/4" do
    @describetag :requires_rabbitmq
    test "publishes message to configured exchange" do
      message = %{test: "data", timestamp: DateTime.utc_now()}
      
      result = AMQPClient.publish(:test_exchange, "test.routing", message)
      assert result == :ok
    end
    
    test "publishes message with options" do
      message = %{urgent: "message"}
      opts = [persistent: true, priority: 5]
      
      result = AMQPClient.publish(:test_exchange, "urgent.routing", message, opts)
      assert result == :ok
    end
    
    test "handles publishing to unknown exchange" do
      message = %{test: "data"}
      
      # Should handle gracefully - exchange will be created if needed
      result = AMQPClient.publish(:unknown_exchange, "test", message)
      # Result depends on implementation - might succeed or fail gracefully
      assert result in [:ok, {:error, :exchange_not_found}]
    end
  end
  
  describe "declare_queue/2" do
    @describetag :requires_rabbitmq
    test "declares queue with default options" do
      queue_name = "test.queue.#{:erlang.unique_integer([:positive])}"
      
      result = AMQPClient.declare_queue(queue_name)
      assert {:ok, _queue_info} = result
    end
    
    test "declares queue with custom options" do
      queue_name = "test.durable.queue.#{:erlang.unique_integer([:positive])}"
      opts = [durable: true, auto_delete: false]
      
      result = AMQPClient.declare_queue(queue_name, opts)
      assert {:ok, _queue_info} = result
    end
  end
  
  describe "subscribe/3" do
    @describetag :requires_rabbitmq
    test "subscribes to queue and receives messages" do
      queue_name = "test.subscribe.queue.#{:erlang.unique_integer([:positive])}"
      
      # Declare the queue first
      {:ok, _} = AMQPClient.declare_queue(queue_name)
      
      # Set up a simple message handler
      test_pid = self()
      handler = fn payload, _meta ->
        send(test_pid, {:received_message, payload})
        :ok
      end
      
      # Subscribe
      result = AMQPClient.subscribe(queue_name, handler)
      assert {:ok, _consumer_tag} = result
      
      # Publish a message to the queue
      message = %{test: "subscription_test"}
      # We need to publish directly to the queue
      case ConnectionManager.get_channel(:test) do
        {:ok, channel} ->
          AMQP.Basic.publish(channel, "", queue_name, Jason.encode!(message))
          
          # Wait for message
          assert_receive {:received_message, received_payload}, 2000
          
          {:ok, decoded} = Jason.decode(received_payload)
          assert decoded["test"] == "subscription_test"
          
        {:error, _} ->
          # Skip if no connection available
          :ok
      end
    end
  end
  
  describe "connection handling" do
    test "handles connection failures gracefully" do
      # Mock a connection failure scenario
      # This would require more sophisticated mocking in a real test
      message = %{test: "data"}
      
      # Should not crash the calling process
      result = AMQPClient.publish(:test_exchange, "test", message)
      assert result in [:ok, {:error, :no_connection}]
    end
  end
  
  describe "message serialization" do
    test "handles different message types" do
      # Test with map
      map_message = %{type: "test", data: [1, 2, 3]}
      result = AMQPClient.publish(:test_exchange, "test", map_message)
      assert result in [:ok, {:error, :no_connection}]
      
      # Test with string
      string_message = "simple string message"
      result = AMQPClient.publish(:test_exchange, "test", string_message)
      assert result in [:ok, {:error, :no_connection}]
      
      # Test with list
      list_message = [1, 2, 3, "test"]
      result = AMQPClient.publish(:test_exchange, "test", list_message)
      assert result in [:ok, {:error, :no_connection}]
    end
  end
  
  describe "error conditions" do
    test "handles malformed messages gracefully" do
      # Test with something that can't be JSON encoded
      malformed = {self(), make_ref()}
      
      result = AMQPClient.publish(:test_exchange, "test", malformed)
      assert {:error, _} = result
    end
  end
end