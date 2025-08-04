defmodule VsmPhoenix.MetaVsm.Core.MetaVsm do
  @moduledoc """
  META-VSM: A recursive, self-replicating Viable System Model
  
  This module implements a fractal VSM architecture where each VSM can:
  - Spawn child VSMs recursively
  - Inherit DNA-like configuration from parent
  - Evolve through genetic algorithms
  - Self-organize into hierarchical structures
  - Maintain viability at all recursive levels
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner
  alias VsmPhoenix.MetaVsm.Genetics.DnaConfig
  alias VsmPhoenix.MetaVsm.Genetics.Evolution
  alias VsmPhoenix.MetaVsm.Fractals.FractalArchitect
  
  @max_recursion_depth 7  # Inspired by human organization limits
  @mutation_rate 0.05     # 5% chance of beneficial mutations
  
  defstruct [
    :id,
    :parent_id,
    :generation,
    :dna,
    :children,
    :depth,
    :fitness,
    :viable,
    :spawning_enabled,
    :evolution_enabled,
    :vsm_components,
    :metadata,
    :birth_time,
    :mutations
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: via_tuple(opts[:id]))
  end
  
  def spawn_child(parent_id, child_config \\ %{}) do
    GenServer.call(via_tuple(parent_id), {:spawn_child, child_config})
  end
  
  def get_family_tree(vsm_id) do
    GenServer.call(via_tuple(vsm_id), :get_family_tree)
  end
  
  def evolve(vsm_id, selection_pressure \\ nil) do
    GenServer.call(via_tuple(vsm_id), {:evolve, selection_pressure})
  end
  
  def get_dna(vsm_id) do
    GenServer.call(via_tuple(vsm_id), :get_dna)
  end
  
  def inject_dna(vsm_id, dna_fragment) do
    GenServer.call(via_tuple(vsm_id), {:inject_dna, dna_fragment})
  end
  
  def measure_fitness(vsm_id) do
    GenServer.call(via_tuple(vsm_id), :measure_fitness)
  end
  
  def kill_unviable(vsm_id) do
    GenServer.cast(via_tuple(vsm_id), :kill_if_unviable)
  end
  
  def get_recursive_state(vsm_id) do
    GenServer.call(via_tuple(vsm_id), :get_recursive_state)
  end
  
  def broadcast_to_descendants(vsm_id, message) do
    GenServer.cast(via_tuple(vsm_id), {:broadcast_descendants, message})
  end
  
  def merge_vsms(vsm1_id, vsm2_id) do
    GenServer.call(via_tuple(vsm1_id), {:merge_with, vsm2_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    id = opts[:id] || generate_vsm_id()
    parent_id = opts[:parent_id]
    generation = opts[:generation] || 0
    depth = opts[:depth] || 0
    
    # Initialize or inherit DNA
    dna = case opts[:dna] do
      nil when is_nil(parent_id) -> 
        DnaConfig.generate_primordial_dna()
      nil -> 
        inherit_and_mutate_dna(parent_id)
      dna -> 
        dna
    end
    
    state = %__MODULE__{
      id: id,
      parent_id: parent_id,
      generation: generation,
      dna: dna,
      children: [],
      depth: depth,
      fitness: 1.0,
      viable: true,
      spawning_enabled: depth < @max_recursion_depth,
      evolution_enabled: Map.get(dna, :evolution_enabled, true),
      vsm_components: initialize_vsm_components(id, dna),
      metadata: %{
        birth_time: System.system_time(:second),
        spawn_count: 0,
        evolution_count: 0,
        last_evolution: nil
      },
      mutations: []
    }
    
    Logger.info("🧬 META-VSM #{id} born at generation #{generation}, depth #{depth}")
    
    # Register with parent if exists
    if parent_id do
      GenServer.cast(via_tuple(parent_id), {:register_child, id})
    end
    
    # Schedule periodic fitness evaluation
    schedule_fitness_check()
    
    # Schedule evolution if enabled
    if state.evolution_enabled do
      schedule_evolution()
    end
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:spawn_child, child_config}, _from, state) do
    if state.spawning_enabled and state.depth < @max_recursion_depth do
      Logger.info("🔄 META-VSM #{state.id} spawning child at depth #{state.depth + 1}")
      
      # Prepare child DNA with inheritance and potential mutations
      child_dna = Evolution.inherit_with_mutations(state.dna, @mutation_rate)
      
      child_opts = Map.merge(child_config, %{
        parent_id: state.id,
        generation: state.generation + 1,
        depth: state.depth + 1,
        dna: child_dna
      })
      
      # Spawn child VSM
      case RecursiveSpawner.spawn_child_vsm(child_opts) do
        {:ok, child_id} ->
          new_state = %{state | 
            children: [child_id | state.children],
            metadata: Map.update!(state.metadata, :spawn_count, &(&1 + 1))
          }
          
          # Notify System5 Queen about new spawn
          notify_queen_of_spawn(state.id, child_id, state.depth + 1)
          
          {:reply, {:ok, child_id}, new_state}
          
        error ->
          {:reply, error, state}
      end
    else
      {:reply, {:error, :spawning_disabled}, state}
    end
  end
  
  @impl true
  def handle_call(:get_family_tree, _from, state) do
    tree = build_family_tree(state)
    {:reply, tree, state}
  end
  
  @impl true
  def handle_call({:evolve, selection_pressure}, _from, state) do
    if state.evolution_enabled do
      Logger.info("🧬 META-VSM #{state.id} evolving with pressure: #{inspect(selection_pressure)}")
      
      # Apply evolution
      {evolved_dna, mutations} = Evolution.evolve(
        state.dna, 
        state.fitness,
        selection_pressure
      )
      
      # Update VSM components with new DNA
      updated_components = reconfigure_components(state.vsm_components, evolved_dna)
      
      new_state = %{state |
        dna: evolved_dna,
        mutations: mutations ++ state.mutations,
        vsm_components: updated_components,
        metadata: state.metadata
          |> Map.update!(:evolution_count, &(&1 + 1))
          |> Map.put(:last_evolution, System.system_time(:second))
      }
      
      # Propagate beneficial mutations to children
      if Evolution.is_beneficial?(mutations, state.fitness) do
        propagate_mutations_to_children(state.children, mutations)
      end
      
      {:reply, {:ok, mutations}, new_state}
    else
      {:reply, {:error, :evolution_disabled}, state}
    end
  end
  
  @impl true
  def handle_call(:get_dna, _from, state) do
    {:reply, state.dna, state}
  end
  
  @impl true
  def handle_call({:inject_dna, dna_fragment}, _from, state) do
    Logger.info("💉 Injecting DNA fragment into META-VSM #{state.id}")
    
    # Merge DNA fragment with current DNA
    merged_dna = DnaConfig.merge_dna(state.dna, dna_fragment)
    
    # Reconfigure components
    updated_components = reconfigure_components(state.vsm_components, merged_dna)
    
    new_state = %{state | 
      dna: merged_dna,
      vsm_components: updated_components
    }
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_call(:measure_fitness, _from, state) do
    fitness = calculate_fitness(state)
    new_state = %{state | fitness: fitness}
    {:reply, fitness, new_state}
  end
  
  @impl true
  def handle_call(:get_recursive_state, _from, state) do
    recursive_state = %{
      id: state.id,
      parent_id: state.parent_id,
      generation: state.generation,
      depth: state.depth,
      fitness: state.fitness,
      viable: state.viable,
      children_count: length(state.children),
      mutations_count: length(state.mutations),
      dna_signature: DnaConfig.signature(state.dna),
      children_states: get_children_states(state.children)
    }
    
    {:reply, recursive_state, state}
  end
  
  @impl true
  def handle_call({:merge_with, other_vsm_id}, _from, state) do
    Logger.info("🔀 Merging META-VSM #{state.id} with #{other_vsm_id}")
    
    case GenServer.call(via_tuple(other_vsm_id), :get_dna) do
      other_dna when is_map(other_dna) ->
        # Perform sexual reproduction-like DNA mixing
        merged_dna = Evolution.crossover(state.dna, other_dna)
        
        # Create offspring with merged DNA
        offspring_opts = %{
          parent_id: state.id,
          generation: state.generation + 1,
          depth: state.depth,
          dna: merged_dna
        }
        
        case RecursiveSpawner.spawn_child_vsm(offspring_opts) do
          {:ok, offspring_id} ->
            {:reply, {:ok, offspring_id}, state}
          error ->
            {:reply, error, state}
        end
        
      _ ->
        {:reply, {:error, :merge_failed}, state}
    end
  end
  
  @impl true
  def handle_cast({:register_child, child_id}, state) do
    Logger.info("📝 Registering child #{child_id} with parent #{state.id}")
    new_state = %{state | children: [child_id | state.children]}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast(:kill_if_unviable, state) do
    if not state.viable or state.fitness < 0.3 do
      Logger.warning("☠️ META-VSM #{state.id} is unviable, initiating self-termination")
      
      # Kill all children first (harsh but necessary)
      Enum.each(state.children, &kill_child/1)
      
      # Notify parent of death
      if state.parent_id do
        GenServer.cast(via_tuple(state.parent_id), {:child_died, state.id})
      end
      
      {:stop, :unviable, state}
    else
      {:noreply, state}
    end
  end
  
  @impl true
  def handle_cast({:child_died, child_id}, state) do
    Logger.info("👻 Child #{child_id} died, removing from registry")
    new_state = %{state | children: List.delete(state.children, child_id)}
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:broadcast_descendants, message}, state) do
    # Broadcast to all children recursively
    Enum.each(state.children, fn child_id ->
      GenServer.cast(via_tuple(child_id), {:broadcast_descendants, message})
      GenServer.cast(via_tuple(child_id), {:ancestor_message, message})
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:ancestor_message, message}, state) do
    Logger.info("📨 META-VSM #{state.id} received ancestor message: #{inspect(message)}")
    # Process ancestor message
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:check_fitness, state) do
    fitness = calculate_fitness(state)
    viable = fitness > 0.3
    
    new_state = %{state | fitness: fitness, viable: viable}
    
    # Natural selection - kill if unviable
    if not viable do
      GenServer.cast(self(), :kill_if_unviable)
    end
    
    schedule_fitness_check()
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:evolve, state) do
    if state.evolution_enabled and state.fitness < 0.8 do
      # Auto-evolve if fitness is suboptimal
      GenServer.call(self(), {:evolve, :auto})
    end
    
    schedule_evolution()
    {:noreply, state}
  end
  
  # Private Functions
  
  defp via_tuple(id) do
    {:via, Registry, {VsmPhoenix.MetaVsmRegistry, id}}
  end
  
  defp generate_vsm_id do
    "meta_vsm_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp inherit_and_mutate_dna(parent_id) do
    parent_dna = GenServer.call(via_tuple(parent_id), :get_dna)
    Evolution.inherit_with_mutations(parent_dna, @mutation_rate)
  end
  
  defp initialize_vsm_components(id, dna) do
    # Initialize the 5 VSM systems based on DNA configuration
    %{
      system1: spawn_system_component(id, :system1, dna.system1_config),
      system2: spawn_system_component(id, :system2, dna.system2_config),
      system3: spawn_system_component(id, :system3, dna.system3_config),
      system4: spawn_system_component(id, :system4, dna.system4_config),
      system5: spawn_system_component(id, :system5, dna.system5_config)
    }
  end
  
  defp spawn_system_component(vsm_id, system_type, config) do
    # This would spawn actual VSM system components
    # For now, we'll just store the configuration
    %{
      type: system_type,
      config: config,
      pid: nil,  # Would be actual process in production
      status: :initialized
    }
  end
  
  defp reconfigure_components(components, new_dna) do
    # Reconfigure each system component with new DNA
    %{
      system1: update_component(components.system1, new_dna.system1_config),
      system2: update_component(components.system2, new_dna.system2_config),
      system3: update_component(components.system3, new_dna.system3_config),
      system4: update_component(components.system4, new_dna.system4_config),
      system5: update_component(components.system5, new_dna.system5_config)
    }
  end
  
  defp update_component(component, new_config) do
    %{component | config: new_config}
  end
  
  defp calculate_fitness(state) do
    # Multi-factor fitness calculation
    base_fitness = 0.5
    
    # Factor 1: Children survival rate
    children_fitness = if length(state.children) > 0 do
      viable_children = Enum.count(state.children, &is_child_viable?/1)
      viable_children / length(state.children)
    else
      0.5
    end
    
    # Factor 2: Depth efficiency (shallower is often better)
    depth_fitness = 1.0 - (state.depth / @max_recursion_depth)
    
    # Factor 3: Evolution success rate
    evolution_fitness = if state.metadata.evolution_count > 0 do
      beneficial_mutations = Enum.count(state.mutations, &(&1.beneficial))
      beneficial_mutations / state.metadata.evolution_count
    else
      0.5
    end
    
    # Factor 4: Age survival (older is fitter)
    age = System.system_time(:second) - state.metadata.birth_time
    age_fitness = min(1.0, age / 3600)  # Max fitness at 1 hour
    
    # Weighted average
    (base_fitness * 0.2 + 
     children_fitness * 0.3 + 
     depth_fitness * 0.2 + 
     evolution_fitness * 0.2 + 
     age_fitness * 0.1)
  end
  
  defp is_child_viable?(child_id) do
    try do
      GenServer.call(via_tuple(child_id), :measure_fitness) > 0.3
    catch
      :exit, _ -> false
    end
  end
  
  defp build_family_tree(state) do
    %{
      id: state.id,
      generation: state.generation,
      depth: state.depth,
      fitness: state.fitness,
      children: Enum.map(state.children, fn child_id ->
        try do
          GenServer.call(via_tuple(child_id), :get_family_tree)
        catch
          :exit, _ -> %{id: child_id, status: :dead}
        end
      end)
    }
  end
  
  defp get_children_states(children) do
    Enum.map(children, fn child_id ->
      try do
        GenServer.call(via_tuple(child_id), :get_recursive_state, 1000)
      catch
        :exit, _ -> %{id: child_id, status: :dead}
      end
    end)
  end
  
  defp propagate_mutations_to_children(children, mutations) do
    Enum.each(children, fn child_id ->
      try do
        GenServer.call(via_tuple(child_id), {:inject_dna, %{mutations: mutations}})
      catch
        :exit, _ -> :ok
      end
    end)
  end
  
  defp kill_child(child_id) do
    try do
      GenServer.cast(via_tuple(child_id), :kill_if_unviable)
    catch
      :exit, _ -> :ok
    end
  end
  
  defp notify_queen_of_spawn(parent_id, child_id, depth) do
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:meta",
      {:vsm_spawned, %{
        parent_id: parent_id,
        child_id: child_id,
        depth: depth,
        timestamp: DateTime.utc_now()
      }}
    )
  end
  
  defp schedule_fitness_check do
    Process.send_after(self(), :check_fitness, 60_000)  # Every minute
  end
  
  defp schedule_evolution do
    Process.send_after(self(), :evolve, 300_000)  # Every 5 minutes
  end
end