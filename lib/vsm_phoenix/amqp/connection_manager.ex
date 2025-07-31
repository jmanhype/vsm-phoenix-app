defmodule VsmPhoenix.AMQP.ConnectionManager do
  @moduledoc """
  Manages RabbitMQ connections for the VSM system
  """
  
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    Logger.info("🐰 Initializing RabbitMQ Connection Manager")
    
    # Try to connect to RabbitMQ
    case establish_connection() do
      {:ok, connection} ->
        Logger.info("✅ Connected to RabbitMQ successfully!")
        
        # Set up VSM exchanges and queues
        setup_vsm_topology(connection)
        
        state = %{
          connection: connection,
          channels: %{},
          status: :connected
        }
        
        {:ok, state}
        
      {:error, reason} ->
        Logger.warning("⚠️  RabbitMQ not available: #{inspect(reason)}. VSM will operate without AMQP.")
        
        # Schedule reconnection attempt
        Process.send_after(self(), :reconnect, 5000)
        
        {:ok, %{connection: nil, channels: %{}, status: :disconnected}}
    end
  end
  
  def handle_info(:reconnect, state) do
    case establish_connection() do
      {:ok, connection} ->
        Logger.info("✅ Reconnected to RabbitMQ!")
        setup_vsm_topology(connection)
        {:noreply, %{state | connection: connection, status: :connected}}
        
      {:error, _reason} ->
        Process.send_after(self(), :reconnect, 5000)
        {:noreply, state}
    end
  end
  
  def handle_call(:get_connection, _from, state) do
    {:reply, state.connection, state}
  end
  
  def handle_call({:get_channel, purpose}, _from, state) do
    case get_or_create_channel(state, purpose) do
      {:ok, channel, new_state} ->
        {:reply, {:ok, channel}, new_state}
      error ->
        {:reply, error, state}
    end
  end
  
  # Connection API
  def get_connection do
    GenServer.call(__MODULE__, :get_connection)
  end
  
  def get_channel(purpose \\ :default) do
    GenServer.call(__MODULE__, {:get_channel, purpose})
  end
  
  # Private functions
  defp establish_connection do
    # Default RabbitMQ connection settings
    options = [
      host: System.get_env("RABBITMQ_HOST", "localhost"),
      port: String.to_integer(System.get_env("RABBITMQ_PORT", "5672")),
      username: System.get_env("RABBITMQ_USER", "guest"),
      password: System.get_env("RABBITMQ_PASS", "guest"),
      virtual_host: System.get_env("RABBITMQ_VHOST", "/")
    ]
    
    AMQP.Connection.open(options)
  end
  
  defp setup_vsm_topology(connection) do
    {:ok, channel} = AMQP.Channel.open(connection)
    
    # Declare VSM exchanges (match existing types if they exist)
    try do
      AMQP.Exchange.declare(channel, "vsm.recursive", :topic, durable: true)
    rescue
      _ -> Logger.debug("Exchange vsm.recursive already exists")
    end
    
    try do
      AMQP.Exchange.declare(channel, "vsm.algedonic", :fanout, durable: true)
    rescue  
      _ -> Logger.debug("Exchange vsm.algedonic already exists")
    end
    
    try do
      AMQP.Exchange.declare(channel, "vsm.coordination", :fanout, durable: true)
    rescue
      _ -> Logger.debug("Exchange vsm.coordination already exists")
    end
    
    try do
      AMQP.Exchange.declare(channel, "vsm.meta", :topic, durable: true)
    rescue
      _ -> Logger.debug("Exchange vsm.meta already exists")
    end
    
    # Declare main VSM queues
    AMQP.Queue.declare(channel, "vsm.system5.policy", durable: true)
    AMQP.Queue.declare(channel, "vsm.system4.intelligence", durable: true)
    AMQP.Queue.declare(channel, "vsm.system3.control", durable: true)
    AMQP.Queue.declare(channel, "vsm.system2.coordination", durable: true)
    AMQP.Queue.declare(channel, "vsm.system1.operations", durable: true)
    
    # Set up bindings (fanout exchange doesn't use routing keys)
    AMQP.Queue.bind(channel, "vsm.system5.policy", "vsm.algedonic")
    
    AMQP.Channel.close(channel)
    
    Logger.info("📋 VSM topology created in RabbitMQ")
  end
  
  defp get_or_create_channel(state, purpose) do
    case state.status do
      :disconnected ->
        {:error, :not_connected}
        
      :connected ->
        case Map.get(state.channels, purpose) do
          nil ->
            case AMQP.Channel.open(state.connection) do
              {:ok, channel} ->
                new_channels = Map.put(state.channels, purpose, channel)
                {:ok, channel, %{state | channels: new_channels}}
              error ->
                error
            end
            
          channel ->
            {:ok, channel, state}
        end
    end
  end
end