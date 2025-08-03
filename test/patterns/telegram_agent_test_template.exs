defmodule VsmPhoenix.System1.Agents.TelegramAgentTest do
  @moduledoc """
  Test suite for TelegramAgent GenServer.
  Tests message handling, integration, and fault tolerance.
  """
  
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias VsmPhoenix.System1.Agents.TelegramAgent
  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @test_timeout 5_000
  
  setup do
    # Ensure clean state
    Application.ensure_all_started(:vsm_phoenix)
    
    # Wait for systems to initialize
    Process.sleep(200)
    
    # Create test agent config
    agent_config = %{
      bot_token: "test_token",
      chat_id: "test_chat",
      webhook_url: "http://localhost:4000/telegram/webhook",
      allowed_commands: ["/start", "/help", "/status", "/metrics"],
      rate_limit: 10,
      rate_window: 60
    }
    
    on_exit(fn ->
      # Cleanup any spawned agents
      Registry.list_agents()
      |> Enum.each(fn %{agent_id: id} ->
        if String.starts_with?(id, "telegram_test_") do
          Registry.unregister(id)
        end
      end)
    end)
    
    {:ok, agent_config: agent_config}
  end
  
  describe "TelegramAgent initialization" do
    test "starts successfully with valid config", %{agent_config: config} do
      agent_id = "telegram_test_#{System.unique_integer([:positive])}"
      
      assert {:ok, pid} = TelegramAgent.start_link([
        id: agent_id,
        config: config
      ])
      
      assert Process.alive?(pid)
      
      # Verify registration
      assert {:ok, ^pid, metadata} = Registry.lookup(agent_id)
      assert metadata.type == :telegram
    end
    
    test "fails to start with invalid config" do
      agent_id = "telegram_test_invalid"
      
      assert {:error, _reason} = TelegramAgent.start_link([
        id: agent_id,
        config: %{}  # Missing required fields
      ])
    end
    
    test "registers webhook on startup", %{agent_config: config} do
      agent_id = "telegram_test_webhook"
      
      capture_log(fn ->
        {:ok, _pid} = TelegramAgent.start_link([
          id: agent_id,
          config: config
        ])
        
        # Give time for webhook registration
        Process.sleep(100)
      end) =~ "Webhook registered"
    end
  end
  
  describe "Message handling" do
    setup %{agent_config: config} do
      agent_id = "telegram_test_messages"
      {:ok, pid} = TelegramAgent.start_link([
        id: agent_id,
        config: config
      ])
      
      {:ok, agent_id: agent_id, agent_pid: pid}
    end
    
    test "processes incoming text message", %{agent_id: agent_id} do
      message = %{
        "message_id" => 123,
        "text" => "Hello bot",
        "chat" => %{"id" => "test_chat"},
        "from" => %{"id" => "user123", "username" => "testuser"}
      }
      
      assert :ok = TelegramAgent.handle_message(agent_id, message)
      
      # Verify message was processed
      {:ok, metrics} = TelegramAgent.get_metrics(agent_id)
      assert metrics.messages_received > 0
    end
    
    test "handles command messages", %{agent_id: agent_id} do
      commands = [
        %{"text" => "/start", "expected" => :welcome},
        %{"text" => "/help", "expected" => :help},
        %{"text" => "/status", "expected" => :status},
        %{"text" => "/metrics", "expected" => :metrics}
      ]
      
      Enum.each(commands, fn %{"text" => text, "expected" => expected} ->
        message = %{
          "message_id" => System.unique_integer([:positive]),
          "text" => text,
          "chat" => %{"id" => "test_chat"},
          "from" => %{"id" => "user123"}
        }
        
        result = TelegramAgent.handle_message(agent_id, message)
        assert {:ok, ^expected} = result
      end)
    end
    
    test "publishes messages to AMQP", %{agent_id: agent_id} do
      message = %{
        "message_id" => 456,
        "text" => "Test AMQP publishing",
        "chat" => %{"id" => "test_chat"},
        "from" => %{"id" => "user123"}
      }
      
      # Subscribe to the agent's AMQP topic
      {:ok, channel} = ConnectionManager.get_channel(:telemetry)
      exchange = "vsm.s1.#{agent_id}.telegram"
      queue = "test_queue_#{System.unique_integer([:positive])}"
      
      {:ok, _} = AMQP.Queue.declare(channel, queue, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, queue, exchange, routing_key: "#")
      
      # Send message
      :ok = TelegramAgent.handle_message(agent_id, message)
      
      # Check AMQP delivery
      assert_receive {:basic_deliver, payload, _meta}, 1000
      
      decoded = Jason.decode!(payload)
      assert decoded["type"] == "telegram_message"
      assert decoded["data"]["text"] == "Test AMQP publishing"
    end
  end
  
  describe "Rate limiting" do
    setup %{agent_config: config} do
      # Set aggressive rate limit for testing
      limited_config = %{config | rate_limit: 3, rate_window: 1}
      
      agent_id = "telegram_test_rate_limit"
      {:ok, pid} = TelegramAgent.start_link([
        id: agent_id,
        config: limited_config
      ])
      
      {:ok, agent_id: agent_id, agent_pid: pid}
    end
    
    test "enforces rate limits", %{agent_id: agent_id} do
      # Send messages up to rate limit
      for i <- 1..3 do
        message = %{
          "message_id" => i,
          "text" => "Message #{i}",
          "chat" => %{"id" => "test_chat"},
          "from" => %{"id" => "user123"}
        }
        
        assert :ok = TelegramAgent.handle_message(agent_id, message)
      end
      
      # Next message should be rate limited
      message = %{
        "message_id" => 4,
        "text" => "Rate limited message",
        "chat" => %{"id" => "test_chat"},
        "from" => %{"id" => "user123"}
      }
      
      assert {:error, :rate_limited} = TelegramAgent.handle_message(agent_id, message)
      
      # Wait for rate window to reset
      Process.sleep(1100)
      
      # Should work again
      assert :ok = TelegramAgent.handle_message(agent_id, message)
    end
  end
  
  describe "Fault tolerance" do
    setup %{agent_config: config} do
      agent_id = "telegram_test_fault"
      {:ok, pid} = TelegramAgent.start_link([
        id: agent_id,
        config: config
      ])
      
      {:ok, agent_id: agent_id, agent_pid: pid, config: config}
    end
    
    test "handles malformed messages gracefully", %{agent_id: agent_id} do
      malformed_messages = [
        nil,
        %{},  # Missing required fields
        %{"text" => "No chat info"},
        %{"chat" => %{"id" => "123"}},  # No text
        "not even a map"
      ]
      
      Enum.each(malformed_messages, fn message ->
        result = TelegramAgent.handle_message(agent_id, message)
        assert {:error, _} = result
      end)
      
      # Agent should still be alive
      assert {:ok, pid, _} = Registry.lookup(agent_id)
      assert Process.alive?(pid)
    end
    
    test "recovers from AMQP connection loss", %{agent_id: agent_id} do
      # This would require mocking AMQP connection
      # For now, just verify the agent stays alive
      
      # Simulate AMQP error by sending a fake connection_closed message
      {:ok, pid, _} = Registry.lookup(agent_id)
      send(pid, {:amqp_connection_closed, :test_reason})
      
      # Give it time to handle
      Process.sleep(100)
      
      # Agent should still be alive and attempting reconnection
      assert Process.alive?(pid)
    end
    
    test "graceful shutdown", %{agent_id: agent_id} do
      {:ok, pid, _} = Registry.lookup(agent_id)
      
      # Stop the agent
      :ok = GenServer.stop(pid, :normal)
      
      # Verify cleanup
      assert {:error, :not_found} = Registry.lookup(agent_id)
    end
  end
  
  describe "Metrics and monitoring" do
    setup %{agent_config: config} do
      agent_id = "telegram_test_metrics"
      {:ok, pid} = TelegramAgent.start_link([
        id: agent_id,
        config: config
      ])
      
      {:ok, agent_id: agent_id, agent_pid: pid}
    end
    
    test "tracks message metrics", %{agent_id: agent_id} do
      # Send some messages
      for i <- 1..5 do
        message = %{
          "message_id" => i,
          "text" => "Message #{i}",
          "chat" => %{"id" => "test_chat"},
          "from" => %{"id" => "user#{i}"}
        }
        
        TelegramAgent.handle_message(agent_id, message)
      end
      
      # Check metrics
      {:ok, metrics} = TelegramAgent.get_metrics(agent_id)
      
      assert metrics.messages_received == 5
      assert metrics.unique_users == 5
      assert metrics.uptime > 0
      assert is_list(metrics.recent_messages)
      assert length(metrics.recent_messages) == 5
    end
    
    test "emits telemetry events", %{agent_id: agent_id} do
      # Attach telemetry handler
      handler_id = "test_telemetry_#{System.unique_integer([:positive])}"
      
      :telemetry.attach(
        handler_id,
        [:vsm, :telegram, :message, :received],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )
      
      # Send a message
      message = %{
        "message_id" => 789,
        "text" => "Telemetry test",
        "chat" => %{"id" => "test_chat"},
        "from" => %{"id" => "user123"}
      }
      
      TelegramAgent.handle_message(agent_id, message)
      
      # Verify telemetry was emitted
      assert_receive {:telemetry_event, measurements, metadata}, 500
      assert metadata.agent_id == agent_id
      assert measurements.count == 1
      
      # Cleanup
      :telemetry.detach(handler_id)
    end
  end
end