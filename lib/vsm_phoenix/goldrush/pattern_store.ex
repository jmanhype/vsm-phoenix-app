defmodule VsmPhoenix.Goldrush.PatternStore do
  @moduledoc """
  Pattern Storage and Retrieval for GoldRush
  
  Supports:
  - Pattern persistence in ETS and disk
  - JSON/YAML configuration loading
  - Dynamic pattern updates
  - Pattern versioning and history
  """
  
  use GenServer
  require Logger
  
  @name __MODULE__
  @table_name :goldrush_patterns
  @pattern_dir "priv/goldrush/patterns"
  @autosave_interval 60_000  # 1 minute
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Save a pattern to the store
  """
  def save_pattern(pattern) do
    GenServer.call(@name, {:save_pattern, pattern})
  end
  
  @doc """
  Load a pattern by ID
  """
  def get_pattern(pattern_id) do
    GenServer.call(@name, {:get_pattern, pattern_id})
  end
  
  @doc """
  Load all patterns
  """
  def load_all_patterns do
    GenServer.call(@name, :load_all_patterns)
  end
  
  @doc """
  Delete a pattern
  """
  def delete_pattern(pattern_id) do
    GenServer.call(@name, {:delete_pattern, pattern_id})
  end
  
  @doc """
  Import patterns from a JSON or YAML file
  """
  def import_patterns_from_file(file_path) do
    GenServer.call(@name, {:import_patterns, file_path})
  end
  
  @doc """
  Export patterns to a file
  """
  def export_patterns_to_file(file_path, format \\ :json) do
    GenServer.call(@name, {:export_patterns, file_path, format})
  end
  
  @doc """
  Update a pattern dynamically
  """
  def update_pattern(pattern_id, updates) do
    GenServer.call(@name, {:update_pattern, pattern_id, updates})
  end
  
  @doc """
  Get pattern history/versions
  """
  def get_pattern_history(pattern_id) do
    GenServer.call(@name, {:get_pattern_history, pattern_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("📁 Initializing GoldRush Pattern Store")
    
    # Create ETS table for fast access
    :ets.new(@table_name, [:set, :public, :named_table, {:read_concurrency, true}])
    
    # Ensure pattern directory exists
    File.mkdir_p!(@pattern_dir)
    
    # Load patterns from disk
    patterns = load_patterns_from_disk()
    
    # Populate ETS
    Enum.each(patterns, fn pattern ->
      :ets.insert(@table_name, {pattern.id, pattern})
    end)
    
    # Schedule periodic autosave
    Process.send_after(self(), :autosave, @autosave_interval)
    
    state = %{
      patterns: patterns,
      pattern_history: %{},  # pattern_id => [versions]
      last_save: System.system_time(:second)
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:save_pattern, pattern}, _from, state) do
    pattern_with_metadata = add_metadata(pattern)
    
    # Save to ETS
    :ets.insert(@table_name, {pattern.id, pattern_with_metadata})
    
    # Update state
    new_patterns = Map.put(state.patterns, pattern.id, pattern_with_metadata)
    
    # Add to history
    new_history = add_to_history(state.pattern_history, pattern.id, pattern_with_metadata)
    
    # Save to disk immediately for important patterns
    if Map.get(pattern, :critical, false) do
      save_pattern_to_disk(pattern_with_metadata)
    end
    
    {:reply, :ok, %{state | 
      patterns: new_patterns,
      pattern_history: new_history
    }}
  end
  
  @impl true
  def handle_call({:get_pattern, pattern_id}, _from, state) do
    case :ets.lookup(@table_name, pattern_id) do
      [{^pattern_id, pattern}] -> {:reply, {:ok, pattern}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call(:load_all_patterns, _from, state) do
    patterns = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, pattern} -> pattern end)
    
    {:reply, {:ok, patterns}, state}
  end
  
  @impl true
  def handle_call({:delete_pattern, pattern_id}, _from, state) do
    # Delete from ETS
    :ets.delete(@table_name, pattern_id)
    
    # Update state
    new_patterns = Map.delete(state.patterns, pattern_id)
    
    # Mark as deleted in history
    new_history = mark_as_deleted(state.pattern_history, pattern_id)
    
    # Delete from disk
    delete_pattern_from_disk(pattern_id)
    
    {:reply, :ok, %{state | 
      patterns: new_patterns,
      pattern_history: new_history
    }}
  end
  
  @impl true
  def handle_call({:import_patterns, file_path}, _from, state) do
    case import_patterns_from_file_impl(file_path) do
      {:ok, patterns} ->
        # Save all imported patterns
        new_state = Enum.reduce(patterns, state, fn pattern, acc_state ->
          pattern_with_metadata = add_metadata(pattern)
          :ets.insert(@table_name, {pattern.id, pattern_with_metadata})
          
          %{acc_state |
            patterns: Map.put(acc_state.patterns, pattern.id, pattern_with_metadata),
            pattern_history: add_to_history(acc_state.pattern_history, pattern.id, pattern_with_metadata)
          }
        end)
        
        {:reply, {:ok, length(patterns)}, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:export_patterns, file_path, format}, _from, state) do
    patterns = Map.values(state.patterns)
    
    result = case format do
      :json -> export_as_json(patterns, file_path)
      :yaml -> export_as_yaml(patterns, file_path)
      _ -> {:error, :unsupported_format}
    end
    
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:update_pattern, pattern_id, updates}, _from, state) do
    case Map.get(state.patterns, pattern_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
        
      existing_pattern ->
        # Merge updates
        updated_pattern = Map.merge(existing_pattern, updates)
        |> Map.put(:updated_at, DateTime.utc_now())
        |> Map.put(:version, (existing_pattern[:version] || 0) + 1)
        
        # Save to ETS
        :ets.insert(@table_name, {pattern_id, updated_pattern})
        
        # Update state
        new_patterns = Map.put(state.patterns, pattern_id, updated_pattern)
        new_history = add_to_history(state.pattern_history, pattern_id, updated_pattern)
        
        {:reply, {:ok, updated_pattern}, %{state |
          patterns: new_patterns,
          pattern_history: new_history
        }}
    end
  end
  
  @impl true
  def handle_call({:get_pattern_history, pattern_id}, _from, state) do
    history = Map.get(state.pattern_history, pattern_id, [])
    {:reply, {:ok, history}, state}
  end
  
  @impl true
  def handle_info(:autosave, state) do
    Logger.debug("💾 Auto-saving patterns to disk")
    save_all_patterns_to_disk(state.patterns)
    
    # Schedule next autosave
    Process.send_after(self(), :autosave, @autosave_interval)
    
    {:noreply, %{state | last_save: System.system_time(:second)}}
  end
  
  # Private Functions
  
  defp add_metadata(pattern) do
    pattern
    |> Map.put(:created_at, DateTime.utc_now())
    |> Map.put(:version, Map.get(pattern, :version, 1))
    |> Map.put(:active, Map.get(pattern, :active, true))
  end
  
  defp add_to_history(history, pattern_id, pattern) do
    versions = Map.get(history, pattern_id, [])
    Map.put(history, pattern_id, [pattern | versions])
  end
  
  defp mark_as_deleted(history, pattern_id) do
    case Map.get(history, pattern_id) do
      nil -> history
      versions ->
        deleted_marker = %{
          id: pattern_id,
          deleted_at: DateTime.utc_now(),
          version: :deleted
        }
        Map.put(history, pattern_id, [deleted_marker | versions])
    end
  end
  
  defp load_patterns_from_disk do
    pattern_files = Path.wildcard("#{@pattern_dir}/*.json")
    
    Enum.flat_map(pattern_files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          case Jason.decode(content, keys: :atoms) do
            {:ok, pattern} -> [pattern]
            {:error, _} -> []
          end
        {:error, _} -> []
      end
    end)
    |> Map.new(fn pattern -> {pattern.id, pattern} end)
  end
  
  defp save_pattern_to_disk(pattern) do
    file_path = "#{@pattern_dir}/#{pattern.id}.json"
    
    case Jason.encode(pattern, pretty: true) do
      {:ok, json} ->
        File.write!(file_path, json)
        Logger.debug("Saved pattern #{pattern.id} to disk")
      {:error, reason} ->
        Logger.error("Failed to save pattern #{pattern.id}: #{inspect(reason)}")
    end
  end
  
  defp save_all_patterns_to_disk(patterns) do
    Enum.each(patterns, fn {_id, pattern} ->
      save_pattern_to_disk(pattern)
    end)
  end
  
  defp delete_pattern_from_disk(pattern_id) do
    file_path = "#{@pattern_dir}/#{pattern_id}.json"
    File.rm(file_path)
  end
  
  defp import_patterns_from_file_impl(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, data} <- parse_file_content(content, file_path) do
      patterns = case data do
        patterns when is_list(patterns) -> patterns
        pattern when is_map(pattern) -> [pattern]
      end
      
      validated_patterns = Enum.map(patterns, &ensure_pattern_fields/1)
      {:ok, validated_patterns}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp parse_file_content(content, file_path) do
    cond do
      String.ends_with?(file_path, ".json") ->
        Jason.decode(content, keys: :atoms)
        
      String.ends_with?(file_path, [".yaml", ".yml"]) ->
        # Would use a YAML parser here
        # For now, return error
        {:error, "YAML parsing not implemented yet"}
        
      true ->
        {:error, "Unsupported file format"}
    end
  end
  
  defp ensure_pattern_fields(pattern) do
    # Ensure pattern has required fields
    pattern
    |> Map.put_new(:id, generate_pattern_id())
    |> Map.put_new(:name, "Unnamed Pattern")
    |> Map.put_new(:conditions, [])
    |> Map.put_new(:logic, "AND")
    |> Map.put_new(:actions, [])
  end
  
  defp generate_pattern_id do
    "pattern_#{:erlang.unique_integer([:positive])}"
  end
  
  defp export_as_json(patterns, file_path) do
    case Jason.encode(patterns, pretty: true) do
      {:ok, json} ->
        case File.write(file_path, json) do
          :ok -> {:ok, length(patterns)}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp export_as_yaml(_patterns, _file_path) do
    {:error, "YAML export not implemented yet"}
  end
end