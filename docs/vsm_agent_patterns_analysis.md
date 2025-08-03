# VSM Agent Patterns Analysis

## Overview

The VSM Phoenix application implements a Viable System Model (VSM) using Elixir/Phoenix with a sophisticated agent-based architecture. Agents operate within System 1 (S1) as the operational units, coordinated by higher-level systems (S2-S5).

## Common Agent Patterns

### 1. GenServer Foundation

All agents are built on Elixir's GenServer behavior, providing:
- Process-based isolation
- Message-passing communication
- Fault tolerance through supervision
- State management

```elixir
use GenServer
def start_link(opts) do
  agent_id = Keyword.fetch!(opts, :id)
  GenServer.start_link(__MODULE__, opts, name: {:global, agent_id})
end
```

### 2. Global Registration Pattern

Agents register globally using `{:global, agent_id}` naming:
- Enables cluster-wide agent discovery
- Supports distributed deployments
- Allows cross-node communication

### 3. S1 Registry Integration

All agents register with the System 1 Registry on initialization:
```elixir
:ok = Registry.register(agent_id, self(), %{
  type: :worker,
  config: config,
  capabilities: get_capabilities(config),
  started_at: DateTime.utc_now()
})
```

This provides:
- Centralized agent discovery
- Metadata storage
- Lifecycle management

### 4. AMQP Message Bus Integration

Every agent type connects to RabbitMQ for asynchronous messaging:

```elixir
{:ok, channel} = ConnectionManager.get_channel(:channel_type)
:ok = AMQP.Exchange.declare(channel, exchange_name, :topic, durable: true)
{:ok, _queue} = AMQP.Queue.declare(channel, queue_name, durable: true)
{:ok, _consumer_tag} = AMQP.Basic.consume(channel, queue_name)
```

Key AMQP patterns:
- Topic exchanges for flexible routing
- Durable queues for reliability
- Consumer acknowledgments for at-least-once delivery
- Routing key conventions: `vsm.s1.<agent_id>.<message_type>`

### 5. Message Handling Pattern

Agents handle both synchronous (GenServer calls) and asynchronous (AMQP) messages:

```elixir
# AMQP message handling
def handle_info({:basic_deliver, payload, meta}, state) do
  case Jason.decode(payload) do
    {:ok, command} ->
      new_state = process_command(command, meta, state)
      AMQP.Basic.ack(state.channel, meta.delivery_tag)
      {:noreply, new_state}
    {:error, reason} ->
      AMQP.Basic.reject(state.channel, meta.delivery_tag, requeue: false)
      {:noreply, state}
  end
end

# Direct GenServer calls
def handle_call({:execute_command, command}, from, state) do
  result = execute_work(command, state)
  {:reply, result, state}
end
```

### 6. Metrics and Monitoring

All agents maintain internal metrics:
```elixir
metrics: %{
  commands_processed: 0,
  commands_failed: 0,
  total_processing_time: 0,
  last_command_at: nil
}
```

## Agent Types

### 1. Worker Agent (`worker_agent.ex`)
- **Purpose**: Core processing units for executing commands
- **AMQP Queues**: 
  - Consumes: `vsm.s1.<id>.command`
  - Publishes: `vsm.s1.<id>.results`
- **Capabilities**: `:process_data`, `:transform`, `:analyze`
- **Special Features**: Can detect LLM capabilities but delegates to LLMWorkerAgent

### 2. Sensor Agent (`sensor_agent.ex`)
- **Purpose**: Periodic telemetry emission
- **AMQP Exchange**: `vsm.s1.<id>.telemetry`
- **Emission Interval**: 5 seconds
- **Data Types**: temperature, pressure, performance, generic
- **Pattern**: Timer-based autonomous operation

### 3. API Agent (`api_agent.ex`)
- **Purpose**: External interface for HTTP/WebSocket endpoints
- **AMQP Exchanges**:
  - Events: `vsm.s1.<id>.api.events`
  - Responses: `vsm.s1.<id>.api.responses`
