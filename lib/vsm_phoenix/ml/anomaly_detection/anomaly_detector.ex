defmodule VsmPhoenix.ML.AnomalyDetection.AnomalyDetector do
  @moduledoc """
  Advanced Anomaly Detection Engine with multiple algorithms:
  - Isolation Forest for unsupervised anomaly detection
  - DBSCAN clustering for density-based outlier detection
  - Autoencoder neural networks for reconstruction-based detection
  - Statistical methods for distribution-based detection
  """

  use GenServer
  require Logger
  alias Nx.Tensor
  
  defstruct [
    :isolation_forest,
    :dbscan_model,
    :autoencoder,
    :statistical_params,
    training_data: [],
    anomaly_threshold: 0.1,
    detection_modes: [:isolation_forest, :autoencoder, :statistical],
    gpu_enabled: false
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Initializing Anomaly Detection Engine")
    
    state = %__MODULE__{
      anomaly_threshold: Keyword.get(opts, :threshold, 0.1),
      detection_modes: Keyword.get(opts, :modes, [:isolation_forest, :autoencoder, :statistical]),
      gpu_enabled: gpu_available?()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:train, data, options}, _from, state) do
    Logger.info("Training anomaly detection models on #{length(data)} samples")
    
    try do
      # Convert data to tensor
      tensor_data = prepare_tensor_data(data, state.gpu_enabled)
      
      # Train multiple models
      new_state = 
        state
        |> train_isolation_forest(tensor_data, options)
        |> train_autoencoder(tensor_data, options)
        |> compute_statistical_params(tensor_data)

      {:reply, {:ok, "Models trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("Training failed: #{inspect(error)}")
        {:reply, {:error, "Training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:detect, data}, _from, state) do
    try do
      tensor_data = prepare_tensor_data(data, state.gpu_enabled)
      
      # Run detection with all enabled models
      results = %{
        isolation_forest: detect_isolation_forest(tensor_data, state),
        autoencoder: detect_autoencoder(tensor_data, state),
        statistical: detect_statistical(tensor_data, state),
        dbscan: detect_dbscan(tensor_data, state)
      }
      
      # Ensemble the results
      ensemble_score = ensemble_anomaly_scores(results, state.detection_modes)
      is_anomaly = ensemble_score > state.anomaly_threshold
      
      result = %{
        is_anomaly: is_anomaly,
        confidence: ensemble_score,
        individual_scores: results,
        timestamp: DateTime.utc_now()
      }
      
      {:reply, {:ok, result}, state}
    rescue
      error ->
        Logger.error("Detection failed: #{inspect(error)}")
        {:reply, {:error, "Detection failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:batch_detect, data_batch}, _from, state) do
    try do
      results = Enum.map(data_batch, fn data ->
        tensor_data = prepare_tensor_data(data, state.gpu_enabled)
        
        scores = %{
          isolation_forest: detect_isolation_forest(tensor_data, state),
          autoencoder: detect_autoencoder(tensor_data, state),
          statistical: detect_statistical(tensor_data, state),
          dbscan: detect_dbscan(tensor_data, state)
        }
        
        ensemble_score = ensemble_anomaly_scores(scores, state.detection_modes)
        
        %{
          data: data,
          is_anomaly: ensemble_score > state.anomaly_threshold,
          confidence: ensemble_score,
          scores: scores
        }
      end)
      
      {:reply, {:ok, results}, state}
    rescue
      error ->
        Logger.error("Batch detection failed: #{inspect(error)}")
        {:reply, {:error, "Batch detection failed: #{Exception.message(error)}"}, state}
    end
  end

  # Public API
  def train(data, options \\ []) do
    GenServer.call(__MODULE__, {:train, data, options}, 30_000)
  end

  def detect(data) do
    GenServer.call(__MODULE__, {:detect, data})
  end

  def batch_detect(data_batch) do
    GenServer.call(__MODULE__, {:batch_detect, data_batch})
  end

  # Private functions
  
  defp prepare_tensor_data(data, gpu_enabled) when is_list(data) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    data
    |> Enum.map(&convert_to_numbers/1)
    |> Nx.tensor(backend: backend)
    |> Nx.to_type(:f32)
  end

  defp convert_to_numbers(item) when is_number(item), do: item
  defp convert_to_numbers(item) when is_list(item), do: Enum.map(item, &convert_to_numbers/1)
  defp convert_to_numbers(item) when is_map(item) do
    item
    |> Map.values()
    |> Enum.flat_map(fn
      val when is_number(val) -> [val]
      val when is_list(val) -> Enum.map(val, &convert_to_numbers/1)
      _ -> [0.0]  # Default for non-numeric values
    end)
  end
  defp convert_to_numbers(_), do: 0.0

  defp train_isolation_forest(state, data, options) do
    Logger.info("Training Isolation Forest")
    
    # Simple isolation forest implementation
    n_trees = Keyword.get(options, :n_trees, 100)
    sample_size = min(256, Nx.axis_size(data, 0))
    
    trees = for _ <- 1..n_trees do
      build_isolation_tree(data, sample_size, 0, options)
    end
    
    %{state | isolation_forest: %{trees: trees, sample_size: sample_size}}
  end

  defp build_isolation_tree(data, sample_size, depth, options) do
    max_depth = Keyword.get(options, :max_depth, 10)
    
    if depth >= max_depth or Nx.axis_size(data, 0) <= 1 do
      %{type: :leaf, size: Nx.axis_size(data, 0)}
    else
      # Random feature and split
      n_features = Nx.axis_size(data, 1)
      feature_idx = :rand.uniform(n_features) - 1
      
      feature_data = Nx.slice_along_axis(data, feature_idx, 1, axis: 1)
      min_val = Nx.reduce_min(feature_data)
      max_val = Nx.reduce_max(feature_data)
      
      if Nx.equal(min_val, max_val) |> Nx.to_number() == 1 do
        %{type: :leaf, size: Nx.axis_size(data, 0)}
      else
        split_val = Nx.to_number(min_val) + :rand.uniform() * Nx.to_number(Nx.subtract(max_val, min_val))
        
        mask = Nx.less(feature_data, split_val) |> Nx.squeeze(axes: [1])
        left_data = Nx.take(data, Nx.argsort(mask, direction: :desc) |> Nx.slice([0], [Nx.sum(mask) |> Nx.to_number()]))
        right_data = Nx.take(data, Nx.argsort(mask) |> Nx.slice([Nx.sum(mask) |> Nx.to_number()], [Nx.axis_size(data, 0) - (Nx.sum(mask) |> Nx.to_number())]))
        
        %{
          type: :node,
          feature: feature_idx,
          threshold: split_val,
          left: build_isolation_tree(left_data, sample_size, depth + 1, options),
          right: build_isolation_tree(right_data, sample_size, depth + 1, options)
        }
      end
    end
  end

  defp train_autoencoder(state, data, options) do
    Logger.info("Training Autoencoder for anomaly detection")
    
    input_size = Nx.axis_size(data, 1)
    hidden_size = Keyword.get(options, :hidden_size, max(8, div(input_size, 2)))
    
    # Build autoencoder model
    model = 
      Axon.input("input", shape: {nil, input_size})
      |> Axon.dense(hidden_size, activation: :relu, name: "encoder_1")
      |> Axon.dense(max(4, div(hidden_size, 2)), activation: :relu, name: "encoder_2")
      |> Axon.dense(hidden_size, activation: :relu, name: "decoder_1")
      |> Axon.dense(input_size, activation: :linear, name: "output")
    
    # Training parameters
    optimizer = Polaris.Optimizers.adam(learning_rate: 0.001)
    loss_fn = &Axon.Losses.mean_squared_error/2
    
    # Train the model
    epochs = Keyword.get(options, :epochs, 50)
    batch_size = Keyword.get(options, :batch_size, 32)
    
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:mean_squared_error)
      |> Axon.Loop.run(create_training_stream(data, batch_size), %{}, epochs: epochs, compiler: EXLA)
    
    %{state | autoencoder: %{model: model, params: params}}
  end

  defp compute_statistical_params(state, data) do
    Logger.info("Computing statistical parameters")
    
    mean = Nx.mean(data, axes: [0])
    std = Nx.standard_deviation(data, axes: [0])
    
    # Compute mahalanobis distance parameters
    centered_data = Nx.subtract(data, mean)
    cov_matrix = compute_covariance(centered_data)
    
    %{state | statistical_params: %{mean: mean, std: std, cov_matrix: cov_matrix}}
  end

  defp compute_covariance(centered_data) do
    n_samples = Nx.axis_size(centered_data, 0)
    
    centered_data
    |> Nx.transpose()
    |> Nx.dot(centered_data)
    |> Nx.divide(n_samples - 1)
  end

  defp detect_isolation_forest(data, state) do
    case state.isolation_forest do
      nil -> 0.0
      %{trees: trees} ->
        # Compute anomaly score as average path length
        path_lengths = Enum.map(trees, &compute_path_length(data, &1, 0))
        avg_path_length = Enum.sum(path_lengths) / length(path_lengths)
        
        # Normalize to [0, 1] range (lower path length = higher anomaly score)
        max_path = 20  # Reasonable maximum depth
        1.0 - (avg_path_length / max_path)
    end
  end

  defp compute_path_length(data, tree, depth) do
    case tree do
      %{type: :leaf} -> depth
      %{type: :node, feature: feature, threshold: threshold, left: left, right: right} ->
        feature_val = Nx.slice_along_axis(data, feature, 1, axis: 1) |> Nx.squeeze() |> Nx.to_number()
        
        if feature_val < threshold do
          compute_path_length(data, left, depth + 1)
        else
          compute_path_length(data, right, depth + 1)
        end
    end
  end

  defp detect_autoencoder(data, state) do
    case state.autoencoder do
      nil -> 0.0
      %{model: model, params: params} ->
        # Compute reconstruction error
        reconstructed = Axon.predict(model, params, %{"input" => data})
        mse = Nx.mean(Nx.power(Nx.subtract(data, reconstructed), 2))
        
        # Normalize to [0, 1] range
        Nx.to_number(mse) |> min(1.0)
    end
  end

  defp detect_statistical(data, state) do
    case state.statistical_params do
      nil -> 0.0
      %{mean: mean, std: std} ->
        # Z-score based detection
        z_scores = Nx.divide(Nx.subtract(data, mean), std)
        max_z_score = Nx.reduce_max(Nx.abs(z_scores)) |> Nx.to_number()
        
        # Convert to probability (3-sigma rule)
        case max_z_score do
          score when score > 3.0 -> 1.0
          score when score > 2.0 -> 0.8
          score when score > 1.0 -> 0.3
          _ -> 0.0
        end
    end
  end

  defp detect_dbscan(data, _state) do
    # Simple density-based detection
    # For now, return 0.0 - implement full DBSCAN later
    0.0
  end

  defp ensemble_anomaly_scores(scores, detection_modes) do
    active_scores = 
      detection_modes
      |> Enum.map(&Map.get(scores, &1, 0.0))
      |> Enum.filter(&(&1 > 0))
    
    case active_scores do
      [] -> 0.0
      scores -> Enum.sum(scores) / length(scores)
    end
  end

  defp create_training_stream(data, batch_size) do
    data
    |> Nx.to_batched(batch_size)
    |> Stream.map(fn batch -> %{"input" => batch} end)
  end

  defp gpu_available? do
    case Application.get_env(:exla, :clients, []) do
      [] -> false
      clients -> Enum.any?(clients, fn {_name, opts} -> opts[:platform] == :gpu end)
    end
  end
end