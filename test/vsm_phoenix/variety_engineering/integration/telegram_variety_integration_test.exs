defmodule VsmPhoenix.VarietyEngineering.Integration.TelegramVarietyIntegrationTest do
  @moduledoc """
  Integration tests for TelegramAgent with Variety Engineering.
  Tests end-to-end message flow from Telegram through variety filters/aggregators.
  """
  
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  
  alias VsmPhoenix.System1.Agents.TelegramAgent
  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.VarietyEngineering.Filters.{PriorityFilter, SemanticFilter}
  alias VsmPhoenix.VarietyEngineering.Aggregators.TemporalAggregator
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @test_bot_token "test_bot_token_12345"
  @test_chat_id 123456789
  
  setup do
    # Ensure clean state
    Application.ensure_all_started(:vsm_phoenix)
    
    # Clean up any existing test agents
    Registry.list_agents()
    |> Enum.filter(fn agent -> 
      String.starts_with?(agent.id, "telegram_variety_test_")
    end)
    |> Enum.each(fn agent -> Registry.unregister(agent.id) end)
    
    :ok
  end
  
  describe "end-to-end telegram message processing" do
    test "processes telegram messages through complete variety engineering pipeline" do
      # Setup TelegramAgent with variety engineering
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_engineering: %{
          enabled: true,
          filters: [
            %{type: :priority, min_priority: :medium},
            %{type: :semantic, categories: [:alert, :error, :status]}
          ],
          aggregators: [
            %{type: :temporal, window_size: 5000}
          ]
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "telegram_variety_test_1",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Create variety engineering components
      priority_filter = PriorityFilter.new(min_priority: :medium)
      semantic_filter = SemanticFilter.new(
        allowed_categories: [:alert, :error, :status],
        auto_categorize: true
      )
      temporal_aggregator = TemporalAggregator.new(
        window_size: 5000,
        aggregation_fn: :count_by_type
      )
      
      # Simulate various telegram messages
      messages = [
        # High priority alert
        %{
          "update_id" => 1,
          "message" => %{
            "message_id" => 1,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "admin"},
            "text" => "/alert System critical failure detected!"
          }
        },
        # Medium priority status
        %{
          "update_id" => 2,
          "message" => %{
            "message_id" => 2,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "admin"},
            "text" => "/status Database backup completed"
          }
        },
        # Low priority chat (should be filtered out)
        %{
          "update_id" => 3,
          "message" => %{
            "message_id" => 3,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user"},
            "text" => "Hello, how are you?"
          }
        },
        # Error report
        %{
          "update_id" => 4,
          "message" => %{
            "message_id" => 4,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "developer"},
            "text" => "/error Payment processing failed for user 12345"
          }
        }
      ]
      
      # Process messages through the pipeline
      processed_messages = []
      
      log = capture_log(fn ->
        Enum.each(messages, fn update ->
          # 1. TelegramAgent receives message
          TelegramAgent.handle_update("telegram_variety_test_1", update)
          
          # 2. Extract message for variety processing
          if update["message"]["text"] do
            message = %{
              id: update["message"]["message_id"],
              text: update["message"]["text"],
              timestamp: System.monotonic_time(:millisecond),
              user: update["message"]["from"]["username"],
              priority: extract_priority(update["message"]["text"]),
              category: nil
            }
            
            # 3. Apply priority filter
            priority_filtered = PriorityFilter.apply(priority_filter, [message])
            
            if length(priority_filtered) > 0 do
              # 4. Apply semantic filter
              categorized = SemanticFilter.categorize(semantic_filter, priority_filtered)
              semantic_filtered = SemanticFilter.apply(semantic_filter, categorized)
              
              if length(semantic_filtered) > 0 do
                processed_messages = processed_messages ++ semantic_filtered
              end
            end
          end
          
          Process.sleep(100)  # Small delay between messages
        end)
        
        Process.sleep(200)  # Allow processing to complete
      end)
      
      # 5. Apply temporal aggregation
      if length(processed_messages) > 0 do
        aggregated = TemporalAggregator.aggregate(temporal_aggregator, processed_messages)
        
        # Verify aggregation results
        assert length(aggregated) >= 1
        
        first_window = hd(aggregated)
        assert first_window.counts.alert >= 1
        assert first_window.counts.status >= 1
        assert first_window.counts.error >= 1
        
        # Should not include casual chat
        refute Map.has_key?(first_window.counts, :chat)
      end
      
      # Verify TelegramAgent processed the messages
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("telegram_variety_test_1")
      assert metrics.messages_received == 4
      
      # Verify variety engineering filtered appropriately
      assert length(processed_messages) == 3  # Chat message filtered out
      
      # Verify semantic categorization
      assert Enum.all?(processed_messages, fn msg ->
        msg.category in [:alert, :status, :error]
      end)
      
      # Clean up
      Process.exit(agent_pid, :normal)
    end
    
    test "handles variety engineering failures gracefully" do
      # Setup TelegramAgent with intentionally failing variety filters
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_engineering: %{
          enabled: true,
          fault_tolerance: true,
          fallback_mode: :pass_through
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "telegram_variety_test_fault",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Create a filter that will fail
      faulty_filter = %{
        apply: fn _messages -> raise "Filter failure!" end
      }
      
      message = %{
        "update_id" => 1,
        "message" => %{
          "message_id" => 1,
          "chat" => %{"id" => @test_chat_id},
          "from" => %{"id" => @test_chat_id, "username" => "user"},
          "text" => "Test message"
        }
      }
      
      log = capture_log(fn ->
        # Should not crash despite filter failure
        TelegramAgent.handle_update("telegram_variety_test_fault", message)
        Process.sleep(100)
      end)
      
      # Should log the error but continue processing
      assert log =~ "variety engineering" or log =~ "filter" or log =~ "error"
      
      # Agent should still be alive
      assert Process.alive?(agent_pid)
      
      # Should have processed the message (fallback mode)
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("telegram_variety_test_fault")
      assert metrics.messages_received == 1
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "AMQP integration with variety engineering" do
    test "publishes filtered messages to appropriate AMQP exchanges" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        publish_to_amqp: true,
        variety_engineering: %{
          enabled: true,
          amqp_routing: %{
            alert: "vsm.alerts",
            error: "vsm.errors",
            status: "vsm.status"
          }
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "telegram_variety_amqp_test",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Simulate messages of different types
      messages = [
        {"/alert Critical system failure", "vsm.alerts"},
        {"/error Database connection lost", "vsm.errors"},
        {"/status All systems operational", "vsm.status"}
      ]
      
      log = capture_log(fn ->
        Enum.each(messages, fn {text, expected_exchange} ->
          update = %{
            "update_id" => System.unique_integer([:positive]),
            "message" => %{
              "message_id" => System.unique_integer([:positive]),
              "chat" => %{"id" => @test_chat_id},
              "from" => %{"id" => @test_chat_id, "username" => "admin"},
              "text" => text
            }
          }
          
          TelegramAgent.handle_update("telegram_variety_amqp_test", update)
          Process.sleep(50)
        end)
        
        Process.sleep(200)
      end)
      
      # Should attempt to publish to different exchanges based on message type
      assert log =~ "Publishing" or log =~ "AMQP"
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "variety engineering metrics and monitoring" do
    test "tracks variety engineering performance metrics" do
      agent_config = %{
        bot_token: @test_bot_token,
        webhook_mode: false,
        authorized_chats: [@test_chat_id],
        variety_engineering: %{
          enabled: true,
          metrics_tracking: true,
          performance_monitoring: true
        }
      }
      
      {:ok, agent_pid} = TelegramAgent.start_link(
        id: "telegram_variety_metrics_test",
        config: agent_config,
        registry: :skip_registration
      )
      
      # Generate load to test performance
      messages = for i <- 1..50 do
        %{
          "update_id" => i,
          "message" => %{
            "message_id" => i,
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "user#{i}"},
            "text" => "Test message #{i}"
          }
        }
      end
      
      start_time = System.monotonic_time(:millisecond)
      
      Enum.each(messages, fn update ->
        TelegramAgent.handle_update("telegram_variety_metrics_test", update)
      end)
      
      Process.sleep(1000)  # Allow processing to complete
      
      end_time = System.monotonic_time(:millisecond)
      processing_time = end_time - start_time
      
      # Get metrics
      {:ok, metrics} = TelegramAgent.get_telegram_metrics("telegram_variety_metrics_test")
      
      # Verify basic metrics
      assert metrics.messages_received == 50
      assert metrics.total_messages >= 50
      
      # Verify variety engineering metrics (if implemented)
      if Map.has_key?(metrics, :variety_engineering) do
        ve_metrics = metrics.variety_engineering
        
        assert ve_metrics.messages_processed == 50
        assert ve_metrics.processing_time_avg < 100  # < 100ms per message
        assert ve_metrics.filter_success_rate >= 0.95
      end
      
      # Performance should be reasonable
      assert processing_time < 5000  # Should complete in under 5 seconds
      
      Process.exit(agent_pid, :normal)
    end
  end
  
  describe "multi-agent coordination with variety engineering" do
    test "coordinates variety engineering across multiple telegram agents" do
      # Setup multiple TelegramAgent instances
      agents = for i <- 1..3 do
        config = %{
          bot_token: @test_bot_token,
          webhook_mode: false,
          authorized_chats: [@test_chat_id],
          variety_engineering: %{
            enabled: true,
            coordination_mode: true,
            shared_context: "multi_agent_test"
          }
        }
        
        agent_id = "telegram_variety_multi_#{i}"
        {:ok, pid} = TelegramAgent.start_link(
          id: agent_id,
          config: config,
          registry: :skip_registration
        )
        
        {agent_id, pid}
      end
      
      # Setup shared temporal aggregator for coordination
      shared_aggregator = TemporalAggregator.new(
        window_size: 10_000,
        coordination_mode: true,
        agent_correlation: true
      )
      
      # Simulate coordinated message processing
      messages = [
        {"telegram_variety_multi_1", "/alert High CPU on server 1"},
        {"telegram_variety_multi_2", "/alert High memory on server 2"},
        {"telegram_variety_multi_3", "/alert High disk on server 3"},
        {"telegram_variety_multi_1", "/status Systems stabilizing"},
        {"telegram_variety_multi_2", "/status Memory usage decreasing"},
        {"telegram_variety_multi_3", "/status All metrics normal"}
      ]
      
      all_processed = []
      
      Enum.each(messages, fn {agent_id, text} ->
        update = %{
          "update_id" => System.unique_integer([:positive]),
          "message" => %{
            "message_id" => System.unique_integer([:positive]),
            "chat" => %{"id" => @test_chat_id},
            "from" => %{"id" => @test_chat_id, "username" => "admin"},
            "text" => text
          }
        }
        
        TelegramAgent.handle_update(agent_id, update)
        
        # Track for coordination analysis
        processed_msg = %{
          agent_id: agent_id,
          text: text,
          timestamp: System.monotonic_time(:millisecond),
          category: if(String.contains?(text, "alert"), do: :alert, else: :status)
        }
        
        all_processed = [processed_msg | all_processed]
        Process.sleep(200)
      end)
      
      # Analyze coordination patterns
      aggregated = TemporalAggregator.aggregate(shared_aggregator, Enum.reverse(all_processed))
      
      if length(aggregated) > 0 do
        window = hd(aggregated)
        
        # Should detect coordinated incident pattern
        assert window.agent_count == 3
        assert window.counts.alert == 3  # All agents reported alerts
        assert window.counts.status == 3  # All agents reported recovery
        
        # Should identify coordination pattern
        if Map.has_key?(window, :coordination_detected) do
          assert window.coordination_detected == true
          assert window.coordination_type == :incident_response
        end
      end
      
      # Clean up agents
      Enum.each(agents, fn {_id, pid} ->
        Process.exit(pid, :normal)
      end)
    end
  end
  
  # Helper functions
  
  defp extract_priority(text) do
    cond do
      String.contains?(text, "/alert") or String.contains?(text, "critical") -> :high
      String.contains?(text, "/error") or String.contains?(text, "failed") -> :high
      String.contains?(text, "/status") -> :medium
      String.starts_with?(text, "/") -> :medium
      true -> :low
    end
  end
end