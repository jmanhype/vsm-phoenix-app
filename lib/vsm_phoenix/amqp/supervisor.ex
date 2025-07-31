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
    
    children = [
      # Start AMQP connection manager
      {VsmPhoenix.AMQP.ConnectionManager, []},
      
      # Start recursive protocol handler
      # {VsmPhoenix.AMQP.RecursiveProtocol, [meta_pid: self(), config: %{identity: "vsm_main"}]}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end