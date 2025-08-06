defmodule VsmPhoenix.Resilience.ResilientAMQPConnection do
  @moduledoc """
  Resilient AMQP Connection Manager with circuit breaker and retry logic.

  Features:
  - Circuit breaker pattern for connection failures
  - Exponential backoff retry logic
  - Connection pooling for bulkhead isolation
  - Health checks and monitoring
  - Graceful degradation when AMQP is unavailable
  """

  use GenServer
  require Logger

  alias VsmPhoenix.Resilience.{CircuitBreaker, Retry}

  defstruct connection: nil,
            channels: %{},
            circuit_breaker: nil,
            status: :disconnected,
            config: %{},
            health_check_timer: nil,
            metrics: %{
              connection_attempts: 0,
              successful_connections: 0,
              failed_connections: 0,
              circuit_breaker_trips: 0
            }

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def get_channel(server \\ __MODULE__, purpose \\ :default) do
    GenServer.call(server, {:get_channel, purpose})
  end

  def get_connection(server \\ __MODULE__) do
    GenServer.call(server, :get_connection)
  end

  def health_check(server \\ __MODULE__) do
    GenServer.call(server, :health_check)
  end

  def get_metrics(server \\ __MODULE__) do
    GenServer.call(server, :get_metrics)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("🔌 Initializing Resilient AMQP Connection Manager")

    # Start circuit breaker
    {:ok, circuit_breaker} =
      CircuitBreaker.start_link(
        name: :"#{__MODULE__}_CircuitBreaker",
        failure_threshold: Keyword.get(opts, :failure_threshold, 5),
        timeout: Keyword.get(opts, :circuit_timeout, 30_000),
        on_state_change: &handle_circuit_state_change/3
      )

    config = %{
      host: System.get_env("RABBITMQ_HOST", "localhost"),
      port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
      username: System.get_env("RABBITMQ_USER", "guest"),
      password: System.get_env("RABBITMQ_PASS", "guest"),
      virtual_host: System.get_env("RABBITMQ_VHOST", "/"),
      connection_timeout: Keyword.get(opts, :connection_timeout, 5_000),
      heartbeat: Keyword.get(opts, :heartbeat, 30)
    }

    state = %__MODULE__{
      circuit_breaker: circuit_breaker,
      config: config
    }

    # Try initial connection
    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    new_state = attempt_connection(state)

    # Schedule health checks
    health_check_timer = Process.send_after(self(), :health_check, 30_000)

    {:noreply, %{new_state | health_check_timer: health_check_timer}}
  end

  @impl true
  def handle_call(:get_connection, _from, state) do
    case state.status do
      :connected -> {:reply, {:ok, state.connection}, state}
      _ -> {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:get_channel, purpose}, _from, state) do
    result =
      case state.status do
        :connected ->
          get_or_create_channel(state, purpose)

        _ ->
          {:error, :not_connected}
      end

    case result do
      {:ok, channel, new_state} ->
        {:reply, {:ok, channel}, new_state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:health_check, _from, state) do
    health = %{
      status: state.status,
      circuit_breaker: CircuitBreaker.get_state(state.circuit_breaker),
      metrics: state.metrics,
      channels: map_size(state.channels)
    }

    {:reply, health, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_info(:health_check, state) do
    new_state =
      case state.status do
        :connected ->
          # Verify connection is still alive
          if connection_alive?(state.connection) do
            state
          else
            Logger.warning("⚠️  AMQP connection lost during health check")
            handle_connection_loss(state)
          end

        _ ->
          # Try to reconnect if disconnected
          attempt_connection(state)
      end

    # Schedule next health check
    health_check_timer = Process.send_after(self(), :health_check, 30_000)

    {:noreply, %{new_state | health_check_timer: health_check_timer}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, reason}, state) do
    cond do
      state.connection && state.connection.pid == pid ->
        Logger.error("📉 AMQP connection down: #{inspect(reason)}")
        new_state = handle_connection_loss(state)
        {:noreply, new_state}

      true ->
        # Check if it's a channel that went down
        new_state = handle_channel_down(state, pid)
        {:noreply, new_state}
    end
  end

  # Private Functions

  defp attempt_connection(state) do
    state = update_metrics(state, :connection_attempts, 1)

    # Use circuit breaker to attempt connection
    result =
      CircuitBreaker.call(
        state.circuit_breaker,
        fn ->
          connect_with_retry(state.config)
        end,
        10_000
      )

    case result do
      {:ok, connection} when is_struct(connection, AMQP.Connection) ->
        Logger.info("✅ Successfully connected to RabbitMQ")
        Process.monitor(connection.pid)

        # Setup VSM topology
        setup_vsm_topology(connection)

        state
        |> update_metrics(:successful_connections, 1)
        |> Map.put(:connection, connection)
        |> Map.put(:status, :connected)
        |> Map.put(:channels, %{})

      {:ok, {:ok, connection}} ->
        Logger.info("✅ Successfully connected to RabbitMQ")
        Process.monitor(connection.pid)

        # Setup VSM topology
        setup_vsm_topology(connection)

        state
        |> update_metrics(:successful_connections, 1)
        |> Map.put(:connection, connection)
        |> Map.put(:status, :connected)
        |> Map.put(:channels, %{})

      {:error, :circuit_open} ->
        Logger.warning("⚡ Circuit breaker is open, skipping connection attempt")

        state
        |> update_metrics(:circuit_breaker_trips, 1)
        |> Map.put(:status, :circuit_open)

      {:error, reason} ->
        Logger.error("❌ Failed to connect to RabbitMQ: #{inspect(reason)}")

        state
        |> update_metrics(:failed_connections, 1)
        |> Map.put(:status, :disconnected)
    end
  end

  defp connect_with_retry(config) do
    Retry.with_retry(
      fn ->
        options = [
          host: config.host,
          port: config.port,
          username: config.username,
          password: config.password,
          virtual_host: config.virtual_host,
          connection_timeout: config.connection_timeout,
          heartbeat: config.heartbeat
        ]

        case AMQP.Connection.open(options) do
          {:ok, connection} -> connection
          {:error, reason} -> raise "Connection failed: #{inspect(reason)}"
        end
      end,
      max_attempts: 3,
      base_backoff: 1_000,
      max_backoff: 5_000
    )
  end

  defp get_or_create_channel(state, purpose) do
    case Map.get(state.channels, purpose) do
      nil ->
        case AMQP.Channel.open(state.connection) do
          {:ok, channel} ->
            Process.monitor(channel.pid)
            new_channels = Map.put(state.channels, purpose, channel)
            {:ok, channel, %{state | channels: new_channels}}

          error ->
            error
        end

      channel ->
        # Verify channel is still alive
        if Process.alive?(channel.pid) do
          {:ok, channel, state}
        else
          # Channel died, create a new one
          new_channels = Map.delete(state.channels, purpose)
          get_or_create_channel(%{state | channels: new_channels}, purpose)
        end
    end
  end

  defp setup_vsm_topology(connection) do
    # This should match the original topology setup
    # but with better error handling
    Retry.with_retry(
      fn ->
        {:ok, channel} = AMQP.Channel.open(connection)

        # Declare exchanges
        exchanges = [
          {"vsm.recursive", :topic},
          {"vsm.algedonic", :fanout},
          {"vsm.coordination", :fanout},
          {"vsm.control", :fanout},
          {"vsm.intelligence", :fanout},
          {"vsm.policy", :fanout},
          {"vsm.audit", :fanout},
          {"vsm.meta", :topic},
          {"vsm.commands", :topic}
        ]

        for {name, type} <- exchanges do
          :ok = AMQP.Exchange.declare(channel, name, type, durable: true)
        end

        # Declare queues
        queues = [
          "vsm.system5.policy",
          "vsm.system4.intelligence",
          "vsm.system3.control",
          "vsm.system2.coordination",
          "vsm.system1.operations",
          "vsm.system5.commands",
          "vsm.system4.commands",
          "vsm.system3.commands",
          "vsm.system2.commands",
          "vsm.system1.commands"
        ]

        for queue <- queues do
          {:ok, _} = AMQP.Queue.declare(channel, queue, durable: true)
        end

        # Set up bindings
        AMQP.Queue.bind(channel, "vsm.system5.policy", "vsm.algedonic")
        AMQP.Queue.bind(channel, "vsm.system4.intelligence", "vsm.algedonic")
        AMQP.Queue.bind(channel, "vsm.system3.control", "vsm.coordination")

        AMQP.Channel.close(channel)

        Logger.info("📋 VSM topology created successfully")
      end,
      max_attempts: 3
    )
  end

  defp connection_alive?(nil), do: false

  defp connection_alive?(connection) do
    Process.alive?(connection.pid)
  end

  defp handle_connection_loss(state) do
    # Close all channels
    for {_, channel} <- state.channels do
      try do
        AMQP.Channel.close(channel)
      catch
        _, _ -> :ok
      end
    end

    %{state | connection: nil, channels: %{}, status: :disconnected}
  end

  defp handle_channel_down(state, pid) do
    new_channels =
      state.channels
      |> Enum.reject(fn {_, channel} -> channel.pid == pid end)
      |> Enum.into(%{})

    %{state | channels: new_channels}
  end

  defp handle_circuit_state_change(name, old_state, new_state) do
    Logger.info("⚡ Circuit breaker #{name} changed from #{old_state} to #{new_state}")

    :telemetry.execute(
      [:vsm_phoenix, :resilience, :circuit_breaker, :state_change],
      %{},
      %{name: name, old_state: old_state, new_state: new_state}
    )
  end

  defp update_metrics(state, metric, increment) do
    new_metrics = Map.update!(state.metrics, metric, &(&1 + increment))
    %{state | metrics: new_metrics}
  end
end
