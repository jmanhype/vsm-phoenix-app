# VSM Phoenix Documentation

## Quick Navigation

### 🚀 [Start Here](01_start_here/readme.md)
New to VSM Phoenix? Start with our overview and quick start guide.

### 🏗️ [Architecture](02_architecture/readme.md)
Deep dive into VSM systems, hive mind design, and MCP integration.

### 🔌 [API Reference](03_api/readme.md)
Complete API documentation with examples.

### 💻 [Development](04_development/readme.md)
Setup, testing, debugging, and contributing guidelines.

### 🚢 [Operations](05_operations/readme.md)
Deployment, monitoring, and production operations.

### 📝 [Decisions](06_decisions/readme.md)
Architectural decisions and rationale.

## Project Overview

VSM Phoenix implements a Viable System Model with:
- **5 VSM Systems** for cybernetic control
- **Hive Mind** distributed coordination
- **MCP Integration** for capability expansion
- **Phoenix LiveView** dashboard
- **100% Elixir/OTP** implementation

## Getting Started

```bash
# Clone and setup
git clone <repo>
cd vsm_phoenix_app
mix deps.get

# Run tests
mix test --no-start

# Start the system
iex -S mix phx.server
```

## Documentation Standards

- All docs use **lowercase-hyphenated.md** naming
- Clear hierarchy with numbered sections
- README.md in each directory for navigation
- Examples included where relevant
- Keep it concise and practical