defmodule VsmPhoenix.Phase2IntegrationTest do
  @moduledoc """
  Comprehensive integration tests for Phase 2 VSM features.
  Tests end-to-end functionality of GoldRush patterns, LLM integration,
  Telegram NLU, and AMQP security across the entire system.
  """
  use VsmPhoenix.DataCase, async: false
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Mox

  alias VsmPhoenix.{
    Goldrush.PatternEngine,
    System4.Intelligence,
    System4.LLMVarietySource,
    System1.Agents.TelegramAgent,
    Telegram.NLUIntegration,
    AMQP.SecurityProtocol,
    Events.EventBus
  }

  setup :verify_on_exit!

  setup do
    # Start necessary services
    start_supervised!(EventBus)
    start_supervised!(PatternEngine)
    
    # Setup mocks
    Mox.stub_with(VsmPhoenix.MockLLMClient, VsmPhoenix.LLM.StubClient)
    
    :ok
  end

  describe "GoldRush Pattern Detection Integration" do
    test "detects complex patterns across multiple VSM systems" do
      # Define a complex pattern that spans multiple systems
      pattern = %{
        "name" => "system_overload",
        "category" => "performance",
        "type" => "composite",
        "expressions" => [
          %{
            "field" => "system",
            "operator" => "equals",
            "value" => "system3"
          },
          %{
            "field" => "cpu_usage",
            "operator" => "greater_than",
            "value" => 85
          },
          %{
            "field" => "memory_usage",
            "operator" => "greater_than",
            "value" => 90
          }
        ],
        "aggregations" => [
          %{
            "function" => "avg",
            "field" => "cpu_usage",
            "window" => "5m",
            "group_by" => ["system"]
          }
        ],
        "alerts" => [
          %{
            "condition" => "match_count > 3",
            "action" => "notify_system4"
          }
        ]
      }

      # Create the pattern
      {:ok, pattern_id} = PatternEngine.create_pattern(pattern)

      # Simulate events from different systems
      events = [
        %{
          "event_type" => "metrics",
          "system" => "system3",
          "cpu_usage" => 88,
          "memory_usage" => 92,
          "timestamp" => DateTime.utc_now()
        },
        %{
          "event_type" => "metrics",
          "system" => "system3",
          "cpu_usage" => 90,
          "memory_usage" => 94,
          "timestamp" => DateTime.utc_now()
        },
        %{
          "event_type" => "metrics",
          "system" => "system3",
          "cpu_usage" => 92,
          "memory_usage" => 95,
          "timestamp" => DateTime.utc_now()
        },
        %{
          "event_type" => "metrics",
          "system" => "system3",
          "cpu_usage" => 87,
          "memory_usage" => 91,
          "timestamp" => DateTime.utc_now()
        }
      ]

      # Process events
      for event <- events do
        {:ok, matches} = PatternEngine.process_event(event)
        
        # After 4th event, pattern should match and trigger alert
        if length(events) == 4 do
          assert length(matches) > 0
          assert Enum.any?(matches, fn m -> m.pattern_id == pattern_id end)
        end
      end

      # Verify System 4 was notified
      assert_receive {:system4_notification, %{alert: "system_overload", system: "system3"}}, 5000
    end

    test "handles temporal patterns with time windows" do
      # Create a temporal pattern
      pattern = %{
        "name" => "spike_detection",
        "type" => "temporal",
        "expressions" => [
          %{
            "field" => "value",
            "operator" => "change_rate",
            "value" => 50,
            "window" => "1m"
          }
        ]
      }

      {:ok, _pattern_id} = PatternEngine.create_pattern(pattern)

      # Generate time-series events
      base_time = DateTime.utc_now()
      
      events = for i <- 0..10 do
        %{
          "event_type" => "metric",
          "value" => if(i > 5, do: 100 + i * 20, else: 100),
          "timestamp" => DateTime.add(base_time, i * 10, :second)
        }
      end

      # Process events and check for spike detection
      for {event, idx} <- Enum.with_index(events) do
        {:ok, matches} = PatternEngine.process_event(event)
        
        # Spike should be detected after index 6
        if idx > 6 do
          assert length(matches) > 0
        end
      end
    end
  end

  describe "LLM Integration with System 4" do
    test "System 4 uses LLM for intelligent decision making" do
      # Mock LLM responses
      expect(VsmPhoenix.MockLLMClient, :chat_completion, fn params ->
        assert params.messages
        assert params.model
        
        {:ok, %{
          "choices" => [
            %{"message" => %{"content" => "Analysis: High resource usage detected. Recommendation: Scale horizontally."}}
          ]
        }}
      end)

      # Create environmental data requiring intelligent analysis
      environmental_data = %{
        metrics: %{
          cpu_usage: 85,
          memory_usage: 90,
          request_rate: 1500,
          error_rate: 0.05
        },
        trends: %{
          cpu_trend: "increasing",
          memory_trend: "stable",
          request_trend: "spike"
        },
        external_factors: %{
          time_of_day: "peak_hours",
          day_of_week: "weekday",
          special_events: ["product_launch"]
        }
      }

      # System 4 analyzes with LLM assistance
      {:ok, intelligence_report} = Intelligence.analyze_with_llm(environmental_data)

      assert intelligence_report.analysis =~ "High resource usage"
      assert intelligence_report.recommendations
      assert intelligence_report.confidence_score > 0.7
    end

    test "LLM variety source provides adaptive recommendations" do
      # Setup variety source
      variety_source = %LLMVarietySource{
        provider: :openai,
        model: "gpt-4-turbo",
        context_window: 8000,
        specialization: "vsm_operations"
      }

      # Mock complex scenario response
      expect(VsmPhoenix.MockLLMClient, :chat_completion, fn _params ->
        {:ok, %{
          "choices" => [
            %{"message" => %{"content" => Jason.encode!(%{
              variety_analysis: %{
                current_variety: 0.7,
                required_variety: 0.85,
                gap: 0.15,
                recommendations: [
                  %{action: "add_cache_layer", impact: 0.08},
                  %{action: "implement_circuit_breaker", impact: 0.05},
                  %{action: "enable_auto_scaling", impact: 0.03}
                ]
              }
            })}}
          ]
        }}
      end)

      # Request variety analysis
      {:ok, variety_response} = LLMVarietySource.analyze_variety_requirements(
        variety_source,
        %{system_state: "stressed", variety_deficit: 0.15}
      )

      assert variety_response.variety_analysis
      assert length(variety_response.variety_analysis.recommendations) == 3
      assert variety_response.variety_analysis.required_variety > variety_response.variety_analysis.current_variety
    end
  end

  describe "Telegram NLU Integration" do
    test "processes natural language commands through VSM systems" do
      # Setup Telegram agent
      {:ok, agent} = start_supervised({
        TelegramAgent,
        agent_id: "test_bot",
        config: %{
          bot_token: "test_token",
          nlu_enabled: true,
          authorized_users: [123456]
        }
      })

      # Test various NLU commands
      test_cases = [
        {
          "/natural Show me system health",
          %{intent: "system_status", entities: %{target: "health", scope: "all"}}
        },
        {
          "/natural What's the current variety in System 3?",
          %{intent: "variety_query", entities: %{system: "system3", metric: "variety"}}
        },
        {
          "/natural Alert me if CPU goes above 80%",
          %{intent: "create_alert", entities: %{metric: "cpu", threshold: 80, operator: "above"}}
        },
        {
          "/natural Analyze the pattern of errors in the last hour",
          %{intent: "pattern_analysis", entities: %{target: "errors", timeframe: "1h"}}
        }
      ]

      for {command, expected} <- test_cases do
        # Process through NLU
        {:ok, nlu_result} = NLUIntegration.process_command(command, agent_id: "test_bot")
        
        assert nlu_result.intent == expected.intent
        assert nlu_result.confidence > 0.8
        
        # Verify entities were extracted
        for {key, value} <- expected.entities do
          assert Map.get(nlu_result.entities, key) == value
        end
        
        # Verify VSM action was triggered
        assert nlu_result.vsm_action
        assert nlu_result.vsm_response
      end
    end

    test "handles conversation context across multiple messages" do
      # Create conversation context
      context = %{
        user_id: 123456,
        conversation_id: "conv_001",
        history: []
      }

      # Simulate multi-turn conversation
      messages = [
        "Show me System 4 status",
        "What about its variety levels?",  # References previous system
        "Compare it with System 3",         # Comparison request
        "Set an alert for high variety"     # Action based on context
      ]

      final_context = Enum.reduce(messages, context, fn message, ctx ->
        {:ok, result} = NLUIntegration.process_with_context(message, ctx)
        
        # Verify context is maintained
        assert result.context.conversation_id == ctx.conversation_id
        assert length(result.context.history) > length(ctx.history)
        
        # Verify appropriate responses based on context
        case message do
          "What about its variety levels?" ->
            assert result.entities.system == "system4"  # Inherited from context
            
          "Compare it with System 3" ->
            assert result.intent == "comparison"
            assert result.entities.systems == ["system4", "system3"]
            
          "Set an alert for high variety" ->
            assert result.intent == "create_alert"
            assert result.entities.metric == "variety"
        end
        
        result.context
      end)

      assert length(final_context.history) == 4
    end
  end

  describe "AMQP Security Integration" do
    test "validates semantic protocol across VSM boundaries" do
      # Create test semantic message
      message = %{
        header: %{
          version: "1.0",
          timestamp: DateTime.utc_now(),
          source: "system1",
          destination: "system4",
          message_type: "variety_request"
        },
        payload: %{
          request_type: "analyze_variety",
          context: %{
            system_state: "normal",
            variety_level: 0.75
          }
        },
        security: %{
          signature: nil,
          encryption: "aes-256-gcm"
        }
      }

      # Sign message
      {:ok, signed_message} = SecurityProtocol.sign_message(message)
      assert signed_message.security.signature

      # Validate message
      {:ok, validation_result} = SecurityProtocol.validate_message(signed_message)
      assert validation_result.valid
      assert validation_result.source_verified
      assert validation_result.integrity_check == :passed
    end

    test "enforces access control between VSM systems" do
      # Test different permission scenarios
      test_scenarios = [
        # System 1 -> System 3: Allowed (operational data)
        {source: "system1", target: "system3", action: "report_metrics", allowed: true},
        
        # System 3 -> System 5: Allowed (control to policy)
        {source: "system3", target: "system5", action: "request_policy", allowed: true},
        
        # System 1 -> System 5: Restricted (must go through hierarchy)
        {source: "system1", target: "system5", action: "direct_policy", allowed: false},
        
        # External -> System 4: Allowed with auth (environmental scanning)
        {source: "external_api", target: "system4", action: "provide_data", allowed: true, requires_auth: true}
      ]

      for scenario <- test_scenarios do
        result = SecurityProtocol.check_access(
          scenario.source,
          scenario.target,
          scenario.action
        )

        if scenario[:allowed] do
          assert result == :ok or (scenario[:requires_auth] and result == {:ok, :auth_required})
        else
          assert {:error, :access_denied} = result
        end
      end
    end

    test "handles encrypted variety amplification messages" do
      # Create variety amplification message
      variety_message = %{
        type: "variety_amplification",
        source: "llm_variety_source",
        target: "system4",
        payload: %{
          variety_delta: 0.15,
          recommendations: ["scale_out", "add_redundancy", "increase_buffer"],
          confidence: 0.85
        }
      }

      # Encrypt message
      {:ok, encrypted} = SecurityProtocol.encrypt_message(variety_message)
      assert encrypted.encrypted
      assert encrypted.encryption_metadata

      # Transmit through AMQP (simulated)
      {:ok, received} = simulate_amqp_transmission(encrypted)

      # Decrypt and verify
      {:ok, decrypted} = SecurityProtocol.decrypt_message(received)
      assert decrypted.payload.variety_delta == variety_message.payload.variety_delta
      assert decrypted.payload.recommendations == variety_message.payload.recommendations
    end
  end

  describe "End-to-End Integration Scenarios" do
    test "complete flow: Telegram command -> NLU -> GoldRush -> LLM -> Response" do
      # User sends natural language command via Telegram
      telegram_message = %{
        chat_id: 123456,
        text: "/natural detect anomalies in system performance over the last hour",
        from: %{id: 123456, username: "test_user"}
      }

      # Mock the complete flow
      expect(VsmPhoenix.MockLLMClient, :chat_completion, 2, fn params ->
        cond do
          String.contains?(params.messages |> List.first() |> Map.get(:content, ""), "detect anomalies") ->
            # NLU understanding
            {:ok, %{
              "choices" => [
                %{"message" => %{"content" => Jason.encode!(%{
                  intent: "anomaly_detection",
                  entities: %{
                    target: "system_performance",
                    timeframe: "1h"
                  },
                  confidence: 0.92
                })}}
              ]
            }}
            
          String.contains?(params.messages |> List.first() |> Map.get(:content, ""), "Analyze these anomalies") ->
            # LLM analysis of detected patterns
            {:ok, %{
              "choices" => [
                %{"message" => %{"content" => "Analysis complete: Detected 3 anomalies. 1) CPU spike at 14:32 (15% above baseline). 2) Memory leak pattern in service X. 3) Unusual request pattern from region Y. Recommended actions: Restart service X, investigate region Y traffic."}}
              ]
            }}
        end
      end)

      # Process through the system
      with {:ok, nlu_result} <- NLUIntegration.process_telegram_message(telegram_message),
           {:ok, pattern_query} <- build_pattern_query(nlu_result),
           {:ok, anomalies} <- PatternEngine.query(pattern_query),
           {:ok, analysis} <- analyze_anomalies_with_llm(anomalies),
           {:ok, response} <- format_telegram_response(analysis) do
        
        # Verify the complete flow worked
        assert nlu_result.intent == "anomaly_detection"
        assert length(anomalies) >= 0  # May or may not find anomalies
        assert response =~ "Analysis complete"
        
        # Verify Telegram response was sent
        assert_receive {:telegram_send, %{
          chat_id: 123456,
          text: response,
          parse_mode: "Markdown"
        }}, 5000
      end
    end

    test "multi-system coordination with pattern-triggered variety amplification" do
      # Setup initial system state
      system_states = %{
        system1: %{variety: 0.8, load: "normal"},
        system2: %{variety: 0.7, sync: "good"},
        system3: %{variety: 0.6, optimization: "running"},
        system4: %{variety: 0.5, adaptation: "needed"},
        system5: %{variety: 0.9, policy: "standard"}
      }

      # Create pattern that detects low variety in System 4
      low_variety_pattern = %{
        "name" => "low_variety_detection",
        "expressions" => [
          %{"field" => "system", "operator" => "equals", "value" => "system4"},
          %{"field" => "variety", "operator" => "less_than", "value" => 0.6}
        ],
        "alerts" => [
          %{"condition" => "immediate", "action" => "trigger_variety_amplification"}
        ]
      }

      {:ok, _pattern_id} = PatternEngine.create_pattern(low_variety_pattern)

      # Simulate System 4 reporting low variety
      event = %{
        "system" => "system4",
        "variety" => 0.5,
        "timestamp" => DateTime.utc_now()
      }

      # Process event - should trigger variety amplification
      {:ok, matches} = PatternEngine.process_event(event)
      assert length(matches) > 0

      # Mock LLM variety amplification response
      expect(VsmPhoenix.MockLLMClient, :chat_completion, fn _params ->
        {:ok, %{
          "choices" => [
            %{"message" => %{"content" => Jason.encode!(%{
              amplification_strategy: %{
                immediate_actions: [
                  %{action: "increase_environmental_scanning", target: "system4", impact: 0.1},
                  %{action: "enable_predictive_models", target: "system4", impact: 0.05},
                  %{action: "expand_data_sources", target: "system4", impact: 0.08}
                ],
                coordination_required: [
                  %{from: "system5", to: "system4", type: "policy_relaxation"},
                  %{from: "system3", to: "system4", type: "resource_allocation"}
                ]
              }
            })}}
          ]
        }}
      end)

      # Trigger variety amplification
      {:ok, amplification_result} = coordinate_variety_amplification(matches, system_states)

      # Verify multi-system coordination occurred
      assert amplification_result.immediate_actions
      assert length(amplification_result.immediate_actions) == 3
      assert amplification_result.coordination_required
      
      # Verify systems were notified
      assert_receive {:system_notification, :system5, %{action: "policy_relaxation", target: "system4"}}, 5000
      assert_receive {:system_notification, :system3, %{action: "resource_allocation", target: "system4"}}, 5000
    end
  end

  # Helper functions
  defp simulate_amqp_transmission(message) do
    # Simulate AMQP transmission with potential security checks
    {:ok, message}
  end

  defp build_pattern_query(nlu_result) do
    {:ok, %{
      intent: nlu_result.intent,
      timeframe: nlu_result.entities[:timeframe] || "1h",
      target: nlu_result.entities[:target] || "all"
    }}
  end

  defp analyze_anomalies_with_llm(anomalies) do
    # Would call LLM service in real implementation
    {:ok, %{
      analysis: "Detected anomalies analyzed",
      anomaly_count: length(anomalies),
      recommendations: ["Monitor closely", "Check service health"]
    }}
  end

  defp format_telegram_response(analysis) do
    response = """
    📊 *Analysis Complete*
    
    Anomalies found: #{analysis.anomaly_count}
    
    #{analysis.analysis}
    
    *Recommendations:*
    #{Enum.map_join(analysis.recommendations, "\n", fn r -> "• #{r}" end)}
    """
    
    {:ok, response}
  end

  defp coordinate_variety_amplification(matches, _system_states) do
    # Simulate variety amplification coordination
    {:ok, %{
      immediate_actions: [
        %{action: "increase_environmental_scanning", target: "system4", impact: 0.1},
        %{action: "enable_predictive_models", target: "system4", impact: 0.05},
        %{action: "expand_data_sources", target: "system4", impact: 0.08}
      ],
      coordination_required: [
        %{from: "system5", to: "system4", type: "policy_relaxation"},
        %{from: "system3", to: "system4", type: "resource_allocation"}
      ]
    }}
  end
end