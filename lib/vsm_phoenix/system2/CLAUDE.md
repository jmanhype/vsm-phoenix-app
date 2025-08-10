# System 2 Directory

This directory contains the System 2 (Coordination) implementation for the VSM Phoenix application.

## Files in this directory

- **coordinator.ex** - Main coordination logic that prevents oscillation between System 1 units
- **cortical_attention_engine.ex** - Neuroscience-inspired attention mechanism for intelligent message prioritization

## Purpose

System 2 acts as the anti-oscillation layer in the VSM hierarchy, ensuring System 1 units don't create feedback loops or conflicting behaviors.

## Key Integration

The Coordinator integrates with the CorticalAttentionEngine to score every message for importance, filtering low-priority messages and expediting critical ones.