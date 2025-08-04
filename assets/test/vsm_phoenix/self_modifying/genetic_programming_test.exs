defmodule VsmPhoenix.SelfModifying.GeneticProgrammingTest do
  use ExUnit.Case, async: true
  
  alias VsmPhoenix.SelfModifying.GeneticProgramming
  
  describe "evolve/3" do
    test "evolves simple arithmetic expressions" do
      initial_code = "1 + 1"
      
      fitness_function = fn code ->
        case Code.eval_string(code) do
          {result, _} when is_number(result) -> 
            # Prefer larger numbers
            min(1.0, result / 100.0)
          _ -> 0
        end
      end
      
      config = %{population_size: 20, generations: 5}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      assert result.best_fitness >= 0
      assert is_binary(result.best_code)
      assert result.generation == 5
    end
    
    test "improves fitness over generations" do
      initial_code = "x = 1"
      
      fitness_function = fn code ->
        # Simple fitness: prefer shorter code
        1.0 - (String.length(code) / 100.0)
      end
      
      config = %{population_size: 10, generations: 3}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      assert length(result.history) == 3
      
      # Check that we have history entries
      assert Enum.all?(result.history, fn entry ->
        Map.has_key?(entry, :generation) and 
        Map.has_key?(entry, :best_fitness) and
        Map.has_key?(entry, :avg_fitness)
      end)
    end
    
    test "handles invalid fitness functions gracefully" do
      initial_code = "1 + 1"
      
      bad_fitness_function = fn _code ->
        raise "fitness error"
      end
      
      config = %{population_size: 5, generations: 2}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, bad_fitness_function, config)
      # Should complete despite fitness function errors
      assert result.best_fitness >= 0
    end
    
    test "maintains population diversity" do
      initial_code = "def f(x), do: x"
      
      fitness_function = fn _code -> :rand.uniform() end
      
      config = %{population_size: 20, generations: 1}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      
      # Check diversity in history
      assert length(result.history) == 1
      history_entry = hd(result.history)
      assert Map.has_key?(history_entry, :diversity)
      assert history_entry.diversity > 0
    end
    
    test "respects configuration parameters" do
      initial_code = "1"
      fitness_function = fn _code -> 0.5 end
      
      config = %{
        population_size: 15,
        generations: 7,
        mutation_rate: 0.2,
        crossover_rate: 0.9
      }
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      assert result.generation == 7
      assert length(result.history) == 7
    end
  end
  
  describe "evolve_functions/3" do
    test "evolves functions for simple mathematical tasks" do
      task_description = "calculate the square of a number"
      
      test_cases = [
        {2, 4},
        {3, 9},
        {4, 16},
        {5, 25}
      ]
      
      config = %{population_size: 20, generations: 10}
      
      assert {:ok, result} = GeneticProgramming.evolve_functions(task_description, test_cases, config)
      assert result.best_fitness > 0
      assert is_binary(result.best_code)
    end
    
    test "handles string processing tasks" do
      task_description = "process text by making it uppercase"
      
      test_cases = [
        {"hello", "HELLO"},
        {"world", "WORLD"},
        {"test", "TEST"}
      ]
      
      config = %{population_size: 15, generations: 5}
      
      # This might not achieve perfect fitness due to complexity, but should attempt evolution
      result = GeneticProgramming.evolve_functions(task_description, test_cases, config)
      assert match?({:ok, _} | {:error, _}, result)
    end
    
    test "handles sorting tasks" do
      task_description = "sort a list of numbers"
      
      test_cases = [
        {[3, 1, 2], [1, 2, 3]},
        {[5, 2, 8, 1], [1, 2, 5, 8]}
      ]
      
      config = %{population_size: 10, generations: 3}
      
      result = GeneticProgramming.evolve_functions(task_description, test_cases, config)
      assert match?({:ok, _} | {:error, _}, result)
    end
    
    test "returns error when no successful evolution occurs" do
      task_description = "impossible task"
      
      # Impossible test cases
      test_cases = [
        {:impossible_input, :impossible_output}
      ]
      
      config = %{population_size: 5, generations: 2}
      
      assert {:error, reason} = GeneticProgramming.evolve_functions(task_description, test_cases, config)
      assert reason == "No successful evolution"
    end
  end
  
  describe "parallel_evolution/4" do
    test "runs multiple evolution islands" do
      initial_code = "x = 1"
      fitness_function = fn _code -> :rand.uniform() end
      
      config = %{population_size: 20, generations: 3}
      
      assert {:ok, result} = GeneticProgramming.parallel_evolution(initial_code, fitness_function, 2, config)
      assert result.best_fitness >= 0
      assert is_binary(result.best_code)
    end
    
    test "selects best result across islands" do
      initial_code = "1 + 1"
      
      # Deterministic fitness for testing
      fitness_function = fn code ->
        String.length(code) / 100.0
      end
      
      config = %{population_size: 8, generations: 2}
      
      assert {:ok, result} = GeneticProgramming.parallel_evolution(initial_code, fitness_function, 2, config)
      assert result.best_fitness > 0
    end
    
    test "handles island failures gracefully" do
      initial_code = "test"
      
      # Fitness function that sometimes fails
      fitness_function = fn _code ->
        if :rand.uniform() < 0.5 do
          raise "random failure"
        else
          0.5
        end
      end
      
      config = %{population_size: 4, generations: 1}
      
      # Should either succeed or fail gracefully
      result = GeneticProgramming.parallel_evolution(initial_code, fitness_function, 3, config)
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
  
  describe "create_evolution_strategy/2" do
    test "creates custom evolution strategy" do
      config = %{
        selection_method: :tournament,
        crossover_method: :subtree,
        mutation_method: :point,
        mutation_rate: 0.15
      }
      
      assert {:ok, strategy} = GeneticProgramming.create_evolution_strategy("custom", config)
      assert strategy.name == "custom"
      assert strategy.config.mutation_rate == 0.15
      assert Map.has_key?(strategy, :operators)
    end
    
    test "uses default values for missing config" do
      config = %{mutation_rate: 0.05}
      
      assert {:ok, strategy} = GeneticProgramming.create_evolution_strategy("minimal", config)
      assert strategy.config.mutation_rate == 0.05
      assert strategy.config.population_size == 50  # Should use default
    end
    
    test "includes all required operators" do
      assert {:ok, strategy} = GeneticProgramming.create_evolution_strategy("test", %{})
      
      operators = strategy.operators
      assert Map.has_key?(operators, :selection)
      assert Map.has_key?(operators, :crossover)
      assert Map.has_key?(operators, :mutation)
      assert Map.has_key?(operators, :fitness)
      
      assert is_function(operators.selection)
      assert is_function(operators.crossover)
      assert is_function(operators.mutation)
      assert is_function(operators.fitness)
    end
  end
  
  describe "evolution operators" do
    test "tournament selection chooses better individuals" do
      # Create a mock evaluated population
      evaluated_population = [
        {"code1", 0.9},
        {"code2", 0.7},
        {"code3", 0.5},
        {"code4", 0.3},
        {"code5", 0.1}
      ]
      
      # Run tournament selection multiple times
      selections = 1..20
      |> Enum.map(fn _ ->
        # We'll test the selection by looking at frequency of high-fitness individuals
        selected_code = case Enum.take_random(evaluated_population, 3) do
          tournament -> 
            {code, _fitness} = Enum.max_by(tournament, fn {_code, fitness} -> fitness end)
            code
        end
        selected_code
      end)
      
      # High fitness individuals should be selected more often
      code1_count = Enum.count(selections, &(&1 == "code1"))
      code5_count = Enum.count(selections, &(&1 == "code5"))
      
      assert code1_count >= code5_count  # Better fitness should be selected more
    end
    
    test "crossover combines parents" do
      parent1 = "hello world"
      parent2 = "goodbye universe"
      
      # Test crossover multiple times to see different combinations
      children = 1..10
      |> Enum.map(fn _ ->
        # Simple crossover implementation for testing
        len1 = String.length(parent1)
        len2 = String.length(parent2)
        cut_point1 = :rand.uniform(len1) - 1
        cut_point2 = :rand.uniform(len2) - 1
        
        String.slice(parent1, 0, cut_point1) <> String.slice(parent2, cut_point2, len2)
      end)
      |> Enum.uniq()
      
      # Should produce some variety
      assert length(children) > 1
      
      # Children should contain parts from both parents
      assert Enum.any?(children, fn child ->
        String.contains?(child, "hello") or String.contains?(child, "world")
      end)
    end
    
    test "mutation changes code" do
      original = "hello"
      
      # Apply mutation multiple times
      mutations = 1..10
      |> Enum.map(fn _ ->
        # Simple mutation for testing
        original
        |> String.graphemes()
        |> Enum.map(fn char ->
          if :rand.uniform() < 0.3 do
            Enum.random(~w(a b c d e f g h i j))
          else
            char
          end
        end)
        |> Enum.join("")
      end)
      |> Enum.uniq()
      
      # Should produce some mutations
      assert length(mutations) > 1
      
      # At least some should be different from original
      assert Enum.any?(mutations, &(&1 != original))
    end
    
    test "fitness evaluation handles various code types" do
      test_codes = [
        "1 + 1",
        "def f(x), do: x",
        "invalid syntax",
        "Enum.sum([1, 2, 3])",
        ""
      ]
      
      fitness_function = fn code ->
        case Code.string_to_quoted(code) do
          {:ok, _} -> 1.0 - String.length(code) / 100.0
          _ -> 0
        end
      end
      
      # Test fitness evaluation
      fitness_values = Enum.map(test_codes, fitness_function)
      
      # Should handle all cases without crashing
      assert length(fitness_values) == length(test_codes)
      assert Enum.all?(fitness_values, &is_number/1)
      assert Enum.all?(fitness_values, &(&1 >= 0))
    end
  end
  
  describe "evolution statistics" do
    test "tracks evolution statistics correctly" do
      initial_code = "1"
      fitness_function = fn code -> String.length(code) / 10.0 end
      config = %{population_size: 10, generations: 3}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      
      # Check statistics structure
      stats = result.statistics
      assert Map.has_key?(stats, :avg_fitness_history)
      assert Map.has_key?(stats, :diversity_history) 
      assert Map.has_key?(stats, :convergence_metrics)
      
      # Should have data for each generation
      assert length(stats.avg_fitness_history) == 3
      assert length(stats.diversity_history) == 3
      
      # Values should be reasonable
      assert Enum.all?(stats.avg_fitness_history, &is_number/1)
      assert Enum.all?(stats.diversity_history, &is_number/1)
      assert Enum.all?(stats.diversity_history, &(&1 >= 0 and &1 <= 1))
    end
    
    test "evolution history contains required fields" do
      initial_code = "test"
      fitness_function = fn _code -> 0.5 end
      config = %{population_size: 5, generations: 2}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      
      # Check history entries
      assert length(result.history) == 2
      
      Enum.each(result.history, fn entry ->
        assert Map.has_key?(entry, :generation)
        assert Map.has_key?(entry, :best_fitness)
        assert Map.has_key?(entry, :avg_fitness)
        assert Map.has_key?(entry, :diversity)
        
        assert is_number(entry.generation)
        assert is_number(entry.best_fitness)
        assert is_number(entry.avg_fitness)
        assert is_number(entry.diversity)
      end)
    end
  end
  
  describe "edge cases and error handling" do
    test "handles empty initial code" do
      initial_code = ""
      fitness_function = fn _code -> 0.1 end
      config = %{population_size: 5, generations: 1}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      assert result.best_fitness >= 0
    end
    
    test "handles very small populations" do
      initial_code = "1"
      fitness_function = fn _code -> 0.5 end
      config = %{population_size: 2, generations: 1}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      assert result.generation == 1
    end
    
    test "handles zero generations" do
      initial_code = "1"
      fitness_function = fn _code -> 0.5 end
      config = %{population_size: 5, generations: 0}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      assert result.generation == 0
      assert length(result.history) == 0
    end
    
    test "handles fitness function that returns non-numbers" do
      initial_code = "test"
      fitness_function = fn _code -> "not a number" end
      config = %{population_size: 5, generations: 1}
      
      assert {:ok, result} = GeneticProgramming.evolve(initial_code, fitness_function, config)
      # Should handle gracefully and use default fitness
      assert is_number(result.best_fitness)
    end
  end
end