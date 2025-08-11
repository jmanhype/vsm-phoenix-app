defmodule VsmPhoenix.Telemetry.Behaviors.AnalogSignalBehavior do
  @moduledoc """
  Shared Behavior for Analog Signal Processing - SOLID Principle Implementation
  
  This behavior defines the contract for all analog signal processing components,
  eliminating code duplication and establishing consistent interfaces across
  the telemetry system.
  
  Implements:
  - Single Responsibility: Each behavior implementation handles one concern
  - Open/Closed: Easy to extend with new signal types
  - Interface Segregation: Minimal, focused interface
  - Dependency Inversion: Depends on abstractions, not concretions
  """

  @doc """
  Process a signal sample with metadata
  Returns {:ok, processed_signal} | {:error, reason}
  """
  @callback process_sample(signal_id :: String.t(), value :: float(), metadata :: map()) :: 
    {:ok, map()} | {:error, any()}

  @doc """
  Analyze signal patterns and return insights
  """
  @callback analyze_patterns(signal_id :: String.t(), analysis_type :: atom()) :: 
    {:ok, map()} | {:error, any()}

  @doc """
  Get signal health status
  """
  @callback get_signal_health(signal_id :: String.t()) :: 
    {:ok, :healthy | :degraded | :critical} | {:error, any()}

  @doc """
  Sample signal data with buffering
  """
  @callback sample_signal(signal_id :: String.t(), value :: float(), metadata :: map()) :: 
    :ok | {:error, any()}

  @doc """
  Register a new signal for processing
  """
  @callback register_signal(signal_id :: String.t(), config :: map()) :: 
    :ok | {:error, any()}

  @doc """
  Get current signal state
  """
  @callback get_signal_state(signal_id :: String.t()) :: 
    {:ok, map()} | {:error, :not_found}

  # Default implementations for common functionality
  
  defmacro __using__(opts \\ []) do
    quote do
      @behaviour VsmPhoenix.Telemetry.Behaviors.AnalogSignalBehavior
      
      require Logger
      alias VsmPhoenix.Telemetry.Behaviors.AnalogSignalBehavior
      
      # Shared logging functionality to eliminate Logger duplication
      defp log_signal_event(level, signal_id, event, metadata \\ %{}) do
        Logger.log(level, "📊 Signal #{signal_id}: #{event}", 
          Map.merge(metadata, %{
            signal_id: signal_id,
            component: __MODULE__,
            timestamp: System.monotonic_time(:microsecond)
          })
        )
      end
      
      # Shared error handling to eliminate try/rescue duplication
      defp safe_signal_operation(signal_id, operation_name, fun) do
        try do
          result = fun.()
          log_signal_event(:debug, signal_id, "#{operation_name} completed", %{result: :success})
          result
        rescue
          error ->
            log_signal_event(:error, signal_id, "#{operation_name} failed", %{
              error: inspect(error),
              stacktrace: __STACKTRACE__
            })
            {:error, error}
        end
      end
      
      # Shared validation patterns
      defp validate_signal_id(signal_id) when is_binary(signal_id) and byte_size(signal_id) > 0, do: :ok
      defp validate_signal_id(_), do: {:error, :invalid_signal_id}
      
      defp validate_signal_value(value) when is_number(value), do: :ok
      defp validate_signal_value(_), do: {:error, :invalid_signal_value}
      
      # Shared buffer management
      defp create_circular_buffer(size) do
        :queue.new()
      end
      
      defp add_to_buffer(buffer, item, max_size) do
        new_buffer = :queue.in(item, buffer)
        if :queue.len(new_buffer) > max_size do
          {_, trimmed_buffer} = :queue.out(new_buffer)
          trimmed_buffer
        else
          new_buffer
        end
      end
      
      # Allow modules to override these defaults
      defoverridable [
        log_signal_event: 3, 
        log_signal_event: 4,
        safe_signal_operation: 3
      ]
    end
  end
end