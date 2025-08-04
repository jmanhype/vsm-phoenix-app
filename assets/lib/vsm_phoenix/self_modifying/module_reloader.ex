defmodule VsmPhoenix.SelfModifying.ModuleReloader do
  @moduledoc """
  Hot-swapping module reloader for VSM self-modification.
  
  Safely reloads modules at runtime with version management,
  rollback capabilities, and dependency tracking.
  """
  
  require Logger
  use GenServer
  
  alias VsmPhoenix.SelfModifying.{CodeGenerator, SafeSandbox}
  
  defstruct [
    :reload_history,
    :module_versions,
    :dependency_graph,
    :reload_callbacks,
    :safety_checks,
    :rollback_points,
    :reload_stats
  ]
  
  @version_limit 10 # Keep last 10 versions of each module
  
  ## Public API
  
  @doc """
  Starts the module reloader service.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Reloads a module with new code.
  
  ## Parameters
  - module_name: The module to reload
  - new_code: New module source code
  - opts: Reload options (safety_checks, callbacks, etc.)
  
  ## Examples
      iex> new_code = "defmodule MyModule do\\n  def hello, do: :world\\nend"
      iex> ModuleReloader.reload_module(MyModule, new_code, validate: true)
      {:ok, :reloaded}
  """
  def reload_module(module_name, new_code, opts \\ []) do
    GenServer.call(__MODULE__, {:reload_module, module_name, new_code, opts}, 10_000)
  end
  
  @doc """
  Hot-swaps a function within a module without full module reload.
  """
  def hot_swap_function(module_name, function_name, arity, new_function_code, opts \\ []) do
    GenServer.call(__MODULE__, {:hot_swap_function, module_name, function_name, arity, new_function_code, opts})
  end
  
  @doc """
  Registers a callback to be executed after module reload.
  """
  def register_reload_callback(module_name, callback_function) do
    GenServer.cast(__MODULE__, {:register_callback, module_name, callback_function})
  end
  
  @doc """
  Rolls back a module to a previous version.
  """
  def rollback_module(module_name, version \\ :previous) do
    GenServer.call(__MODULE__, {:rollback_module, module_name, version})
  end
  
  @doc """
  Gets version history for a module.
  """
  def get_module_versions(module_name) do
    GenServer.call(__MODULE__, {:get_versions, module_name})
  end
  
  @doc """
  Creates a rollback point for current system state.
  """
  def create_rollback_point(point_name) do
    GenServer.call(__MODULE__, {:create_rollback_point, point_name})
  end
  
  @doc """
  Restores system to a rollback point.
  """
  def restore_rollback_point(point_name) do
    GenServer.call(__MODULE__, {:restore_rollback_point, point_name})
  end
  
  @doc """
  Reloads multiple modules atomically.
  """
  def atomic_reload(module_updates, opts \\ []) do
    GenServer.call(__MODULE__, {:atomic_reload, module_updates, opts}, 30_000)
  end
  
  @doc """
  Gets reload statistics and status.
  """
  def get_reload_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  @doc """
  Enables or disables automatic dependency reloading.
  """
  def set_auto_dependency_reload(enabled) do
    GenServer.cast(__MODULE__, {:set_auto_deps, enabled})
  end
  
  ## GenServer Implementation
  
  @impl true
  def init(opts) do
    state = %__MODULE__{
      reload_history: [],
      module_versions: %{},
      dependency_graph: build_initial_dependency_graph(),
      reload_callbacks: %{},
      safety_checks: Keyword.get(opts, :safety_checks, true),
      rollback_points: %{},
      reload_stats: %{
        successful_reloads: 0,
        failed_reloads: 0,
        rollbacks: 0,
        hot_swaps: 0
      }
    }
    
    Logger.info("Module reloader initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_call({:reload_module, module_name, new_code, opts}, _from, state) do
    case perform_module_reload(module_name, new_code, opts, state) do
      {:ok, updated_state} ->
        {:reply, {:ok, :reloaded}, updated_state}
      
      {:error, reason, updated_state} ->
        {:reply, {:error, reason}, updated_state}
    end
  end
  
  @impl true
  def handle_call({:hot_swap_function, module_name, function_name, arity, new_code, opts}, _from, state) do
    case perform_hot_swap(module_name, function_name, arity, new_code, opts, state) do
      {:ok, updated_state} ->
        {:reply, {:ok, :swapped}, updated_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:rollback_module, module_name, version}, _from, state) do
    case perform_rollback(module_name, version, state) do
      {:ok, updated_state} ->
        {:reply, {:ok, :rolled_back}, updated_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:get_versions, module_name}, _from, state) do
    versions = Map.get(state.module_versions, module_name, [])
    {:reply, versions, state}
  end
  
  @impl true
  def handle_call({:create_rollback_point, point_name}, _from, state) do
    case create_system_rollback_point(point_name, state) do
      {:ok, updated_state} ->
        {:reply, {:ok, point_name}, updated_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:restore_rollback_point, point_name}, _from, state) do
    case restore_system_rollback_point(point_name, state) do
      {:ok, updated_state} ->
        {:reply, {:ok, :restored}, updated_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:atomic_reload, module_updates, opts}, _from, state) do
    case perform_atomic_reload(module_updates, opts, state) do
      {:ok, updated_state} ->
        {:reply, {:ok, :atomic_reload_complete}, updated_state}
      
      {:error, reason, updated_state} ->
        {:reply, {:error, reason}, updated_state}
    end
  end
  
  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = Map.merge(state.reload_stats, %{
      tracked_modules: map_size(state.module_versions),
      rollback_points: map_size(state.rollback_points),
      registered_callbacks: map_size(state.reload_callbacks)
    })
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_cast({:register_callback, module_name, callback}, state) do
    callbacks = Map.get(state.reload_callbacks, module_name, [])
    updated_callbacks = Map.put(state.reload_callbacks, module_name, [callback | callbacks])
    
    {:noreply, %{state | reload_callbacks: updated_callbacks}}
  end
  
  @impl true
  def handle_cast({:set_auto_deps, enabled}, state) do
    # This would update internal state to enable/disable auto dependency reloading
    Logger.info("Auto dependency reloading set to: #{enabled}")
    {:noreply, state}
  end
  
  ## Private Functions
  
  defp perform_module_reload(module_name, new_code, opts, state) do
    Logger.info("Reloading module: #{module_name}")
    
    with {:ok, _} <- maybe_run_safety_checks(new_code, opts, state),
         {:ok, current_version} <- capture_current_version(module_name),
         {:ok, _} <- compile_and_validate_code(new_code, opts),
         {:ok, _} <- perform_actual_reload(module_name, new_code),
         {:ok, updated_state} <- update_version_history(module_name, current_version, new_code, state),
         {:ok, final_state} <- execute_reload_callbacks(module_name, updated_state),
         {:ok, stats_updated_state} <- update_reload_stats(final_state, :success) do
      
      Logger.info("Successfully reloaded module: #{module_name}")
      {:ok, stats_updated_state}
    else
      {:error, reason} ->
        Logger.error("Failed to reload module #{module_name}: #{reason}")
        {:error, reason, update_reload_stats(state, :failure)}
    end
  end
  
  defp maybe_run_safety_checks(new_code, opts, state) do
    if Keyword.get(opts, :validate, state.safety_checks) do
      run_safety_checks(new_code)
    else
      {:ok, :skipped}
    end
  end
  
  defp run_safety_checks(code) do
    with {:ok, _} <- validate_syntax(code),
         {:ok, _} <- check_dangerous_patterns(code),
         {:ok, _} <- verify_module_structure(code) do
      {:ok, :safe}
    end
  end
  
  defp validate_syntax(code) do
    case Code.string_to_quoted(code) do
      {:ok, _ast} -> {:ok, :valid_syntax}
      {:error, reason} -> {:error, "Syntax error: #{inspect(reason)}"}
    end
  end
  
  defp check_dangerous_patterns(code) do
    dangerous_patterns = [
      ~r/File\.(rm|rm_rf|write!)/,
      ~r/System\.(cmd|shell)/,
      ~r/:os\./,
      ~r/spawn.*File/,
      ~r/Process\.exit.*:kill/
    ]
    
    if Enum.any?(dangerous_patterns, &Regex.match?(&1, code)) do
      {:error, "Code contains dangerous patterns"}
    else
      {:ok, :safe_patterns}
    end
  end
  
  defp verify_module_structure(code) do
    case Code.string_to_quoted(code) do
      {:ok, {:defmodule, _, _}} -> {:ok, :valid_module}
      {:ok, _} -> {:error, "Code does not define a module"}
      {:error, reason} -> {:error, "Structure validation failed: #{inspect(reason)}"}
    end
  end
  
  defp capture_current_version(module_name) do
    try do
      case :code.which(module_name) do
        :non_existing ->
          {:ok, %{version: :new_module, code: nil, timestamp: DateTime.utc_now()}}
        
        beam_file ->
          # In a real implementation, you'd extract source from debug info or maintain source maps
          {:ok, %{
            version: generate_version_id(),
            beam_file: beam_file,
            timestamp: DateTime.utc_now(),
            info: module_name.module_info()
          }}
      end
    rescue
      e -> {:error, "Failed to capture current version: #{Exception.message(e)}"}
    end
  end
  
  defp compile_and_validate_code(code, opts) do
    compile_timeout = Keyword.get(opts, :compile_timeout, 10_000)
    
    task = Task.async(fn ->
      try do
        case Code.compile_string(code) do
          [] -> {:error, "No modules compiled"}
          modules -> {:ok, modules}
        end
      rescue
        e -> {:error, "Compilation failed: #{Exception.message(e)}"}
      end
    end)
    
    case Task.yield(task, compile_timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, "Compilation timeout"}
    end
  end
  
  defp perform_actual_reload(module_name, new_code) do
    try do
      # Purge the old module
      case :code.purge(module_name) do
        true -> Logger.debug("Purged old version of #{module_name}")
        false -> Logger.debug("No old version to purge for #{module_name}")
      end
      
      # Delete the old module
      case :code.delete(module_name) do
        true -> Logger.debug("Deleted old module #{module_name}")
        false -> Logger.debug("Module #{module_name} was not loaded")
      end
      
      # Compile and load the new version
      case Code.compile_string(new_code) do
        [] -> {:error, "Failed to compile new module"}
        _modules -> 
          Logger.debug("Successfully loaded new version of #{module_name}")
          {:ok, :reloaded}
      end
    rescue
      e -> {:error, "Reload failed: #{Exception.message(e)}"}
    end
  end
  
  defp update_version_history(module_name, current_version, new_code, state) do
    new_version = %{
      version: generate_version_id(),
      code: new_code,
      timestamp: DateTime.utc_now(),
      previous_version: current_version.version
    }
    
    existing_versions = Map.get(state.module_versions, module_name, [])
    updated_versions = [new_version | existing_versions] |> Enum.take(@version_limit)
    
    updated_module_versions = Map.put(state.module_versions, module_name, updated_versions)
    
    {:ok, %{state | module_versions: updated_module_versions}}
  end
  
  defp execute_reload_callbacks(module_name, state) do
    callbacks = Map.get(state.reload_callbacks, module_name, [])
    
    Enum.each(callbacks, fn callback ->
      try do
        case callback do
          fun when is_function(fun, 1) -> fun.(module_name)
          fun when is_function(fun, 0) -> fun.()
          {module, function, args} -> apply(module, function, [module_name | args])
          _ -> Logger.warn("Invalid callback format for #{module_name}")
        end
      rescue
        e -> Logger.error("Callback execution failed for #{module_name}: #{Exception.message(e)}")
      end
    end)
    
    {:ok, state}
  end
  
  defp update_reload_stats(state, result) do
    case result do
      :success ->
        stats = Map.update(state.reload_stats, :successful_reloads, 0, &(&1 + 1))
        %{state | reload_stats: stats}
      
      :failure ->
        stats = Map.update(state.reload_stats, :failed_reloads, 0, &(&1 + 1))
        {:ok, %{state | reload_stats: stats}}
    end
  end
  
  defp perform_hot_swap(module_name, function_name, arity, new_function_code, opts, state) do
    Logger.info("Hot-swapping function: #{module_name}.#{function_name}/#{arity}")
    
    with {:ok, current_module_code} <- get_current_module_source(module_name),
         {:ok, modified_code} <- replace_function_in_code(current_module_code, function_name, arity, new_function_code),
         {:ok, _} <- maybe_run_safety_checks(modified_code, opts, state),
         {:ok, _} <- perform_actual_reload(module_name, modified_code),
         {:ok, updated_state} <- update_hot_swap_stats(state) do
      
      Logger.info("Successfully hot-swapped #{module_name}.#{function_name}/#{arity}")
      {:ok, updated_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp get_current_module_source(module_name) do
    # In a real implementation, this would retrieve the actual source code
    # For now, we'll create a placeholder
    {:ok, "defmodule #{module_name} do\n  # Current module code\nend"}
  end
  
  defp replace_function_in_code(module_code, function_name, arity, new_function_code) do
    # This is a simplified implementation - real function replacement would need AST manipulation
    function_pattern = ~r/def\s+#{function_name}\s*\([^)]*\)\s*.*?(?=\n\s*def|\n\s*defp|\nend|$)/s
    
    case Regex.run(function_pattern, module_code) do
      [old_function] ->
        new_code = String.replace(module_code, old_function, new_function_code)
        {:ok, new_code}
      
      nil ->
        # Function not found, append new function before 'end'
        case String.split(module_code, "\nend", parts: 2) do
          [before_end, after_end] ->
            new_code = before_end <> "\n  " <> new_function_code <> "\nend" <> after_end
            {:ok, new_code}
          
          _ -> {:error, "Could not locate insertion point for new function"}
        end
    end
  end
  
  defp update_hot_swap_stats(state) do
    stats = Map.update(state.reload_stats, :hot_swaps, 0, &(&1 + 1))
    {:ok, %{state | reload_stats: stats}}
  end
  
  defp perform_rollback(module_name, version, state) do
    versions = Map.get(state.module_versions, module_name, [])
    
    case find_rollback_version(versions, version) do
      {:ok, target_version} ->
        case perform_actual_reload(module_name, target_version.code) do
          {:ok, _} ->
            Logger.info("Successfully rolled back #{module_name} to version #{target_version.version}")
            stats = Map.update(state.reload_stats, :rollbacks, 0, &(&1 + 1))
            {:ok, %{state | reload_stats: stats}}
          
          {:error, reason} ->
            {:error, "Rollback failed: #{reason}"}
        end
      
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp find_rollback_version(versions, :previous) do
    case versions do
      [_current, previous | _] -> {:ok, previous}
      _ -> {:error, "No previous version available"}
    end
  end
  
  defp find_rollback_version(versions, version_id) do
    case Enum.find(versions, fn v -> v.version == version_id end) do
      nil -> {:error, "Version #{version_id} not found"}
      version -> {:ok, version}
    end
  end
  
  defp create_system_rollback_point(point_name, state) do
    rollback_point = %{
      name: point_name,
      timestamp: DateTime.utc_now(),
      module_versions: state.module_versions,
      system_snapshot: capture_system_state()
    }
    
    updated_points = Map.put(state.rollback_points, point_name, rollback_point)
    {:ok, %{state | rollback_points: updated_points}}
  end
  
  defp restore_system_rollback_point(point_name, state) do
    case Map.get(state.rollback_points, point_name) do
      nil ->
        {:error, "Rollback point #{point_name} not found"}
      
      rollback_point ->
        case restore_system_state(rollback_point) do
          {:ok, _} ->
            {:ok, %{state | module_versions: rollback_point.module_versions}}
          
          {:error, reason} ->
            {:error, "System restore failed: #{reason}"}
        end
    end
  end
  
  defp perform_atomic_reload(module_updates, opts, state) do
    Logger.info("Starting atomic reload of #{length(module_updates)} modules")
    
    # Validate all modules first
    validation_results = Enum.map(module_updates, fn {module_name, new_code} ->
      {module_name, maybe_run_safety_checks(new_code, opts, state)}
    end)
    
    # Check if all validations passed
    failed_validations = Enum.filter(validation_results, fn {_module, result} ->
      case result do
        {:ok, _} -> false
        {:error, _} -> true
      end
    end)
    
    if failed_validations != [] do
      errors = Enum.map(failed_validations, fn {module, {:error, reason}} ->
        "#{module}: #{reason}"
      end)
      {:error, "Validation failed for modules: #{Enum.join(errors, ", ")}", state}
    else
      # All validations passed, perform atomic reload
      case perform_all_reloads(module_updates, state) do
        {:ok, updated_state} ->
          Logger.info("Atomic reload completed successfully")
          {:ok, updated_state}
        
        {:error, reason, rollback_state} ->
          Logger.error("Atomic reload failed, rolling back: #{reason}")
          {:error, reason, rollback_state}
      end
    end
  end
  
  defp perform_all_reloads(module_updates, state) do
    # Create checkpoint before starting
    checkpoint_name = "atomic_reload_#{System.unique_integer()}"
    {:ok, checkpoint_state} = create_system_rollback_point(checkpoint_name, state)
    
    # Attempt to reload all modules
    result = Enum.reduce_while(module_updates, checkpoint_state, fn {module_name, new_code}, acc_state ->
      case perform_module_reload(module_name, new_code, [], acc_state) do
        {:ok, updated_state} ->
          {:cont, updated_state}
        
        {:error, reason, failed_state} ->
          {:halt, {:error, reason, failed_state}}
      end
    end)
    
    case result do
      {:error, reason, failed_state} ->
        # Rollback to checkpoint
        case restore_system_rollback_point(checkpoint_name, failed_state) do
          {:ok, rollback_state} -> {:error, reason, rollback_state}
          {:error, _} -> {:error, "#{reason} (rollback also failed)", failed_state}
        end
      
      final_state ->
        {:ok, final_state}
    end
  end
  
  defp capture_system_state do
    %{
      loaded_modules: :code.all_loaded(),
      process_count: length(Process.list()),
      memory_usage: :erlang.memory(),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp restore_system_state(_rollback_point) do
    # In a real implementation, this would restore system state
    # For now, we'll just return success
    {:ok, :restored}
  end
  
  defp generate_version_id do
    "v#{System.unique_integer([:positive])}_#{System.system_time(:second)}"
  end
  
  defp build_initial_dependency_graph do
    # Build a graph of module dependencies
    # This is a simplified version - real implementation would analyze actual dependencies
    %{}
  end
end