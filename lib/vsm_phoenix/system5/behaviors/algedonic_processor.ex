defmodule VsmPhoenix.System5.Behaviors.AlgedonicProcessor do
  @moduledoc """
  Behavior for Algedonic Processing in VSM System 5.
  
  Defines the contract for processing pain and pleasure signals
  to ensure consistent implementation across different processors.
  
  This follows the Interface Segregation Principle by defining
  a focused interface only for algedonic concerns.
  """
  
  @type signal_type :: :pain | :pleasure | :neutral
  @type intensity :: float()  # 0.0 to 1.0
  @type context :: map()
  @type algedonic_state :: map()
  
  @doc """
  Send a pleasure signal to the system.
  
  ## Parameters
  - intensity: Signal strength from 0.0 (minimal) to 1.0 (maximum)
  - context: Additional context about the signal source and conditions
  
  ## Returns
  - :ok on successful processing
  - {:error, reason} on failure
  """
  @callback send_pleasure_signal(intensity(), context()) :: :ok | {:error, term()}
  
  @doc """
  Send a pain signal to the system.
  
  ## Parameters  
  - intensity: Signal strength from 0.0 (minimal) to 1.0 (maximum)
  - context: Additional context about the signal source and conditions
  
  ## Returns
  - :ok on successful processing
  - {:error, reason} on failure
  """
  @callback send_pain_signal(intensity(), context()) :: :ok | {:error, term()}
  
  @doc """
  Process a generic algedonic signal.
  
  ## Parameters
  - signal_type: The type of signal (:pain, :pleasure, :neutral)
  - intensity: Signal strength from 0.0 to 1.0
  - context: Additional context about the signal
  
  ## Returns
  - :ok on successful processing
  - {:error, reason} on failure
  """
  @callback process_signal(signal_type(), intensity(), context()) :: :ok | {:error, term()}
  
  @doc """
  Get the current algedonic state.
  
  ## Returns
  - {:ok, state} with current algedonic state data
  - {:error, reason} if state cannot be retrieved
  """
  @callback get_algedonic_state() :: {:ok, algedonic_state()} | {:error, term()}
  
  @doc """
  Check if the current state requires intervention.
  
  ## Returns
  - true if intervention is needed
  - false if system is stable
  """
  @callback requires_intervention?() :: boolean()
  
  @doc """
  Get algedonic signal history for analysis.
  
  ## Parameters
  - limit: Maximum number of signals to return (default: 100)
  
  ## Returns
  - {:ok, signals} list of recent signals
  - {:error, reason} on failure
  """
  @callback get_signal_history(limit :: integer()) :: {:ok, list()} | {:error, term()}
  
  @doc """
  Reset algedonic state to baseline (emergency function).
  
  Should only be used during critical system recovery.
  
  ## Returns
  - :ok if reset successful
  - {:error, reason} if reset fails
  """
  @callback reset_state() :: :ok | {:error, term()}
  
  @doc """
  Get performance metrics for the algedonic processor.
  
  ## Returns
  - {:ok, metrics} with processing statistics
  - {:error, reason} on failure
  """
  @callback get_metrics() :: {:ok, map()} | {:error, term()}
  
  @optional_callbacks [
    requires_intervention?: 0,
    get_signal_history: 1,
    reset_state: 0,
    get_metrics: 0
  ]
end