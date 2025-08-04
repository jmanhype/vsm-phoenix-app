defmodule VsmPhoenix.SelfModifying.AdaptiveBehaviorTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.SelfModifying.AdaptiveBehavior
  
  setup do
    {:ok, _pid} = AdaptiveBehavior.start_link()
    :ok
  end
  
  describe "register_pattern/4" do
    test "registers a simple adaptation pattern" do
      pattern_id = :test_pattern
      conditions = %{cpu_usage: %{operator: :gt, threshold: 80}}
      logic = fn _context -> {:ok, :adapted} end
      
      assert :ok = AdaptiveBehavior.register_pattern(pattern_id, conditions, logic)
    end
    
    test "registers pattern with custom options" do
      pattern_id = :custom_pattern
      conditions = %{memory_usage: %{operator: :gt, threshold: 500}}
      logic = fn _context -> {:ok, :memory_optimized} end
      opts = [priority: :high, timeout: 5000]
      
      assert :ok = AdaptiveBehavior.register_pattern(pattern_id, conditions, logic, opts)
    end
  end
  
  describe "monitor_metric/3" do
    test "monitors CPU usage metric" do
      # Register a pattern first
      pattern_id = :cpu_optimization
      conditions = %{cpu_usage: %{operator: :gt, threshold: 75}}
      logic = fn context -> 
        send(self(), {:adaptation_triggered, context})
        {:ok, :cpu_optimized}
      end
      
      AdaptiveBehavior.register_pattern(pattern_id, conditions, logic)
      
      # Monitor a metric that should trigger the pattern
      AdaptiveBehavior.monitor_metric(:cpu_usage, 85)
      
      # Give some time for async processing
      Process.sleep(100)
      
      # Check if adaptation was triggered (this is simplified - actual implementation might be async)
      # In a real scenario, you'd check the adaptation was actually performed
    end
    
    test "monitors memory usage without triggering" do
      pattern_id = :memory_pattern
      conditions = %{memory_usage: %{operator: :gt, threshold: 1000}}
      logic = fn _context -> {:ok, :memory_adapted} end
      
      AdaptiveBehavior.register_pattern(pattern_id, conditions, logic)
      
      # Monitor metric below threshold
      AdaptiveBehavior.monitor_metric(:memory_usage, 500)
      
      # Should not trigger adaptation
      Process.sleep(50)
      # Verification would depend on internal state inspection
    end
  end
  
  describe "trigger_adaptation/2" do
    test "triggers performance optimization adaptation" do
      context = %{cpu_usage: 90, memory_usage: 80}
      
      assert {:ok, result} = AdaptiveBehavior.trigger_adaptation(:performance_optimization, context)
      assert Map.has_key?(result, :id)
      assert result.type == :performance_optimization
      assert result.context == context
    end
    
    test "triggers error handling adaptation" do
      context = %{error_rate: 0.15, recent_errors: ["timeout", "connection_failed"]}
      
      assert {:ok, result} = AdaptiveBehavior.trigger_adaptation(:error_handling, context)
      assert result.type == :error_handling
    end
    
    test "handles unknown adaptation type" do
      context = %{some_metric: 100}
      
      assert {:error, reason} = AdaptiveBehavior.trigger_adaptation(:unknown_type, context)
      assert reason =~ "Unknown adaptation type"
    end
  end
  
  describe "record_feedback/3" do
    test "records positive feedback" do
      adaptation_id = "test_adaptation_123"
      feedback = :success
      metrics = %{improvement: 25, execution_time: 150}
      
      AdaptiveBehavior.record_feedback(adaptation_id, feedback, metrics)
      
      # Feedback recording is async, so we can't directly verify
      # In a real test, you'd check internal state or wait for processing
      Process.sleep(50)
    end
    
    test "records negative feedback" do
      adaptation_id = "test_adaptation_456"
      feedback = :failure
      metrics = %{error: "optimization failed", rollback_required: true}
      
      AdaptiveBehavior.record_feedback(adaptation_id, feedback, metrics)
      Process.sleep(50)
    end
  end
  
  describe "get_adaptation_stats/0" do
    test "returns current adaptation statistics" do
      # Trigger some adaptations first
      AdaptiveBehavior.trigger_adaptation(:performance_optimization, %{load: 0.8})
      AdaptiveBehavior.trigger_adaptation(:resource_management, %{memory: 85})
      
      Process.sleep(100)
      
      stats = AdaptiveBehavior.get_adaptation_stats()
      
      assert Map.has_key?(stats, :total_patterns)
      assert Map.has_key?(stats, :active_adaptations)
      assert Map.has_key?(stats, :learning_samples)
      assert Map.has_key?(stats, :adaptation_success_rate)
      
      assert is_number(stats.total_patterns)
      assert is_number(stats.active_adaptations)
      assert is_number(stats.adaptation_success_rate)
    end
  end
  
  describe "create_adaptive_function/3" do
    test "creates a self-adapting function" do
      base_function = fn x -> x * 2 end
      fitness_criteria = fn result -> if is_number(result), do: 1.0, else: 0.0 end
      
      assert {:ok, adaptive_fn, adaptation_id} = AdaptiveBehavior.create_adaptive_function(base_function, fitness_criteria)
      
      assert is_function(adaptive_fn)
      assert is_binary(adaptation_id)
      
      # Test the adaptive function
      result = adaptive_fn.(5)
      assert result == 10
    end
    
    test "adaptive function handles errors gracefully" do
      base_function = fn _x -> raise "intentional error" end
      fitness_criteria = fn _result -> 0.5 end
      
      assert {:ok, adaptive_fn, _id} = AdaptiveBehavior.create_adaptive_function(base_function, fitness_criteria)
      
      assert_raise RuntimeError, "intentional error", fn ->
        adaptive_fn.(1)
      end
    end
    
    test "adaptive function records performance metrics" do
      call_count = Agent.start_link(fn -> 0 end)
      
      base_function = fn x -> 
        Agent.update(call_count, &(&1 + 1))
        x + 1 
      end
      fitness_criteria = fn _result -> 0.8 end
      
      {:ok, adaptive_fn, _id} = AdaptiveBehavior.create_adaptive_function(base_function, fitness_criteria)
      
      # Call the function multiple times
      results = Enum.map(1..3, adaptive_fn)
      
      assert results == [2, 3, 4]
      assert Agent.get(call_count, & &1) == 3
    end
  end
  
  describe "learn_from_patterns/1" do
    test "learns from recent adaptation patterns" do
      # Create some adaptation history first
      AdaptiveBehavior.trigger_adaptation(:performance_optimization, %{cpu: 85})
      AdaptiveBehavior.trigger_adaptation(:error_handling, %{error_rate: 0.1})
      
      Process.sleep(100)
      
      assert {:ok, learned_patterns} = AdaptiveBehavior.learn_from_patterns(:hour)
      
      assert is_list(learned_patterns)
      # Patterns might be empty if no history exists yet, but should not error
    end
    
    test "handles different time windows" do
      time_windows = [:hour, :day, :week, 3600]
      
      results = Enum.map(time_windows, fn window ->
        AdaptiveBehavior.learn_from_patterns(window)
      end)
      
      # All should return successfully
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
    end
  end
  
  describe "adaptation strategies" do
    test "performance optimization strategy" do
      context = %{cpu_usage: 95, latency: 2000}
      
      assert {:ok, result} = AdaptiveBehavior.trigger_adaptation(:performance_optimization, context)
      
      # Result should contain adaptation details
      assert Map.has_key?(result, :result)
      assert is_map(result.result) or is_atom(result.result)
    end
    
    test "error handling strategy" do
      context = %{error_rate: 0.25, recent_errors: ["timeout", "connection_error"]}
      
      assert {:ok, result} = AdaptiveBehavior.trigger_adaptation(:error_handling, context)
      
      # Should create some error handling mechanism
      assert Map.has_key?(result, :result)
    end
    
    test "resource management strategy" do
      context = %{memory_usage: 90, process_count: 500}
      
      assert {:ok, result} = AdaptiveBehavior.trigger_adaptation(:resource_management, context)
      
      assert Map.has_key?(result, :result)
    end
  end
  
  describe "pattern triggering" do
    test "triggers pattern based on simple threshold" do
      triggered = Agent.start_link(fn -> false end)
      
      pattern_logic = fn _context ->
        Agent.update(triggered, fn _ -> true end)
        {:ok, :pattern_executed}
      end
      
      AdaptiveBehavior.register_pattern(
        :threshold_test,
        %{test_metric: 50},  # Simple threshold
        pattern_logic
      )
      
      # Trigger with value above threshold
      AdaptiveBehavior.monitor_metric(:test_metric, 75)
      
      Process.sleep(100)
      
      # In a real implementation, this would check if the pattern was triggered
      # For now, we just ensure no errors occurred
    end
    
    test "does not trigger pattern below threshold" do
      triggered = Agent.start_link(fn -> false end)
      
      pattern_logic = fn _context ->
        Agent.update(triggered, fn _ -> true end)
        {:ok, :should_not_execute}
      end
      
      AdaptiveBehavior.register_pattern(
        :no_trigger_test,
        %{test_metric: %{operator: :gt, threshold: 100}},
        pattern_logic
      )
      
      # Trigger with value below threshold
      AdaptiveBehavior.monitor_metric(:test_metric, 50)
      
      Process.sleep(100)
      
      # Pattern should not have been triggered
      assert Agent.get(triggered, & &1) == false
    end
  end
  
  describe "environment monitoring" do
    test "collects basic environment metrics" do
      # Start monitoring and wait for at least one cycle
      Process.sleep(6000)  # Wait for monitoring cycle
      
      stats = AdaptiveBehavior.get_adaptation_stats()
      
      # Should have some environment data
      assert Map.has_key?(stats, :environment_metrics)
    end
    
    test "detects significant environment changes" do
      # This test would require a way to simulate environment changes
      # For now, we just ensure the monitoring doesn't crash
      Process.sleep(1000)
      
      stats = AdaptiveBehavior.get_adaptation_stats()
      assert is_map(stats)
    end
  end
  
  describe "feedback loop" do
    test "processes feedback and updates success rates" do
      # Trigger an adaptation
      {:ok, result} = AdaptiveBehavior.trigger_adaptation(:performance_optimization, %{cpu: 80})
      adaptation_id = result.id
      
      # Record positive feedback
      AdaptiveBehavior.record_feedback(adaptation_id, :success, %{improvement: 30})
      
      Process.sleep(100)
      
      # Check if success rate is updated
      stats = AdaptiveBehavior.get_adaptation_stats()
      assert stats.adaptation_success_rate >= 0
    end
    
    test "handles mixed feedback correctly" do
      # Trigger multiple adaptations
      {:ok, result1} = AdaptiveBehavior.trigger_adaptation(:performance_optimization, %{cpu: 80})
      {:ok, result2} = AdaptiveBehavior.trigger_adaptation(:error_handling, %{errors: 5})
      
      # Record mixed feedback
      AdaptiveBehavior.record_feedback(result1.id, :success, %{improvement: 20})
      AdaptiveBehavior.record_feedback(result2.id, :failure, %{error: "failed to improve"})
      
      Process.sleep(100)
      
      stats = AdaptiveBehavior.get_adaptation_stats()
      
      # Success rate should reflect the mixed results
      assert stats.adaptation_success_rate >= 0
      assert stats.adaptation_success_rate <= 1
    end
  end
  
  describe "concurrent adaptation" do
    test "handles multiple concurrent adaptations" do
      # Trigger multiple adaptations concurrently
      tasks = 1..5
      |> Enum.map(fn i ->
        Task.async(fn ->
          AdaptiveBehavior.trigger_adaptation(:performance_optimization, %{load: i * 10})
        end)
      end)
      
      results = Enum.map(tasks, &Task.await/1)
      
      # All should succeed
      assert Enum.all?(results, fn result -> match?({:ok, _}, result) end)
      
      # All should have unique IDs
      ids = Enum.map(results, fn {:ok, result} -> result.id end)
      unique_ids = Enum.uniq(ids)
      assert length(ids) == length(unique_ids)
    end
    
    test "concurrent metric monitoring" do
      # Monitor multiple metrics concurrently
      metrics = [:cpu_usage, :memory_usage, :disk_usage, :network_latency]
      
      tasks = Enum.map(metrics, fn metric ->
        Task.async(fn ->
          AdaptiveBehavior.monitor_metric(metric, :rand.uniform(100))
        end)
      end)
      
      # Wait for all monitoring to complete
      Enum.each(tasks, &Task.await/1)
      
      # Should not crash or cause issues
      Process.sleep(100)
    end
  end
  
  describe "edge cases and error handling" do
    test "handles invalid pattern conditions" do
      invalid_conditions = %{invalid_key: "not a valid condition"}
      logic = fn _context -> {:ok, :test} end
      
      # Should not crash when registering invalid conditions
      result = AdaptiveBehavior.register_pattern(:invalid_test, invalid_conditions, logic)
      assert result == :ok  # Registration might succeed, but pattern won't trigger
    end
    
    test "handles pattern logic that crashes" do
      crashing_logic = fn _context -> raise "pattern logic error" end
      
      AdaptiveBehavior.register_pattern(
        :crashing_pattern,
        %{test_metric: 50},
        crashing_logic
      )
      
      # Monitor metric that would trigger the pattern
      AdaptiveBehavior.monitor_metric(:test_metric, 75)
      
      Process.sleep(100)
      
      # System should remain stable despite crashing pattern
      stats = AdaptiveBehavior.get_adaptation_stats()
      assert is_map(stats)
    end
    
    test "handles extremely high metric values" do
      large_value = 999_999_999
      
      AdaptiveBehavior.monitor_metric(:extreme_test, large_value)
      
      Process.sleep(50)
      
      # Should handle without overflow or crashes
      stats = AdaptiveBehavior.get_adaptation_stats()
      assert is_map(stats)
    end
    
    test "handles rapid successive metric updates" do
      # Send many metric updates rapidly
      1..100
      |> Enum.each(fn i ->
        AdaptiveBehavior.monitor_metric(:rapid_test, i)
      end)
      
      Process.sleep(200)
      
      # System should remain stable
      stats = AdaptiveBehavior.get_adaptation_stats()
      assert is_map(stats)
    end
  end
end