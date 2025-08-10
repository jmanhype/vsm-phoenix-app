# Goldrush Directory

Event processing and telemetry system for VSM Phoenix.

## Files in this directory:

- `manager.ex` - Plugin-based event processing manager
- `telemetry.ex` - Telemetry event handling
- `supervisor.ex` - Goldrush supervision

## Subdirectory:
- `plugins/` - Event processing plugins

## Purpose:
Provides a plugin-based event processing system that captures and analyzes system events in real-time.

## Key Features:
- Plugin architecture for extensibility
- Real-time event processing
- Integration with Telemetry system
- Policy learning from events

## Plugins Directory:
- `policy_learner.ex` - Learn policies from event patterns
- `variety_detector.ex` - Detect variety changes in events

## Usage:
Events flow through Goldrush where plugins can analyze, transform, and react to system behavior.