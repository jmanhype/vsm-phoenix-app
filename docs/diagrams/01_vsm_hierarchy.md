# VSM System Hierarchy Architecture

## Overview
This diagram shows the complete 5-level Viable Systems Model hierarchy as implemented in VSM Phoenix. Components shown represent what exists in the code, including recursive spawning capabilities and algedonic pathways.

```mermaid
graph TB
    subgraph "VSM Phoenix Application"
        S5[System 5 - Queen<br/>Policy & Identity]
        S4[System 4 - Intelligence<br/>Environment & Adaptation]
        S3[System 3 - Control<br/>Resource Management]
        S2[System 2 - Coordinator<br/>Anti-Oscillation]
        S1[System 1 - Operations<br/>Agents & Execution]
    end

    subgraph "System 5 Implementation"
        Queen[Queen GenServer<br/>lib/vsm_phoenix/system5/queen.ex]
        PolicySynth[PolicySynthesizer Module<br/>lib/vsm_phoenix/system5/policy_synthesizer.ex]
        AlgedProc[Algedonic Processing<br/>(within Queen module)]
        ViabilityCalc[Viability Calculation<br/>(within Queen module)]
    end

    subgraph "System 4 Implementation"
        Intelligence[Intelligence GenServer<br/>lib/vsm_phoenix/system4/intelligence.ex]
        EnvScan[Environmental Scanning<br/>(within Intelligence)]
        LLMVariety[LLMVarietySource Module<br/>lib/vsm_phoenix/system4/llm_variety_source.ex]
        TidewaveStub[Tidewave Integration<br/>(returns mock data)]
        AnomalyDet[Anomaly Detection<br/>(within Intelligence)]
    end

    subgraph "System 3 Implementation"
        Control[Control GenServer<br/>lib/vsm_phoenix/system3/control.ex]
        ResourceMgmt[Resource Management<br/>(within Control)]
        PerfOpt[Performance Optimization<br/>(within Control)]
        AuditChannel[AuditChannel Module<br/>lib/vsm_phoenix/system3/audit_channel.ex]
        S3Audit[S3* Audit Bypass<br/>(functional)]
    end

    subgraph "System 2 Implementation"
        Coordinator[Coordinator GenServer<br/>lib/vsm_phoenix/system2/coordinator.ex]
        InfoFlow[Information Flow<br/>(within Coordinator)]
        AntiOsc[Anti-Oscillation<br/>(within Coordinator)]
    end

    subgraph "System 1 Implementation"
        S1Super[DynamicSupervisor<br/>lib/vsm_phoenix/system1/supervisor.ex]
        AgentReg[Agent Registry<br/>lib/vsm_phoenix/system1/registry.ex]
        WorkerAgent[Worker Agent<br/>lib/vsm_phoenix/system1/agents/worker_agent.ex]
        LLMAgent[LLM Worker Agent<br/>lib/vsm_phoenix/system1/agents/llm_worker_agent.ex]
        SensorAgent[Sensor Agent<br/>lib/vsm_phoenix/system1/agents/sensor_agent.ex]
        APIAgent[API Agent<br/>lib/vsm_phoenix/system1/agents/api_agent.ex]
    end

    %% Main Hierarchy
    S5 --> S4
    S4 --> S3
    S3 --> S2
    S2 --> S1

    %% System 5 Internal
    S5 --> Queen
    Queen --> PolicySynth
    Queen --> AlgedProc
    Queen --> ViabilityCalc

    %% System 4 Internal
    S4 --> Intelligence
    Intelligence --> EnvScan
    Intelligence --> LLMVariety
    Intelligence --> TidewaveStub
    Intelligence --> AnomalyDet

    %% System 3 Internal
    S3 --> Control
    Control --> ResourceMgmt
    Control --> PerfOpt
    Control --> AuditChannel
    AuditChannel --> S3Audit

    %% System 2 Internal
    S2 --> Coordinator
    Coordinator --> InfoFlow
    Coordinator --> AntiOsc

    %% System 1 Internal
    S1 --> S1Super
    S1Super --> AgentReg
    S1Super --> WorkerAgent
    S1Super --> LLMAgent
    S1Super --> SensorAgent
    S1Super --> APIAgent

    %% Algedonic Signals (Direct Path)
    S1 -.->|Pain/Pleasure Signals| S5
    S3 -.->|Critical Signals| S5

    %% S3* Audit Bypass
    S3Audit -.->|Direct Inspection| S1
    
    %% External Integrations
    subgraph "External Systems & Services"
        AMQP[RabbitMQ/AMQP<br/>(Messaging Infrastructure)]
        Phoenix[Phoenix.PubSub<br/>(Internal Messaging)]
        Claude[Claude/Anthropic API<br/>(LLM Services)]
        Hermes[Hermes MCP Client<br/>(Enhanced LLM)]
        MCPServers[MCP Servers<br/>(filesystem, web-search, etc.)]
    end

    %% External Connections
    Queen --> Claude
    LLMVariety --> Hermes
    LLMAgent --> MCPServers
    Control --> AMQP
    Coordinator --> Phoenix

    %% Recursive Spawning Capability
    Intelligence -.->|Variety Explosion| S1Super
    S1Super -.->|Spawn Meta-VSM| S5

    classDef implemented fill:#90EE90,stroke:#333,stroke-width:2px
    classDef partial fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef external fill:#E6E6FA,stroke:#333,stroke-width:2px
    classDef bypass fill:#FFA07A,stroke:#333,stroke-width:3px,stroke-dasharray: 5 5

    class Queen,Intelligence,Control,Coordinator,S1Super,AgentReg,WorkerAgent,LLMAgent,SensorAgent,APIAgent,PolicySynth,LLMVariety,AuditChannel implemented
    class AlgedProc,ViabilityCalc,EnvScan,AnomalyDet,ResourceMgmt,PerfOpt,InfoFlow,AntiOsc,TidewaveStub partial
    class AMQP,Phoenix,Claude,Hermes,MCPServers external
    class S3Audit bypass
```

