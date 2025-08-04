# VSM Phoenix API Documentation

Comprehensive API documentation for the Viable Systems Model (VSM) Phoenix application, covering all Phase 2 features and production-ready endpoints.

## Base URL
```
Development: http://localhost:4000
Production: https://your-domain.com
```

## OpenAPI Specification

```yaml
openapi: 3.0.3
info:
  title: VSM Phoenix API
  description: Viable Systems Model Phoenix Application API
  version: 2.0.0
  contact:
    name: VSM Phoenix Team
    url: https://github.com/your-org/vsm_phoenix_app
servers:
  - url: http://localhost:4000
    description: Development server
  - url: https://your-domain.com
    description: Production server

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    SystemStatus:
      type: object
      properties:
        system_id:
          type: integer
          example: 5
        status:
          type: string
          enum: [healthy, degraded, critical]
        health_score:
          type: number
          format: float
          minimum: 0.0
          maximum: 1.0
        metrics:
          type: object
        last_updated:
          type: string
          format: date-time
    
    Agent:
      type: object
      properties:
        id:
          type: string
          format: uuid
        type:
          type: string
          enum: [worker, llm_worker, sensor, api, telegram]
        status:
          type: string
          enum: [active, idle, error, terminated]
        capabilities:
          type: array
          items:
            type: string
        created_at:
          type: string
          format: date-time
        metrics:
          type: object
    
    PolicyDecision:
      type: object
      properties:
        type:
          type: string
          enum: [resource_allocation, adaptation, governance, emergency]
        priority:
          type: string
          enum: [low, medium, high, critical]
        context:
          type: object
        timeout_ms:
          type: integer
          default: 30000
    
    AlgedonicSignal:
      type: object
      properties:
        intensity:
          type: number
          format: float
          minimum: 0.0
          maximum: 1.0
        context:
          type: string
        source:
          type: string
        timestamp:
          type: string
          format: date-time
    
    Error:
      type: object
      properties:
        error:
          type: string
        message:
          type: string
        details:
          type: object
        timestamp:
          type: string
          format: date-time

security:
  - bearerAuth: []

paths:
```

## Authentication

The VSM Phoenix API uses JWT Bearer tokens for authentication. Include the token in the Authorization header:

```http
Authorization: Bearer <your-jwt-token>
```

### Authentication Endpoints

#### Login
```http
POST /auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "your-password"
}
```

**Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_in": 3600,
  "refresh_token": "refresh_token_here"
}
```

#### Refresh Token
```http
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "your-refresh-token"
}
```

## Core VSM System Endpoints

### System Status

#### Get Overall System Status
```http
GET /api/vsm/status
```

**Response:**
```json
{
  "overall_viability": 0.87,
  "systems": {
    "system1": {
      "status": "healthy",
      "health_score": 0.92,
      "active_agents": 12,
      "success_rate": 0.94
    },
    "system2": {
      "status": "healthy",
      "health_score": 0.88,
      "coordination_effectiveness": 0.89,
      "message_flows": 245
    },
    "system3": {
      "status": "healthy",
      "health_score": 0.85,
      "resource_efficiency": 0.91,
      "utilization": 0.76
    },
    "system4": {
      "status": "healthy",
      "health_score": 0.90,
      "scan_coverage": 0.82,
      "adaptation_readiness": 0.87
    },
    "system5": {
      "status": "healthy",
      "health_score": 0.93,
      "policy_coherence": 0.91,
      "strategic_alignment": 0.88
    }
  },
  "last_updated": "2025-08-04T10:30:00Z"
}
```

#### Get Individual System Status
```http
GET /api/vsm/system/{level}
```

**Parameters:**
- `level` (path): System level (1-5)

**Example: GET /api/vsm/system/5**
```json
{
  "system_id": 5,
  "name": "Queen (Policy & Identity)",
  "status": "healthy",
  "health_score": 0.93,
  "metrics": {
    "policy_coherence": 0.91,
    "identity_preservation": 0.94,
    "strategic_alignment": 0.88,
    "decision_latency_ms": 45,
    "active_policies": 23
  },
  "recent_activities": [
    {
      "type": "policy_synthesis",
      "timestamp": "2025-08-04T10:25:00Z",
      "context": "Resource allocation anomaly detected"
    }
  ],
  "last_updated": "2025-08-04T10:30:00Z"
}
```

### Policy Management

#### Request Policy Decision
```http
POST /api/vsm/system5/decision
Content-Type: application/json

