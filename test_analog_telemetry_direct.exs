# Direct test of Analog Telemetry without full application startup
# Run with: mix run test_analog_telemetry_direct.exs

alias VsmPhoenix.Telemetry.{
  AnalogArchitect,
  SignalProcessor,
  PatternDetector,
  AdaptiveController,
  SignalVisualizer
}

IO.puts("\n🎛️ Testing Analog-Signal Telemetry Architecture (Direct)...\n")

# Start the components manually
{:ok, _} = AnalogArchitect.start_link()
{:ok, _} = SignalProcessor.start_link()
{:ok, _} = PatternDetector.start_link()
{:ok, _} = AdaptiveController.start_link()
{:ok, _} = SignalVisualizer.start_link()

# Register test signals
IO.puts("📡 Registering test signals...")

AnalogArchitect.register_signal("test_message_rate", %{
  sampling_rate: :high_frequency,
  buffer_size: 1000,
  filters: [%{type: :low_pass, params: %{cutoff: 10}}],
  analysis_modes: [:frequency_spectrum, :peak_detection, :anomaly],
  metadata: %{unit: "messages/second"}
})

AnalogArchitect.register_signal("test_error_rate", %{
  sampling_rate: :standard,
  buffer_size: 500,
  filters: [%{type: :high_pass, params: %{cutoff: 0.1}}],
  analysis_modes: [:anomaly, :trend],
  metadata: %{unit: "errors/minute"}
})

# Create adaptive thresholds
IO.puts("\n📏 Setting up adaptive controls...")

AdaptiveController.create_adaptive_threshold("test_message_rate", %{
  strategy: :statistical,
  initial_threshold: 10.0,
  adaptation_rate: 0.1
})

AdaptiveController.create_auto_scaler("test_error_rate", %{
  mode: :dynamic_range,
  input_range: {0, 100},
  output_range: {0, 1}
})

# Simulate data
IO.puts("\n📈 Simulating signal data...")

for i <- 1..50 do
  # Simulate message rate with some noise
  message_rate = 5 + :math.sin(i / 10) * 2 + :rand.uniform() * 0.5
  AnalogArchitect.sample_signal("test_message_rate", message_rate, %{iteration: i})
  
  # Simulate error rate with occasional spikes
  error_rate = if rem(i, 15) == 0 do
    20 + :rand.uniform() * 10  # Spike
  else
    :rand.uniform() * 2  # Normal
  end
  AnalogArchitect.sample_signal("test_error_rate", error_rate, %{iteration: i})
  
  Process.sleep(50)
end

Process.sleep(500)

# Get signal data
IO.puts("\n📊 Analyzing signals...")

{:ok, message_data} = AnalogArchitect.get_signal_data("test_message_rate", %{last_n: 50})
{:ok, error_data} = AnalogArchitect.get_signal_data("test_error_rate", %{last_n: 50})

IO.puts("Message rate samples: #{message_data.sample_count}")
IO.puts("Error rate samples: #{error_data.sample_count}")

# Perform analysis
IO.puts("\n🔬 Performing signal analysis...")

# Frequency analysis
{:ok, freq_analysis} = AnalogArchitect.analyze_waveform("test_message_rate", :frequency_spectrum)
IO.puts("\nFrequency Analysis:")
IO.inspect(freq_analysis, pretty: true)

# Peak detection
{:ok, peaks} = AnalogArchitect.analyze_waveform("test_message_rate", :peak_detection)
IO.puts("\nPeak Detection: Found #{peaks.peak_count} peaks")

# Anomaly detection
{:ok, anomalies} = AnalogArchitect.detect_anomalies("test_error_rate", :statistical)
IO.puts("\nAnomaly Detection: Found #{length(anomalies)} anomalies")
if length(anomalies) > 0 do
  IO.puts("First anomaly:")
  IO.inspect(List.first(anomalies), pretty: true)
end

# Pattern detection
{:ok, patterns} = PatternDetector.detect_patterns("test_message_rate", [:trend, :periodic])
IO.puts("\nPattern Detection:")
IO.inspect(patterns, pretty: true)

# Test adaptive control
IO.puts("\n🎚️ Testing adaptive controls...")

test_values = [5.0, 5.5, 6.0, 15.0, 5.2, 5.1]  # 15.0 is an outlier
for value <- test_values do
  {:ok, controlled} = AdaptiveController.apply_adaptive_control("test_message_rate", value)
  IO.puts("Input: #{value} -> Controlled: #{inspect(controlled)}")
end

# Create visualization
IO.puts("\n🎨 Creating visualizations...")

SignalVisualizer.create_visualization("test_waveform", %{
  type: :waveform,
  signal_ids: ["test_message_rate"],
  update_rate: :fast,
  display_config: %{
    width: 800,
    height: 200,
    colors: %{primary: "#0088cc"}
  }
})

{:ok, viz_data} = SignalVisualizer.get_visualization_data("test_waveform")
IO.puts("Visualization created: #{viz_data.type}")

# Signal mixing test
IO.puts("\n🔀 Testing signal mixing...")

AnalogArchitect.mix_signals("mixed_signal", ["test_message_rate", "test_error_rate"], :average)
{:ok, mixed_data} = AnalogArchitect.get_signal_data("mixed_signal", %{})
IO.puts("Mixed signal samples: #{mixed_data.sample_count}")

IO.puts("\n✅ Analog telemetry test complete!")