- **Features**:
  - Rate limiting per client
  - Endpoint registration
  - WebSocket support via Phoenix.PubSub
  - Request/response correlation

### 4. LLM Worker Agent (`llm_worker_agent.ex`)
- **Purpose**: MCP (Model Context Protocol) client with AI capabilities
- **Extends**: WorkerAgent functionality
- **Special Features**:
  - Dynamic MCP server connections
  - Tool discovery and execution
  - Recursive agent spawning
  - Swarm task orchestration
  - Deep hierarchy creation

## VSM Hierarchy Integration

### System 1 (Operations)
- Houses all agent types
- Managed by `System1.Supervisor`
- Provides:
  - `spawn_agent/2` - Create new agents
  - `terminate_agent/1` - Graceful shutdown
  - `list_agents/0` - Discovery
  - `get_agent_metrics/1` - Monitoring

### System 2 (Coordinator)
- Anti-oscillation and coordination
- PubSub-based message routing
- Synchronization services
- AMQP coordination queue: `vsm.system2.coordination`

### System 3 (Control)
- Resource allocation and optimization
- Performance monitoring
- Conflict resolution
- Direct audit capabilities (bypassing S2)

### System 4 (Intelligence)
- Environmental scanning
- Future planning
- Learning and adaptation

### System 5 (Queen)
- Policy and identity
- Overall system governance
- Meta-VSM spawning capabilities

## Communication Patterns

### 1. Intra-Agent Communication
- Direct GenServer calls for synchronous operations
- Global process registration for discovery

### 2. Inter-Agent Communication
- AMQP topic exchanges for asynchronous messaging
- Phoenix.PubSub for local broadcasts
- Routing key hierarchy: `vsm.s1.<agent_id>.<message_type>`

### 3. Cross-System Communication
- S1→S2: Via PubSub topics `vsm:coordination`, `vsm:system1`
- S2→S1: Coordinated messages via `vsm:context:<id>`
- S3→S1: Direct audit access or through S2 coordination

## Advanced Patterns

### 1. Recursive Agent Spawning (LLMWorkerAgent)
- Agents can spawn child agents
- Hierarchical organization with parent-child relationships
- Configuration inheritance
- Deep hierarchy creation up to N levels

### 2. Swarm Task Orchestration
- Multi-step workflows
- Context passing between steps
- Variable interpolation (`{{key}}` syntax)
- Sequential execution with result chaining

### 3. MCP Integration
- Dynamic capability acquisition
- Tool discovery and execution
- Multiple MCP server connections per agent
- Specialist agent creation with specific MCP servers

### 4. Meta-VSM Spawning
- S1 Operations can spawn entire VSM subsystems
- Recursive system architecture
- Policy inheritance from parent VSM
- Domain specialization

## Best Practices Observed

1. **Graceful Termination**: All agents properly close AMQP channels and unregister
2. **Error Handling**: Malformed messages are rejected without requeue
3. **Metrics Collection**: Comprehensive tracking for observability
4. **Configuration Flexibility**: Runtime config updates supported
5. **Idempotent Operations**: AMQP message acknowledgment patterns
6. **Resource Cleanup**: Proper cleanup in `terminate/2` callbacks

## Integration Points

1. **AMQP Connection Manager**: Centralized channel management
2. **S1 Registry**: Agent lifecycle and discovery
3. **Phoenix.PubSub**: Local event distribution
4. **MCP Client**: External tool integration (LLMWorkerAgent)
5. **System Supervisors**: Fault tolerance and restart strategies

## Conclusion

The VSM agent architecture demonstrates sophisticated patterns for building distributed, fault-tolerant systems. The combination of Elixir's actor model, AMQP messaging, and VSM hierarchical organization creates a robust framework for complex system management. The recent addition of MCP integration through LLMWorkerAgent shows the system's extensibility for AI-enhanced operations.