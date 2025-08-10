# Simple test of Analog Telemetry
# Run with: mix run test_telemetry_simple.exs

alias VsmPhoenix.Telemetry.{AnalogArchitect, PatternDetector}

IO.puts("\n🎛️ Simple Analog Telemetry Test...\n")

# Wait for system to start
Process.sleep(3000)

# Register a test signal
IO.puts("📡 Registering test signal...")
:ok = AnalogArchitect.register_signal("simple_test", %{
  sampling_rate: :standard,
  buffer_size: 100,
  analysis_modes: [:basic, :trend]
})

# Sample some data
IO.puts("📈 Sampling data...")
for i <- 1..20 do
  value = 10 + :math.sin(i / 3) * 5
  AnalogArchitect.sample_signal("simple_test", value, %{index: i})
  Process.sleep(100)
end

# Get data
IO.puts("📊 Retrieving data...")
{:ok, data} = AnalogArchitect.get_signal_data("simple_test", %{})
IO.puts("Samples collected: #{data.sample_count}")

# Basic analysis
{:ok, basic} = AnalogArchitect.analyze_waveform("simple_test", :basic)
IO.puts("\nBasic statistics:")
IO.inspect(basic, pretty: true)

# Trend analysis
{:ok, trend} = AnalogArchitect.analyze_waveform("simple_test", :trend)
IO.puts("\nTrend analysis:")
IO.inspect(trend, pretty: true)

IO.puts("\n✅ Test complete!")