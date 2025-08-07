defmodule VsmPhoenix.Hive.Spawner do
  @moduledoc """
  VSM RECURSIVE SPAWNING SYSTEM
  
  This module enables VSMs to recursively spawn new VSM instances when facing
  variety explosions that exceed their current capacity. Each spawned VSM
  inherits the full S1-S5 architecture but can be specialized for specific domains.
  
  SPAWNING TRIGGERS:
  1. Variety explosion detected by S4
  2. Resource bottleneck identified by S3  
  3. Policy complexity requiring specialized governance (S5)
  4. Novel domain requiring specialized intelligence (S4)
  5. Explicit spawn request via MCP
  
  SPAWNED VSM CHARACTERISTICS:
  - Full S1-S5 recursive architecture
  - Specialized capabilities for target domain
  - MCP client/server for parent communication
  - Independent operation with oversight boundaries
  - Ability to spawn further meta-VSMs
  
  This creates TRUE recursive cybernetics - VSMs spawning VSMs!
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Hive.Discovery
  
  @name __MODULE__
  @spawn_timeout 30_000
  @max_recursive_depth 5
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Spawn a new VSM with specified configuration
  """
  def spawn_vsm(config) do
    GenServer.call(@name, {:spawn_vsm, config}, @spawn_timeout)
  end
  
  @doc """
  Get list of spawned VSMs
  """
  def list_spawned_vsms do
    GenServer.call(@name, :list_spawned)
  end
  
  @doc """
  Terminate a spawned VSM
  """
  def terminate_vsm(vsm_id) do
    GenServer.call(@name, {:terminate_vsm, vsm_id})
  end
  
  @doc """
  Check if spawning is needed based on variety analysis
  """
  def analyze_spawn_need(variety_data) do
    GenServer.call(@name, {:analyze_spawn_need, variety_data})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    Logger.info("🧬 VSM Spawner initializing...")
    
    state = %{
      spawned_vsms: %{},
      spawn_templates: load_spawn_templates(),
      active_spawns: %{},
      config: opts
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:spawn_vsm, config}, from, state) do
    Logger.info("🚀 Spawning VSM: #{config.identity}")
    
    # Validate spawn configuration
    case validate_spawn_config(config) do
      :ok ->
        spawn_id = generate_spawn_id()
        
        # Start async spawn process
        spawn_pid = spawn_link(fn -> execute_spawn(config, from, spawn_id) end)
        
        new_active = Map.put(state.active_spawns, spawn_id, %{
          config: config,
          pid: spawn_pid,
          started_at: DateTime.utc_now(),
          from: from
        })
        
        new_state = %{state | active_spawns: new_active}
        {:noreply, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:list_spawned, _from, state) do
    spawned_list = Map.values(state.spawned_vsms)
    {:reply, {:ok, spawned_list}, state}
  end
  
  @impl true
  def handle_call({:terminate_vsm, vsm_id}, _from, state) do
    case Map.get(state.spawned_vsms, vsm_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      vsm_info ->
        Logger.info("🔚 Terminating VSM: #{vsm_id}")
        
        # Gracefully shutdown the VSM
        case terminate_vsm_process(vsm_info) do
          :ok ->
            new_spawned = Map.delete(state.spawned_vsms, vsm_id)
            {:reply, :ok, %{state | spawned_vsms: new_spawned}}
            
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end
  
  @impl true
  def handle_call({:analyze_spawn_need, variety_data}, _from, state) do
    analysis = analyze_variety_for_spawning(variety_data, state)
    {:reply, analysis, state}
  end
  
  @impl true
  def handle_info({:spawn_complete, spawn_id, result}, state) do
    case Map.get(state.active_spawns, spawn_id) do
      nil ->
        Logger.warning("⚠️  Received spawn complete for unknown spawn: #{spawn_id}")
        {:noreply, state}
        
      spawn_info ->
        Logger.info("✅ Spawn complete: #{spawn_id}")
        
        # Send reply to original caller
        GenServer.reply(spawn_info.from, result)
        
        # Update state based on result
        new_state = case result do
          {:ok, vsm_info} ->
            # Add to spawned VSMs
            new_spawned = Map.put(state.spawned_vsms, vsm_info.identity, vsm_info)
            new_active = Map.delete(state.active_spawns, spawn_id)
            
            %{state | 
              spawned_vsms: new_spawned,
              active_spawns: new_active
            }
            
          {:error, _reason} ->
            # Just remove from active spawns
            new_active = Map.delete(state.active_spawns, spawn_id)
            %{state | active_spawns: new_active}
        end
        
        {:noreply, new_state}
    end
  end
  
  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    # Handle spawned VSM process death
    case find_vsm_by_pid(pid, state.spawned_vsms) do
      {vsm_id, _vsm_info} ->
        Logger.warning("💀 Spawned VSM died: #{vsm_id}, reason: #{inspect(reason)}")
        
        new_spawned = Map.delete(state.spawned_vsms, vsm_id)
        {:noreply, %{state | spawned_vsms: new_spawned}}
        
      nil ->
        {:noreply, state}
    end
  end
  
  # Private Functions - Spawn Execution
  
  defp execute_spawn(config, from_pid, spawn_id) do
    Logger.info("🧬 Executing spawn for #{config.identity}")
    
    try do
      # Step 1: Create VSM application structure
      {:ok, app_config} = create_vsm_app_config(config)
      
      # Step 2: Start VSM application
      {:ok, vsm_supervisor} = start_vsm_application(app_config)
      
      # Step 3: Initialize VSM systems (S1-S5)
      {:ok, systems} = initialize_vsm_systems(vsm_supervisor, config)
      
      # Step 4: Start MCP server for the new VSM
      {:ok, mcp_server} = start_vsm_mcp_server(systems, config)
      
      # Step 5: Register with discovery
      :ok = register_spawned_vsm(config, systems, mcp_server)
      
      # Step 6: Establish parent-child communication
      {:ok, comm_channel} = establish_parent_communication(config)
      
      vsm_info = %{
        identity: config.identity,
        purpose: config.purpose,
        supervisor: vsm_supervisor,
        systems: systems,
        mcp_server: mcp_server,
        comm_channel: comm_channel,
        capabilities: derive_capabilities(config),
        spawned_at: DateTime.utc_now(),
        parent_vsm: config.parent_vsm,
        recursive_depth: config.recursive_depth || 1,
        status: :active
      }
      
      # Monitor the spawned VSM
      Process.monitor(vsm_supervisor)
      
      send(from_pid, {:spawn_complete, spawn_id, {:ok, vsm_info}})
      
    rescue
      error ->
        Logger.error("❌ Spawn failed for #{config.identity}: #{inspect(error)}")
        send(from_pid, {:spawn_complete, spawn_id, {:error, inspect(error)}})
    end
  end
  
  defp create_vsm_app_config(config) do
    app_config = %{
      name: String.to_atom("vsm_#{config.identity}"),
      identity: config.identity,
      purpose: config.purpose,
      specializations: config.capabilities || [],
      parent_vsm: config.parent_vsm,
      recursive_depth: config.recursive_depth || 1,
      
      # System configurations
      systems: %{
        s1: %{contexts: determine_s1_contexts(config)},
        s2: %{coordination_type: determine_s2_type(config)},
        s3: %{resource_scope: determine_s3_scope(config)},
        s4: %{intelligence_domain: determine_s4_domain(config)},
        s5: %{governance_model: determine_s5_model(config)}
      },
      
      # Network configuration
      network: %{
        mcp_port: get_available_port(),
        discovery_enabled: true
      }
    }
    
    {:ok, app_config}
  end
  
  defp start_vsm_application(app_config) do
    Logger.info("🏗️  Starting VSM application: #{app_config.identity}")
    
    # Create dynamic supervisor for this VSM
    supervisor_spec = {
      DynamicSupervisor,
      strategy: :one_for_one,
      name: String.to_atom("#{app_config.name}_supervisor")
    }
    
    case DynamicSupervisor.start_link(supervisor_spec) do
      {:ok, supervisor} ->
        Logger.info("✅ VSM supervisor started: #{inspect(supervisor)}")
        {:ok, supervisor}
        
      {:error, reason} ->
        Logger.error("❌ Failed to start VSM supervisor: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp initialize_vsm_systems(supervisor, config) do
    Logger.info("🧠 Initializing VSM systems for #{config.identity}")
    
    systems = %{}
    
    # Start System 1 - Operations
    {:ok, s1_pid} = start_system1(supervisor, config)
    systems = Map.put(systems, :s1, s1_pid)
    
    # Start System 2 - Coordination
    {:ok, s2_pid} = start_system2(supervisor, config)
    systems = Map.put(systems, :s2, s2_pid)
    
    # Start System 3 - Control
    {:ok, s3_pid} = start_system3(supervisor, config)
    systems = Map.put(systems, :s3, s3_pid)
    
    # Start System 4 - Intelligence
    {:ok, s4_pid} = start_system4(supervisor, config)
    systems = Map.put(systems, :s4, s4_pid)
    
    # Start System 5 - Governance
    {:ok, s5_pid} = start_system5(supervisor, config)
    systems = Map.put(systems, :s5, s5_pid)
    
    Logger.info("✅ All VSM systems initialized for #{config.identity}")
    {:ok, systems}
  end
  
  defp start_vsm_mcp_server(systems, config) do
    Logger.info("📡 Starting MCP server for #{config.identity}")
    
    mcp_config = %{
      vsm_identity: config.identity,
      systems: systems,
      capabilities: derive_capabilities(config),
      parent_vsm: config.parent_vsm
    }
    
    # Start the MCP server process
    case VsmPhoenix.MCP.HiveMindServer.start_link(mcp_config) do
      {:ok, mcp_pid} ->
        # Start stdio transport
        case VsmPhoenix.MCP.HiveMindServer.start_stdio_server() do
          {:ok, _stdio_pid} ->
            Logger.info("✅ MCP server started for #{config.identity}")
            {:ok, mcp_pid}
            
          {:error, reason} ->
            Logger.error("❌ Failed to start stdio server: #{inspect(reason)}")
            {:error, reason}
        end
        
      {:error, reason} ->
        Logger.error("❌ Failed to start MCP server: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp register_spawned_vsm(config, systems, mcp_server) do
    Logger.info("📝 Registering spawned VSM: #{config.identity}")
    
    # Register with discovery system
    Discovery.register_vsm(config.identity)
    
    # TODO: Register with parent VSM
    # TODO: Update global VSM registry
    
    :ok
  end
  
  defp establish_parent_communication(config) do
    Logger.info("🔗 Establishing parent communication for #{config.identity}")
    
    # Create MCP client connection to parent VSM
    parent_connection = %{
      parent_vsm: config.parent_vsm,
      connection_type: :mcp_client,
      established_at: DateTime.utc_now()
    }
    
    {:ok, parent_connection}
  end
  
  # System initialization functions
  
  defp start_system1(supervisor, config) do
    Logger.debug("🔧 Starting System 1 for #{config.identity}")
    
    s1_spec = %{
      id: :system1,
      start: {VsmPhoenix.System1.Operations, :start_link, [[
        identity: config.identity,
        contexts: config.systems.s1.contexts
      ]]},
      type: :worker
    }
    
    case DynamicSupervisor.start_child(supervisor, s1_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, "S1 failed: #{inspect(reason)}"}
    end
  end
  
  defp start_system2(supervisor, config) do
    Logger.debug("🤝 Starting System 2 for #{config.identity}")
    
    # System 2 would coordinate between S1 contexts
    # For now, return a placeholder
    {:ok, spawn(fn -> :timer.sleep(:infinity) end)}
  end
  
  defp start_system3(supervisor, config) do
    Logger.debug("⚖️  Starting System 3 for #{config.identity}")
    
    s3_spec = %{
      id: :system3,
      start: {VsmPhoenix.System3.Control, :start_link, [[
        identity: config.identity,
        resource_scope: config.systems.s3.resource_scope
      ]]},
      type: :worker
    }
    
    case DynamicSupervisor.start_child(supervisor, s3_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, "S3 failed: #{inspect(reason)}"}
    end
  end
  
  defp start_system4(supervisor, config) do
    Logger.debug("🧠 Starting System 4 for #{config.identity}")
    
    s4_spec = %{
      id: :system4,
      start: {VsmPhoenix.System4.Intelligence, :start_link, [[
        identity: config.identity,
        intelligence_domain: config.systems.s4.intelligence_domain
      ]]},
      type: :worker
    }
    
    case DynamicSupervisor.start_child(supervisor, s4_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, "S4 failed: #{inspect(reason)}"}
    end
  end
  
  defp start_system5(supervisor, config) do
    Logger.debug("👑 Starting System 5 for #{config.identity}")
    
    s5_spec = %{
      id: :system5,
      start: {VsmPhoenix.System5.Queen, :start_link, [[
        identity: config.identity,
        governance_model: config.systems.s5.governance_model
      ]]},
      type: :worker
    }
    
    case DynamicSupervisor.start_child(supervisor, s5_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, reason} -> {:error, "S5 failed: #{inspect(reason)}"}
    end
  end
  
  # Configuration determination functions
  
  defp determine_s1_contexts(config) do
    case config.purpose do
      "policy_enforcement" -> [:policy_context]
      "data_analysis" -> [:analytics_context]
      "resource_management" -> [:resource_context]
      _ -> [:general_context]
    end
  end
  
  defp determine_s2_type(config) do
    case length(determine_s1_contexts(config)) do
      1 -> :simple
      2 -> :dual_coordination
      _ -> :multi_coordination
    end
  end
  
  defp determine_s3_scope(config) do
    case config.purpose do
      "policy_enforcement" -> :policy_resources
      "data_analysis" -> :compute_resources
      "resource_management" -> :all_resources
      _ -> :basic_resources
    end
  end
  
  defp determine_s4_domain(config) do
    case config.purpose do
      "policy_enforcement" -> :policy_intelligence
      "data_analysis" -> :data_intelligence
      "resource_management" -> :resource_intelligence
      _ -> :general_intelligence
    end
  end
  
  defp determine_s5_model(config) do
    recursive_depth = config.recursive_depth || 1
    
    case recursive_depth do
      1 -> :autonomous_governance
      2 -> :supervised_governance
      _ -> :constrained_governance
    end
  end
  
  defp derive_capabilities(config) do
    base_capabilities = [
      "vsm_scan_environment",
      "vsm_synthesize_policy", 
      "vsm_allocate_resources",
      "vsm_check_viability"
    ]
    
    specialized_capabilities = case config.purpose do
      "policy_enforcement" ->
        ["vsm_enforce_policy", "vsm_audit_compliance"]
        
      "data_analysis" ->
        ["vsm_analyze_data", "vsm_generate_insights"]
        
      "resource_management" ->
        ["vsm_optimize_resources", "vsm_forecast_demand"]
        
      _ ->
        []
    end
    
    base_capabilities ++ specialized_capabilities ++ (config.capabilities || [])
  end
  
  defp get_available_port do
    # Find an available port for MCP server
    case :gen_tcp.listen(0, []) do
      {:ok, socket} ->
        {:ok, port} = :inet.port(socket)
        :gen_tcp.close(socket)
        port
        
      {:error, _} ->
        # Fallback to random port in range
        4000 + :rand.uniform(1000)
    end
  end
  
  # Utility functions
  
  defp validate_spawn_config(config) do
    required_fields = [:identity, :purpose]
    
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(config, field) or is_nil(Map.get(config, field))
    end)
    
    case missing_fields do
      [] ->
        # Check recursive depth limit
        depth = config.recursive_depth || 1
        if depth > @max_recursive_depth do
          {:error, "Maximum recursive depth exceeded: #{depth}"}
        else
          :ok
        end
        
      fields ->
        {:error, "Missing required fields: #{inspect(fields)}"}
    end
  end
  
  defp generate_spawn_id do
    "SPAWN_#{:erlang.unique_integer([:positive])}"
  end
  
  defp terminate_vsm_process(vsm_info) do
    Logger.info("🔚 Terminating VSM process: #{vsm_info.identity}")
    
    try do
      # Gracefully shutdown systems
      Enum.each(vsm_info.systems, fn {_system, pid} ->
        if Process.alive?(pid) do
          Process.exit(pid, :shutdown)
        end
      end)
      
      # Stop MCP server
      if Process.alive?(vsm_info.mcp_server) do
        Process.exit(vsm_info.mcp_server, :shutdown)
      end
      
      # Stop supervisor
      if Process.alive?(vsm_info.supervisor) do
        DynamicSupervisor.stop(vsm_info.supervisor)
      end
      
      :ok
      
    rescue
      error ->
        Logger.error("❌ Error terminating VSM: #{inspect(error)}")
        {:error, inspect(error)}
    end
  end
  
  defp find_vsm_by_pid(pid, spawned_vsms) do
    Enum.find(spawned_vsms, fn {_id, vsm_info} ->
      vsm_info.supervisor == pid or
      Enum.any?(Map.values(vsm_info.systems), & &1 == pid) or
      vsm_info.mcp_server == pid
    end)
  end
  
  defp analyze_variety_for_spawning(variety_data, _state) do
    # Analyze if the variety explosion requires spawning a new VSM
    variety_score = calculate_variety_score(variety_data)
    capacity_utilization = calculate_capacity_utilization(variety_data)
    
    spawn_recommendation = cond do
      variety_score > 0.8 and capacity_utilization > 0.9 ->
        {:recommend_spawn, "High variety with near-capacity utilization"}
        
      variety_score > 0.9 ->
        {:recommend_spawn, "Extreme variety explosion detected"}
        
      capacity_utilization > 0.95 ->
        {:recommend_spawn, "System at maximum capacity"}
        
      true ->
        {:no_spawn_needed, "System within normal parameters"}
    end
    
    %{
      variety_score: variety_score,
      capacity_utilization: capacity_utilization,
      recommendation: spawn_recommendation,
      analysis_timestamp: DateTime.utc_now()
    }
  end
  
  defp calculate_variety_score(variety_data) do
    # Calculate variety score based on complexity, novelty, and volume
    complexity = Map.get(variety_data, :complexity, 0.5)
    novelty = Map.get(variety_data, :novelty, 0.5)
    volume = Map.get(variety_data, :volume, 0.5)
    
    (complexity * 0.4) + (novelty * 0.4) + (volume * 0.2)
  end
  
  defp calculate_capacity_utilization(variety_data) do
    # Calculate current system capacity utilization
    cpu_usage = Map.get(variety_data, :cpu_usage, 0.5)
    memory_usage = Map.get(variety_data, :memory_usage, 0.5)
    queue_depth = Map.get(variety_data, :queue_depth, 0.5)
    
    (cpu_usage * 0.4) + (memory_usage * 0.3) + (queue_depth * 0.3)
  end
  
  defp load_spawn_templates do
    # Load predefined spawn templates for common scenarios
    %{
      policy_enforcement: %{
        purpose: "policy_enforcement",
        systems: %{
          s1: %{contexts: [:policy_context]},
          s3: %{resource_scope: :policy_resources},
          s4: %{intelligence_domain: :policy_intelligence},
          s5: %{governance_model: :policy_governance}
        }
      },
      data_analysis: %{
        purpose: "data_analysis", 
        systems: %{
          s1: %{contexts: [:analytics_context]},
          s3: %{resource_scope: :compute_resources},
          s4: %{intelligence_domain: :data_intelligence},
          s5: %{governance_model: :analytical_governance}
        }
      },
      resource_management: %{
        purpose: "resource_management",
        systems: %{
          s1: %{contexts: [:resource_context]},
          s3: %{resource_scope: :all_resources},
          s4: %{intelligence_domain: :resource_intelligence},
          s5: %{governance_model: :resource_governance}
        }
      }
    }
  end
end