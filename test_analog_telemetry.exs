# Test script for Analog-Signal Telemetry Integration
# Run with: mix run test_analog_telemetry.exs

alias VsmPhoenix.Telemetry.{
  AnalogArchitect,
  SignalProcessor,
  PatternDetector,
  AdaptiveController,
  SignalVisualizer,
  TelegramIntegration
}

IO.puts("\n🎛️ Testing Analog-Signal Telemetry Architecture...\n")

# Wait for system to initialize
Process.sleep(2000)

# Simulate Telegram activity
IO.puts("📱 Simulating Telegram bot activity...")

# Record some messages
for i <- 1..10 do
  TelegramIntegration.record_message(%{
    chat_id: "test_chat_#{i}",
    user_id: "user_#{rem(i, 3)}",
    text: "Test message #{i} with some content"
  })
  Process.sleep(100)
end

# Record some commands
for i <- 1..5 do
  TelegramIntegration.record_command(
    "/test_command_#{i}",
    :rand.uniform(500) # Random execution time
  )
  Process.sleep(200)
end

# Record some errors
TelegramIntegration.record_error(:api_error, %{code: 500, message: "Test error"})
TelegramIntegration.record_error(:timeout, %{duration: 5000})

Process.sleep(1000)

# Check health
IO.puts("\n📊 Checking Telegram health via analog telemetry...")
{:ok, health} = TelegramIntegration.get_telegram_health()

IO.puts("\nOverall Health: #{health.overall_health}")
IO.puts("Status: #{health.status}")
IO.puts("Uptime: #{health.uptime} seconds")
IO.puts("Total Messages: #{health.total_messages}")
IO.puts("Total Errors: #{health.total_errors}")

IO.puts("\nComponent Health:")
IO.inspect(health.components, pretty: true)

# Get performance dashboard
IO.puts("\n📈 Fetching performance dashboard...")
case TelegramIntegration.get_performance_dashboard() do
  {:ok, dashboard} ->
    IO.puts("Dashboard data retrieved successfully")
    IO.inspect(Map.keys(dashboard), label: "Available visualizations")
  error ->
    IO.puts("Failed to get dashboard: #{inspect(error)}")
end

# Test signal analysis
IO.puts("\n🔬 Testing signal analysis capabilities...")

# Get raw signal data
{:ok, message_rate_data} = AnalogArchitect.get_signal_data("telegram_message_rate", %{last_n: 10})
IO.puts("Message rate samples: #{message_rate_data.sample_count}")

# Detect patterns
{:ok, patterns} = PatternDetector.detect_patterns("telegram_message_rate", [:trend, :anomaly])
IO.puts("Pattern detection results:")
IO.inspect(patterns, pretty: true)

IO.puts("\n✅ Analog telemetry test complete!")