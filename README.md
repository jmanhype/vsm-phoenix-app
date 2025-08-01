# VSM Phoenix - Viable Systems Model Implementation

A complete Phoenix application implementing the Viable Systems Model (VSM) with real-time monitoring and coordination.

## Architecture Overview

This application implements the full VSM hierarchy with Phoenix LiveView for real-time monitoring:

### System 5 - Queen (Policy & Identity)
- **File**: `lib/vsm_phoenix/system5/queen.ex`
- **Purpose**: Policy governance, strategic direction, and identity preservation
- **Features**: 
  - Policy management across all systems
  - Viability assessment and intervention triggers
  - Strategic alignment monitoring

### System 4 - Intelligence (Environment & Adaptation)
- **File**: `lib/vsm_phoenix/system4/intelligence.ex`
- **Purpose**: Environmental scanning, trend analysis, and adaptation proposals
- **Features**:
  - Tidewave market intelligence integration
  - Adaptation model selection and execution
  - Future prediction and modeling

### System 3 - Control (Resource Management)
- **File**: `lib/vsm_phoenix/system3/control.ex`
- **Purpose**: Resource allocation, optimization, and conflict resolution
- **Features**:
  - Dynamic resource allocation
  - Performance optimization
  - Conflict resolution between System 1 units

### System 2 - Coordinator (Anti-Oscillation)
- **File**: `lib/vsm_phoenix/system2/coordinator.ex`
- **Purpose**: PubSub coordination, oscillation dampening, synchronization
- **Features**:
  - Message flow coordination
  - Oscillation detection and dampening
  - Cross-system synchronization

### System 1 - Operations (Operational Contexts)
- **Files**: `lib/vsm_phoenix/system1/context.ex`, `lib/vsm_phoenix/system1/operations.ex`
- **Purpose**: Autonomous operational units for business functions
- **Features**:
  - Base context framework for operational units
  - Example operations context with order processing
  - Resource management and coordination

## Dashboard & Monitoring

### LiveView Dashboard
- **File**: `lib/vsm_phoenix_web/live/vsm_dashboard_live.ex`
- **Purpose**: Real-time system monitoring and control
- **Features**:
  - Real-time viability score tracking
  - System health visualization
  - Resource utilization monitoring
  - Alert management
  - Interactive system controls

## Support Systems

- **Performance Monitor**: System performance tracking and analysis
- **Health Checker**: Continuous system health assessment
- **Telemetry Collector**: Event and metrics collection
- **Tidewave Integration**: Market intelligence integration
- **Config Manager**: Dynamic configuration management

## Getting Started

1. **Install Dependencies**:
   ```bash
   cd /home/batmanosama/viable-systems/vsm_phoenix_app
   mix deps.get
   ```

2. **Setup Database**:
   ```bash
   mix ecto.setup
   ```

3. **Start Phoenix Server**:
   ```bash
   mix phx.server
   ```

4. **Visit Dashboard**:
   - Navigate to `http://localhost:4000`
   - View real-time VSM system monitoring

## Configuration

### Environment Variables (Production)
- `TIDEWAVE_ENABLED`: Enable/disable Tidewave integration
- `TIDEWAVE_API_KEY`: Tidewave API key
- `VSM_VIABILITY_THRESHOLD`: System viability threshold
- `VSM_LEARNING_RATE`: System 4 learning rate

### Development Configuration
- Faster update intervals for testing
- Debug mode enabled
- Mock external services

## Key Features

### Real-Time Coordination
- PubSub-based message coordination
- Anti-oscillation mechanisms
- Cross-system synchronization

### Adaptive Intelligence
- Environmental scanning
- Trend analysis
- Automatic adaptation proposals

### Resource Optimization
- Dynamic resource allocation
- Performance monitoring
- Bottleneck identification

### Policy Governance
- Strategic direction setting
- Identity preservation
- Intervention triggers

### Operational Autonomy
- Self-managing operational contexts
- Health monitoring
- Automatic resource requests

## API Endpoints

The application provides REST API endpoints for each system:

- `/api/queen/*` - System 5 policy and viability
- `/api/intelligence/*` - System 4 scanning and adaptation
- `/api/control/*` - System 3 resource management
- `/api/coordinator/*` - System 2 coordination
- `/api/operations/*` - System 1 operational metrics

## Coordination Hooks

The application uses Claude Flow coordination hooks throughout:

- Pre-task coordination setup
- Post-edit memory storage
- Cross-system decision sharing
- Performance tracking

## Testing

Run the complete test suite:
```bash
mix test
```

## Deployment

The application is configured for production deployment with:
- Environment-based configuration
- SSL support
- Performance optimization
- Monitoring integration

