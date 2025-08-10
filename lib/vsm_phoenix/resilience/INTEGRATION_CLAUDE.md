# Resilience Integration Examples

This file shows concrete examples of integrating resilience patterns with other Phase 2 components.

## 1. Protecting SecureContextRouter

```elixir
# In your code that uses SecureContextRouter
alias VsmPhoenix.Resilience.Integration

# Protect CRDT sync operations
def sync_with_resilience(agent_id, context) do
  Integration.with_bulkhead(:crdt_sync, fn _resource ->
    Integration.with_circuit_breaker(:crdt_network, fn ->
      SecureContextRouter.sync_context(agent_id, context)
    end)
  end, timeout: 30_000)
end

# Protect cryptographic operations
def encrypt_with_resilience(data) do
  Integration.with_circuit_breaker(:crypto_operations, fn ->
    CryptoLayer.encrypt(data)
  end)
end
```

## 2. Protecting CorticalAttentionEngine

```elixir
# Prevent attention overload
def score_with_protection(message, context) do
  # Check fatigue first
  fatigue = CorticalAttentionEngine.get_fatigue_level()
  
  if fatigue > 0.9 do
    {:error, :attention_exhausted}
  else
    Integration.with_bulkhead(:attention_scoring, fn _resource ->
      CorticalAttentionEngine.score_attention(message, context)
    end, timeout: 500)  # Fast timeout
  end
end
```

## 3. Protecting Consensus Operations

```elixir
# Ensure consensus reliability
def propose_with_resilience(topic, value, opts) do
  Integration.with_circuit_breaker(:consensus_protocol, fn ->
    # Check participant health first
    participants = Discovery.find_capable(:consensus_participant)
    
    if length(participants) >= opts[:quorum] do
      Integration.with_bulkhead(:consensus_proposals, fn _resource ->
        Consensus.propose(topic, value, opts)
      end)
    else
      {:error, :insufficient_participants}
    end
  end)
end
```

## 4. Protecting Telemetry DSP

```elixir
# Protect CPU-intensive operations
def apply_fft_with_protection(signal, opts) do
  # Check signal size
  if length(signal) > 10_000 do
    # Large FFT needs chunking
    apply_chunked_fft(signal, opts)
  else
    Integration.with_bulkhead(:dsp_operations, fn _resource ->
      Integration.with_circuit_breaker(:fft_processor, fn ->
        SignalProcessor.apply_fft(signal, opts)
      end)
    end, timeout: 2_000)
  end
end

# Detect anomaly storms
def detect_anomalies_safely(signal_name, window) do
  result = Integration.with_circuit_breaker(:anomaly_detector, fn ->
    SignalProcessor.detect_anomalies(signal_name, window)
  end)
  
  case result do
    {:ok, anomalies} when length(anomalies) > 50 ->
      # Too many anomalies - trip circuit
      {:error, :anomaly_storm}
    other ->
      other
  end
end
```

## Configuration for Phase 2 Components

Add these to `config.ex`:

```elixir
# Crypto operations need quick failure
def circuit_breaker_config(:crypto_operations) do
  %{
    failure_threshold: 3,
    reset_timeout: 60_000,
    timeout: 5_000
  }
end

# Attention can handle more failures
def circuit_breaker_config(:attention_scoring) do
  %{
    failure_threshold: 10,
    reset_timeout: 5_000,
    timeout: 1_000
  }
end

# Consensus is critical
def circuit_breaker_config(:consensus_protocol) do
  %{
    failure_threshold: 2,
    reset_timeout: 30_000,
    timeout: 10_000
  }
end

# DSP needs balanced config
def circuit_breaker_config(:dsp_operations) do
  %{
    failure_threshold: 5,
    reset_timeout: 10_000,
    timeout: 3_000
  }
end
```

## Health Monitoring Integration

```elixir
# Register component health checks
def register_all_health_checks do
  # Crypto health
  HealthMonitor.register_component(:crypto_operations, fn ->
    case CircuitBreaker.get_state(:crypto_operations) do
      %{state: :closed} -> :ok
      %{state: :half_open} -> {:degraded, %{reason: "recovering"}}
      %{state: :open} -> {:error, :circuit_open}
    end
  end)
  
  # Attention health based on fatigue
  HealthMonitor.register_component(:attention_engine, fn ->
    fatigue = CorticalAttentionEngine.get_fatigue_level()
    cond do
      fatigue < 0.5 -> :ok
      fatigue < 0.7 -> {:degraded, %{fatigue: fatigue}}
      true -> {:error, :attention_exhausted}
    end
  end)
  
  # Add similar checks for consensus and DSP...
end
```

## Testing Resilience

```elixir
# Test circuit breaker behavior
test "crypto circuit breaker opens on failures" do
  # Force failures
  for _ <- 1..3 do
    CircuitBreaker.call(:crypto_operations, fn ->
      raise "Crypto error"
    end)
  end
  
  # Circuit should be open
  state = CircuitBreaker.get_state(:crypto_operations)
  assert state.state == :open
end

# Test bulkhead isolation
test "attention scoring isolates resources" do
  # Fill bulkhead
  tasks = for _ <- 1..50 do
    Task.async(fn ->
      Integration.with_bulkhead(:attention_scoring, fn _ ->
        Process.sleep(100)
      end, timeout: 200)
    end)
  end
  
  # Next request should fail
  assert {:error, :bulkhead_full} = 
    Integration.with_bulkhead(:attention_scoring, fn _ -> :ok end)
end
```