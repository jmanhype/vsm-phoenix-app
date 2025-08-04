defmodule VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner do
  @moduledoc """
  Recursive VSM Spawner
  
  Manages the creation of child VSMs with proper supervision,
  resource allocation, and recursive depth management.
  """
  
  use DynamicSupervisor
  require Logger
  
  alias VsmPhoenix.MetaVsm.Core.MetaVsm
  alias VsmPhoenix.MetaVsm.Genetics.DnaConfig
  
  @max_spawn_rate 10  # Max spawns per minute
  @resource_pool_size 100  # Total resource units available
  
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_children: 1000  # Maximum concurrent VSMs
    )
  end
  
  @doc """
  Spawn a new child VSM with inherited characteristics
  """
  def spawn_child_vsm(config) do
    # Check resource availability
    if has_sufficient_resources?(config) do
      # Allocate resources
      allocated_resources = allocate_resources(config)
      
      # Add resource allocation to config
      spawn_config = Map.put(config, :resources, allocated_resources)
      
      # Start the child VSM
      case DynamicSupervisor.start_child(__MODULE__, {MetaVsm, spawn_config}) do
        {:ok, pid} ->
          child_id = config[:id] || generate_child_id()
          
          Logger.info("✨ Spawned child VSM #{child_id} with pid #{inspect(pid)}")
          
          # Register in global registry
          register_vsm(child_id, pid)
          
          # Notify monitoring systems
          notify_spawn_event(child_id, config)
          
          {:ok, child_id}
          
        {:error, reason} = error ->
          Logger.error("Failed to spawn child VSM: #{inspect(reason)}")
          # Return resources to pool
          release_resources(allocated_resources)
          error
      end
    else
      {:error, :insufficient_resources}
    end
  end
  
  @doc """
  Spawn multiple VSMs in parallel (for population initialization)
  """
  def spawn_population(count, base_config \\ %{}) do
    tasks = for i <- 1..count do
      Task.async(fn ->
        config = Map.merge(base_config, %{
          generation: 0,
          depth: 0,
          population_member: i
        })
        spawn_child_vsm(config)
      end)
    end
    
    results = Task.await_many(tasks, 10_000)
    
    successful = Enum.filter(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    Logger.info("🌍 Spawned population: #{length(successful)}/#{count} successful")
    
    results
  end
  
  @doc """
  Spawn a specialized VSM with specific traits
  """
  def spawn_specialized(specialization, parent_config \\ %{}) do
    # Generate specialized DNA
    specialized_dna = DnaConfig.generate_specialized_dna(specialization)
    
    config = Map.merge(parent_config, %{
      dna: specialized_dna,
      specialization: specialization
    })
    
    spawn_child_vsm(config)
  end
  
  @doc """
  Spawn a VSM network with predefined topology
  """
  def spawn_network(topology, size) do
    case topology do
      :hierarchical ->
        spawn_hierarchical_network(size)
        
      :mesh ->
        spawn_mesh_network(size)
        
      :ring ->
        spawn_ring_network(size)
        
      :star ->
        spawn_star_network(size)
        
      :fractal ->
        spawn_fractal_network(size)
        
      _ ->
        {:error, :unknown_topology}
    end
  end
  
  @doc """
  Clone an existing VSM with optional mutations
  """
  def clone_vsm(source_vsm_id, options \\ %{}) do
    case get_vsm_dna(source_vsm_id) do
      {:ok, source_dna} ->
        # Apply optional mutations
        cloned_dna = if options[:mutate] do
          VsmPhoenix.MetaVsm.Genetics.Evolution.inherit_with_mutations(
            source_dna,
            options[:mutation_rate] || 0.05
          )
        else
          source_dna
        end
        
        config = %{
          dna: cloned_dna,
          parent_id: source_vsm_id,
          clone_source: source_vsm_id,
          generation: (options[:generation] || 0) + 1
        }
        
        spawn_child_vsm(config)
        
      error ->
        error
    end
  end
  
  @doc """
  Perform binary fission (split one VSM into two)
  """
  def binary_fission(vsm_id) do
    case get_vsm_state(vsm_id) do
      {:ok, state} ->
        # Create two offspring with slightly modified DNA
        offspring1_dna = VsmPhoenix.MetaVsm.Genetics.Evolution.genetic_drift(state.dna, 1)
        offspring2_dna = VsmPhoenix.MetaVsm.Genetics.Evolution.genetic_drift(state.dna, 1)
        
        # Spawn both offspring
        task1 = Task.async(fn ->
          spawn_child_vsm(%{
            dna: offspring1_dna,
            parent_id: vsm_id,
            fission_sibling: 1
          })
        end)
        
        task2 = Task.async(fn ->
          spawn_child_vsm(%{
            dna: offspring2_dna,
            parent_id: vsm_id,
            fission_sibling: 2
          })
        end)
        
        results = Task.await_many([task1, task2])
        
        # Optionally kill the parent
        if state.fission_kills_parent do
          terminate_vsm(vsm_id)
        end
        
        {:ok, results}
        
      error ->
        error
    end
  end
  
  @doc """
  Spawn a VSM swarm with collective behavior
  """
  def spawn_swarm(swarm_config) do
    size = swarm_config[:size] || 10
    behavior = swarm_config[:behavior] || :cooperative
    
    # Create swarm DNA template
    swarm_dna = DnaConfig.generate_specialized_dna(:replicator)
    |> DnaConfig.apply_epigenetics(behavior)
    
    # Spawn swarm members
    members = for i <- 1..size do
      config = %{
        dna: swarm_dna,
        swarm_id: swarm_config[:id] || generate_swarm_id(),
        swarm_member: i,
        swarm_behavior: behavior
      }
      
      case spawn_child_vsm(config) do
        {:ok, member_id} -> member_id
        _ -> nil
      end
    end
    |> Enum.filter(&(&1 != nil))
    
    Logger.info("🐝 Spawned swarm with #{length(members)} members")
    
    {:ok, %{
      swarm_id: swarm_config[:id],
      members: members,
      size: length(members),
      behavior: behavior
    }}
  end
  
  @doc """
  Emergency spawn (rapid response to crisis)
  """
  def emergency_spawn(crisis_type, count \\ 3) do
    Logger.warning("🚨 Emergency spawn initiated for #{crisis_type}")
    
    # Create crisis-adapted DNA
    crisis_dna = case crisis_type do
      :resource_shortage ->
        DnaConfig.generate_specialized_dna(:optimizer)
        
      :external_threat ->
        DnaConfig.generate_specialized_dna(:guardian)
        
      :innovation_needed ->
        DnaConfig.generate_specialized_dna(:innovator)
        
      _ ->
        DnaConfig.generate_primordial_dna()
    end
    
    # Spawn emergency VSMs in parallel
    tasks = for i <- 1..count do
      Task.async(fn ->
        spawn_child_vsm(%{
          dna: crisis_dna,
          emergency: true,
          crisis_type: crisis_type,
          priority: :high,
          emergency_unit: i
        })
      end)
    end
    
    Task.await_many(tasks, 5_000)
  end
  
  # Private functions
  
  defp has_sufficient_resources?(config) do
    required = calculate_resource_requirement(config)
    available = get_available_resources()
    available >= required
  end
  
  defp calculate_resource_requirement(config) do
    base_requirement = 10
    depth_factor = (config[:depth] || 0) * 2
    complexity_factor = calculate_dna_complexity(config[:dna]) * 5
    
    base_requirement + depth_factor + complexity_factor
  end
  
  defp calculate_dna_complexity(nil), do: 1
  defp calculate_dna_complexity(dna) do
    # Calculate based on number of active features
    active_features = [
      dna.meta_config.evolution_enabled,
      dna.system4_config.pattern_recognition,
      dna.system4_config.model_building,
      dna.meta_config.spawning_rate > 0.5
    ]
    
    Enum.count(active_features, & &1)
  end
  
  defp get_available_resources do
    # In production, this would check actual resource pool
    :rand.uniform(@resource_pool_size)
  end
  
  defp allocate_resources(config) do
    required = calculate_resource_requirement(config)
    
    %{
      compute: required * 0.4,
      memory: required * 0.3,
      network: required * 0.2,
      storage: required * 0.1
    }
  end
  
  defp release_resources(resources) do
    # Return resources to pool
    Logger.debug("Released resources: #{inspect(resources)}")
  end
  
  defp register_vsm(vsm_id, pid) do
    Registry.register(VsmPhoenix.MetaVsmRegistry, vsm_id, pid)
  end
  
  defp notify_spawn_event(child_id, config) do
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:spawning",
      {:vsm_spawned, %{
        child_id: child_id,
        config: config,
        timestamp: DateTime.utc_now()
      }}
    )
  end
  
  defp generate_child_id do
    "vsm_child_#{System.unique_integer([:positive])}"
  end
  
  defp generate_swarm_id do
    "vsm_swarm_#{System.unique_integer([:positive])}"
  end
  
  defp spawn_hierarchical_network(size) do
    # Create root VSM
    {:ok, root_id} = spawn_child_vsm(%{depth: 0, network_role: :root})
    
    # Calculate tree structure
    levels = :math.log2(size) |> Float.ceil() |> round()
    
    # Spawn children level by level
    {all_nodes, _} = Enum.reduce_while(1..levels, {[root_id], [root_id]}, fn level, {all_nodes, current_parents} ->
      if length(all_nodes) >= size do
        {:halt, {all_nodes, current_parents}}
      else
        children = for parent <- current_parents, _ <- 1..2 do
          case spawn_child_vsm(%{
            parent_id: parent,
            depth: level,
            network_role: :node
          }) do
            {:ok, child_id} -> child_id
            _ -> nil
          end
        end
        |> Enum.filter(&(&1 != nil))
        |> Enum.take(size - length(all_nodes))
        
        new_all_nodes = all_nodes ++ children
        {:cont, {new_all_nodes, children}}
      end
    end)
    
    {:ok, %{
      topology: :hierarchical,
      root: root_id,
      nodes: all_nodes,
      size: length(all_nodes)
    }}
  end
  
  defp spawn_mesh_network(size) do
    # Spawn all nodes
    nodes = for i <- 1..size do
      case spawn_child_vsm(%{
        network_role: :mesh_node,
        mesh_index: i
      }) do
        {:ok, node_id} -> node_id
        _ -> nil
      end
    end
    |> Enum.filter(&(&1 != nil))
    
    # Connect all nodes to each other
    for node1 <- nodes, node2 <- nodes, node1 != node2 do
      establish_connection(node1, node2)
    end
    
    {:ok, %{
      topology: :mesh,
      nodes: nodes,
      size: length(nodes),
      connections: length(nodes) * (length(nodes) - 1)
    }}
  end
  
  defp spawn_ring_network(size) do
    # Spawn nodes
    nodes = for i <- 1..size do
      case spawn_child_vsm(%{
        network_role: :ring_node,
        ring_position: i
      }) do
        {:ok, node_id} -> node_id
        _ -> nil
      end
    end
    |> Enum.filter(&(&1 != nil))
    
    # Connect in a ring
    for i <- 0..(length(nodes) - 1) do
      current = Enum.at(nodes, i)
      next = Enum.at(nodes, rem(i + 1, length(nodes)))
      establish_connection(current, next)
    end
    
    {:ok, %{
      topology: :ring,
      nodes: nodes,
      size: length(nodes)
    }}
  end
  
  defp spawn_star_network(size) do
    # Create hub
    {:ok, hub_id} = spawn_child_vsm(%{
      network_role: :hub,
      specialization: :coordinator
    })
    
    # Create spokes
    spokes = for i <- 1..(size - 1) do
      case spawn_child_vsm(%{
        network_role: :spoke,
        hub_id: hub_id,
        spoke_index: i
      }) do
        {:ok, spoke_id} ->
          establish_connection(hub_id, spoke_id)
          spoke_id
        _ ->
          nil
      end
    end
    |> Enum.filter(&(&1 != nil))
    
    {:ok, %{
      topology: :star,
      hub: hub_id,
      spokes: spokes,
      size: 1 + length(spokes)
    }}
  end
  
  defp spawn_fractal_network(size) do
    # Create self-similar structure at multiple scales
    {:ok, root_id} = spawn_child_vsm(%{
      depth: 0,
      fractal_level: 0,
      network_role: :fractal_root
    })
    
    # Recursive fractal spawning
    spawn_fractal_children(root_id, size - 1, 1, 3)
    
    {:ok, %{
      topology: :fractal,
      root: root_id,
      size: size,
      dimension: 2.718  # Fractal dimension
    }}
  end
  
  defp spawn_fractal_children(_parent_id, 0, _level, _branching), do: []
  defp spawn_fractal_children(_parent_id, _remaining, level, _branching) when level > 5, do: []
  
  defp spawn_fractal_children(parent_id, remaining, level, branching) do
    children_to_spawn = min(remaining, branching)
    
    children = for i <- 1..children_to_spawn do
      case spawn_child_vsm(%{
        parent_id: parent_id,
        depth: level,
        fractal_level: level,
        fractal_branch: i
      }) do
        {:ok, child_id} -> child_id
        _ -> nil
      end
    end
    |> Enum.filter(&(&1 != nil))
    
    remaining_after = remaining - length(children)
    
    if remaining_after > 0 do
      # Recursively spawn children for each child
      grandchildren = Enum.flat_map(children, fn child_id ->
        share = div(remaining_after, length(children))
        spawn_fractal_children(child_id, share, level + 1, branching - 1)
      end)
      
      children ++ grandchildren
    else
      children
    end
  end
  
  defp establish_connection(vsm1_id, vsm2_id) do
    # In production, this would establish actual communication channels
    Logger.debug("Connected #{vsm1_id} <-> #{vsm2_id}")
  end
  
  defp get_vsm_dna(vsm_id) do
    try do
      {:ok, MetaVsm.get_dna(vsm_id)}
    catch
      :exit, _ -> {:error, :vsm_not_found}
    end
  end
  
  defp get_vsm_state(vsm_id) do
    try do
      {:ok, MetaVsm.get_recursive_state(vsm_id)}
    catch
      :exit, _ -> {:error, :vsm_not_found}
    end
  end
  
  defp terminate_vsm(vsm_id) do
    try do
      MetaVsm.kill_unviable(vsm_id)
    catch
      :exit, _ -> :ok
    end
  end
end