## Key Implementation Details

### System 5 - Queen (Policy & Identity)
**File**: `lib/vsm_phoenix/system5/queen.ex`

**Implementation**:
- **Queen GenServer**: Core policy and governance system
- **Policy Synthesizer**: Separate module with real LLM integration (Claude/Anthropic)
- **Algedonic Processing**: Handled within Queen module (`process_algedonic_signal/2`)
- **Viability Calculation**: Basic implementation in Queen (`calculate_system_viability/1`)
- **Identity Preservation**: Through policy enforcement

**Key Functions**:
- `synthesize_policy_from_anomaly/1` - LLM-powered policy generation
- `process_algedonic_signal/2` - Pain/pleasure signal processing
- `approve_adaptation/1` - Adaptation approval logic
- `apply_synthesized_policy/2` - Policy implementation

### System 4 - Intelligence (Environment & Adaptation)
**File**: `lib/vsm_phoenix/system4/intelligence.ex`

**Implementation**:
- **Intelligence GenServer**: Environmental monitoring and adaptation
- **Environmental Scanning**: Basic implementation within module (60s fixed interval)
- **LLM Variety Source**: Separate module using Hermes MCP for variety analysis
- **Tidewave Integration**: Exists but returns mock data
- **Anomaly Detection**: Basic implementation in `detect_anomalies/1`

**Key Functions**:
- `scan_environment/1` - Environmental scanning (returns simulated data)
- `generate_adaptation_proposal/1` - Creates adaptation proposals
- `analyze_variety_patterns/3` - LLM-based variety analysis

### System 3 - Control (Resource Management)
**File**: `lib/vsm_phoenix/system3/control.ex`

**Implementation**:
- **Control GenServer**: Resource allocation and optimization
- **Resource Management**: Basic allocation within Control module
- **Performance Optimization**: Simple optimization logic
- **Audit Channel**: Fully functional separate module for S3* bypass
- **S3* Audit Bypass**: Direct S1 inspection without S2 coordination

