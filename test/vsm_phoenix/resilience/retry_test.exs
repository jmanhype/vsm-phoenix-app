defmodule VsmPhoenix.Resilience.RetryTest do
  use ExUnit.Case, async: true
  alias VsmPhoenix.Resilience.Retry
  
  describe "successful operations" do
    test "returns result on first success" do
      assert {:ok, :success} = Retry.with_retry(fn -> :success end)
    end
    
    test "does not retry on success" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(fn ->
        :counters.add(counter, 1, 1)
        :success
      end)
      
      assert {:ok, :success} = result
      assert :counters.get(counter, 1) == 1
    end
  end
  
  describe "retry on failures" do
    test "retries on error" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          count = :counters.add(counter, 1, 1)
          if count < 3 do
            raise "not yet"
          else
            :success
          end
        end,
        max_attempts: 5,
        base_backoff: 10
      )
      
      assert {:ok, :success} = result
      assert :counters.get(counter, 1) == 3
    end
    
    test "fails after max attempts" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          raise "always fails"
        end,
        max_attempts: 3,
        base_backoff: 10
      )
      
      assert {:error, {:max_attempts_reached, {:error, %RuntimeError{message: "always fails"}}}} = result
      assert :counters.get(counter, 1) == 3
    end
    
    test "retries on exit" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          count = :counters.add(counter, 1, 1)
          if count < 2 do
            exit(:boom)
          else
            :success
          end
        end,
        max_attempts: 3,
        base_backoff: 10
      )
      
      assert {:ok, :success} = result
      assert :counters.get(counter, 1) == 2
    end
  end
  
  describe "backoff timing" do
    test "exponential backoff increases wait time" do
      start_time = System.monotonic_time(:millisecond)
      
      Retry.with_retry(
        fn -> raise "fail" end,
        max_attempts: 3,
        base_backoff: 50,
        jitter: false
      )
      
      duration = System.monotonic_time(:millisecond) - start_time
      
      # Should wait 50ms after first failure, 100ms after second
      # Total wait time should be at least 150ms
      assert duration >= 150
    end
    
    test "respects max_backoff" do
      start_time = System.monotonic_time(:millisecond)
      
      Retry.with_retry(
        fn -> raise "fail" end,
        max_attempts: 3,
        base_backoff: 100,
        max_backoff: 150,
        backoff_multiplier: 10,  # Would be 1000ms without max
        jitter: false
      )
      
      duration = System.monotonic_time(:millisecond) - start_time
      
      # Should wait 100ms + 150ms (capped) = 250ms
      assert duration >= 250
      assert duration < 400  # Shouldn't wait the full 1000ms
    end
  end
  
  describe "retry conditions" do
    test "only retries specified error types" do
      counter = :counters.new(1, [])
      
      result = Retry.with_retry(
        fn ->
          :counters.add(counter, 1, 1)
          throw(:not_retryable)
        end,
        retry_on: [:error, :exit],  # Not :throw
        max_attempts: 3,
        base_backoff: 10
      )
      
      assert {:error, {:throw, :not_retryable}} = result
      assert :counters.get(counter, 1) == 1  # No retries
    end
  end
  
  describe "callbacks" do
    test "calls on_retry callback" do
      test_pid = self()
      counter = :counters.new(1, [])
      
      Retry.with_retry(
        fn ->
          count = :counters.add(counter, 1, 1)
          if count < 3 do
            raise "retry me"
          else
            :success
          end
        end,
        max_attempts: 5,
        base_backoff: 10,
        on_retry: fn attempt, error, wait_time ->
          send(test_pid, {:retry, attempt, error, wait_time})
        end
      )
      
      assert_receive {:retry, 1, {:error, %RuntimeError{message: "retry me"}}, _}
      assert_receive {:retry, 2, {:error, %RuntimeError{message: "retry me"}}, _}
      refute_receive {:retry, 3, _, _}  # Third attempt succeeds
    end
  end
  
  describe "retry wrapper function" do
    test "create_retry_fn creates reusable retry function" do
      retry_fn = Retry.create_retry_fn(max_attempts: 2, base_backoff: 10)
      
      # Use the wrapper with different functions
      assert {:ok, :a} = retry_fn.(fn -> :a end)
      assert {:ok, :b} = retry_fn.(fn -> :b end)
      
      # Still respects retry logic
      counter = :counters.new(1, [])
      result = retry_fn.(fn ->
        :counters.add(counter, 1, 1)
        raise "fail"
      end)
      
      assert {:error, {:max_attempts_reached, _}} = result
      assert :counters.get(counter, 1) == 2
    end
  end
end