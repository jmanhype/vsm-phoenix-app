defmodule VsmPhoenix.SelfModifying.GeneticProgramming do
  @moduledoc """
  Genetic Programming system for code evolution in VSM.
  
  Implements evolutionary algorithms to automatically improve and adapt code
  through selection, crossover, mutation, and fitness evaluation.
  """
  
  require Logger
  alias VsmPhoenix.SelfModifying.{SafeSandbox, CodeGenerator}
  
  defstruct [
    :population_size,
    :generations,
    :mutation_rate,
    :crossover_rate,
    :selection_method,
    :fitness_function,
    :population,
    :generation,
    :best_individual,
    :best_fitness,
    :evolution_history,
    :statistics
  ]
  
  @default_config %{
    population_size: 50,
    generations: 100,
    mutation_rate: 0.1,
    crossover_rate: 0.8,
    selection_method: :tournament,
    tournament_size: 3,
    elitism_rate: 0.1
  }
  
  ## Public API
  
  @doc """
  Evolves code using genetic programming.
  
  ## Parameters
  - initial_code: Starting code template or seed
  - fitness_function: Function to evaluate code quality
  - config: Evolution configuration
  
  ## Examples
      iex> fitness_fn = fn code -> 
      ...>   # Evaluate how well the code performs
      ...>   case SafeSandbox.execute(code) do
      ...>     {:ok, result} -> calculate_fitness(result)
      ...>     _ -> 0
      ...>   end
      ...> end
      iex> {:ok, best_code} = GeneticProgramming.evolve(initial_code, fitness_fn)
  """
  def evolve(initial_code, fitness_function, config \\ %{}) do
    config = Map.merge(@default_config, config)
    
    Logger.info("Starting genetic programming evolution with #{config.population_size} individuals for #{config.generations} generations")
    
    with {:ok, initial_population} <- generate_initial_population(initial_code, config.population_size),
         {:ok, evolution_state} <- initialize_evolution_state(initial_population, fitness_function, config),
         {:ok, final_state} <- run_evolution(evolution_state) do
      
      Logger.info("Evolution completed. Best fitness: #{final_state.best_fitness}")
      {:ok, %{
        best_code: final_state.best_individual,
        best_fitness: final_state.best_fitness,
        generation: final_state.generation,
        statistics: final_state.statistics,
        history: final_state.evolution_history
      }}
    else
      {:error, reason} -> 
        Logger.error("Evolution failed: #{reason}")
        {:error, reason}
    end
  end
  
  @doc """
  Evolves a population of functions for a specific task.
  """
  def evolve_functions(task_description, test_cases, config \\ %{}) do
    # Generate initial function templates based on task
    templates = generate_function_templates(task_description)
    
    fitness_function = fn code ->
      evaluate_function_fitness(code, test_cases)
    end
    
    # Evolve each template and select the best
    evolved_functions = Enum.map(templates, fn template ->
      case evolve(template, fitness_function, config) do
        {:ok, result} -> result
        {:error, _} -> nil
      end
    end)
    |> Enum.filter(& &1)
    
    case evolved_functions do
      [] -> {:error, "No successful evolution"}
      functions -> 
        best = Enum.max_by(functions, & &1.best_fitness)
        {:ok, best}
    end
  end
  
  @doc """
  Creates a custom evolution strategy.
  """
  def create_evolution_strategy(name, config) do
    strategy = %{
      name: name,
      config: Map.merge(@default_config, config),
      operators: %{
        selection: get_selection_operator(config[:selection_method] || :tournament),
        crossover: get_crossover_operator(config[:crossover_method] || :subtree),
        mutation: get_mutation_operator(config[:mutation_method] || :point),
        fitness: config[:fitness_function] || (&default_fitness/1)
      }
    }
    
    {:ok, strategy}
  end
  
  @doc """
  Runs parallel evolution with multiple populations.
  """
  def parallel_evolution(initial_code, fitness_function, island_count \\ 4, config \\ %{}) do
    config = Map.merge(@default_config, config)
    
    # Create multiple islands (populations)
    islands = 1..island_count
    |> Enum.map(fn island_id ->
      Task.async(fn ->
        island_config = Map.put(config, :population_size, div(config.population_size, island_count))
        evolve(initial_code, fitness_function, island_config)
      end)
    end)
    
    # Wait for all islands to complete
    results = Enum.map(islands, &Task.await(&1, :infinity))
    
    # Select best result across all islands
    successful_results = Enum.filter(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    case successful_results do
      [] -> {:error, "All islands failed"}
      results ->
        best = Enum.max_by(results, fn {:ok, result} -> result.best_fitness end)
        {:ok, elem(best, 1)}
    end
  end
  
  ## Private functions
  
  defp generate_initial_population(initial_code, population_size) do
    population = 1..population_size
    |> Enum.map(fn _ -> 
      mutate_code(initial_code, 0.3) # Higher initial mutation rate
    end)
    |> Enum.uniq() # Remove duplicates
    
    # If we have fewer unique individuals, generate more variations
    if length(population) < population_size do
      additional_needed = population_size - length(population)
      additional = 1..additional_needed
      |> Enum.map(fn _ -> 
        mutate_code(initial_code, 0.5) # Even higher mutation for diversity
      end)
      
      {:ok, population ++ additional}
    else
      {:ok, population}
    end
  end
  
  defp initialize_evolution_state(population, fitness_function, config) do
    state = %__MODULE__{
      population_size: config.population_size,
      generations: config.generations,
      mutation_rate: config.mutation_rate,
      crossover_rate: config.crossover_rate,
      selection_method: config.selection_method,
      fitness_function: fitness_function,
      population: population,
      generation: 0,
      best_individual: nil,
      best_fitness: -1,
      evolution_history: [],
      statistics: %{
        avg_fitness_history: [],
        diversity_history: [],
        convergence_metrics: []
      }
    }
    
    {:ok, state}
  end
  
  defp run_evolution(state) do
    Enum.reduce_while(1..state.generations, state, fn generation, current_state ->
      Logger.debug("Generation #{generation}/#{current_state.generations}")
      
      # Evaluate fitness of current population
      evaluated_population = evaluate_population(current_state.population, current_state.fitness_function)
      
      # Update state with current generation results
      updated_state = update_generation_state(current_state, evaluated_population, generation)
      
      # Check termination conditions
      if should_terminate?(updated_state) do
        Logger.info("Early termination at generation #{generation}")
        {:halt, updated_state}
      else
        # Create next generation
        next_population = create_next_generation(evaluated_population, updated_state)
        next_state = %{updated_state | population: next_population, generation: generation}
        
        {:cont, next_state}
      end
    end)
    |> then(&{:ok, &1})
  rescue
    e -> {:error, "Evolution error: #{Exception.message(e)}"}
  end
  
  defp evaluate_population(population, fitness_function) do
    population
    |> Enum.map(fn individual ->
      fitness = evaluate_individual_fitness(individual, fitness_function)
      {individual, fitness}
    end)
    |> Enum.sort_by(fn {_individual, fitness} -> fitness end, :desc)
  end
  
  defp evaluate_individual_fitness(code, fitness_function) do
    try do
      case SafeSandbox.execute(fitness_function, [code], timeout: 2000) do
        {:ok, fitness} when is_number(fitness) -> max(0, fitness)
        {:ok, _} -> 0
        {:error, _} -> 0
      end
    rescue
      _ -> 0
    end
  end
  
  defp update_generation_state(state, evaluated_population, generation) do
    {best_individual, best_fitness} = hd(evaluated_population)
    
    avg_fitness = evaluated_population
    |> Enum.map(fn {_code, fitness} -> fitness end)
    |> Enum.sum()
    |> Kernel./(length(evaluated_population))
    
    diversity = calculate_diversity(evaluated_population)
    
    new_statistics = %{
      avg_fitness_history: [avg_fitness | state.statistics.avg_fitness_history],
      diversity_history: [diversity | state.statistics.diversity_history],
      convergence_metrics: state.statistics.convergence_metrics
    }
    
    %{state |
      generation: generation,
      best_individual: if(best_fitness > state.best_fitness, do: best_individual, else: state.best_individual),
      best_fitness: max(best_fitness, state.best_fitness),
      evolution_history: [%{
        generation: generation,
        best_fitness: best_fitness,
        avg_fitness: avg_fitness,
        diversity: diversity
      } | state.evolution_history],
      statistics: new_statistics
    }
  end
  
  defp should_terminate?(state) do
    # Termination conditions
    cond do
      # Perfect fitness reached
      state.best_fitness >= 1.0 -> true
      
      # Convergence (no improvement for many generations)
      length(state.evolution_history) >= 20 ->
        recent_best = state.evolution_history
        |> Enum.take(20)
        |> Enum.map(& &1.best_fitness)
        
        variance = calculate_variance(recent_best)
        variance < 0.001 # Very low variance indicates convergence
      
      # Default: continue
      true -> false
    end
  end
  
  defp create_next_generation(evaluated_population, state) do
    elite_count = round(state.population_size * 0.1) # Keep top 10%
    elite = evaluated_population |> Enum.take(elite_count) |> Enum.map(fn {code, _} -> code end)
    
    # Generate rest through selection, crossover, and mutation
    remaining_count = state.population_size - elite_count
    
    new_individuals = 1..remaining_count
    |> Enum.map(fn _ ->
      if :rand.uniform() < state.crossover_rate do
        # Crossover
        parent1 = tournament_selection(evaluated_population, 3)
        parent2 = tournament_selection(evaluated_population, 3)
        child = crossover_code(parent1, parent2)
        
        # Maybe mutate the child
        if :rand.uniform() < state.mutation_rate do
          mutate_code(child, 0.1)
        else
          child
        end
      else
        # Just select and maybe mutate
        parent = tournament_selection(evaluated_population, 3)
        if :rand.uniform() < state.mutation_rate do
          mutate_code(parent, 0.1)
        else
          parent
        end
      end
    end)
    
    elite ++ new_individuals
  end
  
  defp tournament_selection(evaluated_population, tournament_size) do
    tournament = Enum.take_random(evaluated_population, tournament_size)
    {winner, _fitness} = Enum.max_by(tournament, fn {_code, fitness} -> fitness end)
    winner
  end
  
  defp crossover_code(parent1, parent2) do
    # Simple crossover: take parts from each parent
    len1 = String.length(parent1)
    len2 = String.length(parent2)
    
    if len1 == 0 or len2 == 0 do
      if len1 > len2 do
        parent1
      else
        parent2
      end
    else
      cut_point1 = :rand.uniform(len1) - 1
      cut_point2 = :rand.uniform(len2) - 1
      
      part1 = String.slice(parent1, 0, cut_point1)
      part2 = String.slice(parent2, cut_point2, len2 - cut_point2)
      
      part1 <> part2
    end
  end
  
  defp mutate_code(code, mutation_rate) do
    code
    |> String.graphemes()
    |> Enum.map(fn char ->
      if :rand.uniform() < mutation_rate do
        mutate_character(char)
      else
        char
      end
    end)
    |> Enum.join("")
  end
  
  defp mutate_character(char) do
    case char do
      # Mutate common programming characters
      "(" -> Enum.random(["(", "[", "{"])
      ")" -> Enum.random([")", "]", "}"])
      "+" -> Enum.random(["+", "-", "*", "/"])
      "=" -> Enum.random(["=", "!", "<", ">"])
      _ -> 
        # For other characters, pick a random character from common set
        common_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.,;:-+*/=<>()[]{}|&"
        String.at(common_chars, :rand.uniform(String.length(common_chars)) - 1)
    end
  end
  
  defp calculate_diversity(evaluated_population) do
    codes = Enum.map(evaluated_population, fn {code, _} -> code end)
    unique_codes = Enum.uniq(codes)
    
    length(unique_codes) / length(codes)
  end
  
  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)
    
    variance = values
    |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    variance
  end
  
  defp generate_function_templates(task_description) do
    # Generate basic function templates based on task keywords
    base_templates = [
      "def solve(input) do\n  # TODO: implement\n  input\nend",
      "def process(data) do\n  data |> transform() |> validate()\nend",
      "def calculate(x, y) do\n  x + y\nend",
      "def filter_data(list) do\n  Enum.filter(list, &valid?/1)\nend"
    ]
    
    # Customize templates based on task description keywords
    task_lower = String.downcase(task_description)
    
    cond do
      String.contains?(task_lower, ["sort", "order"]) ->
        ["def sort_data(list) do\n  Enum.sort(list)\nend" | base_templates]
      
      String.contains?(task_lower, ["math", "calculate", "compute"]) ->
        ["def compute(a, b) do\n  a * b + :math.sqrt(a)\nend" | base_templates]
      
      String.contains?(task_lower, ["string", "text"]) ->
        ["def process_text(text) do\n  text |> String.trim() |> String.upcase()\nend" | base_templates]
      
      true ->
        base_templates
    end
  end
  
  defp evaluate_function_fitness(code, test_cases) do
    try do
      # Compile and test the function
      case CodeGenerator.generate_code(code, %{}) do
        {:ok, %{code: compiled_code}} ->
          # Run test cases
          passed_tests = Enum.count(test_cases, fn {input, expected} ->
            case SafeSandbox.execute("#{compiled_code}\nsolve(#{inspect(input)})", [], timeout: 1000) do
              {:ok, result} -> result == expected
              _ -> false
            end
          end)
          
          passed_tests / length(test_cases)
        
        _ -> 0
      end
    rescue
      _ -> 0
    end
  end
  
  defp get_selection_operator(:tournament), do: &tournament_selection/2
  defp get_selection_operator(:roulette), do: &roulette_selection/2
  defp get_selection_operator(_), do: &tournament_selection/2
  
  defp get_crossover_operator(:subtree), do: &crossover_code/2
  defp get_crossover_operator(:single_point), do: &single_point_crossover/2
  defp get_crossover_operator(_), do: &crossover_code/2
  
  defp get_mutation_operator(:point), do: &mutate_code/2
  defp get_mutation_operator(:subtree), do: &subtree_mutation/2
  defp get_mutation_operator(_), do: &mutate_code/2
  
  defp default_fitness(code) do
    # Default fitness: prefer shorter, syntactically correct code
    case Code.string_to_quoted(code) do
      {:ok, _} -> max(0, 1.0 - String.length(code) / 1000.0)
      _ -> 0
    end
  end
  
  defp roulette_selection(evaluated_population, _size) do
    total_fitness = Enum.sum(Enum.map(evaluated_population, fn {_, fitness} -> fitness end))
    
    if total_fitness == 0 do
      {code, _} = Enum.random(evaluated_population)
      code
    else
      target = :rand.uniform() * total_fitness
      select_roulette(evaluated_population, target, 0)
    end
  end
  
  defp select_roulette([{code, fitness} | _], target, acc) when acc + fitness >= target do
    code
  end
  defp select_roulette([{_, fitness} | rest], target, acc) do
    select_roulette(rest, target, acc + fitness)
  end
  defp select_roulette([], _target, _acc) do
    # Fallback - return empty string as we don't have access to the population here
    ""
  end
  
  defp single_point_crossover(parent1, parent2) do
    len = min(String.length(parent1), String.length(parent2))
    if len == 0 do
      parent1
    else
      cut_point = :rand.uniform(len) - 1
      String.slice(parent1, 0, cut_point) <> String.slice(parent2, cut_point, String.length(parent2))
    end
  end
  
  defp subtree_mutation(code, mutation_rate) do
    # More aggressive mutation that replaces entire subtrees
    if :rand.uniform() < mutation_rate do
      # Replace a random portion with a new random subtree
      len = String.length(code)
      if len > 10 do
        start_pos = :rand.uniform(len - 5)
        end_pos = start_pos + :rand.uniform(5)
        
        new_subtree = generate_random_subtree()
        String.slice(code, 0, start_pos) <> new_subtree <> String.slice(code, end_pos, len)
      else
        code
      end
    else
      code
    end
  end
  
  defp generate_random_subtree do
    subtrees = [
      "x + y",
      "Enum.map(list, fn x -> x * 2 end)",
      "if condition, do: true, else: false",
      "case value do\n  :ok -> :success\n  _ -> :error\nend",
      "String.upcase(text)"
    ]
    
    Enum.random(subtrees)
  end
end