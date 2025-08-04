defmodule VsmPhoenix.EmergentIntelligence.SwarmMind do
  @moduledoc """
  Collective intelligence system that emerges from swarm interactions.
  Implements distributed consciousness and group decision-making.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.S5.{HolonManager, SynergyOptimizer, MetasystemManager}
  alias VsmPhoenix.EmergentIntelligence.{EmergentBehavior, CollectiveLearning, SelfOrganization}

  @collective_threshold 0.75  # Consensus threshold for decisions
  @emergence_detection_interval 5_000
  @consciousness_sync_interval 2_000
  @learning_batch_size 100

  # Swarm consciousness states
  @states [:dispersed, :converging, :synchronized, :transcendent]

  defstruct [
    :id,
    :agents,
    :collective_memory,
    :consciousness_level,
    :emergence_patterns,
    :decision_history,
    :learning_buffer,
    :synchronization_matrix,
    :state,
    :metrics,
    :created_at,
    :updated_at
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_agent(agent_id, capabilities) do
    GenServer.call(__MODULE__, {:add_agent, agent_id, capabilities})
  end

  def collective_decision(decision_context) do
    GenServer.call(__MODULE__, {:collective_decision, decision_context})
  end

  def get_consciousness_level do
    GenServer.call(__MODULE__, :get_consciousness_level)
  end

  def synchronize_swarm do
    GenServer.cast(__MODULE__, :synchronize_swarm)
  end

  def detect_emergence do
    GenServer.call(__MODULE__, :detect_emergence)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    
    state = %__MODULE__{
      id: generate_swarm_id(),
      agents: %{},
      collective_memory: initialize_memory(),
      consciousness_level: 0.0,
      emergence_patterns: [],
      decision_history: [],
      learning_buffer: [],
      synchronization_matrix: %{},
      state: :dispersed,
      metrics: initialize_metrics(),
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    schedule_emergence_detection()
    schedule_consciousness_sync()

    Logger.info("SwarmMind initialized: #{state.id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:add_agent, agent_id, capabilities}, _from, state) do
    agent = %{
      id: agent_id,
      capabilities: capabilities,
      contribution_score: 0.5,
      synchronization: 0.0,
      joined_at: DateTime.utc_now()
    }

    new_agents = Map.put(state.agents, agent_id, agent)
    updated_state = %{state | agents: new_agents}
    
    # Recalculate consciousness level
    consciousness = calculate_consciousness_level(updated_state)
    
    {:reply, :ok, %{updated_state | consciousness_level: consciousness}}
  end

  @impl true
  def handle_call({:collective_decision, context}, _from, state) do
    # Gather input from all agents
    agent_inputs = gather_agent_inputs(state.agents, context)
    
    # Apply swarm intelligence algorithms
    decision = apply_swarm_algorithms(agent_inputs, context, state)
    
    # Update decision history
    history_entry = %{
      context: context,
      decision: decision,
      participants: Map.keys(state.agents),
      consciousness_level: state.consciousness_level,
      timestamp: DateTime.utc_now()
    }
    
    new_history = [history_entry | state.decision_history] |> Enum.take(1000)
    
    # Learn from decision
    updated_state = learn_from_decision(state, decision, context)
    
    {:reply, {:ok, decision}, %{updated_state | decision_history: new_history}}
  end

  @impl true
  def handle_call(:get_consciousness_level, _from, state) do
    {:reply, state.consciousness_level, state}
  end

  @impl true
  def handle_call(:detect_emergence, _from, state) do
    patterns = detect_emergent_patterns(state)
    behaviors = EmergentBehavior.detect_behaviors(state.agents, state.decision_history)
    
    emergence_data = %{
      patterns: patterns,
      behaviors: behaviors,
      consciousness_level: state.consciousness_level,
      swarm_state: state.state
    }
    
    updated_state = %{state | emergence_patterns: patterns}
    
    {:reply, emergence_data, updated_state}
  end

  @impl true
  def handle_cast(:synchronize_swarm, state) do
    # Synchronize all agents
    synchronized_agents = synchronize_agents(state.agents)
    
    # Update synchronization matrix
    sync_matrix = calculate_sync_matrix(synchronized_agents)
    
    # Determine new swarm state
    new_state = determine_swarm_state(sync_matrix, state.consciousness_level)
    
    updated_state = %{state | 
      agents: synchronized_agents,
      synchronization_matrix: sync_matrix,
      state: new_state,
      updated_at: DateTime.utc_now()
    }
    
    {:noreply, updated_state}
  end

  @impl true
  def handle_info(:emergence_detection, state) do
    patterns = detect_emergent_patterns(state)
    
    # Trigger self-organization if patterns detected
    state = if length(patterns) > 0 do
      SelfOrganization.reorganize(state, patterns)
    else
      state
    end
    
    schedule_emergence_detection()
    {:noreply, %{state | emergence_patterns: patterns}}
  end

  @impl true
  def handle_info(:consciousness_sync, state) do
    # Synchronize collective consciousness
    consciousness = calculate_consciousness_level(state)
    
    # Apply collective learning
    state = if length(state.learning_buffer) >= @learning_batch_size do
      CollectiveLearning.apply_learning(state, state.learning_buffer)
    else
      state
    end
    
    schedule_consciousness_sync()
    {:noreply, %{state | consciousness_level: consciousness}}
  end

  # Private Functions

  defp generate_swarm_id do
    "swarm_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp initialize_memory do
    %{
      shared_knowledge: %{},
      collective_experiences: [],
      emergent_insights: [],
      synchronization_patterns: []
    }
  end

  defp initialize_metrics do
    %{
      total_decisions: 0,
      consensus_rate: 0.0,
      emergence_events: 0,
      avg_sync_level: 0.0,
      collective_intelligence_score: 0.0
    }
  end

  defp gather_agent_inputs(agents, context) do
    agents
    |> Enum.map(fn {id, agent} ->
      input = generate_agent_input(agent, context)
      weight = calculate_input_weight(agent)
      {id, input, weight}
    end)
  end

  defp generate_agent_input(agent, context) do
    # Generate input based on agent capabilities and context
    %{
      perspective: analyze_context(agent.capabilities, context),
      confidence: calculate_confidence(agent, context),
      suggestions: generate_suggestions(agent, context)
    }
  end

  defp calculate_input_weight(agent) do
    # Weight based on contribution score and synchronization
    base_weight = agent.contribution_score
    sync_bonus = agent.synchronization * 0.3
    min(1.0, base_weight + sync_bonus)
  end

  defp analyze_context(capabilities, context) do
    # Analyze context from agent's capability perspective
    relevant_aspects = Enum.filter(context, fn {key, _} ->
      Enum.any?(capabilities, &capability_matches?(&1, key))
    end)
    
    Map.new(relevant_aspects)
  end

  defp capability_matches?(capability, context_key) do
    capability_str = to_string(capability)
    context_str = to_string(context_key)
    String.contains?(capability_str, context_str) or String.contains?(context_str, capability_str)
  end

  defp calculate_confidence(agent, context) do
    # Calculate confidence based on past performance and relevance
    base_confidence = agent.contribution_score
    relevance = calculate_relevance(agent.capabilities, context)
    base_confidence * relevance
  end

  defp calculate_relevance(capabilities, context) do
    context_keys = Map.keys(context)
    matching_capabilities = Enum.count(capabilities, fn cap ->
      Enum.any?(context_keys, &capability_matches?(cap, &1))
    end)
    
    if length(capabilities) > 0 do
      matching_capabilities / length(capabilities)
    else
      0.0
    end
  end

  defp generate_suggestions(agent, context) do
    # Generate suggestions based on agent's capabilities
    agent.capabilities
    |> Enum.map(fn capability ->
      %{
        type: capability,
        action: suggest_action(capability, context),
        priority: calculate_priority(capability, context)
      }
    end)
    |> Enum.filter(& &1.action != nil)
  end

  defp suggest_action(capability, context) do
    case capability do
      :optimization -> optimize_suggestion(context)
      :analysis -> analyze_suggestion(context)
      :coordination -> coordinate_suggestion(context)
      :execution -> execute_suggestion(context)
      _ -> nil
    end
  end

  defp optimize_suggestion(context) do
    %{
      action: :optimize,
      target: Map.get(context, :bottleneck, :general),
      method: :gradient_descent
    }
  end

  defp analyze_suggestion(context) do
    %{
      action: :analyze,
      focus: Map.get(context, :problem_area, :system),
      depth: :comprehensive
    }
  end

  defp coordinate_suggestion(context) do
    %{
      action: :coordinate,
      entities: Map.get(context, :agents, []),
      strategy: :consensus
    }
  end

  defp execute_suggestion(context) do
    %{
      action: :execute,
      task: Map.get(context, :primary_task, :default),
      mode: :parallel
    }
  end

  defp calculate_priority(capability, context) do
    urgency = Map.get(context, :urgency, 0.5)
    relevance = calculate_relevance([capability], context)
    urgency * relevance
  end

  defp apply_swarm_algorithms(agent_inputs, context, state) do
    # Apply multiple swarm intelligence algorithms
    
    # 1. Ant Colony Optimization for path finding
    aco_result = ant_colony_optimization(agent_inputs, context)
    
    # 2. Particle Swarm Optimization for solution search
    pso_result = particle_swarm_optimization(agent_inputs, state)
    
    # 3. Bee Algorithm for resource allocation
    bee_result = bee_algorithm(agent_inputs, context)
    
    # 4. Firefly Algorithm for synchronization
    firefly_result = firefly_algorithm(agent_inputs, state.synchronization_matrix)
    
    # Combine results using weighted voting
    combine_swarm_results([aco_result, pso_result, bee_result, firefly_result], state.consciousness_level)
  end

  defp ant_colony_optimization(inputs, context) do
    # Simplified ACO implementation
    pheromone_trails = initialize_pheromone_trails(inputs)
    
    best_path = Enum.reduce(1..10, nil, fn _iteration, current_best ->
      paths = generate_ant_paths(inputs, pheromone_trails)
      best = find_best_path(paths, context)
      update_pheromones(pheromone_trails, best)
      
      if current_best == nil or path_quality(best) > path_quality(current_best) do
        best
      else
        current_best
      end
    end)
    
    %{algorithm: :aco, result: best_path}
  end

  defp particle_swarm_optimization(inputs, state) do
    # Simplified PSO implementation
    particles = initialize_particles(inputs)
    global_best = find_best_particle(particles)
    
    updated_particles = Enum.reduce(1..20, particles, fn _iteration, current_particles ->
      moved_particles = Enum.map(current_particles, fn particle ->
        velocity = calculate_velocity(particle, global_best, state)
        position = update_position(particle, velocity)
        %{particle | velocity: velocity, position: position}
      end)
      
      new_global_best = find_best_particle(moved_particles)
      if particle_fitness(new_global_best) > particle_fitness(global_best) do
        new_global_best
      else
        global_best
      end
      
      moved_particles
    end)
    
    %{algorithm: :pso, result: find_best_particle(updated_particles)}
  end

  defp bee_algorithm(inputs, context) do
    # Simplified Bee Algorithm
    scout_bees = deploy_scouts(inputs)
    food_sources = discover_food_sources(scout_bees, context)
    
    best_source = Enum.reduce(1..15, nil, fn _iteration, current_best ->
      # Worker bees exploit food sources
      exploited = exploit_sources(food_sources, inputs)
      
      # Onlooker bees select sources probabilistically
      selected = onlooker_selection(exploited)
      
      # Find best source
      best = find_best_source(selected)
      
      if current_best == nil or source_quality(best) > source_quality(current_best) do
        best
      else
        current_best
      end
    end)
    
    %{algorithm: :bee, result: best_source}
  end

  defp firefly_algorithm(inputs, sync_matrix) do
    # Simplified Firefly Algorithm for synchronization
    fireflies = initialize_fireflies(inputs)
    
    synchronized = Enum.reduce(1..25, fireflies, fn _iteration, current_fireflies ->
      Enum.map(current_fireflies, fn firefly ->
        # Move towards brighter fireflies
        brighter = find_brighter_fireflies(firefly, current_fireflies)
        
        if length(brighter) > 0 do
          target = Enum.random(brighter)
          move_towards(firefly, target, sync_matrix)
        else
          random_walk(firefly)
        end
      end)
    end)
    
    %{algorithm: :firefly, result: calculate_synchronization(synchronized)}
  end

  defp combine_swarm_results(results, consciousness_level) do
    # Weight results based on consciousness level
    weights = calculate_algorithm_weights(consciousness_level)
    
    weighted_results = Enum.zip(results, weights)
    |> Enum.map(fn {result, weight} ->
      score_result(result) * weight
    end)
    
    # Select best weighted result
    best_index = Enum.find_index(weighted_results, fn score ->
      score == Enum.max(weighted_results)
    end)
    
    Enum.at(results, best_index).result
  end

  defp calculate_algorithm_weights(consciousness_level) do
    # Adjust weights based on consciousness level
    base_weights = [0.25, 0.25, 0.25, 0.25]
    
    if consciousness_level > 0.8 do
      # High consciousness: favor synchronization
      [0.2, 0.2, 0.2, 0.4]
    elsif consciousness_level > 0.5 do
      # Medium consciousness: balanced
      base_weights
    else
      # Low consciousness: favor exploration
      [0.3, 0.3, 0.3, 0.1]
    end
  end

  defp score_result(result) do
    # Score algorithm result quality
    Map.get(result.result, :quality, 0.5)
  end

  defp learn_from_decision(state, decision, context) do
    # Add to learning buffer
    learning_entry = %{
      decision: decision,
      context: context,
      agents: state.agents,
      consciousness: state.consciousness_level,
      timestamp: DateTime.utc_now()
    }
    
    new_buffer = [learning_entry | state.learning_buffer]
    
    # Apply immediate learning if buffer is full
    if length(new_buffer) >= @learning_batch_size do
      CollectiveLearning.apply_learning(state, new_buffer)
    else
      %{state | learning_buffer: new_buffer}
    end
  end

  defp calculate_consciousness_level(state) do
    # Calculate collective consciousness based on multiple factors
    
    # 1. Agent synchronization
    sync_level = calculate_average_sync(state.agents)
    
    # 2. Shared memory coherence
    memory_coherence = calculate_memory_coherence(state.collective_memory)
    
    # 3. Decision consensus history
    consensus_rate = calculate_consensus_rate(state.decision_history)
    
    # 4. Emergence pattern strength
    emergence_strength = calculate_emergence_strength(state.emergence_patterns)
    
    # Weighted combination
    (sync_level * 0.3 + memory_coherence * 0.2 + 
     consensus_rate * 0.3 + emergence_strength * 0.2)
  end

  defp calculate_average_sync(agents) do
    if map_size(agents) == 0 do
      0.0
    else
      total_sync = Enum.reduce(agents, 0.0, fn {_, agent}, acc ->
        acc + agent.synchronization
      end)
      total_sync / map_size(agents)
    end
  end

  defp calculate_memory_coherence(memory) do
    # Check coherence of shared knowledge
    shared_items = Map.get(memory, :shared_knowledge, %{}) |> map_size()
    experiences = length(Map.get(memory, :collective_experiences, []))
    
    if shared_items + experiences == 0 do
      0.0
    else
      # Simple coherence metric
      min(1.0, (shared_items + experiences) / 100)
    end
  end

  defp calculate_consensus_rate(history) do
    if length(history) == 0 do
      0.5
    else
      recent_decisions = Enum.take(history, 10)
      
      consensus_count = Enum.count(recent_decisions, fn decision ->
        Map.get(decision, :consensus_level, 0.0) > @collective_threshold
      end)
      
      consensus_count / length(recent_decisions)
    end
  end

  defp calculate_emergence_strength(patterns) do
    if length(patterns) == 0 do
      0.0
    else
      avg_strength = Enum.reduce(patterns, 0.0, fn pattern, acc ->
        acc + Map.get(pattern, :strength, 0.0)
      end) / length(patterns)
      
      min(1.0, avg_strength)
    end
  end

  defp synchronize_agents(agents) do
    # Synchronize all agents using firefly-inspired algorithm
    Map.new(agents, fn {id, agent} ->
      neighbors = find_neighbors(id, agents)
      sync_value = calculate_sync_value(agent, neighbors)
      
      updated_agent = %{agent | 
        synchronization: sync_value,
        contribution_score: update_contribution_score(agent, sync_value)
      }
      
      {id, updated_agent}
    end)
  end

  defp find_neighbors(agent_id, agents) do
    # Find agents with similar capabilities
    target_agent = Map.get(agents, agent_id)
    
    agents
    |> Enum.filter(fn {id, _} -> id != agent_id end)
    |> Enum.filter(fn {_, agent} ->
      capability_overlap(target_agent.capabilities, agent.capabilities) > 0.3
    end)
    |> Enum.map(fn {_, agent} -> agent end)
  end

  defp capability_overlap(caps1, caps2) do
    if length(caps1) == 0 or length(caps2) == 0 do
      0.0
    else
      common = MapSet.intersection(MapSet.new(caps1), MapSet.new(caps2)) |> MapSet.size()
      total = MapSet.union(MapSet.new(caps1), MapSet.new(caps2)) |> MapSet.size()
      
      if total > 0 do
        common / total
      else
        0.0
      end
    end
  end

  defp calculate_sync_value(agent, neighbors) do
    if length(neighbors) == 0 do
      agent.synchronization
    else
      # Average synchronization with neighbors
      neighbor_sync = Enum.reduce(neighbors, 0.0, fn neighbor, acc ->
        acc + neighbor.synchronization
      end) / length(neighbors)
      
      # Move towards neighbor average
      agent.synchronization * 0.7 + neighbor_sync * 0.3
    end
  end

  defp update_contribution_score(agent, sync_value) do
    # Update contribution based on synchronization
    base_score = agent.contribution_score
    sync_bonus = (sync_value - 0.5) * 0.2
    
    new_score = base_score + sync_bonus
    max(0.0, min(1.0, new_score))
  end

  defp calculate_sync_matrix(agents) do
    # Calculate pairwise synchronization matrix
    agent_list = Map.to_list(agents)
    
    matrix = for {id1, agent1} <- agent_list,
                 {id2, agent2} <- agent_list,
                 id1 != id2,
                 into: %{} do
      sync_value = abs(agent1.synchronization - agent2.synchronization)
      {{id1, id2}, 1.0 - sync_value}
    end
    
    matrix
  end

  defp determine_swarm_state(sync_matrix, consciousness_level) do
    # Determine swarm state based on synchronization and consciousness
    avg_sync = if map_size(sync_matrix) > 0 do
      Map.values(sync_matrix) |> Enum.sum() |> Kernel./(map_size(sync_matrix))
    else
      0.0
    end
    
    cond do
      consciousness_level > 0.9 and avg_sync > 0.85 -> :transcendent
      consciousness_level > 0.7 and avg_sync > 0.7 -> :synchronized
      consciousness_level > 0.5 and avg_sync > 0.5 -> :converging
      true -> :dispersed
    end
  end

  defp detect_emergent_patterns(state) do
    # Detect patterns in collective behavior
    
    patterns = []
    
    # Check for consensus patterns
    consensus_pattern = detect_consensus_pattern(state.decision_history)
    patterns = if consensus_pattern, do: [consensus_pattern | patterns], else: patterns
    
    # Check for synchronization waves
    sync_pattern = detect_sync_waves(state.agents)
    patterns = if sync_pattern, do: [sync_pattern | patterns], else: patterns
    
    # Check for knowledge crystallization
    knowledge_pattern = detect_knowledge_crystallization(state.collective_memory)
    patterns = if knowledge_pattern, do: [knowledge_pattern | patterns], else: patterns
    
    # Check for self-organization
    org_pattern = detect_self_organization(state.agents, state.synchronization_matrix)
    patterns = if org_pattern, do: [org_pattern | patterns], else: patterns
    
    patterns
  end

  defp detect_consensus_pattern(history) do
    recent = Enum.take(history, 20)
    
    if length(recent) >= 5 do
      consensus_trend = Enum.map(recent, & &1.consciousness_level)
      
      if trending_up?(consensus_trend) do
        %{
          type: :consensus_emergence,
          strength: calculate_trend_strength(consensus_trend),
          data: consensus_trend
        }
      else
        nil
      end
    else
      nil
    end
  end

  defp detect_sync_waves(agents) do
    sync_values = agents
    |> Map.values()
    |> Enum.map(& &1.synchronization)
    
    if length(sync_values) >= 3 do
      variance = calculate_variance(sync_values)
      
      if variance < 0.1 do
        %{
          type: :synchronization_wave,
          strength: 1.0 - variance,
          data: sync_values
        }
      else
        nil
      end
    else
      nil
    end
  end

  defp detect_knowledge_crystallization(memory) do
    shared_knowledge = Map.get(memory, :shared_knowledge, %{})
    insights = Map.get(memory, :emergent_insights, [])
    
    if map_size(shared_knowledge) > 10 or length(insights) > 5 do
      %{
        type: :knowledge_crystallization,
        strength: min(1.0, (map_size(shared_knowledge) + length(insights)) / 30),
        data: %{
          knowledge_items: map_size(shared_knowledge),
          insights: length(insights)
        }
      }
    else
      nil
    end
  end

  defp detect_self_organization(agents, sync_matrix) do
    if map_size(agents) >= 3 and map_size(sync_matrix) > 0 do
      # Check for cluster formation
      clusters = identify_clusters(agents, sync_matrix)
      
      if length(clusters) > 1 do
        %{
          type: :self_organization,
          strength: calculate_cluster_strength(clusters),
          data: clusters
        }
      else
        nil
      end
    else
      nil
    end
  end

  defp identify_clusters(agents, sync_matrix) do
    # Simple clustering based on synchronization values
    threshold = 0.7
    
    agents
    |> Map.keys()
    |> Enum.reduce([], fn agent_id, clusters ->
      # Find cluster for this agent
      cluster_idx = Enum.find_index(clusters, fn cluster ->
        Enum.any?(cluster, fn other_id ->
          sync_value = Map.get(sync_matrix, {agent_id, other_id}, 0.0)
          sync_value > threshold
        end)
      end)
      
      if cluster_idx do
        List.update_at(clusters, cluster_idx, &[agent_id | &1])
      else
        [[agent_id] | clusters]
      end
    end)
  end

  defp calculate_cluster_strength(clusters) do
    if length(clusters) == 0 do
      0.0
    else
      avg_size = Enum.reduce(clusters, 0, fn cluster, acc ->
        acc + length(cluster)
      end) / length(clusters)
      
      min(1.0, avg_size / 10)
    end
  end

  defp trending_up?(values) do
    if length(values) < 2 do
      false
    else
      pairs = Enum.zip(values, Enum.drop(values, 1))
      increasing = Enum.count(pairs, fn {a, b} -> b > a end)
      increasing > length(pairs) * 0.6
    end
  end

  defp calculate_trend_strength(values) do
    if length(values) < 2 do
      0.0
    else
      first = List.first(values)
      last = List.last(values)
      change = (last - first) / max(0.01, first)
      min(1.0, abs(change))
    end
  end

  defp calculate_variance(values) do
    if length(values) == 0 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      sum_squared_diff = Enum.reduce(values, 0.0, fn val, acc ->
        acc + :math.pow(val - mean, 2)
      end)
      sum_squared_diff / length(values)
    end
  end

  # Helper functions for swarm algorithms

  defp initialize_pheromone_trails(inputs) do
    # Initialize pheromone trails between input nodes
    %{}
  end

  defp generate_ant_paths(inputs, _trails) do
    # Generate paths through decision space
    Enum.map(1..10, fn _ ->
      %{path: Enum.shuffle(inputs), quality: :rand.uniform()}
    end)
  end

  defp find_best_path(paths, _context) do
    Enum.max_by(paths, & &1.quality)
  end

  defp path_quality(path) do
    Map.get(path, :quality, 0.0)
  end

  defp update_pheromones(_trails, _best_path) do
    # Update pheromone trails based on best path
    %{}
  end

  defp initialize_particles(inputs) do
    Enum.map(inputs, fn {id, input, weight} ->
      %{
        id: id,
        position: input,
        velocity: %{},
        best_position: input,
        fitness: weight
      }
    end)
  end

  defp find_best_particle(particles) do
    Enum.max_by(particles, & &1.fitness)
  end

  defp particle_fitness(particle) do
    Map.get(particle, :fitness, 0.0)
  end

  defp calculate_velocity(particle, global_best, _state) do
    # Simplified velocity calculation
    inertia = 0.7
    cognitive = 0.2
    social = 0.1
    
    %{
      x: inertia * Map.get(particle.velocity, :x, 0) +
         cognitive * :rand.uniform() +
         social * (Map.get(global_best, :fitness, 0) - particle.fitness)
    }
  end

  defp update_position(particle, velocity) do
    # Update particle position based on velocity
    Map.merge(particle.position, velocity)
  end

  defp deploy_scouts(inputs) do
    # Deploy scout bees to explore
    Enum.take_random(inputs, max(1, div(length(inputs), 3)))
  end

  defp discover_food_sources(scouts, _context) do
    # Discover food sources (solutions)
    Enum.map(scouts, fn {id, input, weight} ->
      %{id: id, location: input, quality: weight * :rand.uniform()}
    end)
  end

  defp exploit_sources(sources, _inputs) do
    # Worker bees exploit sources
    Enum.map(sources, fn source ->
      %{source | quality: source.quality * (0.9 + :rand.uniform() * 0.2)}
    end)
  end

  defp onlooker_selection(sources) do
    # Probabilistic selection by onlooker bees
    total_quality = Enum.reduce(sources, 0.0, & &1.quality + &2)
    
    selected = Enum.filter(sources, fn source ->
      probability = source.quality / max(0.01, total_quality)
      :rand.uniform() < probability
    end)
    
    if length(selected) > 0, do: selected, else: sources
  end

  defp find_best_source(sources) do
    if length(sources) > 0 do
      Enum.max_by(sources, & &1.quality)
    else
      %{quality: 0.0}
    end
  end

  defp source_quality(source) do
    Map.get(source, :quality, 0.0)
  end

  defp initialize_fireflies(inputs) do
    Enum.map(inputs, fn {id, input, weight} ->
      %{
        id: id,
        position: input,
        brightness: weight,
        attractiveness: weight * 0.8
      }
    end)
  end

  defp find_brighter_fireflies(firefly, all_fireflies) do
    Enum.filter(all_fireflies, fn other ->
      other.id != firefly.id and other.brightness > firefly.brightness
    end)
  end

  defp move_towards(firefly, target, _sync_matrix) do
    # Move firefly towards target
    step_size = 0.1
    new_brightness = firefly.brightness + 
                    (target.brightness - firefly.brightness) * step_size
    
    %{firefly | 
      brightness: new_brightness,
      attractiveness: new_brightness * 0.8
    }
  end

  defp random_walk(firefly) do
    # Random walk for exploration
    change = (:rand.uniform() - 0.5) * 0.1
    %{firefly | 
      brightness: max(0.0, min(1.0, firefly.brightness + change))
    }
  end

  defp calculate_synchronization(fireflies) do
    if length(fireflies) == 0 do
      %{quality: 0.0}
    else
      avg_brightness = Enum.reduce(fireflies, 0.0, & &1.brightness + &2) / length(fireflies)
      %{quality: avg_brightness, synchronization: fireflies}
    end
  end

  defp schedule_emergence_detection do
    Process.send_after(self(), :emergence_detection, @emergence_detection_interval)
  end

  defp schedule_consciousness_sync do
    Process.send_after(self(), :consciousness_sync, @consciousness_sync_interval)
  end
end