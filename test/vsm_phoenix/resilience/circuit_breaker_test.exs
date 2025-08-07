defmodule VsmPhoenix.Resilience.CircuitBreakerTest do
  use ExUnit.Case, async: true
  alias VsmPhoenix.Resilience.CircuitBreaker
  
  setup do
    {:ok, breaker} = CircuitBreaker.start_link(
      name: :"test_breaker_#{System.unique_integer()}",
      failure_threshold: 3,
      success_threshold: 2,
      timeout: 100,  # Short timeout for tests
      reset_timeout: 200
    )
    
    {:ok, breaker: breaker}
  end
  
  describe "circuit breaker states" do
    test "starts in closed state", %{breaker: breaker} do
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :closed
      assert state.failure_count == 0
    end
    
    test "successful calls in closed state", %{breaker: breaker} do
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      assert {:ok, 42} = CircuitBreaker.call(breaker, fn -> 42 end)
      
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :closed
      assert state.failure_count == 0
    end
    
    test "opens after reaching failure threshold", %{breaker: breaker} do
      # Fail 3 times to open the circuit
      for _ <- 1..3 do
        assert {:error, _} = CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :open
      assert state.failure_count == 3
    end
    
    test "rejects calls when open", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Calls should be rejected immediately
      assert {:error, :circuit_open} = CircuitBreaker.call(breaker, fn -> :success end)
    end
    
    test "transitions to half_open after timeout", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Wait for timeout
      Process.sleep(150)
      
      # Next call should go through (half_open state)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :half_open
      assert state.success_count == 1
    end
    
    test "closes after success threshold in half_open", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Wait for timeout
      Process.sleep(150)
      
      # Succeed twice to close the circuit
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
      
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :closed
      assert state.failure_count == 0
      assert state.success_count == 0
    end
    
    test "reopens on failure in half_open", %{breaker: breaker} do
      # Open the circuit
      for _ <- 1..3 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Wait for timeout
      Process.sleep(150)
      
      # Fail once in half_open to reopen
      assert {:error, _} = CircuitBreaker.call(breaker, fn -> raise "boom again" end)
      
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :open
    end
  end
  
  describe "reset functionality" do
    test "reset clears all state", %{breaker: breaker} do
      # Create some failures
      for _ <- 1..2 do
        CircuitBreaker.call(breaker, fn -> raise "boom" end)
      end
      
      # Reset
      CircuitBreaker.reset(breaker)
      
      state = CircuitBreaker.get_state(breaker)
      assert state.state == :closed
      assert state.failure_count == 0
      assert state.success_count == 0
    end
  end
  
  describe "error handling" do
    test "handles different error types", %{breaker: breaker} do
      # Runtime error
      assert {:error, %RuntimeError{}} = CircuitBreaker.call(breaker, fn -> raise "runtime error" end)
      
      # Exit
      assert {:error, {:exit, :boom}} = CircuitBreaker.call(breaker, fn -> exit(:boom) end)
      
      # All count as failures
      state = CircuitBreaker.get_state(breaker)
      assert state.failure_count == 2
    end
  end
  
  describe "state change callbacks" do
    test "calls on_state_change callback", %{breaker: breaker} do
      test_pid = self()
      
      {:ok, cb_breaker} = CircuitBreaker.start_link(
        name: :"callback_breaker_#{System.unique_integer()}",
        failure_threshold: 2,
        timeout: 100,
        on_state_change: fn name, old_state, new_state ->
          send(test_pid, {:state_change, name, old_state, new_state})
        end
      )
      
      # Cause circuit to open
      CircuitBreaker.call(cb_breaker, fn -> raise "boom" end)
      CircuitBreaker.call(cb_breaker, fn -> raise "boom" end)
      
      assert_receive {:state_change, _, :closed, :open}
    end
  end
end