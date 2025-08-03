# Test helper for VSM Phoenix application
# Provides utilities and setup for variety engineering and TelegramAgent tests

ExUnit.start()

# Configure test environment
Application.put_env(:vsm_phoenix, :test_mode, true)
Application.put_env(:vsm_phoenix, :telegram_bot_token, "test_token")

defmodule VsmPhoenix.TestHelpers do
  @moduledoc """
  Test helpers for VSM Phoenix variety engineering tests.
  """
  
  def create_test_message(text, opts \\ []) do
    %{
      "update_id" => Keyword.get(opts, :update_id, System.unique_integer([:positive])),
      "message" => %{
        "message_id" => Keyword.get(opts, :message_id, System.unique_integer([:positive])),
        "chat" => %{"id" => Keyword.get(opts, :chat_id, 123456789)},
        "from" => %{
          "id" => Keyword.get(opts, :from_id, 123456789),
          "username" => Keyword.get(opts, :username, "testuser")
        },
        "text" => text,
        "date" => System.system_time(:second)
      }
    }
  end
  
  def create_variety_message(id, priority, category, content) do
    %{
      id: id,
      priority: priority,
      category: category,
      content: content,
      timestamp: System.monotonic_time(:millisecond)
    }
  end
  
  def wait_for_async_processing(timeout \\ 1000) do
    Process.sleep(timeout)
  end
  
  def assert_variety_reduced(before_count, after_count, min_reduction \\ 0.1) do
    reduction_ratio = (before_count - after_count) / before_count
    assert reduction_ratio >= min_reduction, 
      "Expected at least #{min_reduction * 100}% reduction, got #{reduction_ratio * 100}%"
  end
  
  def generate_test_metrics(count, base_value \\ 50) do
    for i <- 1..count do
      %{
        id: i,
        timestamp: i * 1000,
        value: base_value + :rand.uniform() * 20,
        source: "test_source_#{rem(i, 5)}"
      }
    end
  end
end

# Import test helpers
defmodule VsmPhoenix.Case do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      import VsmPhoenix.TestHelpers
    end
  end
end