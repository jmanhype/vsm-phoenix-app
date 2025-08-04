defmodule VsmPhoenix.EmergentIntelligence.SelfOrganization do
  @moduledoc """
  Implements self-organization mechanisms for the swarm.
  Enables autonomous restructuring and adaptation without central control.
  """

  require Logger
  alias VsmPhoenix.S5.{HolonManager, AlgedonicSignalProcessor}

  @reorganization_threshold 0.3
  @stability_threshold 0.8
  @adaptation_rate 0.15

  # Organization patterns
  @organization_patterns [
    :hierarchical,
    :flat,
    :mesh,
    :hub_and_spoke,
    :modular,
    :fractal,
    :small_world,
    :scale_free
  ]

  @doc """
  Reorganize swarm based on emergent patterns
  """
  def reorganize(state, patterns) do
    # Analyze current organization
    current_structure = analyze_current_structure(state)
    
    # Determine optimal organization
    optimal = determine_optimal_organization(patterns, current_structure, state)
    
    # Calculate reorganization plan
    plan = create_reorganization_plan(current_structure, optimal, state)
    
    # Execute reorganization
    reorganized_state = execute_reorganization(state, plan)
    
    # Verify stability
    if verify_stability(reorganized_state) do
      reorganized_state
    else
      # Rollback if unstable
      Logger.warn("Reorganization resulted in instability, rolling back")
      state
    end
  end

  @doc """
  Enable autonomous adaptation
  """
  def autonomous_adaptation(state) do
    # Detect environmental changes
    changes = detect_environmental_changes(state)
    
    # Calculate adaptation response
    adaptations = calculate_adaptations(changes, state)
    
    # Apply adaptations gradually
    apply_adaptations(state, adaptations)
  end

  @doc """
  Implement criticality and edge of chaos dynamics
  """
  def maintain_criticality(state) do
    # Calculate current criticality
    criticality = calculate_criticality(state)
    
    # Adjust parameters to maintain edge of chaos
    adjusted_params = if criticality < 0.6 do
      increase_disorder(state)
    elsif criticality > 0.8 do
      increase_order(state)
    else
      state  # Already at edge of chaos
    end
    
    adjusted_params
  end

  @doc """
  Create self-organizing clusters
  """
  def form_clusters(agents) do
    # Calculate affinity matrix
    affinity_matrix = calculate_affinity_matrix(agents)
    
    # Apply clustering algorithm
    clusters = spectral_clustering(affinity_matrix, agents)
    
    # Assign cluster roles
    clusters_with_roles = assign_cluster_roles(clusters)
    
    # Establish inter-cluster communication
    establish_cluster_links(clusters_with_roles)
  end

  @doc """
  Implement stigmergic coordination
  """
  def stigmergic_coordination(state, environment) do
    # Agents leave traces in environment
    traces = collect_agent_traces(state.agents)
    
    # Update environment with traces
    updated_env = update_environment_traces(environment, traces)
    
    # Agents respond to environmental traces
    coordinated_agents = coordinate_through_traces(state.agents, updated_env)
    
    %{state | 
      agents: coordinated_agents,
      environment: updated_env
    }
  end

  # Private Functions

  defp analyze_current_structure(state) do
    agents = Map.get(state, :agents, %{})
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    %{
      pattern: identify_organization_pattern(agents, sync_matrix),
      connectivity: calculate_connectivity(sync_matrix),
      hierarchy_level: calculate_hierarchy_level(agents),
      modularity: calculate_modularity(agents, sync_matrix),
      centralization: calculate_centralization(agents, sync_matrix),
      metrics: collect_structure_metrics(agents, sync_matrix)
    }
  end

  defp identify_organization_pattern(agents, sync_matrix) do
    # Identify current organization pattern
    connectivity = calculate_connectivity(sync_matrix)
    hierarchy = calculate_hierarchy_level(agents)
    centralization = calculate_centralization(agents, sync_matrix)
    
    cond do
      hierarchy > 0.7 -> :hierarchical
      connectivity > 0.8 and centralization < 0.3 -> :mesh
      centralization > 0.7 -> :hub_and_spoke
      connectivity < 0.3 -> :modular
      true -> :flat
    end
  end

  defp calculate_connectivity(sync_matrix) do
    if map_size(sync_matrix) == 0 do
      0.0
    else
      # Average connection strength
      total = Map.values(sync_matrix) |> Enum.sum()
      total / map_size(sync_matrix)
    end
  end

  defp calculate_hierarchy_level(agents) do
    # Calculate hierarchy based on contribution scores
    if map_size(agents) == 0 do
      0.0
    else
      scores = agents
      |> Map.values()
      |> Enum.map(& &1.contribution_score)
      
      # Gini coefficient as measure of hierarchy
      calculate_gini_coefficient(scores)
    end
  end

  defp calculate_gini_coefficient(values) do
    if length(values) < 2 do
      0.0
    else
      sorted = Enum.sort(values)
      n = length(sorted)
      
      sum = Enum.with_index(sorted)
      |> Enum.reduce(0.0, fn {val, i}, acc ->
        acc + (2 * (i + 1) - n - 1) * val
      end)
      
      sum / (n * Enum.sum(sorted))
    end
  end

  defp calculate_modularity(agents, sync_matrix) do
    # Calculate network modularity
    if map_size(agents) < 3 do
      0.0
    else
      # Simplified modularity calculation
      clusters = simple_clustering(agents, sync_matrix)
      
      if length(clusters) > 1 do
        internal_edges = count_internal_edges(clusters, sync_matrix)
        total_edges = map_size(sync_matrix)
        
        if total_edges > 0 do
          internal_edges / total_edges
        else
          0.0
        end
      else
        0.0
      end
    end
  end

  defp simple_clustering(agents, sync_matrix) do
    # Simple clustering based on synchronization
    threshold = 0.6
    
    agents
    |> Map.keys()
    |> Enum.reduce([], fn agent_id, clusters ->
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

  defp count_internal_edges(clusters, sync_matrix) do
    Enum.reduce(clusters, 0, fn cluster, acc ->
      internal = for a1 <- cluster, a2 <- cluster, a1 != a2 do
        if Map.has_key?(sync_matrix, {a1, a2}) do
          1
        else
          0
        end
      end
      |> Enum.sum()
      
      acc + internal
    end)
  end

  defp calculate_centralization(agents, sync_matrix) do
    # Calculate network centralization
    if map_size(agents) == 0 do
      0.0
    else
      # Calculate degree centrality for each agent
      centralities = Map.new(agents, fn {id, _} ->
        degree = Enum.count(sync_matrix, fn {{a1, a2}, _} ->
          a1 == id or a2 == id
        end)
        {id, degree}
      end)
      
      max_centrality = centralities |> Map.values() |> Enum.max(fn -> 0 end)
      avg_centrality = if map_size(centralities) > 0 do
        Map.values(centralities) |> Enum.sum() |> Kernel./(map_size(centralities))
      else
        0
      end
      
      if avg_centrality > 0 do
        (max_centrality - avg_centrality) / max_centrality
      else
        0.0
      end
    end
  end

  defp collect_structure_metrics(agents, sync_matrix) do
    %{
      agent_count: map_size(agents),
      edge_count: map_size(sync_matrix),
      avg_degree: calculate_average_degree(agents, sync_matrix),
      clustering_coefficient: calculate_clustering_coefficient(agents, sync_matrix),
      path_length: estimate_avg_path_length(agents, sync_matrix)
    }
  end

  defp calculate_average_degree(agents, sync_matrix) do
    if map_size(agents) == 0 do
      0.0
    else
      total_edges = map_size(sync_matrix) * 2  # Each edge counted twice
      total_edges / map_size(agents)
    end
  end

  defp calculate_clustering_coefficient(agents, sync_matrix) do
    # Simplified clustering coefficient
    if map_size(agents) < 3 do
      0.0
    else
      # For each agent, check how many of its neighbors are connected
      coefficients = Map.keys(agents)
      |> Enum.map(fn agent_id ->
        neighbors = get_neighbors(agent_id, sync_matrix)
        
        if length(neighbors) < 2 do
          0.0
        else
          # Count edges between neighbors
          neighbor_edges = for n1 <- neighbors, n2 <- neighbors, n1 < n2 do
            if Map.has_key?(sync_matrix, {n1, n2}) or Map.has_key?(sync_matrix, {n2, n1}) do
              1
            else
              0
            end
          end
          |> Enum.sum()
          
          possible_edges = length(neighbors) * (length(neighbors) - 1) / 2
          
          if possible_edges > 0 do
            neighbor_edges / possible_edges
          else
            0.0
          end
        end
      end)
      
      if length(coefficients) > 0 do
        Enum.sum(coefficients) / length(coefficients)
      else
        0.0
      end
    end
  end

  defp get_neighbors(agent_id, sync_matrix) do
    sync_matrix
    |> Enum.filter(fn {{a1, a2}, _} ->
      a1 == agent_id or a2 == agent_id
    end)
    |> Enum.map(fn {{a1, a2}, _} ->
      if a1 == agent_id, do: a2, else: a1
    end)
    |> Enum.uniq()
  end

  defp estimate_avg_path_length(_agents, _sync_matrix) do
    # Simplified: estimate based on network size
    2.5  # Placeholder for small-world network
  end

  defp determine_optimal_organization(patterns, current, state) do
    # Score each organization pattern
    pattern_scores = Enum.map(@organization_patterns, fn pattern ->
      score = score_organization_pattern(pattern, patterns, current, state)
      {pattern, score}
    end)
    
    # Select best pattern
    {best_pattern, best_score} = Enum.max_by(pattern_scores, fn {_, score} -> score end)
    
    %{
      pattern: best_pattern,
      score: best_score,
      target_metrics: calculate_target_metrics(best_pattern, state),
      adaptation_strategy: select_adaptation_strategy(best_pattern, current.pattern)
    }
  end

  defp score_organization_pattern(pattern, emergence_patterns, current, state) do
    # Score based on multiple factors
    
    # Efficiency score
    efficiency = calculate_pattern_efficiency(pattern, state)
    
    # Adaptability score
    adaptability = calculate_pattern_adaptability(pattern, emergence_patterns)
    
    # Stability score
    stability = calculate_pattern_stability(pattern, current)
    
    # Scalability score
    scalability = calculate_pattern_scalability(pattern, state)
    
    # Weighted combination
    efficiency * 0.3 + adaptability * 0.3 + stability * 0.2 + scalability * 0.2
  end

  defp calculate_pattern_efficiency(pattern, state) do
    agent_count = map_size(Map.get(state, :agents, %{}))
    
    case pattern do
      :hierarchical -> if agent_count > 20, do: 0.8, else: 0.5
      :flat -> if agent_count < 10, do: 0.9, else: 0.3
      :mesh -> 0.7
      :hub_and_spoke -> if agent_count > 10 and agent_count < 50, do: 0.85, else: 0.5
      :modular -> if agent_count > 30, do: 0.9, else: 0.6
      :fractal -> 0.75
      :small_world -> 0.8
      :scale_free -> if agent_count > 50, do: 0.9, else: 0.4
      _ -> 0.5
    end
  end

  defp calculate_pattern_adaptability(pattern, emergence_patterns) do
    # Check how well pattern supports emergent behaviors
    behavior_support = Enum.count(emergence_patterns, fn ep ->
      supports_emergence?(pattern, ep.type)
    end) / max(1, length(emergence_patterns))
    
    base_adaptability = case pattern do
      :mesh -> 0.9
      :modular -> 0.85
      :small_world -> 0.8
      :flat -> 0.75
      :fractal -> 0.7
      :scale_free -> 0.65
      :hub_and_spoke -> 0.5
      :hierarchical -> 0.4
      _ -> 0.5
    end
    
    (base_adaptability + behavior_support) / 2
  end

  defp supports_emergence?(pattern, emergence_type) do
    case {pattern, emergence_type} do
      {:mesh, _} -> true  # Mesh supports all emergence types
      {:hierarchical, :coordination} -> true
      {:modular, :specialization} -> true
      {:small_world, :information_flow} -> true
      {:scale_free, :robustness} -> true
      _ -> false
    end
  end

  defp calculate_pattern_stability(pattern, current) do
    # Stability based on transition cost
    if pattern == current.pattern do
      1.0  # No change needed
    else
      # Calculate transition difficulty
      transition_cost = calculate_transition_cost(current.pattern, pattern)
      1.0 - transition_cost
    end
  end

  defp calculate_transition_cost(from_pattern, to_pattern) do
    # Cost matrix for transitions
    case {from_pattern, to_pattern} do
      {same, same} -> 0.0
      {:flat, :hierarchical} -> 0.7
      {:hierarchical, :flat} -> 0.8
      {:mesh, _} -> 0.3
      {_, :mesh} -> 0.3
      {:modular, _} -> 0.4
      {_, :modular} -> 0.4
      _ -> 0.5
    end
  end

  defp calculate_pattern_scalability(pattern, state) do
    growth_potential = Map.get(state, :growth_potential, 0.5)
    
    case pattern do
      :scale_free -> 0.95
      :modular -> 0.9
      :fractal -> 0.85
      :hierarchical -> 0.8
      :small_world -> 0.75
      :hub_and_spoke -> 0.6
      :mesh -> 0.4
      :flat -> 0.2
      _ -> 0.5
    end * (0.5 + growth_potential * 0.5)
  end

  defp calculate_target_metrics(pattern, _state) do
    # Define target metrics for each pattern
    case pattern do
      :hierarchical ->
        %{
          hierarchy_level: 0.8,
          connectivity: 0.4,
          modularity: 0.3,
          centralization: 0.6
        }
      :flat ->
        %{
          hierarchy_level: 0.1,
          connectivity: 0.7,
          modularity: 0.2,
          centralization: 0.1
        }
      :mesh ->
        %{
          hierarchy_level: 0.2,
          connectivity: 0.9,
          modularity: 0.1,
          centralization: 0.2
        }
      :hub_and_spoke ->
        %{
          hierarchy_level: 0.4,
          connectivity: 0.5,
          modularity: 0.4,
          centralization: 0.8
        }
      :modular ->
        %{
          hierarchy_level: 0.3,
          connectivity: 0.3,
          modularity: 0.9,
          centralization: 0.3
        }
      :fractal ->
        %{
          hierarchy_level: 0.6,
          connectivity: 0.6,
          modularity: 0.7,
          centralization: 0.4
        }
      :small_world ->
        %{
          hierarchy_level: 0.3,
          connectivity: 0.5,
          modularity: 0.5,
          centralization: 0.3
        }
      :scale_free ->
        %{
          hierarchy_level: 0.5,
          connectivity: 0.4,
          modularity: 0.4,
          centralization: 0.7
        }
      _ ->
        %{
          hierarchy_level: 0.5,
          connectivity: 0.5,
          modularity: 0.5,
          centralization: 0.5
        }
    end
  end

  defp select_adaptation_strategy(target_pattern, current_pattern) do
    if target_pattern == current_pattern do
      :maintain
    else
      case {current_pattern, target_pattern} do
        {_, :hierarchical} -> :gradual_stratification
        {_, :flat} -> :gradual_flattening
        {_, :mesh} -> :increase_connectivity
        {_, :hub_and_spoke} -> :create_hubs
        {_, :modular} -> :form_modules
        {_, :fractal} -> :recursive_organization
        {_, :small_world} -> :create_shortcuts
        {_, :scale_free} -> :preferential_attachment
        _ -> :gradual_transition
      end
    end
  end

  defp create_reorganization_plan(current, optimal, state) do
    %{
      phases: plan_reorganization_phases(current, optimal),
      timeline: estimate_reorganization_timeline(current, optimal),
      resource_requirements: calculate_resource_requirements(current, optimal),
      risk_assessment: assess_reorganization_risks(current, optimal, state),
      rollback_plan: create_rollback_plan(state)
    }
  end

  defp plan_reorganization_phases(current, optimal) do
    case optimal.adaptation_strategy do
      :maintain ->
        [{:maintain, "Maintain current structure"}]
        
      :gradual_stratification ->
        [
          {:identify_leaders, "Identify high-performing agents"},
          {:create_layers, "Create hierarchical layers"},
          {:establish_chains, "Establish command chains"},
          {:optimize_flow, "Optimize information flow"}
        ]
        
      :gradual_flattening ->
        [
          {:reduce_layers, "Reduce hierarchical layers"},
          {:distribute_authority, "Distribute decision authority"},
          {:enhance_peer_comm, "Enhance peer communication"},
          {:equalize_roles, "Equalize agent roles"}
        ]
        
      :increase_connectivity ->
        [
          {:identify_gaps, "Identify connectivity gaps"},
          {:create_links, "Create new agent links"},
          {:strengthen_weak, "Strengthen weak connections"},
          {:optimize_topology, "Optimize network topology"}
        ]
        
      :create_hubs ->
        [
          {:identify_hubs, "Identify potential hub agents"},
          {:strengthen_hubs, "Strengthen hub connections"},
          {:connect_spokes, "Connect spoke agents to hubs"},
          {:balance_load, "Balance hub load"}
        ]
        
      :form_modules ->
        [
          {:identify_clusters, "Identify natural clusters"},
          {:strengthen_internal, "Strengthen internal connections"},
          {:reduce_external, "Reduce external connections"},
          {:establish_interfaces, "Establish module interfaces"}
        ]
        
      _ ->
        [
          {:prepare, "Prepare for reorganization"},
          {:execute, "Execute reorganization"},
          {:stabilize, "Stabilize new structure"},
          {:optimize, "Optimize performance"}
        ]
    end
  end

  defp estimate_reorganization_timeline(_current, optimal) do
    base_time = case optimal.pattern do
      :hierarchical -> 10
      :flat -> 5
      :mesh -> 8
      :hub_and_spoke -> 7
      :modular -> 12
      :fractal -> 15
      :small_world -> 9
      :scale_free -> 11
      _ -> 10
    end
    
    %{
      total_duration: base_time,
      phase_durations: List.duplicate(2, div(base_time, 2))
    }
  end

  defp calculate_resource_requirements(_current, optimal) do
    %{
      computation: case optimal.pattern do
        :mesh -> :high
        :fractal -> :high
        :modular -> :medium
        _ -> :low
      end,
      communication: case optimal.pattern do
        :mesh -> :high
        :flat -> :high
        :hierarchical -> :low
        _ -> :medium
      end,
      coordination: case optimal.pattern do
        :modular -> :high
        :fractal -> :high
        _ -> :medium
      end
    }
  end

  defp assess_reorganization_risks(_current, _optimal, state) do
    %{
      disruption_risk: if map_size(state.agents) > 20, do: :high, else: :medium,
      failure_risk: :low,
      performance_impact: :temporary_decrease,
      recovery_time: :moderate
    }
  end

  defp create_rollback_plan(state) do
    %{
      snapshot: create_state_snapshot(state),
      trigger_conditions: [
        {:stability_below, 0.3},
        {:performance_drop, 0.5},
        {:agent_failures, 0.3}
      ],
      rollback_procedure: :automatic
    }
  end

  defp create_state_snapshot(state) do
    %{
      agents: Map.get(state, :agents, %{}),
      synchronization_matrix: Map.get(state, :synchronization_matrix, %{}),
      consciousness_level: Map.get(state, :consciousness_level, 0.5),
      timestamp: DateTime.utc_now()
    }
  end

  defp execute_reorganization(state, plan) do
    # Execute reorganization phases
    Enum.reduce(plan.phases, state, fn {phase, _description}, acc_state ->
      execute_phase(phase, acc_state, plan)
    end)
  end

  defp execute_phase(phase, state, _plan) do
    case phase do
      :maintain -> state
      
      :identify_leaders ->
        identify_and_promote_leaders(state)
      
      :create_layers ->
        create_hierarchical_layers(state)
      
      :establish_chains ->
        establish_command_chains(state)
      
      :reduce_layers ->
        flatten_hierarchy(state)
      
      :distribute_authority ->
        distribute_decision_authority(state)
      
      :identify_gaps ->
        state  # Analysis phase, no change
      
      :create_links ->
        create_new_connections(state)
      
      :strengthen_weak ->
        strengthen_weak_connections(state)
      
      :identify_hubs ->
        identify_hub_candidates(state)
      
      :strengthen_hubs ->
        strengthen_hub_connections(state)
      
      :identify_clusters ->
        identify_natural_clusters(state)
      
      :strengthen_internal ->
        strengthen_cluster_internals(state)
      
      :reduce_external ->
        reduce_inter_cluster_connections(state)
      
      _ ->
        state
    end
  end

  defp identify_and_promote_leaders(state) do
    # Identify top performing agents
    agents = Map.get(state, :agents, %{})
    
    sorted_agents = agents
    |> Enum.sort_by(fn {_, agent} -> agent.contribution_score end, :desc)
    
    # Promote top 20% as leaders
    leader_count = max(1, div(map_size(agents), 5))
    leaders = Enum.take(sorted_agents, leader_count)
    
    # Update agent roles
    updated_agents = Map.new(agents, fn {id, agent} ->
      is_leader = Enum.any?(leaders, fn {leader_id, _} -> leader_id == id end)
      
      updated = if is_leader do
        %{agent | 
          contribution_score: min(1.0, agent.contribution_score * 1.2),
          capabilities: [:leadership | agent.capabilities] |> Enum.uniq()
        }
      else
        agent
      end
      
      {id, updated}
    end)
    
    %{state | agents: updated_agents}
  end

  defp create_hierarchical_layers(state) do
    # Create layers based on contribution scores
    agents = Map.get(state, :agents, %{})
    
    # Sort and divide into layers
    sorted = agents
    |> Map.to_list()
    |> Enum.sort_by(fn {_, agent} -> agent.contribution_score end, :desc)
    
    layer_size = max(1, div(length(sorted), 3))
    
    layers = %{
      top: Enum.take(sorted, layer_size),
      middle: Enum.slice(sorted, layer_size, layer_size),
      bottom: Enum.drop(sorted, layer_size * 2)
    }
    
    # Store layer information (simplified: just return state)
    Map.put(state, :hierarchy_layers, layers)
  end

  defp establish_command_chains(state) do
    # Establish reporting relationships
    layers = Map.get(state, :hierarchy_layers, %{})
    
    if map_size(layers) > 0 do
      # Create command chains (simplified)
      state
    else
      state
    end
  end

  defp flatten_hierarchy(state) do
    # Remove hierarchical structures
    agents = Map.get(state, :agents, %{})
    
    # Equalize contribution scores
    avg_score = if map_size(agents) > 0 do
      total = Enum.reduce(agents, 0.0, fn {_, agent}, acc ->
        acc + agent.contribution_score
      end)
      total / map_size(agents)
    else
      0.5
    end
    
    updated_agents = Map.new(agents, fn {id, agent} ->
      # Move scores toward average
      new_score = agent.contribution_score * 0.7 + avg_score * 0.3
      {id, %{agent | contribution_score: new_score}}
    end)
    
    %{state | 
      agents: updated_agents,
      hierarchy_layers: %{}
    }
  end

  defp distribute_decision_authority(state) do
    # Give all agents equal decision weight
    agents = Map.get(state, :agents, %{})
    
    updated_agents = Map.new(agents, fn {id, agent} ->
      {id, %{agent | 
        capabilities: [:decision_making | agent.capabilities] |> Enum.uniq()
      }}
    end)
    
    %{state | agents: updated_agents}
  end

  defp create_new_connections(state) do
    # Add new connections to increase connectivity
    agents = Map.get(state, :agents, %{})
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    agent_ids = Map.keys(agents)
    
    # Add random connections
    new_connections = for a1 <- agent_ids,
                          a2 <- agent_ids,
                          a1 < a2,
                          not Map.has_key?(sync_matrix, {a1, a2}),
                          :rand.uniform() < 0.3,
                          into: %{} do
      {{a1, a2}, 0.5}
    end
    
    %{state | synchronization_matrix: Map.merge(sync_matrix, new_connections)}
  end

  defp strengthen_weak_connections(state) do
    # Strengthen existing weak connections
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    strengthened = Map.new(sync_matrix, fn {key, value} ->
      if value < 0.5 do
        {key, min(1.0, value * 1.5)}
      else
        {key, value}
      end
    end)
    
    %{state | synchronization_matrix: strengthened}
  end

  defp identify_hub_candidates(state) do
    # Identify agents that could serve as hubs
    agents = Map.get(state, :agents, %{})
    
    # Select agents with high contribution scores
    hubs = agents
    |> Enum.filter(fn {_, agent} -> agent.contribution_score > 0.7 end)
    |> Enum.map(fn {id, _} -> id end)
    |> Enum.take(max(1, div(map_size(agents), 10)))
    
    Map.put(state, :hub_agents, hubs)
  end

  defp strengthen_hub_connections(state) do
    # Strengthen connections to hub agents
    hubs = Map.get(state, :hub_agents, [])
    agents = Map.get(state, :agents, %{})
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    if length(hubs) > 0 do
      # Connect all agents to hubs
      new_connections = for hub <- hubs,
                            {agent_id, _} <- agents,
                            agent_id != hub,
                            into: %{} do
        key = if hub < agent_id, do: {hub, agent_id}, else: {agent_id, hub}
        {key, 0.8}
      end
      
      %{state | synchronization_matrix: Map.merge(sync_matrix, new_connections)}
    else
      state
    end
  end

  defp identify_natural_clusters(state) do
    # Identify natural groupings of agents
    agents = Map.get(state, :agents, %{})
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    clusters = simple_clustering(agents, sync_matrix)
    Map.put(state, :clusters, clusters)
  end

  defp strengthen_cluster_internals(state) do
    # Strengthen connections within clusters
    clusters = Map.get(state, :clusters, [])
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    strengthened = Enum.reduce(clusters, sync_matrix, fn cluster, acc ->
      # Strengthen all intra-cluster connections
      updates = for a1 <- cluster,
                   a2 <- cluster,
                   a1 < a2,
                   into: %{} do
        {{a1, a2}, 0.9}
      end
      
      Map.merge(acc, updates)
    end)
    
    %{state | synchronization_matrix: strengthened}
  end

  defp reduce_inter_cluster_connections(state) do
    # Reduce connections between clusters
    clusters = Map.get(state, :clusters, [])
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    # Create cluster membership map
    membership = Enum.reduce(clusters, %{}, fn cluster, acc ->
      Enum.reduce(cluster, acc, fn agent_id, acc2 ->
        Map.put(acc2, agent_id, cluster)
      end)
    end)
    
    # Weaken inter-cluster connections
    weakened = Map.new(sync_matrix, fn {{a1, a2}, value} ->
      if Map.get(membership, a1) != Map.get(membership, a2) do
        {{a1, a2}, value * 0.5}
      else
        {{a1, a2}, value}
      end
    end)
    
    %{state | synchronization_matrix: weakened}
  end

  defp verify_stability(state) do
    # Verify the reorganized state is stable
    
    # Check agent synchronization
    agents = Map.get(state, :agents, %{})
    avg_sync = if map_size(agents) > 0 do
      total = Enum.reduce(agents, 0.0, fn {_, agent}, acc ->
        acc + agent.synchronization
      end)
      total / map_size(agents)
    else
      0.0
    end
    
    # Check consciousness level
    consciousness = Map.get(state, :consciousness_level, 0.0)
    
    # Check for critical failures
    critical_failures = check_critical_failures(state)
    
    # Stable if above thresholds and no critical failures
    avg_sync > @reorganization_threshold and 
    consciousness > @reorganization_threshold and
    length(critical_failures) == 0
  end

  defp check_critical_failures(state) do
    failures = []
    
    # Check for disconnected agents
    if has_disconnected_agents?(state) do
      failures = [:disconnected_agents | failures]
    end
    
    # Check for consciousness collapse
    if Map.get(state, :consciousness_level, 0) < 0.1 do
      failures = [:consciousness_collapse | failures]
    end
    
    failures
  end

  defp has_disconnected_agents?(state) do
    agents = Map.get(state, :agents, %{})
    sync_matrix = Map.get(state, :synchronization_matrix, %{})
    
    # Check if any agent has no connections
    Enum.any?(agents, fn {id, _} ->
      connections = Enum.count(sync_matrix, fn {{a1, a2}, _} ->
        a1 == id or a2 == id
      end)
      connections == 0
    end)
  end

  defp detect_environmental_changes(state) do
    # Detect changes in environment or context
    previous = Map.get(state, :previous_environment, %{})
    current = Map.get(state, :environment, %{})
    
    changes = MapSet.difference(
      MapSet.new(Map.keys(current)),
      MapSet.new(Map.keys(previous))
    )
    
    %{
      new_factors: MapSet.to_list(changes),
      change_magnitude: MapSet.size(changes) / max(1, map_size(current)),
      change_type: classify_change_type(changes)
    }
  end

  defp classify_change_type(changes) do
    cond do
      MapSet.size(changes) == 0 -> :stable
      MapSet.size(changes) < 3 -> :minor
      MapSet.size(changes) < 10 -> :moderate
      true -> :major
    end
  end

  defp calculate_adaptations(changes, state) do
    adaptations = []
    
    # Adapt to change magnitude
    if changes.change_magnitude > 0.3 do
      adaptations = [:increase_flexibility | adaptations]
    end
    
    # Adapt to change type
    case changes.change_type do
      :major ->
        adaptations = [:restructure, :increase_exploration | adaptations]
      :moderate ->
        adaptations = [:adjust_parameters | adaptations]
      :minor ->
        adaptations = [:fine_tune | adaptations]
      _ ->
        adaptations
    end
    
    # Add specific adaptations for new factors
    factor_adaptations = Enum.map(changes.new_factors, fn factor ->
      adapt_to_factor(factor, state)
    end)
    
    adaptations ++ factor_adaptations
  end

  defp adapt_to_factor(_factor, _state) do
    # Placeholder for factor-specific adaptation
    :general_adaptation
  end

  defp apply_adaptations(state, adaptations) do
    Enum.reduce(adaptations, state, fn adaptation, acc_state ->
      apply_single_adaptation(acc_state, adaptation)
    end)
  end

  defp apply_single_adaptation(state, adaptation) do
    case adaptation do
      :increase_flexibility ->
        increase_system_flexibility(state)
      
      :restructure ->
        # Trigger reorganization
        reorganize(state, [])
      
      :increase_exploration ->
        increase_exploration_rate(state)
      
      :adjust_parameters ->
        adjust_system_parameters(state)
      
      :fine_tune ->
        fine_tune_performance(state)
      
      _ ->
        state
    end
  end

  defp increase_system_flexibility(state) do
    # Increase adaptability of agents
    agents = Map.get(state, :agents, %{})
    
    flexible_agents = Map.new(agents, fn {id, agent} ->
      # Add adaptability capabilities
      new_caps = [:adaptability, :flexibility | agent.capabilities] |> Enum.uniq()
      {id, %{agent | capabilities: new_caps}}
    end)
    
    %{state | agents: flexible_agents}
  end

  defp increase_exploration_rate(state) do
    # Increase exploration behavior
    Map.put(state, :exploration_rate, 0.7)
  end

  defp adjust_system_parameters(state) do
    # Adjust various system parameters
    state
    |> Map.put(:learning_rate, @adaptation_rate * 1.2)
    |> Map.put(:synchronization_strength, 0.6)
  end

  defp fine_tune_performance(state) do
    # Fine tune for optimal performance
    agents = Map.get(state, :agents, %{})
    
    # Slightly adjust contribution scores
    tuned_agents = Map.new(agents, fn {id, agent} ->
      adjustment = (:rand.uniform() - 0.5) * 0.1
      new_score = max(0.0, min(1.0, agent.contribution_score + adjustment))
      {id, %{agent | contribution_score: new_score}}
    end)
    
    %{state | agents: tuned_agents}
  end

  defp calculate_criticality(state) do
    # Calculate system criticality (edge of chaos)
    
    # Order parameter: synchronization
    agents = Map.get(state, :agents, %{})
    order = if map_size(agents) > 0 do
      total_sync = Enum.reduce(agents, 0.0, fn {_, agent}, acc ->
        acc + agent.synchronization
      end)
      total_sync / map_size(agents)
    else
      0.0
    end
    
    # Disorder parameter: variance in behaviors
    disorder = calculate_behavioral_variance(agents)
    
    # Criticality is balance between order and disorder
    if order + disorder > 0 do
      disorder / (order + disorder)
    else
      0.5
    end
  end

  defp calculate_behavioral_variance(agents) do
    if map_size(agents) == 0 do
      0.0
    else
      # Variance in contribution scores as proxy for behavioral diversity
      scores = Map.values(agents) |> Enum.map(& &1.contribution_score)
      
      mean = Enum.sum(scores) / length(scores)
      variance = Enum.reduce(scores, 0.0, fn score, acc ->
        acc + :math.pow(score - mean, 2)
      end) / length(scores)
      
      :math.sqrt(variance)
    end
  end

  defp increase_disorder(state) do
    # Increase disorder to reach criticality
    agents = Map.get(state, :agents, %{})
    
    disordered_agents = Map.new(agents, fn {id, agent} ->
      # Add random perturbation
      perturbation = (:rand.uniform() - 0.5) * 0.2
      new_sync = max(0.0, min(1.0, agent.synchronization + perturbation))
      {id, %{agent | synchronization: new_sync}}
    end)
    
    %{state | agents: disordered_agents}
  end

  defp increase_order(state) do
    # Increase order to reach criticality
    agents = Map.get(state, :agents, %{})
    
    # Move synchronization toward mean
    mean_sync = if map_size(agents) > 0 do
      total = Enum.reduce(agents, 0.0, fn {_, agent}, acc ->
        acc + agent.synchronization
      end)
      total / map_size(agents)
    else
      0.5
    end
    
    ordered_agents = Map.new(agents, fn {id, agent} ->
      new_sync = agent.synchronization * 0.8 + mean_sync * 0.2
      {id, %{agent | synchronization: new_sync}}
    end)
    
    %{state | agents: ordered_agents}
  end

  defp calculate_affinity_matrix(agents) do
    # Calculate pairwise affinity between agents
    agent_list = Map.to_list(agents)
    
    for {id1, agent1} <- agent_list,
        {id2, agent2} <- agent_list,
        id1 != id2,
        into: %{} do
      affinity = calculate_agent_affinity(agent1, agent2)
      {{id1, id2}, affinity}
    end
  end

  defp calculate_agent_affinity(agent1, agent2) do
    # Calculate affinity based on multiple factors
    
    # Capability similarity
    cap_similarity = capability_similarity(agent1.capabilities, agent2.capabilities)
    
    # Synchronization similarity
    sync_diff = abs(agent1.synchronization - agent2.synchronization)
    sync_similarity = 1.0 - sync_diff
    
    # Contribution compatibility
    contrib_compat = 1.0 - abs(agent1.contribution_score - agent2.contribution_score) / 2
    
    # Weighted affinity
    cap_similarity * 0.4 + sync_similarity * 0.3 + contrib_compat * 0.3
  end

  defp capability_similarity(caps1, caps2) do
    if length(caps1) == 0 or length(caps2) == 0 do
      0.0
    else
      intersection = MapSet.intersection(MapSet.new(caps1), MapSet.new(caps2))
      union = MapSet.union(MapSet.new(caps1), MapSet.new(caps2))
      
      if MapSet.size(union) > 0 do
        MapSet.size(intersection) / MapSet.size(union)
      else
        0.0
      end
    end
  end

  defp spectral_clustering(affinity_matrix, agents) do
    # Simplified spectral clustering
    threshold = 0.6
    
    # Group agents with high affinity
    agent_ids = Map.keys(agents)
    
    Enum.reduce(agent_ids, [], fn agent_id, clusters ->
      # Find cluster for this agent
      cluster_idx = Enum.find_index(clusters, fn cluster ->
        Enum.any?(cluster, fn other_id ->
          affinity = Map.get(affinity_matrix, {agent_id, other_id}, 0.0)
          affinity > threshold
        end)
      end)
      
      if cluster_idx do
        List.update_at(clusters, cluster_idx, &[agent_id | &1])
      else
        [[agent_id] | clusters]
      end
    end)
  end

  defp assign_cluster_roles(clusters) do
    # Assign roles to clusters
    Enum.map(clusters, fn cluster ->
      %{
        members: cluster,
        role: determine_cluster_role(cluster),
        leader: select_cluster_leader(cluster),
        specialization: determine_cluster_specialization(cluster)
      }
    end)
  end

  defp determine_cluster_role(cluster) do
    # Determine role based on cluster size and position
    cond do
      length(cluster) > 10 -> :core
      length(cluster) > 5 -> :processing
      length(cluster) > 2 -> :support
      true -> :peripheral
    end
  end

  defp select_cluster_leader(cluster) do
    # Select leader (simplified: just pick first)
    List.first(cluster)
  end

  defp determine_cluster_specialization(_cluster) do
    # Determine what the cluster specializes in
    Enum.random([:computation, :communication, :storage, :coordination])
  end

  defp establish_cluster_links(clusters) do
    # Establish communication between clusters
    cluster_links = for c1 <- clusters,
                        c2 <- clusters,
                        c1 != c2,
                        should_link_clusters?(c1, c2) do
      {c1.leader, c2.leader}
    end
    
    %{
      clusters: clusters,
      links: cluster_links
    }
  end

  defp should_link_clusters?(c1, c2) do
    # Determine if clusters should be linked
    c1.role == :core or c2.role == :core or
    (c1.specialization != c2.specialization and :rand.uniform() > 0.5)
  end

  defp collect_agent_traces(agents) do
    # Collect traces left by agents
    Map.values(agents)
    |> Enum.map(fn agent ->
      %{
        agent_id: agent.id,
        position: %{x: :rand.uniform(), y: :rand.uniform()},  # Simplified position
        strength: agent.contribution_score,
        type: determine_trace_type(agent),
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp determine_trace_type(agent) do
    # Determine type of trace based on agent capabilities
    cond do
      :exploration in agent.capabilities -> :exploration_pheromone
      :exploitation in agent.capabilities -> :resource_pheromone
      :coordination in agent.capabilities -> :coordination_signal
      true -> :general_trace
    end
  end

  defp update_environment_traces(environment, traces) do
    # Update environment with new traces
    existing_traces = Map.get(environment, :traces, [])
    
    # Decay old traces
    decayed = Enum.map(existing_traces, fn trace ->
      %{trace | strength: trace.strength * 0.9}
    end)
    |> Enum.filter(& &1.strength > 0.01)
    
    # Add new traces
    updated_traces = traces ++ decayed
    
    # Aggregate overlapping traces
    aggregated = aggregate_traces(updated_traces)
    
    Map.put(environment, :traces, aggregated)
  end

  defp aggregate_traces(traces) do
    # Aggregate traces at similar positions
    traces
    |> Enum.group_by(fn trace ->
      # Group by quantized position
      {round(trace.position.x * 10), round(trace.position.y * 10), trace.type}
    end)
    |> Enum.map(fn {_key, group} ->
      # Aggregate group into single trace
      %{
        position: List.first(group).position,
        strength: Enum.reduce(group, 0.0, & &1.strength + &2) / length(group),
        type: List.first(group).type,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp coordinate_through_traces(agents, environment) do
    # Agents respond to environmental traces
    traces = Map.get(environment, :traces, [])
    
    Map.new(agents, fn {id, agent} ->
      # Find relevant traces
      relevant_traces = Enum.filter(traces, fn trace ->
        trace_relevant_to_agent?(trace, agent)
      end)
      
      # Update agent based on traces
      updated_agent = if length(relevant_traces) > 0 do
        respond_to_traces(agent, relevant_traces)
      else
        agent
      end
      
      {id, updated_agent}
    end)
  end

  defp trace_relevant_to_agent?(trace, agent) do
    # Check if trace is relevant to agent
    case trace.type do
      :exploration_pheromone -> :exploration in agent.capabilities
      :resource_pheromone -> :exploitation in agent.capabilities
      :coordination_signal -> :coordination in agent.capabilities
      _ -> true
    end
  end

  defp respond_to_traces(agent, traces) do
    # Agent responds to traces
    strongest_trace = Enum.max_by(traces, & &1.strength)
    
    # Adjust agent behavior based on strongest trace
    case strongest_trace.type do
      :exploration_pheromone ->
        %{agent | 
          capabilities: [:exploration | agent.capabilities] |> Enum.uniq()
        }
      
      :resource_pheromone ->
        %{agent | 
          capabilities: [:exploitation | agent.capabilities] |> Enum.uniq(),
          contribution_score: min(1.0, agent.contribution_score * 1.1)
        }
      
      :coordination_signal ->
        %{agent | 
          synchronization: min(1.0, agent.synchronization + 0.1)
        }
      
      _ ->
        agent
    end
  end
end