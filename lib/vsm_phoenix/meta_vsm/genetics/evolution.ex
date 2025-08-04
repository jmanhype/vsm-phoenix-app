defmodule VsmPhoenix.MetaVsm.Genetics.Evolution do
  @moduledoc """
  Genetic Evolution Engine for META-VSM
  
  Implements genetic algorithms for VSM evolution including:
  - Mutation operations
  - Crossover (sexual reproduction)
  - Selection pressure
  - Fitness evaluation
  - Evolutionary strategies
  """
  
  alias VsmPhoenix.MetaVsm.Genetics.DnaConfig
  
  @mutation_types [:point, :insertion, :deletion, :duplication, :inversion]
  @crossover_types [:single_point, :two_point, :uniform, :arithmetic]
  
  @doc """
  Inherit DNA from parent with potential mutations
  """
  def inherit_with_mutations(parent_dna, mutation_rate) do
    inherited = deep_copy(parent_dna)
    
    # Add parent to lineage
    lineage = Map.get(inherited, :lineage, [])
    inherited = Map.put(inherited, :lineage, [parent_dna.unique_id | lineage])
    
    # Apply mutations based on rate
    if :rand.uniform() < mutation_rate do
      apply_mutations(inherited, select_mutation_strategy())
    else
      inherited
    end
  end
  
  @doc """
  Evolve DNA based on fitness and selection pressure
  """
  def evolve(dna, fitness, selection_pressure) do
    strategy = determine_evolution_strategy(fitness, selection_pressure)
    
    mutations = case strategy do
      :aggressive ->
        # Multiple mutations for rapid evolution
        apply_multiple_mutations(dna, 3)
        
      :conservative ->
        # Single careful mutation
        apply_single_mutation(dna, :beneficial)
        
      :adaptive ->
        # Fitness-based mutation
        if fitness < 0.5 do
          apply_multiple_mutations(dna, 2)
        else
          apply_single_mutation(dna, :neutral)
        end
        
      :experimental ->
        # Radical changes
        apply_radical_mutations(dna)
        
      _ ->
        []
    end
    
    evolved_dna = apply_mutation_list(dna, mutations)
    {evolved_dna, mutations}
  end
  
  @doc """
  Perform crossover between two DNA strands (sexual reproduction)
  """
  def crossover(dna1, dna2, method \\ :uniform) do
    case method do
      :single_point ->
        single_point_crossover(dna1, dna2)
        
      :two_point ->
        two_point_crossover(dna1, dna2)
        
      :uniform ->
        uniform_crossover(dna1, dna2)
        
      :arithmetic ->
        arithmetic_crossover(dna1, dna2)
        
      _ ->
        uniform_crossover(dna1, dna2)
    end
  end
  
  @doc """
  Check if mutations are beneficial based on fitness change
  """
  def is_beneficial?(mutations, current_fitness) do
    expected_fitness = calculate_expected_fitness(mutations, current_fitness)
    expected_fitness > current_fitness
  end
  
  @doc """
  Generate a specific type of mutation
  """
  def generate_mutation(type, target \\ nil) do
    case type do
      :point ->
        generate_point_mutation(target)
        
      :insertion ->
        generate_insertion_mutation()
        
      :deletion ->
        generate_deletion_mutation(target)
        
      :duplication ->
        generate_duplication_mutation(target)
        
      :inversion ->
        generate_inversion_mutation(target)
        
      _ ->
        generate_point_mutation(target)
    end
  end
  
  @doc """
  Apply natural selection to a population of DNAs
  """
  def natural_selection(population, fitness_scores, survival_rate \\ 0.5) do
    # Sort by fitness
    sorted = population
    |> Enum.zip(fitness_scores)
    |> Enum.sort_by(fn {_dna, fitness} -> fitness end, :desc)
    
    # Select survivors
    survivor_count = round(length(sorted) * survival_rate)
    survivors = sorted
    |> Enum.take(survivor_count)
    |> Enum.map(fn {dna, _} -> dna end)
    
    survivors
  end
  
  @doc """
  Create next generation through reproduction
  """
  def reproduce_generation(parents, target_size) do
    if length(parents) == 0 do
      []
    else
      Enum.map(1..target_size, fn _ ->
        # Select two random parents
        parent1 = Enum.random(parents)
        parent2 = Enum.random(parents)
        
        # Crossover with mutation
        offspring = crossover(parent1, parent2)
        
        # Apply mutation with small probability
        if :rand.uniform() < 0.1 do
          {mutated, _} = evolve(offspring, 0.5, :adaptive)
          mutated
        else
          offspring
        end
      end)
    end
  end
  
  @doc """
  Calculate genetic diversity in a population
  """
  def genetic_diversity(population) do
    if length(population) < 2 do
      0.0
    else
      # Compare all pairs and average their differences
      pairs = for dna1 <- population, dna2 <- population, dna1 != dna2, do: {dna1, dna2}
      
      similarities = Enum.map(pairs, fn {dna1, dna2} ->
        DnaConfig.similarity(dna1, dna2)
      end)
      
      if length(similarities) > 0 do
        avg_similarity = Enum.sum(similarities) / length(similarities)
        1.0 - avg_similarity  # Convert similarity to diversity
      else
        0.0
      end
    end
  end
  
  @doc """
  Simulate genetic drift (random changes over time)
  """
  def genetic_drift(dna, generations \\ 1) do
    Enum.reduce(1..generations, dna, fn _, acc ->
      if :rand.uniform() < 0.01 do  # 1% drift per generation
        apply_drift_mutation(acc)
      else
        acc
      end
    end)
  end
  
  @doc """
  Apply directed evolution towards a goal
  """
  def directed_evolution(dna, goal_traits, steps \\ 10) do
    Enum.reduce(1..steps, dna, fn _, current_dna ->
      # Generate candidate mutations
      candidates = for _ <- 1..5 do
        {mutated, _} = evolve(current_dna, 0.5, :adaptive)
        mutated
      end
      
      # Select best candidate based on goal similarity
      best = Enum.max_by(candidates, fn candidate ->
        calculate_goal_similarity(candidate, goal_traits)
      end)
      
      best
    end)
  end
  
  # Private functions
  
  defp deep_copy(dna) do
    :erlang.binary_to_term(:erlang.term_to_binary(dna))
  end
  
  defp select_mutation_strategy do
    Enum.random([:beneficial, :neutral, :experimental])
  end
  
  defp determine_evolution_strategy(fitness, selection_pressure) do
    cond do
      selection_pressure == :extreme and fitness < 0.3 ->
        :experimental
      selection_pressure == :high and fitness < 0.5 ->
        :aggressive
      selection_pressure == :low or fitness > 0.8 ->
        :conservative
      true ->
        :adaptive
    end
  end
  
  defp apply_mutations(dna, strategy) do
    mutation = case strategy do
      :beneficial ->
        improve_weakest_trait(dna)
      :neutral ->
        modify_random_trait(dna)
      :experimental ->
        radical_change(dna)
      _ ->
        modify_random_trait(dna)
    end
    
    apply_mutation(dna, mutation)
  end
  
  defp apply_single_mutation(dna, type) do
    mutation = DnaConfig.mutation_template(type)
    [{:mutation, type, mutation}]
  end
  
  defp apply_multiple_mutations(dna, count) do
    for _ <- 1..count do
      type = Enum.random([:beneficial, :neutral])
      {:mutation, type, DnaConfig.mutation_template(type)}
    end
  end
  
  defp apply_radical_mutations(dna) do
    [{:mutation, :radical, DnaConfig.mutation_template(:radical)}]
  end
  
  defp apply_mutation_list(dna, mutations) do
    Enum.reduce(mutations, dna, fn {:mutation, _type, template}, acc ->
      apply_mutation_template(acc, template)
    end)
  end
  
  defp apply_mutation(dna, mutation) do
    apply_mutation_template(dna, mutation)
  end
  
  defp apply_mutation_template(dna, template) do
    Enum.reduce(template, dna, fn {path, change}, acc ->
      apply_change_at_path(acc, path, change)
    end)
  end
  
  defp apply_change_at_path(dna, path, change) when is_atom(path) do
    if Map.has_key?(dna, path) do
      Map.update!(dna, path, fn value ->
        apply_change_operation(value, change)
      end)
    else
      dna
    end
  end
  
  defp apply_change_at_path(dna, path, change) do
    # Handle nested paths
    dna
  end
  
  defp apply_change_operation(value, {:add, amount}) when is_number(value) do
    value + amount
  end
  
  defp apply_change_operation(value, {:subtract, amount}) when is_number(value) do
    value - amount
  end
  
  defp apply_change_operation(value, {:multiply, factor}) when is_number(value) do
    value * factor
  end
  
  defp apply_change_operation(_value, {:set, new_value}) do
    new_value
  end
  
  defp apply_change_operation(value, _) do
    value
  end
  
  defp single_point_crossover(dna1, dna2) do
    # Convert to list of key-value pairs
    list1 = Map.to_list(dna1)
    list2 = Map.to_list(dna2)
    
    # Select crossover point
    point = :rand.uniform(length(list1))
    
    # Combine halves
    {head1, tail1} = Enum.split(list1, point)
    {_head2, tail2} = Enum.split(list2, point)
    
    # Create offspring
    Map.new(head1 ++ tail2)
  end
  
  defp two_point_crossover(dna1, dna2) do
    list1 = Map.to_list(dna1)
    list2 = Map.to_list(dna2)
    
    # Select two crossover points
    point1 = :rand.uniform(length(list1) - 1)
    point2 = point1 + :rand.uniform(length(list1) - point1)
    
    # Split into three segments
    {seg1_1, rest1} = Enum.split(list1, point1)
    {seg2_1, seg3_1} = Enum.split(rest1, point2 - point1)
    
    {_seg1_2, rest2} = Enum.split(list2, point1)
    {seg2_2, _seg3_2} = Enum.split(rest2, point2 - point1)
    
    # Combine segments
    Map.new(seg1_1 ++ seg2_2 ++ seg3_1)
  end
  
  defp uniform_crossover(dna1, dna2) do
    # For each gene, randomly select from parent 1 or 2
    Map.merge(dna1, dna2, fn _key, v1, v2 ->
      if :rand.uniform() < 0.5 do
        v1
      else
        v2
      end
    end)
  end
  
  defp arithmetic_crossover(dna1, dna2) do
    # Average numeric values, randomly select others
    Map.merge(dna1, dna2, fn _key, v1, v2 ->
      cond do
        is_number(v1) and is_number(v2) ->
          (v1 + v2) / 2
        is_map(v1) and is_map(v2) ->
          arithmetic_crossover(v1, v2)
        true ->
          if :rand.uniform() < 0.5, do: v1, else: v2
      end
    end)
  end
  
  defp generate_point_mutation(target) do
    # Change a single gene value
    %{
      behavioral_traits: %{
        Enum.random([:aggression, :cooperation, :exploration]) => {:set, :rand.uniform()}
      }
    }
  end
  
  defp generate_insertion_mutation do
    # Add a new trait or capability
    %{
      meta_config: %{
        new_capability: {:set, true}
      }
    }
  end
  
  defp generate_deletion_mutation(_target) do
    # Remove or disable a feature
    %{
      meta_config: %{
        evolution_enabled: {:set, false}
      }
    }
  end
  
  defp generate_duplication_mutation(_target) do
    # Duplicate a system configuration
    %{
      system1_config: %{
        agent_count: {:multiply, 2}
      }
    }
  end
  
  defp generate_inversion_mutation(_target) do
    # Invert behavioral traits
    %{
      behavioral_traits: %{
        aggression: {:set, :rand.uniform()},
        cooperation: {:set, :rand.uniform()}
      }
    }
  end
  
  defp improve_weakest_trait(dna) do
    # Find and improve the weakest behavioral trait
    weakest = dna.behavioral_traits
    |> Enum.min_by(fn {_k, v} -> v end)
    |> elem(0)
    
    %{
      behavioral_traits: %{
        weakest => {:add, 0.2}
      }
    }
  end
  
  defp modify_random_trait(_dna) do
    trait = Enum.random([:aggression, :cooperation, :exploration, :exploitation])
    change = (:rand.uniform() - 0.5) * 0.2
    
    %{
      behavioral_traits: %{
        trait => {:add, change}
      }
    }
  end
  
  defp radical_change(_dna) do
    %{
      meta_config: %{
        mutation_rate: {:set, 0.3},
        spawning_rate: {:multiply, 2}
      },
      behavioral_traits: %{
        risk_tolerance: {:set, 0.9}
      }
    }
  end
  
  defp calculate_expected_fitness(mutations, current_fitness) do
    # Estimate fitness impact of mutations
    beneficial_count = Enum.count(mutations, fn {_, type, _} -> type == :beneficial end)
    harmful_count = Enum.count(mutations, fn {_, type, _} -> type == :harmful end)
    
    fitness_change = (beneficial_count * 0.1) - (harmful_count * 0.15)
    max(0.0, min(1.0, current_fitness + fitness_change))
  end
  
  defp apply_drift_mutation(dna) do
    # Small random change
    target = Enum.random([:system1_config, :system2_config, :system3_config, 
                          :system4_config, :system5_config])
    
    update_in(dna, [target], fn config ->
      if is_map(config) do
        key = config |> Map.keys() |> Enum.random()
        value = Map.get(config, key)
        
        if is_number(value) do
          drift = (:rand.uniform() - 0.5) * 0.02
          Map.put(config, key, value + drift)
        else
          config
        end
      else
        config
      end
    end)
  end
  
  defp calculate_goal_similarity(dna, goal_traits) do
    # Calculate how close DNA is to goal traits
    Enum.reduce(goal_traits, 0.0, fn {trait_path, goal_value}, score ->
      current_value = get_in(dna, trait_path)
      
      if current_value && is_number(current_value) && is_number(goal_value) do
        difference = abs(current_value - goal_value)
        trait_score = 1.0 - min(1.0, difference)
        score + trait_score
      else
        score
      end
    end) / map_size(goal_traits)
  end
end