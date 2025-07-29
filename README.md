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