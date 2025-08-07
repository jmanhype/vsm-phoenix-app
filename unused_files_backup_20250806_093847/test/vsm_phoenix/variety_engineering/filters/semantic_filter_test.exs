defmodule VsmPhoenix.VarietyEngineering.Filters.SemanticFilterTest do
  @moduledoc """
  Test suite for Semantic Filter (S4→S3).
  Tests content analysis, categorization, and semantic filtering.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Filters.SemanticFilter
  
  describe "content categorization" do
    test "categorizes messages by content patterns" do
      messages = [
        %{id: 1, text: "CPU usage at 95%, memory exhausted", category: nil},
        %{id: 2, text: "User john.doe logged in successfully", category: nil},
        %{id: 3, text: "Database connection failed: timeout", category: nil},
        %{id: 4, text: "Temperature sensor reading: 72F", category: nil},
        %{id: 5, text: "Deployment completed for version 2.1.0", category: nil}
      ]
      
      filter = SemanticFilter.new(
        categories: [:performance, :security, :error, :telemetry, :deployment],
        auto_categorize: true
      )
      
      categorized = SemanticFilter.categorize(filter, messages)
      
      assert Enum.find(categorized, &(&1.id == 1)).category == :performance
      assert Enum.find(categorized, &(&1.id == 2)).category == :security
      assert Enum.find(categorized, &(&1.id == 3)).category == :error
      assert Enum.find(categorized, &(&1.id == 4)).category == :telemetry
      assert Enum.find(categorized, &(&1.id == 5)).category == :deployment
    end
    
    test "filters by allowed categories" do
      messages = [
        %{id: 1, text: "Error: disk full", category: :error},
        %{id: 2, text: "Info: cache cleared", category: :info},
        %{id: 3, text: "Warning: high latency", category: :warning},
        %{id: 4, text: "Debug: entering function", category: :debug}
      ]
      
      # Only allow errors and warnings
      filter = SemanticFilter.new(allowed_categories: [:error, :warning])
      filtered = SemanticFilter.apply(filter, messages)
      
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn msg ->
        msg.category in [:error, :warning]
      end)
    end
    
    test "keyword-based filtering" do
      messages = [
        %{id: 1, text: "Critical failure in authentication module"},
        %{id: 2, text: "Routine maintenance completed"},
        %{id: 3, text: "Emergency shutdown initiated"},
        %{id: 4, text: "Daily backup successful"},
        %{id: 5, text: "Security breach detected"}
      ]
      
      filter = SemanticFilter.new(
        must_contain: ["critical", "emergency", "security", "breach"],
        must_not_contain: ["routine", "daily", "successful"]
      )
      
      filtered = SemanticFilter.apply(filter, messages)
      
      assert length(filtered) == 3
      assert Enum.map(filtered, & &1.id) == [1, 3, 5]
    end
  end
  
  describe "pattern matching" do
    test "regex pattern filtering" do
      messages = [
        %{id: 1, text: "Error code: ERR-1234"},
        %{id: 2, text: "Status: OK"},
        %{id: 3, text: "Error code: ERR-5678"},
        %{id: 4, text: "Warning: WRN-9012"},
        %{id: 5, text: "Info: System healthy"}
      ]
      
      # Filter for error codes
      filter = SemanticFilter.new(
        patterns: [~r/ERR-\d{4}/]
      )
      
      filtered = SemanticFilter.apply(filter, messages)
      
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn msg ->
        String.contains?(msg.text, "ERR-")
      end)
    end
    
    test "complex pattern combinations" do
      messages = [
        %{id: 1, text: "2024-01-15 10:30:45 ERROR Database connection lost"},
        %{id: 2, text: "2024-01-15 10:31:00 INFO Attempting reconnection"},
        %{id: 3, text: "2024-01-15 10:31:05 ERROR Connection failed"},
        %{id: 4, text: "User message: ERROR please help"},  # Not a log
        %{id: 5, text: "2024-01-15 10:32:00 WARN High memory usage"}
      ]
      
      # Filter for actual error logs (not just containing "ERROR")
      filter = SemanticFilter.new(
        patterns: [
          ~r/^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+ERROR/
        ]
      )
      
      filtered = SemanticFilter.apply(filter, messages)
      
      assert length(filtered) == 2
      assert Enum.map(filtered, & &1.id) == [1, 3]
    end
  end
  
  describe "semantic similarity" do
    test "groups similar messages" do
      messages = [
        %{id: 1, text: "Database connection timeout after 30 seconds"},
        %{id: 2, text: "Unable to connect to database: timeout"},
        %{id: 3, text: "Network latency spike detected"},
        %{id: 4, text: "DB connection timed out"},
        %{id: 5, text: "High network delay observed"}
      ]
      
      filter = SemanticFilter.new(
        similarity_threshold: 0.7,
        group_similar: true
      )
      
      groups = SemanticFilter.group_similar(filter, messages)
      
      # Should group database messages together
      db_group = Enum.find(groups, fn group ->
        Enum.any?(group, &(&1.id == 1))
      end)
      
      assert length(db_group) >= 2
      assert Enum.all?([1, 2, 4], fn id ->
        Enum.any?(db_group, &(&1.id == id))
      end)
      
      # Network messages in another group
      network_group = Enum.find(groups, fn group ->
        Enum.any?(group, &(&1.id == 3))
      end)
      
      assert length(network_group) >= 2
    end
  end
  
  describe "context-aware filtering" do
    test "filters based on message context" do
      messages = [
        %{
          id: 1,
          text: "Error occurred",
          context: %{source: "payment_service", user_id: 123}
        },
        %{
          id: 2,
          text: "Error occurred",
          context: %{source: "logging_service", user_id: nil}
        },
        %{
          id: 3,
          text: "Success",
          context: %{source: "payment_service", user_id: 456}
        }
      ]
      
      # Filter for payment service errors only
      filter = SemanticFilter.new(
        context_rules: [
          {:source, "payment_service"},
          {:text_contains, "error"}
        ]
      )
      
      filtered = SemanticFilter.apply(filter, messages)
      
      assert length(filtered) == 1
      assert hd(filtered).id == 1
    end
  end
  
  describe "telegram integration" do
    test "analyzes telegram message semantics" do
      telegram_messages = [
        %{
          message: %{text: "/alert Database is down!", chat: %{id: 123}},
          timestamp: ~U[2024-01-15 10:00:00Z]
        },
        %{
          message: %{text: "hello how are you", chat: %{id: 123}},
          timestamp: ~U[2024-01-15 10:00:30Z]
        },
        %{
          message: %{text: "/status production", chat: %{id: 123}},
          timestamp: ~U[2024-01-15 10:01:00Z]
        },
        %{
          message: %{text: "please help me with login", chat: %{id: 456}},
          timestamp: ~U[2024-01-15 10:01:30Z]
        }
      ]
      
      # Filter for operational commands/alerts only
      filter = SemanticFilter.new(
        telegram_mode: true,
        command_filter: true,
        operational_only: true
      )
      
      filtered = SemanticFilter.apply(filter, telegram_messages)
      
      assert length(filtered) == 2
      # Should keep /alert and /status commands
      assert Enum.all?(filtered, fn msg ->
        String.starts_with?(msg.message.text, "/")
      end)
    end
    
    test "detects spam and repetitive messages" do
      messages = for i <- 1..10 do
        text = if rem(i, 3) == 0 do
          "Buy cheap products now! Click here!"
        else
          "Normal message #{i}"
        end
        
        %{
          id: i,
          message: %{text: text, chat: %{id: 123}},
          timestamp: DateTime.add(~U[2024-01-15 10:00:00Z], i * 10, :second)
        }
      end
      
      filter = SemanticFilter.new(
        spam_detection: true,
        repetition_threshold: 2
      )
      
      filtered = SemanticFilter.apply(filter, messages)
      
      # Should filter out spam messages
      assert length(filtered) < 10
      assert Enum.all?(filtered, fn msg ->
        not String.contains?(msg.message.text, "Buy cheap")
      end)
    end
  end
  
  describe "performance" do
    test "efficiently processes large message batches" do
      messages = for i <- 1..10_000 do
        %{
          id: i,
          text: "Message #{i} with #{Enum.random(["error", "info", "warning"])} level",
          category: nil
        }
      end
      
      filter = SemanticFilter.new(
        allowed_categories: [:error, :warning],
        auto_categorize: true
      )
      
      {time, filtered} = :timer.tc(fn ->
        SemanticFilter.apply(filter, messages)
      end)
      
      # Should process quickly
      assert time < 100_000  # 100ms for 10k messages
      assert length(filtered) > 0
    end
  end
  
  describe "ML-based semantic analysis" do
    test "uses embeddings for semantic similarity" do
      messages = [
        %{id: 1, text: "The server is experiencing high CPU usage"},
        %{id: 2, text: "Processor utilization is elevated"},
        %{id: 3, text: "User logged in successfully"},
        %{id: 4, text: "CPU consumption is above normal"},
        %{id: 5, text: "Authentication completed for user"}
      ]
      
      filter = SemanticFilter.new(
        use_embeddings: true,
        similarity_threshold: 0.8
      )
      
      # Find messages similar to "high CPU"
      similar = SemanticFilter.find_similar(
        filter,
        "high CPU load",
        messages
      )
      
      # Should find semantically similar messages
      assert length(similar) >= 3
      similar_ids = Enum.map(similar, & &1.id)
      assert 1 in similar_ids
      assert 2 in similar_ids
      assert 4 in similar_ids
    end
  end
end