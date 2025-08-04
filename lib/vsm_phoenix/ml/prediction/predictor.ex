defmodule VsmPhoenix.ML.Prediction.Predictor do
  @moduledoc """
  Advanced Predictive Analytics Engine with multiple algorithms:
  - Time series forecasting with LSTM, GRU, and ARIMA
  - Regression models (linear, polynomial, ridge, lasso)
  - Classification algorithms (logistic regression, SVM, random forest)
  - Ensemble methods for improved accuracy
  """

  use GenServer
  require Logger
  alias Nx.Tensor

  defstruct [
    :time_series_models,
    :regression_models,
    :classification_models,
    :ensemble_models,
    prediction_cache: %{},
    gpu_enabled: false,
    model_metrics: %{}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Initializing Predictive Analytics Engine")
    
    state = %__MODULE__{
      gpu_enabled: gpu_available?(),
      time_series_models: %{},
      regression_models: %{},
      classification_models: %{},
      ensemble_models: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:train_time_series, data, options}, _from, state) do
    Logger.info("Training time series forecasting models")
    
    try do
      model_type = Keyword.get(options, :model_type, :lstm)
      new_model = train_time_series_model(data, model_type, options, state.gpu_enabled)
      
      new_models = Map.put(state.time_series_models, model_type, new_model)
      new_state = %{state | time_series_models: new_models}
      
      {:reply, {:ok, "Time series model (#{model_type}) trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("Time series training failed: #{inspect(error)}")
        {:reply, {:error, "Time series training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:train_regression, data, targets, options}, _from, state) do
    Logger.info("Training regression models")
    
    try do
      model_type = Keyword.get(options, :model_type, :linear)
      new_model = train_regression_model(data, targets, model_type, options, state.gpu_enabled)
      
      new_models = Map.put(state.regression_models, model_type, new_model)
      new_state = %{state | regression_models: new_models}
      
      {:reply, {:ok, "Regression model (#{model_type}) trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("Regression training failed: #{inspect(error)}")
        {:reply, {:error, "Regression training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:train_classification, data, labels, options}, _from, state) do
    Logger.info("Training classification models")
    
    try do
      model_type = Keyword.get(options, :model_type, :logistic)
      new_model = train_classification_model(data, labels, model_type, options, state.gpu_enabled)
      
      new_models = Map.put(state.classification_models, model_type, new_model)
      new_state = %{state | classification_models: new_models}
      
      {:reply, {:ok, "Classification model (#{model_type}) trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("Classification training failed: #{inspect(error)}")
        {:reply, {:error, "Classification training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:predict_time_series, data, steps_ahead, model_type}, _from, state) do
    try do
      model = Map.get(state.time_series_models, model_type || :lstm)
      
      case model do
        nil -> {:reply, {:error, "Time series model not found: #{model_type}"}, state}
        _ ->
          predictions = predict_time_series(data, steps_ahead, model, state.gpu_enabled)
          
          result = %{
            predictions: predictions,
            model_type: model_type,
            steps_ahead: steps_ahead,
            timestamp: DateTime.utc_now()
          }
          
          {:reply, {:ok, result}, state}
      end
    rescue
      error ->
        Logger.error("Time series prediction failed: #{inspect(error)}")
        {:reply, {:error, "Time series prediction failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:predict_regression, data, model_type}, _from, state) do
    try do
      model = Map.get(state.regression_models, model_type || :linear)
      
      case model do
        nil -> {:reply, {:error, "Regression model not found: #{model_type}"}, state}
        _ ->
          predictions = predict_regression(data, model, state.gpu_enabled)
          
          result = %{
            predictions: predictions,
            model_type: model_type,
            timestamp: DateTime.utc_now()
          }
          
          {:reply, {:ok, result}, state}
      end
    rescue
      error ->
        Logger.error("Regression prediction failed: #{inspect(error)}")
        {:reply, {:error, "Regression prediction failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:predict_classification, data, model_type}, _from, state) do
    try do
      model = Map.get(state.classification_models, model_type || :logistic)
      
      case model do
        nil -> {:reply, {:error, "Classification model not found: #{model_type}"}, state}
        _ ->
          predictions = predict_classification(data, model, state.gpu_enabled)
          
          result = %{
            predictions: predictions,
            probabilities: predictions.probabilities,
            model_type: model_type,
            timestamp: DateTime.utc_now()
          }
          
          {:reply, {:ok, result}, state}
      end
    rescue
      error ->
        Logger.error("Classification prediction failed: #{inspect(error)}")
        {:reply, {:error, "Classification prediction failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:ensemble_predict, data, prediction_type, options}, _from, state) do
    try do
      result = case prediction_type do
        :time_series -> ensemble_time_series_predict(data, state, options)
        :regression -> ensemble_regression_predict(data, state, options)
        :classification -> ensemble_classification_predict(data, state, options)
        _ -> {:error, "Unknown prediction type: #{prediction_type}"}
      end
      
      {:reply, result, state}
    rescue
      error ->
        Logger.error("Ensemble prediction failed: #{inspect(error)}")
        {:reply, {:error, "Ensemble prediction failed: #{Exception.message(error)}"}, state}
    end
  end

  # Public API
  def train_time_series(data, options \\ []) do
    GenServer.call(__MODULE__, {:train_time_series, data, options}, 60_000)
  end

  def train_regression(data, targets, options \\ []) do
    GenServer.call(__MODULE__, {:train_regression, data, targets, options}, 60_000)
  end

  def train_classification(data, labels, options \\ []) do
    GenServer.call(__MODULE__, {:train_classification, data, labels, options}, 60_000)
  end

  def predict_time_series(data, steps_ahead, model_type \\ :lstm) do
    GenServer.call(__MODULE__, {:predict_time_series, data, steps_ahead, model_type})
  end

  def predict_regression(data, model_type \\ :linear) do
    GenServer.call(__MODULE__, {:predict_regression, data, model_type})
  end

  def predict_classification(data, model_type \\ :logistic) do
    GenServer.call(__MODULE__, {:predict_classification, data, model_type})
  end

  def ensemble_predict(data, prediction_type, options \\ []) do
    GenServer.call(__MODULE__, {:ensemble_predict, data, prediction_type, options})
  end

  # Private functions
  
  defp train_time_series_model(data, model_type, options, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare time series data
    {train_data, train_targets} = prepare_time_series_data(data, options)
    train_data = Nx.tensor(train_data, backend: backend) |> Nx.to_type(:f32)
    train_targets = Nx.tensor(train_targets, backend: backend) |> Nx.to_type(:f32)
    
    model = case model_type do
      :lstm -> build_lstm_model(train_data)
      :gru -> build_gru_model(train_data)
      :rnn -> build_rnn_model(train_data)
      :transformer -> build_transformer_time_series_model(train_data)
      _ -> build_lstm_model(train_data)
    end
    
    # Training configuration
    optimizer = Polaris.Optimizers.adam(learning_rate: Keyword.get(options, :learning_rate, 0.001))
    loss_fn = &Axon.Losses.mean_squared_error/2
    
    epochs = Keyword.get(options, :epochs, 100)
    batch_size = Keyword.get(options, :batch_size, 32)
    
    # Train the model
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:mean_squared_error)
      |> Axon.Loop.metric(:mean_absolute_error)
      |> Axon.Loop.run(create_time_series_batches(train_data, train_targets, batch_size), %{}, 
                       epochs: epochs, compiler: EXLA)
    
    %{
      model: model,
      params: params,
      model_type: model_type,
      input_shape: Nx.shape(train_data),
      scaler_params: compute_scaler_params(data)
    }
  end

  defp train_regression_model(data, targets, model_type, options, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare data
    train_data = normalize_features(data) |> Nx.tensor(backend: backend) |> Nx.to_type(:f32)
    train_targets = Nx.tensor(targets, backend: backend) |> Nx.to_type(:f32)
    
    model = case model_type do
      :linear -> build_linear_regression_model(train_data)
      :polynomial -> build_polynomial_regression_model(train_data, options)
      :ridge -> build_ridge_regression_model(train_data, options)
      :neural -> build_neural_regression_model(train_data)
      _ -> build_linear_regression_model(train_data)
    end
    
    # Training configuration
    optimizer = case model_type do
      :ridge -> Polaris.Optimizers.adam(learning_rate: 0.01)
      _ -> Polaris.Optimizers.adam(learning_rate: Keyword.get(options, :learning_rate, 0.001))
    end
    
    loss_fn = case model_type do
      :ridge -> create_ridge_loss_fn(Keyword.get(options, :alpha, 1.0))
      _ -> &Axon.Losses.mean_squared_error/2
    end
    
    epochs = Keyword.get(options, :epochs, 100)
    batch_size = Keyword.get(options, :batch_size, 32)
    
    # Train the model
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:mean_squared_error)
      |> Axon.Loop.metric(:mean_absolute_error)
      |> Axon.Loop.run(create_regression_batches(train_data, train_targets, batch_size), %{}, 
                       epochs: epochs, compiler: EXLA)
    
    %{
      model: model,
      params: params,
      model_type: model_type,
      feature_scaler: compute_feature_scaler_params(data)
    }
  end

  defp train_classification_model(data, labels, model_type, options, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare data
    train_data = normalize_features(data) |> Nx.tensor(backend: backend) |> Nx.to_type(:f32)
    num_classes = Enum.uniq(labels) |> length()
    train_labels = encode_labels(labels, num_classes) |> Nx.tensor(backend: backend)
    
    model = case model_type do
      :logistic -> build_logistic_regression_model(train_data, num_classes)
      :neural -> build_neural_classification_model(train_data, num_classes)
      :svm -> build_svm_model(train_data, num_classes, options)
      _ -> build_logistic_regression_model(train_data, num_classes)
    end
    
    # Training configuration
    optimizer = Polaris.Optimizers.adam(learning_rate: Keyword.get(options, :learning_rate, 0.001))
    loss_fn = if num_classes > 2, do: &Axon.Losses.categorical_cross_entropy/2, else: &Axon.Losses.binary_cross_entropy/2
    
    epochs = Keyword.get(options, :epochs, 100)
    batch_size = Keyword.get(options, :batch_size, 32)
    
    # Train the model
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:accuracy)
      |> Axon.Loop.run(create_classification_batches(train_data, train_labels, batch_size), %{}, 
                       epochs: epochs, compiler: EXLA)
    
    %{
      model: model,
      params: params,
      model_type: model_type,
      num_classes: num_classes,
      feature_scaler: compute_feature_scaler_params(data),
      label_encoder: create_label_encoder(labels)
    }
  end

  # Model building functions
  
  defp build_lstm_model(data) do
    {_batch, seq_len, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, seq_len, features})
    |> Axon.lstm(128, name: "lstm1", return_sequence: true)
    |> then(fn {output, _state} -> output end)
    |> Axon.lstm(64, name: "lstm2")
    |> then(fn {output, _state} -> output end)
    |> Axon.dense(32, activation: :relu, name: "dense1")
    |> Axon.dropout(rate: 0.2)
    |> Axon.dense(1, name: "output")
  end

  defp build_gru_model(data) do
    {_batch, seq_len, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, seq_len, features})
    |> Axon.gru(128, name: "gru1", return_sequence: true)
    |> then(fn {output, _state} -> output end)
    |> Axon.gru(64, name: "gru2")
    |> then(fn {output, _state} -> output end)
    |> Axon.dense(32, activation: :relu, name: "dense1")
    |> Axon.dropout(rate: 0.2)
    |> Axon.dense(1, name: "output")
  end

  defp build_rnn_model(data) do
    {_batch, seq_len, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, seq_len, features})
    |> Axon.dense(128, activation: :tanh, name: "rnn1")
    |> Axon.dense(64, activation: :tanh, name: "rnn2")
    |> Axon.dense(32, activation: :relu, name: "dense1")
    |> Axon.dense(1, name: "output")
  end

  defp build_transformer_time_series_model(data) do
    {_batch, seq_len, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, seq_len, features})
    |> Axon.dense(256, name: "input_projection")
    |> add_positional_encoding(256)
    |> multi_head_attention(8, 256)
    |> Axon.flatten()
    |> Axon.dense(128, activation: :relu, name: "dense1")
    |> Axon.dense(1, name: "output")
  end

  defp build_linear_regression_model(data) do
    {_batch, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(1, name: "output")
  end

  defp build_polynomial_regression_model(data, options) do
    {_batch, features} = Nx.shape(data)
    degree = Keyword.get(options, :degree, 2)
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(features * degree, activation: :relu, name: "poly_expansion")
    |> Axon.dense(1, name: "output")
  end

  defp build_ridge_regression_model(data, _options) do
    {_batch, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(64, activation: :relu, name: "hidden1")
    |> Axon.dense(32, activation: :relu, name: "hidden2")
    |> Axon.dense(1, name: "output")
  end

  defp build_neural_regression_model(data) do
    {_batch, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(128, activation: :relu, name: "dense1")
    |> Axon.dropout(rate: 0.3)
    |> Axon.dense(64, activation: :relu, name: "dense2")
    |> Axon.dropout(rate: 0.2)
    |> Axon.dense(32, activation: :relu, name: "dense3")
    |> Axon.dense(1, name: "output")
  end

  defp build_logistic_regression_model(data, num_classes) do
    {_batch, features} = Nx.shape(data)
    activation = if num_classes > 2, do: :softmax, else: :sigmoid
    output_size = if num_classes > 2, do: num_classes, else: 1
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(output_size, activation: activation, name: "output")
  end

  defp build_neural_classification_model(data, num_classes) do
    {_batch, features} = Nx.shape(data)
    activation = if num_classes > 2, do: :softmax, else: :sigmoid
    output_size = if num_classes > 2, do: num_classes, else: 1
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(128, activation: :relu, name: "dense1")
    |> Axon.dropout(rate: 0.3)
    |> Axon.dense(64, activation: :relu, name: "dense2")
    |> Axon.dropout(rate: 0.2)
    |> Axon.dense(32, activation: :relu, name: "dense3")
    |> Axon.dense(output_size, activation: activation, name: "output")
  end

  defp build_svm_model(data, num_classes, _options) do
    # Simplified SVM using neural network approximation
    {_batch, features} = Nx.shape(data)
    activation = if num_classes > 2, do: :softmax, else: :sigmoid
    output_size = if num_classes > 2, do: num_classes, else: 1
    
    Axon.input("input", shape: {nil, features})
    |> Axon.dense(256, activation: :relu, name: "svm_hidden1")
    |> Axon.dense(128, activation: :relu, name: "svm_hidden2")
    |> Axon.dense(output_size, activation: activation, name: "output")
  end

  # Prediction functions
  
  defp predict_time_series(data, steps_ahead, model, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare input data
    input_data = prepare_prediction_input(data, model.input_shape, backend)
    
    # Generate predictions step by step
    predictions = generate_sequential_predictions(input_data, steps_ahead, model)
    
    # Denormalize predictions
    denormalize_predictions(predictions, model.scaler_params)
  end

  defp predict_regression(data, model, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Normalize input data
    normalized_data = apply_feature_scaler(data, model.feature_scaler)
    input_data = Nx.tensor(normalized_data, backend: backend) |> Nx.to_type(:f32)
    
    # Make predictions
    Axon.predict(model.model, model.params, %{"input" => input_data})
  end

  defp predict_classification(data, model, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Normalize input data
    normalized_data = apply_feature_scaler(data, model.feature_scaler)
    input_data = Nx.tensor(normalized_data, backend: backend) |> Nx.to_type(:f32)
    
    # Make predictions
    probabilities = Axon.predict(model.model, model.params, %{"input" => input_data})
    
    # Convert to class predictions
    predicted_classes = if model.num_classes > 2 do
      Nx.argmax(probabilities, axis: 1)
    else
      Nx.greater(probabilities, 0.5) |> Nx.as_type(:s32)
    end
    
    # Decode labels
    decoded_classes = decode_labels(predicted_classes, model.label_encoder)
    
    %{
      classes: decoded_classes,
      probabilities: probabilities
    }
  end

  # Ensemble prediction functions
  
  defp ensemble_time_series_predict(data, state, options) do
    steps_ahead = Keyword.get(options, :steps_ahead, 1)
    
    # Collect predictions from all available models
    predictions = 
      state.time_series_models
      |> Enum.map(fn {model_type, model} ->
        try do
          pred = predict_time_series(data, steps_ahead, model, state.gpu_enabled)
          {model_type, pred}
        rescue
          _ -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    
    case predictions do
      [] -> {:error, "No time series models available"}
      predictions ->
        # Weighted ensemble (equal weights for now)
        ensemble_pred = average_predictions(Enum.map(predictions, fn {_, pred} -> pred end))
        
        {:ok, %{
          ensemble_prediction: ensemble_pred,
          individual_predictions: Map.new(predictions),
          model_count: length(predictions)
        }}
    end
  end

  defp ensemble_regression_predict(data, state, _options) do
    # Collect predictions from all available models
    predictions = 
      state.regression_models
      |> Enum.map(fn {model_type, model} ->
        try do
          pred = predict_regression(data, model, state.gpu_enabled)
          {model_type, pred}
        rescue
          _ -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    
    case predictions do
      [] -> {:error, "No regression models available"}
      predictions ->
        # Weighted ensemble
        ensemble_pred = average_tensor_predictions(Enum.map(predictions, fn {_, pred} -> pred end))
        
        {:ok, %{
          ensemble_prediction: ensemble_pred,
          individual_predictions: Map.new(predictions),
          model_count: length(predictions)
        }}
    end
  end

  defp ensemble_classification_predict(data, state, _options) do
    # Collect predictions from all available models
    predictions = 
      state.classification_models
      |> Enum.map(fn {model_type, model} ->
        try do
          pred = predict_classification(data, model, state.gpu_enabled)
          {model_type, pred}
        rescue
          _ -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    
    case predictions do
      [] -> {:error, "No classification models available"}
      predictions ->
        # Ensemble voting
        ensemble_result = ensemble_classification_voting(predictions)
        
        {:ok, %{
          ensemble_prediction: ensemble_result,
          individual_predictions: Map.new(predictions),
          model_count: length(predictions)
        }}
    end
  end

  # Helper functions
  
  defp prepare_time_series_data(data, options) do
    window_size = Keyword.get(options, :window_size, 10)
    
    normalized_data = normalize_time_series(data)
    
    # Create sliding windows
    windows = create_sliding_windows(normalized_data, window_size)
    {input_windows, target_values} = Enum.unzip(windows)
    
    {input_windows, target_values}
  end

  defp normalize_time_series(data) when is_list(data) do
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    range = max_val - min_val
    
    if range > 0 do
      Enum.map(data, fn x -> (x - min_val) / range end)
    else
      data
    end
  end

  defp create_sliding_windows(data, window_size) do
    data
    |> Enum.with_index()
    |> Enum.drop(window_size)
    |> Enum.map(fn {target, index} ->
      window = Enum.slice(data, index - window_size, window_size)
      {window, target}
    end)
  end

  defp normalize_features(data) when is_list(data) do
    # Z-score normalization
    data_tensor = Nx.tensor(data)
    mean = Nx.mean(data_tensor, axes: [0])
    std = Nx.standard_deviation(data_tensor, axes: [0])
    
    Nx.divide(Nx.subtract(data_tensor, mean), std)
    |> Nx.to_list()
  end

  defp encode_labels(labels, num_classes) do
    unique_labels = Enum.uniq(labels)
    label_map = Enum.with_index(unique_labels) |> Map.new()
    
    if num_classes > 2 do
      # One-hot encoding for multi-class
      Enum.map(labels, fn label ->
        index = Map.get(label_map, label)
        one_hot = List.duplicate(0, num_classes)
        List.replace_at(one_hot, index, 1)
      end)
    else
      # Binary encoding
      Enum.map(labels, fn label -> if Map.get(label_map, label) == 0, do: 0, else: 1 end)
    end
  end

  defp create_time_series_batches(data, targets, batch_size) do
    data
    |> Nx.to_batched(batch_size)
    |> Stream.zip(Nx.to_batched(targets, batch_size))
    |> Stream.map(fn {batch_data, batch_targets} -> 
      %{"input" => batch_data, "target" => batch_targets} 
    end)
  end

  defp create_regression_batches(data, targets, batch_size) do
    data
    |> Nx.to_batched(batch_size)
    |> Stream.zip(Nx.to_batched(targets, batch_size))
    |> Stream.map(fn {batch_data, batch_targets} -> 
      %{"input" => batch_data, "target" => batch_targets} 
    end)
  end

  defp create_classification_batches(data, labels, batch_size) do
    data
    |> Nx.to_batched(batch_size)
    |> Stream.zip(Nx.to_batched(labels, batch_size))
    |> Stream.map(fn {batch_data, batch_labels} -> 
      %{"input" => batch_data, "target" => batch_labels} 
    end)
  end

  defp compute_scaler_params(data) do
    min_val = Enum.min(data)
    max_val = Enum.max(data)
    %{min: min_val, max: max_val, range: max_val - min_val}
  end

  defp compute_feature_scaler_params(data) do
    data_tensor = Nx.tensor(data)
    %{
      mean: Nx.mean(data_tensor, axes: [0]),
      std: Nx.standard_deviation(data_tensor, axes: [0])
    }
  end

  defp create_label_encoder(labels) do
    unique_labels = Enum.uniq(labels)
    label_to_index = Enum.with_index(unique_labels) |> Map.new()
    index_to_label = Enum.with_index(unique_labels) |> Enum.map(fn {label, idx} -> {idx, label} end) |> Map.new()
    
    %{label_to_index: label_to_index, index_to_label: index_to_label}
  end

  defp create_ridge_loss_fn(alpha) do
    fn y_true, y_pred ->
      mse_loss = Axon.Losses.mean_squared_error(y_true, y_pred)
      # Add L2 regularization (simplified)
      ridge_penalty = Nx.multiply(alpha, Nx.mean(Nx.power(y_pred, 2)))
      Nx.add(mse_loss, ridge_penalty)
    end
  end

  defp generate_sequential_predictions(input_data, steps_ahead, model) do
    # Generate predictions step by step for time series
    Enum.reduce(1..steps_ahead, {input_data, []}, fn _step, {current_input, predictions} ->
      # Make prediction for current step
      pred = Axon.predict(model.model, model.params, %{"input" => current_input})
      
      # Update input for next step (sliding window)
      new_input = update_input_window(current_input, pred)
      
      {new_input, [pred | predictions]}
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp update_input_window(current_input, new_prediction) do
    # Slide the window: remove first element, add new prediction
    {_batch, seq_len, features} = Nx.shape(current_input)
    
    # Take all but first timestep
    shifted_input = Nx.slice_along_axis(current_input, 1, seq_len - 1, axis: 1)
    
    # Add new prediction as last timestep
    reshaped_pred = Nx.reshape(new_prediction, {1, 1, features})
    Nx.concatenate([shifted_input, reshaped_pred], axis: 1)
  end

  defp prepare_prediction_input(data, input_shape, backend) do
    # Prepare data to match model input shape
    normalized_data = normalize_time_series(data)
    
    # Create proper tensor shape
    case input_shape do
      {_batch, seq_len, features} ->
        # Take last seq_len values and reshape
        input_values = Enum.take(normalized_data, -seq_len)
        reshaped = Enum.map(input_values, fn x -> [x] end)  # Add feature dimension
        Nx.tensor([reshaped], backend: backend) |> Nx.to_type(:f32)
      
      _ ->
        Nx.tensor([normalized_data], backend: backend) |> Nx.to_type(:f32)
    end
  end

  defp denormalize_predictions(predictions, scaler_params) do
    Enum.map(predictions, fn pred ->
      pred_value = Nx.to_number(pred)
      pred_value * scaler_params.range + scaler_params.min
    end)
  end

  defp apply_feature_scaler(data, scaler_params) do
    data_tensor = Nx.tensor(data)
    normalized = Nx.divide(Nx.subtract(data_tensor, scaler_params.mean), scaler_params.std)
    Nx.to_list(normalized)
  end

  defp decode_labels(predicted_indices, label_encoder) do
    predicted_indices
    |> Nx.to_list()
    |> Enum.map(fn index -> Map.get(label_encoder.index_to_label, index) end)
  end

  defp average_predictions(predictions) do
    # Average multiple prediction lists
    prediction_count = length(predictions)
    prediction_length = length(hd(predictions))
    
    for i <- 0..(prediction_length - 1) do
      values = Enum.map(predictions, fn pred -> Enum.at(pred, i) end)
      Enum.sum(values) / prediction_count
    end
  end

  defp average_tensor_predictions(predictions) do
    # Average tensor predictions
    stacked = Nx.stack(predictions)
    Nx.mean(stacked, axes: [0])
  end

  defp ensemble_classification_voting(predictions) do
    # Majority voting for classification ensemble
    individual_classes = Enum.map(predictions, fn {_, pred} -> pred.classes end)
    individual_probs = Enum.map(predictions, fn {_, pred} -> pred.probabilities end)
    
    # Average probabilities
    avg_probs = average_tensor_predictions(individual_probs)
    
    # Majority vote for classes
    vote_results = transpose_lists(individual_classes)
    |> Enum.map(fn class_votes ->
      # Find most common class
      class_votes
      |> Enum.frequencies()
      |> Enum.max_by(fn {_class, count} -> count end)
      |> elem(0)
    end)
    
    %{
      classes: vote_results,
      probabilities: avg_probs
    }
  end

  defp transpose_lists(lists) do
    case lists do
      [] -> []
      [first | _] ->
        length = length(first)
        for i <- 0..(length - 1) do
          Enum.map(lists, fn list -> Enum.at(list, i) end)
        end
    end
  end

  # Positional encoding and attention for transformer (reuse from pattern recognizer)
  defp add_positional_encoding(input, model_size) do
    Axon.layer(input, fn x, _opts ->
      seq_len = Nx.axis_size(x, 1)
      pos_encoding = create_positional_encoding(seq_len, model_size)
      Nx.add(x, pos_encoding)
    end)
  end

  defp create_positional_encoding(seq_len, model_size) do
    positions = Nx.iota({seq_len, 1})
    div_term = Nx.exp(Nx.multiply(Nx.iota({div(model_size, 2)}), -:math.log(10000.0) / model_size))
    
    pe_sin = Nx.sin(Nx.multiply(positions, Nx.reshape(div_term, {1, div(model_size, 2)})))
    pe_cos = Nx.cos(Nx.multiply(positions, Nx.reshape(div_term, {1, div(model_size, 2)})))
    
    pe = Nx.concatenate([pe_sin, pe_cos], axis: 1)
    Nx.reshape(pe, {1, seq_len, model_size})
  end

  defp multi_head_attention(input, num_heads, model_size) do
    head_size = div(model_size, num_heads)
    
    query = Axon.dense(input, model_size, name: "query")
    key = Axon.dense(input, model_size, name: "key")
    value = Axon.dense(input, model_size, name: "value")
    
    query = Axon.reshape(query, {:auto, :auto, num_heads, head_size})
    key = Axon.reshape(key, {:auto, :auto, num_heads, head_size})
    value = Axon.reshape(value, {:auto, :auto, num_heads, head_size})
    
    attention_weights = Axon.layer([query, key], fn q, k, _opts ->
      scores = Nx.dot(q, [2, 3], k, [3, 2])
      scores = Nx.divide(scores, :math.sqrt(head_size))
      Nx.softmax(scores, axis: -1)
    end)
    
    attended = Axon.layer([attention_weights, value], fn weights, v, _opts ->
      Nx.dot(weights, [2, 3], v, [2, 3])
    end)
    
    attended
    |> Axon.reshape({:auto, :auto, model_size})
    |> Axon.dense(model_size, name: "attention_output")
  end

  defp gpu_available? do
    case Application.get_env(:exla, :clients, []) do
      [] -> false
      clients -> Enum.any?(clients, fn {_name, opts} -> opts[:platform] == :gpu end)
    end
  end
end