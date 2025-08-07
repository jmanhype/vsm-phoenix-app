defmodule VsmPhoenix.System5.Persistence.Supervisor do
  @moduledoc """
  Supervisor for System5 persistence layer components.

  Manages:
  - PolicyStore: ETS-based policy persistence
  - AdaptationStore: Adaptation patterns and learning
  - VarietyMetricsStore: Variety metrics tracking

  Ensures fault tolerance and automatic restart of persistence services.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("System5 Persistence Supervisor starting...")

    children = [
      # PolicyStore - manages policy persistence
      {VsmPhoenix.System5.Persistence.PolicyStore, []},

      # AdaptationStore - manages adaptation patterns
      {VsmPhoenix.System5.Persistence.AdaptationStore, []},

      # VarietyMetricsStore - tracks variety measurements
      {VsmPhoenix.System5.Persistence.VarietyMetricsStore, []}
    ]

    # Supervise with one-for-one strategy
    # If one store crashes, only restart that specific store
    opts = [strategy: :one_for_one, max_restarts: 3, max_seconds: 5]

    Supervisor.init(children, opts)
  end

  @doc """
  Check health status of all persistence components
  """
  def health_check do
    children = [
      {:policy_store, VsmPhoenix.System5.Persistence.PolicyStore},
      {:adaptation_store, VsmPhoenix.System5.Persistence.AdaptationStore},
      {:variety_metrics_store, VsmPhoenix.System5.Persistence.VarietyMetricsStore}
    ]

    Enum.map(children, fn {name, module} ->
      status =
        case Process.whereis(module) do
          nil ->
            :not_running

          pid when is_pid(pid) ->
            if Process.alive?(pid), do: :healthy, else: :unhealthy
        end

      {name, status}
    end)
    |> Map.new()
  end

  @doc """
  Get persistence statistics from all stores
  """
  def get_statistics do
    stats = %{}

    # Get policy store stats
    stats =
      try do
        case GenServer.call(VsmPhoenix.System5.Persistence.PolicyStore, {:list_policies, %{}}) do
          {:ok, policies} ->
            Map.put(stats, :policy_count, length(policies))

          _ ->
            stats
        end
      rescue
        _ -> stats
      end

    # Get adaptation store stats
    stats =
      try do
        case GenServer.call(VsmPhoenix.System5.Persistence.AdaptationStore, :get_metrics) do
          {:ok, metrics} ->
            Map.merge(stats, %{
              adaptation_count: metrics.total_adaptations,
              pattern_count: metrics.total_patterns,
              adaptation_success_rate: metrics.overall_success_rate
            })

          _ ->
            stats
        end
      rescue
        _ -> stats
      end

    # Get variety metrics stats
    stats =
      try do
        case GenServer.call(
               VsmPhoenix.System5.Persistence.VarietyMetricsStore,
               :get_requisite_status
             ) do
          {:ok, status} ->
            Map.merge(stats, %{
              variety_gap: status.variety_gap,
              requisite_variety_met: status.requisite_variety_met,
              coverage_ratio: status.coverage_ratio
            })

          _ ->
            stats
        end
      rescue
        _ -> stats
      end

    stats
  end
end
