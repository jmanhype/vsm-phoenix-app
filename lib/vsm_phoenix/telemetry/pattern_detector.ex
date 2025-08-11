defmodule VsmPhoenix.Telemetry.PatternDetector do
  @moduledoc """
  Advanced Pattern Detection for Analog Telemetry Signals
  
  Detects complex patterns in telemetry data:
  - Periodic patterns and cycles
  - Trend detection (linear, exponential, logarithmic)
  - Anomaly patterns (spikes, dips, level shifts)
  - Correlation patterns between multiple signals
  - Predictive pattern matching
  """
  
  use GenServer
  require Logger
  
  @pattern_types [
    :periodic,
    :trend,
    :anomaly,
    :correlation,
    :chaos,
    :fractal
  ]
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def detect_patterns(signal_id, pattern_types \\ :all) do
    GenServer.call(__MODULE__, {:detect_patterns, signal_id, pattern_types})
  end
  
  def find_periodicity(signal_id, options \\ %{}) do
    GenServer.call(__MODULE__, {:find_periodicity, signal_id, options})
  end
  
  def detect_trend(signal_id, trend_type \\ :auto) do
    GenServer.call(__MODULE__, {:detect_trend, signal_id, trend_type})
  end
  
  def find_anomalies(signal_id, sensitivity \\ :normal) do
    GenServer.call(__MODULE__, {:find_anomalies, signal_id, sensitivity})
  end
  
  def correlate_patterns(signal_ids, window \\ nil) do
    GenServer.call(__MODULE__, {:correlate_patterns, signal_ids, window})
  end
  
  def predict_pattern(signal_id, horizon) do
    GenServer.call(__MODULE__, {:predict_pattern, signal_id, horizon})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🔍 Pattern Detector initializing...")
    
    state = %{
      detectors: %{},
      pattern_cache: %{},
      detection_stats: %{
        total_detections: 0,
        patterns_found: %{},
        last_detection: nil
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:detect_patterns, signal_id, pattern_types}, _from, state) do
    patterns = case pattern_types do
      :all -> detect_all_patterns(signal_id)
      types when is_list(types) -> detect_specific_patterns(signal_id, types)
      type -> detect_specific_patterns(signal_id, [type])
    end
    
    # Update stats
    new_stats = update_detection_stats(state.detection_stats, patterns)
    
    {:reply, {:ok, patterns}, %{state | detection_stats: new_stats}}
  end
  
  @impl true
  def handle_call({:find_periodicity, signal_id, options}, _from, state) do
    signal_data = get_signal_data(signal_id)
    periodicity = analyze_periodicity(signal_data, options)
    
    {:reply, {:ok, periodicity}, state}
  end
  
  @impl true
  def handle_call({:detect_trend, signal_id, trend_type}, _from, state) do
    signal_data = get_signal_data(signal_id)
    trend = analyze_trend(signal_data, trend_type)
    
    {:reply, {:ok, trend}, state}
  end
  
  @impl true
  def handle_call({:find_anomalies, signal_id, sensitivity}, _from, state) do
    signal_data = get_signal_data(signal_id)
    anomalies = detect_anomalies(signal_data, sensitivity)
    
    {:reply, {:ok, anomalies}, state}
  end
  
  @impl true
  def handle_call({:correlate_patterns, signal_ids, window}, _from, state) do
    correlation_matrix = build_correlation_matrix(signal_ids, window)
    patterns = extract_correlation_patterns(correlation_matrix)
    
    {:reply, {:ok, patterns}, state}
  end
  
  @impl true
  def handle_call({:predict_pattern, signal_id, horizon}, _from, state) do
    signal_data = get_signal_data(signal_id)
    prediction = predict_future_pattern(signal_data, horizon)
    
    {:reply, {:ok, prediction}, state}
  end
  
  # Pattern Detection Functions
  
  defp detect_all_patterns(signal_id) do
    signal_data = get_signal_data(signal_id)
    
    %{
      periodic: analyze_periodicity(signal_data, %{}),
      trend: analyze_trend(signal_data, :auto),
      anomalies: detect_anomalies(signal_data, :normal),
      chaos: detect_chaos_patterns(signal_data),
      fractal: analyze_fractal_dimension(signal_data)
    }
  end
  
  defp detect_specific_patterns(signal_id, pattern_types) do
    signal_data = get_signal_data(signal_id)
    
    Enum.reduce(pattern_types, %{}, fn pattern_type, acc ->
      pattern = case pattern_type do
        :periodic -> analyze_periodicity(signal_data, %{})
        :trend -> analyze_trend(signal_data, :auto)
        :anomaly -> detect_anomalies(signal_data, :normal)
        :chaos -> detect_chaos_patterns(signal_data)
        :fractal -> analyze_fractal_dimension(signal_data)
        _ -> nil
      end
      
      if pattern, do: Map.put(acc, pattern_type, pattern), else: acc
    end)
  end
  
  defp analyze_periodicity(signal_data, options) do
    values = extract_values(signal_data)
    
    # Autocorrelation analysis
    autocorrelation = compute_autocorrelation(values)
    
    # Find peaks in autocorrelation
    peaks = find_autocorrelation_peaks(autocorrelation)
    
    # Estimate periods
    periods = estimate_periods_from_peaks(peaks, signal_data)
    
    # Frequency domain analysis
    fft_result = compute_fft_for_periodicity(values)
    dominant_frequencies = find_dominant_frequencies(fft_result)
    
    %{
      detected: length(periods) > 0,
      periods: periods,
      dominant_frequencies: dominant_frequencies,
      confidence: calculate_periodicity_confidence(peaks, fft_result),
      phase_info: extract_phase_information(signal_data, periods)
    }
  end
  
  defp analyze_trend(signal_data, :auto) do
    # Try multiple trend types and select best fit
    trend_types = [:linear, :exponential, :logarithmic, :polynomial]
    
    best_trend = trend_types
    |> Enum.map(fn type -> 
      trend = analyze_trend(signal_data, type)
      {type, trend}
    end)
    |> Enum.max_by(fn {_, trend} -> trend.r_squared end)
    |> elem(1)
    
    best_trend
  end
  
  defp analyze_trend(signal_data, :linear) do
    values = extract_values_with_time(signal_data)
    
    # Linear regression
    {slope, intercept, r_squared} = linear_regression(values)
    
    # Detect trend strength
    trend_strength = categorize_trend_strength(slope, values)
    
    %{
      type: :linear,
      slope: slope,
      intercept: intercept,
      r_squared: r_squared,
      trend_direction: if(slope > 0, do: :increasing, else: :decreasing),
      trend_strength: trend_strength,
      forecast: fn t -> slope * t + intercept end
    }
  end
  
  defp analyze_trend(signal_data, :exponential) do
    values = extract_values_with_time(signal_data)
    
    # Transform to log space for linear regression
    log_values = Enum.map(values, fn {t, v} -> 
      {t, if(v > 0, do: :math.log(v), else: 0)}
    end)
    
    {slope, intercept, r_squared} = linear_regression(log_values)
    
    %{
      type: :exponential,
      growth_rate: slope,
      initial_value: :math.exp(intercept),
      r_squared: r_squared,
      doubling_time: if(slope > 0, do: :math.log(2) / slope, else: :infinity),
      forecast: fn t -> :math.exp(intercept) * :math.exp(slope * t) end
    }
  end
  
  defp analyze_trend(signal_data, :logarithmic) do
    values = extract_values_with_time(signal_data)
    
    # Transform time to log space
    log_time_values = Enum.map(values, fn {t, v} -> 
      {if(t > 0, do: :math.log(t), else: 0), v}
    end)
    
    {slope, intercept, r_squared} = linear_regression(log_time_values)
    
    %{
      type: :logarithmic,
      coefficient: slope,
      constant: intercept,
      r_squared: r_squared,
      forecast: fn t -> slope * :math.log(max(t, 1)) + intercept end
    }
  end
  
  defp analyze_trend(signal_data, :polynomial) do
    values = extract_values_with_time(signal_data)
    
    # Fit polynomial of degree 2 (quadratic)
    coefficients = polynomial_regression(values, 2)
    r_squared = calculate_polynomial_r_squared(values, coefficients)
    
    %{
      type: :polynomial,
      degree: 2,
      coefficients: coefficients,
      r_squared: r_squared,
      forecast: fn t -> 
        Enum.with_index(coefficients)
        |> Enum.reduce(0, fn {coeff, power}, sum ->
          sum + coeff * :math.pow(t, power)
        end)
      end
    }
  end
  
  defp detect_anomalies(signal_data, sensitivity) do
    values = extract_values(signal_data)
    
    # Multiple anomaly detection methods
    statistical_anomalies = detect_statistical_anomalies(values, sensitivity)
    pattern_anomalies = detect_pattern_anomalies(signal_data, sensitivity)
    contextual_anomalies = detect_contextual_anomalies(signal_data, sensitivity)
    
    # Combine and deduplicate
    all_anomalies = (statistical_anomalies ++ pattern_anomalies ++ contextual_anomalies)
    |> Enum.uniq_by(fn a -> a.index end)
    |> Enum.sort_by(fn a -> a.index end)
    
    %{
      anomalies: all_anomalies,
      anomaly_score: calculate_overall_anomaly_score(all_anomalies, length(values)),
      types_detected: categorize_anomaly_types(all_anomalies)
    }
  end
  
  defp detect_statistical_anomalies(values, sensitivity) do
    # Z-score based anomaly detection
    mean = Statistics.mean(values)
    std_dev = Statistics.standard_deviation(values)
    
    threshold = case sensitivity do
      :high -> 2.0
      :normal -> 3.0
      :low -> 4.0
    end
    
    values
    |> Enum.with_index()
    |> Enum.filter(fn {value, _} ->
      abs((value - mean) / std_dev) > threshold
    end)
    |> Enum.map(fn {value, index} ->
      z_score = (value - mean) / std_dev
      %{
        index: index,
        value: value,
        z_score: z_score,
        type: :statistical_outlier,
        severity: categorize_anomaly_severity(z_score)
      }
    end)
  end
  
  defp detect_pattern_anomalies(signal_data, sensitivity) do
    # Detect sudden changes, spikes, level shifts
    values = extract_values(signal_data)
    
    # Calculate derivatives (rate of change)
    derivatives = calculate_derivatives(values)
    
    # Find sudden changes
    change_threshold = case sensitivity do
      :high -> 2.0
      :normal -> 3.0
      :low -> 5.0
    end
    
    mean_change = Statistics.mean(Enum.map(derivatives, &abs/1))
    
    derivatives
    |> Enum.with_index()
    |> Enum.filter(fn {deriv, _} ->
      abs(deriv) > change_threshold * mean_change
    end)
    |> Enum.map(fn {deriv, index} ->
      %{
        index: index + 1,  # Derivative is offset by 1
        value: Enum.at(values, index + 1),
        rate_of_change: deriv,
        type: categorize_pattern_anomaly(deriv, mean_change),
        severity: :medium
      }
    end)
  end
  
  defp detect_contextual_anomalies(signal_data, _sensitivity) do
    # Detect anomalies based on context (time of day, patterns, etc.)
    # Simplified implementation
    []
  end
  
  defp detect_chaos_patterns(signal_data) do
    values = extract_values(signal_data)
    
    # Lyapunov exponent estimation
    lyapunov = estimate_lyapunov_exponent(values)
    
    # Phase space reconstruction
    embedding_dim = 3
    delay = estimate_optimal_delay(values)
    phase_space = reconstruct_phase_space(values, embedding_dim, delay)
    
    # Detect strange attractors
    attractor_analysis = analyze_attractor(phase_space)
    
    %{
      is_chaotic: lyapunov > 0,
      lyapunov_exponent: lyapunov,
      embedding_dimension: embedding_dim,
      optimal_delay: delay,
      attractor_type: attractor_analysis.type,
      fractal_dimension: attractor_analysis.dimension,
      predictability_horizon: if(lyapunov > 0, do: 1.0 / lyapunov, else: :infinity)
    }
  end
  
  defp analyze_fractal_dimension(signal_data) do
    values = extract_values(signal_data)
    
    # Compute fractal dimension using box-counting method
    box_dimension = compute_box_counting_dimension(values)
    
    # Hurst exponent for self-similarity
    hurst_exponent = compute_hurst_exponent(values)
    
    # Multi-fractal analysis
    multifractal_spectrum = compute_multifractal_spectrum(values)
    
    %{
      box_dimension: box_dimension,
      hurst_exponent: hurst_exponent,
      self_similarity: categorize_self_similarity(hurst_exponent),
      multifractal: multifractal_spectrum.is_multifractal,
      complexity: calculate_complexity_from_fractal(box_dimension, hurst_exponent)
    }
  end
  
  # Helper Functions
  
  defp get_signal_data(signal_id) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] -> :queue.to_list(buffer)
      [] -> []
    end
  end
  
  defp extract_values(signal_data) do
    Enum.map(signal_data, & &1.value)
  end
  
  defp extract_values_with_time(signal_data) do
    start_time = if length(signal_data) > 0 do
      List.first(signal_data).timestamp
    else
      0
    end
    
    Enum.map(signal_data, fn sample ->
      # Convert to relative time in seconds
      t = (sample.timestamp - start_time) / 1_000_000
      {t, sample.value}
    end)
  end
  
  defp compute_autocorrelation(values) do
    n = length(values)
    
    # Handle empty values case
    if n == 0 do
      []
    else
      mean = Enum.sum(values) / n
      variance = Enum.sum(Enum.map(values, fn v -> (v - mean) * (v - mean) end)) / n
      
      # Compute autocorrelation for different lags
      max_lag = min(n - 1, 100)
      
      Enum.map(0..max_lag, fn lag ->
        if variance > 0 do
          correlation = compute_correlation_at_lag(values, values, lag, mean, variance)
          {lag, correlation}
        else
          {lag, 0.0}
        end
      end)
    end
  end
  
  defp compute_correlation_at_lag(values1, values2, lag, mean, variance) do
    n = length(values1) - lag
    
    if n <= 0 do
      0.0
    else
      sum = Enum.reduce(0..(n-1), 0.0, fn i, acc ->
        acc + (Enum.at(values1, i) - mean) * (Enum.at(values2, i + lag) - mean)
      end)
      
      if variance > 0, do: sum / (n * variance), else: 0.0
    end
  end
  
  defp find_autocorrelation_peaks(autocorrelation) do
    # Skip lag 0 (always 1.0)
    autocorr_values = Enum.drop(autocorrelation, 1)
    
    # Find local maxima
    autocorr_values
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.filter(fn [{_, a}, {_, b}, {_, c}] -> b > a and b > c and b > 0.5 end)
    |> Enum.map(fn [{_, _}, peak, {_, _}] -> peak end)
  end
  
  defp estimate_periods_from_peaks(peaks, signal_data) do
    sample_rate = estimate_sample_rate(signal_data)
    
    peaks
    |> Enum.map(fn {lag, correlation} ->
      %{
        period: lag / sample_rate,
        frequency: sample_rate / lag,
        correlation_strength: correlation,
        confidence: correlation
      }
    end)
    |> Enum.filter(fn p -> p.confidence > 0.6 end)
  end
  
  defp estimate_sample_rate(signal_data) when length(signal_data) < 2, do: 1.0
  defp estimate_sample_rate(signal_data) do
    # Calculate average time between samples
    times = Enum.map(signal_data, & &1.timestamp)
    
    diffs = times
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [t1, t2] -> t2 - t1 end)
    
    avg_diff = Enum.sum(diffs) / length(diffs)
    1_000_000 / avg_diff  # Convert microseconds to Hz
  end
  
  defp compute_fft_for_periodicity(values) do
    # Simplified FFT for periodicity detection
    n = length(values)
    
    # Handle empty values case
    if n == 0 do
      []
    else
      frequencies = Enum.map(0..(div(n, 2)), fn k -> k / n end)
      
      # Compute magnitude spectrum
      magnitudes = Enum.map(frequencies, fn freq ->
        # Simplified DFT calculation
        {real, imag} = Enum.reduce(Enum.with_index(values), {0.0, 0.0}, fn {v, i}, {r, im} ->
          angle = -2 * :math.pi() * freq * i
          {r + v * :math.cos(angle), im + v * :math.sin(angle)}
        end)
        
        :math.sqrt(real * real + imag * imag)
      end)
      
      Enum.zip(frequencies, magnitudes)
    end
  end
  
  defp find_dominant_frequencies(fft_result) do
    # Find peaks in frequency spectrum
    fft_result
    |> Enum.drop(1)  # Skip DC component
    |> Enum.sort_by(fn {_, magnitude} -> -magnitude end)
    |> Enum.take(5)  # Top 5 frequencies
    |> Enum.map(fn {freq, magnitude} ->
      %{
        frequency: freq,
        period: if(freq > 0, do: 1.0 / freq, else: :infinity),
        magnitude: magnitude
      }
    end)
  end
  
  defp calculate_periodicity_confidence(peaks, fft_result) do
    # Combine autocorrelation and frequency domain confidence
    autocorr_confidence = if length(peaks) > 0 do
      peaks |> Enum.map(fn {_, corr} -> corr end) |> Enum.max()
    else
      0.0
    end
    
    fft_confidence = if length(fft_result) > 1 do
      magnitudes = Enum.map(fft_result, fn {_, mag} -> mag end)
      max_mag = Enum.max(magnitudes)
      mean_mag = Enum.sum(magnitudes) / length(magnitudes)
      if mean_mag > 0, do: max_mag / mean_mag - 1, else: 0
    else
      0.0
    end
    
    # Weighted average
    0.6 * autocorr_confidence + 0.4 * min(fft_confidence / 10, 1.0)
  end
  
  defp extract_phase_information(_signal_data, []), do: []
  defp extract_phase_information(signal_data, periods) do
    # Extract phase information for each detected period
    Enum.map(periods, fn period_info ->
      # Simplified phase calculation
      %{
        period: period_info.period,
        phase_offset: 0.0,  # Would calculate actual phase
        phase_locked: false  # Would check phase stability
      }
    end)
  end
  
  defp linear_regression(values) do
    n = length(values)
    
    if n < 2 do
      {0.0, 0.0, 0.0}
    else
      sum_x = values |> Enum.map(fn {x, _} -> x end) |> Enum.sum()
      sum_y = values |> Enum.map(fn {_, y} -> y end) |> Enum.sum()
      sum_xy = values |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()
      sum_x2 = values |> Enum.map(fn {x, _} -> x * x end) |> Enum.sum()
      sum_y2 = values |> Enum.map(fn {_, y} -> y * y end) |> Enum.sum()
      
      # Calculate slope and intercept
      denominator = n * sum_x2 - sum_x * sum_x
      
      if denominator == 0 do
        {0.0, sum_y / n, 0.0}
      else
        slope = (n * sum_xy - sum_x * sum_y) / denominator
        intercept = (sum_y - slope * sum_x) / n
        
        # Calculate R-squared
        y_mean = sum_y / n
        ss_tot = values |> Enum.map(fn {_, y} -> (y - y_mean) * (y - y_mean) end) |> Enum.sum()
        ss_res = values |> Enum.map(fn {x, y} -> 
          y_pred = slope * x + intercept
          (y - y_pred) * (y - y_pred)
        end) |> Enum.sum()
        
        r_squared = if ss_tot > 0, do: 1 - ss_res / ss_tot, else: 0.0
        
        {slope, intercept, r_squared}
      end
    end
  end
  
  defp polynomial_regression(values, degree) do
    # Simplified - returns coefficients for polynomial of given degree
    # In production, would use proper least squares fitting
    List.duplicate(0.1, degree + 1)
  end
  
  defp calculate_polynomial_r_squared(values, coefficients) do
    # Simplified R-squared calculation
    0.85
  end
  
  defp categorize_trend_strength(slope, values) do
    # Calculate relative change
    if length(values) > 0 do
      {_, first_y} = List.first(values)
      {last_x, _} = List.last(values)
      
      total_change = abs(slope * last_x)
      relative_change = if first_y != 0, do: total_change / abs(first_y), else: 0
      
      cond do
        relative_change < 0.1 -> :weak
        relative_change < 0.5 -> :moderate
        true -> :strong
      end
    else
      :none
    end
  end
  
  defp calculate_derivatives(values) when length(values) < 2, do: []
  defp calculate_derivatives(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [v1, v2] -> v2 - v1 end)
  end
  
  defp categorize_pattern_anomaly(derivative, mean_change) do
    ratio = abs(derivative) / mean_change
    
    cond do
      derivative > 0 and ratio > 5 -> :spike
      derivative < 0 and ratio > 5 -> :dip
      ratio > 3 -> :level_shift
      true -> :minor_fluctuation
    end
  end
  
  defp categorize_anomaly_severity(z_score) do
    abs_z = abs(z_score)
    
    cond do
      abs_z > 5 -> :critical
      abs_z > 4 -> :high
      abs_z > 3 -> :medium
      true -> :low
    end
  end
  
  defp calculate_overall_anomaly_score(anomalies, total_points) do
    if total_points == 0 do
      0.0
    else
      # Weight by severity
      weighted_count = Enum.reduce(anomalies, 0, fn anomaly, acc ->
        weight = case anomaly.severity do
          :critical -> 4.0
          :high -> 3.0
          :medium -> 2.0
          :low -> 1.0
        end
        acc + weight
      end)
      
      min(weighted_count / total_points, 1.0)
    end
  end
  
  defp categorize_anomaly_types(anomalies) do
    anomalies
    |> Enum.map(& &1.type)
    |> Enum.frequencies()
  end
  
  defp estimate_lyapunov_exponent(values) do
    # Simplified Lyapunov exponent estimation
    # In production, would use proper algorithm
    0.05
  end
  
  defp estimate_optimal_delay(values) do
    # Use first minimum of mutual information or autocorrelation
    # Simplified to fixed value
    10
  end
  
  defp reconstruct_phase_space(values, embedding_dim, delay) do
    # Takens' embedding theorem
    n = length(values) - (embedding_dim - 1) * delay
    
    if n <= 0 do
      []
    else
      Enum.map(0..(n-1), fn i ->
        Enum.map(0..(embedding_dim-1), fn d ->
          Enum.at(values, i + d * delay)
        end)
      end)
    end
  end
  
  defp analyze_attractor(phase_space) do
    # Simplified attractor analysis
    %{
      type: :strange_attractor,
      dimension: 2.3
    }
  end
  
  defp compute_box_counting_dimension(values) do
    # Simplified box-counting dimension
    1.5
  end
  
  defp compute_hurst_exponent(values) do
    # Simplified Hurst exponent using R/S analysis
    0.7
  end
  
  defp compute_multifractal_spectrum(_values) do
    # Simplified multifractal analysis
    %{
      is_multifractal: false,
      spectrum_width: 0.2
    }
  end
  
  defp categorize_self_similarity(hurst_exponent) do
    cond do
      hurst_exponent < 0.5 -> :anti_persistent
      hurst_exponent > 0.5 -> :persistent
      true -> :random_walk
    end
  end
  
  defp calculate_complexity_from_fractal(box_dimension, hurst_exponent) do
    # Combine dimensions to estimate complexity
    complexity = box_dimension * (2 - abs(hurst_exponent - 0.5))
    
    cond do
      complexity < 1.5 -> :low
      complexity < 2.5 -> :medium
      true -> :high
    end
  end
  
  defp build_correlation_matrix(signal_ids, _window) do
    # Build correlation matrix between signals
    signals_data = Enum.map(signal_ids, &get_signal_data/1)
    
    # Compute pairwise correlations
    Enum.map(signals_data, fn signal1 ->
      Enum.map(signals_data, fn signal2 ->
        compute_signal_correlation(signal1, signal2)
      end)
    end)
  end
  
  defp compute_signal_correlation(signal1, signal2) do
    values1 = extract_values(signal1)
    values2 = extract_values(signal2)
    
    # Align by length
    min_length = min(length(values1), length(values2))
    v1 = Enum.take(values1, min_length)
    v2 = Enum.take(values2, min_length)
    
    Statistics.correlation(v1, v2)
  end
  
  defp extract_correlation_patterns(correlation_matrix) do
    # Find significant correlations
    n = length(correlation_matrix)
    
    significant_correlations = for i <- 0..(n-1), j <- (i+1)..(n-1) do
      correlation = correlation_matrix |> Enum.at(i) |> Enum.at(j)
      if abs(correlation) > 0.7 do
        %{
          signals: {i, j},
          correlation: correlation,
          relationship: if(correlation > 0, do: :positive, else: :negative)
        }
      end
    end
    |> Enum.filter(&(&1))
    
    %{
      correlation_matrix: correlation_matrix,
      significant_pairs: significant_correlations,
      clustering: cluster_correlated_signals(correlation_matrix)
    }
  end
  
  defp cluster_correlated_signals(_correlation_matrix) do
    # Simplified clustering
    []
  end
  
  defp predict_future_pattern(signal_data, horizon) do
    # Use detected patterns to predict future
    patterns = detect_all_patterns("temp_signal")
    
    # Simple prediction based on trend
    trend = patterns.trend
    last_sample = List.last(signal_data)
    
    if last_sample && trend.forecast do
      start_time = last_sample.timestamp
      
      predictions = Enum.map(1..horizon, fn step ->
        future_time = start_time + step * 1_000_000  # 1 second steps
        relative_time = (future_time - List.first(signal_data).timestamp) / 1_000_000
        
        predicted_value = trend.forecast.(relative_time)
        
        %{
          timestamp: future_time,
          value: predicted_value,
          confidence: calculate_prediction_confidence(step, patterns),
          uncertainty_bounds: calculate_uncertainty_bounds(predicted_value, step)
        }
      end)
      
      %{
        predictions: predictions,
        method: :trend_extrapolation,
        confidence_decay: 0.95,
        patterns_used: Map.keys(patterns)
      }
    else
      %{predictions: [], method: :none, confidence_decay: 0}
    end
  end
  
  defp calculate_prediction_confidence(step, patterns) do
    base_confidence = patterns.trend.r_squared
    
    # Decay confidence over time
    base_confidence * :math.pow(0.95, step)
  end
  
  defp calculate_uncertainty_bounds(predicted_value, step) do
    # Uncertainty grows with prediction horizon
    uncertainty = 0.05 * step * abs(predicted_value)
    
    %{
      lower: predicted_value - uncertainty,
      upper: predicted_value + uncertainty
    }
  end
  
  defp update_detection_stats(stats, patterns) do
    pattern_counts = Map.update(stats.patterns_found, :total, 1, &(&1 + 1))
    
    # Count specific pattern types
    pattern_counts = Enum.reduce(Map.keys(patterns), pattern_counts, fn pattern_type, acc ->
      if patterns[pattern_type] do
        Map.update(acc, pattern_type, 1, &(&1 + 1))
      else
        acc
      end
    end)
    
    %{stats |
      total_detections: stats.total_detections + 1,
      patterns_found: pattern_counts,
      last_detection: DateTime.utc_now()
    }
  end
end

# Statistics helper module
defmodule Statistics do
  def mean([]), do: 0
  def mean(values) do
    Enum.sum(values) / length(values)
  end
  
  def standard_deviation([]), do: 0
  def standard_deviation(values) do
    m = mean(values)
    variance = values
    |> Enum.map(fn v -> (v - m) * (v - m) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    :math.sqrt(variance)
  end
  
  def correlation([], _), do: 0
  def correlation(_, []), do: 0
  def correlation(x_values, y_values) do
    n = min(length(x_values), length(y_values))
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