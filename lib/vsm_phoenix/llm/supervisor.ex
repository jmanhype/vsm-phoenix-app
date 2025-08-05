defmodule VsmPhoenix.LLM.Supervisor do
  @moduledoc """
  Supervisor for LLM-related processes.
  Manages the LLM cache and initializes ETS tables.
  """
  
  use Supervisor
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Initialize ETS tables for LLM client
    :ets.new(:llm_rate_limits, [:set, :public, :named_table])
    :ets.new(:llm_usage, [:set, :public, :named_table])
    
    children = [
      # LLM Cache process
      VsmPhoenix.LLM.Cache
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end