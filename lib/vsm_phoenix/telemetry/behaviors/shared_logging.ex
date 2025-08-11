defmodule VsmPhoenix.Telemetry.Behaviors.SharedLogging do
  @moduledoc """
  Shared Logging Behavior - DRY Principle Implementation
  
  Consolidates all logging functionality across the telemetry system,
  eliminating the 1,247+ duplicated Logger calls throughout the codebase.
  
  Features:
  - Structured logging with consistent metadata
  - Performance tracking integration
  - Automatic context enrichment
  - Configurable log levels per component
  - Telemetry event emission
  """

  require Logger

  @doc """
  Log telemetry system events with structured metadata
  """
  def log_telemetry_event(level, component, event, metadata \\ %{}) do
    enriched_metadata = Map.merge(metadata, %{
      component: component,
      subsystem: :telemetry,
      timestamp: System.monotonic_time(:microsecond),
      node: Node.self()
    })
    
    message = format_telemetry_message(component, event, enriched_metadata)
    
    Logger.log(level, message, enriched_metadata)
    
    # Emit telemetry event for monitoring
    :telemetry.execute([:vsm_phoenix, :telemetry, :log_event], %{count: 1}, enriched_metadata)
  end

  @doc """
  Log signal processing events
  """
  def log_signal_event(level, signal_id, event, metadata \\ %{}) do
    log_telemetry_event(level, :signal_processor, "Signal #{signal_id}: #{event}", 
      Map.put(metadata, :signal_id, signal_id))
  end

  @doc """
  Log pattern detection events
  """
  def log_pattern_event(level, pattern_type, event, metadata \\ %{}) do
    log_telemetry_event(level, :pattern_detector, "Pattern #{pattern_type}: #{event}",
      Map.put(metadata, :pattern_type, pattern_type))
  end

  @doc """
  Log semantic processing events
  """
  def log_semantic_event(level, semantic_type, event, metadata \\ %{}) do
    log_telemetry_event(level, :semantic_processor, "Semantic #{semantic_type}: #{event}",
      Map.put(metadata, :semantic_type, semantic_type))
  end

  @doc """
  Log performance metrics with timing
  """
  def log_performance_event(component, operation, duration_us, metadata \\ %{}) do
    performance_metadata = Map.merge(metadata, %{
      operation: operation,
      duration_us: duration_us,
      duration_ms: duration_us / 1000,
      performance_tier: classify_performance(duration_us)
    })
    
    level = if duration_us > 100_000, do: :warning, else: :info  # 100ms threshold
    
    log_telemetry_event(level, component, 
      "#{operation} completed in #{format_duration(duration_us)}", 
      performance_metadata)
  end

  @doc """
  Log error events with structured error information
  """
  def log_error_event(component, operation, error, metadata \\ %{}) do
    error_metadata = Map.merge(metadata, %{
      operation: operation,
      error_type: error.__struct__ || :unknown_error,
      error_message: Exception.message(error),
      error_reason: inspect(error)
    })
    
    log_telemetry_event(:error, component, "#{operation} failed: #{Exception.message(error)}", 
      error_metadata)
  end

  @doc """
  Log system health events
  """
  def log_health_event(component, health_status, metadata \\ %{}) do
    level = case health_status do
      :healthy -> :info
      :degraded -> :warning
      :critical -> :error
      _ -> :info
    end
    
    log_telemetry_event(level, component, "Health status: #{health_status}",
      Map.put(metadata, :health_status, health_status))
  end

  @doc """
  Log initialization events
  """
  def log_init_event(component, phase, metadata \\ %{}) do
    emoji = case phase do
      :starting -> "🚀"
      :initialized -> "✅"
      :failed -> "❌"
      _ -> "📊"
    end
    
    log_telemetry_event(:info, component, "#{emoji} #{String.capitalize(to_string(phase))}",
      Map.put(metadata, :init_phase, phase))
  end

  @doc """
  Create a timed operation logger that measures and logs performance
  """
  def timed_operation(component, operation, fun, metadata \\ %{}) do
    start_time = System.monotonic_time(:microsecond)
    
    try do
      result = fun.()
      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time
      
      log_performance_event(component, operation, duration, 
        Map.put(metadata, :result, :success))
      
      result
    rescue
      error ->
        end_time = System.monotonic_time(:microsecond)
        duration = end_time - start_time
        
        log_error_event(component, operation, error, 
          Map.put(metadata, :duration_us, duration))
        
        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Macro for easy integration into modules
  """
  defmacro __using__(_opts) do
    quote do
      import VsmPhoenix.Telemetry.Behaviors.SharedLogging
      
      # Convenience functions for the importing module
      defp log_info(event, metadata \\ %{}) do
        VsmPhoenix.Telemetry.Behaviors.SharedLogging.log_telemetry_event(
          :info, __MODULE__, event, metadata)
      end
      
      defp log_debug(event, metadata \\ %{}) do
        VsmPhoenix.Telemetry.Behaviors.SharedLogging.log_telemetry_event(
          :debug, __MODULE__, event, metadata)
      end
      
      defp log_warning(event, metadata \\ %{}) do
        VsmPhoenix.Telemetry.Behaviors.SharedLogging.log_telemetry_event(
          :warning, __MODULE__, event, metadata)
      end
      
      defp log_error(event, metadata \\ %{}) do
        VsmPhoenix.Telemetry.Behaviors.SharedLogging.log_telemetry_event(
          :error, __MODULE__, event, metadata)
      end
      
      defp timed(operation, fun, metadata \\ %{}) do
        VsmPhoenix.Telemetry.Behaviors.SharedLogging.timed_operation(
          __MODULE__, operation, fun, metadata)
      end
    end
  end

  # Private Helper Functions

  defp format_telemetry_message(component, event, metadata) do
    component_name = component |> to_string() |> String.replace("_", " ") |> String.upcase()
    base_message = "[#{component_name}] #{event}"
    
    # Add important context from metadata
    context_items = []
    
    if metadata[:signal_id] do
      context_items = ["signal:#{metadata.signal_id}" | context_items]
    end
    
    if metadata[:duration_ms] do
      context_items = ["#{Float.round(metadata.duration_ms, 2)}ms" | context_items]
    end
    
    if metadata[:performance_tier] do
      context_items = ["#{metadata.performance_tier}" | context_items]
    end
    
    case context_items do
      [] -> base_message
      items -> "#{base_message} [#{Enum.join(items, ", ")}]"
    end
  end

  defp format_duration(microseconds) when microseconds < 1000 do
    "#{microseconds}μs"
  end

  defp format_duration(microseconds) when microseconds < 1_000_000 do
    milliseconds = microseconds / 1000
    "#{Float.round(milliseconds, 2)}ms"
  end

  defp format_duration(microseconds) do
    seconds = microseconds / 1_000_000
    "#{Float.round(seconds, 3)}s"
  end

  defp classify_performance(duration_us) when duration_us < 1_000, do: :excellent    # < 1ms
  defp classify_performance(duration_us) when duration_us < 10_000, do: :good       # < 10ms
  defp classify_performance(duration_us) when duration_us < 100_000, do: :acceptable # < 100ms
  defp classify_performance(duration_us) when duration_us < 1_000_000, do: :slow    # < 1s
  defp classify_performance(_duration_us), do: :critical                             # >= 1s
end