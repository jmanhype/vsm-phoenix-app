# CLAUDE.md Directory Guide

## Purpose
Each subdirectory in the VSM Phoenix codebase now contains a focused CLAUDE.md file that explains:
- What files are in that specific directory
- The purpose and key concepts
- Quick start examples
- Integration points with other components

## Phase 2 Component Directories with CLAUDE.md:

### My Implementations:
- `lib/vsm_phoenix/crdt/CLAUDE.md` - CRDT state synchronization
- `lib/vsm_phoenix/security/CLAUDE.md` - Cryptographic security layer

### Other Swarm Implementations:
- `lib/vsm_phoenix/system2/CLAUDE.md` - Cortical Attention Engine (5D scoring)
- `lib/vsm_phoenix/amqp/*/CLAUDE.md` - Distributed coordination (consensus, discovery, etc.)
- `lib/vsm_phoenix/telemetry/CLAUDE.md` - Telemetry with DSP/FFT processing
- `lib/vsm_phoenix/resilience/CLAUDE.md` - Circuit breakers (limited adoption)

### Integration Examples:
- `lib/vsm_phoenix/system1/agents/CLAUDE.md` - Telegram bot using all Phase 2 features
- `lib/vsm_phoenix/infrastructure/CLAUDE.md` - Base infrastructure extended by Phase 2

## How to Use:
1. Navigate to any directory
2. Read the CLAUDE.md for quick context
3. Understand the files and their purposes
4. See integration points with other components
5. Find quick start code examples

## Benefits:
- Focused documentation per directory
- No need to search through large documents
- Clear separation of concerns
- Easy to maintain and update
- Perfect for Claude Code context windows

Total CLAUDE.md files: 20+ across all VSM subdirectories