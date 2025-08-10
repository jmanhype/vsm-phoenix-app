defmodule VsmPhoenix.Telemetry.SignalAggregator do
  @moduledoc """
  Signal Aggregation and Transformation Pipeline
  
  Aggregates multiple telemetry signals into higher-level insights:
  - Multi-signal fusion and composition
  - Hierarchical aggregation (system -> subsystem -> component)
  - Time-based windowing and bucketing
  - Statistical aggregation functions
  - Signal transformation pipelines
  """
  
  use GenServer
  require Logger
  
  @aggregation_functions %{
    mean: :mean,
    median: :median,
    mode: :mode,
    sum: :sum,
    min: :min,
    max: :max,
    std_dev: :std_dev,
    percentile: :percentile,
    variance: :variance,
    rms: :rms,
    harmonic_mean: :harmonic_mean,
    geometric_mean: :geometric_mean
  }
  
  @time_windows %{
    instant: 0,
    second: 1_000_000,
    minute: 60_000_000,
    hour: 3_600_000_000,
    day: 86_400_000_000
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_aggregation_pipeline(pipeline_id, config) do
    GenServer.call(__MODULE__, {:create_pipeline, pipeline_id, config})
  end
  
  def aggregate_signals(signal_ids, aggregation_type, options \\ %{}) do
    GenServer.call(__MODULE__, {:aggregate, signal_ids, aggregation_type, options})
  end
  
  def create_composite_signal(output_id, input_signals, transformation) do
    GenServer.call(__MODULE__, {:create_composite, output_id, input_signals, transformation})
  end
  
  def aggregate_by_time(signal_id, time_window, aggregation_func) do
    GenServer.call(__MODULE__, {:aggregate_time, signal_id, time_window, aggregation_func})
  end
  
  def create_hierarchical_aggregation(hierarchy_spec) do
    GenServer.call(__MODULE__, {:create_hierarchy, hierarchy_spec})
  end
  
  def get_aggregation_results(aggregation_id) do
    GenServer.call(__MODULE__, {:get_results, aggregation_id})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("📊 Signal Aggregator initializing...")
    
    # ETS tables for aggregation state
    :ets.new(:aggregation_pipelines, [:set, :public, :named_table])
    :ets.new(:aggregation_results, [:set, :public, :named_table])
    :ets.new(:composite_signals, [:set, :public, :named_table])
    
    # Start aggregation processor
    schedule_aggregation_processing()
    
    state = %{
      pipelines: %{},
      active_aggregations: %{},
      hierarchies: %{},
      processing_queue: :queue.new()
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:create_pipeline, pipeline_id, config}, _from, state) do
    Logger.info("🔧 Creating aggregation pipeline: #{pipeline_id}")
    
    pipeline = %{
      id: pipeline_id,
      input_signals: config.input_signals,
      stages: parse_pipeline_stages(config.stages),
      output_signal: config.output_signal,
      trigger: config.trigger || :continuous,
      metadata: config.metadata || %{},
      created_at: DateTime.utc_now()
    }
    
    # Store pipeline
    :ets.insert(:aggregation_pipelines, {pipeline_id, pipeline})
    
    # Initialize pipeline state
    new_state = %{state | pipelines: Map.put(state.pipelines, pipeline_id, pipeline)}
    
    {:reply, {:ok, pipeline}, new_state}
  end
  
  @impl true
  def handle_call({:aggregate, signal_ids, aggregation_type, options}, _from, state) do
    result = perform_aggregation(signal_ids, aggregation_type, options)
    
    # Store result
    result_id = generate_result_id()
    :ets.insert(:aggregation_results, {result_id, result})
    
    {:reply, {:ok, result}, state}
  end
  
  @impl true
  def handle_call({:create_composite, output_id, input_signals, transformation}, _from, state) do
    composite = create_composite_signal_impl(output_id, input_signals, transformation)
    
    # Register as new signal
    VsmPhoenix.Telemetry.AnalogArchitect.register_signal(output_id, %{
      sampling_rate: :standard,
      metadata: %{
        type: :composite,
        inputs: input_signals,
        transformation: inspect(transformation)
      }
    })
    
    {:reply, {:ok, composite}, state}
  end
  
  @impl true
  def handle_call({:aggregate_time, signal_id, time_window, aggregation_func}, _from, state) do
    time_aggregation = perform_time_aggregation(signal_id, time_window, aggregation_func)
    
    {:reply, {:ok, time_aggregation}, state}
  end
  
  @impl true
  def handle_call({:create_hierarchy, hierarchy_spec}, _from, state) do
    hierarchy = build_aggregation_hierarchy(hierarchy_spec)
    
    hierarchy_id = hierarchy_spec.id || generate_hierarchy_id()
    new_hierarchies = Map.put(state.hierarchies, hierarchy_id, hierarchy)
    
    {:reply, {:ok, hierarchy}, %{state | hierarchies: new_hierarchies}}
  end
  
  @impl true
  def handle_call({:get_results, aggregation_id}, _from, state) do
    case :ets.lookup(:aggregation_results, aggregation_id) do
      [{^aggregation_id, result}] -> {:reply, {:ok, result}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_info(:process_aggregations, state) do
    # Process all active pipelines
    process_active_pipelines(state.pipelines)
    
    # Schedule next processing
    schedule_aggregation_processing()
    
    {:noreply, state}
  end
  
  # Aggregation Implementation
  
  defp perform_aggregation(signal_ids, :statistical, options) do
    # Gather signal data
    signals_data = Enum.map(signal_ids, &get_signal_values/1)
    
    # Align signals by timestamp
    aligned_data = align_signals_by_timestamp(signals_data)
    
    # Calculate statistics
    stats = calculate_multi_signal_statistics(aligned_data, options)
    
    %{
      type: :statistical_aggregation,
      input_signals: signal_ids,
      statistics: stats,
      sample_count: length(aligned_data),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp perform_aggregation(signal_ids, :weighted, %{weights: weights} = options) do
    # Weighted aggregation
    signals_data = Enum.map(signal_ids, &get_signal_values/1)
    aligned_data = align_signals_by_timestamp(signals_data)
    
    weighted_values = calculate_weighted_aggregation(aligned_data, weights)
    
    %{
      type: :weighted_aggregation,
      input_signals: signal_ids,
      weights: weights,
      aggregated_values: weighted_values,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp perform_aggregation(signal_ids, :fusion, options) do
    # Multi-signal fusion using Kalman filter or similar
    signals_data = Enum.map(signal_ids, &get_signal_values/1)
    
    fusion_result = perform_signal_fusion(signals_data, options)
    
    %{
      type: :signal_fusion,
      input_signals: signal_ids,
      fusion_method: options[:method] || :kalman,
      fused_signal: fusion_result,
      confidence: calculate_fusion_confidence(fusion_result),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp perform_aggregation(signal_ids, :correlation_matrix, _options) do
    # Build correlation matrix
    signals_data = Enum.map(signal_ids, &get_signal_values/1)
    
    correlation_matrix = build_correlation_matrix(signals_data)
    principal_components = calculate_principal_components(correlation_matrix)
    
    %{
      type: :correlation_aggregation,
      input_signals: signal_ids,
      correlation_matrix: correlation_matrix,
      principal_components: principal_components,
      explained_variance: calculate_explained_variance(principal_components),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp create_composite_signal_impl(output_id, input_signals, transformation) do
    # Get input signal data
    input_data = Enum.map(input_signals, fn signal_id ->
      {signal_id, get_signal_values(signal_id)}
    end)
    
    # Apply transformation
    composite_values = apply_signal_transformation(input_data, transformation)
    
    # Store composite signal
    composite = %{
      id: output_id,
      type: :composite,
      inputs: input_signals,
      transformation: transformation,
      values: composite_values,
      created_at: DateTime.utc_now()
    }
    
    :ets.insert(:composite_signals, {output_id, composite})
    
    # Feed composite values to the analog architect
    Enum.each(composite_values, fn sample ->
      VsmPhoenix.Telemetry.AnalogArchitect.sample_signal(output_id, sample.value, sample.metadata)
    end)
    
    composite
  end
  
  defp perform_time_aggregation(signal_id, time_window, aggregation_func) do
    signal_data = get_signal_data(signal_id)
    
    # Get window size in microseconds
    window_size = @time_windows[time_window] || time_window
    
    # Group samples by time window
    windowed_data = group_by_time_window(signal_data, window_size)
    
    # Apply aggregation function to each window
    aggregated_windows = Enum.map(windowed_data, fn {window_start, samples} ->
      values = Enum.map(samples, & &1.value)
      
      aggregated_value = case aggregation_func do
        func when is_function(func) -> func.(values)
        func_name when is_atom(func_name) -> 
          apply_aggregation_function(func_name, values)
      end
      
      %{
        window_start: window_start,
        window_end: window_start + window_size,
        aggregated_value: aggregated_value,
        sample_count: length(samples),
        metadata: aggregate_metadata(samples)
      }
    end)
    
    %{
      signal_id: signal_id,
      time_window: time_window,
      window_size: window_size,
      aggregation_function: aggregation_func,
      aggregated_data: aggregated_windows,
      total_windows: length(aggregated_windows)
    }
  end
  
  defp build_aggregation_hierarchy(hierarchy_spec) do
    # Build hierarchical aggregation structure
    levels = hierarchy_spec.levels
    
    hierarchy = Enum.reduce(levels, %{}, fn level, acc ->
      level_aggregations = Enum.map(level.nodes, fn node ->
        %{
          id: node.id,
          input_signals: node.inputs,
          aggregation_type: node.aggregation_type,
          parent: node.parent,
          children: node.children || []
        }
      end)
      
      Map.put(acc, level.name, level_aggregations)
    end)
    
    %{
      id: hierarchy_spec.id,
      name: hierarchy_spec.name,
      levels: hierarchy,
      root_signals: extract_root_signals(hierarchy),
      aggregation_order: determine_aggregation_order(hierarchy)
    }
  end
  
  # Pipeline Processing
  
  defp parse_pipeline_stages(stages) do
    Enum.map(stages, fn stage ->
      %{
        name: stage.name,
        type: stage.type,
        function: parse_stage_function(stage.function),
        params: stage.params || %{},
        output: stage.output
      }
    end)
  end
  
  defp parse_stage_function(func) when is_function(func), do: func
  defp parse_stage_function(func_name) when is_atom(func_name) do
    case @aggregation_functions[func_name] do
      nil -> fn x -> x end
      :mean -> &VsmPhoenix.Telemetry.SignalAggregator.Statistics.mean/1
      :median -> &VsmPhoenix.Telemetry.SignalAggregator.Statistics.median/1
      :mode -> &VsmPhoenix.Telemetry.SignalAggregator.Statistics.mode/1
      :sum -> &Enum.sum/1
      :min -> &Enum.min/1
      :max -> &Enum.max/1
      :std_dev -> &VsmPhoenix.Telemetry.SignalAggregator.Statistics.standard_deviation/1
      :percentile -> &VsmPhoenix.Telemetry.SignalAggregator.Statistics.percentile/2
      :variance -> &VsmPhoenix.Telemetry.SignalAggregator.Statistics.variance/1
      :rms -> &calculate_rms/1
      :harmonic_mean -> &calculate_harmonic_mean/1
      :geometric_mean -> &calculate_geometric_mean/1
    end
  end
  defp parse_stage_function(_), do: fn x -> x end
  
  defp process_active_pipelines(pipelines) do
    Enum.each(pipelines, fn {_id, pipeline} ->
      if should_process_pipeline?(pipeline) do
        process_pipeline(pipeline)
      end
    end)
  end
  
  defp should_process_pipeline?(%{trigger: :continuous}), do: true
  defp should_process_pipeline?(%{trigger: {:interval, interval}, last_run: last_run}) do
    DateTime.diff(DateTime.utc_now(), last_run, :millisecond) >= interval
  end
  defp should_process_pipeline?(_), do: false
  
  defp process_pipeline(pipeline) do
    # Get input signal data
    input_data = Enum.map(pipeline.input_signals, fn signal_id ->
      {signal_id, get_signal_values(signal_id)}
    end)
    
    # Process through stages
    result = Enum.reduce(pipeline.stages, input_data, fn stage, data ->
      apply_pipeline_stage(stage, data)
    end)
    
    # Output result
    if pipeline.output_signal do
      output_to_signal(pipeline.output_signal, result)
    end
    
    # Update pipeline last run time
    :ets.update_element(:aggregation_pipelines, pipeline.id, {2, %{pipeline | last_run: DateTime.utc_now()}})
  end
  
  defp apply_pipeline_stage(stage, data) do
    case stage.type do
      :map -> apply_map_stage(stage, data)
      :filter -> apply_filter_stage(stage, data)
      :reduce -> apply_reduce_stage(stage, data)
      :window -> apply_window_stage(stage, data)
      :transform -> apply_transform_stage(stage, data)
    end
  end
  
  # Helper Functions
  
  defp get_signal_data(signal_id) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] -> :queue.to_list(buffer)
      [] -> []
    end
  end
  
  defp get_signal_values(signal_id) do
    get_signal_data(signal_id)
    |> Enum.map(& &1.value)
  end
  
  defp align_signals_by_timestamp(signals_data) do
    # Find common timestamp range
    all_timestamps = signals_data
    |> Enum.flat_map(fn signal ->
      Enum.map(signal, & &1.timestamp)
    end)
    |> Enum.uniq()
    |> Enum.sort()
    
    # Interpolate values for each timestamp
    Enum.map(all_timestamps, fn timestamp ->
      values = Enum.map(signals_data, fn signal ->
        interpolate_value_at_timestamp(signal, timestamp)
      end)
      
      %{
        timestamp: timestamp,
        values: values
      }
    end)
  end
  
  defp interpolate_value_at_timestamp(signal_data, timestamp) do
    # Find surrounding samples
    {before_samples, after_samples} = signal_data
    |> Enum.split_while(fn sample -> sample.timestamp <= timestamp end)
    
    case {List.last(before_samples), List.first(after_samples)} do
      {nil, nil} -> 0.0
      {nil, sample} -> sample.value
      {sample, nil} -> sample.value
      {s1, s2} ->
        # Linear interpolation
        t1 = s1.timestamp
        t2 = s2.timestamp
        v1 = s1.value
        v2 = s2.value
        
        if t2 == t1 do
          v1
        else
          v1 + (v2 - v1) * (timestamp - t1) / (t2 - t1)
        end
    end
  end
  
  defp calculate_multi_signal_statistics(aligned_data, options) do
    # Calculate statistics across all signals
    %{
      mean: calculate_vector_mean(aligned_data),
      covariance_matrix: calculate_covariance_matrix(aligned_data),
      correlation_matrix: calculate_correlation_matrix(aligned_data),
      ranges: calculate_signal_ranges(aligned_data),
      synchrony: calculate_signal_synchrony(aligned_data)
    }
  end
  
  defp calculate_vector_mean(aligned_data) do
    n = length(aligned_data)
    
    if n > 0 do
      sum_vectors = Enum.reduce(aligned_data, nil, fn point, acc ->
        if acc do
          Enum.zip(acc, point.values)
          |> Enum.map(fn {a, b} -> a + b end)
        else
          point.values
        end
      end)
      
      Enum.map(sum_vectors, &(&1 / n))
    else
      []
    end
  end
  
  defp calculate_covariance_matrix(aligned_data) do
    # Simplified covariance calculation
    means = calculate_vector_mean(aligned_data)
    n_signals = length(means)
    
    # Initialize covariance matrix
    matrix = for i <- 0..(n_signals-1) do
      for j <- 0..(n_signals-1) do
        calculate_covariance_element(aligned_data, means, i, j)
      end
    end
    
    matrix
  end
  
  defp calculate_covariance_element(aligned_data, means, i, j) do
    n = length(aligned_data)
    
    if n > 1 do
      sum = Enum.reduce(aligned_data, 0.0, fn point, acc ->
        vi = Enum.at(point.values, i) - Enum.at(means, i)
        vj = Enum.at(point.values, j) - Enum.at(means, j)
        acc + vi * vj
      end)
      
      sum / (n - 1)
    else
      0.0
    end
  end
  
  defp calculate_correlation_matrix(aligned_data) do
    cov_matrix = calculate_covariance_matrix(aligned_data)
    n_signals = length(cov_matrix)
    
    # Convert covariance to correlation
    for i <- 0..(n_signals-1) do
      for j <- 0..(n_signals-1) do
        cov_ij = cov_matrix |> Enum.at(i) |> Enum.at(j)
        var_i = cov_matrix |> Enum.at(i) |> Enum.at(i)
        var_j = cov_matrix |> Enum.at(j) |> Enum.at(j)
        
        if var_i > 0 and var_j > 0 do
          cov_ij / :math.sqrt(var_i * var_j)
        else
          0.0
        end
      end
    end
  end
  
  defp calculate_signal_ranges(aligned_data) do
    if length(aligned_data) == 0 do
      []
    else
      n_signals = length(List.first(aligned_data).values)
      
      Enum.map(0..(n_signals-1), fn i ->
        values = Enum.map(aligned_data, fn point ->
          Enum.at(point.values, i)
        end)
        
        %{
          min: Enum.min(values),
          max: Enum.max(values),
          range: Enum.max(values) - Enum.min(values)
        }
      end)
    end
  end
  
  defp calculate_signal_synchrony(aligned_data) do
    # Phase synchrony calculation
    correlation_matrix = calculate_correlation_matrix(aligned_data)
    
    # Average correlation as synchrony measure
    n = length(correlation_matrix)
    
    if n > 1 do
      sum = for i <- 0..(n-1), j <- (i+1)..(n-1) do
        abs(correlation_matrix |> Enum.at(i) |> Enum.at(j))
      end
      |> Enum.sum()
      
      count = n * (n - 1) / 2
      sum / count
    else
      1.0
    end
  end
  
  defp calculate_weighted_aggregation(aligned_data, weights) do
    Enum.map(aligned_data, fn point ->
      weighted_sum = point.values
      |> Enum.zip(weights)
      |> Enum.map(fn {v, w} -> v * w end)
      |> Enum.sum()
      
      %{
        timestamp: point.timestamp,
        value: weighted_sum
      }
    end)
  end
  
  defp perform_signal_fusion(signals_data, options) do
    method = options[:method] || :kalman
    
    case method do
      :kalman -> kalman_signal_fusion(signals_data, options)
      :bayesian -> bayesian_signal_fusion(signals_data, options)
      :dempster_shafer -> dempster_shafer_fusion(signals_data, options)
      _ -> simple_average_fusion(signals_data)
    end
  end
  
  defp kalman_signal_fusion(_signals_data, _options) do
    # Simplified Kalman fusion
    # In production, implement full multi-sensor Kalman filter
    []
  end
  
  defp bayesian_signal_fusion(_signals_data, _options) do
    # Bayesian sensor fusion
    []
  end
  
  defp dempster_shafer_fusion(_signals_data, _options) do
    # Dempster-Shafer evidence theory fusion
    []
  end
  
  defp simple_average_fusion(signals_data) do
    # Simple averaging as fallback
    aligned = align_signals_by_timestamp(signals_data)
    
    Enum.map(aligned, fn point ->
      avg_value = Enum.sum(point.values) / length(point.values)
      
      %{
        timestamp: point.timestamp,
        value: avg_value,
        confidence: 0.8
      }
    end)
  end
  
  defp calculate_fusion_confidence(fusion_result) do
    # Calculate confidence based on signal agreement
    if length(fusion_result) > 0 do
      0.9  # Simplified
    else
      0.0
    end
  end
  
  defp build_correlation_matrix(signals_data) do
    n = length(signals_data)
    
    for i <- 0..(n-1) do
      for j <- 0..(n-1) do
        if i == j do
          1.0
        else
          Statistics.correlation(
            Enum.at(signals_data, i),
            Enum.at(signals_data, j)
          )
        end
      end
    end
  end
  
  defp calculate_principal_components(correlation_matrix) do
    # Simplified PCA - in production use proper eigenvalue decomposition
    %{
      components: [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
      eigenvalues: [2.5, 0.8, 0.2],
      loadings: correlation_matrix
    }
  end
  
  defp calculate_explained_variance(principal_components) do
    eigenvalues = principal_components.eigenvalues
    total_variance = Enum.sum(eigenvalues)
    
    eigenvalues
    |> Enum.map(&(&1 / total_variance))
    |> Enum.scan(&+/2)
  end
  
  defp apply_signal_transformation(input_data, transformation) when is_function(transformation) do
    # Apply custom transformation function
    transformation.(input_data)
  end
  
  defp apply_signal_transformation(input_data, {:formula, formula}) do
    # Parse and apply formula transformation
    apply_formula_transformation(input_data, formula)
  end
  
  defp apply_signal_transformation(input_data, {:pipeline, stages}) do
    # Apply pipeline of transformations
    Enum.reduce(stages, input_data, fn stage, data ->
      apply_signal_transformation(data, stage)
    end)
  end
  
  defp apply_formula_transformation(_input_data, _formula) do
    # Formula parser implementation
    []
  end
  
  defp group_by_time_window(signal_data, window_size) do
    signal_data
    |> Enum.group_by(fn sample ->
      div(sample.timestamp, window_size) * window_size
    end)
    |> Enum.sort_by(fn {window_start, _} -> window_start end)
  end
  
  defp apply_aggregation_function(func_name, values) do
    case @aggregation_functions[func_name] do
      nil -> Statistics.mean(values)
      func -> func.(values)
    end
  end
  
  defp aggregate_metadata(samples) do
    # Aggregate metadata from samples
    %{
      sources: samples |> Enum.map(& &1.metadata[:source]) |> Enum.uniq(),
      quality: samples |> Enum.map(& &1.metadata[:quality] || 1.0) |> Statistics.mean()
    }
  end
  
  defp extract_root_signals(hierarchy) do
    # Find all leaf signals
    hierarchy
    |> Map.values()
    |> List.flatten()
    |> Enum.flat_map(& &1.input_signals)
    |> Enum.uniq()
  end
  
  defp determine_aggregation_order(hierarchy) do
    # Topological sort for hierarchical processing
    []
  end
  
  defp apply_map_stage(stage, data) do
    Enum.map(data, fn {signal_id, values} ->
      {signal_id, Enum.map(values, stage.function)}
    end)
  end
  
  defp apply_filter_stage(stage, data) do
    Enum.map(data, fn {signal_id, values} ->
      {signal_id, Enum.filter(values, stage.function)}
    end)
  end
  
  defp apply_reduce_stage(stage, data) do
    Enum.map(data, fn {signal_id, values} ->
      {signal_id, Enum.reduce(values, stage.params[:initial], stage.function)}
    end)
  end
  
  defp apply_window_stage(stage, data) do
    window_size = stage.params[:size] || 10
    
    Enum.map(data, fn {signal_id, values} ->
      windowed = values
      |> Enum.chunk_every(window_size, window_size - 1, :discard)
      |> Enum.map(stage.function)
      
      {signal_id, windowed}
    end)
  end
  
  defp apply_transform_stage(stage, data) do
    stage.function.(data)
  end
  
  defp output_to_signal(signal_id, result) do
    # Send aggregated results to output signal
    timestamp = :erlang.system_time(:microsecond)
    
    value = case result do
      [{_, v}] when is_number(v) -> v
      values when is_list(values) -> Statistics.mean(values)
      v when is_number(v) -> v
      _ -> 0.0
    end
    
    VsmPhoenix.Telemetry.AnalogArchitect.sample_signal(
      signal_id,
      value,
      %{aggregated: true, timestamp: timestamp}
    )
  end
  
  # Utility functions
  
  defp generate_result_id do
    "result_#{:erlang.unique_integer([:positive])}"
  end
  
  defp generate_hierarchy_id do
    "hierarchy_#{:erlang.unique_integer([:positive])}"
  end
  
  defp schedule_aggregation_processing do
    Process.send_after(self(), :process_aggregations, 1000)  # Every second
  end
  
  defp calculate_rms(values) do
    if length(values) > 0 do
      values
      |> Enum.map(&(&1 * &1))
      |> Enum.sum()
      |> Kernel./(length(values))
      |> :math.sqrt()
    else
      0.0
    end
  end
  
  defp calculate_harmonic_mean(values) do
    values = Enum.filter(values, &(&1 != 0))
    
    if length(values) > 0 do
      reciprocal_sum = values
      |> Enum.map(&(1 / &1))
      |> Enum.sum()
      
      length(values) / reciprocal_sum
    else
      0.0
    end
  end
  
  defp calculate_geometric_mean(values) do
    positive_values = Enum.filter(values, &(&1 > 0))
    
    if length(positive_values) > 0 do
      product = Enum.reduce(positive_values, 1.0, &*/2)
      :math.pow(product, 1 / length(positive_values))
    else
      0.0
    end
  end
end

# Extended Statistics module
defmodule VsmPhoenix.Telemetry.SignalAggregator.Statistics do
  def mean([]), do: 0
  def mean(values), do: Enum.sum(values) / length(values)
  
  def median([]), do: 0
  def median(values) do
    sorted = Enum.sort(values)
    mid = div(length(sorted), 2)
    
    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end
  
  def mode([]), do: nil
  def mode(values) do
    frequencies = Enum.frequencies(values)
    {value, _count} = Enum.max_by(frequencies, fn {_v, count} -> count end)
    value
  end
  
  def variance([]), do: 0
  def variance(values) do
    m = mean(values)
    values
    |> Enum.map(fn v -> (v - m) * (v - m) end)
    |> Enum.sum()
    |> Kernel./(length(values))
  end
  
  def standard_deviation(values), do: :math.sqrt(variance(values))
  
  def percentile([], _p), do: 0
  def percentile(values, p) when p >= 0 and p <= 100 do
    sorted = Enum.sort(values)
    k = (length(sorted) - 1) * p / 100
    f = :erlang.floor(k)
    c = :erlang.ceil(k)
    
    if f == c do
      Enum.at(sorted, round(k))
    else
      v0 = Enum.at(sorted, round(f))
      v1 = Enum.at(sorted, round(c))
      v0 + (k - f) * (v1 - v0)
    end
  end
  
  def correlation(x_values, y_values) do
    n = min(length(x_values), length(y_values))
    
    if n < 2 do
      0.0
    else
      x = Enum.take(x_values, n)
      y = Enum.take(y_values, n)
      
      x_mean = mean(x)
      y_mean = mean(y)
      
      numerator = Enum.zip(x, y)
      |> Enum.map(fn {xi, yi} -> (xi - x_mean) * (yi - y_mean) end)
      |> Enum.sum()
      
      x_std = standard_deviation(x)
      y_std = standard_deviation(y)
      
      denominator = n * x_std * y_std
      
      if denominator > 0, do: numerator / denominator, else: 0
    end
  end
end