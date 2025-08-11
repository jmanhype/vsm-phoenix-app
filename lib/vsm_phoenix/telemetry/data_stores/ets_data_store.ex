defmodule VsmPhoenix.Telemetry.DataStores.ETSDataStore do
  @moduledoc """
  ETS-based Telemetry Data Store Implementation
  
  Implements the TelemetryDataStore behavior using ETS tables for
  high-performance in-memory storage of telemetry data.
  
  Single Responsibility: Only handles ETS-based data operations
  """

  @behaviour VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  
  use GenServer
  require Logger

  @table_configs %{
    signal_data: [:set, :public, :named_table, {:write_concurrency, true}],
    signal_analysis: [:bag, :public, :named_table, {:write_concurrency, true}],
    semantic_relationships: [:bag, :public, :named_table, {:read_concurrency, true}],
    pattern_results: [:bag, :public, :named_table, {:read_concurrency, true}],
    signal_metadata: [:set, :public, :named_table, {:read_concurrency, true}]
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🗄️ Initializing ETS Telemetry Data Store")
    
    # Create ETS tables with optimized configurations
    tables = Map.new(@table_configs, fn {table_name, config} ->
      full_table_name = :"telemetry_#{table_name}"
      :ets.new(full_table_name, config)
      {table_name, full_table_name}
    end)
    
    state = %{
      tables: tables,
      stats: %{
        stores: 0,
        retrievals: 0,
        errors: 0
      }
    }
    
    {:ok, state}
  end

  # TelemetryDataStore Implementation

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def store_signal_data(signal_id, data) do
    GenServer.call(__MODULE__, {:store_signal_data, signal_id, data})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def get_signal_data(signal_id) do
    GenServer.call(__MODULE__, {:get_signal_data, signal_id})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def store_analysis(signal_id, analysis) do
    GenServer.call(__MODULE__, {:store_analysis, signal_id, analysis})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def get_analysis(signal_id, analysis_type) do
    GenServer.call(__MODULE__, {:get_analysis, signal_id, analysis_type})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def store_relationship(from_signal, to_signal, relationship) do
    GenServer.call(__MODULE__, {:store_relationship, from_signal, to_signal, relationship})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def get_relationships(signal_id) do
    GenServer.call(__MODULE__, {:get_relationships, signal_id})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def store_pattern(pattern_id, pattern_data) do
    GenServer.call(__MODULE__, {:store_pattern, pattern_id, pattern_data})
  end

  @impl VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  def get_patterns(signal_id) do
    GenServer.call(__MODULE__, {:get_patterns, signal_id})
  end

  # GenServer Callbacks

  @impl true
  def handle_call({:store_signal_data, signal_id, data}, _from, state) do
    try do
      enriched_data = Map.merge(data, %{
        signal_id: signal_id,
        stored_at: System.monotonic_time(:microsecond)
      })
      
      :ets.insert(state.tables.signal_data, {signal_id, enriched_data})
      
      new_stats = Map.update!(state.stats, :stores, &(&1 + 1))
      {:reply, :ok, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Failed to store signal data for #{signal_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:get_signal_data, signal_id}, _from, state) do
    try do
      case :ets.lookup(state.tables.signal_data, signal_id) do
        [{^signal_id, data}] -> 
          new_stats = Map.update!(state.stats, :retrievals, &(&1 + 1))
          {:reply, {:ok, data}, %{state | stats: new_stats}}
        [] -> 
          {:reply, {:error, :not_found}, state}
      end
    rescue
      error ->
        Logger.error("Failed to get signal data for #{signal_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:store_analysis, signal_id, analysis}, _from, state) do
    try do
      analysis_entry = Map.merge(analysis, %{
        signal_id: signal_id,
        analysis_id: generate_analysis_id(signal_id, analysis),
        stored_at: System.monotonic_time(:microsecond)
      })
      
      :ets.insert(state.tables.signal_analysis, {signal_id, analysis_entry})
      
      new_stats = Map.update!(state.stats, :stores, &(&1 + 1))
      {:reply, :ok, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Failed to store analysis for #{signal_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:get_analysis, signal_id, analysis_type}, _from, state) do
    try do
      analyses = :ets.lookup(state.tables.signal_analysis, signal_id)
      
      filtered_analyses = analyses
      |> Enum.map(fn {_, analysis} -> analysis end)
      |> Enum.filter(fn analysis -> 
        analysis[:type] == analysis_type or analysis[:analysis_type] == analysis_type
      end)
      
      case filtered_analyses do
        [] -> {:reply, {:error, :not_found}, state}
        [analysis | _] -> 
          new_stats = Map.update!(state.stats, :retrievals, &(&1 + 1))
          {:reply, {:ok, analysis}, %{state | stats: new_stats}}
      end
    rescue
      error ->
        Logger.error("Failed to get analysis for #{signal_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:store_relationship, from_signal, to_signal, relationship}, _from, state) do
    try do
      relationship_entry = Map.merge(relationship, %{
        from_signal: from_signal,
        to_signal: to_signal,
        relationship_id: generate_relationship_id(from_signal, to_signal),
        stored_at: System.monotonic_time(:microsecond)
      })
      
      :ets.insert(state.tables.semantic_relationships, {from_signal, relationship_entry})
      
      new_stats = Map.update!(state.stats, :stores, &(&1 + 1))
      {:reply, :ok, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Failed to store relationship #{from_signal} -> #{to_signal}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:get_relationships, signal_id}, _from, state) do
    try do
      relationships = :ets.lookup(state.tables.semantic_relationships, signal_id)
      |> Enum.map(fn {_, relationship} -> relationship end)
      
      new_stats = Map.update!(state.stats, :retrievals, &(&1 + 1))
      {:reply, {:ok, relationships}, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Failed to get relationships for #{signal_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:store_pattern, pattern_id, pattern_data}, _from, state) do
    try do
      pattern_entry = Map.merge(pattern_data, %{
        pattern_id: pattern_id,
        stored_at: System.monotonic_time(:microsecond)
      })
      
      signal_id = pattern_data[:signal_id] || pattern_id
      :ets.insert(state.tables.pattern_results, {signal_id, pattern_entry})
      
      new_stats = Map.update!(state.stats, :stores, &(&1 + 1))
      {:reply, :ok, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Failed to store pattern #{pattern_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:get_patterns, signal_id}, _from, state) do
    try do
      patterns = :ets.lookup(state.tables.pattern_results, signal_id)
      |> Enum.map(fn {_, pattern} -> pattern end)
      
      new_stats = Map.update!(state.stats, :retrievals, &(&1 + 1))
      {:reply, {:ok, patterns}, %{state | stats: new_stats}}
    rescue
      error ->
        Logger.error("Failed to get patterns for #{signal_id}: #{inspect(error)}")
        new_stats = Map.update!(state.stats, :errors, &(&1 + 1))
        {:reply, {:error, error}, %{state | stats: new_stats}}
    end
  end

  # Private Helper Functions

  defp generate_analysis_id(signal_id, analysis) do
    hash_input = "#{signal_id}_#{analysis[:type] || :unknown}_#{System.monotonic_time(:microsecond)}"
    :crypto.hash(:sha256, hash_input) |> Base.encode16(case: :lower) |> String.slice(0, 16)
  end

  defp generate_relationship_id(from_signal, to_signal) do
    hash_input = "#{from_signal}_#{to_signal}_#{System.monotonic_time(:microsecond)}"
    :crypto.hash(:sha256, hash_input) |> Base.encode16(case: :lower) |> String.slice(0, 16)
  end
end