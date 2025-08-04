defmodule VsmPhoenix.VsmSupervisor do
  @moduledoc """
  Enhanced VSM Supervisor with META-VSM Recursive Spawning
  
  Manages VSM-specific processes including:
  - Traditional VSM support systems
  - META-VSM recursive spawning infrastructure
  - Genetic evolution engine
  - Fractal architecture management
  - Self-replicating VSM colonies
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    # Check if META-VSM mode is enabled
    meta_vsm_enabled = Keyword.get(opts, :meta_vsm_enabled, true)
    
    Logger.info("🚀 Initializing VSM Supervisor (META-VSM: #{meta_vsm_enabled})")
    
    children = base_children() ++ if meta_vsm_enabled do
      meta_vsm_children()
    else
      []
    end
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  @doc """
  Spawn a new META-VSM instance
  """
  def spawn_meta_vsm(config \\ %{}) do
    VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner.spawn_child_vsm(config)
  end
  
  @doc """
  Create a VSM swarm with collective intelligence
  """
  def spawn_vsm_swarm(size, behavior \\ :cooperative) do
    VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner.spawn_swarm(%{
      size: size,
      behavior: behavior,
      id: "swarm_#{System.unique_integer([:positive])}"
    })
  end
  
  @doc """
  Initialize a fractal VSM network
  """
  def spawn_fractal_network(pattern \\ :tree, depth \\ 5) do
    topology = VsmPhoenix.MetaVsm.Fractals.FractalArchitect.design_topology(pattern, depth)
    
    VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner.spawn_network(
      pattern,
      topology.structure |> length()
    )
  end
  
  @doc """
  Emergency spawn for crisis response
  """
  def emergency_spawn(crisis_type, count \\ 3) do
    VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner.emergency_spawn(crisis_type, count)
  end
  
  @doc """
  Get META-VSM population statistics
  """
  def get_population_stats do
    registry_size = Registry.count(VsmPhoenix.MetaVsmRegistry)
    
    %{
      total_vsms: registry_size,
      active_vsms: count_active_vsms(),
      average_fitness: calculate_average_fitness(),
      genetic_diversity: calculate_genetic_diversity(),
      deepest_recursion: find_deepest_recursion()
    }
  end
  
  # Private functions
  
  defp base_children do
    [
      # VSM Performance Monitor
      {VsmPhoenix.PerformanceMonitor, []},
      
      # VSM Health Checker
      {VsmPhoenix.HealthChecker, []},
      
      # VSM Telemetry Collector
      {VsmPhoenix.TelemetryCollector, []},
      
      # Tidewave Integration (if available)
      {VsmPhoenix.TidewaveIntegration, []},
      
      # VSM Configuration Manager
      {VsmPhoenix.ConfigManager, []}
    ]
  end
  
  defp meta_vsm_children do
    [
      # META-VSM Registry for tracking all VSM instances
      {Registry, keys: :unique, name: VsmPhoenix.MetaVsmRegistry},
      
      # Recursive Spawner Supervisor
      {VsmPhoenix.MetaVsm.Spawner.RecursiveSpawner, []},
      
      # Primordial VSM (the first one)
      {VsmPhoenix.MetaVsm.Core.MetaVsm, [
        id: "primordial_vsm",
        generation: 0,
        depth: 0,
        dna: VsmPhoenix.MetaVsm.Genetics.DnaConfig.generate_primordial_dna()
      ]}
    ]
  end
  
  defp count_active_vsms do
    Registry.select(VsmPhoenix.MetaVsmRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$2"]}])
    |> Enum.count(fn pid -> Process.alive?(pid) end)
  end
  
  defp calculate_average_fitness do
    Registry.select(VsmPhoenix.MetaVsmRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.map(fn vsm_id ->
      try do
        VsmPhoenix.MetaVsm.Core.MetaVsm.measure_fitness(vsm_id)
      catch
        :exit, _ -> 0.0
      end
    end)
    |> case do
      [] -> 0.0
      fitnesses -> Enum.sum(fitnesses) / length(fitnesses)
    end
  end
  
  defp calculate_genetic_diversity do
    dnas = Registry.select(VsmPhoenix.MetaVsmRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.map(fn vsm_id ->
      try do
        VsmPhoenix.MetaVsm.Core.MetaVsm.get_dna(vsm_id)
      catch
        :exit, _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    
    if length(dnas) > 1 do
      VsmPhoenix.MetaVsm.Genetics.Evolution.genetic_diversity(dnas)
    else
      0.0
    end
  end
  
  defp find_deepest_recursion do
    Registry.select(VsmPhoenix.MetaVsmRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
    |> Enum.map(fn vsm_id ->
      try do
        state = VsmPhoenix.MetaVsm.Core.MetaVsm.get_recursive_state(vsm_id)
        state.depth
      catch
        :exit, _ -> 0
      end
    end)
    |> Enum.max(fn -> 0 end)
  end
end