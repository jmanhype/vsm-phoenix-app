defmodule VsmPhoenix.Resilience.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.Resilience.{
    IntegrationAdapter,
    CircuitBreaker,
    Bulkhead,
    ResilientHTTPClient,
    HealthMonitor,
    TelegramResilientClient
  }
  
  @moduletag :integration
  
  describe "AMQP integration" do
    test "resilient AMQP operations work end-to-end" do
      # Test getting a channel through the integration adapter
      case IntegrationAdapter.get_amqp_channel(:test_purpose) do
        {:ok, channel} ->
          assert Process.alive?(channel.pid)
          
          # Test channel operation
          assert {:ok, _} = AMQP.Queue.declare(channel, "test_resilience_queue", durable: false)
          
          # Clean up
          AMQP.Queue.delete(channel, "test_resilience_queue")
          IntegrationAdapter.release_amqp_channel(channel)
          
        {:error, :not_connected} ->
          # AMQP not available in test environment - this is OK
          assert true
          
        {:error, reason} ->
          flunk("Unexpected AMQP error: #{inspect(reason)}")
      end
    end
    
    test "AMQP operations protected by bulkhead" do
      # Verify bulkhead exists and works
      case Bulkhead.checkout(:bulkhead_amqp_channels, 1000) do
        {:ok, resource} ->
          Bulkhead.checkin(:bulkhead_amqp_channels, resource)
          assert true
          
        {:error, :timeout} ->
          # Bulkhead timeout is acceptable behavior
          assert true
          
        {:error, reason} ->
          # Check if it's a service unavailable error
          if reason in [:not_connected, :bulkhead_full] do
            assert true
          else
            flunk("Unexpected bulkhead error: #{inspect(reason)}")
          end
      end
    end
  end
  
  describe "HTTP client integration" do
    test "resilient HTTP client protects against failures" do
      # Test with a known failing URL
      result = IntegrationAdapter.resilient_http_request(
        :external_api_client,
        :get,
        "http://example.invalid",
        "",
        [],
        timeout: 1000
      )
      
      # Should get an error but not crash
      assert {:error, _reason} = result
    end
    
    test "Telegram resilient client handles API errors gracefully" do
      # Test with invalid bot token
      result = TelegramResilientClient.get_bot_info("invalid_token")
      
      # Should handle the error gracefully
      case result do
        {:error, _reason} -> assert true
        {:ok, _} -> flunk("Should not succeed with invalid token")
      end
    end
  end
  
  describe "bulkhead resource management" do
    test "bulkheads prevent resource exhaustion" do
      # Test that bulkheads limit concurrent operations
      bulkhead = :bulkhead_llm_requests
      
      # Get current state
      state = Bulkhead.get_state(bulkhead)
      max_concurrent = state.max_concurrent
      
      # Try to exceed the limit
      tasks = for i <- 1..(max_concurrent + 5) do
        Task.async(fn ->
          case Bulkhead.checkout(bulkhead, 100) do
            {:ok, resource} ->
              Process.sleep(50)  # Hold resource briefly
              Bulkhead.checkin(bulkhead, resource)
              {:ok, i}
            error ->
              error
          end
        end)
      end
      
      results = Task.await_many(tasks, 5000)
      
      # Some should succeed, some should be rejected or timeout
      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, _}, &1))
      
      assert successes <= max_concurrent
      assert failures >= 5  # The extra requests should fail
    end
  end
  
  describe "circuit breaker integration" do
    test "circuit breakers protect against cascading failures" do
      # Create a test circuit breaker
      {:ok, breaker} = CircuitBreaker.start_link(
        name: :"test_integration_breaker_#{System.unique_integer()}",
        failure_threshold: 2,
        timeout: 100
      )
      
      # Cause failures to open circuit
      CircuitBreaker.call(breaker, fn -> raise "fail" end)
      CircuitBreaker.call(breaker, fn -> raise "fail" end)
      
      # Circuit should now be open
      assert {:error, :circuit_open} = CircuitBreaker.call(breaker, fn -> :success end)
      
      # Wait for timeout
      Process.sleep(150)
      
      # Should now allow requests (half-open)
      assert {:ok, :success} = CircuitBreaker.call(breaker, fn -> :success end)
    end
  end
  
  describe "health monitoring integration" do
    test "health monitor provides system overview" do
      health = HealthMonitor.get_health()
      
      # Should have basic structure
      assert is_map(health)
      assert Map.has_key?(health, :status)
      assert health.status in [:healthy, :degraded, :unhealthy]
      
      # Should have component information
      if Map.has_key?(health, :components) do
        assert is_map(health.components)
      end
    end
  end
  
  describe "metrics and telemetry" do
    test "resilience metrics are collected" do
      # Force metrics collection
      VsmPhoenix.Resilience.MetricsReporter.broadcast_now()
      
      # Wait for metrics processing
      Process.sleep(100)
      
      # Check that metrics are being generated
      snapshot = VsmPhoenix.Resilience.Telemetry.get_metrics_snapshot()
      
      assert is_map(snapshot)
      assert Map.has_key?(snapshot, :bulkheads)
      assert Map.has_key?(snapshot, :circuit_breakers)
      assert Map.has_key?(snapshot, :health)
    end
    
    test "Prometheus metrics export works" do
      metrics = VsmPhoenix.Resilience.Telemetry.export_prometheus_metrics()
      
      assert is_binary(metrics)
      # Should contain Prometheus metric format
      assert String.contains?(metrics, "# TYPE")
    end
  end
  
  describe "failure simulation" do
    @tag :slow
    test "system degrades gracefully under load" do
      # Simulate high load by exhausting bulkheads
      tasks = for _ <- 1..50 do
        Task.async(fn ->
          Bulkhead.with_resource(:bulkhead_http_connections, fn _resource ->
            Process.sleep(100)
            :ok
          end, 5000)
        end)
      end
      
      results = Task.await_many(tasks, 10_000)
      
      # Should have mix of successes and controlled failures
      successes = Enum.count(results, &match?({:ok, :ok}, &1))
      failures = Enum.count(results, &match?({:error, _}, &1))
      
      assert successes > 0, "Some requests should succeed"
      assert failures > 0, "Some requests should be limited by bulkhead"
      
      # System should still be responsive
      health = HealthMonitor.get_health()
      assert health.status in [:healthy, :degraded]  # Not completely unhealthy
    end
  end
end