defmodule VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore do
  @moduledoc """
  Telemetry Data Store Abstraction - Separation of Concerns
  
  Provides a clean abstraction layer for telemetry data persistence,
  separating data storage concerns from business logic.
  
  This abstraction enables:
  - Easy testing with mock implementations
  - Swapping storage backends without code changes
  - Clear separation between data and processing logic
  - Dependency inversion (depend on abstractions)
  """

  @doc """
  Store signal data
  """
  @callback store_signal_data(signal_id :: String.t(), data :: map()) :: 
    :ok | {:error, any()}

  @doc """
  Retrieve signal data
  """
  @callback get_signal_data(signal_id :: String.t()) :: 
    {:ok, map()} | {:error, :not_found}

  @doc """
  Store signal analysis results
  """
  @callback store_analysis(signal_id :: String.t(), analysis :: map()) :: 
    :ok | {:error, any()}

  @doc """
  Get signal analysis results
  """
  @callback get_analysis(signal_id :: String.t(), analysis_type :: atom()) :: 
    {:ok, map()} | {:error, :not_found}

  @doc """
  Store semantic relationships
  """
  @callback store_relationship(from_signal :: String.t(), to_signal :: String.t(), 
                              relationship :: map()) :: :ok | {:error, any()}

  @doc """
  Query semantic relationships
  """
  @callback get_relationships(signal_id :: String.t()) :: 
    {:ok, [map()]} | {:error, any()}

  @doc """
  Store pattern detection results
  """
  @callback store_pattern(pattern_id :: String.t(), pattern_data :: map()) :: 
    :ok | {:error, any()}

  @doc """
  Get pattern detection results
  """
  @callback get_patterns(signal_id :: String.t()) :: 
    {:ok, [map()]} | {:error, any()}

  # Factory function for creating data store implementations
  def create(type \\ :ets) do
    case type do
      :ets -> VsmPhoenix.Telemetry.DataStores.ETSDataStore
      :crdt -> VsmPhoenix.Telemetry.DataStores.CRDTDataStore
      :memory -> VsmPhoenix.Telemetry.DataStores.MemoryDataStore
      :persistent -> VsmPhoenix.Telemetry.DataStores.PersistentDataStore
      _ -> raise ArgumentError, "Unknown data store type: #{type}"
    end
  end
end