defmodule VsmPhoenix.Resilience.Supervisor do
  @moduledoc """
  Supervisor for all resilience components in VSM Phoenix.

  This supervisor manages:
  - Circuit breakers for various services
  - Bulkhead pools for resource isolation
  - Resilient HTTP clients
  - Health check services

  Uses a rest_for_one strategy to ensure dependent services
  are restarted if a core service fails.
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("🛡️  Starting VSM Resilience Supervisor")

    children = [
      # Health Monitor - monitors all resilience components
      {VsmPhoenix.Resilience.HealthMonitor, []},

      # Metrics Reporter - publishes metrics to PubSub
      {VsmPhoenix.Resilience.MetricsReporter, []},

      # Circuit breakers for various services - each needs unique ID
      Supervisor.child_spec(
        {VsmPhoenix.Resilience.CircuitBreaker, 
          name: :external_api_breaker,
          failure_threshold: 5,
          success_threshold: 3,
          timeout: 30_000
        },
        id: :external_api_breaker
      ),
      Supervisor.child_spec(
        {VsmPhoenix.Resilience.CircuitBreaker,
          name: :llm_api_breaker,
          failure_threshold: 3,
          success_threshold: 2,
          timeout: 60_000
        },
        id: :llm_api_breaker
      ),
      Supervisor.child_spec(
        {VsmPhoenix.Resilience.CircuitBreaker,
          name: :amqp_breaker,
          failure_threshold: 5,
          success_threshold: 3,
          timeout: 30_000
        },
        id: :amqp_breaker
      ),
      Supervisor.child_spec(
        {VsmPhoenix.Resilience.CircuitBreaker,
          name: :database_breaker,
          failure_threshold: 3,
          success_threshold: 2,
          timeout: 20_000
        },
        id: :database_breaker
      ),

      # Bulkhead pools for resource isolation
      bulkhead_spec(:amqp_channels, max_concurrent: 20, max_waiting: 100),
      bulkhead_spec(:http_connections, max_concurrent: 50, max_waiting: 200),
      bulkhead_spec(:llm_requests, max_concurrent: 10, max_waiting: 50),

      # HTTP Clients with circuit breakers
      http_client_spec(:hermes_client,
        timeout: 10_000,
        circuit_breaker_threshold: 5
      ),
      http_client_spec(:external_api_client,
        timeout: 5_000,
        circuit_breaker_threshold: 3
      ),

      # Resilient AMQP Connection - Commented out to avoid conflict with existing ConnectionManager
      # {VsmPhoenix.Resilience.ResilientAMQPConnection,
      #  name: VsmPhoenix.AMQP.ConnectionManager, failure_threshold: 5, circuit_timeout: 30_000}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # Helper functions to create child specs

  defp bulkhead_spec(name, opts) do
    id = :"bulkhead_#{name}"
    config = Keyword.put(opts, :name, id)

    %{
      id: id,
      start: {VsmPhoenix.Resilience.Bulkhead, :start_link, [config]},
      restart: :permanent,
      type: :worker
    }
  end

  defp http_client_spec(name, opts) do
    id = :"http_client_#{name}"
    config = Keyword.put(opts, :name, id)

    %{
      id: id,
      start: {VsmPhoenix.Resilience.ResilientHTTPClient, :start_link, [config]},
      restart: :permanent,
      type: :worker
    }
  end
end
