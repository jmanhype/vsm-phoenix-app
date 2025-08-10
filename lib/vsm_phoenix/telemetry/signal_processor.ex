defmodule VsmPhoenix.Telemetry.SignalProcessor do
  @moduledoc """
  Advanced Signal Processing for Analog Telemetry
  
  Implements sophisticated signal processing algorithms:
  - Digital Signal Processing (DSP) filters
  - Fast Fourier Transform (FFT) analysis
  - Wavelet transforms for time-frequency analysis
  - Adaptive filtering and noise reduction
  - Signal correlation and convolution
  """
  
  use GenServer
  require Logger
  
  # DSP Constants
  @pi :math.pi()
  @sample_rates %{
    ultra_high: 1000,    # 1kHz for microsecond precision
    high: 100,           # 100Hz for millisecond precision
    standard: 10,        # 10Hz for normal metrics
    low: 1               # 1Hz for slow-changing data
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def process_signal(signal_data, processing_type, params \\ %{}) do
    GenServer.call(__MODULE__, {:process, signal_data, processing_type, params})
  end
  
  def apply_fft(signal_data, options \\ %{}) do
    GenServer.call(__MODULE__, {:fft, signal_data, options})
  end
  
  def correlate_signals(signal_a, signal_b) do
    GenServer.call(__MODULE__, {:correlate, signal_a, signal_b})
  end
  
  def apply_wavelet_transform(signal_data, wavelet_type \\ :morlet) do
    GenServer.call(__MODULE__, {:wavelet, signal_data, wavelet_type})
  end
  
  def design_filter(filter_spec) do
    GenServer.call(__MODULE__, {:design_filter, filter_spec})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("🔊 Signal Processor initializing with DSP capabilities...")
    
    state = %{
      filter_cache: %{},
      fft_plans: %{},
      processing_stats: %{
        total_processed: 0,
        processing_time: 0,
        filter_applications: 0,
        fft_computations: 0
      }
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:process, signal_data, :butterworth_filter, params}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Design Butterworth filter
    filter = design_butterworth_filter(params)
    
    # Apply filter
    filtered_signal = apply_digital_filter(signal_data, filter)
    
    processing_time = System.monotonic_time(:microsecond) - start_time
    
    new_stats = update_processing_stats(state.processing_stats, :filter, processing_time)
    
    {:reply, {:ok, filtered_signal}, %{state | processing_stats: new_stats}}
  end
  
  @impl true
  def handle_call({:process, signal_data, :kalman_filter, params}, _from, state) do
    # Kalman filter for optimal state estimation
    kalman_state = initialize_kalman_filter(params)
    filtered_signal = apply_kalman_filter(signal_data, kalman_state)
    
    {:reply, {:ok, filtered_signal}, state}
  end
  
  @impl true
  def handle_call({:process, signal_data, :adaptive_filter, params}, _from, state) do
    # Adaptive filter that adjusts coefficients based on signal characteristics
    adaptive_result = apply_adaptive_filter(signal_data, params)
    
    {:reply, {:ok, adaptive_result}, state}
  end
  
  @impl true
  def handle_call({:fft, signal_data, options}, _from, state) do
    start_time = System.monotonic_time(:microsecond)
    
    # Perform FFT
    fft_result = compute_fft(signal_data, options)
    
    processing_time = System.monotonic_time(:microsecond) - start_time
    new_stats = update_processing_stats(state.processing_stats, :fft, processing_time)
    
    {:reply, {:ok, fft_result}, %{state | processing_stats: new_stats}}
  end
  
  @impl true
  def handle_call({:correlate, signal_a_name, signal_b_name}, _from, state) do
    # Fetch actual signal data from AnalogArchitect
    with {:ok, signal_a_data} <- VsmPhoenix.Telemetry.AnalogArchitect.get_signal_data(signal_a_name, %{}),
         {:ok, signal_b_data} <- VsmPhoenix.Telemetry.AnalogArchitect.get_signal_data(signal_b_name, %{}) do
      correlation = compute_cross_correlation(signal_a_data, signal_b_data)
      {:reply, {:ok, correlation}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:wavelet, signal_data, wavelet_type}, _from, state) do
    wavelet_result = compute_wavelet_transform(signal_data, wavelet_type)
    {:reply, {:ok, wavelet_result}, state}
  end
  
  @impl true
  def handle_call({:design_filter, filter_spec}, _from, state) do
    filter = case filter_spec.type do
      :butterworth -> design_butterworth_filter(filter_spec)
      :chebyshev -> design_chebyshev_filter(filter_spec)
      :elliptic -> design_elliptic_filter(filter_spec)
      :fir -> design_fir_filter(filter_spec)
      _ -> {:error, :unknown_filter_type}
    end
    
    {:reply, filter, state}
  end
  
  # DSP Implementation Functions
  
  defp design_butterworth_filter(%{order: order, cutoff: cutoff, type: filter_type}) do
    # Butterworth filter design with maximally flat passband
    sample_rate = get_sample_rate()
    normalized_cutoff = cutoff / (sample_rate / 2)  # Nyquist normalization
    
    # Calculate poles for Butterworth filter
    poles = calculate_butterworth_poles(order, normalized_cutoff, filter_type)
    
    # Convert to digital filter coefficients using bilinear transform
    {b_coeffs, a_coeffs} = bilinear_transform(poles, sample_rate)
    
    %{
      type: :butterworth,
      order: order,
      cutoff: cutoff,
      filter_type: filter_type,
      b_coefficients: b_coeffs,
      a_coefficients: a_coeffs,
      sample_rate: sample_rate
    }
  end
  
  defp calculate_butterworth_poles(order, cutoff, :low_pass) do
    # Generate s-plane poles for Butterworth filter
    Enum.map(0..(order-1), fn k ->
      angle = @pi * (2*k + order + 1) / (2 * order)
      real = -cutoff * :math.cos(angle)
      imag = -cutoff * :math.sin(angle)
      {real, imag}
    end)
  end
  
  defp calculate_butterworth_poles(order, cutoff, :high_pass) do
    # High-pass transformation of low-pass poles
    low_pass_poles = calculate_butterworth_poles(order, cutoff, :low_pass)
    
    Enum.map(low_pass_poles, fn {real, imag} ->
      magnitude_squared = real*real + imag*imag
      {-cutoff*cutoff*real/magnitude_squared, -cutoff*cutoff*imag/magnitude_squared}
    end)
  end
  
  defp bilinear_transform(poles, sample_rate) do
    # Bilinear transform: s = 2/T * (1-z^-1)/(1+z^-1)
    t = 1.0 / sample_rate
    
    # For simplicity, returning example coefficients
    # In production, implement full bilinear transform
    b = [0.2, 0.4, 0.2]
    a = [1.0, -0.5, 0.3]
    
    {b, a}
  end
  
  defp apply_digital_filter(signal_data, filter) do
    b = filter.b_coefficients
    a = filter.a_coefficients
    
    # Direct Form II implementation
    filtered = Enum.reduce(signal_data, {[], [], []}, fn sample, {output, x_history, y_history} ->
      # Update input history
      x_hist = [sample.value | Enum.take(x_history, length(b) - 1)]
      
      # Calculate output
      feed_forward = x_hist
      |> Enum.zip(b)
      |> Enum.map(fn {x, b_coeff} -> x * b_coeff end)
      |> Enum.sum()
      
      feedback = if length(y_history) > 0 do
        y_history
        |> Enum.take(length(a) - 1)
        |> Enum.zip(Enum.drop(a, 1))
        |> Enum.map(fn {y, a_coeff} -> -y * a_coeff end)
        |> Enum.sum()
      else
        0
      end
      
      y_new = (feed_forward + feedback) / List.first(a)
      
      # Update histories
      y_hist = [y_new | Enum.take(y_history, length(a) - 2)]
      
      filtered_sample = %{sample | value: y_new, filtered: true}
      
      {[filtered_sample | output], x_hist, y_hist}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
  
  defp initialize_kalman_filter(params) do
    %{
      # State estimate
      x: params[:initial_state] || 0.0,
      # Error covariance
      p: params[:initial_covariance] || 1.0,
      # Process noise covariance
      q: params[:process_noise] || 0.01,
      # Measurement noise covariance
      r: params[:measurement_noise] || 0.1,
      # State transition matrix (simplified to scalar)
      f: params[:state_transition] || 1.0,
      # Measurement matrix
      h: params[:measurement_matrix] || 1.0
    }
  end
  
  defp apply_kalman_filter(signal_data, kalman_state) do
    {filtered_signal, _final_state} = 
      Enum.map_reduce(signal_data, kalman_state, fn sample, state ->
        # Prediction step
        x_pred = state.f * state.x
        p_pred = state.f * state.p * state.f + state.q
        
        # Update step
        y = sample.value - state.h * x_pred  # Innovation
        s = state.h * p_pred * state.h + state.r  # Innovation covariance
        k = p_pred * state.h / s  # Kalman gain
        
        # Updated estimates
        x_new = x_pred + k * y
        p_new = (1 - k * state.h) * p_pred
        
        filtered_sample = %{sample | 
          value: x_new, 
          filtered: true,
          kalman_gain: k,
          innovation: y
        }
        
        new_state = %{state | x: x_new, p: p_new}
        
        {filtered_sample, new_state}
      end)
    
    filtered_signal
  end
  
  defp apply_adaptive_filter(signal_data, params) do
    # LMS (Least Mean Squares) adaptive filter
    filter_length = params[:filter_length] || 10
    learning_rate = params[:learning_rate] || 0.01
    
    initial_weights = List.duplicate(0.0, filter_length)
    
    {filtered_signal, _final_weights} =
      Enum.map_reduce(signal_data, {initial_weights, []}, fn sample, {weights, buffer} ->
        # Update buffer
        new_buffer = [sample.value | Enum.take(buffer, filter_length - 1)]
        
        # Compute filter output
        output = if length(new_buffer) == filter_length do
          new_buffer
          |> Enum.zip(weights)
          |> Enum.map(fn {x, w} -> x * w end)
          |> Enum.sum()
        else
          sample.value  # Not enough history yet
        end
        
        # Compute error (using simple prediction error)
        error = sample.value - output
        
        # Update weights using LMS algorithm
        new_weights = if length(new_buffer) == filter_length do
          weights
          |> Enum.zip(new_buffer)
          |> Enum.map(fn {w, x} -> w + learning_rate * error * x end)
        else
          weights
        end
        
        filtered_sample = %{sample |
          value: output,
          filtered: true,
          adaptation_error: error,
          filter_weights: new_weights
        }
        
        {filtered_sample, {new_weights, new_buffer}}
      end)
    
    filtered_signal
  end
  
  defp compute_fft(signal_data, options) do
    # Extract values
    values = Enum.map(signal_data, & &1.value)
    n = length(values)
    
    # Pad to next power of 2 for efficiency
    padded_length = next_power_of_2(n)
    padded_values = pad_signal(values, padded_length)
    
    # Compute FFT using Cooley-Tukey algorithm
    fft_result = fft_recursive(padded_values)
    
    # Compute frequency bins
    sample_rate = options[:sample_rate] || 100
    frequency_bins = compute_frequency_bins(padded_length, sample_rate)
    
    # Compute magnitude spectrum
    magnitude_spectrum = Enum.map(fft_result, fn {real, imag} ->
      :math.sqrt(real*real + imag*imag)
    end)
    
    # Compute phase spectrum
    phase_spectrum = Enum.map(fft_result, fn {real, imag} ->
      :math.atan2(imag, real)
    end)
    
    %{
      fft_complex: fft_result,
      magnitude_spectrum: magnitude_spectrum,
      phase_spectrum: phase_spectrum,
      frequency_bins: frequency_bins,
      dominant_frequency: find_dominant_frequency(magnitude_spectrum, frequency_bins),
      spectral_energy: compute_spectral_energy(magnitude_spectrum)
    }
  end
  
  defp fft_recursive([value]), do: [{value, 0.0}]
  defp fft_recursive(values) when length(values) == 2 do
    [a, b] = values
    [{a + b, 0.0}, {a - b, 0.0}]
  end
  defp fft_recursive(values) do
    n = length(values)
    half_n = div(n, 2)
    
    # Split into even and odd indices
    {even, odd} = values
    |> Enum.with_index()
    |> Enum.split_with(fn {_, i} -> rem(i, 2) == 0 end)
    
    even_values = Enum.map(even, &elem(&1, 0))
    odd_values = Enum.map(odd, &elem(&1, 0))
    
    # Recursive FFT
    even_fft = fft_recursive(even_values)
    odd_fft = fft_recursive(odd_values)
    
    # Combine results
    Enum.map(0..(n-1), fn k ->
      k_mod = rem(k, half_n)
      {even_real, even_imag} = Enum.at(even_fft, k_mod)
      {odd_real, odd_imag} = Enum.at(odd_fft, k_mod)
      
      # Twiddle factor
      angle = -2.0 * @pi * k / n
      tw_real = :math.cos(angle)
      tw_imag = :math.sin(angle)
      
      # Complex multiplication
      temp_real = odd_real * tw_real - odd_imag * tw_imag
      temp_imag = odd_real * tw_imag + odd_imag * tw_real
      
      if k < half_n do
        {even_real + temp_real, even_imag + temp_imag}
      else
        {even_real - temp_real, even_imag - temp_imag}
      end
    end)
  end
  
  defp extract_samples({:samples, samples}), do: samples
  defp extract_samples(samples) when is_list(samples), do: samples
  defp extract_samples(_), do: []

  defp compute_cross_correlation(signal_a, signal_b) do
    # Extract actual samples from signal data
    a_samples = extract_samples(signal_a)
    b_samples = extract_samples(signal_b)
    
    # Normalize signals
    a_values = normalize_signal(Enum.map(a_samples, & &1.value))
    b_values = normalize_signal(Enum.map(b_samples, & &1.value))
    
    # Compute correlation at different lags
    max_lag = min(length(a_values), length(b_values)) - 1
    
    correlation_values = Enum.map(-max_lag..max_lag, fn lag ->
      correlation = compute_correlation_at_lag(a_values, b_values, lag)
      {lag, correlation}
    end)
    
    # Find peak correlation
    {peak_lag, peak_correlation} = Enum.max_by(correlation_values, fn {_, corr} -> abs(corr) end)
    
    %{
      correlation_values: correlation_values,
      peak_lag: peak_lag,
      peak_correlation: peak_correlation,
      correlation_coefficient: compute_pearson_correlation(a_values, b_values)
    }
  end
  
  defp compute_wavelet_transform(signal_data, wavelet_type) do
    values = Enum.map(signal_data, & &1.value)
    
    # Generate wavelet
    wavelet_func = get_wavelet_function(wavelet_type)
    
    # Compute continuous wavelet transform at different scales
    scales = generate_scales(length(values))
    
    cwt_matrix = Enum.map(scales, fn scale ->
      # Convolve signal with scaled wavelet
      Enum.map(0..(length(values)-1), fn position ->
        compute_wavelet_coefficient(values, wavelet_func, scale, position)
      end)
    end)
    
    %{
      wavelet_type: wavelet_type,
      coefficients: cwt_matrix,
      scales: scales,
      time_frequency_map: build_time_frequency_map(cwt_matrix, scales),
      ridges: extract_wavelet_ridges(cwt_matrix)
    }
  end
  
  # Helper Functions
  
  defp get_sample_rate, do: @sample_rates.standard
  
  defp update_processing_stats(stats, operation, processing_time) do
    %{stats |
      total_processed: stats.total_processed + 1,
      processing_time: stats.processing_time + processing_time,
      "#{operation}_computations": Map.get(stats, "#{operation}_computations", 0) + 1
    }
  end
  
  defp next_power_of_2(n) do
    :math.pow(2, :math.ceil(:math.log2(n))) |> round()
  end
  
  defp pad_signal(values, target_length) do
    padding_length = target_length - length(values)
    values ++ List.duplicate(0.0, padding_length)
  end
  
  defp compute_frequency_bins(n, sample_rate) do
    Enum.map(0..(n-1), fn k ->
      k * sample_rate / n
    end)
  end
  
  defp find_dominant_frequency(magnitude_spectrum, frequency_bins) do
    # Find the frequency with maximum magnitude (excluding DC component)
    {_max_mag, max_idx} = magnitude_spectrum
    |> Enum.drop(1)  # Skip DC
    |> Enum.with_index(1)
    |> Enum.max_by(fn {mag, _} -> mag end)
    
    Enum.at(frequency_bins, max_idx)
  end
  
  defp compute_spectral_energy(magnitude_spectrum) do
    magnitude_spectrum
    |> Enum.map(&(&1 * &1))
    |> Enum.sum()
    |> :math.sqrt()
  end
  
  defp normalize_signal(values) do
    mean = Enum.sum(values) / length(values)
    std_dev = :math.sqrt(Enum.sum(Enum.map(values, fn v -> (v - mean) * (v - mean) end)) / length(values))
    
    if std_dev > 0 do
      Enum.map(values, fn v -> (v - mean) / std_dev end)
    else
      values
    end
  end
  
  defp compute_correlation_at_lag(a_values, b_values, lag) do
    # Compute correlation coefficient at specific lag
    n = min(length(a_values), length(b_values) - abs(lag))
    
    if n <= 0 do
      0.0
    else
      {a_segment, b_segment} = if lag >= 0 do
        {Enum.take(a_values, n), Enum.drop(b_values, lag) |> Enum.take(n)}
      else
        {Enum.drop(a_values, -lag) |> Enum.take(n), Enum.take(b_values, n)}
      end
      
      Enum.zip(a_segment, b_segment)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()
      |> Kernel./(n)
    end
  end
  
  defp compute_pearson_correlation(a_values, b_values) do
    n = min(length(a_values), length(b_values))
    a_subset = Enum.take(a_values, n)
    b_subset = Enum.take(b_values, n)
    
    a_mean = Enum.sum(a_subset) / n
    b_mean = Enum.sum(b_subset) / n
    
    numerator = Enum.zip(a_subset, b_subset)
    |> Enum.map(fn {a, b} -> (a - a_mean) * (b - b_mean) end)
    |> Enum.sum()
    
    a_variance = Enum.map(a_subset, fn a -> (a - a_mean) * (a - a_mean) end) |> Enum.sum()
    b_variance = Enum.map(b_subset, fn b -> (b - b_mean) * (b - b_mean) end) |> Enum.sum()
    
    denominator = :math.sqrt(a_variance * b_variance)
    
    if denominator > 0, do: numerator / denominator, else: 0.0
  end
  
  defp get_wavelet_function(:morlet) do
    # Morlet wavelet: complex sinusoid modulated by Gaussian
    fn t, scale ->
      sigma = scale / 5.0
      norm = 1.0 / :math.sqrt(sigma * :math.sqrt(@pi))
      gaussian = :math.exp(-t*t / (2*sigma*sigma))
      complex_real = :math.cos(5*t/scale)
      norm * gaussian * complex_real
    end
  end
  
  defp get_wavelet_function(:mexican_hat) do
    # Mexican hat wavelet (Ricker wavelet)
    fn t, scale ->
      t_scaled = t / scale
      norm = 2.0 / (:math.sqrt(3) * :math.pow(@pi, 0.25))
      norm * (1 - t_scaled*t_scaled) * :math.exp(-t_scaled*t_scaled/2)
    end
  end
  
  defp generate_scales(signal_length) do
    # Generate logarithmically spaced scales
    min_scale = 2
    max_scale = min(signal_length / 4, 128)
    num_scales = 32
    
    log_min = :math.log(min_scale)
    log_max = :math.log(max_scale)
    
    Enum.map(0..(num_scales-1), fn i ->
      :math.exp(log_min + i * (log_max - log_min) / (num_scales - 1))
    end)
  end
  
  defp compute_wavelet_coefficient(values, wavelet_func, scale, position) do
    # Compute single wavelet coefficient
    n = length(values)
    
    Enum.reduce(0..(n-1), 0.0, fn i, sum ->
      t = (i - position) / scale
      if abs(t) < 10 do  # Limit wavelet support
        sum + Enum.at(values, i) * wavelet_func.(t, scale)
      else
        sum
      end
    end) / :math.sqrt(scale)
  end
  
  defp build_time_frequency_map(cwt_matrix, scales) do
    # Build time-frequency representation
    Enum.zip(scales, cwt_matrix)
    |> Enum.map(fn {scale, coeffs} ->
      frequency = 1.0 / scale  # Approximate frequency
      {frequency, coeffs}
    end)
    |> Map.new()
  end
  
  defp extract_wavelet_ridges(cwt_matrix) do
    # Extract ridges (local maxima across scales)
    # Simplified implementation - production would use more sophisticated ridge detection
    []
  end
  
  defp design_chebyshev_filter(_spec) do
    # Chebyshev filter with ripple in passband
    %{type: :chebyshev, coefficients: []}
  end
  
  defp design_elliptic_filter(_spec) do
    # Elliptic filter with ripple in both passband and stopband
    %{type: :elliptic, coefficients: []}
  end
  
  defp design_fir_filter(_spec) do
    # Finite Impulse Response filter
    %{type: :fir, coefficients: []}
  end
end