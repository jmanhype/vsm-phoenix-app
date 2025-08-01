# System 3 Audit Bypass Flow

## Overview

The S3 Audit Bypass provides a privileged mechanism for System 3 (Control) to directly inspect any System 1 agent without going through System 2 coordination. This is a critical capability for emergency diagnostics, security audits, and anomaly investigation.

## Architecture

```
┌─────────────────────┐
│   System 3 Control  │
│  (Resource Mgmt)    │
└──────────┬──────────┘
           │
           │ audit/2
           ▼
┌─────────────────────┐      ┌─────────────────────┐
│   Audit Channel     │      │   System 2          │
│  (Direct Bypass)    │      │  (Coordinator)      │
└──────────┬──────────┘      └─────────────────────┘
           │                           ❌ BYPASSED
           │ AMQP RPC
           │ vsm.s1.{target}.command
           ▼
┌─────────────────────┐
│   System 1 Agent    │
│  (Direct Access)    │
└─────────────────────┘
```

## Audit Flow

### 1. Initiate Audit

```elixir
# From System 3 Control
VsmPhoenix.System3.Control.audit(:operations_context, [
  operation: :dump_state  # or :get_metrics, :get_resources
])
```

### 2. Audit Channel Processing

The AuditChannel:
- Generates a unique audit ID and correlation ID
- Creates an audit request with bypass flag
- Publishes directly to S1's command queue via AMQP
- Sets timeout for response (5 seconds default)

### 3. S1 Agent Response

Each S1 agent:
- Listens on `vsm.s1.{context_name}.command` queue
- Recognizes audit commands by type and bypass flag
- Executes requested operation without S2 coordination
- Returns response via `vsm.audit.responses` queue

### 4. Response Handling

The AuditChannel:
- Correlates response with pending audit
- Calculates response time
- Emits telemetry events
- Returns result to caller

## Security Considerations

### Authorization

- Only System 3 can initiate audit bypasses
- Each audit is logged with timestamp and requester
- Audit operations are read-only (no state modification)

### Logging

All audits generate:
- Audit log entries in S3 Control state
- Telemetry events for monitoring
- AMQP message traces

### Valid Use Cases

1. **Emergency Diagnostics**: When S2 is unresponsive
2. **Resource Auditing**: Verify actual vs reported usage
3. **Security Investigation**: Check for unauthorized state
4. **Performance Analysis**: Direct metric collection
5. **Anomaly Detection**: Investigate suspicious behavior

## Audit Operations

### dump_state
Returns complete S1 state including:
- Operational state
- Current metrics
- Resource allocation
- Coordination state
- Health status
- Active operations count
- Configuration
- Meta-systems list

### get_metrics
Returns only the metrics map from S1 state

### get_resources
Returns only the resource allocation map

## Telemetry Events

### Emitted by S3 Control

```elixir
:telemetry.execute(
  [:vsm, :system3, :audit],
  %{count: 1},
  %{target: target, operation: operation, bypass: true}
)
```

### Emitted by Audit Channel

```elixir
# On completion
:telemetry.execute(
  [:vsm, :system3, :audit, :complete],
  %{response_time: ms},
  %{target: target, operation: operation, success: boolean}
)

# On timeout
:telemetry.execute(
  [:vsm, :system3, :audit, :timeout],
  %{count: 1},
  %{target: target, operation: operation}
)
```

### Emitted by S1 Agent

```elixir
:telemetry.execute(
  [:vsm, :system1, :audit],
  %{count: 1},
  %{context: context, operation: operation, requester: requester}
)
```

## AMQP Message Format

### Audit Request

```json
{
  "type": "audit_command",
  "operation": "dump_state",
  "target": "operations_context",
  "requester": "system3_control",
  "timestamp": "2024-01-20T10:30:00Z",
  "bypass_coordination": true,
  "audit_id": "AUDIT-1234567890",
  "correlation_id": "audit-1234567890-0",
  "reply_to": "vsm.audit.responses"
}
```

### Audit Response

```json
{
  "status": "success",
  "context": "operations_context",
  "state": {
    "operational_state": "active",
    "metrics": {...},
    "resources": {...},
    "health": 0.95,
    "active_operations": 3
  },
  "timestamp": "2024-01-20T10:30:01Z"
}
```

## Implementation Details

### AuditChannel GenServer

- Maintains pending audits map
- Handles timeout with Process.send_after
- Supports bulk audits via Task.Supervisor
- Stores audit history (last 1000 entries)

### S1 Context Integration

- Sets up audit AMQP channel during init
- Handles audit commands in handle_info(:basic_deliver)
- Publishes responses to reply_to queue
- Maintains audit_channel in state

### Error Handling

- Timeout after 5 seconds (configurable)
- Channel failures trigger retry
- Invalid operations return error response
- All errors logged and tracked

## Testing

Run the test script to verify audit bypass:

```bash
elixir scripts/test_s3_audit_bypass.exs
```

This tests:
1. Direct audit of single S1
2. Bulk audit of multiple S1s
3. Resource-specific audits
4. Metrics collection
5. Timeout handling

## Future Enhancements

1. **Audit Policies**: Define what S3 can audit and when
2. **Rate Limiting**: Prevent audit abuse
3. **Audit Trails**: Persistent storage of audit history
4. **Alerting**: Notify on suspicious audit patterns
5. **Encryption**: Secure audit data in transit