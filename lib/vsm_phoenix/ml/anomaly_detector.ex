defmodule VsmPhoenix.ML.AnomalyDetector do
  @moduledoc """
  Real Machine Learning Anomaly Detection for VSM Phoenix.
  
  Implements:
  - Isolation Forest for outlier detection
  - LSTM for time series anomaly detection
  - Real-time anomaly scoring
  - Adaptive threshold learning
  - Pattern-based anomaly classification
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.ML.Pipeline
  
  @name __MODULE__
  @isolation_forest_trees 100
  @lstm_sequence_length 50
  @anomaly_threshold 0.75
  @retraining_interval 3600000  # 1 hour
  @buffer_size 1000
  
  # State structure
  defstruct [
    :isolation_forest,
    :lstm_model,
    :scaler,
    :training_data,
    :anomaly_buffer,
    :statistics,
    :last_training,
    :feature_extractors,
    :adaptive_threshold
  ]
  
  # Public API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  def detect_anomaly(data) do
    GenServer.call(@name, {:detect_anomaly, data})
  end
  
  def detect_time_series_anomaly(sequence) do
    GenServer.call(@name, {:detect_time_series_anomaly, sequence})
  end
  
  def batch_detect(data_batch) do
    GenServer.call(@name, {:batch_detect, data_batch})
  end
  
  def train_model(training_data) do
    GenServer.call(@name, {:train_model, training_data}, 60000)
  end
  
  def get_model_stats do
    GenServer.call(@name, :get_model_stats)
  end
  
  def update_threshold(new_threshold) do
    GenServer.call(@name, {:update_threshold, new_threshold})
  end
  
  # GenServer Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🤖 Initializing ML Anomaly Detector...")
    
    # Initialize Nx backend
    Nx.default_backend(EXLA.Backend)
    
    state = %__MODULE__{
      isolation_forest: nil,
      lstm_model: nil,
      scaler: nil,
      training_data: [],
      anomaly_buffer: :queue.new(),
      statistics: %{
        total_detections: 0,
        anomalies_found: 0,
        false_positive_rate: 0.0,
        last_accuracy: 0.0,
        detection_times: []
      },
      last_training: nil,
      feature_extractors: initialize_feature_extractors(),
      adaptive_threshold: @anomaly_threshold
    }
    
    # Schedule periodic retraining
    schedule_retraining()
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:detect_anomaly, data}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Extract features from raw data
      features = extract_features(data, state.feature_extractors)
      
      # Scale features if scaler is available
      scaled_features = if state.scaler do
        scale_features(features, state.scaler)
      else
        features
      end
      
      # Calculate anomaly scores using different methods
      isolation_score = if state.isolation_forest do
        calculate_isolation_score(scaled_features, state.isolation_forest)
      else
        0.5  # Default uncertainty
      end
      
      # Statistical anomaly detection
      statistical_score = calculate_statistical_anomaly(scaled_features, state.training_data)
      
      # Ensemble scoring
      combined_score = (isolation_score * 0.7 + statistical_score * 0.3)
      
      # Determine if anomaly based on adaptive threshold
      is_anomaly = combined_score > state.adaptive_threshold
      
      # Build detailed result
      result = %{
        is_anomaly: is_anomaly,
        anomaly_score: combined_score,
        isolation_score: isolation_score,
        statistical_score: statistical_score,
        threshold: state.adaptive_threshold,
        confidence: calculate_confidence(combined_score, state.adaptive_threshold),
        feature_contributions: analyze_feature_contributions(scaled_features),
        detection_time: System.monotonic_time(:millisecond) - start_time
      }
      
      # Update statistics and adaptive threshold
      new_state = update_detection_stats(state, result)
      |> update_adaptive_threshold(result)
      |> buffer_anomaly_data(data, result)
      
      {:reply, {:ok, result}, new_state}
      
    rescue
      error ->
        Logger.error("Anomaly detection failed: #{inspect(error)}")
        {:reply, {:error, :detection_failed}, state}
    end
  end
  
  @impl true
  def handle_call({:detect_time_series_anomaly, sequence}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      if state.lstm_model && length(sequence) >= @lstm_sequence_length do
        # Prepare sequence data
        sequence_tensor = prepare_sequence_data(sequence)
        
        # Get LSTM prediction
        prediction = Axon.predict(state.lstm_model, sequence_tensor)
        
        # Calculate reconstruction error
        actual = Enum.take(sequence, -1) |> List.first()
        predicted = Nx.to_number(prediction)
        reconstruction_error = abs(actual - predicted)
        
        # Normalize error to anomaly score
        anomaly_score = min(reconstruction_error / (abs(actual) + 0.001), 1.0)
        
        is_anomaly = anomaly_score > state.adaptive_threshold
        
        result = %{
          is_anomaly: is_anomaly,
          anomaly_score: anomaly_score,
          reconstruction_error: reconstruction_error,
          predicted_value: predicted,
          actual_value: actual,
          sequence_length: length(sequence),
          detection_time: System.monotonic_time(:millisecond) - start_time
        }
        
        new_state = update_detection_stats(state, result)
        |> update_adaptive_threshold(result)
        
        {:reply, {:ok, result}, new_state}
      else
        # Fallback to statistical method for short sequences
        statistical_result = detect_sequence_anomaly_statistical(sequence, state)
        {:reply, {:ok, statistical_result}, state}
      end
      
    rescue
      error ->
        Logger.error("Time series anomaly detection failed: #{inspect(error)}")
        {:reply, {:error, :time_series_detection_failed}, state}
    end
  end
  
  @impl true
  def handle_call({:batch_detect, data_batch}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Process batch efficiently using Nx operations
      features_batch = Enum.map(data_batch, fn data ->
        extract_features(data, state.feature_extractors)
      end)
      
      # Convert to tensor for batch processing
      features_tensor = Nx.tensor(features_batch)
      
      # Batch isolation forest scoring
      isolation_scores = if state.isolation_forest do
        batch_isolation_scores(features_tensor, state.isolation_forest)
      else
        Nx.broadcast(0.5, {length(data_batch)})
      end
      
      # Batch statistical scoring
      statistical_scores = batch_statistical_scores(features_tensor, state.training_data)
      
      # Combine scores
      combined_scores = Nx.add(
        Nx.multiply(isolation_scores, 0.7),
        Nx.multiply(statistical_scores, 0.3)
      )
      
      # Convert to results
      results = combined_scores
      |> Nx.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {score, idx} ->
        is_anomaly = score > state.adaptive_threshold
        
        %{
          index: idx,
          is_anomaly: is_anomaly,
          anomaly_score: score,
          threshold: state.adaptive_threshold,
          confidence: calculate_confidence(score, state.adaptive_threshold)
        }
      end)
      
      batch_result = %{
        total_processed: length(data_batch),
        anomalies_found: Enum.count(results, & &1.is_anomaly),
        anomaly_rate: Enum.count(results, & &1.is_anomaly) / length(data_batch),
        results: results,
        processing_time: System.monotonic_time(:millisecond) - start_time
      }
      
      # Update state with batch statistics
      new_state = update_batch_stats(state, batch_result)
      
      {:reply, {:ok, batch_result}, new_state}
      
    rescue
      error ->
        Logger.error("Batch anomaly detection failed: #{inspect(error)}")
        {:reply, {:error, :batch_detection_failed}, state}
    end
  end
  
  @impl true
  def handle_call({:train_model, training_data}, _from, state) do
    Logger.info("🤖 Training anomaly detection models with #{length(training_data)} samples...")
    
    start_time = System.monotonic_time(:millisecond)
    
    try do
      # Extract features from training data
      feature_matrix = Enum.map(training_data, fn data ->
        extract_features(data, state.feature_extractors)
      end)
      
      # Create feature scaler
      scaler = create_feature_scaler(feature_matrix)
      scaled_features = Enum.map(feature_matrix, &scale_features(&1, scaler))
      
      # Train Isolation Forest
      Logger.info("🌲 Training Isolation Forest...")
      isolation_forest = train_isolation_forest(scaled_features)
      
      # Train LSTM for time series (if we have sequential data)
      lstm_model = if has_sequential_structure?(training_data) do
        Logger.info("🧠 Training LSTM model...")
        train_lstm_model(training_data)
      else
        state.lstm_model
      end
      
      training_time = System.monotonic_time(:millisecond) - start_time
      Logger.info("✅ Model training completed in #{training_time}ms")
      
      new_state = %{state |
        isolation_forest: isolation_forest,
        lstm_model: lstm_model,
        scaler: scaler,
        training_data: scaled_features,
        last_training: DateTime.utc_now(),
        statistics: Map.put(state.statistics, :last_training_time, training_time)
      }
      
      {:reply, {:ok, %{training_time: training_time, samples: length(training_data)}}, new_state}
      
    rescue
      error ->
        Logger.error("Model training failed: #{inspect(error)}")
        {:reply, {:error, :training_failed}, state}
    end
  end
  
  @impl true
  def handle_call(:get_model_stats, _from, state) do
    stats = %{
      model_status: %{
        isolation_forest_trained: state.isolation_forest != nil,
        lstm_model_trained: state.lstm_model != nil,
        scaler_available: state.scaler != nil,
        last_training: state.last_training,
        training_samples: length(state.training_data)
      },
      detection_stats: state.statistics,
      configuration: %{
        isolation_forest_trees: @isolation_forest_trees,
        lstm_sequence_length: @lstm_sequence_length,
        current_threshold: state.adaptive_threshold,
        buffer_size: @buffer_size
      },
      performance_metrics: calculate_performance_metrics(state.statistics)
    }
    
    {:reply, {:ok, stats}, state}
  end
  
  @impl true
  def handle_call({:update_threshold, new_threshold}, _from, state) do
    Logger.info("🎯 Updating anomaly threshold from #{state.adaptive_threshold} to #{new_threshold}")
    
    new_state = %{state | adaptive_threshold: new_threshold}
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_info(:retrain_models, state) do
    # Periodic retraining if we have enough new data
    schedule_retraining()
    
    if should_retrain?(state) do
      Logger.info("🔄 Triggering periodic model retraining...")
      
      # Extract recent data from buffer for retraining
      recent_data = extract_buffer_data(state.anomaly_buffer)
      
      if length(recent_data) > 100 do
        # Trigger retraining asynchronously
        Task.start(fn ->
          GenServer.call(@name, {:train_model, recent_data}, 60000)
        end)
      end
    end
    
    {:noreply, state}
  end
  
  # Private Functions
  
  defp initialize_feature_extractors do
    %{
      statistical: &extract_statistical_features/1,
      frequency: &extract_frequency_features/1,
      temporal: &extract_temporal_features/1,
      structural: &extract_structural_features/1
    }
  end
  
  defp extract_features(data, extractors) do
    # Extract comprehensive features from raw data
    case data do
      data when is_list(data) and length(data) > 0 ->
        numerical_data = Enum.map(data, fn
          x when is_number(x) -> x
          x when is_map(x) -> extract_numerical_from_map(x)
          x -> hash_to_number(x)
        end)
        
        # Extract different types of features
        statistical = extractors.statistical.(numerical_data)
        frequency = extractors.frequency.(numerical_data)
        temporal = extractors.temporal.(numerical_data)
        structural = extractors.structural.(numerical_data)
        
        statistical ++ frequency ++ temporal ++ structural
        
      data when is_map(data) ->
        extract_features_from_map(data, extractors)
        
      data when is_number(data) ->
        [data, data * data, :math.log(abs(data) + 1), :math.sin(data)]
        
      _ ->
        # Fallback: convert to hash-based features
        hash_features(data)
    end
  end
  
  defp extract_statistical_features(data) when is_list(data) and length(data) > 0 do
    n = length(data)
    mean = Enum.sum(data) / n
    variance = Enum.sum(Enum.map(data, fn x -> (x - mean) * (x - mean) end)) / n
    std_dev = :math.sqrt(variance)
    
    sorted = Enum.sort(data)
    median = if rem(n, 2) == 0 do
      (Enum.at(sorted, div(n, 2) - 1) + Enum.at(sorted, div(n, 2))) / 2
    else
      Enum.at(sorted, div(n, 2))
    end
    
    # Advanced statistical features
    skewness = if std_dev > 0 do
      third_moment = Enum.sum(Enum.map(data, fn x -> :math.pow((x - mean) / std_dev, 3) end)) / n
      third_moment
    else
      0.0
    end
    
    kurtosis = if std_dev > 0 do
      fourth_moment = Enum.sum(Enum.map(data, fn x -> :math.pow((x - mean) / std_dev, 4) end)) / n
      fourth_moment - 3.0  # Excess kurtosis
    else
      0.0
    end
    
    [mean, variance, std_dev, median, 
     Enum.min(data), Enum.max(data), 
     skewness, kurtosis,
     Enum.sum(Enum.map(data, &abs/1)) / n,  # Mean absolute value
     :math.sqrt(Enum.sum(Enum.map(data, fn x -> x * x end)) / n)]  # RMS
  end
  
  defp extract_statistical_features(_), do: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  
  defp extract_frequency_features(data) when is_list(data) and length(data) > 1 do
    # Simplified frequency domain features
    # In practice, would use FFT
    n = length(data)
    
    # Zero crossing rate
    zero_crossings = data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] -> (a >= 0 and b < 0) or (a < 0 and b >= 0) end)
    
    zero_crossing_rate = zero_crossings / (n - 1)
    
    # Peak count (simplified)
    peaks = data
    |> Enum.with_index()
    |> Enum.count(fn {val, idx} ->
      prev = if idx > 0, do: Enum.at(data, idx - 1), else: val
      next = if idx < n - 1, do: Enum.at(data, idx + 1), else: val
      val > prev and val > next
    end)
    
    peak_rate = peaks / n
    
    # Spectral centroid (approximation)
    abs_data = Enum.map(data, &abs/1)
    total_magnitude = Enum.sum(abs_data)
    
    spectral_centroid = if total_magnitude > 0 do
      weighted_sum = abs_data
      |> Enum.with_index()
      |> Enum.map(fn {mag, idx} -> mag * idx end)
      |> Enum.sum()
      
      weighted_sum / total_magnitude
    else
      0.0
    end
    
    [zero_crossing_rate, peak_rate, spectral_centroid]
  end
  
  defp extract_frequency_features(_), do: [0.0, 0.0, 0.0]
  
  defp extract_temporal_features(data) when is_list(data) and length(data) > 1 do
    # Temporal pattern features
    n = length(data)
    
    # First and second derivatives (rate of change)
    first_diff = data
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b - a end)
    
    second_diff = first_diff
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b - a end)
    
    # Statistics of derivatives
    first_diff_mean = if length(first_diff) > 0, do: Enum.sum(first_diff) / length(first_diff), else: 0.0
    first_diff_std = if length(first_diff) > 1 do
      variance = Enum.sum(Enum.map(first_diff, fn x -> (x - first_diff_mean) * (x - first_diff_mean) end)) / length(first_diff)
      :math.sqrt(variance)
    else
      0.0
    end
    
    second_diff_mean = if length(second_diff) > 0, do: Enum.sum(second_diff) / length(second_diff), else: 0.0
    
    # Trend strength
    trend_strength = abs(first_diff_mean)
    
    # Autocorrelation at lag 1
    autocorr_1 = if n > 1 do
      calculate_autocorrelation(data, 1)
    else
      0.0
    end
    
    [first_diff_mean, first_diff_std, second_diff_mean, trend_strength, autocorr_1]
  end
  
  defp extract_temporal_features(_), do: [0.0, 0.0, 0.0, 0.0, 0.0]
  
  defp extract_structural_features(data) when is_list(data) and length(data) > 0 do
    # Structural complexity features
    n = length(data)
    
    # Entropy (simplified)
    # Discretize data into bins
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    
    entropy = if max_val > min_val do
      bin_size = (max_val - min_val) / 10
      binned = Enum.map(data, fn x -> trunc((x - min_val) / bin_size) |> min(9) end)
      frequencies = Enum.frequencies(binned)
      
      frequencies
      |> Map.values()
      |> Enum.map(fn count -> 
        p = count / n
        if p > 0, do: -p * :math.log2(p), else: 0.0
      end)
      |> Enum.sum()
    else
      0.0
    end
    
    # Lempel-Ziv complexity (approximation)
    lz_complexity = calculate_lz_complexity(data)
    
    # Fractal dimension (box counting approximation)
    fractal_dim = estimate_fractal_dimension(data)
    
    [entropy, lz_complexity, fractal_dim]
  end
  
  defp extract_structural_features(_), do: [0.0, 0.0, 0.0]
  
  defp extract_features_from_map(data, extractors) do
    # Extract numerical values from map
    numerical_values = data
    |> Map.values()
    |> Enum.flat_map(fn
      v when is_number(v) -> [v]
      v when is_list(v) -> Enum.filter(v, &is_number/1)
      _ -> []
    end)
    
    if length(numerical_values) > 0 do
      extract_features(numerical_values, extractors)
    else
      # Use map structure features
      [
        map_size(data),
        length(Map.keys(data)),
        hash_to_number(data) / 1000000000
      ] ++ List.duplicate(0.0, 18)  # Pad to expected length
    end
  end
  
  defp extract_numerical_from_map(map) do
    map
    |> Map.values()
    |> Enum.find(0.0, &is_number/1)
  end
  
  defp hash_to_number(data) do
    :crypto.hash(:sha256, inspect(data))
    |> :binary.decode_unsigned()
    |> rem(1000000)
    |> Kernel./(1000000)
  end
  
  defp hash_features(data) do
    hash = hash_to_number(data)
    [hash, hash * hash, :math.sin(hash * 10), :math.cos(hash * 10)] ++ List.duplicate(hash, 17)
  end
  
  defp calculate_autocorrelation(data, lag) do
    n = length(data)
    if n <= lag do
      0.0
    else
      mean = Enum.sum(data) / n
      
      # Calculate autocovariance
      autocovariance = data
      |> Enum.take(n - lag)
      |> Enum.with_index()
      |> Enum.map(fn {x, i} ->
        y = Enum.at(data, i + lag)
        (x - mean) * (y - mean)
      end)
      |> Enum.sum()
      |> Kernel./(n - lag)
      
      # Calculate variance
      variance = data
      |> Enum.map(fn x -> (x - mean) * (x - mean) end)
      |> Enum.sum()
      |> Kernel./(n)
      
      if variance > 0, do: autocovariance / variance, else: 0.0
    end
  end
  
  defp calculate_lz_complexity(data) do
    # Simplified Lempel-Ziv complexity
    # Convert to binary string first
    binary_data = data
    |> Enum.map(fn x -> if x > 0, do: "1", else: "0" end)
    |> Enum.join("")
    
    # Count unique substrings (simplified)
    substrings = for i <- 0..(String.length(binary_data) - 1),
                     j <- (i + 1)..String.length(binary_data) do
      String.slice(binary_data, i, j - i)
    end
    
    unique_count = substrings |> Enum.uniq() |> length()
    unique_count / (String.length(binary_data) + 1)
  end
  
  defp estimate_fractal_dimension(data) do
    # Box counting dimension estimation
    n = length(data)
    if n < 4 do
      1.0
    else
      # Simple approach: count covering intervals at different scales
      scales = [1, 2, 4, 8]
      valid_scales = Enum.filter(scales, fn s -> s < n end)
      
      if length(valid_scales) < 2 do
        1.0
      else
        counts = Enum.map(valid_scales, fn scale ->
          box_count = estimate_box_count(data, scale)
          {scale, box_count}
        end)
        
        # Linear regression on log-log plot
        log_scales = Enum.map(counts, fn {s, _} -> :math.log(s) end)
        log_counts = Enum.map(counts, fn {_, c} -> :math.log(max(c, 1)) end)
        
        # Simple slope calculation
        if length(log_scales) >= 2 do
          slope = calculate_slope(log_scales, log_counts)
          abs(slope)
        else
          1.0
        end
      end
    end
  end
  
  defp estimate_box_count(data, scale) do
    n = length(data)
    boxes = div(n, scale)
    
    # Count non-empty boxes
    data
    |> Enum.chunk_every(scale)
    |> Enum.count(fn chunk -> Enum.any?(chunk, fn x -> abs(x) > 0.001 end) end)
  end
  
  defp calculate_slope(x_vals, y_vals) do
    n = length(x_vals)
    if n < 2 do
      0.0
    else
      x_mean = Enum.sum(x_vals) / n
      y_mean = Enum.sum(y_vals) / n
      
      numerator = x_vals
      |> Enum.zip(y_vals)
      |> Enum.map(fn {x, y} -> (x - x_mean) * (y - y_mean) end)
      |> Enum.sum()
      
      denominator = x_vals
      |> Enum.map(fn x -> (x - x_mean) * (x - x_mean) end)
      |> Enum.sum()
      
      if denominator > 0, do: numerator / denominator, else: 0.0
    end
  end
  
  defp create_feature_scaler(feature_matrix) do
    # Create min-max scaler
    if length(feature_matrix) == 0 do
      nil
    else
      # Transpose to get features by column
      num_features = length(List.first(feature_matrix))
      
      feature_stats = for i <- 0..(num_features - 1) do
        feature_values = Enum.map(feature_matrix, &Enum.at(&1, i, 0))
        min_val = Enum.min(feature_values)
        max_val = Enum.max(feature_values)
        range = max_val - min_val
        
        %{min: min_val, max: max_val, range: if(range > 0, do: range, else: 1.0)}
      end
      
      feature_stats
    end
  end
  
  defp scale_features(features, nil), do: features
  defp scale_features(features, scaler) do
    # Apply min-max scaling
    features
    |> Enum.with_index()
    |> Enum.map(fn {value, idx} ->
      if idx < length(scaler) do
        stats = Enum.at(scaler, idx)
        (value - stats.min) / stats.range
      else
        value
      end
    end)
  end
  
  defp train_isolation_forest(features) do
    # Implement Isolation Forest algorithm
    Logger.info("🌲 Building #{@isolation_forest_trees} isolation trees...")
    
    n_samples = length(features)
    subsample_size = min(256, n_samples)  # Standard isolation forest subsample size
    
    trees = for _i <- 1..@isolation_forest_trees do
      # Random subsample
      subsample = Enum.take_random(features, subsample_size)
      
      # Build isolation tree
      build_isolation_tree(subsample, 0, trunc(:math.log2(subsample_size)))
    end
    
    %{
      trees: trees,
      n_trees: @isolation_forest_trees,
      subsample_size: subsample_size,
      trained_at: DateTime.utc_now()
    }
  end
  
  defp build_isolation_tree(data, depth, max_depth) do
    if length(data) <= 1 or depth >= max_depth do
      # Leaf node
      %{type: :leaf, size: length(data), depth: depth}
    else
      # Internal node - choose random feature and split point
      feature_count = length(List.first(data))
      feature_idx = :rand.uniform(feature_count) - 1
      
      feature_values = Enum.map(data, &Enum.at(&1, feature_idx, 0))
      min_val = Enum.min(feature_values)
      max_val = Enum.max(feature_values)
      
      if max_val > min_val do
        split_point = min_val + :rand.uniform() * (max_val - min_val)
        
        # Split data
        {left_data, right_data} = Enum.split_with(data, fn sample ->
          Enum.at(sample, feature_idx, 0) < split_point
        end)
        
        %{
          type: :internal,
          feature_idx: feature_idx,
          split_point: split_point,
          depth: depth,
          left: build_isolation_tree(left_data, depth + 1, max_depth),
          right: build_isolation_tree(right_data, depth + 1, max_depth)
        }
      else
        # All values same, create leaf
        %{type: :leaf, size: length(data), depth: depth}
      end
    end
  end
  
  defp calculate_isolation_score(features, isolation_forest) do
    # Average path length across all trees
    path_lengths = Enum.map(isolation_forest.trees, fn tree ->
      path_length_in_tree(features, tree)
    end)
    
    avg_path_length = Enum.sum(path_lengths) / length(path_lengths)
    
    # Normalize using expected path length of unsuccessful search in BST
    n = isolation_forest.subsample_size
    expected_length = if n > 2 do
      2 * (:math.log(n - 1) + 0.5772156649) - (2 * (n - 1) / n)
    else
      1.0
    end
    
    # Anomaly score: 2^(-avg_path_length / expected_length)
    :math.pow(2, -avg_path_length / expected_length)
  end
  
  defp path_length_in_tree(features, tree, current_depth \\ 0) do
    case tree.type do
      :leaf ->
        # Add expected path length for leaf based on size
        current_depth + estimate_leaf_path_length(tree.size)
        
      :internal ->
        feature_value = Enum.at(features, tree.feature_idx, 0)
        
        if feature_value < tree.split_point do
          path_length_in_tree(features, tree.left, current_depth + 1)
        else
          path_length_in_tree(features, tree.right, current_depth + 1)
        end
    end
  end
  
  defp estimate_leaf_path_length(size) do
    if size > 2 do
      2 * (:math.log(size - 1) + 0.5772156649) - (2 * (size - 1) / size)
    else
      1.0
    end
  end
  
  defp calculate_statistical_anomaly(features, training_data) do
    if length(training_data) == 0 do
      0.5  # No training data, return neutral score
    else
      # Calculate statistical distance from training distribution
      n_features = length(features)
      
      # Calculate mean and std for each feature from training data
      feature_stats = for i <- 0..(n_features - 1) do
        values = Enum.map(training_data, &Enum.at(&1, i, 0))
        mean = Enum.sum(values) / length(values)
        variance = Enum.sum(Enum.map(values, fn x -> (x - mean) * (x - mean) end)) / length(values)
        std = :math.sqrt(variance + 0.0000000001)  # Add small epsilon to avoid division by zero
        
        %{mean: mean, std: std}
      end
      
      # Calculate Mahalanobis-like distance
      distances = features
      |> Enum.with_index()
      |> Enum.map(fn {value, idx} ->
        if idx < length(feature_stats) do
          stats = Enum.at(feature_stats, idx)
          abs(value - stats.mean) / stats.std
        else
          0.0
        end
      end)
      
      # Average normalized distance
      avg_distance = Enum.sum(distances) / length(distances)
      
      # Convert to anomaly score (0-1 range)
      :math.tanh(avg_distance / 3.0)  # Normalize using tanh
    end
  end
  
  defp train_lstm_model(training_data) do
    # Build LSTM model for time series anomaly detection
    Logger.info("🧠 Building LSTM architecture...")
    
    # Prepare sequential training data
    sequences = prepare_training_sequences(training_data)
    
    if length(sequences) < 10 do
      Logger.warning("Not enough sequential data for LSTM training")
      nil
    else
      # Define LSTM model architecture
      model = Axon.input("sequence", shape: {@lstm_sequence_length, 1})
      |> Axon.lstm(32, name: "lstm1")
      |> elem(0)  # Take only the output, not the state
      |> Axon.dropout(rate: 0.2)
      |> Axon.lstm(16, name: "lstm2")
      |> elem(0)
      |> Axon.dense(1, name: "output", activation: :linear)
      
      # Prepare training data tensors
      {x_train, y_train} = prepare_lstm_training_data(sequences)
      
      # Training parameters
      optimizer = Polaris.Optimizers.adam(learning_rate: 0.001)
      
      # Compile and train
      Logger.info("🏃 Training LSTM model...")
      
      trained_model = model
      |> Axon.Loop.trainer(:mean_squared_error, optimizer)
      |> Axon.Loop.metric(:mean_absolute_error)
      |> Axon.Loop.run(Stream.zip(x_train, y_train), %{}, 
          epochs: 50, 
          iterations: 100,
          log: 10)
      
      Logger.info("✅ LSTM training completed")
      trained_model
    end
  rescue
    error ->
      Logger.error("LSTM training failed: #{inspect(error)}")
      nil
  end
  
  defp has_sequential_structure?(data) do
    # Check if data has temporal/sequential structure
    length(data) >= @lstm_sequence_length * 2
  end
  
  defp prepare_training_sequences(training_data) do
    # Convert training data to sequences for LSTM
    case training_data do
      [first | _] when is_list(first) ->
        # Data is already sequences
        training_data
        
      data when is_list(data) ->
        # Convert flat data to overlapping sequences
        if length(data) >= @lstm_sequence_length do
          for i <- 0..(length(data) - @lstm_sequence_length) do
            Enum.slice(data, i, @lstm_sequence_length)
          end
        else
          []
        end
        
      _ ->
        []
    end
  end
  
  defp prepare_lstm_training_data(sequences) do
    # Prepare X (input) and Y (target) tensors
    x_data = sequences
    |> Enum.map(fn seq ->
      Enum.take(seq, @lstm_sequence_length - 1)  # All but last
      |> Enum.map(&[&1])  # Add feature dimension
    end)
    
    y_data = sequences
    |> Enum.map(fn seq ->
      [List.last(seq)]  # Last element as target
    end)
    
    x_tensor = Nx.tensor(x_data, type: :f32)
    y_tensor = Nx.tensor(y_data, type: :f32)
    
    {x_tensor, y_tensor}
  end
  
  defp prepare_sequence_data(sequence) do
    # Prepare single sequence for LSTM prediction
    padded_sequence = if length(sequence) < @lstm_sequence_length do
      padding = List.duplicate(0.0, @lstm_sequence_length - length(sequence))
      padding ++ sequence
    else
      Enum.take(sequence, -@lstm_sequence_length)
    end
    
    # Add batch and feature dimensions
    padded_sequence
    |> Enum.map(&[&1])
    |> then(&[&1])
    |> Nx.tensor(type: :f32)
  end
  
  defp detect_sequence_anomaly_statistical(sequence, state) do
    # Statistical fallback for sequence anomaly detection
    if length(sequence) < 2 do
      %{
        is_anomaly: false,
        anomaly_score: 0.0,
        method: :insufficient_data
      }
    else
      # Use statistical properties of the sequence
      mean = Enum.sum(sequence) / length(sequence)
      last_value = List.last(sequence)
      
      # Simple deviation-based anomaly score
      if length(sequence) > 1 do
        recent_values = Enum.take(sequence, -10)
        recent_mean = Enum.sum(recent_values) / length(recent_values)
        recent_std = :math.sqrt(
          Enum.sum(Enum.map(recent_values, fn x -> (x - recent_mean) * (x - recent_mean) end)) / 
          length(recent_values)
        )
        
        z_score = if recent_std > 0, do: abs(last_value - recent_mean) / recent_std, else: 0.0
        anomaly_score = :math.tanh(z_score / 3.0)  # Normalize to 0-1
        
        %{
          is_anomaly: anomaly_score > state.adaptive_threshold,
          anomaly_score: anomaly_score,
          z_score: z_score,
          method: :statistical_fallback,
          sequence_length: length(sequence)
        }
      else
        %{
          is_anomaly: false,
          anomaly_score: 0.0,
          method: :single_point
        }
      end
    end
  end
  
  defp batch_isolation_scores(features_tensor, isolation_forest) do
    # Process batch through isolation forest
    # Note: This is a simplified version - in practice would vectorize tree traversal
    features_list = Nx.to_list(features_tensor)
    
    scores = Enum.map(features_list, fn features ->
      calculate_isolation_score(features, isolation_forest)
    end)
    
    Nx.tensor(scores)
  end
  
  defp batch_statistical_scores(features_tensor, training_data) do
    # Process batch statistical scoring
    features_list = Nx.to_list(features_tensor)
    
    scores = Enum.map(features_list, fn features ->
      calculate_statistical_anomaly(features, training_data)
    end)
    
    Nx.tensor(scores)
  end
  
  defp calculate_confidence(score, threshold) do
    # Calculate confidence based on distance from threshold
    distance_from_threshold = abs(score - threshold)
    max_distance = max(threshold, 1.0 - threshold)
    
    if max_distance > 0 do
      distance_from_threshold / max_distance
    else
      0.5
    end
  end
  
  defp analyze_feature_contributions(features) do
    # Analyze which features contribute most to anomaly score
    # Simplified version - would use proper feature importance methods
    features
    |> Enum.with_index()
    |> Enum.map(fn {value, idx} ->
      %{
        feature_idx: idx,
        value: value,
        contribution: abs(value - 0.5),  # Distance from normal
        feature_type: classify_feature_type(idx)
      }
    end)
    |> Enum.sort_by(& &1.contribution, :desc)
    |> Enum.take(5)  # Top 5 contributing features
  end
  
  defp classify_feature_type(idx) do
    cond do
      idx < 10 -> :statistical
      idx < 13 -> :frequency  
      idx < 18 -> :temporal
      true -> :structural
    end
  end
  
  defp update_detection_stats(state, result) do
    new_stats = state.statistics
    |> Map.update(:total_detections, 1, &(&1 + 1))
    |> Map.update(:anomalies_found, 
        (if result.is_anomaly, do: 1, else: 0), 
        &(&1 + if result.is_anomaly, do: 1, else: 0))
    |> Map.update(:detection_times, [result.detection_time], 
        &([result.detection_time | &1] |> Enum.take(100)))
    
    # Update false positive rate (simplified)
    anomaly_rate = new_stats.anomalies_found / new_stats.total_detections
    new_stats = Map.put(new_stats, :anomaly_rate, anomaly_rate)
    
    %{state | statistics: new_stats}
  end
  
  defp update_adaptive_threshold(state, result) do
    # Simple adaptive threshold adjustment
    current_threshold = state.adaptive_threshold
    
    # Adjust based on recent anomaly rates
    recent_anomaly_rate = state.statistics[:anomaly_rate] || 0.0
    
    new_threshold = cond do
      recent_anomaly_rate > 0.1 ->  # Too many anomalies, increase threshold
        min(current_threshold + 0.01, 0.95)
        
      recent_anomaly_rate < 0.01 ->  # Too few anomalies, decrease threshold
        max(current_threshold - 0.01, 0.05)
        
      true ->
        current_threshold
    end
    
    %{state | adaptive_threshold: new_threshold}
  end
  
  defp buffer_anomaly_data(state, data, result) do
    # Buffer anomaly data for retraining
    new_buffer = if result.is_anomaly do
      :queue.in({data, result}, state.anomaly_buffer)
    else
      state.anomaly_buffer
    end
    
    # Keep buffer size manageable
    final_buffer = if :queue.len(new_buffer) > @buffer_size do
      {_, smaller_buffer} = :queue.out(new_buffer)
      smaller_buffer
    else
      new_buffer
    end
    
    %{state | anomaly_buffer: final_buffer}
  end
  
  defp update_batch_stats(state, batch_result) do
    new_stats = state.statistics
    |> Map.update(:total_detections, batch_result.total_processed, &(&1 + batch_result.total_processed))
    |> Map.update(:anomalies_found, batch_result.anomalies_found, &(&1 + batch_result.anomalies_found))
    |> Map.put(:last_batch_time, batch_result.processing_time)
    |> Map.put(:last_batch_anomaly_rate, batch_result.anomaly_rate)
    
    %{state | statistics: new_stats}
  end
  
  defp calculate_performance_metrics(statistics) do
    %{
      detection_rate: statistics[:anomalies_found] || 0,
      total_processed: statistics[:total_detections] || 0,
      average_detection_time: if length(statistics[:detection_times] || []) > 0 do
        Enum.sum(statistics[:detection_times]) / length(statistics[:detection_times])
      else
        0.0
      end,
      throughput: if statistics[:total_detections] && statistics[:total_detections] > 0 do
        statistics[:total_detections] / max(1, div(System.system_time(:second), 3600))  # per hour
      else
        0.0
      end
    }
  end
  
  defp should_retrain?(state) do
    # Check if we should retrain models based on various criteria
    time_since_training = if state.last_training do
      DateTime.diff(DateTime.utc_now(), state.last_training, :second)
    else
      @retraining_interval + 1  # Force training if never trained
    end
    
    buffer_size = :queue.len(state.anomaly_buffer)
    
    # Retrain if enough time passed or buffer is full
    time_since_training > div(@retraining_interval, 1000) or buffer_size > div(@buffer_size, 2)
  end
  
  defp extract_buffer_data(buffer) do
    # Extract data from anomaly buffer for retraining
    :queue.to_list(buffer)
    |> Enum.map(fn {data, _result} -> data end)
  end
  
  defp schedule_retraining do
    Process.send_after(self(), :retrain_models, @retraining_interval)
  end
end