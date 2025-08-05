# VSM Phoenix Phase 2 API Documentation

## Overview

VSM Phoenix Phase 2 introduces advanced cybernetic features including GoldRush pattern matching, LLM integration, enhanced security, and real-time WebSocket subscriptions. This document provides comprehensive API documentation with examples.

## Base URLs

- **Development**: `http://localhost:4000`
- **Production**: `https://api.vsmphoenix.io`

## Authentication

Most endpoints require authentication using JWT tokens:

```bash
Authorization: Bearer YOUR_ACCESS_TOKEN
```

## API Endpoints

### 1. GoldRush Pattern Matching API

The GoldRush pattern matching engine provides powerful event processing capabilities.

#### 1.1 List Patterns
```http
GET /api/goldrush/patterns
```

**Response:**
```json
[
  {
    "id": "pat_123",
    "name": "user_login_pattern",
    "pattern": "event.type == 'user.login' && event.data.success == true",
    "actions": ["log_successful_login", "update_last_login"],
    "created_at": "2024-01-15T10:30:00Z"
  }
]
```

**cURL Example:**
```bash
curl -X GET http://localhost:4000/api/goldrush/patterns
```

#### 1.2 Create Pattern
```http
POST /api/goldrush/patterns
```

**Request Body:**
```json
{
  "name": "high_cpu_alert",
  "pattern": "metric.type == 'cpu' && metric.value > 90",
  "actions": ["send_alert", "scale_up"]
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:4000/api/goldrush/patterns \
  -H "Content-Type: application/json" \
  -d '{
    "name": "high_cpu_alert",
    "pattern": "metric.type == '\''cpu'\'' && metric.value > 90",
    "actions": ["send_alert", "scale_up"]
  }'
```

#### 1.3 Submit Event
```http
POST /api/goldrush/events
```

**Request Body:**
```json
{
  "type": "metric",
  "data": {
    "type": "cpu",
    "value": 95,
    "host": "server-01"
  },
  "metadata": {
    "timestamp": "2024-01-15T10:30:00Z",
    "source": "monitoring-agent"
  }
}
```

**Response:**
```json
{
  "matched_patterns": ["high_cpu_alert"],
  "actions_triggered": ["send_alert", "scale_up"],
  "processing_time_ms": 12
}
```

#### 1.4 Complex Query
```http
POST /api/goldrush/query
```

**Request Body:**
```json
{
  "query": {
    "type": "aggregate",
    "aggregation": "count",
    "filters": {
      "event_type": "user.login",
      "time_range": {
        "start": "2024-01-01T00:00:00Z",
        "end": "2024-01-31T23:59:59Z"
      }
    },
    "group_by": ["country", "device_type"]
  }
}
```

**JavaScript SDK Example:**
```javascript
const goldrush = new GoldRushClient({
  baseURL: 'http://localhost:4000/api/goldrush',
  apiKey: 'your-api-key'
});

// Create a pattern
const pattern = await goldrush.patterns.create({
  name: 'failed_login_threshold',
  pattern: 'event.type == "login.failed" && count() > 5 within 5m',
  actions: ['lock_account', 'notify_security']
});

// Submit events
await goldrush.events.submit({
  type: 'login.failed',
  data: { user_id: 'user123', ip: '192.168.1.1' }
});
```

### 2. LLM Service API

Integration with language models for intelligent system responses.

#### 2.1 Chat with LLM
```http
POST /api/llm/chat
```

**Request Body:**
```json
{
  "message": "Analyze the current system performance and suggest optimizations",
  "model": "gpt-4",
  "temperature": 0.7,
  "max_tokens": 1000,
  "context": [
    {
      "role": "system",
      "content": "You are a VSM system analyst"
    }
  ]
}
```

**Response:**
```json
{
  "response": "Based on the current metrics, I recommend...",
  "model": "gpt-4",
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 350,
    "total_tokens": 500
  }
}
```

