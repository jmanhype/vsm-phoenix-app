# Security Directory Context

This directory implements cryptographic security for VSM communications.

## Files in this directory:
- `supervisor.ex` - Supervises the CryptoLayer
- `crypto_layer.ex` - All cryptographic operations and key management

## Key Features:
- AES-256-GCM encryption
- HMAC-SHA256/512 signatures
- Automatic key rotation (24hr)
- Ephemeral keys for Perfect Forward Secrecy (1hr)
- Replay protection with nonces

## Quick Start:
```elixir
# Initialize a node
CryptoLayer.initialize_node("my_node")

# Encrypt a message
{:ok, encrypted} = CryptoLayer.encrypt_message(data, recipient_id)

# Establish secure channel
{:ok, channel} = CryptoLayer.establish_secure_channel(node1, node2)
```

## Integration Points:
- Cortical Attention Engine affects encryption strength (high attention = stronger crypto)
- Consensus coordinates key rotation across nodes
- Telemetry monitors crypto performance with FFT analysis for timing attacks
- Circuit breakers protect against crypto overload