{
  "type": "resource_allocation",
  "priority": "high",
  "context": {
    "resource": "compute",
    "amount": 50,
    "requestor": "system3",
    "reason": "High load detected"
  },
  "timeout_ms": 30000
}
```

**Response:**
```json
{
  "decision_id": "dec_abc123",
  "decision": "approved",
  "reasoning": "Resource allocation approved based on historical patterns and current system health",
  "implementation_steps": [
    "Allocate 50 compute units from reserve pool",
    "Monitor resource utilization for 1 hour",
    "Generate utilization report"
  ],
  "auto_executable": true,
  "executed_at": "2025-08-04T10:30:15Z",
  "expires_at": "2025-08-04T11:30:15Z"
}
```

### Algedonic Signals

#### Send Pleasure Signal
```http
POST /api/vsm/algedonic/pleasure
Content-Type: application/json

{
  "intensity": 0.8,
  "context": "Successful task completion - 95% success rate achieved",
  "source": "system1_agent_worker_01"
}
```

#### Send Pain Signal
```http
POST /api/vsm/algedonic/pain
Content-Type: application/json

{
  "intensity": 0.6,
  "context": "Resource exhaustion warning - CPU at 90%",
  "source": "system3_resource_monitor"
}
```

**Response (both):**
```json
{
  "signal_id": "sig_xyz789",
  "processed": true,
  "viability_impact": -0.02,
  "triggered_policies": [
    "emergency_resource_allocation"
  ],
  "timestamp": "2025-08-04T10:30:00Z"
}
```

## Agent Management (System 1)

### Create Agent
```http
POST /api/vsm/agents
Content-Type: application/json

{
  "type": "llm_worker",
  "capabilities": ["llm_reasoning", "mcp_tools", "task_planning"],
  "config": {
    "llm_model": "gpt-4",
    "max_context_length": 8192,
    "temperature": 0.7
  },
  "resources": {
    "cpu_limit": 2.0,
    "memory_limit": "4GB"
  }
}
```

**Response:**
```json
{
  "agent": {
    "id": "agent_llm_001",
    "type": "llm_worker",
    "status": "active",
    "capabilities": ["llm_reasoning", "mcp_tools", "task_planning"],
    "created_at": "2025-08-04T10:30:00Z",
    "health_score": 1.0,
    "metrics": {
      "tasks_completed": 0,
      "average_response_time_ms": 0,
      "success_rate": 0.0
    }
  }
}
```

### List Agents
```http
GET /api/vsm/agents
```

**Query Parameters:**
- `type` (optional): Filter by agent type
- `status` (optional): Filter by status
- `limit` (optional): Maximum number of agents to return (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Response:**
```json
{
  "agents": [
    {
      "id": "agent_worker_001",
      "type": "worker",
      "status": "active",
      "capabilities": ["process_data", "transform", "analyze"],
      "created_at": "2025-08-04T09:15:00Z",
      "health_score": 0.95,
      "metrics": {
        "tasks_completed": 142,
        "average_response_time_ms": 23,
        "success_rate": 0.97
      }
    }
    // ... more agents
  ],
  "total_count": 12,
  "active_count": 10,
  "pagination": {
    "limit": 50,
    "offset": 0,
    "has_more": false
  }
}
```

### Get Agent Details
```http
GET /api/vsm/agents/{agent_id}
```

**Response:**
```json
{
  "agent": {
    "id": "agent_llm_001",
    "type": "llm_worker",
    "status": "active",
    "capabilities": ["llm_reasoning", "mcp_tools", "task_planning"],
    "created_at": "2025-08-04T10:30:00Z",
    "health_score": 0.92,
    "config": {
      "llm_model": "gpt-4",
      "max_context_length": 8192,
      "temperature": 0.7
    },
    "metrics": {
      "tasks_completed": 37,
      "average_response_time_ms": 1250,
      "success_rate": 0.95,
      "errors_count": 2,
      "last_activity": "2025-08-04T10:45:00Z"
    },
    "recent_tasks": [
      {
        "task_id": "task_abc123",
        "command": "llm_reasoning",
        "status": "completed",
        "duration_ms": 1100,
        "timestamp": "2025-08-04T10:45:00Z"
      }
    ]
  }
}
```

### Execute Command on Agent
```http
POST /api/vsm/agents/{agent_id}/command
Content-Type: application/json

