defmodule VsmPhoenix.System1.Agents.SensorAgent do
  @moduledoc """
  S1 Sensor Agent - Emits telemetry data every 5 seconds.
  
  Publishes to: vsm.s1.<id>.telemetry
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.AMQP.ConnectionManager
  alias AMQP

  @telemetry_interval 5_000  # 5 seconds

  # Client API

  def start_link(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
  end

  def get_metrics(agent_id) do
    GenServer.call({:global, agent_id}, :get_metrics)
  end

  def update_sensor_config(agent_id, config) do
    GenServer.cast({:global, agent_id}, {:update_config, config})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    agent_id = Keyword.fetch!(opts, :id)
    config = Keyword.get(opts, :config, %{})
    registry = Keyword.get(opts, :registry, Registry)
    
    Logger.info("🔍 Sensor Agent #{agent_id} initializing...")
    
    # Register with S1 Registry if not skipped
    unless registry == :skip_registration do
      :ok = registry.register(agent_id, self(), %{
        type: :sensor,
        config: config,
        started_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
    
    # Get AMQP channel
    {:ok, channel} = ConnectionManager.get_channel(:telemetry)
    
    # Declare exchange and queue
    exchange_name = "vsm.s1.#{agent_id}.telemetry"
    :ok = AMQP.Exchange.declare(channel, exchange_name, :topic, durable: true)
    
    queue_name = "vsm.s1.#{agent_id}.telemetry.queue"
    {:ok, _queue} = AMQP.Queue.declare(channel, queue_name, durable: true)
    :ok = AMQP.Queue.bind(channel, queue_name, exchange_name, routing_key: "#")
    
    # Schedule first telemetry emission
    Process.send_after(self(), :emit_telemetry, @telemetry_interval)
    
    state = %{
      agent_id: agent_id,
      config: config,
      channel: channel,
      exchange: exchange_name,
      metrics: %{
        messages_sent: 0,
        last_emission: nil,
        uptime: 0,
        sensor_readings: []
      },
      start_time: System.monotonic_time(:second)
    }
    
    {:ok, state}
  end

  @impl true
  def handle_info(:emit_telemetry, state) do
    # Generate sensor data based on config
    sensor_data = generate_sensor_data(state.config)
    
    # Create telemetry message
    telemetry = %{
      agent_id: state.agent_id,
      type: :sensor,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      uptime: System.monotonic_time(:second) - state.start_time,
      data: sensor_data,
      sequence: state.metrics.messages_sent + 1
    }
    
    # Publish to AMQP
    message = Jason.encode!(telemetry)
    routing_key = "sensor.#{state.agent_id}.telemetry"
    
    case AMQP.Basic.publish(state.channel, state.exchange, routing_key, message,
           content_type: "application/json",
           persistent: true) do
      :ok ->
        Logger.debug("📡 Sensor #{state.agent_id} emitted telemetry ##{telemetry.sequence}")
        
        # Update metrics
        new_metrics = %{state.metrics |
          messages_sent: state.metrics.messages_sent + 1,
          last_emission: DateTime.utc_now() |> DateTime.to_iso8601(),
          sensor_readings: [sensor_data | Enum.take(state.metrics.sensor_readings, 99)]
        }
        
        # Schedule next emission
        Process.send_after(self(), :emit_telemetry, @telemetry_interval)
        
        {:noreply, %{state | metrics: new_metrics}}
        
      error ->
        Logger.error("Failed to emit telemetry: #{inspect(error)}")
        # Retry after interval
        Process.send_after(self(), :emit_telemetry, @telemetry_interval)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = Map.put(state.metrics, :uptime, System.monotonic_time(:second) - state.start_time)
    {:reply, {:ok, metrics}, state}
  end

  @impl true
  def handle_cast({:update_config, new_config}, state) do
    Logger.info("Sensor #{state.agent_id} config updated")
    {:noreply, %{state | config: Map.merge(state.config, new_config)}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Sensor Agent #{state.agent_id} terminating: #{inspect(reason)}")
    
    # Unregister from registry
    Registry.unregister(state.agent_id)
    
    # Close AMQP channel if needed
    if state.channel && Process.alive?(state.channel.pid) do
      AMQP.Channel.close(state.channel)
    end
    
    :ok
  end

  # Private Functions

  defp via_tuple(agent_id) do
    {:via, Registry, {:s1_registry, agent_id}}
  end

  defp generate_sensor_data(config) do
    sensor_type = Map.get(config, :sensor_type, :generic)
    
    case sensor_type do
      :temperature ->
        %{
          type: :temperature,
          value: 20 + :rand.uniform() * 10,
          unit: "celsius"
        }
        
      :pressure ->
        %{
          type: :pressure,
          value: 1013 + :rand.uniform() * 20 - 10,
          unit: "hPa"
        }
        
      :performance ->
        %{
          type: :performance,
          cpu_usage: :rand.uniform(),
          memory_usage: :rand.uniform(),
          throughput: :rand.uniform(1000)
        }
        
      _ ->
        # Generic sensor data
        %{
          type: :generic,
          value: :rand.uniform(),
          metadata: Map.get(config, :metadata, %{})
        }
    end
  end
end