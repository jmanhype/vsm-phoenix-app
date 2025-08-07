defmodule VsmPhoenix.VarietyEngineering.Filters.PriorityFilterTest do
  @moduledoc """
  Test suite for Priority Filter (S5→S4).
  Tests filtering of messages based on priority levels.
  """
  
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.VarietyEngineering.Filters.PriorityFilter
  
  describe "priority filtering" do
    test "filters messages by priority threshold" do
      messages = [
        %{id: 1, priority: :critical, content: "System failure"},
        %{id: 2, priority: :high, content: "Performance degradation"},
        %{id: 3, priority: :medium, content: "Configuration change"},
        %{id: 4, priority: :low, content: "Status update"},
        %{id: 5, priority: :info, content: "Diagnostic info"}
      ]
      
      # Filter for high priority and above
      filter = PriorityFilter.new(min_priority: :high)
      filtered = PriorityFilter.apply(filter, messages)
      
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn msg -> 
        msg.priority in [:critical, :high]
      end)
    end
    
    test "handles numeric priority levels" do
      messages = [
        %{id: 1, priority: 5, content: "P5 - Critical"},
        %{id: 2, priority: 4, content: "P4 - High"},
        %{id: 3, priority: 3, content: "P3 - Medium"},
        %{id: 4, priority: 2, content: "P2 - Low"},
        %{id: 5, priority: 1, content: "P1 - Info"}
      ]
      
      # Filter for priority 3 and above
      filter = PriorityFilter.new(min_priority: 3)
      filtered = PriorityFilter.apply(filter, messages)
      
      assert length(filtered) == 3
      assert Enum.all?(filtered, fn msg -> msg.priority >= 3 end)
    end
    
    test "handles missing priority field" do
      messages = [
        %{id: 1, priority: :high, content: "Has priority"},
        %{id: 2, content: "No priority field"},
        %{id: 3, priority: nil, content: "Nil priority"},
        %{id: 4, priority: :low, content: "Low priority"}
      ]
      
      filter = PriorityFilter.new(min_priority: :medium, default_priority: :low)
      filtered = PriorityFilter.apply(filter, messages)
      
      # Only the high priority message passes
      assert length(filtered) == 1
      assert hd(filtered).id == 1
    end
    
    test "dynamic priority adjustment" do
      messages = [
        %{id: 1, priority: :medium, source: "critical_system", content: "Alert"},
        %{id: 2, priority: :low, keywords: ["emergency", "failure"], content: "Emergency!"},
        %{id: 3, priority: :medium, content: "Normal update"},
        %{id: 4, priority: :low, age_seconds: 3600, content: "Old message"}
      ]
      
      # Filter with dynamic rules
      filter = PriorityFilter.new(
        min_priority: :high,
        boost_rules: [
          {:source_match, "critical_", 2},  # Boost by 2 levels
          {:keyword_match, ["emergency", "urgent"], 2},
          {:age_threshold, 1800, -1}  # Decrease old messages
        ]
      )
      
      filtered = PriorityFilter.apply(filter, messages)
      
      # Messages 1 and 2 should be boosted to high
      assert length(filtered) == 2
      assert Enum.find(filtered, &(&1.id == 1))
      assert Enum.find(filtered, &(&1.id == 2))
    end
  end
  
  describe "priority statistics" do
    test "tracks priority distribution" do
      messages = for i <- 1..100 do
        %{
          id: i,
          priority: Enum.random([:critical, :high, :medium, :low, :info]),
          content: "Message #{i}"
        }
      end
      
      filter = PriorityFilter.new(min_priority: :medium, track_stats: true)
      filtered = PriorityFilter.apply(filter, messages)
      
      stats = PriorityFilter.get_stats(filter)
      
      assert stats.total_processed == 100
      assert stats.total_passed == length(filtered)
      assert stats.priority_breakdown[:critical] >= 0
      assert stats.priority_breakdown[:high] >= 0
      assert stats.filter_rate > 0 and stats.filter_rate < 1
    end
  end
  
  describe "performance" do
    test "efficiently filters large message batches" do
      messages = for i <- 1..10_000 do
        %{
          id: i,
          priority: rem(i, 5) + 1,
          content: "Message #{i}"
        }
      end
      
      filter = PriorityFilter.new(min_priority: 4)
      
      {time, filtered} = :timer.tc(fn ->
        PriorityFilter.apply(filter, messages)
      end)
      
      # Should filter to ~40% of messages (priorities 4 and 5)
      assert length(filtered) == 4000
      
      # Should be very fast (< 1ms per 1000 messages)
      assert time < 10_000  # 10ms for 10k messages
    end
  end
  
  describe "integration with telegram agent" do
    test "filters telegram messages by priority" do
      telegram_messages = [
        %{
          update_id: 1,
          message: %{
            text: "/alert System down!",
            chat: %{id: 123},
            from: %{id: 456}
          },
          priority: :critical  # Extracted from /alert command
        },
        %{
          update_id: 2,
          message: %{
            text: "Hello bot",
            chat: %{id: 123},
            from: %{id: 456}
          },
          priority: :low  # Regular message
        },
        %{
          update_id: 3,
          message: %{
            text: "/status",
            chat: %{id: 123},
            from: %{id: 789}
          },
          priority: :medium  # Status command
        }
      ]
      
      filter = PriorityFilter.new(
        min_priority: :medium,
        telegram_mode: true
      )
      
      filtered = PriorityFilter.apply(filter, telegram_messages)
      
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn msg ->
        msg.priority in [:critical, :medium]
      end)
    end
  end
end