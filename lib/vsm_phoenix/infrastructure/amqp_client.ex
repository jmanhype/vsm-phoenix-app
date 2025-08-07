defmodule VsmPhoenix.Infrastructure.AMQPClient do
  @moduledoc """
  Abstraction layer for AMQP operations with configurable exchanges.
  Provides a unified interface for all VSM systems to interact with RabbitMQ.
  """

  use GenServer
  require Logger
  alias VsmPhoenix.Infrastructure.ExchangeConfig
  alias VsmPhoenix.Infrastructure.AMQPRoutes

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @doc """
  Publish a message to an exchange with automatic exchange resolution.
  """
  def publish(exchange_key, routing_key, message, opts \\ []) do
    GenServer.call(__MODULE__, {:publish, exchange_key, routing_key, message, opts})
  end

  @doc """
  Declare a queue and bind it to an exchange based on configuration.
  """
  def declare_queue(queue_key, exchange_key, opts \\ []) do
    GenServer.call(__MODULE__, {:declare_queue, queue_key, exchange_key, opts})
  end

  @doc """
  Declare a queue with a literal queue name (for testing and simple cases).
  """
  def declare_queue_by_name(queue_name, opts) when is_binary(queue_name) do
    GenServer.call(__MODULE__, {:declare_queue_literal, queue_name, opts})
  end

  @doc """
  Subscribe to a queue for message consumption.
  """
  def subscribe(queue_key, consumer_pid, opts \\ []) do
    GenServer.call(__MODULE__, {:subscribe, queue_key, consumer_pid, opts})
  end

  @doc """
  Subscribe to a queue with a literal queue name (for testing and simple cases).
  """
  def subscribe_by_name(queue_name, handler_fun, opts \\ [])
      when is_binary(queue_name) and is_function(handler_fun) do
    GenServer.call(__MODULE__, {:subscribe_literal, queue_name, handler_fun, opts})
  end

  @doc """
  Get the actual exchange name for a given key.
  """
  def get_exchange_name(exchange_key) do
    ExchangeConfig.get_exchange_name(exchange_key)
  end

  @doc """
  Get the actual queue name for a given key.
  """
  def get_queue_name(queue_key, opts \\ []) do
    AMQPRoutes.get_queue_name(queue_key, opts)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      connection: nil,
      channels: %{},
      config: opts[:config] || ExchangeConfig.load_config(),
      connection_manager: opts[:connection_manager] || VsmPhoenix.AMQP.ConnectionManager
    }

    {:ok, state, {:continue, :setup}}
  end

  @impl true
  def handle_continue(:setup, state) do
    case state.connection_manager.get_connection() do
      nil ->
        Logger.warning("AMQP connection not available, operating in offline mode")
        {:noreply, state}

      connection ->
        {:noreply, %{state | connection: connection}}
    end
  end

  @impl true
  def handle_call({:publish, exchange_key, routing_key, message, opts}, _from, state) do
    exchange_name = ExchangeConfig.get_exchange_name(exchange_key)

    case get_channel(state, :publish) do
      {:ok, channel} ->
        result =
          AMQP.Basic.publish(
            channel,
            exchange_name,
            routing_key,
            message,
            Keyword.merge(opts, persistent: true)
          )

        {:reply, result, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:declare_queue, queue_key, exchange_key, opts}, _from, state) do
    queue_name = AMQPRoutes.get_queue_name(queue_key, opts)
    exchange_name = ExchangeConfig.get_exchange_name(exchange_key)

    case get_channel(state, :declare) do
      {:ok, channel} ->
        with {:ok, _} <- AMQP.Queue.declare(channel, queue_name, durable: true),
             :ok <- maybe_bind_queue(channel, queue_name, exchange_name, opts) do
          {:reply, {:ok, queue_name}, state}
        else
          error -> {:reply, error, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:declare_queue_literal, queue_name, opts}, _from, state) do
    case get_channel(state, :declare) do
      {:ok, channel} ->
        queue_opts = Keyword.merge([durable: false, auto_delete: true], opts)

        case AMQP.Queue.declare(channel, queue_name, queue_opts) do
          {:ok, _queue_info} = result -> {:reply, result, state}
          error -> {:reply, error, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:subscribe, queue_key, consumer_pid, opts}, _from, state) do
    queue_name = AMQPRoutes.get_queue_name(queue_key, opts)

    case get_channel(state, :consume) do
      {:ok, channel} ->
        case AMQP.Basic.consume(channel, queue_name, consumer_pid, opts) do
          {:ok, consumer_tag} ->
            {:reply, {:ok, consumer_tag}, state}

          error ->
            {:reply, error, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:subscribe_literal, queue_name, handler_fun, opts}, _from, state) do
    case get_channel(state, :consume) do
      {:ok, channel} ->
        # For literal subscription, we need to handle messages differently
        # Create a simple consumer process that calls the handler function
        consumer_pid =
          spawn_link(fn ->
            receive do
              {:basic_deliver, payload, meta} ->
                handler_fun.(payload, meta)
            end
          end)

        case AMQP.Basic.consume(channel, queue_name, consumer_pid, opts) do
          {:ok, consumer_tag} ->
            {:reply, {:ok, consumer_tag}, state}

          error ->
            {:reply, error, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Functions

  defp get_channel(state, purpose) do
    case state.connection do
      nil ->
        {:error, :no_connection}

      _conn ->
        state.connection_manager.get_channel(purpose)
    end
  end

  defp maybe_bind_queue(channel, queue_name, exchange_name, opts) do
    if opts[:bind] != false do
      routing_key = opts[:routing_key] || queue_name
      AMQP.Queue.bind(channel, queue_name, exchange_name, routing_key: routing_key)
    else
      :ok
    end
  end
end
