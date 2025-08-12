defmodule VsmPhoenix.AMQP.Supervisor do
  @moduledoc """
  Supervisor for AMQP/RabbitMQ connections and recursive protocols
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    Logger.info("🐰 Starting AMQP/RabbitMQ Supervisor for VSM recursive protocols")
    
    # Check if AMQP should be enabled and if RabbitMQ is available
    if amqp_enabled?() and rabbitmq_available?() do
      Logger.info("🐰 RabbitMQ available, starting AMQP components")
      
      children = [
        # Start AMQP connection manager
        {VsmPhoenix.AMQP.ConnectionManager, []},
        
        # Start AMQP channel pool
        {VsmPhoenix.AMQP.ChannelPool, []},
        
        # Start AMQP client for infrastructure
        {VsmPhoenix.Infrastructure.AMQPClient, []},
        
        # Start command router with RPC support
        {VsmPhoenix.AMQP.CommandRouter, []},
        
        # Start secure command router with cryptographic protection
        {VsmPhoenix.AMQP.SecureCommandRouter, []},
        
        # Advanced aMCP Protocol Extensions
        {VsmPhoenix.AMQP.Discovery, []},
        {VsmPhoenix.AMQP.Consensus, []},
        {VsmPhoenix.AMQP.NetworkOptimizer, []},
        {VsmPhoenix.AMQP.ProtocolIntegration, []},
        
        # Start recursive protocol handler
        # {VsmPhoenix.AMQP.RecursiveProtocol, [meta_pid: self(), config: %{identity: "vsm_main"}]}
      ]
      
      Supervisor.init(children, strategy: :one_for_one)
    else
      Logger.warning("⚠️  AMQP disabled or RabbitMQ not available, running without AMQP")
      # Return empty children list
      Supervisor.init([], strategy: :one_for_one)
    end
  end
  
  defp amqp_enabled? do
    System.get_env("DISABLE_AMQP") != "true"
  end
  
  defp rabbitmq_available? do
    case :gen_tcp.connect('localhost', 5672, [], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true
      {:error, _} ->
        false
    end
  end
end