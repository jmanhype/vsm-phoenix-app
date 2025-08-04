defmodule VsmPhoenix.ML.PatternRecognition.PatternRecognizer do
  @moduledoc """
  Advanced Pattern Recognition System with multiple neural architectures:
  - CNN for spatial pattern detection
  - RNN/LSTM for temporal pattern analysis
  - Transformer for sequence-to-sequence pattern matching
  - Reinforcement learning for adaptive pattern recognition
  """

  use GenServer
  require Logger
  alias Nx.Tensor

  defstruct [
    :cnn_model,
    :rnn_model,
    :transformer_model,
    :rl_agent,
    pattern_library: %{},
    recognition_threshold: 0.7,
    gpu_enabled: false,
    training_history: []
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Initializing Pattern Recognition System")
    
    state = %__MODULE__{
      recognition_threshold: Keyword.get(opts, :threshold, 0.7),
      gpu_enabled: gpu_available?()
    }

    # Initialize models
    {:ok, initialize_models(state)}
  end

  @impl true
  def handle_call({:train_cnn, data, labels, options}, _from, state) do
    Logger.info("Training CNN for spatial pattern recognition")
    
    try do
      new_cnn = train_cnn_model(data, labels, options, state.gpu_enabled)
      new_state = %{state | cnn_model: new_cnn}
      
      {:reply, {:ok, "CNN trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("CNN training failed: #{inspect(error)}")
        {:reply, {:error, "CNN training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:train_rnn, sequences, labels, options}, _from, state) do
    Logger.info("Training RNN for temporal pattern recognition")
    
    try do
      new_rnn = train_rnn_model(sequences, labels, options, state.gpu_enabled)
      new_state = %{state | rnn_model: new_rnn}
      
      {:reply, {:ok, "RNN trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("RNN training failed: #{inspect(error)}")
        {:reply, {:error, "RNN training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:train_transformer, sequences, targets, options}, _from, state) do
    Logger.info("Training Transformer for sequence pattern matching")
    
    try do
      new_transformer = train_transformer_model(sequences, targets, options, state.gpu_enabled)
      new_state = %{state | transformer_model: new_transformer}
      
      {:reply, {:ok, "Transformer trained successfully"}, new_state}
    rescue
      error ->
        Logger.error("Transformer training failed: #{inspect(error)}")
        {:reply, {:error, "Transformer training failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:recognize_pattern, data, pattern_type}, _from, state) do
    try do
      result = case pattern_type do
        :spatial -> recognize_spatial_pattern(data, state)
        :temporal -> recognize_temporal_pattern(data, state)
        :sequence -> recognize_sequence_pattern(data, state)
        :adaptive -> recognize_adaptive_pattern(data, state)
        _ -> {:error, "Unknown pattern type: #{pattern_type}"}
      end
      
      {:reply, result, state}
    rescue
      error ->
        Logger.error("Pattern recognition failed: #{inspect(error)}")
        {:reply, {:error, "Pattern recognition failed: #{Exception.message(error)}"}, state}
    end
  end

  @impl true
  def handle_call({:add_pattern, pattern_name, pattern_data, pattern_type}, _from, state) do
    new_library = Map.put(state.pattern_library, pattern_name, %{
      data: pattern_data,
      type: pattern_type,
      created_at: DateTime.utc_now(),
      usage_count: 0
    })
    
    new_state = %{state | pattern_library: new_library}
    {:reply, {:ok, "Pattern '#{pattern_name}' added to library"}, new_state}
  end

  @impl true
  def handle_call(:get_pattern_library, _from, state) do
    {:reply, {:ok, state.pattern_library}, state}
  end

  # Public API
  def train_cnn(data, labels, options \\ []) do
    GenServer.call(__MODULE__, {:train_cnn, data, labels, options}, 60_000)
  end

  def train_rnn(sequences, labels, options \\ []) do
    GenServer.call(__MODULE__, {:train_rnn, sequences, labels, options}, 60_000)
  end

  def train_transformer(sequences, targets, options \\ []) do
    GenServer.call(__MODULE__, {:train_transformer, sequences, targets, options}, 60_000)
  end

  def recognize_pattern(data, pattern_type) do
    GenServer.call(__MODULE__, {:recognize_pattern, data, pattern_type})
  end

  def add_pattern(pattern_name, pattern_data, pattern_type) do
    GenServer.call(__MODULE__, {:add_pattern, pattern_name, pattern_data, pattern_type})
  end

  def get_pattern_library do
    GenServer.call(__MODULE__, :get_pattern_library)
  end

  # Private functions
  
  defp initialize_models(state) do
    Logger.info("Initializing neural network models")
    
    %{state |
      cnn_model: build_default_cnn(),
      rnn_model: build_default_rnn(),
      transformer_model: build_default_transformer()
    }
  end

  defp build_default_cnn do
    # Default CNN architecture for pattern recognition
    Axon.input("input", shape: {nil, 28, 28, 1})
    |> Axon.conv(32, kernel_size: {3, 3}, activation: :relu, name: "conv1")
    |> Axon.max_pool(kernel_size: {2, 2})
    |> Axon.conv(64, kernel_size: {3, 3}, activation: :relu, name: "conv2")
    |> Axon.max_pool(kernel_size: {2, 2})
    |> Axon.conv(64, kernel_size: {3, 3}, activation: :relu, name: "conv3")
    |> Axon.flatten()
    |> Axon.dense(64, activation: :relu, name: "dense1")
    |> Axon.dropout(rate: 0.5)
    |> Axon.dense(10, activation: :softmax, name: "output")
  end

  defp build_default_rnn do
    # Default RNN architecture for temporal patterns
    Axon.input("input", shape: {nil, nil, 50})
    |> Axon.lstm(128, name: "lstm1")
    |> then(fn {output, _state} -> output end)
    |> Axon.lstm(64, name: "lstm2")
    |> then(fn {output, _state} -> output end)
    |> Axon.dense(32, activation: :relu, name: "dense1")
    |> Axon.dense(10, activation: :softmax, name: "output")
  end

  defp build_default_transformer do
    # Simplified transformer for sequence patterns
    input_size = 512
    model_size = 256
    num_heads = 8
    
    Axon.input("input", shape: {nil, nil, input_size})
    |> Axon.dense(model_size, name: "input_projection")
    |> add_positional_encoding(model_size)
    |> multi_head_attention(num_heads, model_size)
    |> Axon.add()  # Skip connection
    |> Axon.layer_norm()
    |> feed_forward_network(model_size)
    |> Axon.add()  # Skip connection
    |> Axon.layer_norm()
    |> Axon.dense(input_size, name: "output_projection")
  end

  defp add_positional_encoding(input, model_size) do
    # Simplified positional encoding
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
    
    # Interleave sin and cos
    pe = Nx.concatenate([pe_sin, pe_cos], axis: 1)
    Nx.reshape(pe, {1, seq_len, model_size})
  end

  defp multi_head_attention(input, num_heads, model_size) do
    head_size = div(model_size, num_heads)
    
    # Query, Key, Value projections
    query = Axon.dense(input, model_size, name: "query")
    key = Axon.dense(input, model_size, name: "key")
    value = Axon.dense(input, model_size, name: "value")
    
    # Reshape for multi-head attention
    query = Axon.reshape(query, {:auto, :auto, num_heads, head_size})
    key = Axon.reshape(key, {:auto, :auto, num_heads, head_size})
    value = Axon.reshape(value, {:auto, :auto, num_heads, head_size})
    
    # Scaled dot-product attention
    attention_weights = Axon.layer([query, key], fn q, k, _opts ->
      scores = Nx.dot(q, [2, 3], k, [3, 2])
      scores = Nx.divide(scores, :math.sqrt(head_size))
      Nx.softmax(scores, axis: -1)
    end)
    
    attended = Axon.layer([attention_weights, value], fn weights, v, _opts ->
      Nx.dot(weights, [2, 3], v, [2, 3])
    end)
    
    # Concatenate heads and project
    attended
    |> Axon.reshape({:auto, :auto, model_size})
    |> Axon.dense(model_size, name: "attention_output")
  end

  defp feed_forward_network(input, model_size) do
    input
    |> Axon.dense(model_size * 4, activation: :relu, name: "ffn1")
    |> Axon.dense(model_size, name: "ffn2")
  end

  defp train_cnn_model(data, labels, options, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare data
    train_data = prepare_image_data(data, backend)
    train_labels = prepare_labels(labels, backend)
    
    # Build model
    model = build_cnn_for_data(train_data)
    
    # Training configuration
    optimizer = Polaris.Optimizers.adam(learning_rate: Keyword.get(options, :learning_rate, 0.001))
    loss_fn = &Axon.Losses.categorical_cross_entropy/2
    
    epochs = Keyword.get(options, :epochs, 50)
    batch_size = Keyword.get(options, :batch_size, 32)
    
    # Train the model
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:accuracy)
      |> Axon.Loop.run(create_training_batches(train_data, train_labels, batch_size), %{}, 
                       epochs: epochs, compiler: EXLA)
    
    %{model: model, params: params, input_shape: Nx.shape(train_data)}
  end

  defp train_rnn_model(sequences, labels, options, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare sequence data
    train_sequences = prepare_sequence_data(sequences, backend)
    train_labels = prepare_labels(labels, backend)
    
    # Build model
    model = build_rnn_for_data(train_sequences)
    
    # Training configuration
    optimizer = Polaris.Optimizers.adam(learning_rate: Keyword.get(options, :learning_rate, 0.001))
    loss_fn = &Axon.Losses.categorical_cross_entropy/2
    
    epochs = Keyword.get(options, :epochs, 50)
    batch_size = Keyword.get(options, :batch_size, 32)
    
    # Train the model
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:accuracy)
      |> Axon.Loop.run(create_training_batches(train_sequences, train_labels, batch_size), %{}, 
                       epochs: epochs, compiler: EXLA)
    
    %{model: model, params: params, sequence_length: Nx.axis_size(train_sequences, 1)}
  end

  defp train_transformer_model(sequences, targets, options, gpu_enabled) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Prepare data
    train_sequences = prepare_sequence_data(sequences, backend)
    train_targets = prepare_sequence_data(targets, backend)
    
    # Build model
    model = build_transformer_for_data(train_sequences)
    
    # Training configuration
    optimizer = Polaris.Optimizers.adam(learning_rate: Keyword.get(options, :learning_rate, 0.0001))
    loss_fn = &Axon.Losses.mean_squared_error/2
    
    epochs = Keyword.get(options, :epochs, 100)
    batch_size = Keyword.get(options, :batch_size, 16)
    
    # Train the model
    params =
      model
      |> Axon.Loop.trainer(loss_fn, optimizer)
      |> Axon.Loop.metric(:mean_squared_error)
      |> Axon.Loop.run(create_training_batches(train_sequences, train_targets, batch_size), %{}, 
                       epochs: epochs, compiler: EXLA)
    
    %{model: model, params: params, vocab_size: Nx.axis_size(train_sequences, 2)}
  end

  defp recognize_spatial_pattern(data, state) do
    case state.cnn_model do
      nil -> {:error, "CNN model not trained"}
      %{model: model, params: params} ->
        input_data = prepare_image_data(data, state.gpu_enabled)
        predictions = Axon.predict(model, params, %{"input" => input_data})
        
        confidence = Nx.reduce_max(predictions) |> Nx.to_number()
        predicted_class = Nx.argmax(predictions) |> Nx.to_number()
        
        {:ok, %{
          pattern_type: :spatial,
          predicted_class: predicted_class,
          confidence: confidence,
          is_recognized: confidence > state.recognition_threshold
        }}
    end
  end

  defp recognize_temporal_pattern(data, state) do
    case state.rnn_model do
      nil -> {:error, "RNN model not trained"}
      %{model: model, params: params} ->
        input_data = prepare_sequence_data(data, state.gpu_enabled)
        predictions = Axon.predict(model, params, %{"input" => input_data})
        
        confidence = Nx.reduce_max(predictions) |> Nx.to_number()
        predicted_class = Nx.argmax(predictions) |> Nx.to_number()
        
        {:ok, %{
          pattern_type: :temporal,
          predicted_class: predicted_class,
          confidence: confidence,
          is_recognized: confidence > state.recognition_threshold
        }}
    end
  end

  defp recognize_sequence_pattern(data, state) do
    case state.transformer_model do
      nil -> {:error, "Transformer model not trained"}
      %{model: model, params: params} ->
        input_data = prepare_sequence_data(data, state.gpu_enabled)
        predictions = Axon.predict(model, params, %{"input" => input_data})
        
        # Calculate similarity score with input
        similarity = calculate_sequence_similarity(input_data, predictions)
        
        {:ok, %{
          pattern_type: :sequence,
          similarity: similarity,
          confidence: similarity,
          is_recognized: similarity > state.recognition_threshold,
          reconstructed: predictions
        }}
    end
  end

  defp recognize_adaptive_pattern(data, state) do
    # Ensemble approach using all available models
    results = []
    
    results = if state.cnn_model do
      case recognize_spatial_pattern(data, state) do
        {:ok, result} -> [result | results]
        _ -> results
      end
    else
      results
    end
    
    results = if state.rnn_model do
      case recognize_temporal_pattern(data, state) do
        {:ok, result} -> [result | results]
        _ -> results
      end
    else
      results
    end
    
    results = if state.transformer_model do
      case recognize_sequence_pattern(data, state) do
        {:ok, result} -> [result | results]
        _ -> results
      end
    else
      results
    end
    
    case results do
      [] -> {:error, "No models available for pattern recognition"}
      results ->
        avg_confidence = Enum.map(results, & &1.confidence) |> Enum.sum() |> Kernel./(length(results))
        
        {:ok, %{
          pattern_type: :adaptive,
          ensemble_results: results,
          confidence: avg_confidence,
          is_recognized: avg_confidence > state.recognition_threshold
        }}
    end
  end

  # Helper functions
  
  defp prepare_image_data(data, gpu_enabled) when is_list(data) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    # Convert to tensor and normalize
    data
    |> normalize_image_data()
    |> Nx.tensor(backend: backend)
    |> Nx.to_type(:f32)
  end

  defp prepare_sequence_data(data, gpu_enabled) when is_list(data) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    data
    |> normalize_sequence_data()
    |> Nx.tensor(backend: backend)
    |> Nx.to_type(:f32)
  end

  defp prepare_labels(labels, gpu_enabled) when is_list(labels) do
    backend = if gpu_enabled, do: EXLA.Backend, else: Nx.BinaryBackend
    
    labels
    |> Nx.tensor(backend: backend)
    |> Nx.to_type(:s32)
  end

  defp normalize_image_data(data) do
    # Normalize image data to [0, 1] range
    Enum.map(data, fn image ->
      case image do
        list when is_list(list) ->
          Enum.map(list, fn pixel -> pixel / 255.0 end)
        _ -> 
          [image / 255.0]
      end
    end)
  end

  defp normalize_sequence_data(data) do
    # Basic sequence normalization
    flat_data = List.flatten(data)
    max_val = Enum.max(flat_data)
    min_val = Enum.min(flat_data)
    range = max_val - min_val
    
    if range > 0 do
      Enum.map(data, fn sequence ->
        Enum.map(sequence, fn value -> (value - min_val) / range end)
      end)
    else
      data
    end
  end

  defp build_cnn_for_data(data) do
    {_batch, height, width, channels} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, height, width, channels})
    |> Axon.conv(32, kernel_size: {3, 3}, activation: :relu, name: "conv1")
    |> Axon.max_pool(kernel_size: {2, 2})
    |> Axon.conv(64, kernel_size: {3, 3}, activation: :relu, name: "conv2")
    |> Axon.max_pool(kernel_size: {2, 2})
    |> Axon.flatten()
    |> Axon.dense(128, activation: :relu, name: "dense1")
    |> Axon.dropout(rate: 0.5)
    |> Axon.dense(10, activation: :softmax, name: "output")
  end

  defp build_rnn_for_data(data) do
    {_batch, seq_len, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, seq_len, features})
    |> Axon.lstm(64, name: "lstm1")
    |> then(fn {output, _state} -> output end)
    |> Axon.dense(32, activation: :relu, name: "dense1")
    |> Axon.dense(10, activation: :softmax, name: "output")
  end

  defp build_transformer_for_data(data) do
    {_batch, seq_len, features} = Nx.shape(data)
    
    Axon.input("input", shape: {nil, seq_len, features})
    |> Axon.dense(256, name: "input_projection")
    |> add_positional_encoding(256)
    |> multi_head_attention(8, 256)
    |> Axon.dense(features, name: "output_projection")
  end

  defp create_training_batches(data, labels, batch_size) do
    data
    |> Nx.to_batched(batch_size)
    |> Stream.zip(Nx.to_batched(labels, batch_size))
    |> Stream.map(fn {batch_data, batch_labels} -> 
      %{"input" => batch_data, "target" => batch_labels} 
    end)
  end

  defp calculate_sequence_similarity(input, output) do
    # Calculate cosine similarity
    input_flat = Nx.flatten(input)
    output_flat = Nx.flatten(output)
    
    dot_product = Nx.dot(input_flat, output_flat)
    input_norm = Nx.LinAlg.norm(input_flat)
    output_norm = Nx.LinAlg.norm(output_flat)
    
    similarity = Nx.divide(dot_product, Nx.multiply(input_norm, output_norm))
    Nx.to_number(similarity)
  end

  defp gpu_available? do
    case Application.get_env(:exla, :clients, []) do
      [] -> false
      clients -> Enum.any?(clients, fn {_name, opts} -> opts[:platform] == :gpu end)
    end
  end
end