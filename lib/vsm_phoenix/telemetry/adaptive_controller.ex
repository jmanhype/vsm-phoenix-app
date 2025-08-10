defmodule VsmPhoenix.Telemetry.AdaptiveController do
  @moduledoc """
  Adaptive Threshold and Auto-Scaling Controller
  
  Implements intelligent, self-adjusting control mechanisms:
  - Dynamic threshold adaptation based on signal characteristics
  - Auto-scaling for optimal signal range utilization
  - Adaptive noise filtering and suppression
  - Self-tuning control parameters
  - Hysteresis and dead-band management
  """
  
  use GenServer
  require Logger
  
  @adaptation_strategies [
    :statistical,      # Based on mean, std dev
    :percentile,       # Based on percentile ranges
    :entropy,          # Based on information entropy
    :gradient,         # Based on rate of change
    :machine_learning, # ML-based adaptation
    :fuzzy_logic       # Fuzzy control rules
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_adaptive_threshold(signal_id, config) do
    GenServer.call(__MODULE__, {:create_threshold, signal_id, config})
  end
  
  def create_auto_scaler(signal_id, config) do
    GenServer.call(__MODULE__, {:create_scaler, signal_id, config})
  end
  
  def apply_adaptive_control(signal_id, value) do
    GenServer.call(__MODULE__, {:apply_control, signal_id, value})
  end
  
  def update_adaptation(signal_id, feedback) do
    GenServer.cast(__MODULE__, {:update_adaptation, signal_id, feedback})
  end
  
  def get_control_parameters(signal_id) do
    GenServer.call(__MODULE__, {:get_parameters, signal_id})
  end
  
  def enable_learning_mode(signal_id, enabled \\ true) do
    GenServer.cast(__MODULE__, {:set_learning_mode, signal_id, enabled})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🎚️ Adaptive Controller initializing...")
    
    # ETS tables for control state
    :ets.new(:adaptive_thresholds, [:set, :public, :named_table])
    :ets.new(:auto_scalers, [:set, :public, :named_table])
    :ets.new(:control_history, [:bag, :public, :named_table])
    :ets.new(:adaptation_models, [:set, :public, :named_table])
    
    # Start adaptation loop
    schedule_adaptation_update()
    
    state = %{
      controllers: %{},
      learning_signals: MapSet.new(),
      adaptation_rate: 0.1,
      update_interval: 5000  # 5 seconds
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:create_threshold, signal_id, config}, _from, state) do
    Logger.info("📏 Creating adaptive threshold for signal: #{signal_id}")
    
    threshold_controller = %{
      signal_id: signal_id,
      strategy: config[:strategy] || :statistical,
      initial_threshold: config[:initial_threshold] || 0.0,
      current_threshold: config[:initial_threshold] || 0.0,
      adaptation_rate: config[:adaptation_rate] || 0.1,
      history_size: config[:history_size] || 1000,
      hysteresis: config[:hysteresis] || 0.05,
      dead_band: config[:dead_band] || 0.01,
      constraints: config[:constraints] || %{},
      statistics: initialize_statistics(),
      created_at: DateTime.utc_now()
    }
    
    :ets.insert(:adaptive_thresholds, {signal_id, threshold_controller})
    
    {:reply, {:ok, threshold_controller}, state}
  end
  
  @impl true
  def handle_call({:create_scaler, signal_id, config}, _from, state) do
    Logger.info("⚖️ Creating auto-scaler for signal: #{signal_id}")
    
    scaler = %{
      signal_id: signal_id,
      scaling_mode: config[:mode] || :dynamic_range,
      input_range: config[:input_range] || {-1.0, 1.0},
      output_range: config[:output_range] || {0.0, 1.0},
      current_scale: 1.0,
      current_offset: 0.0,
      adaptation_speed: config[:adaptation_speed] || 0.05,
      outlier_handling: config[:outlier_handling] || :clip,
      statistics: initialize_scaling_statistics(),
      created_at: DateTime.utc_now()
    }
    
    :ets.insert(:auto_scalers, {signal_id, scaler})
    
    {:reply, {:ok, scaler}, state}
  end
  
  @impl true
  def handle_call({:apply_control, signal_id, value}, _from, state) do
    # Apply both threshold and scaling if configured
    controlled_value = value
    |> apply_threshold_control(signal_id)
    |> apply_scaling_control(signal_id)
    
    # Record in history
    record_control_application(signal_id, value, controlled_value)
    
    # Update statistics
    update_control_statistics(signal_id, value, controlled_value)
    
    {:reply, {:ok, controlled_value}, state}
  end
  
  @impl true
  def handle_call({:get_parameters, signal_id}, _from, state) do
    threshold_params = case :ets.lookup(:adaptive_thresholds, signal_id) do
      [{^signal_id, threshold}] -> %{threshold: threshold}
      [] -> %{}
    end
    
    scaler_params = case :ets.lookup(:auto_scalers, signal_id) do
      [{^signal_id, scaler}] -> %{scaler: scaler}
      [] -> %{}
    end
    
    params = Map.merge(threshold_params, scaler_params)
    
    {:reply, {:ok, params}, state}
  end
  
  @impl true
  def handle_cast({:update_adaptation, signal_id, feedback}, state) do
    # Update adaptation based on feedback
    update_threshold_adaptation(signal_id, feedback)
    update_scaler_adaptation(signal_id, feedback)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:set_learning_mode, signal_id, enabled}, state) do
    new_learning_signals = if enabled do
      MapSet.put(state.learning_signals, signal_id)
    else
      MapSet.delete(state.learning_signals, signal_id)
    end
    
    {:noreply, %{state | learning_signals: new_learning_signals}}
  end
  
  @impl true
  def handle_info(:update_adaptations, state) do
    # Periodic adaptation update
    update_all_adaptations(state.learning_signals)
    
    # Schedule next update
    schedule_adaptation_update()
    
    {:noreply, state}
  end
  
  # Threshold Control Implementation
  
  defp apply_threshold_control(value, signal_id) do
    case :ets.lookup(:adaptive_thresholds, signal_id) do
      [{^signal_id, threshold}] ->
        apply_threshold_with_hysteresis(value, threshold)
      [] ->
        value
    end
  end
  
  defp apply_threshold_with_hysteresis(value, threshold) do
    current = threshold.current_threshold
    hysteresis = threshold.hysteresis
    dead_band = threshold.dead_band
    
    cond do
      # Above threshold with hysteresis
      value > current + hysteresis ->
        {:triggered, value, :above}
        
      # Below threshold with hysteresis
      value < current - hysteresis ->
        {:triggered, value, :below}
        
      # Within dead band
      abs(value - current) < dead_band ->
        {:dead_band, value, :neutral}
        
      # Normal operation
      true ->
        {:normal, value, :neutral}
    end
  end
  
  defp update_threshold_adaptation(signal_id, feedback) do
    case :ets.lookup(:adaptive_thresholds, signal_id) do
      [{^signal_id, threshold}] ->
        new_threshold = adapt_threshold(threshold, feedback)
        :ets.insert(:adaptive_thresholds, {signal_id, new_threshold})
      [] ->
        :ok
    end
  end
  
  defp adapt_threshold(threshold, feedback) do
    case threshold.strategy do
      :statistical ->
        adapt_statistical_threshold(threshold, feedback)
      :percentile ->
        adapt_percentile_threshold(threshold, feedback)
      :entropy ->
        adapt_entropy_threshold(threshold, feedback)
      :gradient ->
        adapt_gradient_threshold(threshold, feedback)
      :machine_learning ->
        adapt_ml_threshold(threshold, feedback)
      :fuzzy_logic ->
        adapt_fuzzy_threshold(threshold, feedback)
    end
  end
  
  defp adapt_statistical_threshold(threshold, feedback) do
    stats = threshold.statistics
    
    # Update statistics with new feedback
    new_stats = update_statistics(stats, feedback)
    
    # Calculate new threshold based on statistics
    mean = new_stats.mean
    std_dev = new_stats.std_dev
    
    # Adaptive threshold: mean + k * std_dev
    k = calculate_adaptive_k(new_stats, threshold.adaptation_rate)
    new_threshold_value = mean + k * std_dev
    
    # Apply constraints
    constrained_threshold = apply_threshold_constraints(new_threshold_value, threshold.constraints)
    
    %{threshold |
      current_threshold: constrained_threshold,
      statistics: new_stats
    }
  end
  
  defp adapt_percentile_threshold(threshold, feedback) do
    stats = threshold.statistics
    percentile = Map.get(threshold, :target_percentile, 95)
    
    # Update value history
    new_stats = update_percentile_statistics(stats, feedback)
    
    # Calculate threshold at target percentile
    new_threshold_value = calculate_percentile(new_stats.values, percentile)
    
    %{threshold |
      current_threshold: new_threshold_value,
      statistics: new_stats
    }
  end
  
  defp adapt_entropy_threshold(threshold, feedback) do
    # Information-theoretic adaptation
    stats = threshold.statistics
    
    # Calculate entropy of recent values
    entropy = calculate_entropy(stats.recent_values)
    
    # Adjust threshold based on entropy
    # High entropy = more variation = wider threshold
    # Low entropy = less variation = tighter threshold
    entropy_factor = entropy / :math.log(2)  # Normalize
    
    base_threshold = stats.mean
    threshold_width = stats.std_dev * (1 + entropy_factor)
    
    new_threshold_value = base_threshold + threshold_width
    
    %{threshold |
      current_threshold: new_threshold_value,
      statistics: Map.put(stats, :entropy, entropy)
    }
  end
  
  defp adapt_gradient_threshold(threshold, feedback) do
    # Rate-of-change based adaptation
    stats = threshold.statistics
    
    # Calculate gradient (rate of change)
    gradient = calculate_signal_gradient(stats.recent_values)
    
    # Adjust threshold based on gradient
    # High gradient = rapid change = predictive threshold
    # Low gradient = slow change = reactive threshold
    prediction_factor = min(abs(gradient) * threshold.adaptation_rate, 1.0)
    
    current = threshold.current_threshold
    predicted = current + gradient * prediction_factor
    
    # Smooth transition
    new_threshold_value = current * 0.8 + predicted * 0.2
    
    %{threshold |
      current_threshold: new_threshold_value,
      statistics: Map.put(stats, :gradient, gradient)
    }
  end
  
  defp adapt_ml_threshold(threshold, _feedback) do
    # Machine learning based adaptation
    # Simplified - in production would use actual ML model
    threshold
  end
  
  defp adapt_fuzzy_threshold(threshold, feedback) do
    # Fuzzy logic based adaptation
    stats = threshold.statistics
    
    # Define fuzzy membership functions
    error = feedback.error || 0
    rate = feedback.rate || 0
    
    # Fuzzy rules
    adjustment = apply_fuzzy_rules(error, rate, stats)
    
    new_threshold_value = threshold.current_threshold + adjustment
    
    %{threshold |
      current_threshold: new_threshold_value
    }
  end
  
  # Scaling Control Implementation
  
  defp apply_scaling_control(value, signal_id) do
    case :ets.lookup(:auto_scalers, signal_id) do
      [{^signal_id, scaler}] ->
        scale_value(value, scaler)
      [] ->
        value
    end
  end
  
  defp scale_value({:triggered, value, direction}, scaler) do
    scaled = scale_value(value, scaler)
    {:triggered, scaled, direction}
  end
  
  defp scale_value({:dead_band, value, direction}, scaler) do
    scaled = scale_value(value, scaler)
    {:dead_band, scaled, direction}
  end
  
  defp scale_value({:normal, value, direction}, scaler) do
    scaled = scale_value(value, scaler)
    {:normal, scaled, direction}
  end
  
  defp scale_value(value, scaler) when is_number(value) do
    # Apply scaling transformation
    scaled = (value - scaler.current_offset) * scaler.current_scale
    
    # Handle outliers
    handle_outlier(scaled, scaler)
  end
  
  defp handle_outlier(value, scaler) do
    {out_min, out_max} = scaler.output_range
    
    case scaler.outlier_handling do
      :clip ->
        # Clip to output range
        max(out_min, min(out_max, value))
        
      :compress ->
        # Sigmoid compression
        if value < out_min do
          out_min + (value - out_min) * 0.1
        else
          if value > out_max do
            out_max + (value - out_max) * 0.1
          else
            value
          end
        end
        
      :reject ->
        # Reject outliers
        if value >= out_min and value <= out_max do
          value
        else
          nil
        end
        
      _ ->
        value
    end
  end
  
  defp update_scaler_adaptation(signal_id, feedback) do
    case :ets.lookup(:auto_scalers, signal_id) do
      [{^signal_id, scaler}] ->
        new_scaler = adapt_scaler(scaler, feedback)
        :ets.insert(:auto_scalers, {signal_id, new_scaler})
      [] ->
        :ok
    end
  end
  
  defp adapt_scaler(scaler, feedback) do
    case scaler.scaling_mode do
      :dynamic_range ->
        adapt_dynamic_range_scaler(scaler, feedback)
      :histogram_equalization ->
        adapt_histogram_scaler(scaler, feedback)
      :adaptive_normalization ->
        adapt_normalization_scaler(scaler, feedback)
      :robust_scaling ->
        adapt_robust_scaler(scaler, feedback)
    end
  end
  
  defp adapt_dynamic_range_scaler(scaler, feedback) do
    stats = scaler.statistics
    
    # Update min/max tracking
    new_stats = update_range_statistics(stats, feedback.value)
    
    # Calculate new scale and offset
    {in_min, in_max} = {new_stats.observed_min, new_stats.observed_max}
    {out_min, out_max} = scaler.output_range
    
    # Avoid division by zero
    input_range = max(in_max - in_min, 0.001)
    output_range = out_max - out_min
    
    # Smooth adaptation
    alpha = scaler.adaptation_speed
    new_scale = (1 - alpha) * scaler.current_scale + alpha * (output_range / input_range)
    new_offset = (1 - alpha) * scaler.current_offset + alpha * in_min
    
    %{scaler |
      current_scale: new_scale,
      current_offset: new_offset,
      statistics: new_stats
    }
  end
  
  defp adapt_histogram_scaler(scaler, feedback) do
    # Histogram equalization for uniform distribution
    stats = scaler.statistics
    
    # Update histogram
    new_stats = update_histogram(stats, feedback.value)
    
    # Calculate cumulative distribution
    cdf = calculate_cdf(new_stats.histogram)
    
    # Update scaling function based on CDF
    %{scaler |
      statistics: Map.put(new_stats, :cdf, cdf)
    }
  end
  
  defp adapt_normalization_scaler(scaler, feedback) do
    # Z-score normalization with adaptive parameters
    stats = scaler.statistics
    
    # Update running statistics
    new_stats = update_running_statistics(stats, feedback.value)
    
    # Calculate scale and offset for z-score normalization
    mean = new_stats.running_mean
    std_dev = max(new_stats.running_std_dev, 0.001)
    
    {out_min, out_max} = scaler.output_range
    out_center = (out_min + out_max) / 2
    out_range = (out_max - out_min) / 6  # Map ±3 std dev to output range
    
    new_scale = out_range / std_dev
    new_offset = mean - out_center / new_scale
    
    %{scaler |
      current_scale: new_scale,
      current_offset: new_offset,
      statistics: new_stats
    }
  end
  
  defp adapt_robust_scaler(scaler, feedback) do
    # Robust scaling using median and IQR
    stats = scaler.statistics
    
    # Update robust statistics
    new_stats = update_robust_statistics(stats, feedback.value)
    
    # Use median and IQR for scaling
    median = new_stats.median
    iqr = new_stats.iqr
    
    {out_min, out_max} = scaler.output_range
    out_range = out_max - out_min
    
    # Scale based on IQR (more robust to outliers)
    new_scale = out_range / max(iqr * 2, 0.001)
    new_offset = median - (out_min + out_max) / 2 / new_scale
    
    %{scaler |
      current_scale: new_scale,
      current_offset: new_offset,
      statistics: new_stats
    }
  end
  
  # Statistics and Helper Functions
  
  defp initialize_statistics do
    %{
      count: 0,
      sum: 0.0,
      sum_squares: 0.0,
      mean: 0.0,
      variance: 0.0,
      std_dev: 0.0,
      recent_values: :queue.new(),
      max_history: 1000
    }
  end
  
  defp initialize_scaling_statistics do
    %{
      observed_min: nil,
      observed_max: nil,
      running_mean: 0.0,
      running_std_dev: 1.0,
      count: 0,
      histogram: %{},
      percentiles: %{},
      median: 0.0,
      iqr: 1.0,
      value_buffer: []
    }
  end
  
  defp update_statistics(stats, feedback) do
    value = feedback.value || 0
    
    # Update counts and sums
    new_count = stats.count + 1
    new_sum = stats.sum + value
    new_sum_squares = stats.sum_squares + value * value
    
    # Update mean and variance
    new_mean = new_sum / new_count
    new_variance = (new_sum_squares / new_count) - (new_mean * new_mean)
    new_std_dev = :math.sqrt(max(new_variance, 0))
    
    # Update recent values queue
    new_recent = :queue.in(value, stats.recent_values)
    new_recent = if :queue.len(new_recent) > stats.max_history do
      {_, trimmed} = :queue.out(new_recent)
      trimmed
    else
      new_recent
    end
    
    %{stats |
      count: new_count,
      sum: new_sum,
      sum_squares: new_sum_squares,
      mean: new_mean,
      variance: new_variance,
      std_dev: new_std_dev,
      recent_values: new_recent
    }
  end
  
  defp update_percentile_statistics(stats, feedback) do
    value = feedback.value || 0
    
    # Maintain sorted list of values
    values = Map.get(stats, :values, [])
    new_values = insert_sorted([value | values], stats.max_history)
    
    %{stats | values: new_values}
  end
  
  defp calculate_percentile([], _p), do: 0
  defp calculate_percentile(values, p) do
    sorted = Enum.sort(values)
    index = round((length(sorted) - 1) * p / 100)
    Enum.at(sorted, index)
  end
  
  defp calculate_entropy(values) when length(values) < 2, do: 0
  defp calculate_entropy(values) do
    # Calculate Shannon entropy
    # Discretize values into bins
    n_bins = 10
    {min_val, max_val} = Enum.min_max(values)
    
    if min_val == max_val do
      0  # No variation, no entropy
    else
      bin_width = (max_val - min_val) / n_bins
      
      # Count values in each bin
      bin_counts = Enum.reduce(values, %{}, fn value, acc ->
        bin = min(floor((value - min_val) / bin_width), n_bins - 1)
        Map.update(acc, bin, 1, &(&1 + 1))
      end)
      
      # Calculate entropy
      total = length(values)
      
      Map.values(bin_counts)
      |> Enum.map(fn count ->
        p = count / total
        if p > 0, do: -p * :math.log(p), else: 0
      end)
      |> Enum.sum()
    end
  end
  
  defp calculate_signal_gradient(values) when length(values) < 2, do: 0
  defp calculate_signal_gradient(values) do
    # Simple linear regression for gradient
    indexed_values = Enum.with_index(values)
    n = length(values)
    
    sum_x = Enum.sum(0..(n-1))
    sum_y = Enum.sum(values)
    sum_xy = indexed_values |> Enum.map(fn {y, x} -> x * y end) |> Enum.sum()
    sum_x2 = Enum.sum(Enum.map(0..(n-1), &(&1 * &1)))
    
    denominator = n * sum_x2 - sum_x * sum_x
    
    if denominator == 0 do
      0
    else
      (n * sum_xy - sum_x * sum_y) / denominator
    end
  end
  
  defp calculate_adaptive_k(stats, adaptation_rate) do
    # Adaptive k-factor for statistical threshold
    # Based on signal stability
    stability = 1.0 / (1.0 + stats.variance)
    
    # Base k-factor (number of standard deviations)
    base_k = 2.0
    
    # Adjust based on stability and adaptation rate
    base_k * (1.0 + adaptation_rate * (1.0 - stability))
  end
  
  defp apply_threshold_constraints(threshold_value, constraints) do
    # Apply min/max constraints
    threshold_value
    |> max(Map.get(constraints, :min, -:math.inf()))
    |> min(Map.get(constraints, :max, :math.inf()))
  end
  
  defp apply_fuzzy_rules(error, rate, _stats) do
    # Simplified fuzzy logic rules
    # In production, implement full fuzzy inference system
    
    # If error is large and rate is positive, increase threshold significantly
    if abs(error) > 0.5 and rate > 0 do
      0.1 * sign(error)
    else
      # If error is small, make small adjustments
      if abs(error) < 0.1 do
        0.01 * sign(error)
      else
        0.05 * sign(error)
      end
    end
  end
  
  defp sign(x) when x >= 0, do: 1
  defp sign(_), do: -1
  
  defp update_range_statistics(stats, value) do
    new_min = case stats.observed_min do
      nil -> value
      min -> min(min, value)
    end
    
    new_max = case stats.observed_max do
      nil -> value
      max -> max(max, value)
    end
    
    %{stats |
      observed_min: new_min,
      observed_max: new_max,
      count: stats.count + 1
    }
  end
  
  defp update_histogram(stats, value) do
    # Update histogram bins
    histogram = Map.update(stats.histogram, round(value * 10) / 10, 1, &(&1 + 1))
    %{stats | histogram: histogram}
  end
  
  defp calculate_cdf(histogram) do
    # Calculate cumulative distribution function
    sorted_bins = histogram
    |> Map.to_list()
    |> Enum.sort_by(fn {bin, _} -> bin end)
    
    total = histogram |> Map.values() |> Enum.sum()
    
    {cdf, _} = Enum.reduce(sorted_bins, {[], 0}, fn {bin, count}, {acc, cumsum} ->
      new_cumsum = cumsum + count
      {[{bin, new_cumsum / total} | acc], new_cumsum}
    end)
    
    Enum.reverse(cdf)
  end
  
  defp update_running_statistics(stats, value) do
    # Welford's online algorithm for running mean and variance
    count = stats.count + 1
    delta = value - stats.running_mean
    new_mean = stats.running_mean + delta / count
    delta2 = value - new_mean
    
    new_variance = if count > 1 do
      ((count - 1) * stats.running_std_dev * stats.running_std_dev + delta * delta2) / count
    else
      0
    end
    
    %{stats |
      count: count,
      running_mean: new_mean,
      running_std_dev: :math.sqrt(new_variance)
    }
  end
  
  defp update_robust_statistics(stats, value) do
    # Update buffer and calculate robust statistics
    buffer = [value | Map.get(stats, :value_buffer, [])]
    |> Enum.take(1000)  # Keep last 1000 values
    
    sorted = Enum.sort(buffer)
    n = length(sorted)
    
    median = if rem(n, 2) == 0 do
      mid = div(n, 2)
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, div(n, 2))
    end
    
    # Calculate IQR (Interquartile Range)
    q1_index = round(n * 0.25)
    q3_index = round(n * 0.75)
    q1 = Enum.at(sorted, q1_index)
    q3 = Enum.at(sorted, q3_index)
    iqr = q3 - q1
    
    %{stats |
      value_buffer: buffer,
      median: median,
      iqr: iqr
    }
  end
  
  defp insert_sorted(values, max_size) do
    values
    |> Enum.sort()
    |> Enum.take(max_size)
  end
  
  defp record_control_application(signal_id, input_value, output_value) do
    timestamp = :erlang.system_time(:microsecond)
    
    record = %{
      signal_id: signal_id,
      input: input_value,
      output: output_value,
      timestamp: timestamp,
      transformation: calculate_transformation(input_value, output_value)
    }
    
    :ets.insert(:control_history, {signal_id, record})
  end
  
  defp calculate_transformation(input, {:triggered, output, direction}) do
    %{
      type: :threshold_triggered,
      direction: direction,
      input_value: input,
      output_value: output
    }
  end
  
  defp calculate_transformation(input, output) when is_number(input) and is_number(output) do
    %{
      type: :scaling,
      scale_factor: if(input != 0, do: output / input, else: 0),
      offset: output - input
    }
  end
  
  defp calculate_transformation(_, _), do: %{type: :unknown}
  
  defp update_control_statistics(signal_id, input_value, output_value) do
    # Update performance metrics for the control system
    :telemetry.execute(
      [:vsm, :telemetry, :adaptive_control],
      %{
        input_value: extract_numeric_value(input_value),
        output_value: extract_numeric_value(output_value),
        control_applied: input_value != output_value
      },
      %{signal_id: signal_id}
    )
  end
  
  defp extract_numeric_value({_, value, _}), do: value
  defp extract_numeric_value(value) when is_number(value), do: value
  defp extract_numeric_value(_), do: 0
  
  defp update_all_adaptations(learning_signals) do
    # Update adaptations for all signals in learning mode
    Enum.each(learning_signals, fn signal_id ->
      # Get recent control history
      history = get_recent_control_history(signal_id)
      
      if length(history) > 0 do
        # Calculate feedback metrics
        feedback = calculate_adaptation_feedback(history)
        
        # Update adaptations
        update_threshold_adaptation(signal_id, feedback)
        update_scaler_adaptation(signal_id, feedback)
      end
    end)
  end
  
  defp get_recent_control_history(signal_id) do
    # Get last 100 control applications
    case :ets.lookup(:control_history, signal_id) do
      records ->
        records
        |> Enum.map(fn {_, record} -> record end)
        |> Enum.sort_by(& &1.timestamp, :desc)
        |> Enum.take(100)
    end
  end
  
  defp calculate_adaptation_feedback(history) do
    # Analyze control history to generate feedback
    values = Enum.map(history, & &1.input)
    
    %{
      value: List.first(values) || 0,
      error: calculate_control_error(history),
      rate: calculate_value_rate(values),
      effectiveness: calculate_control_effectiveness(history)
    }
  end
  
  defp calculate_control_error(history) do
    # Calculate average control error
    errors = Enum.map(history, fn record ->
      abs(extract_numeric_value(record.output) - extract_numeric_value(record.input))
    end)
    
    if length(errors) > 0 do
      Enum.sum(errors) / length(errors)
    else
      0
    end
  end
  
  defp calculate_value_rate(values) when length(values) < 2, do: 0
  defp calculate_value_rate(values) do
    # Calculate average rate of change
    differences = values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> b - a end)
    
    if length(differences) > 0 do
      Enum.sum(differences) / length(differences)
    else
      0
    end
  end
  
  defp calculate_control_effectiveness(history) do
    # Measure how well the control system is performing
    # Simplified metric - in production would be more sophisticated
    triggered_count = Enum.count(history, fn record ->
      match?({:triggered, _, _}, record.output)
    end)
    
    1.0 - (triggered_count / max(length(history), 1))
  end
  
  defp schedule_adaptation_update do
    Process.send_after(self(), :update_adaptations, 5000)
  end
end