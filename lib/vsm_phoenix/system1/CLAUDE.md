# System 1 Directory

This directory contains the System 1 (Operations) implementation - the autonomous operational units.

## Files in this directory:
- `supervisor.ex` - Dynamic supervisor for spawning agents
- `context.ex` - Base context module for all System 1 units
- `operations.ex` - Operational logic execution
- `registry.ex` - Agent registry and lookup
- `telegram_init.ex` - Telegram bot initialization
- `llm_worker_init.ex` - LLM worker initialization

## Subdirectory:
- `agents/` - Contains all agent implementations

## Purpose:
System 1 units are the "doing" parts of the VSM - they execute tasks autonomously while reporting to higher systems.

## Key Features:
- Dynamic agent spawning
- Agent registry for discovery
- Context-based operation execution
- Multiple agent types (telegram, worker, sensor, api)