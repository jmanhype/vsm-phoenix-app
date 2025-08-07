# VSM Phoenix Architecture

This directory contains architectural documentation for the VSM Phoenix application.

## Core Architecture Documents

- [**ARCHITECTURE_SUMMARY.md**](./ARCHITECTURE_SUMMARY.md) - Overall system architecture overview
- [**system5_persistence.md**](./system5_persistence.md) - System5 persistence layer design
- [**mcp_architecture_design.md**](./mcp_architecture_design.md) - MCP integration architecture

## Implementation Guides

- [**IMPLEMENTATION_SUMMARY.md**](./IMPLEMENTATION_SUMMARY.md) - Implementation status and roadmap
- [**DECOMPOSITION_PLAN.md**](./DECOMPOSITION_PLAN.md) - System decomposition strategy
- [**migration_plan.md**](./migration_plan.md) - Migration and upgrade plans

## Project History

- [**CUTOVER_SUCCESS.md**](./CUTOVER_SUCCESS.md) - Successful cutover documentation

## VSM Systems

The application implements Beer's Viable Systems Model (VSM) with 5 hierarchical systems:

- **System 1**: Operations (Operational contexts and agents)
- **System 2**: Coordination (Anti-oscillation and coordination)  
- **System 3**: Control (Resource management and optimization)
- **System 4**: Intelligence (Environmental scanning and adaptation)
- **System 5**: Queen (Policy and identity governance)

## Key Integrations

- **Resilience Patterns**: Circuit breakers, bulkheads, retry logic
- **MCP Protocol**: Model Context Protocol for AI agent communication
- **AMQP/RabbitMQ**: Inter-system messaging and event handling
- **Variety Engineering**: Ashby's Law implementation across VSM hierarchy