{
  "command": "llm_reasoning",
  "params": {
    "prompt": "Analyze the current system performance and suggest optimizations",
    "context": {
      "cpu_usage": 0.75,
      "memory_usage": 0.68,
      "active_tasks": 23
    }
  },
  "timeout_ms": 30000
}
```

**Response:**
```json
{
  "task_id": "task_xyz456",
  "status": "completed",
  "result": {
    "analysis": "System performance is within normal parameters. CPU usage at 75% suggests room for optimization...",
    "recommendations": [
      "Consider load balancing across additional agents",
      "Implement task prioritization",
      "Monitor memory allocation patterns"
    ],
    "confidence": 0.87
  },
  "execution_time_ms": 1247,
  "timestamp": "2025-08-04T10:30:15Z"
}
```

### Terminate Agent
```http
DELETE /api/vsm/agents/{agent_id}
```

**Response:**
```json
{
  "agent_id": "agent_llm_001",
  "status": "terminated",
  "final_metrics": {
    "total_tasks_completed": 37,
    "total_uptime_seconds": 3600,
    "final_success_rate": 0.95
  },
  "terminated_at": "2025-08-04T11:30:00Z"
}
```

## System 3 Audit

### Direct Audit Bypass
```http
POST /api/vsm/audit/bypass
Content-Type: application/json

{
  "target_agents": ["agent_worker_001", "agent_llm_001"],
  "audit_type": "resource_usage",
  "detailed": true
}
```

**Response:**
```json
{
  "audit_id": "audit_abc789",
  "results": {
    "agent_worker_001": {
      "resource_usage": {
        "cpu_usage": 0.45,
        "memory_usage": "1.2GB",
        "network_io": "150MB",
        "disk_io": "50MB"
      },
      "efficiency_score": 0.92,
      "recommendations": ["Optimal performance, no issues detected"]
    },
    "agent_llm_001": {
      "resource_usage": {
        "cpu_usage": 0.78,
        "memory_usage": "3.1GB",
        "network_io": "500MB",
        "disk_io": "25MB"
      },
      "efficiency_score": 0.83,
      "recommendations": ["Consider memory optimization for LLM context handling"]
    }
  },
  "overall_assessment": {
    "resource_efficiency": 0.87,
    "waste_detected": false,
    "optimization_opportunities": 2
  },
  "timestamp": "2025-08-04T10:30:00Z"
}
```

## Telegram Integration

### Webhook Endpoint
```http
POST /api/vsm/telegram/webhook/{agent_id}
Content-Type: application/json

{
  "update_id": 123456789,
  "message": {
    "message_id": 1,
    "from": {
      "id": 987654321,
      "first_name": "John",
      "username": "johndoe"
    },
    "chat": {
      "id": 987654321,
      "type": "private"
    },
    "date": 1625097600,
    "text": "/status"
  }
}
```

### Health Check
```http
GET /api/vsm/telegram/health
```

**Response:**
```json
{
  "status": "healthy",
  "active_bots": 3,
  "total_messages_processed": 1247,
  "average_response_time_ms": 89,
  "last_activity": "2025-08-04T10:45:00Z"
}
```

### Set Webhook (Development)
```http
POST /api/vsm/telegram/set_webhook
Content-Type: application/json

{
  "bot_token": "your-bot-token",
  "webhook_url": "https://your-domain.com/api/vsm/telegram/webhook/agent_telegram_001"
}
```

## MCP (Model Context Protocol)

### Health Check
```http
GET /mcp/health
```

**Response:**
```json
{
  "status": "healthy",
  "mcp_version": "2024-11-05",
  "available_tools": 15,
  "active_sessions": 3,
  "capabilities": {
    "tools": true,
    "resources": true,
    "prompts": false,
    "logging": true
  }
}
```

### JSON-RPC Endpoint
```http
POST /mcp/
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list",
  "params": {}
}
```

**Available MCP Tools:**
- `vsm_scan_environment` - Trigger environmental scanning
- `vsm_synthesize_policy` - Generate policies from data
- `vsm_spawn_meta_system` - Spawn recursive VSM instances
- `vsm_allocate_resources` - Request resource allocation
- `vsm_check_viability` - Get viability metrics
- `vsm_trigger_adaptation` - Generate adaptation proposals
- `analyze_variety` - Analyze variety patterns
- `synthesize_policy` - Policy synthesis from anomalies
- `check_meta_system_need` - Determine meta-system requirements

## WebSocket API (Real-time)

### Connect to Live Updates
```javascript
const socket = new WebSocket('ws://localhost:4000/socket/websocket');

// Subscribe to system updates
socket.send(JSON.stringify({
  topic: 'vsm:health',
  event: 'phx_join',
  payload: {},
  ref: 1
}));

