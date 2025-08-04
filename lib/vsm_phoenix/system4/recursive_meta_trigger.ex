defmodule VsmPhoenix.System4.RecursiveMetaTrigger do
  @moduledoc """
  Recursive Meta-System Triggering for System 4 Intelligence.
  
  This module implements recursive meta-system spawning capabilities,
  allowing System 4 to trigger the creation of new VSM instances that
  contain their own S1-S2-S3-S4-S5 subsystems, creating infinite
  recursive potential.
  
  Features:
  - Recursive VSM spawning
  - Meta-system configuration
  - Recursive depth management
  - Cross-system communication
  - Infinite variety generation
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.System1.Operations
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.Queen
  alias VsmPhoenix.MCP.HermesClient
  
  @name __MODULE__
  @recursion_threshold 0.8
  @max_recursion_depth 10  # Safety limit
  @meta_spawn_cooldown 60_000  # 1 minute between spawns
  
  # Client API
  
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  def evaluate_meta_trigger(variety_data, system_state) do
    GenServer.call(@name, {:evaluate_trigger, variety_data, system_state})
  end
  
  def spawn_meta_system(config) do
    GenServer.call(@name, {:spawn_meta, config})
  end
  
  def configure_recursion(depth, strategy) do
    GenServer.call(@name, {:configure_recursion, depth, strategy})
  end
  
  def get_meta_hierarchy do
    GenServer.call(@name, :get_meta_hierarchy)
  end
  
  def connect_meta_systems(parent_id, child_id) do
    GenServer.cast(@name, {:connect_systems, parent_id, child_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🌀 Recursive Meta-System Trigger initializing...")
    
    state = %{
      meta_systems: %{},
      recursion_tree: %{
        root: self(),
        children: [],
        depth: 0
      },
      spawn_history: [],
      recursion_config: %{
        max_depth: @max_recursion_depth,
        spawn_strategy: :adaptive,
        propagation_mode: :selective
      },
      meta_metrics: %{
        total_spawned: 0,
        active_systems: 0,
        max_depth_reached: 0,
        recursion_events: 0,
        variety_amplification: 1.0
      },
      last_spawn_time: nil,
      communication_channels: %{}
    }
    
    # Schedule periodic meta-system health check
    schedule_meta_health_check()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:evaluate_trigger, variety_data, system_state}, _from, state) do
    Logger.info("🌀 Evaluating meta-system trigger conditions")
    
    # Calculate trigger score
    trigger_score = calculate_trigger_score(variety_data, system_state, state)
    
    # Check recursion conditions
    should_spawn = should_spawn_meta?(trigger_score, state)
    
    evaluation = %{
      trigger_score: trigger_score,
      should_spawn: should_spawn,
      recursion_depth: calculate_safe_recursion_depth(variety_data, state),
      spawn_config: if(should_spawn, do: generate_spawn_config(variety_data, system_state), else: nil),
      reason: determine_spawn_reason(trigger_score, variety_data),
      cooldown_active: is_cooldown_active?(state)
    }
    
    # Auto-spawn if critical
    new_state = if should_spawn && trigger_score > 0.95 && !is_cooldown_active?(state) do
      Logger.warning("🌀🚨 CRITICAL META-SPAWN TRIGGERED AUTOMATICALLY!")
      spawn_meta_system_internal(evaluation.spawn_config, state)
    else
      state
    end
    
    {:reply, {:ok, evaluation}, new_state}
  end
  
  @impl true
  def handle_call({:spawn_meta, config}, _from, state) do
    Logger.info("🌀 Spawning meta-system with config: #{inspect(config)}")
    
    if is_cooldown_active?(state) do
      {:reply, {:error, :cooldown_active}, state}
    else
      new_state = spawn_meta_system_internal(config, state)
      {:reply, {:ok, List.first(new_state.spawn_history)}, new_state}
    end
  end
  
  @impl true
  def handle_call({:configure_recursion, depth, strategy}, _from, state) do
    Logger.info("🌀 Configuring recursion: depth=#{depth}, strategy=#{strategy}")
    
    new_config = %{state.recursion_config |
      max_depth: min(depth, @max_recursion_depth),
      spawn_strategy: strategy
    }
    
    new_state = %{state | recursion_config: new_config}
    
    {:reply, {:ok, new_config}, new_state}
  end
  
  @impl true
  def handle_call(:get_meta_hierarchy, _from, state) do
    hierarchy = %{
      tree: state.recursion_tree,
      active_systems: Map.keys(state.meta_systems),
      total_depth: calculate_tree_depth(state.recursion_tree),
      total_nodes: count_tree_nodes(state.recursion_tree),
      communication_map: state.communication_channels,
      metrics: state.meta_metrics
    }
    
    {:reply, {:ok, hierarchy}, state}
  end
  
  @impl true
  def handle_cast({:connect_systems, parent_id, child_id}, state) do
    Logger.info("🌀 Connecting meta-systems: #{parent_id} -> #{child_id}")
    
    # Establish communication channel
    channel = establish_meta_channel(parent_id, child_id)
    
    new_channels = Map.put(state.communication_channels, {parent_id, child_id}, channel)
    new_state = %{state | communication_channels: new_channels}
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(:check_meta_health, state) do
    # Check health of spawned meta-systems
    {active, inactive} = state.meta_systems
    |> Enum.split_with(fn {_id, meta} ->
      is_meta_system_alive?(meta)
    end)
    
    if length(inactive) > 0 do
      Logger.info("🌀 Cleaning up #{length(inactive)} inactive meta-systems")
    end
    
    # Update metrics
    new_metrics = %{state.meta_metrics |
      active_systems: length(active)
    }
    
    # Clean up inactive systems
    new_meta_systems = Map.new(active)
    
    # Schedule next check
    schedule_meta_health_check()
    
    new_state = %{state |
      meta_systems: new_meta_systems,
      meta_metrics: new_metrics
    }
    
    {:noreply, new_state}
  end
  
  # Private Functions
  
  defp spawn_meta_system_internal(config, state) do
    Logger.warning("🌀✨ SPAWNING RECURSIVE META-SYSTEM!")
    
    # Generate meta-system ID
    meta_id = "meta_vsm_#{:erlang.system_time(:microsecond)}"
    
    # Create meta-VSM configuration
    meta_config = %{
      id: meta_id,
      parent: self(),
      recursion_depth: state.recursion_tree.depth + 1,
      purpose: config[:purpose] || "variety_absorption",
      
      # Each meta-system gets its own subsystems!
      subsystems: %{
        system1: spawn_meta_s1(meta_id, config),
        system2: spawn_meta_s2(meta_id, config),
        system3: spawn_meta_s3(meta_id, config),
        system4: spawn_meta_s4(meta_id, config),
        system5: spawn_meta_s5(meta_id, config)
      },
      
      # Recursive capability
      can_spawn_meta: state.recursion_tree.depth < state.recursion_config.max_depth - 1,
      
      # Variety configuration
      variety_config: config[:variety_config] || %{
        absorption_rate: 0.8,
        amplification: 1.5,
        quantum_enabled: true
      }
    }
    
    # Spawn the meta-system supervisor
    case spawn_meta_supervisor(meta_config) do
      {:ok, supervisor_pid} ->
        # Record the meta-system
        meta_system = %{
          id: meta_id,
          pid: supervisor_pid,
          config: meta_config,
          spawned_at: DateTime.utc_now(),
          parent: self(),
          depth: state.recursion_tree.depth + 1
        }
        
        # Update state
        new_meta_systems = Map.put(state.meta_systems, meta_id, meta_system)
        new_tree = add_to_recursion_tree(state.recursion_tree, meta_system)
        new_history = [meta_system | state.spawn_history] |> Enum.take(100)
        
        # Update metrics
        new_metrics = %{state.meta_metrics |
          total_spawned: state.meta_metrics.total_spawned + 1,
          active_systems: state.meta_metrics.active_systems + 1,
          max_depth_reached: max(state.meta_metrics.max_depth_reached, meta_system.depth),
          variety_amplification: state.meta_metrics.variety_amplification * meta_config.variety_config.amplification
        }
        
        # Establish communication with parent
        establish_parent_child_communication(self(), supervisor_pid)
        
        # If MCP is available, create MCP bridge
        if config[:mcp_enabled] do
          create_mcp_bridge(meta_id, supervisor_pid)
        end
        
        %{state |
          meta_systems: new_meta_systems,
          recursion_tree: new_tree,
          spawn_history: new_history,
          meta_metrics: new_metrics,
          last_spawn_time: DateTime.utc_now()
        }
        
      {:error, reason} ->
        Logger.error("🌀 Failed to spawn meta-system: #{inspect(reason)}")
        state
    end
  end
  
  defp calculate_trigger_score(variety_data, system_state, state) do
    # Calculate meta-system trigger score
    factors = []
    
    # Factor 1: Variety explosion
    variety_score = if variety_data[:variety_explosion] do
      0.9
    else
      calculate_variety_pressure(variety_data)
    end
    factors = [variety_score | factors]
    
    # Factor 2: System stress
    stress_score = system_state[:stress_level] || 0.0
    factors = [stress_score | factors]
    
    # Factor 3: Recursive potential
    recursive_score = if variety_data[:recursive_potential] do
      length(variety_data.recursive_potential) / 10.0
    else
      0.0
    end |> min(1.0)
    factors = [recursive_score | factors]
    
    # Factor 4: Meta-system seeds
    meta_seeds_score = if variety_data[:meta_system_seeds] do
      map_size(variety_data.meta_system_seeds) / 5.0
    else
      0.0
    end |> min(1.0)
    factors = [meta_seeds_score | factors]
    
    # Factor 5: Emergent complexity
    emergence_score = case variety_data[:emergence_level] do
      :high -> 0.8
      :medium -> 0.5
      :low -> 0.2
      _ -> 0.0
    end
    factors = [emergence_score | factors]
    
    # Calculate weighted average
    if length(factors) > 0 do
      Enum.sum(factors) / length(factors)
    else
      0.0
    end
  end
  
  defp calculate_variety_pressure(variety_data) do
    # Calculate variety pressure that might trigger meta-spawn
    pattern_count = map_size(variety_data[:novel_patterns] || %{})
    
    if pattern_count > 20 do
      1.0
    else
      pattern_count / 20.0
    end
  end
  
  defp should_spawn_meta?(trigger_score, state) do
    # Determine if meta-system should be spawned
    trigger_score > @recursion_threshold &&
    !is_cooldown_active?(state) &&
    state.recursion_tree.depth < state.recursion_config.max_depth
  end
  
  defp is_cooldown_active?(state) do
    # Check if spawn cooldown is active
    case state.last_spawn_time do
      nil -> false
      last_time ->
        diff = DateTime.diff(DateTime.utc_now(), last_time, :millisecond)
        diff < @meta_spawn_cooldown
    end
  end
  
  defp calculate_safe_recursion_depth(variety_data, state) do
    # Calculate safe recursion depth based on variety
    base_depth = state.recursion_config.max_depth
    
    # Reduce depth if variety is extreme
    variety_factor = if variety_data[:variety_explosion] do
      0.5
    else
      0.8
    end
    
    round(base_depth * variety_factor)
  end
  
  defp generate_spawn_config(variety_data, system_state) do
    # Generate configuration for new meta-system
    %{
      purpose: determine_meta_purpose(variety_data, system_state),
      variety_config: %{
        target_patterns: variety_data[:novel_patterns] || %{},
        absorption_strategy: select_absorption_strategy(variety_data),
        quantum_enabled: variety_data[:quantum_enabled] || false
      },
      resource_allocation: calculate_resource_allocation(system_state),
      communication_mode: :async,
      mcp_enabled: Application.get_env(:vsm_phoenix, :enable_mcp, false)
    }
  end
  
  defp determine_meta_purpose(variety_data, _system_state) do
    # Determine purpose of meta-system
    cond do
      variety_data[:variety_explosion] -> :emergency_absorption
      map_size(variety_data[:meta_system_seeds] || %{}) > 3 -> :seed_cultivation
      length(variety_data[:recursive_potential] || []) > 5 -> :recursive_exploration
      variety_data[:emergence_level] == :high -> :emergence_management
      true -> :variety_processing
    end
  end
  
  defp select_absorption_strategy(variety_data) do
    # Select variety absorption strategy for meta-system
    if variety_data[:quantum_enabled] do
      :quantum_absorption
    else
      :selective_absorption
    end
  end
  
  defp calculate_resource_allocation(_system_state) do
    # Calculate resources for meta-system
    %{
      cpu_cores: 2,
      memory_mb: 512,
      priority: :high
    }
  end
  
  defp determine_spawn_reason(trigger_score, variety_data) do
    # Determine reason for spawn recommendation
    cond do
      trigger_score > 0.95 -> :critical_variety_overload
      variety_data[:variety_explosion] -> :variety_explosion_detected
      map_size(variety_data[:meta_system_seeds] || %{}) > 3 -> :meta_seeds_present
      length(variety_data[:recursive_potential] || []) > 5 -> :recursive_opportunity
      trigger_score > @recursion_threshold -> :threshold_exceeded
      true -> :no_spawn_needed
    end
  end
  
  defp spawn_meta_supervisor(config) do
    # Spawn the meta-system supervisor process
    # In production, this would use proper OTP supervision
    try do
      pid = spawn(fn -> 
        meta_system_loop(config)
      end)
      
      Process.monitor(pid)
      {:ok, pid}
    rescue
      e -> {:error, e}
    end
  end
  
  defp meta_system_loop(config) do
    # Meta-system main loop
    receive do
      {:variety, data} ->
        # Process variety in meta-system
        process_meta_variety(data, config)
        meta_system_loop(config)
        
      {:command, cmd} ->
        # Execute command in meta-system
        execute_meta_command(cmd, config)
        meta_system_loop(config)
        
      :shutdown ->
        Logger.info("🌀 Meta-system #{config.id} shutting down")
        cleanup_meta_system(config)
        
      _ ->
        meta_system_loop(config)
    end
  end
  
  defp process_meta_variety(data, config) do
    # Process variety in meta-system context
    Logger.debug("🌀 Meta-system #{config.id} processing variety")
    
    # Use quantum absorption if enabled
    if config.variety_config.quantum_enabled do
      # Quantum variety processing would happen here
      :ok
    else
      # Normal variety processing
      :ok
    end
  end
  
  defp execute_meta_command(cmd, config) do
    # Execute command in meta-system
    Logger.debug("🌀 Meta-system #{config.id} executing: #{inspect(cmd)}")
  end
  
  defp cleanup_meta_system(config) do
    # Clean up meta-system resources
    Logger.info("🌀 Cleaning up meta-system #{config.id}")
    
    # Terminate subsystems
    Enum.each(config.subsystems, fn {_name, pid} ->
      if is_pid(pid) && Process.alive?(pid) do
        Process.exit(pid, :shutdown)
      end
    end)
  end
  
  defp spawn_meta_s1(meta_id, config) do
    # Spawn meta System 1 (Operations)
    {:ok, pid} = GenServer.start(
      VsmPhoenix.System1.Operations,
      %{
        meta: true,
        parent: meta_id,
        config: config[:s1_config] || %{}
      }
    )
    pid
  end
  
  defp spawn_meta_s2(meta_id, config) do
    # Spawn meta System 2 (Coordination)
    # Simplified - would spawn actual S2
    spawn(fn -> 
      Logger.info("🌀 Meta S2 for #{meta_id} active")
      Process.sleep(:infinity)
    end)
  end
  
  defp spawn_meta_s3(meta_id, config) do
    # Spawn meta System 3 (Control)
    {:ok, pid} = GenServer.start(
      VsmPhoenix.System3.Control,
      %{
        meta: true,
        parent: meta_id,
        config: config[:s3_config] || %{}
      }
    )
    pid
  end
  
  defp spawn_meta_s4(meta_id, config) do
    # Spawn meta System 4 (Intelligence)
    {:ok, pid} = GenServer.start(
      VsmPhoenix.System4.Intelligence,
      %{
        meta: true,
        parent: meta_id,
        config: config[:s4_config] || %{},
        llm_enabled: true
      }
    )
    pid
  end
  
  defp spawn_meta_s5(meta_id, config) do
    # Spawn meta System 5 (Queen/Governance)
    {:ok, pid} = GenServer.start(
      VsmPhoenix.System5.Queen,
      %{
        meta: true,
        parent: meta_id,
        config: config[:s5_config] || %{},
        recursive_depth: :infinite
      }
    )
    pid
  end
  
  defp add_to_recursion_tree(tree, meta_system) do
    # Add meta-system to recursion tree
    %{tree |
      children: [meta_system.id | tree.children],
      depth: max(tree.depth, meta_system.depth)
    }
  end
  
  defp establish_parent_child_communication(parent_pid, child_pid) do
    # Establish communication between parent and child systems
    Logger.info("🌀 Establishing parent-child communication")
    
    # Send introduction messages
    send(child_pid, {:parent, parent_pid})
    send(parent_pid, {:child, child_pid})
  end
  
  defp establish_meta_channel(parent_id, child_id) do
    # Establish communication channel between meta-systems
    %{
      type: :bidirectional,
      parent: parent_id,
      child: child_id,
      protocol: :async_message_passing,
      established_at: DateTime.utc_now()
    }
  end
  
  defp create_mcp_bridge(meta_id, supervisor_pid) do
    # Create MCP bridge for meta-system
    Logger.info("🌀 Creating MCP bridge for #{meta_id}")
    
    # This would connect to Hermes MCP for meta-system
    case HermesClient.create_meta_bridge(meta_id, supervisor_pid) do
      {:ok, bridge} ->
        Logger.info("🌀 MCP bridge established: #{inspect(bridge)}")
      {:error, reason} ->
        Logger.warning("🌀 MCP bridge creation failed: #{inspect(reason)}")
    end
  end
  
  defp is_meta_system_alive?(meta_system) do
    # Check if meta-system is still alive
    is_pid(meta_system.pid) && Process.alive?(meta_system.pid)
  end
  
  defp calculate_tree_depth(tree) do
    # Calculate total depth of recursion tree
    tree.depth
  end
  
  defp count_tree_nodes(tree) do
    # Count total nodes in recursion tree
    1 + length(tree.children)
  end
  
  defp schedule_meta_health_check do
    Process.send_after(self(), :check_meta_health, 30_000)  # Every 30 seconds
  end
end