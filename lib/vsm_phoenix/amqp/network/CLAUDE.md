# Network Optimization Module

Optimizes AMQP message delivery through batching and compression.

## network_optimizer.ex

### Purpose:
Reduces network overhead and improves throughput by intelligently batching messages and compressing large payloads.

### Key Features:
- **Message batching** - Groups up to 50 messages
- **Auto-compression** - Compresses payloads > 1KB  
- **Priority bypass** - Critical messages sent immediately
- **Adaptive timeouts** - Adjusts based on network conditions

### API:
```elixir
# Send optimized message
NetworkOptimizer.send_optimized(channel, exchange, routing_key, message,
  immediate: false  # Allow batching
)

# Force flush batches
NetworkOptimizer.flush_all()

# Get performance metrics
NetworkOptimizer.get_metrics()
```

### DSP Integration:
- Uses SignalProcessor to analyze traffic patterns
- Detects periodic bursts and adjusts batch timing
- Predicts load spikes and pre-optimizes

### Optimization Rules:
- Critical priority → Send immediately
- Batch full (50 msgs) → Flush
- Timeout (100ms) → Flush  
- Large payload → Compress