## VSM Compliance

This implementation follows Beer's VSM principles:
- Recursive structure with autonomous subsystems
- Homeostatic loops for stability
- Anti-oscillation mechanisms
- Environmental adaptation
- Policy-based governance

Each system maintains its autonomy while contributing to overall system viability through coordinated interaction patterns.

## Roadmap

### Current State
The VSM Phoenix application has implemented the basic five-system VSM structure with AMQP message passing, real-time dashboard monitoring, and algedonic signal processing. All systems communicate via RabbitMQ/AMQP exchanges, providing a foundation for distributed cybernetic control.

### Phase 1: Complete VSM Foundation (1-2 weeks)
**Goal**: Build a proper cybernetic foundation with multiple autonomous operational units

- [ ] **Multiple System 1 Units with Plugin Architecture**
  - Dynamic agent registry for spawning operational units
  - Example agents: SensorAgent, WorkerAgent, APIAgent
  - Each agent with own AMQP channel and local state
  - Plugin system for easy extension

- [ ] **Bidirectional AMQP Communication**
  - Command flows from higher to lower systems (S5→S4→S3→S2→S1)
  - Not just data flowing upward
  - Proper control loops with feedback

- [ ] **System 3* (Three Star) Audit Function**
  - Direct inspection channel to S1 units
  - Bypasses S2 coordination layer
  - Sporadic audit capability per Beer's VSM

- [ ] **Variety Engineering**
  - Implement variety attenuation between levels
  - Each level filters/amplifies information appropriately
  - Proper handling of Ashby's Law of Requisite Variety

### Phase 2: Intelligence & Event Processing (2-3 weeks)
**Goal**: Add pattern recognition, event processing, and basic AI capabilities

- [ ] **GoldRush Event Pattern Matching**
  - Declarative event conditions (e.g., "when cpu > 80% AND memory > 90%")
  - Real-time pattern matching on event streams
  - Event aggregation and fusion
  - Hierarchical event managers

- [ ] **LLM Integration for System 4**
  - Environmental scanning and interpretation
  - Anomaly explanation in natural language
  - Future scenario planning and modeling
  - Integration with OpenAI/Anthropic APIs

- [ ] **aMCP Protocol Extensions**
  - Semantic context preservation across messages
  - Event causality chain tracking
  - Priority-based message routing
  - Persistent context using CRDTs

- [ ] **Security Layer**
  - Cryptographic nonce validation
  - Replay attack protection
  - Message-level signing
  - Bloom filters for efficient validation

### Phase 3: Meta-Cognitive Evolution (3-4 weeks)
**Goal**: Create self-aware, self-modifying system with emergent behaviors

- [ ] **Meta-Cognitive Observation Layer**
  - System observes its own decision-making processes
  - Tracks conflicts between subsystems
  - Counts patterns and generates metrics about itself
  - Real-time introspection capabilities

- [ ] **Dynamic Policy Generation**
  - LLM analyzes event patterns to suggest new policies
  - Policies compiled to active AMQP handlers
  - System can modify its own behavioral rules
  - Meta-policies (policies about making policies)

- [ ] **Emergent Subsystem Creation**
  - Automatic spawning of new S1 agents based on patterns
  - Agents can create sub-agents (recursive structure)
  - Self-organizing system topology
  - Dynamic resource allocation

- [ ] **Self-Documentation & SOPs**
  - Auto-generation of Standard Operating Procedures
  - System documents its own discoveries
  - Human-readable explanations of decisions
  - Continuous improvement loops

### Phase 4: Advanced Features (Future)
**Goal**: Production-ready distributed cognitive system

- [ ] **WASM Plugin Compilation**
  - Secure sandboxed execution
  - Browser-deployable agents
  - Cross-platform compatibility

- [ ] **Visual Canvas Interface**
  - Drag-and-drop agent composition
  - Visual workflow design
  - Real-time system visualization

- [ ] **Distributed Features**
  - Zone-aware routing
  - Zombie node detection
  - Self-healing capabilities
  - Multi-region deployment

- [ ] **Agent Marketplace**
  - Registry for sharing agents
  - Trust scoring system
  - One-click deployment
  - Community contributions

### Technical Approach
The implementation follows the Cybernetic.ai whitepaper's vision while maintaining compatibility with Beer's original VSM principles. We're building on Erlang/Elixir's fault-tolerant distributed systems capabilities, AMQP for reliable messaging, and modern AI/LLM integration for intelligence layers.

Each phase delivers working functionality while building toward a truly autonomous, self-improving system - a meta-cognitive orchestrator that can observe, analyze, and modify its own thinking patterns.