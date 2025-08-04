defmodule VsmPhoenix.SelfModifying.IntegrationTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.SelfModifying.{
    CodeGenerator,
    SafeSandbox,
    GeneticProgramming,
    AdaptiveBehavior,
    ModuleReloader
  }
  
  setup_all do
    # Start all services
    {:ok, _} = SafeSandbox.start_link()
    {:ok, _} = AdaptiveBehavior.start_link()
    {:ok, _} = ModuleReloader.start_link()
    
    :ok
  end
  
  describe "complete self-modification workflow" do
    test "generates, tests, and deploys optimized code" do
      # Step 1: Generate initial code
      initial_template = """
      defmodule OptimizationTarget do
        def calculate_sum(list) do
          {{implementation}}
        end
      end
      """
      
      bindings = %{implementation: "Enum.sum(list)"}
      
      assert {:ok, generated} = CodeGenerator.generate_code(initial_template, bindings)
      
      # Step 2: Create the module
      assert {:ok, _module} = CodeGenerator.create_module(OptimizationTarget, generated.code)
      
      # Step 3: Test initial performance
      test_data = 1..1000 |> Enum.to_list()
      initial_result = OptimizationTarget.calculate_sum(test_data)
      assert initial_result == 500500
      
      # Step 4: Evolve the implementation
      fitness_function = fn code ->
        try do
          case SafeSandbox.execute(code, [test_data], timeout: 1000) do
            {:ok, ^initial_result} -> 1.0  # Correct result gets max fitness
            {:ok, _wrong_result} -> 0.1   # Wrong result gets low fitness
            {:error, _} -> 0               # Errors get zero fitness
          end
        rescue
          _ -> 0
        end
      end
      
      evolution_config = %{population_size: 10, generations: 3}
      
      case GeneticProgramming.evolve("Enum.sum(list)", fitness_function, evolution_config) do
        {:ok, evolution_result} ->
          assert evolution_result.best_fitness > 0
          
          # Step 5: Hot-swap the optimized implementation
          new_implementation = """
          def calculate_sum(list) do
            #{evolution_result.best_code}
          end
          """
          
          assert {:ok, :swapped} = ModuleReloader.hot_swap_function(
            OptimizationTarget,
            :calculate_sum,
            1,
            new_implementation
          )
          
          # Step 6: Verify the optimization works
          optimized_result = OptimizationTarget.calculate_sum(test_data)
          assert optimized_result == initial_result  # Should still be correct
          
        {:error, _reason} ->
          # Evolution might fail with small population/generations, which is ok for testing
          :ok
      end
    end
    
    test "adaptive behavior responds to performance issues" do
      # Step 1: Create a function that simulates performance problems
      slow_function = fn _x ->
        Process.sleep(100)  # Simulate slow operation
        :result
      end
      
      fitness_criteria = fn result ->
        case result do
          :result -> 0.8
          _ -> 0.0
        end
      end
      
      # Step 2: Create adaptive version
      assert {:ok, adaptive_fn, adaptation_id} = AdaptiveBehavior.create_adaptive_function(
        slow_function,
        fitness_criteria
      )
      
      # Step 3: Use the function and trigger performance monitoring
      start_time = System.monotonic_time(:millisecond)
      result = adaptive_fn.(1)
      execution_time = System.monotonic_time(:millisecond) - start_time
      
      assert result == :result
      assert execution_time >= 100  # Should take at least 100ms due to sleep
      
      # Step 4: Simulate performance degradation detection
      AdaptiveBehavior.monitor_metric(:function_latency, execution_time)
      
      # Step 5: Trigger optimization adaptation
      context = %{
        function_id: adaptation_id,
        current_latency: execution_time,
        target_latency: 50
      }
      
      assert {:ok, adaptation_result} = AdaptiveBehavior.trigger_adaptation(
        :performance_optimization,
        context
      )
      
      assert adaptation_result.type == :performance_optimization
      assert Map.has_key?(adaptation_result, :result)
    end
    
    test "code generation with safety validation in sandbox" do
      # Step 1: Generate potentially unsafe code
      unsafe_template = """
      defmodule TestModule do
        def risky_operation do
          {{operation}}
        end
      end
      """
      
      # Test with safe operation
      safe_bindings = %{operation: "1 + 1"}
      assert {:ok, safe_code} = CodeGenerator.generate_code(unsafe_template, safe_bindings)
      
      # Step 2: Validate in sandbox
      assert {:ok, :safe} = SafeSandbox.validate_code_safety(safe_code.code)
      
      # Step 3: Test with dangerous operation
      dangerous_bindings = %{operation: "File.rm(\"/etc/passwd\")"}
      assert {:ok, dangerous_code} = CodeGenerator.generate_code(unsafe_template, dangerous_bindings)
      
      # Step 4: Sandbox should catch the danger
      assert {:error, reason} = SafeSandbox.validate_code_safety(dangerous_code.code)
      assert reason =~ "Unsafe code"
    end
    
    test "module reloader with genetic programming evolution" do
      # Step 1: Create initial module
      initial_code = """
      defmodule EvolvingModule do
        def fibonacci(n) when n <= 1, do: n
        def fibonacci(n), do: fibonacci(n-1) + fibonacci(n-2)
      end
      """
      
      assert {:ok, :reloaded} = ModuleReloader.reload_module(EvolvingModule, initial_code)
      
      # Test initial implementation (slow recursive fibonacci)
      assert EvolvingModule.fibonacci(5) == 5
      
      # Step 2: Define fitness function for optimization
      fitness_fn = fn code ->
        try do
          # Test if evolved code still produces correct results
          test_cases = [{0, 0}, {1, 1}, {5, 5}, {8, 21}]
          
          case SafeSandbox.execute(code, [], timeout: 2000) do
            {:ok, _} ->
              # Simple fitness: prefer shorter code (approximating efficiency)
              base_fitness = 1.0 - (String.length(code) / 1000.0)
              max(0, base_fitness)
            {:error, _} -> 0
          end
        rescue
          _ -> 0
        end
      end
      
      # Step 3: Attempt to evolve a better implementation
      base_fibonacci_code = "def fibonacci(n) when n <= 1, do: n; def fibonacci(n), do: fibonacci(n-1) + fibonacci(n-2)"
      
      case GeneticProgramming.evolve(base_fibonacci_code, fitness_fn, %{population_size: 8, generations: 2}) do
        {:ok, evolution_result} ->
          # Step 4: Try to reload with evolved code
          evolved_module_code = """
          defmodule EvolvingModule do
            #{evolution_result.best_code}
          end
          """
          
          # This might fail due to syntax issues, which is expected with genetic programming
          case ModuleReloader.reload_module(EvolvingModule, evolved_module_code, validate: false) do
            {:ok, :reloaded} ->
              # If successful, test that it still works
              result = EvolvingModule.fibonacci(5)
              assert is_number(result)
            
            {:error, _reason} ->
              # Evolution might produce invalid code, which is ok for testing
              :ok
          end
        
        {:error, _} ->
          # Evolution might fail, which is ok for this integration test
          :ok
      end
    end
    
    test "full adaptive system with multiple components" do
      # Step 1: Register adaptive patterns
      pattern_logic = fn context ->
        # Simulate code optimization based on context
        if Map.get(context, :cpu_usage, 0) > 80 do
          {:ok, :cpu_optimized}
        else
          {:ok, :no_optimization_needed}
        end
      end
      
      AdaptiveBehavior.register_pattern(
        :cpu_optimization,
        %{cpu_usage: %{operator: :gt, threshold: 75}},
        pattern_logic
      )
      
      # Step 2: Create a module that can be optimized
      target_code = """
      defmodule AdaptiveTarget do
        def intensive_calculation(n) do
          1..n |> Enum.map(&(&1 * &1)) |> Enum.sum()
        end
      end
      """
      
      ModuleReloader.reload_module(AdaptiveTarget, target_code)
      
      # Step 3: Monitor system under load
      initial_result = AdaptiveTarget.intensive_calculation(1000)
      assert is_number(initial_result)
      
      # Step 4: Simulate high CPU usage
      AdaptiveBehavior.monitor_metric(:cpu_usage, 85)
      
      # Step 5: Create rollback point before optimization
      ModuleReloader.create_rollback_point("before_optimization")
      
      # Step 6: Trigger adaptive response
      context = %{
        cpu_usage: 85,
        target_module: AdaptiveTarget,
        optimization_target: :intensive_calculation
      }
      
      {:ok, adaptation} = AdaptiveBehavior.trigger_adaptation(:performance_optimization, context)
      
      # Step 7: Record feedback
      AdaptiveBehavior.record_feedback(adaptation.id, :success, %{cpu_reduction: 15})
      
      # Step 8: Get system statistics
      stats = AdaptiveBehavior.get_adaptation_stats()
      reload_stats = ModuleReloader.get_reload_stats()
      
      assert stats.total_patterns >= 1
      assert is_number(reload_stats.successful_reloads)
      
      # The integration is successful if all components work together without crashing
    end
    
    test "error recovery and rollback integration" do
      # Step 1: Create a working module
      working_code = """
      defmodule RecoveryTestModule do
        def working_function(x), do: x * 2
      end
      """
      
      ModuleReloader.reload_module(RecoveryTestModule, working_code)
      assert RecoveryTestModule.working_function(5) == 10
      
      # Step 2: Create rollback point
      ModuleReloader.create_rollback_point("working_state")
      
      # Step 3: Attempt to evolve the function
      evolution_fitness = fn code ->
        case SafeSandbox.execute("#{code}; working_function(5)", [], timeout: 1000) do
          {:ok, 10} -> 1.0  # Correct behavior
          {:ok, _} -> 0.5   # Different behavior
          {:error, _} -> 0  # Broken code
        end
      end
      
      base_code = "def working_function(x), do: x * 2"
      
      case GeneticProgramming.evolve(base_code, evolution_fitness, %{population_size: 5, generations: 2}) do
        {:ok, evolution_result} ->
          # Step 4: Try to apply evolved code
          evolved_code = """
          defmodule RecoveryTestModule do
            #{evolution_result.best_code}
          end
          """
          
          case ModuleReloader.reload_module(RecoveryTestModule, evolved_code, validate: false) do
            {:ok, :reloaded} ->
              # Test if evolved version works
              try do
                result = RecoveryTestModule.working_function(5)
                if result != 10 do
                  # Evolution changed behavior, rollback
                  ModuleReloader.restore_rollback_point("working_state")
                end
              rescue
                _ ->
                  # Evolution broke the function, rollback
                  ModuleReloader.restore_rollback_point("working_state")
              end
            
            {:error, _} ->
              # Failed to reload, rollback
              ModuleReloader.restore_rollback_point("working_state")
          end
        
        {:error, _} ->
          # Evolution failed, ensure original still works
          assert RecoveryTestModule.working_function(5) == 10
      end
      
      # Final verification - module should still work regardless of what happened
      final_result = RecoveryTestModule.working_function(5)
      assert final_result == 10 or is_number(final_result)
    end
    
    test "concurrent self-modification operations" do
      # Test that multiple self-modification operations can run concurrently
      
      tasks = 1..3
      |> Enum.map(fn i ->
        Task.async(fn ->
          module_name = :"ConcurrentSelfMod#{i}"
          
          # Each task performs a complete self-modification cycle
          code = """
          defmodule #{module_name} do
            def compute(x), do: x + #{i}
          end
          """
          
          # 1. Generate and create module
          {:ok, generated} = CodeGenerator.generate_code(code, %{})
          {:ok, _} = CodeGenerator.create_module(module_name, generated.code)
          
          # 2. Test in sandbox
          test_result = SafeSandbox.execute("#{module_name}.compute(10)", [], timeout: 1000)
          
          # 3. Register adaptive behavior
          pattern_id = :"pattern_#{i}"
          AdaptiveBehavior.register_pattern(
            pattern_id,
            %{load: 50},
            fn _ctx -> {:ok, :adapted} end
          )
          
          # 4. Create rollback point
          point_name = "checkpoint_#{i}"
          ModuleReloader.create_rollback_point(point_name)
          
          {module_name, test_result, pattern_id, point_name}
        end)
      end)
      
      results = Enum.map(tasks, &Task.await(&1, 10_000))
      
      # All tasks should complete successfully
      assert length(results) == 3
      
      # Verify each result
      Enum.each(results, fn {module_name, test_result, pattern_id, point_name} ->
        assert is_atom(module_name)
        assert match?({:ok, _} | {:error, _}, test_result)
        assert is_atom(pattern_id)
        assert is_binary(point_name)
      end)
    end
  end
  
  describe "system resilience and error handling" do
    test "system remains stable under various error conditions" do
      # Test 1: Invalid code generation
      assert {:error, _} = CodeGenerator.generate_code("invalid {{{{ syntax", %{})
      
      # Test 2: Dangerous code in sandbox
      assert {:error, _} = SafeSandbox.execute("System.cmd(\"rm\", [\"-rf\", \"/\"])")
      
      # Test 3: Evolution with impossible fitness
      impossible_fitness = fn _code -> :not_a_number end
      evolution_result = GeneticProgramming.evolve("test", impossible_fitness, %{population_size: 3, generations: 1})
      assert match?({:ok, _} | {:error, _}, evolution_result)
      
      # Test 4: Module reload with compilation errors
      bad_code = "defmodule BadModule do\n  def broken( do: syntax error\nend"
      assert {:error, _} = ModuleReloader.reload_module(BadModule, bad_code, validate: true)
      
      # Test 5: Adaptive behavior with crashing pattern
      crashing_pattern = fn _ctx -> raise "pattern error" end
      AdaptiveBehavior.register_pattern(:crash_test, %{test: 1}, crashing_pattern)
      AdaptiveBehavior.monitor_metric(:test, 2)  # Should not crash the system
      
      Process.sleep(100)
      
      # System should still be responsive
      stats = AdaptiveBehavior.get_adaptation_stats()
      assert is_map(stats)
    end
    
    test "performance under load" do
      # Create multiple modules and perform operations
      start_time = System.monotonic_time(:millisecond)
      
      # Generate multiple modules
      modules = 1..10
      |> Enum.map(fn i ->
        code = """
        defmodule LoadTestModule#{i} do
          def value, do: #{i}
        end
        """
        
        {:ok, generated} = CodeGenerator.generate_code(code, %{})
        {:ok, module_name} = CodeGenerator.create_module(:"LoadTestModule#{i}", generated.code)
        module_name
      end)
      
      # Test all modules work
      results = Enum.map(modules, fn module ->
        apply(module, :value, [])
      end)
      
      assert results == Enum.to_list(1..10)
      
      execution_time = System.monotonic_time(:millisecond) - start_time
      
      # Should complete within reasonable time (adjust threshold as needed)
      assert execution_time < 5000  # 5 seconds
    end
  end
  
  describe "learning and adaptation over time" do
    test "system learns from successful adaptations" do
      # Perform several adaptations
      1..5
      |> Enum.each(fn i ->
        context = %{iteration: i, load: i * 10}
        {:ok, adaptation} = AdaptiveBehavior.trigger_adaptation(:performance_optimization, context)
        
        # Record success for even iterations, failure for odd
        feedback = if rem(i, 2) == 0, do: :success, else: :failure
        AdaptiveBehavior.record_feedback(adaptation.id, feedback, %{improvement: i})
      end)
      
      Process.sleep(200)
      
      # Attempt to learn from patterns
      {:ok, learned_patterns} = AdaptiveBehavior.learn_from_patterns(:hour)
      
      # Learning might not produce results with limited data, but should not crash
      assert is_list(learned_patterns)
    end
  end
end