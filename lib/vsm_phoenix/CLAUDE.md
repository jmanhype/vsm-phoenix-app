# VSM Phoenix Root Directory

Core application modules and system-wide components for the Viable Systems Model implementation.

## Files in this directory:

### Application Core
- `application.ex` - Main OTP application that starts the VSM supervision tree
- `bulletproof_application.ex` - Fault-tolerant application variant
- `test_application.ex` - Test environment application
- `vsm_supervisor.ex` - Root VSM supervisor

### System Services
- `health_checker.ex` - System-wide health monitoring
- `performance_monitor.ex` - Performance tracking and optimization
- `telemetry_collector.ex` - Telemetry event collection
- `config_manager.ex` - Configuration management
- `repo.ex` - Ecto repository (database)
- `tidewave_integration.ex` - External Tidewave service integration

## Subdirectories:
- `amqp/` - Advanced aMCP Protocol Extensions
- `crdt/` - Conflict-free replicated data types
- `goldrush/` - Event processing system
- `hive/` - Distributed hive coordination
- `infrastructure/` - Core infrastructure services
- `mcp/` - Model Context Protocol implementation
- `resilience/` - Circuit breakers and fault tolerance
- `security/` - Cryptographic security layer
- `service_bus/` - Azure Service Bus integration
- `system1/` - Operations (doing)
- `system2/` - Coordination (anti-oscillation)
- `system3/` - Control (resource management)
- `system4/` - Intelligence (environmental scanning)
- `system5/` - Queen (policy and identity)
- `telemetry/` - Signal processing and DSP
- `variety_engineering/` - Ashby's Law implementation

## Key Integration Points:
- Application starts all VSM systems in hierarchical order
- Health checker monitors all subsystems
- Performance monitor tracks cross-system metrics
- Telemetry feeds into signal processing