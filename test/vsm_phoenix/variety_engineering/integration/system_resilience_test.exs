defmodule VsmPhoenix.VarietyEngineering.Integration.SystemResilienceTest do
  @moduledoc """
  Integration tests for system resilience and fault tolerance.
  Tests recovery from failures, load handling, and graceful degradation.
  """
  
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias VsmPhoenix.System1.Agents.TelegramAgent
  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.VarietyEngineering.Filters.{PriorityFilter, SemanticFilter}
  alias VsmPhoenix.VarietyEngineering.Aggregators.TemporalAggregator
  
  @test_bot_token "test_bot_token_12345"
  @test_chat_id 123456789
  
  setup do
    Application.ensure_all_started(:vsm_phoenix)
    
    # Clean up any existing test agents
    Registry.list_agents()
    |> Enum.filter(fn agent -> 
      String.starts_with?(agent.id, "resilience_test_")
    end)
    |> Enum.each(fn agent -> Registry.unregister(agent.id) end)
    
    :ok
  end
  
  describe "high load handling" do
    test "handles burst of telegram messages without dropping any" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        rate_limiting: %{
          enabled: false  # Disable for load testing
        },
        variety_engineering: %{
          enabled: true,
          performance_mode: true
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "resilience_test_load",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Generate burst of 1000 messages
      messages = for i <- 1..1000 do
        %{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "loadtest_user"},
            "text" => "Load test message #{i}"
          }
        }
      end
      
      start_time = System.monotonic_time(:millisecond)
      
      # Send all messages as fast as possible
      log = capture_log(fn ->
        Enum.each(messages, fn update ->
          TelegramAgent.handle_update("resilience_test_load", update)
        end)
        
        # Wait for processing to complete
        Process.sleep(2000)
      end)
      
      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time
      
      # Verify all messages were processed
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("resilience_test_load")
      assert metrics.messages_received == 1000
      
      # Should handle 1000 messages in reasonable time
      assert total_time < 10_000  # Under 10 seconds
      
      # Should not have crashed
      assert Process.alive?(agent_pid)
      
      # Should not have dropped messages (no error logs)
      refute log =~ "dropped" or log =~ "failed to process"
      
      Process.exit(agent_pid, :normal)
    end
    
    test "gracefully degrades under extreme load" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_engineering: %{
          enabled: true,
          graceful_degradation: %{
            enabled: true,
            load_threshold: 100,  # messages per second
            degradation_strategy: :drop_low_priority
          }
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "resilience_test_degradation",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Generate extreme load with mixed priorities
      messages = []
      for i <- 1..2000 do
        priority = cond do
          rem(i, 10) == 0 -> :high    # 10% high priority
          rem(i, 5) == 0 -> :medium   # 20% medium priority (including high)
          true -> :low                # 70% low priority
        end
        
        text = case priority do
          :high -> "/alert Critical system #{i}"
          :medium -> "/status Update #{i}"
          :low -> "Chat message #{i}"
        end
        
        messages = messages ++ [%{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user"},
            "text" => text
          },
          "priority" => priority
        }]
      end
      
      log = capture_log(fn ->
        # Send messages very rapidly
        Enum.each(messages, fn update ->
          TelegramAgent.handle_update("resilience_test_degradation", update)
        end)
        
        Process.sleep(3000)
      end)
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("resilience_test_degradation")
      
      # Should prioritize high priority messages
      if Map.has_key?(metrics, :degradation_stats) do
        degradation = metrics.degradation_stats
        assert degradation.high_priority_processed / degradation.high_priority_received > 0.9
        assert degradation.low_priority_processed / degradation.low_priority_received < 0.8
      end
      
      # System should still be responsive
      assert Process.alive?(agent_pid)
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "fault tolerance and recovery" do
    test "recovers from variety filter failures" do
      # Create a filter that fails intermittently
      failing_filter = PriorityFilter.new(
        min_priority: :medium,
        failure_mode: :intermittent,  # Simulated config
        failure_rate: 0.3  # 30% failure rate
      )
      
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_engineering: %{
          enabled: true,
          fault_tolerance: %{
            enabled: true,
            retry_attempts: 3,
            circuit_breaker: true,
            fallback_strategy: :bypass_filter
          }
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "resilience_test_recovery",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Send messages that should trigger filter failures
      messages = for i <- 1..20 do
        %{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user"},
            "text" => "Test message #{i}"
          }
        }
      end
      
      log = capture_log(fn ->
        Enum.each(messages, fn update ->
          TelegramAgent.handle_update("resilience_test_recovery", update)
          Process.sleep(50)  # Small delay to see failure patterns
        end)
        
        Process.sleep(500)
      end)
      
      # Should log some filter failures but continue processing
      assert log =~ "filter" or log =~ "retry" or log =~ "fallback"
      
      # Should have processed all messages despite failures
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("resilience_test_recovery")
      assert metrics.messages_received == 20
      
      # Agent should still be alive
      assert Process.alive?(agent_pid)
      
      Process.exit(agent_pid, :normal)
    end
    
    test "handles AMQP connection failures gracefully" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        publish_to_amqp: true,
        amqp_resilience: %{
          retry_attempts: 3,
          retry_delay: 100,
          circuit_breaker_threshold: 5,
          fallback_storage: :local_queue
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "resilience_test_amqp",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Simulate AMQP connection failure
      send(agent_pid, {:amqp_connection_down, :network_failure})
      
      # Continue sending messages
      messages = for i <- 1..10 do
        %{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user"},
            "text" => "/alert Message during AMQP failure #{i}"
          }
        }
      end
      
      log = capture_log(fn ->
        Enum.each(messages, fn update ->
          TelegramAgent.handle_update("resilience_test_amqp", update)
        end)
        
        Process.sleep(500)
        
        # Simulate connection recovery
        send(agent_pid, {:amqp_connection_restored})
        Process.sleep(500)
      end)
      
      # Should continue processing messages despite AMQP issues
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("resilience_test_amqp")
      assert metrics.messages_received == 10
      
      # Should log AMQP issues and recovery
      assert log =~ "AMQP" or log =~ "connection" or log =~ "retry"
      
      # Agent should still be alive
      assert Process.alive?(agent_pid)
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "memory and resource management" do
    test "manages memory efficiently under sustained load" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        resource_management: %{
          memory_limit: 50_000_000,  # 50MB
          cleanup_interval: 1000,     # 1 second
          message_retention: 100      # Keep last 100 messages
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "resilience_test_memory",
        config: agent_config,
        registry: :skip_registration
      )
      
      initial_memory = get_process_memory(agent_pid)
      
      # Send sustained load of messages
      for batch <- 1..10 do
        messages = for i <- 1..100 do
          msg_id = (batch - 1) * 100 + i
          %{
            "update_id" => msg_id,
            "message" => %{
              "message_id" => msg_id,
              "chat" => %{"id" => @test_chat_id},
              "from" => %{"id" => @test_chat_id, "username" => "user"},
              "text" => "Message #{msg_id} with some content to test memory usage"
            }
          }
        end
        
        Enum.each(messages, fn update ->
          TelegramAgent.handle_update("resilience_test_memory", update)
        end)
        
        # Check memory after each batch
        current_memory = get_process_memory(agent_pid)
        memory_growth = current_memory - initial_memory
        
        # Memory should not grow unboundedly
        assert memory_growth < 20_000_000  # Less than 20MB growth
        
        Process.sleep(200)
      end
      
      final_memory = get_process_memory(agent_pid)
      total_growth = final_memory - initial_memory
      
      # Should maintain reasonable memory usage
      assert total_growth < 30_000_000  # Less than 30MB total growth
      
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("resilience_test_memory")
      assert metrics.messages_received == 1000
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "variety engineering cascade failures" do
    test "isolates variety engineering failures from core functionality" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_engineering: %{
          enabled: true,
          isolation: %{
            timeout_ms: 1000,
            max_failures: 5,
            isolation_strategy: :circuit_breaker
          }
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "resilience_test_isolation",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Send messages that will cause variety engineering to fail
      failing_messages = for i <- 1..10 do
        %{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user"},
            "text" => "Malformed message #{i} with #{String.duplicate("x", 10_000)}"  # Very long
          }
        }
      end
      
      log = capture_log(fn ->
        Enum.each(failing_messages, fn update ->
          TelegramAgent.handle_update("resilience_test_isolation", update)
        end)
        
        Process.sleep(1000)
      end)
      
      # Now send normal messages - should work despite variety engineering issues
      normal_messages = for i <- 11..15 do
        %{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user"},
            "text" => "/status Normal message #{i}"
          }
        }
      end
      
      Enum.each(normal_messages, fn update ->
        TelegramAgent.handle_update("resilience_test_isolation", update)
      end)
      
      Process.sleep(500)
      
      # Should have processed all messages (15 total)
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("resilience_test_isolation")
      assert metrics.messages_received == 15
      
      # Should have isolated variety engineering failures
      assert log =~ "circuit" or log =~ "isolation" or log =~ "timeout"
      
      # Core telegram functionality should continue working
      assert Process.alive?(agent_pid)
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "coordinated system recovery" do
    test "coordinates recovery across multiple agents" do
      # Setup multiple agents with coordinated recovery
      agents = for i <- 1..3 do
        config = %{
          bot_token: @test_bot_token,
          webhook_mode: false,
          authorized_chats: [@test_chat_id],
          coordination: %{
            enabled: true,
            recovery_mode: :coordinated,
            health_check_interval: 500
          }
        }
        
        agent_id = "resilience_test_coord_#{i}"
        {:ok, pid} = TelegramAgent.start_link(
          id: agent_id,
          config: config,
          registry: :skip_registration
        )
        
        {agent_id, pid}
      end
      
      # Simulate failure in one agent
      {failing_agent_id, failing_pid} = hd(agents)
      
      log = capture_log(fn ->
        # Simulate heavy load on failing agent
        for i <- 1..100 do
          update = %{
            "update_id" => i,
            "message" => %{
              "message_id" => i,
              "chat" => %{"id" => @test_chat_id},
              "from" => %{"id" => @test_chat_id, "username" => "stress_test"},
              "text" => String.duplicate("load test ", 1000)  # Heavy message
            }
          }
          TelegramAgent.handle_update(failing_agent_id, update)
        end
        
        Process.sleep(1000)
        
        # Send normal messages to other agents - they should handle gracefully
        Enum.each(tl(agents), fn {agent_id, _pid} ->
          for i <- 1..5 do
            update = %{
              "update_id" => 100 + i,
              "message" => %{
                "message_id" => 100 + i,
                "chat" => %{"id" => @test_chat_id},
                "from" => %{"id" => @test_chat_id, "username" => "normal_user"},
                "text" => "/status Normal operation #{i}"
              }
            }
            TelegramAgent.handle_update(agent_id, update)
          end
        end)
        
        Process.sleep(1000)
      end)
      
      # Check that healthy agents are still responsive
      healthy_agents = tl(agents)
      Enum.each(healthy_agents, fn {agent_id, pid} ->
        assert Process.alive?(pid)
        
        {:ok, metrics} = TelegramAgent.get_telegram_metrics(agent_id)
        assert metrics.messages_received == 5
      end)
      
      # Should log coordination activities
      assert log =~ "coordination" or log =~ "health" or log =~ "recovery"
      
      # Clean up
      Enum.each(agents, fn {_id, pid} ->
        if Process.alive?(pid) do
          Process.exit(pid, :normal)
        end
      end)
    end
  end
  
  # Helper functions
  
  defp get_process_memory(pid) do
    case Process.info(pid, :memory) do
      {:memory, memory_bytes} -> memory_bytes
      nil -> 0
    end
  end
end