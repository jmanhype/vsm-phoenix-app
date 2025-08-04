defmodule VsmPhoenix.MetaVsm.Demo do
  @moduledoc """
  Demonstration module for META-VSM recursive spawning capabilities
  
  This module provides examples of:
  - Recursive VSM spawning
  - Genetic evolution
  - Fractal network creation
  - Swarm intelligence
  - Emergency response
  """
  
  require Logger
  alias VsmPhoenix.VsmSupervisor
  alias VsmPhoenix.MetaVsm.Core.MetaVsm
  alias VsmPhoenix.MetaVsm.Genetics.{DnaConfig, Evolution}
  alias VsmPhoenix.MetaVsm.Fractals.FractalArchitect
  
  @doc """
  Demonstrate basic recursive spawning
  """
  def demo_recursive_spawning do
    Logger.info("🎯 Starting Recursive Spawning Demo")
    
    # Spawn parent VSM
    {:ok, parent_id} = VsmSupervisor.spawn_meta_vsm(%{
      id: "demo_parent",
      specialization: :replicator
    })
    
    Logger.info("Parent VSM created: #{parent_id}")
    
    # Parent spawns children
    for i <- 1..3 do
      {:ok, child_id} = MetaVsm.spawn_child(parent_id, %{
        id: "demo_child_#{i}"
      })
      Logger.info("  Child #{i} spawned: #{child_id}")
      
      # Each child spawns grandchildren
      for j <- 1..2 do
        {:ok, grandchild_id} = MetaVsm.spawn_child(child_id, %{
          id: "demo_grandchild_#{i}_#{j}"
        })
        Logger.info("    Grandchild #{i}.#{j} spawned: #{grandchild_id}")
      end
    end
    
    # Display family tree
    tree = MetaVsm.get_family_tree(parent_id)
    Logger.info("Family Tree: #{inspect(tree, pretty: true)}")
    
    {:ok, parent_id}
  end
  
  @doc """
  Demonstrate genetic evolution
  """
  def demo_evolution do
    Logger.info("🧬 Starting Evolution Demo")
    
    # Create initial population
    population_size = 10
    Logger.info("Creating initial population of #{population_size} VSMs")
    
    population = for i <- 1..population_size do
      {:ok, vsm_id} = VsmSupervisor.spawn_meta_vsm(%{
        id: "evo_vsm_#{i}",
        dna: DnaConfig.generate_primordial_dna()
      })
      vsm_id
    end
    
    # Run evolution for multiple generations
    generations = 5
    
    evolved_population = Enum.reduce(1..generations, population, fn gen, current_pop ->
      Logger.info("Generation #{gen}:")
      
      # Measure fitness
      fitness_scores = Enum.map(current_pop, fn vsm_id ->
        MetaVsm.measure_fitness(vsm_id)
      end)
      
      avg_fitness = Enum.sum(fitness_scores) / length(fitness_scores)
      Logger.info("  Average fitness: #{Float.round(avg_fitness, 3)}")
      
      # Natural selection
      dnas = Enum.map(current_pop, &MetaVsm.get_dna/1)
      survivors = Evolution.natural_selection(dnas, fitness_scores, 0.5)
      
      # Reproduction
      new_generation = Evolution.reproduce_generation(survivors, population_size)
      
      # Spawn new generation
      new_vsm_ids = Enum.map(new_generation, fn dna ->
        {:ok, vsm_id} = VsmSupervisor.spawn_meta_vsm(%{
          id: "evo_gen#{gen}_#{System.unique_integer([:positive])}",
          dna: dna,
          generation: gen
        })
        vsm_id
      end)
      
      # Kill old generation (natural selection)
      Enum.each(current_pop, &MetaVsm.kill_unviable/1)
      
      new_vsm_ids
    end)
    
    # Check final genetic diversity
    final_dnas = Enum.map(evolved_population, &MetaVsm.get_dna/1)
    diversity = Evolution.genetic_diversity(final_dnas)
    Logger.info("Final genetic diversity: #{Float.round(diversity, 3)}")
    
    {:ok, evolved_population}
  end
  
  @doc """
  Demonstrate fractal network creation
  """
  def demo_fractal_network do
    Logger.info("🌿 Starting Fractal Network Demo")
    
    patterns = [:tree, :sierpinski, :dragon, :spiral]
    
    networks = Enum.map(patterns, fn pattern ->
      Logger.info("Creating #{pattern} fractal network...")
      
      {:ok, network} = VsmSupervisor.spawn_fractal_network(pattern, 4)
      
      Logger.info("  Network created: #{inspect(network)}")
      
      # Calculate fractal dimension
      dimension = FractalArchitect.calculate_fractal_dimension(network)
      Logger.info("  Fractal dimension: #{Float.round(dimension, 3)}")
      
      {pattern, network}
    end)
    
    {:ok, networks}
  end
  
  @doc """
  Demonstrate swarm intelligence
  """
  def demo_swarm_intelligence do
    Logger.info("🐝 Starting Swarm Intelligence Demo")
    
    # Create cooperative swarm
    {:ok, swarm1} = VsmSupervisor.spawn_vsm_swarm(10, :cooperative)
    Logger.info("Cooperative swarm created: #{swarm1.swarm_id}")
    
    # Create competitive swarm
    {:ok, swarm2} = VsmSupervisor.spawn_vsm_swarm(10, :hostile)
    Logger.info("Competitive swarm created: #{swarm2.swarm_id}")
    
    # Send collective task to cooperative swarm
    Enum.each(swarm1.members, fn member_id ->
      MetaVsm.broadcast_to_descendants(member_id, {:collective_task, :resource_optimization})
    end)
    
    # Observe emergent behavior
    :timer.sleep(2000)
    
    # Check swarm coherence
    swarm1_dnas = Enum.map(swarm1.members, &MetaVsm.get_dna/1)
    coherence = calculate_swarm_coherence(swarm1_dnas)
    Logger.info("Swarm 1 coherence: #{Float.round(coherence, 3)}")
    
    swarm2_dnas = Enum.map(swarm2.members, &MetaVsm.get_dna/1)
    coherence2 = calculate_swarm_coherence(swarm2_dnas)
    Logger.info("Swarm 2 coherence: #{Float.round(coherence2, 3)}")
    
    {:ok, %{cooperative: swarm1, competitive: swarm2}}
  end
  
  @doc """
  Demonstrate emergency response system
  """
  def demo_emergency_response do
    Logger.info("🚨 Starting Emergency Response Demo")
    
    # Simulate different crisis types
    crisis_scenarios = [
      :resource_shortage,
      :external_threat,
      :innovation_needed
    ]
    
    responses = Enum.map(crisis_scenarios, fn crisis ->
      Logger.info("Simulating crisis: #{crisis}")
      
      # Trigger emergency spawn
      vsms = VsmSupervisor.emergency_spawn(crisis, 3)
      
      Logger.info("  Emergency VSMs spawned: #{length(vsms)}")
      
      # Check specialized traits
      Enum.each(vsms, fn {:ok, vsm_id} ->
        dna = MetaVsm.get_dna(vsm_id)
        traits = DnaConfig.dominant_traits(dna)
        Logger.info("    VSM #{vsm_id} traits: #{inspect(traits)}")
      end)
      
      {crisis, vsms}
    end)
    
    {:ok, responses}
  end
  
  @doc """
  Demonstrate VSM merging (sexual reproduction)
  """
  def demo_vsm_merging do
    Logger.info("💞 Starting VSM Merging Demo")
    
    # Create two parent VSMs with different specializations
    {:ok, parent1} = VsmSupervisor.spawn_meta_vsm(%{
      id: "merge_parent1",
      dna: DnaConfig.generate_specialized_dna(:explorer)
    })
    
    {:ok, parent2} = VsmSupervisor.spawn_meta_vsm(%{
      id: "merge_parent2",
      dna: DnaConfig.generate_specialized_dna(:optimizer)
    })
    
    Logger.info("Parent 1 (Explorer) created: #{parent1}")
    Logger.info("Parent 2 (Optimizer) created: #{parent2}")
    
    # Merge VSMs to create offspring
    {:ok, offspring_id} = MetaVsm.merge_vsms(parent1, parent2)
    
    Logger.info("Offspring created: #{offspring_id}")
    
    # Check offspring traits
    offspring_dna = MetaVsm.get_dna(offspring_id)
    traits = DnaConfig.dominant_traits(offspring_dna)
    
    Logger.info("Offspring inherited traits: #{inspect(traits)}")
    
    # Check similarity to parents
    parent1_dna = MetaVsm.get_dna(parent1)
    parent2_dna = MetaVsm.get_dna(parent2)
    
    sim1 = DnaConfig.similarity(offspring_dna, parent1_dna)
    sim2 = DnaConfig.similarity(offspring_dna, parent2_dna)
    
    Logger.info("Similarity to Parent 1: #{Float.round(sim1, 3)}")
    Logger.info("Similarity to Parent 2: #{Float.round(sim2, 3)}")
    
    {:ok, %{
      parent1: parent1,
      parent2: parent2,
      offspring: offspring_id,
      inherited_traits: traits
    }}
  end
  
  @doc """
  Run all demonstrations
  """
  def run_all_demos do
    Logger.info("🎭 Running All META-VSM Demonstrations")
    Logger.info("=" |> String.duplicate(50))
    
    demos = [
      {:recursive_spawning, &demo_recursive_spawning/0},
      {:evolution, &demo_evolution/0},
      {:fractal_network, &demo_fractal_network/0},
      {:swarm_intelligence, &demo_swarm_intelligence/0},
      {:emergency_response, &demo_emergency_response/0},
      {:vsm_merging, &demo_vsm_merging/0}
    ]
    
    results = Enum.map(demos, fn {name, demo_fn} ->
      Logger.info("")
      Logger.info("Running #{name} demo...")
      Logger.info("-" |> String.duplicate(30))
      
      result = demo_fn.()
      :timer.sleep(1000)  # Brief pause between demos
      
      {name, result}
    end)
    
    Logger.info("")
    Logger.info("=" |> String.duplicate(50))
    Logger.info("All demonstrations completed!")
    
    # Display population statistics
    stats = VsmSupervisor.get_population_stats()
    Logger.info("Final Population Statistics:")
    Logger.info("  Total VSMs: #{stats.total_vsms}")
    Logger.info("  Active VSMs: #{stats.active_vsms}")
    Logger.info("  Average Fitness: #{Float.round(stats.average_fitness, 3)}")
    Logger.info("  Genetic Diversity: #{Float.round(stats.genetic_diversity, 3)}")
    Logger.info("  Deepest Recursion: #{stats.deepest_recursion}")
    
    {:ok, results}
  end
  
  @doc """
  Clean up all META-VSMs (for testing)
  """
  def cleanup_all do
    Logger.info("🧹 Cleaning up all META-VSMs")
    
    Registry.select(VsmPhoenix.MetaVsmRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.each(fn vsm_id ->
      try do
        MetaVsm.kill_unviable(vsm_id)
      catch
        :exit, _ -> :ok
      end
    end)
    
    Logger.info("Cleanup completed")
    :ok
  end
  
  # Private helper functions
  
  defp calculate_swarm_coherence(dnas) do
    if length(dnas) < 2 do
      1.0
    else
      # Calculate average similarity between all pairs
      pairs = for d1 <- dnas, d2 <- dnas, d1 != d2, do: {d1, d2}
      
      similarities = Enum.map(pairs, fn {dna1, dna2} ->
        DnaConfig.similarity(dna1, dna2)
      end)
      
      if length(similarities) > 0 do
        Enum.sum(similarities) / length(similarities)
      else
        0.0
      end
    end
  end
end