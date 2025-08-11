defmodule VsmPhoenix.Goldrush.Supervisor do
  @moduledoc """
  Supervisor for Goldrush components - ensures proper startup order
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Start components in the correct order
      # NOTE: These modules don't exist yet - commented out for now
      # VsmPhoenix.Goldrush.PatternStore,
      # VsmPhoenix.Goldrush.PatternEngine,
      # VsmPhoenix.Goldrush.EventAggregator,
      # VsmPhoenix.Goldrush.ActionHandler,
      # Manager depends on all the above
      VsmPhoenix.Goldrush.Manager
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