**cURL Example:**
```bash
curl -X POST http://localhost:4000/api/llm/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "message": "What are the current bottlenecks in System 3?",
    "model": "gpt-4",
    "temperature": 0.5
  }'
```

#### 2.2 Generate Embeddings
```http
POST /api/llm/embeddings
```

**Request Body:**
```json
{
  "texts": [
    "System performance is degrading",
    "CPU usage is high",
    "Memory consumption is normal"
  ],
  "model": "text-embedding-ada-002"
}
```

**Python SDK Example:**
```python
from vsm_phoenix import LLMClient

client = LLMClient(api_key="your-api-key")

# Chat completion
response = client.chat.create(
    message="Analyze the algedonic signals from the past hour",
    model="gpt-4",
    temperature=0.7
)

# Generate embeddings for similarity search
embeddings = client.embeddings.create(
    texts=["System alert", "Performance warning", "All systems normal"],
    model="text-embedding-ada-002"
)
```

### 3. Security Configuration API

Advanced authentication and authorization management.

#### 3.1 User Login
```http
POST /api/auth/login
```

**Request Body:**
```json
{
  "email": "admin@vsmphoenix.io",
  "password": "secure_password"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600,
  "user": {
    "id": "user_123",
    "email": "admin@vsmphoenix.io",
    "name": "System Admin",
    "roles": ["admin", "operator"]
  }
}
```

#### 3.2 Refresh Token
```http
POST /api/auth/refresh
```

**Headers:**
```
Authorization: Bearer YOUR_REFRESH_TOKEN
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_in": 3600
}
```

#### 3.3 Get Permissions
```http
GET /api/auth/permissions
```

**Response:**
```json
{
  "permissions": [
    "vsm.read",
    "vsm.write",
    "agents.manage",
    "llm.access",
    "goldrush.admin"
  ],
  "roles": ["admin", "operator"],
  "resource_access": {
    "system_1": ["read", "write"],
    "system_2": ["read", "write"],
    "system_3": ["read"],
    "system_4": ["read"],
    "system_5": ["read", "write", "decide"]
  }
}
```

### 4. WebSocket Event Subscriptions

Real-time event streaming and notifications.

#### 4.1 Create Subscription
```http
POST /api/ws/subscribe
```

**Request Body:**
```json
{
  "channels": [
    "vsm.alerts",
    "system.metrics",
    "agent.events",
    "goldrush.matches"
  ],
  "filters": {
    "severity": ["high", "critical"],
    "systems": ["s1", "s3", "s5"]
  }
}
```

**Response:**
```json
{
  "subscription_id": "sub_abc123",
  "ws_url": "ws://localhost:4000/socket/websocket?token=xyz",
  "channels": ["vsm.alerts", "system.metrics", "agent.events", "goldrush.matches"]
}
```

#### 4.2 WebSocket Connection Example

**JavaScript:**
```javascript
class VSMWebSocket {
  constructor(subscriptionId, wsUrl) {
    this.ws = new WebSocket(wsUrl);
    this.subscriptionId = subscriptionId;
    
    this.ws.onopen = () => {
      console.log('Connected to VSM WebSocket');
      this.authenticate();
    };
    
    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.handleMessage(data);
    };
  }
  
  authenticate() {
    this.ws.send(JSON.stringify({
      type: 'authenticate',
      subscription_id: this.subscriptionId
    }));
  }
  
  handleMessage(data) {
    switch(data.type) {
      case 'vsm.alert':
        console.log('VSM Alert:', data.payload);
        break;
      case 'system.metric':
        console.log('System Metric:', data.payload);
        break;
      case 'goldrush.match':
        console.log('Pattern Match:', data.payload);
        break;
    }
  }
  
  subscribe(channel) {
    this.ws.send(JSON.stringify({
      type: 'subscribe',
      channel: channel
    }));
  }
}

// Usage
const createWebSocketConnection = async () => {
  const response = await fetch('/api/ws/subscribe', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + accessToken
    },
    body: JSON.stringify({
      channels: ['vsm.alerts', 'agent.events']
    })
  });
  
  const { subscription_id, ws_url } = await response.json();
  return new VSMWebSocket(subscription_id, ws_url);
};
```

