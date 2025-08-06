defmodule VsmPhoenix.Resilience.Telemetry do
  @moduledoc """
  Telemetry integration for resilience patterns.

  Emits events for:
  - Circuit breaker state changes
  - Retry attempts
  - Bulkhead usage
  - Health check results

  To attach handlers:

      :telemetry.attach_many(
        "vsm-resilience-handler",
        [
          [:vsm_phoenix, :resilience, :circuit_breaker, :state_change],
          [:vsm_phoenix, :resilience, :retry],
          [:vsm_phoenix, :resilience, :bulkhead, :checkout],
          [:vsm_phoenix, :resilience, :health_check]
        ],
        &VsmPhoenix.Resilience.Telemetry.handle_event/4,
        nil
      )
  """

  require Logger

  @doc """
  Standard telemetry event handler for resilience events
  """
  def handle_event(
        [:vsm_phoenix, :resilience, :circuit_breaker, :state_change],
        _measurements,
        metadata,
        _config
      ) do
    Logger.info(
      "⚡ Circuit breaker #{metadata.name} changed: #{metadata.old_state} → #{metadata.new_state}"
    )
  end

  def handle_event([:vsm_phoenix, :resilience, :retry], measurements, metadata, _config) do
    # Only log retries for attempts > 2 to reduce noise
    if measurements.attempt > 2 do
      Logger.info(
        "🔄 Retry attempt #{measurements.attempt} for #{metadata.operation || "operation"}"
      )
    end
  end

  def handle_event(
        [:vsm_phoenix, :resilience, :bulkhead, :checkout],
        measurements,
        metadata,
        _config
      ) do
    case metadata.result do
      :rejected ->
        Logger.warning("❌ Bulkhead #{metadata.name} rejected request (full)")

      :timeout ->
        Logger.warning("⏱️  Bulkhead #{metadata.name} checkout timeout")

      _ ->
        # Success and queued events only logged at debug level in prod
        :ok
    end
  end

  def handle_event([:vsm_phoenix, :resilience, :health_check], measurements, metadata, _config) do
    healthy = measurements.healthy_count
    degraded = measurements.degraded_count
    unhealthy = measurements.unhealthy_count
    total = healthy + degraded + unhealthy

    status_emoji =
      case metadata.status do
        :healthy -> "💚"
        :degraded -> "💛"
        :unhealthy -> "❤️"
      end

    Logger.info(
      "#{status_emoji} Health check: #{healthy}/#{total} healthy, #{degraded} degraded, #{unhealthy} unhealthy"
    )
  end

  def handle_event(
        [:vsm_phoenix, :resilience, :http_client, :request],
        measurements,
        metadata,
        _config
      ) do
    # Only log slow requests or errors
    cond do
      metadata.status == :error ->
        Logger.warning(
          "❌ HTTP #{metadata.method} #{metadata.url} failed (#{measurements.duration}ms)"
        )

      measurements.duration > 5000 ->
        Logger.info(
          "⏱️  Slow HTTP #{metadata.method} #{metadata.url} (#{measurements.duration}ms)"
        )

      true ->
        :ok
    end
  end

  @doc """
  Attach all resilience telemetry handlers
  """
  def attach_handlers do
    events = [
      [:vsm_phoenix, :resilience, :circuit_breaker, :state_change],
      [:vsm_phoenix, :resilience, :retry],
      [:vsm_phoenix, :resilience, :bulkhead, :checkout],
      [:vsm_phoenix, :resilience, :health_check],
      [:vsm_phoenix, :resilience, :http_client, :request]
    ]

    :telemetry.attach_many(
      "vsm-resilience-handler",
      events,
      &handle_event/4,
      nil
    )

    Logger.info("📊 Attached resilience telemetry handlers")
  end

  @doc """
  Detach all resilience telemetry handlers
  """
  def detach_handlers do
    :telemetry.detach("vsm-resilience-handler")
  end

  @doc """
  Get current metrics snapshot
  """
  def get_metrics_snapshot do
    %{
      circuit_breakers: get_circuit_breaker_metrics(),
      bulkheads: get_bulkhead_metrics(),
      health: get_health_metrics()
    }
  end

  defp get_circuit_breaker_metrics do
    # This would need to track circuit breakers in registry
    # For now, return empty map
    %{}
  end

  defp get_bulkhead_metrics do
    bulkheads = [
      :bulkhead_amqp_channels,
      :bulkhead_http_connections,
      :bulkhead_llm_requests
    ]

    Map.new(bulkheads, fn bulkhead ->
      try do
        metrics = VsmPhoenix.Resilience.Bulkhead.get_metrics(bulkhead)
        state = VsmPhoenix.Resilience.Bulkhead.get_state(bulkhead)

        {bulkhead,
         %{
           utilization: state.busy / state.max_concurrent * 100,
           queue_depth: state.waiting,
           total_requests: metrics.total_checkouts,
           rejected_requests: metrics.rejected_checkouts,
           timeouts: metrics.timeouts
         }}
      catch
        _, _ -> {bulkhead, %{error: "unavailable"}}
      end
    end)
  end

  defp get_health_metrics do
    try do
      VsmPhoenix.Resilience.HealthMonitor.get_health()
    catch
      _, _ -> %{error: "unavailable"}
    end
  end

  @doc """
  Export metrics in Prometheus format
  """
  def export_prometheus_metrics do
    snapshot = get_metrics_snapshot()

    lines = []

    # Bulkhead metrics
    for {bulkhead, metrics} <- snapshot.bulkheads, not Map.has_key?(metrics, :error) do
      name = Atom.to_string(bulkhead)

      [
        "# TYPE bulkhead_utilization_percent gauge",
        "bulkhead_utilization_percent{bulkhead=\"#{name}\"} #{metrics.utilization}",
        "# TYPE bulkhead_queue_depth gauge",
        "bulkhead_queue_depth{bulkhead=\"#{name}\"} #{metrics.queue_depth}",
        "# TYPE bulkhead_total_requests_total counter",
        "bulkhead_total_requests_total{bulkhead=\"#{name}\"} #{metrics.total_requests}",
        "# TYPE bulkhead_rejected_requests_total counter",
        "bulkhead_rejected_requests_total{bulkhead=\"#{name}\"} #{metrics.rejected_requests}",
        "# TYPE bulkhead_timeouts_total counter",
        "bulkhead_timeouts_total{bulkhead=\"#{name}\"} #{metrics.timeouts}"
      ]
    end
    |> List.flatten()
    |> Enum.join("\n")
  end
end
