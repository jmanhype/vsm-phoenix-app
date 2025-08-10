defmodule VsmPhoenix.System5.AlgedonicSignals do
  @moduledoc """
  Simple interface for emitting algedonic signals (pain/pleasure) throughout VSM.
  
  This is a convenience module that delegates to the more complex AlgedonicProcessor
  component while providing a simple API for other modules.
  """

  alias VsmPhoenix.System5.Components.AlgedonicProcessor

  @doc """
  Emit an algedonic signal to the VSM system.
  
  Signal format:
  - {:pain, intensity: 0.0-1.0, context: map}
  - {:pleasure, intensity: 0.0-1.0, context: map}  
  - {:neutral, intensity: 0.0-1.0, context: map}
  
  Examples:
      iex> AlgedonicSignals.emit_signal({:pain, intensity: 0.8, context: :telegram_api_failure})
      :ok
      
      iex> AlgedonicSignals.emit_signal({:pleasure, intensity: 0.6, context: :circuit_breaker_recovered})
      :ok
  """
  def emit_signal(signal) do
    case signal do
      {:pain, intensity: intensity, context: context} ->
        AlgedonicProcessor.send_pain_signal(intensity, context)
        
      {:pleasure, intensity: intensity, context: context} ->
        AlgedonicProcessor.send_pleasure_signal(intensity, context)
        
      {:neutral, intensity: intensity, context: context} ->
        # Neutral signals are treated as very low intensity pleasure
        # (system functioning normally)
        AlgedonicProcessor.send_pleasure_signal(intensity * 0.1, context)
        
      # Handle legacy tuple format
      {:pain, intensity, context} when is_number(intensity) ->
        AlgedonicProcessor.send_pain_signal(intensity, context)
        
      {:pleasure, intensity, context} when is_number(intensity) ->
        AlgedonicProcessor.send_pleasure_signal(intensity, context)
        
      {:neutral, intensity, context} when is_number(intensity) ->
        AlgedonicProcessor.send_pleasure_signal(intensity * 0.1, context)
        
      # Handle structured signal with data
      {signal_type, intensity: intensity, context: context, data: data} ->
        enriched_context = if is_map(context) do
          Map.put(context, :additional_data, data)
        else
          %{original_context: context, additional_data: data}
        end
        
        emit_signal({signal_type, intensity: intensity, context: enriched_context})
        
      _ ->
        require Logger
        Logger.warning("Unknown algedonic signal format: #{inspect(signal)}")
        :error
    end
    
    :ok
  rescue
    error ->
      require Logger
      Logger.error("Failed to emit algedonic signal #{inspect(signal)}: #{inspect(error)}")
      :error
  end

  @doc """
  Get current algedonic state of the system.
  """
  def get_current_state() do
    case Process.whereis(AlgedonicProcessor) do
      nil -> 
        {:error, :algedonic_processor_not_started}
      _pid ->
        AlgedonicProcessor.get_algedonic_state()
    end
  end

  @doc """
  Get recent signal history.
  """
  def get_signal_history(limit \\ 50) do
    case Process.whereis(AlgedonicProcessor) do
      nil -> 
        {:error, :algedonic_processor_not_started}
      _pid ->
        AlgedonicProcessor.get_signal_history(limit)
    end
  end

  @doc """
  Analyze current signal patterns.
  """
  def analyze_patterns() do
    case Process.whereis(AlgedonicProcessor) do
      nil -> 
        {:error, :algedonic_processor_not_started}
      _pid ->
        AlgedonicProcessor.analyze_signal_patterns()
    end
  end

  # Convenience functions for common signals

  def emit_pain(intensity, context \\ %{}) do
    emit_signal({:pain, intensity: intensity, context: context})
  end

  def emit_pleasure(intensity, context \\ %{}) do
    emit_signal({:pleasure, intensity: intensity, context: context})
  end

  def emit_success(intensity \\ 0.7, context \\ %{}) do
    emit_signal({:pleasure, intensity: intensity, context: Map.put(context, :type, :success)})
  end

  def emit_failure(intensity \\ 0.8, context \\ %{}) do
    emit_signal({:pain, intensity: intensity, context: Map.put(context, :type, :failure)})
  end

  def emit_recovery(intensity \\ 0.6, context \\ %{}) do
    emit_signal({:pleasure, intensity: intensity, context: Map.put(context, :type, :recovery)})
  end

  def emit_degradation(intensity \\ 0.5, context \\ %{}) do
    emit_signal({:pain, intensity: intensity, context: Map.put(context, :type, :degradation)})
  end
end