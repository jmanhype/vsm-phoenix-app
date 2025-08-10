# Service Bus Directory

Microsoft Azure Service Bus integration for enterprise-scale VSM deployment.

## Files in this directory:

- `connector.ex` - Azure Service Bus AMQP 1.0 connector

## Purpose:
Enables VSM Phoenix to integrate with Microsoft Azure Service Bus for enterprise messaging at massive scale. Service Bus provides reliable, secure message delivery across cloud and hybrid environments.

## Key Features:
- AMQP 1.0 protocol support
- Queue creation for VSM instances
- Topic/subscription patterns for recursive signals
- Enterprise-grade reliability
- Cloud-scale messaging

## Configuration:
Requires environment variables:
- `AZURE_SERVICE_BUS_NAMESPACE` - Your Service Bus namespace
- `AZURE_SERVICE_BUS_KEY_NAME` - Access key name (default: RootManageSharedAccessKey)
- `AZURE_SERVICE_BUS_KEY` - Access key value

## Integration with VSM:
- Each VSM instance can have its own queue
- Recursive signals published to topics
- Enables multi-cloud VSM deployments
- Supports enterprise compliance requirements

## Usage:
```elixir
# Create queue for VSM instance
ServiceBus.Connector.create_vsm_queue("vsm_production_1")

# Publish recursive signal
ServiceBus.Connector.publish_recursive_signal(signal)
```