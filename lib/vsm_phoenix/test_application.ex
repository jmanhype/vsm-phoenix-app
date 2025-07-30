defmodule VsmPhoenix.TestApplication do
  @moduledoc """
  Minimal application for testing - starts only essential services
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Only start the bare minimum for tests
      VsmPhoenix.Repo,
      {Phoenix.PubSub, name: VsmPhoenix.PubSub}
    ]
    
    opts = [strategy: :one_for_one, name: VsmPhoenix.TestSupervisor]
    Supervisor.start_link(children, opts)
  end
end