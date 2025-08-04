defmodule VsmPhoenix.ML.NeuralTraining.Supervisor do
  @moduledoc """
  Supervisor for neural training components
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {VsmPhoenix.ML.NeuralTraining.NeuralTrainer, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end