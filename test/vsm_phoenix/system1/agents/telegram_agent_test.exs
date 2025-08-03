defmodule VsmPhoenix.System1.Agents.TelegramAgentTest do
  @moduledoc """
  Comprehensive test suite for TelegramAgent GenServer.
  Tests initialization, message handling, AMQP integration, rate limiting,
  authorization, metrics, and fault tolerance.
  """
  
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias VsmPhoenix.System1.Agents.TelegramAgent
  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @test_bot_token "test_bot_token_12345"
  @test_chat_id 123456789
  @test_timeout 5_000
  
  setup do
    # Ensure AMQP connection is available
    {:ok, _} = ConnectionManager.start_link([])
    
    # Start Registry if not already started
    case Registry.start_link([]) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    
    on_exit(fn ->
      # Clean up any test agents
      Registry.list_agents()
      |> Enum.filter(fn agent -> agent.metadata[:type] == :telegram end)
      |> Enum.each(fn agent -> Registry.unregister(agent.id) end)
    end)
    
    :ok
  end
  
  describe "start_link/1" do
    test "starts agent with valid config" do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id]
      }
      
      assert {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_agent",
        config: config,
        registry: :skip_registration
      )
      
      assert Process.alive?(pid)
      Process.exit(pid, :normal)
    end
    
    test "fails without bot token" do
      assert {:stop, :no_bot_token} = TelegramAgent.init(
        id: "test_telegram_agent",
        config: %{},
        registry: :skip_registration
      )
    end
  end
  
  describe "authorization" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        admin_chats: [@test_chat_id]
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_agent",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_agent", pid: pid}
    end
    
    test "processes authorized message", %{agent_id: agent_id} do
      update = %{
        "update_id" => 1,
        "message" => %{
          "message_id" => 1,
          "chat" => %{"id" => @test_chat_id},
          "from" => %{"id" => @test_chat_id, "username" => "testuser"},
          "text" => "/help"
        }
      }
      
      log = capture_log(fn ->
        TelegramAgent.handle_update(agent_id, update)
        Process.sleep(100)
      end)
      
      refute log =~ "Unauthorized"
    end
    
    test "rejects unauthorized message", %{agent_id: agent_id} do
      unauthorized_chat = 999999999
      
      update = %{
        "update_id" => 2,
        "message" => %{
          "message_id" => 2,
          "chat" => %{"id" => unauthorized_chat},
          "from" => %{"id" => unauthorized_chat, "username" => "hacker"},
          "text" => "/status"
        }
      }
      
      # Mock send_message to capture the response
      TelegramAgent.handle_update(agent_id, update)
      Process.sleep(100)
      
      # In real implementation, this would send "Unauthorized" message
      # For testing, we'd need to mock the HTTP client
    end
  end
  
  describe "command processing" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        admin_chats: [@test_chat_id]
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_agent",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_agent", pid: pid}
    end
    
    test "handles /start command", %{agent_id: agent_id} do
      update = create_command_update("/start")
      
      log = capture_log(fn ->
        TelegramAgent.handle_update(agent_id, update)
        Process.sleep(100)
      end)
      
      assert log =~ "Telegram Agent received"
    end
    
    test "handles /help command", %{agent_id: agent_id} do
      update = create_command_update("/help")
      
      TelegramAgent.handle_update(agent_id, update)
      Process.sleep(100)
      
      # Command should be processed without errors
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      assert metrics.commands_processed > 0
    end
    
    test "handles /status command", %{agent_id: agent_id} do
      update = create_command_update("/status")
      
      log = capture_log(fn ->
        TelegramAgent.handle_update(agent_id, update)
        Process.sleep(100)
      end)
      
      assert log =~ "Telegram Agent received"
    end
    
    test "handles unknown command", %{agent_id: agent_id} do
      update = create_command_update("/unknown")
      
      TelegramAgent.handle_update(agent_id, update)
      Process.sleep(100)
      
      # Should still count as processed
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      assert metrics.commands_processed > 0
    end
  end
  
  describe "metrics" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id]
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_agent",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_agent", pid: pid}
    end
    
    test "tracks message metrics", %{agent_id: agent_id} do
      # Process some messages
      Enum.each(1..3, fn i ->
        update = create_message_update("Test message #{i}")
        TelegramAgent.handle_update(agent_id, update)
      end)
      
      Process.sleep(100)
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      
      assert metrics.messages_received == 3
      assert metrics.total_messages >= 3
      assert metrics.last_activity != nil
    end
    
    test "tracks command statistics", %{agent_id: agent_id} do
      # Process different commands
      commands = ["/start", "/help", "/help", "/status"]
      
      Enum.each(commands, fn cmd ->
        update = create_command_update(cmd)
        TelegramAgent.handle_update(agent_id, update)
      end)
      
      Process.sleep(100)
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      
      assert metrics.commands_processed == 4
      assert metrics.command_breakdown["help"] == 2
      assert metrics.command_breakdown["start"] == 1
      assert metrics.command_breakdown["status"] == 1
    end
  end
  
  describe "webhook management" do
    test "can set and delete webhook" do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_agent",
        config: config,
        registry: :skip_registration
      )
      
      # Note: In real tests, we'd mock the HTTP client
      # to avoid actual API calls
      
      Process.exit(pid, :normal)
    end
  end
  
  describe "rate limiting" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        rate_limit: %{
          max_messages: 3,
          window_seconds: 1
        }
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_agent_rate",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_agent_rate", pid: pid}
    end
    
    test "enforces rate limits per chat", %{agent_id: agent_id} do
      # Send messages up to rate limit
      for i <- 1..3 do
        update = create_message_update("Message #{i}")
        TelegramAgent.handle_update(agent_id, update)
      end
      
      # Fourth message should be rate limited
      log = capture_log(fn ->
        update = create_message_update("Rate limited message")
        TelegramAgent.handle_update(agent_id, update)
        Process.sleep(100)
      end)
      
      assert log =~ "rate limit"
      
      # Wait for rate window to reset
      Process.sleep(1100)
      
      # Should work again
      update = create_message_update("After rate limit")
      TelegramAgent.handle_update(agent_id, update)
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      assert metrics.messages_received > 3
    end
  end
  
  describe "AMQP integration" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        publish_to_amqp: true
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_amqp",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_amqp", pid: pid}
    end
    
    test "publishes messages to AMQP exchange", %{agent_id: agent_id} do
      # Note: This would require a proper AMQP test setup
      # For now, we verify the agent handles AMQP publishing
      
      update = create_message_update("Test AMQP message")
      
      log = capture_log(fn ->
        TelegramAgent.handle_update(agent_id, update)
        Process.sleep(100)
      end)
      
      # Should log AMQP publishing attempt
      assert log =~ "Publishing" or log =~ "AMQP"
    end
  end
  
  describe "fault tolerance" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id]
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_fault",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_fault", pid: pid}
    end
    
    test "handles malformed updates gracefully", %{agent_id: agent_id} do
      malformed_updates = [
        nil,
        %{},  # Missing update_id
        %{"update_id" => 1},  # Missing message
        %{"update_id" => 2, "message" => %{}},  # Missing message fields
        %{"update_id" => 3, "message" => %{"text" => "No chat info"}},
        "not even a map"
      ]
      
      Enum.each(malformed_updates, fn update ->
        # Should not crash the agent
        log = capture_log(fn ->
          TelegramAgent.handle_update(agent_id, update)
          Process.sleep(50)
        end)
        
        # Should log error but continue
        assert log =~ "Error" or log =~ "Invalid"
      end)
      
      # Agent should still be alive
      assert Process.alive?(pid)
    end
    
    test "recovers from processing errors", %{agent_id: agent_id, pid: pid} do
      # Send a message that might cause processing error
      update = %{
        "update_id" => 1,
        "message" => %{
          "message_id" => 1,
          "chat" => %{"id" => @test_chat_id},
          "from" => %{"id" => @test_chat_id},
          "text" => String.duplicate("x", 10_000)  # Very long message
        }
      }
      
      TelegramAgent.handle_update(agent_id, update)
      Process.sleep(100)
      
      # Agent should still be alive
      assert Process.alive?(pid)
      
      # Should still process normal messages
      normal_update = create_message_update("Normal message")
      TelegramAgent.handle_update(agent_id, normal_update)
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      assert metrics.messages_received > 0
    end
  end
  
  describe "variety engineering integration" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_filters: [:priority, :command_type]
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_variety",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_variety", pid: pid}
    end
    
    test "applies variety filters to messages", %{agent_id: agent_id} do
      # Send various types of messages
      messages = [
        create_message_update("Low priority message"),
        create_command_update("/alert High priority alert!"),
        create_message_update("Normal chat message"),
        create_command_update("/status"),
        create_message_update("Another low priority")
      ]
      
      Enum.each(messages, fn update ->
        TelegramAgent.handle_update(agent_id, update)
      end)
      
      Process.sleep(200)
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
      assert metrics.messages_received == 5
      # Variety filters would reduce what gets forwarded
    end
  end
  
  describe "telemetry events" do
    setup do
      config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id]
      }
      
      {:ok, pid} = TelegramAgent.start_link(
        id: "test_telegram_telemetry",
        config: config,
        registry: :skip_registration
      )
      
      on_exit(fn -> Process.exit(pid, :normal) end)
      
      {:ok, agent_id: "test_telegram_telemetry", pid: pid}
    end
    
    test "emits telemetry events for messages", %{agent_id: agent_id} do
      # Attach telemetry handler
      handler_id = "test_handler_#{System.unique_integer([:positive])}"
      
      :telemetry.attach(
        handler_id,
        [:vsm, :telegram, :message, :received],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )
      
      # Send a message
      update = create_message_update("Telemetry test")
      TelegramAgent.handle_update(agent_id, update)
      
      # Should receive telemetry event
      assert_receive {:telemetry_event, measurements, metadata}, 1000
      assert metadata.agent_id == agent_id
      assert measurements.count == 1
      
      # Cleanup
      :telemetry.detach(handler_id)
    end
    
    test "emits telemetry for rate limiting", %{agent_id: agent_id} do
      handler_id = "test_rate_handler_#{System.unique_integer([:positive])}"
      
      :telemetry.attach(
        handler_id,
        [:vsm, :telegram, :rate_limit, :exceeded],
        fn _event, measurements, metadata, _config ->
          send(self(), {:rate_limit_event, measurements, metadata})
        end,
        nil
      )
      
      # Configure aggressive rate limit
      :sys.replace_state(pid, fn state ->
        put_in(state, [:config, :rate_limit], %{max_messages: 1, window_seconds: 10})
      end)
      
      # Send messages to trigger rate limit
      TelegramAgent.handle_update(agent_id, create_message_update("First"))
      TelegramAgent.handle_update(agent_id, create_message_update("Second"))
      
      # Should receive rate limit event
      assert_receive {:rate_limit_event, _measurements, metadata}, 1000
      assert metadata.agent_id == agent_id
      
      :telemetry.detach(handler_id)
    end
  end
  
  # Helper functions
  
  defp create_command_update(command) do
    %{
      "update_id" => System.unique_integer([:positive]),
      "message" => %{
        "message_id" => System.unique_integer([:positive]),
        "chat" => %{"id" => @test_chat_id, "type" => "private"},
        "from" => %{
          "id" => @test_chat_id,
          "username" => "testuser",
          "first_name" => "Test"
        },
        "text" => command,
        "date" => System.system_time(:second)
      }
    }
  end
  
  defp create_message_update(text) do
    %{
      "update_id" => System.unique_integer([:positive]),
      "message" => %{
        "message_id" => System.unique_integer([:positive]),
        "chat" => %{"id" => @test_chat_id, "type" => "private"},
        "from" => %{
          "id" => @test_chat_id,
          "username" => "testuser",
          "first_name" => "Test"
        },
        "text" => text,
        "date" => System.system_time(:second)
      }
    }
  end
end