**Key Functions**:
- `allocate_resources/1` - Resource allocation
- `optimize_performance/1` - Performance optimization
- `audit/2` - S3* audit bypass functionality
- `reallocate_for_emergency/1` - Emergency resource reallocation

### System 2 - Coordinator (Anti-Oscillation)
**File**: `lib/vsm_phoenix/system2/coordinator.ex`

**Implementation**:
- **Coordinator GenServer**: Message coordination and anti-oscillation
- **Information Flow**: Managed through PubSub within Coordinator
- **Anti-Oscillation**: Basic dampening logic in `dampen_oscillations/1`
- **Phoenix.PubSub**: Used for internal message coordination

**Key Functions**:
- `coordinate_message/3` - Inter-context messaging
- `dampen_oscillations/1` - Oscillation detection and dampening
- `synchronize_operations/1` - S1 context synchronization

### System 1 - Operations (Operational Contexts)
**Files**: `lib/vsm_phoenix/system1/operations.ex`, `lib/vsm_phoenix/system1/agents/*.ex`

**Implementation**:
- **DynamicSupervisor**: Manages agent lifecycle
- **Agent Registry**: ETS-based registry with PubSub events
- **Worker Agent**: Basic task processing agent
- **LLM Worker Agent**: MCP-enabled agent with tool execution
- **Sensor Agent**: Data collection and monitoring
- **API Agent**: External API integration

**Agent Capabilities**:
- Worker: Basic data processing, analysis
- LLM Worker: MCP tool execution, AI reasoning
- Sensor: Environmental data collection
- API: External system integration

## MCP Integration

### MCP Client Architecture
- **MCP Client**: `lib/vsm_phoenix/mcp/client.ex` - Connects to any MCP server
- **StdioTransport**: `lib/vsm_phoenix/mcp/stdio_transport.ex` - Process communication
- **Protocol Handler**: `lib/vsm_phoenix/mcp/protocol.ex` - MCP protocol implementation
- **Discovery Engine**: `lib/vsm_phoenix/mcp/discovery_engine.ex` - Server discovery

### Available MCP Servers
- Filesystem operations
- Web search capabilities
- GitHub integration
- Memory operations
- SQLite database access

## AMQP Messaging Implementation

### Exchanges (Actual Types)
- `vsm.commands` - direct exchange for command routing
- `vsm.algedonic` - fanout exchange for pain/pleasure signals
- `vsm.coordination` - **fanout** exchange (not topic as designed)
- `vsm.control` - **fanout** exchange (not direct as designed)
- `vsm.intelligence` - fanout exchange for intelligence events
- `vsm.policy` - fanout exchange for policy updates
- `vsm.recursive` - topic exchange for recursive spawning
- `vsm.audit` - fanout exchange for audit events

### Message Flow
- Commands use direct routing to specific system queues
- Events use fanout for broadcast to all interested systems
- Limited use of topic routing (only recursive exchange)

## Recursive VSM Spawning

The system supports recursive meta-VSM spawning when variety exceeds system capacity:
1. System 4 detects variety explosion via LLM analysis
2. Triggers meta-system spawning via System 1
3. New VSM instance created with own S3-4-5 hierarchy
4. Maintains connection to parent VSM via AMQP

## Implementation Status

### Fully Implemented ✅
- Core VSM hierarchy and GenServers
- Policy synthesis with LLM integration
- S3* audit bypass functionality
- AMQP messaging infrastructure
- MCP client and agent integration
- Agent registry and lifecycle management
- Basic environmental scanning
- Command RPC system

### Partially Implemented 🟨
- Algedonic signal processing (basic)
- Viability calculations (simplified)
- Environmental scanning (mock data)
- Performance optimization (basic logic)
- Anti-oscillation (simple dampening)
- Tidewave integration (stub only)

### Key Simplifications
1. Many components shown as separate in original design are implemented within their parent modules
2. Several integrations (Tidewave, some environmental data) return simulated data
3. Health monitoring, performance optimization, and environmental scanning are simplified
4. Strong LLM integration for policy synthesis and variety analysis
5. The cybernetic principles are maintained even with simplified implementations