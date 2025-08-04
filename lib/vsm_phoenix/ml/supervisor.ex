defmodule VsmPhoenix.ML.Supervisor do
  @moduledoc """
  ML Supervisor for managing machine learning components and models.
  Orchestrates anomaly detection, pattern recognition, and predictive analytics.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting ML Supervisor with GPU acceleration support")

    children = [
      # Model storage and management
      {VsmPhoenix.ML.ModelStorage, []},
      
      # Neural network training supervisor
      {VsmPhoenix.ML.NeuralTrainer.Supervisor, []},
      
      # Anomaly detection engines
      {VsmPhoenix.ML.AnomalyDetection.Supervisor, []},
      
      # Pattern recognition systems
      {VsmPhoenix.ML.PatternRecognition.Supervisor, []},
      
      # Predictive analytics engines
      {VsmPhoenix.ML.Prediction.Supervisor, []},
      
      # Performance monitoring
      {VsmPhoenix.ML.PerformanceMonitor, []},
      
      # GPU resource manager
      {VsmPhoenix.ML.GPUManager, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Gets status of all ML components
  """
  def status do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {id, pid, _type, _modules} ->
      case pid do
        :undefined -> {id, :not_running}
        pid when is_pid(pid) -> {id, :running}
        _ -> {id, :unknown}
      end
    end)
    |> Map.new()
  end

  @doc """
  Restarts a specific ML component
  """
  def restart_child(child_id) do
    case Supervisor.restart_child(__MODULE__, child_id) do
      {:ok, _pid} -> {:ok, "#{child_id} restarted successfully"}
      {:error, :not_found} -> {:error, "#{child_id} not found"}
      {:error, reason} -> {:error, "Failed to restart #{child_id}: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets memory usage statistics for ML components
  """
  def memory_stats do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.reduce(children, %{total: 0, components: %{}}, fn {id, pid, _type, _modules}, acc ->
      case pid do
        pid when is_pid(pid) ->
          memory = :erlang.process_info(pid, :memory)[:memory] || 0
          %{
            total: acc.total + memory,
            components: Map.put(acc.components, id, memory)
          }
        _ ->
          acc
      end
    end)
  end
end