# VSM Phoenix Architecture Diagrams

This directory contains comprehensive architectural diagrams for the VSM Phoenix application, documenting all major systems, processes, and integrations.

## Phase 1 Diagrams (Critical - Completed)

### [01. VSM System Hierarchy](./01_vsm_hierarchy.md)
**Overview**: Complete 5-level Viable Systems Model hierarchy with recursive spawning capabilities and algedonic pathways.

**Key Features**:
- System 5 (Queen) → System 4 (Intelligence) → System 3 (Control) → System 2 (Coordinator) → System 1 (Operations)
- Algedonic pain/pleasure signal flows
- Policy synthesis and distribution
- S3* audit bypass mechanisms
- Recursive meta-system spawning triggers

### [02. AMQP Exchange Topology](./02_amqp_topology.md)
**Overview**: Complete AMQP messaging infrastructure with 6 exchanges, queue topology, and bidirectional RPC patterns.

**Key Features**:
- 6 exchanges: commands, algedonic, coordination, control, intelligence, policy
- Direct, fanout, and topic exchange patterns
- RPC implementation with direct-reply-to
- Queue durability and consumer configuration

### [03. Policy Synthesis Workflow](./03_policy_synthesis.md)
**Overview**: Autonomous policy synthesis system where System 5 automatically generates policies from anomaly data using LLM analysis.

**Key Features**:
- Anomaly aggregation and pattern detection
- LLM-powered policy generation
- Auto-approval vs manual review workflows
- Policy distribution via AMQP fanout
- Effectiveness tracking and feedback loops

### [04. LiveView Dashboard Architecture](./04_liveview_dashboard.md)
**Overview**: Real-time Phoenix LiveView dashboard with 7 PubSub channels, algedonic signal processing, and comprehensive monitoring.

**Key Features**:
- Real-time system metrics across all 5 VSM levels
- Algedonic pulse visualization and history
- Agent status grid with live updates
- Performance charts and resource monitoring
- Interactive control panels and alerts

## Phase 2 Diagrams (High Value - Completed)

### [05. RPC Command Flow Architecture](./05_rpc_command_flow.md)
**Overview**: Hierarchical command routing and execution patterns across VSM systems using AMQP RPC with direct-reply-to.

**Key Features**:
- System 5 → System 4 → System 3 → System 1 command cascades
- AMQP RPC patterns with correlation IDs and timeouts
- Emergency command handling and recovery
- Performance characteristics and throughput metrics

### [06. Agent Lifecycle Architecture](./06_agent_lifecycle.md)  
**Overview**: Complete agent management lifecycle from spawn to termination for all 4 agent types with automatic MCP integration.

**Key Features**:
- Worker, LLM Worker, Sensor, and API agent types
- Health monitoring and automatic restart mechanisms
- MCP server auto-connection and tool discovery
- State management and graceful shutdown procedures

### [07. MCP Integration Architecture](./07_mcp_integration.md)
**Overview**: Comprehensive Model Context Protocol integration with 35+ tools, dynamic server discovery, and VSMCP recursive protocol.

**Key Features**:
- Dynamic MCP server discovery via NPM, GitHub, and MAGG
- 35+ available tools across filesystem, web, communication domains
- VSMCP protocol for VSM-to-VSM communication
- Connection pooling and error handling strategies

### [08. S3 Audit Bypass Architecture](./08_s3_audit_bypass.md)
**Overview**: System 3* audit bypass mechanism for direct inspection of System 1 agents without System 2 coordination.

**Key Features**:
- Direct agent state inspection bypassing coordination
- Resource usage analysis and performance optimization
- Comprehensive audit reporting with recommendations
- Integration with dashboard and policy synthesis

## Phase 3 Diagrams (Operational - Completed)

### [09. Adaptation Proposal Lifecycle](./09_adaptation_proposal_lifecycle.md)
**Overview**: Complete adaptation workflow from System 4's environmental detection through System 5's policy synthesis and implementation.