// Listen for updates
socket.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('VSM Update:', data);
};
```

**Available WebSocket Topics:**
- `vsm:health` - System viability updates
- `vsm:metrics` - Performance metrics
- `vsm:coordination` - System 2 coordination events
- `vsm:policy` - Policy updates from System 5
- `vsm:algedonic` - Pleasure/pain signals
- `vsm.registry.events` - Agent registration events
- `vsm:amqp` - AMQP message events

## Error Handling

### Standard Error Response
```json
{
  "error": "validation_error",
  "message": "Invalid agent type specified",
  "details": {
    "field": "type",
    "valid_values": ["worker", "llm_worker", "sensor", "api", "telegram"]
  },
  "timestamp": "2025-08-04T10:30:00Z",
  "request_id": "req_abc123"
}
```

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `409` - Conflict
- `422` - Unprocessable Entity
- `429` - Too Many Requests
- `500` - Internal Server Error
- `503` - Service Unavailable

## Rate Limiting

The API implements rate limiting to ensure system stability:

- **General API**: 1000 requests per hour per API key
- **Agent Commands**: 100 requests per minute per agent
- **MCP Endpoints**: 500 requests per hour per session
- **WebSocket**: 10 connections per user

## Monitoring & Observability

### Health Check Endpoint
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "2.0.0",
  "uptime_seconds": 3600,
  "components": {
    "database": "healthy",
    "amqp": "healthy",
    "redis": "healthy",
    "llm_services": "healthy"
  },
  "metrics": {
    "requests_per_second": 12.5,
    "average_response_time_ms": 45,
    "error_rate": 0.002
  }
}
```

### Metrics Endpoint
```http
GET /metrics
```

Returns Prometheus-compatible metrics for monitoring integration.

## SDK Examples

### JavaScript/Node.js
```javascript
const VsmClient = require('@vsm/phoenix-client');

const client = new VsmClient({
  baseUrl: 'http://localhost:4000',
  apiKey: 'your-api-key'
});

// Get system status
const status = await client.getSystemStatus();
console.log('Viability:', status.overall_viability);

// Create an agent
const agent = await client.createAgent({
  type: 'llm_worker',
  capabilities: ['llm_reasoning', 'task_planning']
});

// Execute command
const result = await client.executeCommand(agent.id, {
  command: 'llm_reasoning',
  params: { prompt: 'Analyze system performance' }
});
```

### Python
```python
import asyncio
from vsm_phoenix_client import VsmClient

async def main():
    client = VsmClient(
        base_url='http://localhost:4000',
        api_key='your-api-key'
    )
    
    # Get system status
    status = await client.get_system_status()
    print(f"Viability: {status['overall_viability']}")
    
    # Create and use agent
    agent = await client.create_agent(
        type='worker',
        capabilities=['process_data', 'analyze']
    )
    
    result = await client.execute_command(
        agent['id'],
        command='analyze',
        params={'data': [1, 2, 3, 4, 5]}
    )
    
if __name__ == '__main__':
    asyncio.run(main())
```

### cURL Examples

#### Get System Status
```bash
curl -H "Authorization: Bearer your-jwt-token" \
     http://localhost:4000/api/vsm/status
```

#### Create Agent
```bash
curl -X POST \
     -H "Authorization: Bearer your-jwt-token" \
     -H "Content-Type: application/json" \
     -d '{
       "type": "worker",
       "capabilities": ["process_data", "analyze"]
     }' \
     http://localhost:4000/api/vsm/agents
```

#### Send Algedonic Signal
```bash
curl -X POST \
     -H "Authorization: Bearer your-jwt-token" \
     -H "Content-Type: application/json" \
     -d '{
       "intensity": 0.8,
       "context": "Task completed successfully",
       "source": "agent_worker_001"
     }' \
     http://localhost:4000/api/vsm/algedonic/pleasure
```

---

## Production Considerations

### Security
- Always use HTTPS in production
- Implement proper JWT token management
- Use environment variables for sensitive configuration
- Enable CORS only for trusted domains
- Implement request validation and sanitization

### Performance
- Enable response caching where appropriate
- Use connection pooling for database and AMQP
- Implement proper error handling and retries
- Monitor API performance with tools like Prometheus
- Configure appropriate timeouts

### Scalability
- Deploy behind a load balancer
- Use Redis for session storage
- Implement horizontal scaling for agents
- Monitor resource usage and auto-scale
- Use database read replicas for heavy read workloads

For more detailed implementation examples and advanced usage patterns, see the `/examples` directory in the repository.
