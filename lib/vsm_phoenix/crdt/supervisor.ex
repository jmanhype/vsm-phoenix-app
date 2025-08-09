defmodule VsmPhoenix.CRDT.Supervisor do
  @moduledoc """
  Supervisor for CRDT-based context persistence system.
  
  Manages the lifecycle of CRDT components including:
  - ContextStore for managing distributed state
  - AMQP integration for state synchronization
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    Logger.info("🔄 Starting CRDT Supervisor")
    
    # Generate a unique node ID if not provided
    node_id = opts[:node_id] || generate_node_id()
    
    children = [
      # CRDT Context Store
      {VsmPhoenix.CRDT.ContextStore, [node_id: node_id] ++ opts}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  defp generate_node_id do
    # Use a combination of node name and timestamp for uniqueness
    node_str = node() |> to_string() |> String.replace("@", "_")
    timestamp = :erlang.system_time(:microsecond)
    "#{node_str}_#{timestamp}"
  end
end