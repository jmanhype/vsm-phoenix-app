defmodule VsmPhoenix.Telemetry.DataStores.MemoryDataStore do
  @moduledoc """
  Simple in-memory data store for telemetry data.
  
  This is a minimal implementation used as a fallback when other
  data stores are not available.
  """
  
  @behaviour VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  
  use GenServer
  
  def start_link(config \\ %{}) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end
  
  def init(config) do
    state = %{
      signals: %{},
      patterns: %{},
      config: config
    }
    {:ok, state}
  end
  
  # Behavior callbacks
  
  @impl true
  def store_signal_data(signal_id, data) do
    GenServer.call(__MODULE__, {:store_signal, signal_id, data})
  end
  
  @impl true  
  def get_signal_data(signal_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:get_signal, signal_id, options})
  end
  
  @impl true
  def query_signal_data(query) do
    GenServer.call(__MODULE__, {:query_signals, query})
  end
  
  @impl true
  def delete_signal_data(signal_id) do
    GenServer.call(__MODULE__, {:delete_signal, signal_id})
  end
  
  @impl true
  def store_pattern(pattern_id, pattern_data) do
    GenServer.call(__MODULE__, {:store_pattern, pattern_id, pattern_data})
  end
  
  @impl true
  def get_patterns(signal_id) do
    GenServer.call(__MODULE__, {:get_patterns, signal_id})
  end
  
  # Server callbacks
  
  def handle_call({:store_signal, signal_id, data}, _from, state) do
    new_signals = Map.put(state.signals, signal_id, data)
    {:reply, :ok, %{state | signals: new_signals}}
  end
  
  def handle_call({:get_signal, signal_id, _options}, _from, state) do
    case Map.get(state.signals, signal_id) do
      nil -> {:reply, {:error, :not_found}, state}
      data -> {:reply, {:ok, data}, state}
    end
  end
  
  def handle_call({:query_signals, _query}, _from, state) do
    # Simple implementation - return all signals
    {:reply, {:ok, Map.values(state.signals)}, state}
  end
  
  def handle_call({:delete_signal, signal_id}, _from, state) do
    new_signals = Map.delete(state.signals, signal_id)
    {:reply, :ok, %{state | signals: new_signals}}
  end
  
  def handle_call({:store_pattern, pattern_id, pattern_data}, _from, state) do
    new_patterns = Map.put(state.patterns, pattern_id, pattern_data)
    {:reply, :ok, %{state | patterns: new_patterns}}
  end
  
  def handle_call({:get_patterns, signal_id}, _from, state) do
    patterns = state.patterns
    |> Map.values()
    |> Enum.filter(fn pattern -> pattern[:signal_id] == signal_id end)
    
    {:reply, {:ok, patterns}, state}
  end
end