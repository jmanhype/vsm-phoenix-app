defmodule VsmPhoenix.Resilience.HealthMonitor do
  @moduledoc """
  Health monitoring service for resilience components.

  Features:
  - Periodic health checks of all resilience components
  - Aggregated health status reporting
  - Telemetry event emission
  - Alerting on degraded performance
  """

  use GenServer
  require Logger

  defstruct [
    # 30 seconds
    check_interval: 30_000,
    components: %{},
    status: :healthy,
    last_check: nil
  ]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current health status of all components
  """
  def get_health do
    GenServer.call(__MODULE__, :get_health)
  end

  @doc """
  Register a component for health monitoring
  """
  def register_component(name, check_fn) do
    GenServer.cast(__MODULE__, {:register_component, name, check_fn})
  end

  @doc """
  Force an immediate health check
  """
  def check_now do
    GenServer.cast(__MODULE__, :check_now)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    check_interval = Keyword.get(opts, :check_interval, 30_000)

    state = %__MODULE__{
      check_interval: check_interval
    }

    # Schedule first health check
    Process.send_after(self(), :perform_health_check, 1000)

    Logger.info("🏥 Health Monitor started with #{check_interval}ms check interval")

    {:ok, state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    health_report = %{
      status: state.status,
      last_check: state.last_check,
      components:
        Map.new(state.components, fn {name, component} ->
          {name,
           %{
             status: component.status,
             last_check: component.last_check,
             details: component.details
           }}
        end)
    }

    {:reply, health_report, state}
  end

  @impl true
  def handle_cast({:register_component, name, check_fn}, state) do
    component = %{
      check_fn: check_fn,
      status: :unknown,
      last_check: nil,
      details: %{}
    }

    new_components = Map.put(state.components, name, component)
    Logger.info("📋 Registered component #{name} for health monitoring")

    {:noreply, %{state | components: new_components}}
  end

  @impl true
  def handle_cast(:check_now, state) do
    new_state = perform_health_checks(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:perform_health_check, state) do
    new_state = perform_health_checks(state)

    # Schedule next check
    Process.send_after(self(), :perform_health_check, state.check_interval)

    {:noreply, new_state}
  end

  # Private Functions

  defp perform_health_checks(state) do
    # Health checks logged via telemetry events

    # Check default components
    default_components = check_default_components()

    # Check registered components
    custom_components = check_custom_components(state.components)

    # Merge all components
    all_components = Map.merge(default_components, custom_components)

    # Calculate overall status
    overall_status = calculate_overall_status(all_components)

    # Emit telemetry
    :telemetry.execute(
      [:vsm_phoenix, :resilience, :health_check],
      %{
        healthy_count: count_by_status(all_components, :healthy),
        degraded_count: count_by_status(all_components, :degraded),
        unhealthy_count: count_by_status(all_components, :unhealthy)
      },
      %{status: overall_status}
    )

    # Log status changes
    if overall_status != state.status do
      Logger.warning("🏥 Health status changed from #{state.status} to #{overall_status}")
    end

    %{state | components: all_components, status: overall_status, last_check: DateTime.utc_now()}
  end

  defp check_default_components do
    %{
      amqp_connection: check_amqp_health(),
      circuit_breakers: check_circuit_breakers(),
      bulkheads: check_bulkheads()
    }
  end

  defp check_amqp_health do
    try do
      case VsmPhoenix.AMQP.ConnectionManager.health_check() do
        %{status: :connected} ->
          %{status: :healthy, last_check: DateTime.utc_now(), details: %{connected: true}}

        %{status: :circuit_open} ->
          %{status: :unhealthy, last_check: DateTime.utc_now(), details: %{circuit_open: true}}

        _ ->
          %{status: :degraded, last_check: DateTime.utc_now(), details: %{connected: false}}
      end
    catch
      _, _ ->
        %{
          status: :unhealthy,
          last_check: DateTime.utc_now(),
          details: %{error: "health check failed"}
        }
    end
  end

  defp check_circuit_breakers do
    # Check known circuit breakers
    breakers = [
      VsmPhoenix.AMQP.ConnectionManager_CircuitBreaker,
      :http_client_hermes_client_CircuitBreaker,
      :http_client_external_api_client_CircuitBreaker
    ]

    breaker_states =
      Enum.map(breakers, fn breaker ->
        try do
          case VsmPhoenix.Resilience.CircuitBreaker.get_state(breaker) do
            %{state: :closed} -> :healthy
            %{state: :half_open} -> :degraded
            %{state: :open} -> :unhealthy
          end
        catch
          _, _ -> :unknown
        end
      end)

    status =
      cond do
        Enum.any?(breaker_states, &(&1 == :unhealthy)) -> :unhealthy
        Enum.any?(breaker_states, &(&1 == :degraded)) -> :degraded
        Enum.any?(breaker_states, &(&1 == :unknown)) -> :degraded
        true -> :healthy
      end

    %{
      status: status,
      last_check: DateTime.utc_now(),
      details: %{breakers: breaker_states}
    }
  end

  defp check_bulkheads do
    bulkheads = [
      :bulkhead_amqp_channels,
      :bulkhead_http_connections,
      :bulkhead_llm_requests
    ]

    bulkhead_states =
      Enum.map(bulkheads, fn bulkhead ->
        try do
          state = VsmPhoenix.Resilience.Bulkhead.get_state(bulkhead)
          utilization = state.busy / state.max_concurrent

          cond do
            utilization > 0.9 -> :unhealthy
            utilization > 0.7 -> :degraded
            true -> :healthy
          end
        catch
          _, _ -> :unknown
        end
      end)

    status =
      cond do
        # Bulkheads being full is less critical
        Enum.any?(bulkhead_states, &(&1 == :unhealthy)) -> :degraded
        Enum.any?(bulkhead_states, &(&1 == :degraded)) -> :degraded
        Enum.any?(bulkhead_states, &(&1 == :unknown)) -> :degraded
        true -> :healthy
      end

    %{
      status: status,
      last_check: DateTime.utc_now(),
      details: %{bulkheads: bulkhead_states}
    }
  end

  defp check_custom_components(components) do
    Map.new(components, fn {name, component} ->
      status =
        try do
          case component.check_fn.() do
            :ok -> :healthy
            {:ok, _} -> :healthy
            {:degraded, details} -> {:degraded, details}
            {:error, _} -> :unhealthy
            _ -> :unknown
          end
        catch
          _, _ -> :unhealthy
        end

      updated_component = %{component | status: status, last_check: DateTime.utc_now()}

      {name, updated_component}
    end)
  end

  defp calculate_overall_status(components) do
    statuses =
      components
      |> Map.values()
      |> Enum.map(& &1.status)

    cond do
      Enum.any?(statuses, &(&1 == :unhealthy)) -> :unhealthy
      Enum.any?(statuses, &(&1 == :degraded)) -> :degraded
      Enum.any?(statuses, &(&1 == :unknown)) -> :degraded
      true -> :healthy
    end
  end

  defp count_by_status(components, status) do
    components
    |> Map.values()
    |> Enum.count(&(&1.status == status))
  end
end
