# AMQP Directory

This directory contains the Advanced aMCP Protocol Extensions and AMQP infrastructure for VSM Phoenix.

## Files in this directory:

- `supervisor.ex` - Supervises all AMQP components
- `connection_manager.ex` - Manages RabbitMQ connections
- `channel_pool.ex` - Pools AMQP channels for efficiency
- `command_router.ex` - Routes commands to handlers
- `secure_command_router.ex` - Adds HMAC security to routing
- `discovery.ex` - Gossip-based agent discovery protocol
- `consensus.ex` - Multi-phase distributed consensus
- `network_optimizer.ex` - Message batching and compression
- `protocol_integration.ex` - Unified interface for all protocols
- `message_types.ex` - Protocol message definitions

## Purpose:

Provides distributed coordination capabilities including agent discovery, consensus decision-making, and network optimization, all secured with cryptographic signatures.

## Key Integration:
- Uses Queen's Security infrastructure for HMAC signing
- Integrates with Intelligence's CorticalAttentionEngine for priority scoring
- Leverages Persistence's SignalProcessor for pattern detection
- Protected by Resilience's CircuitBreakers