#### 4.3 Event Types

**VSM Alerts:**
```json
{
  "type": "vsm.alert",
  "payload": {
    "id": "alert_123",
    "severity": "high",
    "system": "s3",
    "message": "Audit discrepancy detected",
    "timestamp": "2024-01-15T10:30:00Z",
    "data": {
      "expected": 100,
      "actual": 95,
      "variance": 5
    }
  }
}
```

**System Metrics:**
```json
{
  "type": "system.metric",
  "payload": {
    "system": "s1",
    "metrics": {
      "cpu": 45.2,
      "memory": 78.5,
      "operations_per_second": 1250,
      "queue_depth": 15
    },
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

**GoldRush Pattern Match:**
```json
{
  "type": "goldrush.match",
  "payload": {
    "pattern_id": "pat_123",
    "pattern_name": "high_cpu_alert",
    "event": {
      "type": "metric",
      "data": { "cpu": 92 }
    },
    "actions_triggered": ["send_alert", "scale_up"],
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### 5. VSM Core System API

Core Viable System Model operations.

#### 5.1 System Status
```http
GET /api/vsm/status
```

**Response:**
```json
{
  "status": "healthy",
  "systems": {
    "s1": {
      "status": "operational",
      "agents": 15,
      "load": 0.75
    },
    "s2": {
      "status": "operational",
      "coordination_efficiency": 0.92
    },
    "s3": {
      "status": "operational",
      "audit_status": "in_sync",
      "last_audit": "2024-01-15T10:00:00Z"
    },
    "s4": {
      "status": "operational",
      "intelligence_insights": 42,
      "variety_absorption": 0.88
    },
    "s5": {
      "status": "operational",
      "policy_version": "2.1.0",
      "decisions_today": 156
    }
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### 5.2 Algedonic Signals
```http
POST /api/vsm/algedonic/pain
```

**Request Body:**
```json
{
  "source": "s1_operations",
  "intensity": 0.8,
  "message": "High error rate detected in transaction processing",
  "metadata": {
    "error_rate": 0.15,
    "affected_services": ["payment", "order"],
    "duration_minutes": 5
  }
}
```

**Response:**
```json
{
  "signal_id": "alg_789",
  "type": "pain",
  "intensity": 0.8,
  "propagation": ["s3", "s5"],
  "actions_taken": [
    "Notified S3 for immediate audit",
    "Escalated to S5 for policy review",
    "Triggered automatic scaling"
  ],
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### 6. S1 Agent Management API

Manage System 1 operational agents.

#### 6.1 Create Agent
```http
POST /api/vsm/agents
```

**Request Body:**
```json
{
  "name": "payment_processor",
  "type": "transaction_handler",
  "capabilities": ["process_payment", "validate_card", "fraud_detection"],
  "config": {
    "max_concurrent": 100,
    "timeout_ms": 5000,
    "retry_attempts": 3
  }
}
```

**Response:**
```json
{
  "id": "agent_456",
  "name": "payment_processor",
  "type": "transaction_handler",
  "status": "active",
  "capabilities": ["process_payment", "validate_card", "fraud_detection"],
  "created_at": "2024-01-15T10:30:00Z",
  "endpoint": "tcp://agent-456.vsm.local:5555"
}
```

#### 6.2 Execute Agent Command
```http
POST /api/vsm/agents/{id}/command
```

**Request Body:**
```json
{
  "command": "process_batch",
  "args": ["batch_123", "--priority", "high"],
  "timeout": 30000
}
```

**Response:**
```json
{
  "result": "success",
  "output": {
    "processed": 150,
    "failed": 2,
    "duration_ms": 2845
  },
  "execution_time_ms": 2850
}
```

## Client SDK Examples

### Elixir/Phoenix Client

```elixir
defmodule MyApp.VSMClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl, "http://localhost:4000/api"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.BearerAuth, token: System.get_env("VSM_API_TOKEN")

  def get_system_status do
    get("/vsm/status")
  end

  def create_pattern(pattern) do
    post("/goldrush/patterns", pattern)
  end

  def chat_with_llm(message, opts \\ []) do
    body = %{
      message: message,
      model: Keyword.get(opts, :model, "gpt-4"),
      temperature: Keyword.get(opts, :temperature, 0.7)
    }
    
    post("/llm/chat", body)
  end
  
  def send_algedonic_signal(type, intensity, message) do
    post("/vsm/algedonic/#{type}", %{
      intensity: intensity,
      message: message,
      source: "client_app"
    })
  end
end

# Usage
{:ok, %{body: status}} = MyApp.VSMClient.get_system_status()
{:ok, %{body: response}} = MyApp.VSMClient.chat_with_llm("Analyze system health")
```

### Node.js/TypeScript Client

```typescript
import axios, { AxiosInstance } from 'axios';

interface VSMClientConfig {
  baseURL: string;
  apiKey: string;
}

class VSMClient {
  private client: AxiosInstance;

  constructor(config: VSMClientConfig) {
    this.client = axios.create({
      baseURL: config.baseURL,
      headers: {
        'Authorization': `Bearer ${config.apiKey}`,
        'Content-Type': 'application/json'
      }
    });
  }

  async getSystemStatus() {
    const response = await this.client.get('/vsm/status');
    return response.data;
  }

  async createGoldRushPattern(pattern: {
    name: string;
    pattern: string;
    actions: string[];
  }) {
    const response = await this.client.post('/goldrush/patterns', pattern);
    return response.data;
  }

  async chatWithLLM(message: string, options?: {
    model?: string;
    temperature?: number;
    maxTokens?: number;
  }) {
    const response = await this.client.post('/llm/chat', {
      message,
      model: options?.model || 'gpt-4',
      temperature: options?.temperature || 0.7,
      max_tokens: options?.maxTokens || 1000
    });
    return response.data;
  }

  createWebSocketConnection(channels: string[]): Promise<WebSocket> {
    return new Promise(async (resolve, reject) => {
      try {
        const response = await this.client.post('/ws/subscribe', { channels });
        const { ws_url } = response.data;
        
        const ws = new WebSocket(ws_url);
        ws.onopen = () => resolve(ws);
        ws.onerror = reject;
      } catch (error) {
        reject(error);
      }
    });
  }
}

// Usage
const client = new VSMClient({
  baseURL: 'http://localhost:4000/api',
  apiKey: process.env.VSM_API_KEY!
});

const status = await client.getSystemStatus();
console.log('System Status:', status);

const ws = await client.createWebSocketConnection(['vsm.alerts', 'agent.events']);
ws.onmessage = (event) => {
  console.log('Received:', JSON.parse(event.data));
};
```

### Python Client

```python
import requests
import websocket
import json
from typing import Dict, List, Optional

class VSMClient:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
    
    def get_system_status(self) -> Dict:
        response = requests.get(
            f'{self.base_url}/vsm/status',
            headers=self.headers
        )
        response.raise_for_status()
        return response.json()
    
    def create_pattern(self, name: str, pattern: str, actions: List[str]) -> Dict:
        response = requests.post(
            f'{self.base_url}/goldrush/patterns',
            headers=self.headers,
            json={
                'name': name,
                'pattern': pattern,
                'actions': actions
            }
        )
        response.raise_for_status()
        return response.json()
    
    def chat_with_llm(self, message: str, model: str = 'gpt-4', 
                      temperature: float = 0.7) -> Dict:
        response = requests.post(
            f'{self.base_url}/llm/chat',
            headers=self.headers,
            json={
                'message': message,
                'model': model,
                'temperature': temperature
            }
        )
        response.raise_for_status()
        return response.json()
    
    def subscribe_to_events(self, channels: List[str], 
                           on_message=None) -> websocket.WebSocket:
        # Create subscription
        response = requests.post(
            f'{self.base_url}/ws/subscribe',
            headers=self.headers,
            json={'channels': channels}
        )
        response.raise_for_status()
        
        data = response.json()
        ws_url = data['ws_url']
        subscription_id = data['subscription_id']
        
        # Connect to WebSocket
        ws = websocket.WebSocket()
        ws.connect(ws_url)
        
        # Authenticate
        ws.send(json.dumps({
            'type': 'authenticate',
            'subscription_id': subscription_id
        }))
        
        # Set up message handler
        if on_message:
            def run():
                while True:
                    message = ws.recv()
                    on_message(json.loads(message))
            
            import threading
            thread = threading.Thread(target=run)
            thread.daemon = True
            thread.start()
        
        return ws

# Usage
client = VSMClient('http://localhost:4000/api', 'your-api-key')

# Get system status
status = client.get_system_status()
print(f"System Status: {status['status']}")

# Create a pattern
pattern = client.create_pattern(
    name='error_spike',
    pattern='event.type == "error" && count() > 100 within 1m',
    actions=['alert_ops', 'scale_up']
)

# Chat with LLM
response = client.chat_with_llm(
    "What optimizations can improve System 2 coordination?"
)
print(f"LLM Response: {response['response']}")

# Subscribe to events
def handle_event(event):
    print(f"Received event: {event['type']} - {event['payload']}")

ws = client.subscribe_to_events(
    channels=['vsm.alerts', 'goldrush.matches'],
    on_message=handle_event
)
```

## Rate Limiting

- **Default Rate Limit**: 1000 requests per hour per API key
- **Burst Limit**: 100 requests per minute
- **WebSocket Connections**: Maximum 10 concurrent connections per API key

Rate limit headers:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 950
X-RateLimit-Reset: 1705318800
```

## Error Responses

All errors follow a consistent format:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Pattern with ID 'pat_xyz' not found",
    "details": {
      "resource_type": "pattern",
      "resource_id": "pat_xyz"
    }
  },
  "request_id": "req_abc123"
}
```

Common error codes:
- `AUTHENTICATION_REQUIRED` - Missing or invalid authentication
- `PERMISSION_DENIED` - Insufficient permissions
- `RESOURCE_NOT_FOUND` - Requested resource doesn't exist
- `VALIDATION_ERROR` - Invalid request parameters
- `RATE_LIMIT_EXCEEDED` - Too many requests
- `INTERNAL_ERROR` - Server error

## Webhooks

Configure webhooks to receive notifications:

```json
POST /api/webhooks
{
  "url": "https://your-app.com/webhooks/vsm",
  "events": ["pattern.matched", "system.alert", "agent.status_change"],
  "secret": "your-webhook-secret"
}
```

Webhook payload:
```json
{
  "id": "evt_123",
  "type": "pattern.matched",
  "data": {
    "pattern_id": "pat_456",
    "pattern_name": "high_cpu_alert",
    "matched_event": {...}
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "signature": "sha256=..."
}
```

## Best Practices

1. **Use pagination** for list endpoints:
   ```
   GET /api/goldrush/patterns?page=2&per_page=50
   ```

2. **Include idempotency keys** for critical operations:
   ```
   Idempotency-Key: unique-request-id
   ```

3. **Monitor rate limits** and implement exponential backoff

4. **Use WebSockets** for real-time updates instead of polling

5. **Cache responses** where appropriate

6. **Validate webhook signatures** for security

## Support

- **Documentation**: https://docs.vsmphoenix.io
- **API Status**: https://status.vsmphoenix.io
- **Support Email**: support@vsmphoenix.io
- **Community Forum**: https://forum.vsmphoenix.io

## Changelog

### Version 2.0.0 (Phase 2)
- Added GoldRush pattern matching engine
- Integrated LLM services
- Enhanced security with JWT authentication
- Added WebSocket subscriptions
- Improved agent management
- Added comprehensive monitoring

### Version 1.0.0 (Phase 1)
- Initial VSM core implementation
- Basic agent management
- Algedonic signal processing
- System status monitoring