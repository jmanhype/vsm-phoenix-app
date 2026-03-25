# VSM Phoenix App

Phoenix LiveView application implementing Stafford Beer's Viable System Model (VSM). Provides a web dashboard for a 5-level cybernetic hierarchy with AMQP messaging, CRDT state, and LLM-based policy synthesis.

## Status

| Metric | Value |
|--------|-------|
| Version | 0.1.0 |
| Elixir | >= 1.14 |
| Runtime deps | 27 (Phoenix, Ecto, AMQP, LiveView, etc.) |
| Modules (.ex) | 251 |
| Test files | 61 |
| CI | GitHub Actions -- last run failed (Feb 2026, security scanning) |
| Database | PostgreSQL (required) |
| Message broker | RabbitMQ (required for AMQP features) |

## What it does

Implements the 5 VSM subsystems as Elixir processes with a Phoenix LiveView frontend:

| System | Role | Module path |
|--------|------|------------|
| System 1 | Operations -- task execution units | `lib/vsm_phoenix/system1/` |
| System 2 | Coordination -- anti-oscillation, conflict damping | `lib/vsm_phoenix/system2/` |
| System 3 | Control -- resource allocation, S3* audit bypass | `lib/vsm_phoenix/system3/` |
| System 4 | Intelligence -- environment scanning, adaptation proposals | `lib/vsm_phoenix/system4/` |
| System 5 | Policy -- governance, identity, algedonic signal processing | `lib/vsm_phoenix/system5/` |

Additional subsystems:

- AMQP messaging layer with 6 exchange types (`lib/vsm_phoenix/amqp/`)
- CRDT-based distributed state (G-Counter, PN-Counter, OR-Set, LWW-Set)
- Goldrush reactive stream plugins for telemetry
- Hive spawning for recursive VSM instances
- MCP tool integration via hermes_mcp

## Setup

Requires PostgreSQL and RabbitMQ running locally or via Docker.

```bash
git clone https://github.com/jmanhype/vsm-phoenix-app
cd vsm-phoenix-app
mix deps.get
mix ecto.setup
mix phx.server
```

Visit `http://localhost:4000` for the LiveView dashboard.

## Key dependencies

| Dependency | Purpose |
|-----------|---------|
| phoenix ~> 1.7.10 | Web framework |
| phoenix_live_view ~> 0.20.1 | Real-time dashboard |
| ecto_sql ~> 3.10 | Database layer |
| amqp ~> 3.2 | RabbitMQ client |
| hermes_mcp (git) | MCP tool protocol |
| quantum ~> 3.5 | Cron scheduling |
| httpoison ~> 2.0 | HTTP client |

## Project structure

```
lib/vsm_phoenix/
  system1/          # Operations (workers, task units)
  system2/          # Coordinator (anti-oscillation)
  system3/          # Control (resource management)
  system4/          # Intelligence (environment scanning)
  system5/          # Policy (queen, governance)
  amqp/             # 18 modules -- messaging infrastructure
  crdt/             # 6 modules -- distributed state types
  infrastructure/   # HTTP, security, metrics, PubSub
  goldrush/         # Reactive stream processing
  hive/             # Recursive VSM spawning
  agents/           # Agent factory, Telegram integration
```

## Limitations

- CI is not passing. Last workflow failure was a security scanning step.
- Depends on 2 git-sourced dependencies (hermes_mcp, goldrush) pinned to branches, not SHAs. Builds can break if upstream changes.
- The tidewave dependency is also git-sourced (branch: main).
- RabbitMQ is required for the AMQP subsystem; no in-memory fallback exists.
- 251 modules for a v0.1.0 project suggests significant scope. Test coverage relative to module count (61 test files for 251 modules) leaves gaps.
- No hex publication.

## License

Not specified in mix.exs. Check repository for LICENSE file.
