defmodule VsmPhoenix.Infrastructure.Supervisor do
  @moduledoc """
  Supervisor for infrastructure abstraction layer components.
  Manages AMQP and HTTP client abstractions.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # HTTP Client
      {VsmPhoenix.Infrastructure.HTTPClient, []},

      # AMQP Client - starts after ConnectionManager
      {VsmPhoenix.Infrastructure.AMQPClient, []}
    ]

    # Use one_for_one strategy - if one crashes, only restart that one
    Supervisor.init(children, strategy: :one_for_one)
  end
end