**Key Features**:
- Environmental trigger detection and variety explosion analysis
- System 4 to System 5 adaptation proposal workflow
- Policy synthesis and implementation cascade
- Feedback loops and adaptation outcome tracking

### [10. Environmental Scanning Process](./10_environmental_scanning.md)
**Overview**: Comprehensive environmental scanning with intelligence gathering, LLM variety amplification, and multi-dimensional anomaly detection.

**Key Features**:
- Multi-source intelligence gathering (Tidewave, LLM, direct sensors)
- Adaptive scanning frequency based on variety levels
- Real-time anomaly detection and escalation
- Continuous learning and baseline adjustment

### [11. Performance Monitoring Flow](./11_performance_monitoring.md)
**Overview**: Real-time telemetry collection, metrics aggregation, health monitoring, and viability assessment across all VSM systems.

**Key Features**:
- 5-second telemetry collection from all agents
- Comprehensive health assessment and viability scoring
- Alert management with automatic escalation
- Real-time dashboard integration and visualization

### [12. API Integration Flows](./12_api_integration.md)
**Overview**: Multi-protocol API architecture including REST endpoints, JSON-RPC MCP protocols, WebSocket real-time updates, and external system webhooks.

**Key Features**:
- RESTful VSM system management APIs
- MCP JSON-RPC protocol implementation
- Real-time WebSocket dashboard updates
- External webhook integration and routing

## Additional Specialized Diagrams (40+ Total Available)

Based on comprehensive codebase analysis, the following additional diagram categories are available:

### Network & Messaging (4 diagrams)
- Message queue structure and consumer patterns
- Algedonic signal propagation flows
- Subscription/publication patterns

### Database & Data Flow (2 diagrams)
- State management and persistence patterns
- Configuration data flows

### Process & Workflow (5 diagrams)
- Resource allocation workflows
- Agent spawning processes
- Decision trees and business logic

### UI & User Experience (3 diagrams)
- Dashboard data flows
- User interaction patterns
- Component hierarchies

### Security & Audit (3 diagrams)
- Authentication and authorization flows
- Audit trail data flows
- Security boundaries

### Performance & Monitoring (4 diagrams)
- Telemetry collection architecture
- System health dependency maps
- Bottleneck analysis flows

## Diagram Standards

### Tools Used
- **Mermaid**: Primary diagramming tool for GitHub compatibility
- **Sequence Diagrams**: For process flows and interactions
- **Flowcharts**: For decision trees and workflows
- **Component Diagrams**: For architectural overviews

### Color Coding
- **System 5**: Red (#ff9999) - Policy and governance
- **System 4**: Blue (#99ccff) - Intelligence and environment
- **System 3**: Green (#99ff99) - Control and resources
- **System 2**: Orange (#ffcc99) - Coordination and information
- **System 1**: Yellow (#ffff99) - Operations and agents
- **External**: Gray (#e6e6e6) - External systems and interfaces
- **Algedonic**: Red dashed - Pain/pleasure signal flows

### Documentation Format
Each diagram includes:
- **Overview**: Purpose and scope
- **Mermaid Diagram**: Visual representation
- **Process Flows**: Sequence diagrams for complex interactions
- **Implementation Details**: Code examples and file references
- **Configuration**: Settings and parameters
- **Performance Notes**: Characteristics and optimization

## Usage Instructions

### Viewing Diagrams
- All diagrams use Mermaid syntax and render directly in GitHub
- Click on any diagram link above to view the full documentation
- Diagrams include interactive elements and detailed annotations

### Updating Diagrams
- Diagrams are maintained as Markdown files with embedded Mermaid
- Update the source `.md` files to modify diagrams
- Follow the established color coding and naming conventions

### Integration with README
- Main README references key diagrams for architectural understanding
- Each system section includes links to relevant diagrams
- API documentation includes flow diagrams for complex operations

This comprehensive diagram collection provides complete visual documentation for one of the most sophisticated cybernetic system implementations available, suitable for technical teams, stakeholders, and academic research.