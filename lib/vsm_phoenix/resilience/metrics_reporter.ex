defmodule VsmPhoenix.Resilience.MetricsReporter do
  @moduledoc """
  Live metrics reporter for resilience patterns.
  Periodically publishes metrics to PubSub for dashboard consumption.
  """

  use GenServer
  require Logger

  # Publish every 5 seconds
  @publish_interval 5_000

  defstruct timer: nil,
            subscribers: MapSet.new()

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Subscribe to metrics updates
  """
  def subscribe do
    Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "resilience_metrics")
  end

  @doc """
  Unsubscribe from metrics updates
  """
  def unsubscribe do
    Phoenix.PubSub.unsubscribe(VsmPhoenix.PubSub, "resilience_metrics")
  end

  @doc """
  Force immediate metrics broadcast
  """
  def broadcast_now do
    GenServer.cast(__MODULE__, :broadcast_metrics)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Attach telemetry handlers
    VsmPhoenix.Resilience.Telemetry.attach_handlers()

    # Schedule first broadcast
    timer = Process.send_after(self(), :broadcast_metrics, @publish_interval)

    Logger.info("📊 Resilience Metrics Reporter started")

    {:ok, %__MODULE__{timer: timer}}
  end

  @impl true
  def handle_info(:broadcast_metrics, state) do
    broadcast_metrics()

    # Schedule next broadcast
    timer = Process.send_after(self(), :broadcast_metrics, @publish_interval)

    {:noreply, %{state | timer: timer}}
  end

  @impl true
  def handle_cast(:broadcast_metrics, state) do
    broadcast_metrics()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    VsmPhoenix.Resilience.Telemetry.detach_handlers()
    :ok
  end

  # Private Functions

  defp broadcast_metrics do
    metrics = collect_all_metrics()

    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "resilience_metrics",
      {:resilience_metrics, metrics}
    )
  end

  defp collect_all_metrics do
    %{
      timestamp: DateTime.utc_now(),
      circuit_breakers: collect_circuit_breaker_metrics(),
      bulkheads: collect_bulkhead_metrics(),
      amqp_connection: collect_amqp_metrics(),
      http_clients: collect_http_client_metrics(),
      health_status: collect_health_status()
    }
  end

  defp collect_circuit_breaker_metrics do
    breakers = [
      {VsmPhoenix.AMQP.ConnectionManager_CircuitBreaker, "AMQP Connection"},
      {:http_client_hermes_client_CircuitBreaker, "Hermes Client"},
      {:http_client_external_api_client_CircuitBreaker, "External API Client"}
    ]

    Map.new(breakers, fn {breaker, name} ->
      metrics =
        try do
          state = VsmPhoenix.Resilience.CircuitBreaker.get_state(breaker)

          %{
            state: state.state,
            failure_count: state.failure_count,
            success_count: state.success_count,
            last_failure_time: state.last_failure_time,
            available: true
          }
        catch
          _, _ -> %{available: false}
        end

      {name, metrics}
    end)
  end

  defp collect_bulkhead_metrics do
    bulkheads = [
      {:bulkhead_amqp_channels, "AMQP Channels"},
      {:bulkhead_http_connections, "HTTP Connections"},
      {:bulkhead_llm_requests, "LLM Requests"}
    ]

    Map.new(bulkheads, fn {bulkhead, name} ->
      metrics =
        try do
          state = VsmPhoenix.Resilience.Bulkhead.get_state(bulkhead)
          metrics = VsmPhoenix.Resilience.Bulkhead.get_metrics(bulkhead)

          %{
            available: state.available,
            busy: state.busy,
            waiting: state.waiting,
            max_concurrent: state.max_concurrent,
            max_waiting: state.max_waiting,
            utilization_percent: Float.round(state.busy / state.max_concurrent * 100, 1),
            total_checkouts: metrics.total_checkouts,
            successful_checkouts: metrics.successful_checkouts,
            rejected_checkouts: metrics.rejected_checkouts,
            timeouts: metrics.timeouts,
            current_usage: metrics.current_usage,
            peak_usage: metrics.peak_usage,
            queue_size: metrics.queue_size,
            peak_queue_size: metrics.peak_queue_size,
            status: :available
          }
        catch
          _, _ -> %{status: :unavailable}
        end

      {name, metrics}
    end)
  end

  defp collect_amqp_metrics do
    try do
      health = VsmPhoenix.AMQP.ConnectionManager.health_check()
      metrics = VsmPhoenix.AMQP.ConnectionManager.get_metrics()

      Map.merge(health, %{
        connection_attempts: metrics.connection_attempts,
        successful_connections: metrics.successful_connections,
        failed_connections: metrics.failed_connections,
        circuit_breaker_trips: metrics.circuit_breaker_trips
      })
    catch
      _, _ -> %{status: :unavailable}
    end
  end

  defp collect_http_client_metrics do
    clients = [
      {:http_client_hermes_client, "Hermes Client"},
      {:http_client_external_api_client, "External API Client"}
    ]

    Map.new(clients, fn {client, name} ->
      metrics =
        try do
          client_metrics = VsmPhoenix.Resilience.ResilientHTTPClient.get_metrics(client)
          circuit_state = VsmPhoenix.Resilience.ResilientHTTPClient.get_circuit_state(client)

          Map.merge(client_metrics, %{
            circuit_breaker: circuit_state,
            status: :available
          })
        catch
          _, _ -> %{status: :unavailable}
        end

      {name, metrics}
    end)
  end

  defp collect_health_status do
    try do
      VsmPhoenix.Resilience.HealthMonitor.get_health()
    catch
      _, _ -> %{status: :unavailable}
    end
  end
end
