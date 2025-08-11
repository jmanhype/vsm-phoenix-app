defmodule VsmPhoenix.System4.Intelligence.ScannerBehaviour do
  @moduledoc """
  Behaviour contract for environmental scanning operations.
  
  Defines the interface that all environmental scanners must implement,
  enabling dependency injection and polymorphic behavior.
  """
  
  @doc """
  Performs environmental scanning based on scope and data source.
  
  ## Parameters
  - scope: :full | :partial | :targeted
  - data_source: Connection or configuration for data retrieval
  
  ## Returns
  - {:ok, scan_results} on successful scan
  - {:error, reason} on failure
  """
  @callback scan(scope :: atom(), data_source :: term()) :: 
    {:ok, scan_results :: map()} | {:error, reason :: term()}
    
  @doc """
  Analyzes raw scan results to extract meaningful insights.
  
  ## Parameters
  - results: Raw scan data from scan/2 function
  
  ## Returns
  - {:ok, analysis} with processed insights
  - {:error, reason} on analysis failure
  """
  @callback analyze_results(results :: map()) ::
    {:ok, analysis :: map()} | {:error, reason :: term()}
    
  @doc """
  Validates scan configuration and parameters.
  
  ## Parameters
  - config: Scanner configuration
  
  ## Returns
  - {:ok, validated_config} if valid
  - {:error, validation_errors} if invalid
  """
  @callback validate_config(config :: map()) ::
    {:ok, validated_config :: map()} | {:error, validation_errors :: list()}
end