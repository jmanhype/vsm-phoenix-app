defmodule VsmPhoenix.Telegram.NLUIntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Telegram.{NLUService, ConversationManager, IntentMapper}
  
  describe "NLU Integration" do
    test "analyzes natural language status request" do
      # Test various ways to ask for status
      test_cases = [
        {"What's the system status?", :get_status},
        {"How is the VSM doing?", :get_status},
        {"Show me the health of the system", :get_status},
        {"status", :get_status}
      ]
      
      for {text, expected_intent} <- test_cases do
        {:ok, result} = NLUService.analyze_message(text)
        assert result.intent == expected_intent
        assert result.confidence >= 0.7
      end
    end
    
    test "extracts entities from VSM spawn requests" do
      text = "Create a new recursive VSM with 5 agents"
      {:ok, result} = NLUService.analyze_message(text)
      
      assert result.intent == :spawn_vsm
      assert result.entities[:type] == "recursive"
      assert result.entities[:agent_count] == 5
    end
    
    test "maps intents to commands correctly" do
      # Test intent to command mapping
      entities = %{level: "critical", message: "Database is down"}
      {:ok, command_info} = IntentMapper.map_intent_to_command(:send_alert, entities)
      
      assert command_info.command == "/alert"
      assert command_info.args == ["critical", "Database is down"]
      assert command_info.handler == :handle_alert_command
    end
    
    test "handles unknown intents gracefully" do
      text = "Do something completely random that makes no sense"
      {:ok, result} = NLUService.analyze_message(text)
      
      assert result.intent == :unknown
      assert result.confidence < 0.5
    end
    
    test "provides command suggestions for partial input" do
      suggestions = IntentMapper.get_command_suggestions("sta")
      
      assert length(suggestions) > 0
      assert Enum.any?(suggestions, fn s -> s.command == "/status" end)
    end
  end
  
  describe "Conversation Management" do
    setup do
      chat_id = 123456
      user_info = %{
        user_id: "789",
        username: "testuser",
        role: "user"
      }
      
      {:ok, chat_id: chat_id, user_info: user_info}
    end
    
    test "maintains conversation context", %{chat_id: chat_id, user_info: user_info} do
      # Start conversation
      {:ok, _conversation} = ConversationManager.start_conversation(chat_id, user_info)
      
      # Add messages
      {:ok, _} = ConversationManager.add_message(chat_id, :user, "What's the status?", %{
        intent: :get_status
      })
      
      {:ok, _} = ConversationManager.add_message(chat_id, :assistant, "System is healthy", %{})
      
      # Get context
      {:ok, context} = ConversationManager.get_context(chat_id)
      
      assert context.conversation_length == 2
      assert length(context.last_messages) == 2
      assert context.user_id == "789"
    end
    
    test "handles multi-step flows", %{chat_id: chat_id, user_info: user_info} do
      {:ok, _} = ConversationManager.start_conversation(chat_id, user_info)
      
      # Start VSM configuration flow
      {:ok, flow_def} = ConversationManager.set_active_flow(chat_id, :vsm_configuration)
      
      assert flow_def != nil
      assert ConversationManager.has_active_flow?(chat_id)
      
      # Update flow state
      {:ok, _} = ConversationManager.update_flow_state(chat_id, %{
        vsm_type: "recursive",
        agent_count: 5
      })
      
      # Complete flow
      {:ok, result} = ConversationManager.complete_flow(chat_id)
      
      assert result.vsm_type == "recursive"
      assert result.agent_count == 5
      refute ConversationManager.has_active_flow?(chat_id)
    end
  end
  
  describe "Intent Response Formatting" do
    test "formats status response naturally" do
      status_data = %{
        status: %{
          s1: %{status: "healthy"},
          s2: %{status: "healthy"},
          s3: %{status: "warning"},
          s4: %{status: "healthy"},
          s5: %{status: "healthy"}
        }
      }
      
      response = IntentMapper.format_command_response(:get_status, status_data, %{})
      
      assert String.contains?(response, "current system status")
      assert String.contains?(response, "warning")
    end
    
    test "provides helpful error messages" do
      error_result = {:error, "Connection timeout"}
      response = IntentMapper.format_command_response(:spawn_vsm, error_result, %{})
      
      assert String.contains?(response, "couldn't create")
      assert String.contains?(response, "try with different parameters")
    end
  end
end