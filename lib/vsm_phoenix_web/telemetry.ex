defmodule VsmPhoenixWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters to collect and publish the metrics
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("vsm_phoenix.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("vsm_phoenix.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("vsm_phoenix.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("vsm_phoenix.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("vsm_phoenix.repo.query.idle_time",
        unit: {:native, :millisecond},
        description: "The time the connection spent waiting before being checked out for the query"
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # VSM Specific Metrics
      summary("vsm.system.performance",
        tags: [:system_level],
        description: "VSM System Performance Metrics"
      ),
      summary("vsm.cybernetic.feedback.duration",
        unit: {:native, :millisecond},
        tags: [:feedback_type],
        description: "Cybernetic feedback loop processing time"
      ),
      counter("vsm.algedonic.signals.total",
        tags: [:signal_type],
        description: "Total algedonic signals processed"
      ),
      summary("vsm.queen.decisions.duration",
        unit: {:native, :millisecond},
        description: "Queen decision processing time"
      ),
      counter("vsm.system.messages.total",
        tags: [:system_level, :message_type],
        description: "Total inter-system messages"
      ),
      
      # VSM Audit Metrics
      counter("vsm.system3.audit",
        tags: [:target, :operation, :bypass],
        description: "System 3 audit operations"
      ),
      summary("vsm.system3.audit.complete",
        unit: {:native, :millisecond},
        tags: [:target, :operation, :success],
        description: "Audit operation completion time"
      ),
      counter("vsm.system3.audit.timeout",
        tags: [:target, :operation],
        description: "Audit operation timeouts"
      ),
      counter("vsm.system1.audit",
        tags: [:context, :operation, :requester],
        description: "System 1 audit requests received"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {VsmPhoenixWeb, :count_users, []}
      {__MODULE__, :dispatch_vsm_metrics, []}
    ]
  end

  def dispatch_vsm_metrics do
    # VSM System Health Metrics
    :telemetry.execute([:vsm, :system, :health], %{
      system1_health: get_system_health(VsmPhoenix.System1.Operations),
      system2_health: get_system_health(VsmPhoenix.System2.Coordinator),
      system3_health: get_system_health(VsmPhoenix.System3.Control),
      system4_health: get_system_health(VsmPhoenix.System4.Intelligence),
      system5_health: get_system_health(VsmPhoenix.System5.Queen)
    })

    # Memory usage per VSM system
    systems = [
      VsmPhoenix.System1.Operations,
      VsmPhoenix.System2.Coordinator,
      VsmPhoenix.System3.Control,
      VsmPhoenix.System4.Intelligence,
      VsmPhoenix.System5.Queen
    ]

    Enum.each(systems, fn system ->
      case GenServer.whereis(system) do
        nil -> :ok
        pid ->
          case Process.info(pid, :memory) do
            {:memory, memory} ->
              :telemetry.execute([:vsm, :system, :memory], %{memory: memory}, %{system: system})
            _ -> :ok
          end
      end
    end)
  end

  defp get_system_health(module) do
    case GenServer.whereis(module) do
      nil -> 0.0
      _pid -> 1.0
    end
  end
end