# Development Directory

Developer guides and testing documentation.

## Files in this directory:

- `readme.md` - Development overview

## Subdirectories:

### testing/
Testing guides and results:
- `testing-guide.md` - How to write tests
- `test-summary.md` - Test suite summary
- `test-results-latest.md` - Latest test results
- `dashboard-tests.md` - Dashboard testing guide

## Purpose:
Provides guidance for developers working on VSM Phoenix:
- Development setup
- Coding standards
- Testing practices
- Debugging techniques
- Performance optimization

## Development Workflow:

### Setup
1. Install dependencies: `mix deps.get`
2. Setup database: `mix ecto.setup`
3. Start services: `docker-compose up`
4. Run server: `mix phx.server`

### Testing
- Unit tests: `mix test`
- Integration tests: `mix test --only integration`
- Coverage: `mix test --cover`
- Specific file: `mix test path/to/test.exs`

### Code Quality
- Format: `mix format`
- Lint: `mix credo`
- Dialyzer: `mix dialyzer`
- Documentation: `mix docs`

## Best Practices:
- Follow OTP principles
- Write comprehensive tests
- Document public APIs
- Use proper supervision
- Handle errors gracefully

## Phase 2 Development:
- CRDT integration patterns
- Security layer usage
- Telemetry instrumentation
- Distributed testing strategies