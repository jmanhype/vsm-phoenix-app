defmodule VsmPhoenix.System5.Behaviors.ViabilityEvaluator do
  @moduledoc """
  Behavior for Viability Evaluation in VSM System 5.
  
  Defines the contract for system viability assessment and monitoring
  to ensure consistent implementation across different evaluators.
  
  Follows Interface Segregation Principle by focusing only on viability concerns.
  """
  
  @type viability_data :: map()
  @type viability_index :: float()  # 0.0 to 1.0
  @type intervention_type :: :emergency | :urgent | :maintenance | :preventive
  @type system_metrics :: map()
  
  @doc """
  Evaluate overall system viability.
  
  Assesses the current health and sustainability of the entire VSM system.
  
  ## Returns
  - {:ok, viability_data} with comprehensive viability assessment
  - {:error, reason} on evaluation failure
  """
  @callback evaluate_viability() :: {:ok, viability_data()} | {:error, term()}
  
  @doc """
  Calculate viability index from system metrics.
  
  ## Parameters
  - current_metrics: Current system performance metrics
  - historical_data: Historical data for trend analysis
  
  ## Returns
  - {:ok, viability_index} value between 0.0 (critical) and 1.0 (optimal)
  - {:error, reason} on calculation failure
  """
  @callback calculate_viability_index(system_metrics(), map()) :: {:ok, viability_index()} | {:error, term()}
  
  @doc """
  Check if system requires immediate intervention.
  
  ## Returns
  - {:ok, intervention_type} if intervention is needed
  - {:ok, :none} if system is stable
  - {:error, reason} on check failure
  """
  @callback requires_intervention() :: {:ok, intervention_type() | :none} | {:error, term()}
  
  @doc """
  Initiate health intervention based on viability assessment.
  
  ## Parameters
  - viability_data: Current viability assessment data
  
  ## Returns
  - :ok on successful intervention initiation
  - {:error, reason} on intervention failure
  """
  @callback initiate_intervention(viability_data()) :: :ok | {:error, term()}
  
  @doc """
  Get viability trends over time.
  
  ## Parameters
  - time_window: Time window for trend analysis in milliseconds
  
  ## Returns
  - {:ok, trends} with trend analysis data
  - {:error, reason} on analysis failure
  """
  @callback get_viability_trends(integer()) :: {:ok, map()} | {:error, term()}
  
  @doc """
  Calculate system resilience score.
  
  Measures how well the system can maintain viability under stress.
  
  ## Returns
  - {:ok, resilience_score} value between 0.0 and 1.0
  - {:error, reason} on calculation failure
  """
  @callback calculate_resilience_score() :: {:ok, float()} | {:error, term()}
  
  @doc """
  Predict future viability based on current trends.
  
  ## Parameters
  - prediction_horizon: How far ahead to predict (milliseconds)
  
  ## Returns
  - {:ok, predicted_viability} future viability prediction
  - {:error, reason} on prediction failure
  """
  @callback predict_viability(integer()) :: {:ok, viability_data()} | {:error, term()}
  
  @doc """
  Get viability assessment metrics and statistics.
  
  ## Returns
  - {:ok, metrics} viability evaluation performance metrics
  - {:error, reason} on failure
  """
  @callback get_evaluation_metrics() :: {:ok, map()} | {:error, term()}
  
  @optional_callbacks [
    get_viability_trends: 1,
    calculate_resilience_score: 0,
    predict_viability: 1,
    get_evaluation_metrics: 0
  ]
end