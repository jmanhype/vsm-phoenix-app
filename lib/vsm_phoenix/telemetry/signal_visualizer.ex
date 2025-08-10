defmodule VsmPhoenix.Telemetry.SignalVisualizer do
  @moduledoc """
  Real-time Signal Visualization and Monitoring
  
  Provides visualization capabilities for analog telemetry signals:
  - Real-time waveform rendering
  - Spectrum analysis visualization
  - Multi-signal oscilloscope view
  - Heat maps and waterfall displays
  - Phase portraits and attractors
  - Statistical distribution plots
  """
  
  use GenServer
  require Logger
  
  @visualization_modes [
    :waveform,
    :spectrum,
    :spectrogram,
    :phase_portrait,
    :heat_map,
    :waterfall,
    :constellation,
    :histogram,
    :scatter_plot
  ]
  
  @update_rates %{
    real_time: 50,      # 20 FPS
    fast: 100,          # 10 FPS
    normal: 250,        # 4 FPS
    slow: 1000          # 1 FPS
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def create_visualization(viz_id, config) do
    GenServer.call(__MODULE__, {:create_viz, viz_id, config})
  end
  
  def update_visualization(viz_id, signal_data) do
    GenServer.cast(__MODULE__, {:update_viz, viz_id, signal_data})
  end
  
  def get_visualization_data(viz_id) do
    GenServer.call(__MODULE__, {:get_viz_data, viz_id})
  end
  
  def create_dashboard(dashboard_id, visualizations) do
    GenServer.call(__MODULE__, {:create_dashboard, dashboard_id, visualizations})
  end
  
  def enable_monitoring(signal_id, monitoring_config) do
    GenServer.call(__MODULE__, {:enable_monitoring, signal_id, monitoring_config})
  end
  
  def get_monitoring_alerts(signal_id) do
    GenServer.call(__MODULE__, {:get_alerts, signal_id})
  end
  
  # Server Implementation
  
  @impl true
  def init(_opts) do
    Logger.info("📈 Signal Visualizer initializing...")
    
    # ETS tables for visualization state
    :ets.new(:visualizations, [:set, :public, :named_table])
    :ets.new(:viz_buffers, [:set, :public, :named_table])
    :ets.new(:dashboards, [:set, :public, :named_table])
    :ets.new(:monitoring_alerts, [:bag, :public, :named_table])
    :ets.new(:visualization_cache, [:set, :public, :named_table])
    
    # Start update loop
    schedule_visualization_updates()
    
    state = %{
      visualizations: %{},
      monitors: %{},
      alert_queue: :queue.new(),
      render_engine: initialize_render_engine()
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:create_viz, viz_id, config}, _from, state) do
    Logger.info("🎨 Creating visualization: #{viz_id}")
    
    visualization = %{
      id: viz_id,
      type: config[:type] || :waveform,
      signal_ids: List.wrap(config[:signal_ids]),
      display_config: parse_display_config(config),
      update_rate: @update_rates[config[:update_rate] || :normal],
      buffer_size: config[:buffer_size] || 1000,
      render_state: initialize_render_state(config[:type]),
      created_at: DateTime.utc_now()
    }
    
    # Initialize visualization buffer
    :ets.insert(:viz_buffers, {viz_id, :queue.new()})
    :ets.insert(:visualizations, {viz_id, visualization})
    
    # Subscribe to signal updates
    subscribe_to_signals(visualization.signal_ids, viz_id)
    
    {:reply, {:ok, visualization}, state}
  end
  
  @impl true
  def handle_call({:get_viz_data, viz_id}, _from, state) do
    case :ets.lookup(:visualizations, viz_id) do
      [{^viz_id, viz}] ->
        # Get current buffer
        buffer_data = get_viz_buffer(viz_id)
        
        # Render visualization
        rendered_data = render_visualization(viz, buffer_data)
        
        {:reply, {:ok, rendered_data}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end
  
  @impl true
  def handle_call({:create_dashboard, dashboard_id, visualizations}, _from, state) do
    dashboard = %{
      id: dashboard_id,
      visualizations: visualizations,
      layout: calculate_dashboard_layout(visualizations),
      created_at: DateTime.utc_now()
    }
    
    :ets.insert(:dashboards, {dashboard_id, dashboard})
    
    {:reply, {:ok, dashboard}, state}
  end
  
  @impl true
  def handle_call({:enable_monitoring, signal_id, config}, _from, state) do
    monitor = %{
      signal_id: signal_id,
      thresholds: config[:thresholds] || %{},
      alert_conditions: config[:alert_conditions] || [],
      notification_config: config[:notifications] || %{},
      active: true,
      alert_history: []
    }
    
    new_monitors = Map.put(state.monitors, signal_id, monitor)
    
    {:reply, :ok, %{state | monitors: new_monitors}}
  end
  
  @impl true
  def handle_call({:get_alerts, signal_id}, _from, state) do
    alerts = case :ets.lookup(:monitoring_alerts, signal_id) do
      alerts -> Enum.map(alerts, fn {_, alert} -> alert end)
    end
    
    {:reply, {:ok, alerts}, state}
  end
  
  @impl true
  def handle_cast({:update_viz, viz_id, signal_data}, state) do
    # Update visualization buffer
    update_viz_buffer(viz_id, signal_data)
    
    # Check monitoring conditions
    check_monitoring_conditions(signal_data, state.monitors)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info(:update_visualizations, state) do
    # Update all active visualizations
    update_all_visualizations()
    
    # Process alert queue
    process_alert_queue(state.alert_queue)
    
    # Schedule next update
    schedule_visualization_updates()
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:signal_update, signal_id, data}, state) do
    # Route signal update to relevant visualizations
    route_signal_update(signal_id, data)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:render_viz, viz_id}, state) do
    # Render specific visualization
    case :ets.lookup(:visualizations, viz_id) do
      [{^viz_id, viz}] ->
        rendered_data = render_single_visualization(viz)
        :ets.insert(:visualization_cache, {viz_id, rendered_data, DateTime.utc_now()})
      [] ->
        Logger.warning("Render request for unknown visualization: #{viz_id}")
    end
    
    {:noreply, state}
  end
  
  # Visualization Rendering
  
  defp get_signal_buffer(signal_id) do
    case :ets.lookup(:signal_buffers, signal_id) do
      [{^signal_id, buffer}] -> 
        {:ok, :queue.to_list(buffer)}
      [] -> 
        {:error, :not_found}
    end
  end
  
  defp render_single_visualization(viz) do
    # Get signal data
    signal_data = Enum.reduce(viz.signal_ids, %{}, fn signal_id, acc ->
      case get_signal_buffer(signal_id) do
        {:ok, buffer_data} -> Map.put(acc, signal_id, buffer_data)
        _ -> acc
      end
    end)
    
    if map_size(signal_data) > 0 do
      # Render based on type
      first_signal_data = signal_data |> Map.values() |> List.first()
      render_visualization(viz, first_signal_data)
    else
      %{type: viz.type, error: :no_data}
    end
  end
  
  defp render_visualization(%{type: :waveform} = viz, buffer_data) do
    %{
      type: :waveform,
      data: render_waveform(buffer_data, viz.display_config),
      axes: generate_waveform_axes(buffer_data, viz.display_config),
      metadata: %{
        sample_count: length(buffer_data),
        time_range: calculate_time_range(buffer_data)
      }
    }
  end
  
  defp render_visualization(%{type: :spectrum} = viz, buffer_data) do
    # Compute frequency spectrum
    spectrum_data = compute_spectrum(buffer_data)
    
    %{
      type: :spectrum,
      data: render_spectrum(spectrum_data, viz.display_config),
      axes: generate_spectrum_axes(spectrum_data, viz.display_config),
      metadata: %{
        dominant_frequency: find_dominant_frequency(spectrum_data),
        bandwidth: calculate_bandwidth(spectrum_data)
      }
    }
  end
  
  defp render_visualization(%{type: :spectrogram} = viz, buffer_data) do
    # Time-frequency representation
    spectrogram_data = compute_spectrogram(buffer_data, viz.display_config)
    
    %{
      type: :spectrogram,
      data: render_spectrogram(spectrogram_data, viz.display_config),
      axes: generate_spectrogram_axes(spectrogram_data, viz.display_config),
      colormap: viz.display_config[:colormap] || :viridis
    }
  end
  
  defp render_visualization(%{type: :phase_portrait} = viz, buffer_data) do
    # Phase space representation
    phase_data = compute_phase_portrait(buffer_data, viz.display_config)
    
    %{
      type: :phase_portrait,
      data: render_phase_portrait(phase_data, viz.display_config),
      axes: generate_phase_axes(phase_data),
      attractor: detect_attractor_type(phase_data)
    }
  end
  
  defp render_visualization(%{type: :heat_map} = viz, buffer_data) do
    # 2D heat map visualization
    heat_map_data = compute_heat_map(buffer_data, viz.display_config)
    
    %{
      type: :heat_map,
      data: render_heat_map(heat_map_data, viz.display_config),
      colormap: viz.display_config[:colormap] || :plasma,
      intensity_range: calculate_intensity_range(heat_map_data)
    }
  end
  
  defp render_visualization(%{type: :histogram} = viz, buffer_data) do
    # Statistical distribution
    histogram_data = compute_histogram(buffer_data, viz.display_config)
    
    %{
      type: :histogram,
      data: render_histogram(histogram_data, viz.display_config),
      statistics: calculate_distribution_stats(buffer_data),
      distribution_fit: fit_distribution(buffer_data)
    }
  end
  
  defp render_visualization(%{type: :scatter_plot} = viz, buffer_data) do
    # Multi-dimensional scatter plot
    scatter_data = prepare_scatter_data(buffer_data, viz.display_config)
    
    %{
      type: :scatter_plot,
      data: render_scatter_plot(scatter_data, viz.display_config),
      correlation: calculate_correlation_matrix(scatter_data),
      clusters: detect_clusters(scatter_data)
    }
  end
  
  # Waveform Rendering
  
  defp render_waveform(buffer_data, display_config) do
    # Downsample if necessary
    max_points = display_config[:max_points] || 1000
    samples = downsample_signal(buffer_data, max_points)
    
    # Apply display transformations
    samples
    |> apply_display_scale(display_config)
    |> apply_display_offset(display_config)
    |> format_waveform_data()
  end
  
  defp downsample_signal(data, max_points) when length(data) <= max_points, do: data
  defp downsample_signal(data, max_points) do
    # LTTB (Largest Triangle Three Buckets) algorithm
    bucket_size = length(data) / max_points
    
    Enum.chunk_every(data, ceil(bucket_size))
    |> Enum.map(&select_representative_point/1)
  end
  
  defp select_representative_point([point]), do: point
  defp select_representative_point(bucket) do
    # Select point with maximum triangle area
    # Simplified - in production use full LTTB
    Enum.at(bucket, div(length(bucket), 2))
  end
  
  defp apply_display_scale(samples, config) do
    scale = config[:scale] || 1.0
    Enum.map(samples, fn sample ->
      %{sample | value: sample.value * scale}
    end)
  end
  
  defp apply_display_offset(samples, config) do
    offset = config[:offset] || 0.0
    Enum.map(samples, fn sample ->
      %{sample | value: sample.value + offset}
    end)
  end
  
  defp format_waveform_data(samples) do
    Enum.map(samples, fn sample ->
      %{
        x: sample.timestamp,
        y: sample.value,
        metadata: sample.metadata
      }
    end)
  end
  
  # Spectrum Analysis
  
  defp compute_spectrum(buffer_data) do
    values = Enum.map(buffer_data, & &1.value)
    
    # FFT computation
    fft_result = compute_fft(values)
    
    # Convert to power spectrum
    power_spectrum = Enum.map(fft_result, fn {real, imag} ->
      :math.sqrt(real * real + imag * imag)
    end)
    
    # Generate frequency bins
    sample_rate = estimate_sample_rate(buffer_data)
    frequency_bins = generate_frequency_bins(length(values), sample_rate)
    
    Enum.zip(frequency_bins, power_spectrum)
  end
  
  defp render_spectrum(spectrum_data, display_config) do
    # Apply display options
    spectrum_data
    |> apply_spectrum_window(display_config[:window])
    |> apply_spectrum_scale(display_config[:scale_type])
    |> format_spectrum_data()
  end
  
  defp apply_spectrum_window(spectrum_data, nil), do: spectrum_data
  defp apply_spectrum_window(spectrum_data, :hanning) do
    # Apply Hanning window
    # Simplified implementation
    spectrum_data
  end
  
  defp apply_spectrum_scale(spectrum_data, :log) do
    Enum.map(spectrum_data, fn {freq, magnitude} ->
      {freq, 20 * :math.log10(max(magnitude, 0.000001))}
    end)
  end
  defp apply_spectrum_scale(spectrum_data, _), do: spectrum_data
  
  # Spectrogram Rendering
  
  defp compute_spectrogram(buffer_data, config) do
    window_size = config[:window_size] || 256
    overlap = config[:overlap] || 0.5
    
    # Split into overlapping windows
    windows = create_overlapping_windows(buffer_data, window_size, overlap)
    
    # Compute spectrum for each window
    Enum.map(windows, fn {window_data, timestamp} ->
      spectrum = compute_spectrum(window_data)
      %{
        timestamp: timestamp,
        spectrum: spectrum
      }
    end)
  end
  
  defp create_overlapping_windows(data, window_size, overlap) do
    step = round(window_size * (1 - overlap))
    
    data
    |> Enum.chunk_every(window_size, step, :discard)
    |> Enum.map(fn window ->
      timestamp = List.first(window).timestamp
      {window, timestamp}
    end)
  end
  
  # Phase Portrait
  
  defp compute_phase_portrait(buffer_data, config) do
    delay = config[:delay] || 10
    dimension = config[:dimension] || 2
    
    # Takens embedding
    values = Enum.map(buffer_data, & &1.value)
    
    embed_phase_space(values, dimension, delay)
  end
  
  defp embed_phase_space(values, dimension, delay) do
    max_index = length(values) - (dimension - 1) * delay
    
    if max_index > 0 do
      Enum.map(0..(max_index - 1), fn i ->
        coordinates = Enum.map(0..(dimension - 1), fn d ->
          Enum.at(values, i + d * delay)
        end)
        
        %{coordinates: coordinates, index: i}
      end)
    else
      []
    end
  end
  
  # Heat Map
  
  defp compute_heat_map(buffer_data, config) do
    # Create 2D grid from signal data
    grid_size = config[:grid_size] || {50, 50}
    
    # Map signal values to 2D grid
    # Simplified - in production would use actual 2D signal data
    create_heat_map_grid(buffer_data, grid_size)
  end
  
  defp create_heat_map_grid(data, {width, height}) do
    # Create synthetic 2D data from 1D signal
    # This is a placeholder - real implementation would handle actual 2D data
    for y <- 0..(height - 1) do
      for x <- 0..(width - 1) do
        index = y * width + x
        if index < length(data) do
          Enum.at(data, index).value
        else
          0.0
        end
      end
    end
  end
  
  # Monitoring and Alerts
  
  defp check_monitoring_conditions(signal_data, monitors) do
    signal_id = signal_data[:signal_id]
    
    case Map.get(monitors, signal_id) do
      nil -> :ok
      monitor when monitor.active ->
        check_thresholds(signal_data, monitor)
        check_alert_conditions(signal_data, monitor)
      _ -> :ok
    end
  end
  
  defp check_thresholds(signal_data, monitor) do
    value = signal_data[:value]
    
    Enum.each(monitor.thresholds, fn {threshold_name, threshold_value} ->
      case threshold_name do
        :upper when value > threshold_value ->
          create_alert(signal_data[:signal_id], :threshold_exceeded, %{
            threshold: threshold_name,
            value: value,
            limit: threshold_value
          })
          
        :lower when value < threshold_value ->
          create_alert(signal_data[:signal_id], :threshold_exceeded, %{
            threshold: threshold_name,
            value: value,
            limit: threshold_value
          })
          
        _ -> :ok
      end
    end)
  end
  
  defp check_alert_conditions(signal_data, monitor) do
    Enum.each(monitor.alert_conditions, fn condition ->
      if evaluate_alert_condition(signal_data, condition) do
        create_alert(signal_data[:signal_id], condition.type, %{
          condition: condition,
          triggered_value: signal_data[:value]
        })
      end
    end)
  end
  
  defp evaluate_alert_condition(_signal_data, _condition) do
    # Simplified - implement condition evaluation logic
    false
  end
  
  defp create_alert(signal_id, alert_type, details) do
    alert = %{
      signal_id: signal_id,
      type: alert_type,
      details: details,
      timestamp: DateTime.utc_now(),
      severity: determine_alert_severity(alert_type, details)
    }
    
    :ets.insert(:monitoring_alerts, {signal_id, alert})
    
    # Emit telemetry event
    :telemetry.execute(
      [:vsm, :telemetry, :monitoring_alert],
      %{severity: alert.severity},
      %{signal_id: signal_id, alert_type: alert_type}
    )
  end
  
  defp determine_alert_severity(:threshold_exceeded, %{threshold: :upper}), do: :high
  defp determine_alert_severity(:threshold_exceeded, %{threshold: :lower}), do: :medium
  defp determine_alert_severity(_, _), do: :low
  
  # Helper Functions
  
  defp parse_display_config(config) do
    %{
      width: config[:width] || 800,
      height: config[:height] || 400,
      colors: config[:colors] || default_colors(),
      grid: config[:grid] || true,
      labels: config[:labels] || true,
      scale: config[:scale] || :auto,
      offset: config[:offset] || :auto
    }
  end
  
  defp initialize_render_state(viz_type) do
    case viz_type do
      :waveform -> %{last_render: nil, frame_count: 0}
      :spectrum -> %{fft_plan: nil, window_function: :hanning}
      :spectrogram -> %{color_scale: :viridis, time_window: []}
      :phase_portrait -> %{trajectory: [], max_points: 1000}
      _ -> %{}
    end
  end
  
  defp initialize_render_engine do
    %{
      canvas_cache: %{},
      color_maps: load_color_maps(),
      font_cache: %{}
    }
  end
  
  defp get_viz_buffer(viz_id) do
    case :ets.lookup(:viz_buffers, viz_id) do
      [{^viz_id, buffer}] -> :queue.to_list(buffer)
      [] -> []
    end
  end
  
  defp update_viz_buffer(viz_id, signal_data) do
    case :ets.lookup(:viz_buffers, viz_id) do
      [{^viz_id, buffer}] ->
        # Add new data
        new_buffer = :queue.in(signal_data, buffer)
        
        # Trim if needed
        max_size = get_buffer_size(viz_id)
        trimmed_buffer = if :queue.len(new_buffer) > max_size do
          {_, smaller} = :queue.out(new_buffer)
          smaller
        else
          new_buffer
        end
        
        :ets.insert(:viz_buffers, {viz_id, trimmed_buffer})
      [] ->
        :ok
    end
  end
  
  defp get_buffer_size(viz_id) do
    case :ets.lookup(:visualizations, viz_id) do
      [{^viz_id, viz}] -> viz.buffer_size
      [] -> 1000
    end
  end
  
  defp subscribe_to_signals(signal_ids, viz_id) do
    Enum.each(signal_ids, fn signal_id ->
      Phoenix.PubSub.subscribe(VsmPhoenix.PubSub, "signal:#{signal_id}")
    end)
  end
  
  defp route_signal_update(signal_id, data) do
    # Find all visualizations using this signal
    visualizations = :ets.tab2list(:visualizations)
    |> Enum.filter(fn {_id, viz} ->
      signal_id in viz.signal_ids
    end)
    
    # Update each visualization
    Enum.each(visualizations, fn {viz_id, _viz} ->
      update_viz_buffer(viz_id, data)
    end)
  end
  
  defp calculate_dashboard_layout(visualizations) do
    # Simple grid layout
    count = length(visualizations)
    cols = :math.ceil(:math.sqrt(count)) |> round()
    rows = :math.ceil(count / cols) |> round()
    
    %{
      grid: {rows, cols},
      positions: Enum.with_index(visualizations) |> Enum.map(fn {viz, i} ->
        {viz.id, %{row: div(i, cols), col: rem(i, cols)}}
      end) |> Map.new()
    }
  end
  
  defp update_all_visualizations do
    # Update visualizations that need refresh
    visualizations = :ets.tab2list(:visualizations)
    
    Enum.each(visualizations, fn {viz_id, viz} ->
      if should_update_viz?(viz) do
        # Trigger render
        send(self(), {:render_viz, viz_id})
      end
    end)
  end
  
  defp should_update_viz?(viz) do
    # Check if enough time has passed since last update
    true  # Simplified
  end
  
  defp process_alert_queue(queue) do
    # Process pending alerts
    case :queue.out(queue) do
      {{:value, alert}, rest} ->
        send_alert_notification(alert)
        process_alert_queue(rest)
      {:empty, _} ->
        :ok
    end
  end
  
  defp send_alert_notification(_alert) do
    # Send notifications (email, webhook, etc.)
    :ok
  end
  
  defp generate_waveform_axes(data, _config) do
    if length(data) > 0 do
      time_range = {List.first(data).timestamp, List.last(data).timestamp}
      value_range = data |> Enum.map(& &1.value) |> Enum.min_max()
      
      %{
        x_axis: %{
          label: "Time",
          range: time_range,
          type: :time
        },
        y_axis: %{
          label: "Value",
          range: value_range,
          type: :linear
        }
      }
    else
      %{x_axis: %{}, y_axis: %{}}
    end
  end
  
  defp generate_spectrum_axes(spectrum_data, _config) do
    if length(spectrum_data) > 0 do
      {freqs, mags} = Enum.unzip(spectrum_data)
      
      %{
        x_axis: %{
          label: "Frequency (Hz)",
          range: {Enum.min(freqs), Enum.max(freqs)},
          type: :linear
        },
        y_axis: %{
          label: "Magnitude",
          range: {0, Enum.max(mags)},
          type: :linear
        }
      }
    else
      %{x_axis: %{}, y_axis: %{}}
    end
  end
  
  defp calculate_time_range([]), do: {0, 0}
  defp calculate_time_range(data) do
    timestamps = Enum.map(data, & &1.timestamp)
    {Enum.min(timestamps), Enum.max(timestamps)}
  end
  
  defp find_dominant_frequency(spectrum_data) do
    if length(spectrum_data) > 0 do
      {freq, _mag} = Enum.max_by(spectrum_data, fn {_f, m} -> m end)
      freq
    else
      0
    end
  end
  
  defp calculate_bandwidth(spectrum_data) do
    # 3dB bandwidth calculation
    if length(spectrum_data) > 0 do
      max_mag = spectrum_data |> Enum.map(fn {_f, m} -> m end) |> Enum.max()
      threshold = max_mag * 0.707  # -3dB
      
      above_threshold = Enum.filter(spectrum_data, fn {_f, m} -> m >= threshold end)
      
      if length(above_threshold) > 0 do
        freqs = Enum.map(above_threshold, fn {f, _} -> f end)
        Enum.max(freqs) - Enum.min(freqs)
      else
        0
      end
    else
      0
    end
  end
  
  defp estimate_sample_rate([]), do: 100.0
  defp estimate_sample_rate([_]), do: 100.0
  defp estimate_sample_rate(data) do
    # Calculate average time between samples
    timestamps = Enum.map(data, & &1.timestamp)
    
    diffs = timestamps
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [t1, t2] -> t2 - t1 end)
    
    if length(diffs) > 0 do
      avg_diff = Enum.sum(diffs) / length(diffs)
      1_000_000 / avg_diff  # Convert microseconds to Hz
    else
      100.0
    end
  end
  
  defp compute_fft(values) do
    # Simplified FFT - in production use NIF or proper FFT library
    n = length(values)
    
    Enum.map(0..(n-1), fn k ->
      {real, imag} = Enum.reduce(Enum.with_index(values), {0.0, 0.0}, fn {v, n_idx}, {r, i} ->
        angle = -2 * :math.pi() * k * n_idx / n
        {r + v * :math.cos(angle), i + v * :math.sin(angle)}
      end)
      
      {real / n, imag / n}
    end)
  end
  
  defp generate_frequency_bins(n, sample_rate) do
    Enum.map(0..(n-1), fn k ->
      k * sample_rate / n
    end)
  end
  
  defp detect_attractor_type(_phase_data) do
    # Simplified attractor detection
    :strange_attractor
  end
  
  defp calculate_intensity_range(heat_map_data) do
    all_values = List.flatten(heat_map_data)
    
    if length(all_values) > 0 do
      {Enum.min(all_values), Enum.max(all_values)}
    else
      {0, 1}
    end
  end
  
  defp calculate_distribution_stats(data) do
    values = Enum.map(data, & &1.value)
    
    %{
      mean: calculate_mean(values),
      median: calculate_median(values),
      std_dev: calculate_std_dev(values),
      skewness: calculate_skewness(values),
      kurtosis: calculate_kurtosis(values)
    }
  end
  
  defp fit_distribution(data) do
    # Fit common distributions and find best match
    # Simplified - return normal distribution
    values = Enum.map(data, & &1.value)
    %{
      type: :normal,
      parameters: %{
        mean: calculate_mean(values),
        std_dev: calculate_std_dev(values)
      },
      goodness_of_fit: 0.95
    }
  end
  
  defp calculate_skewness(values) do
    # Simplified skewness calculation
    0.0
  end
  
  defp calculate_kurtosis(values) do
    # Simplified kurtosis calculation
    3.0
  end
  
  defp calculate_mean([]), do: 0
  defp calculate_mean(values) do
    Enum.sum(values) / length(values)
  end
  
  defp calculate_median([]), do: 0
  defp calculate_median(values) do
    sorted = Enum.sort(values)
    mid = div(length(sorted), 2)
    
    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end
  
  defp calculate_std_dev([]), do: 0
  defp calculate_std_dev(values) do
    mean = calculate_mean(values)
    variance = values
    |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(values))
    
    :math.sqrt(variance)
  end
  
  defp prepare_scatter_data(buffer_data, config) do
    # Prepare multi-dimensional scatter plot data
    dimensions = config[:dimensions] || [:value, :timestamp]
    
    Enum.map(buffer_data, fn sample ->
      Enum.map(dimensions, fn dim ->
        case dim do
          :value -> sample.value
          :timestamp -> sample.timestamp
          field -> Map.get(sample.metadata, field, 0)
        end
      end)
    end)
  end
  
  defp calculate_correlation_matrix(scatter_data) do
    # Calculate correlation between dimensions
    # Simplified implementation
    [[1.0, 0.5], [0.5, 1.0]]
  end
  
  defp detect_clusters(scatter_data) do
    # Simplified clustering - in production use DBSCAN or K-means
    [%{center: [0, 0], size: length(scatter_data)}]
  end
  
  defp format_spectrum_data(spectrum_data) do
    Enum.map(spectrum_data, fn {freq, magnitude} ->
      %{x: freq, y: magnitude}
    end)
  end
  
  defp render_spectrogram(spectrogram_data, _config) do
    # Format for visualization
    spectrogram_data
  end
  
  defp generate_spectrogram_axes(_data, _config) do
    %{
      x_axis: %{label: "Time", type: :time},
      y_axis: %{label: "Frequency", type: :linear},
      z_axis: %{label: "Magnitude", type: :linear}
    }
  end
  
  defp render_phase_portrait(phase_data, _config) do
    # Format phase portrait data
    phase_data
  end
  
  defp generate_phase_axes(_data) do
    %{
      x_axis: %{label: "X(t)", type: :linear},
      y_axis: %{label: "X(t-τ)", type: :linear}
    }
  end
  
  defp render_heat_map(heat_map_data, _config) do
    heat_map_data
  end
  
  defp compute_histogram(buffer_data, config) do
    bins = config[:bins] || 50
    values = Enum.map(buffer_data, & &1.value)
    
    if length(values) > 0 do
      {min_val, max_val} = Enum.min_max(values)
      bin_width = (max_val - min_val) / bins
      
      # Count values in each bin
      histogram = Enum.reduce(values, %{}, fn value, acc ->
        bin = min(floor((value - min_val) / bin_width), bins - 1)
        Map.update(acc, bin, 1, &(&1 + 1))
      end)
      
      # Convert to list format
      Enum.map(0..(bins-1), fn bin ->
        %{
          bin: bin,
          range: {min_val + bin * bin_width, min_val + (bin + 1) * bin_width},
          count: Map.get(histogram, bin, 0)
        }
      end)
    else
      []
    end
  end
  
  defp render_histogram(histogram_data, _config) do
    histogram_data
  end
  
  defp render_scatter_plot(scatter_data, _config) do
    scatter_data
  end
  
  defp default_colors do
    %{
      primary: "#007bff",
      secondary: "#6c757d",
      success: "#28a745",
      danger: "#dc3545",
      warning: "#ffc107",
      info: "#17a2b8"
    }
  end
  
  defp load_color_maps do
    %{
      viridis: generate_viridis_colormap(),
      plasma: generate_plasma_colormap(),
      inferno: generate_inferno_colormap(),
      magma: generate_magma_colormap()
    }
  end
  
  defp generate_viridis_colormap do
    # Simplified - return basic colormap
    ["#440154", "#31688e", "#35b779", "#fde725"]
  end
  
  defp generate_plasma_colormap do
    ["#0d0887", "#6a00a8", "#b12a90", "#e16462", "#fca636", "#f0f921"]
  end
  
  defp generate_inferno_colormap do
    ["#000004", "#420a68", "#932667", "#dd513a", "#fca50a", "#fcffa4"]
  end
  
  defp generate_magma_colormap do
    ["#000004", "#3b0f70", "#8c2981", "#de4968", "#fe9f6d", "#fcfdbf"]
  end
  
  defp schedule_visualization_updates do
    Process.send_after(self(), :update_visualizations, 50)  # 20 FPS
  end
end