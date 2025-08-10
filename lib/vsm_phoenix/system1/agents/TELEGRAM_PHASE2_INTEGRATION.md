# Telegram Bot Phase 2 Integration Guide

## Overview

This guide shows how the Telegram bot integrates with all Phase 2 components, leveraging the archaeological findings from all VSM swarms.

## Component Integration Map

### 1. CRDT Integration (My Implementation)

```elixir
# In telegram_agent.ex
def handle_message(message, state) do
  # Track user activity in distributed state
  ContextStore.increment_counter("telegram_messages")
  ContextStore.add_to_set("active_telegram_users", message.from.id)
  
  # Store conversation context
  ContextStore.update_lww_set("conversations", message.chat.id, %{
    last_message: message.text,
    timestamp: DateTime.utc_now()
  })
end
```

### 2. Security Integration (My Implementation)

```elixir
# Encrypt sensitive commands
def handle_admin_command(command, from, state) do
  {:ok, encrypted} = CryptoLayer.encrypt_message(
    %{command: command, from: from},
    "vsm_audit_node"
  )
  
  SecureContextRouter.route_command("system5", encrypted)
end
```

### 3. Cortical Attention-Engine Integration (VSM-Intelligence)

```elixir
# Score messages for priority handling
def prioritize_message(message, state) do
  # 5-dimensional scoring
  {:ok, score, dimensions} = CorticalAttentionEngine.score_attention(
    message.text,
    %{
      source: :telegram,
      user_id: message.from.id,
      chat_type: message.chat.type
    }
  )
  
  # Dimensions: {urgency, complexity, uncertainty, impact, novelty}
  case score do
    s when s > 0.9 -> handle_critical_message(message, dimensions)
    s when s > 0.7 -> handle_important_message(message, dimensions)
    _ -> handle_normal_message(message)
  end
end
```

### 4. Consensus Integration (VSM-Infra)

```elixir
# Multi-admin commands require consensus
def handle_multi_admin_command(command, admins, state) do
  case Consensus.propose(
    "telegram_bot",
    :admin_command,
    %{command: command, proposed_by: hd(admins)},
    quorum_size: length(admins) / 2 + 1
  ) do
    {:ok, :committed} -> execute_admin_command(command)
    {:error, :rejected} -> send_message("Command rejected by consensus")
  end
end
```

### 5. Telemetry Integration (VSM-Persistence)

```elixir
# Rich telemetry for bot operations
def emit_telemetry(event, measurements, metadata) do
  :telemetry.execute(
    [:vsm, :telegram, event],
    measurements,
    Map.merge(metadata, %{
      node: node(),
      bot_name: "@VaoAssitantBot"
    })
  )
  
  # Special handling for performance metrics
  if event == :message_processing do
    # FFT analysis for response time patterns
    TelemetryAnalyzer.analyze_response_pattern(measurements.duration)
  end
end
```

### 6. Circuit Breaker Protection (VSM-Resilience)

```elixir
# Protect Telegram API calls
def send_message_protected(chat_id, text, opts \\ []) do
  CircuitBreaker.call(
    :telegram_api,
    fn -> Telegram.send_message(chat_id, text, opts) end,
    timeout: 5_000,
    fallback: fn -> 
      # Store for retry
      ContextStore.add_to_set("telegram_pending_messages", {chat_id, text})
      {:error, :circuit_open}
    end
  )
end
```

## Practical Integration Examples

### High-Priority Message Flow

```elixir
# Complete flow with all Phase 2 components
def process_urgent_command(message) do
  # 1. Attention scoring
  {:ok, score, _} = CorticalAttentionEngine.score_attention(message.text, context)
  
  # 2. CRDT tracking
  ContextStore.increment_counter("urgent_commands")
  
  # 3. Encrypt if sensitive
  encrypted = if score > 0.95 do
    {:ok, enc} = CryptoLayer.encrypt_message(message, "queen_system5")
    enc
  else
    message
  end
  
  # 4. Consensus if multi-admin
  if requires_consensus?(message) do
    Consensus.propose("telegram", :urgent_command, encrypted)
  else
    # 5. Circuit breaker protected execution
    CircuitBreaker.call(:command_execution, fn ->
      execute_command(encrypted)
    end)
  end
  
  # 6. Telemetry
  :telemetry.execute(
    [:vsm, :telegram, :urgent_command],
    %{attention_score: score},
    %{command_type: extract_type(message)}
  )
end
```

### Distributed Bot State

```elixir
# Bot state synchronized across nodes
def sync_bot_state do
  %{
    # From CRDT
    total_messages: ContextStore.get_counter_value("telegram_messages"),
    active_users: ContextStore.get_set_members("active_telegram_users"),
    
    # From Security
    encrypted_configs: CryptoLayer.get_encrypted_configs(),
    
    # From Telemetry
    performance_metrics: TelemetryAnalyzer.get_bot_metrics(),
    
    # From Consensus
    pending_decisions: Consensus.get_pending_proposals("telegram"),
    
    # From Circuit Breakers
    api_health: CircuitBreaker.status(:telegram_api)
  }
end
```

## Configuration for Full Integration

```elixir
# In config/config.exs
config :vsm_phoenix, :telegram,
  # Basic bot config
  bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
  
  # Phase 2 integrations
  enable_crdt_sync: true,
  enable_encryption: true,
  attention_threshold: 0.7,
  consensus_admins: ["admin1", "admin2", "admin3"],
  circuit_breaker_threshold: 5,
  telemetry_sample_rate: 1.0,
  
  # Security settings
  encrypt_admin_commands: true,
  key_rotation_interval: :daily,
  
  # Performance
  batch_crdt_updates: true,
  compression_threshold: 1024
```

## Benefits of Full Integration

1. **High Availability**: Bot state replicated across nodes (CRDT)
2. **Security**: Sensitive data encrypted end-to-end (CryptoLayer)
3. **Smart Prioritization**: 5D attention scoring for message handling
4. **Democratic Control**: Multi-admin consensus for critical operations
5. **Observability**: Rich telemetry with FFT analysis
6. **Resilience**: Circuit breakers prevent cascade failures

## Monitoring Dashboard Queries

```elixir
# Real-time bot health
%{
  messages_per_minute: ContextStore.get_counter_rate("telegram_messages"),
  active_users: MapSet.size(ContextStore.get_set_members("active_telegram_users")),
  attention_distribution: CorticalAttentionEngine.get_score_histogram(:telegram),
  encryption_ops: CryptoLayer.get_metrics().telegram_operations,
  consensus_pending: Consensus.pending_count("telegram"),
  circuit_status: CircuitBreaker.all_status() |> Map.get(:telegram_api),
  latency_fft: TelemetryAnalyzer.get_fft_analysis(:telegram_response_time)
}
```

## Future Enhancements

1. **Attention-Based Rate Limiting**: Use 5D scores to prioritize users
2. **Encrypted Group Chats**: End-to-end encryption for group conversations  
3. **Consensus-Based Moderation**: Democratic content moderation
4. **Predictive Circuit Breaking**: FFT analysis predicts API failures
5. **CRDT-Based Presence**: Distributed online/offline tracking