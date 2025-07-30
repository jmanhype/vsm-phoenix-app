# VSM Phoenix Project Structure

## Root Directory

```
.
├── assets/          # Frontend assets (CSS, JS, images)
├── config/          # Phoenix configuration files
├── deps/            # Elixir dependencies (67 packages)
├── docs/            # Project documentation
├── examples/        # Example implementations
├── lib/             # Main application source code
├── logs/            # Application logs (gitignored)
├── priv/            # Private application files
├── scripts/         # Utility and test scripts
├── test/            # Test suite
├── .env             # Environment variables
├── .gitignore       # Git ignore configuration
├── mix.exs          # Project configuration
├── mix.lock         # Dependency lock file
├── package.json     # Node.js dependencies
├── README.md        # Project readme
├── TESTING.md       # Testing guide
├── start_vsm_mcp_server.exs  # MCP server starter
└── vsm_server.js    # JavaScript VSM server
```

## Source Code Structure (lib/)

```
lib/
├── vsm_phoenix/
│   ├── application.ex           # Main OTP application
│   ├── repo.ex                  # Database repository
│   ├── amqp/                    # AMQP protocol implementation
│   ├── goldrush/                # Telemetry and monitoring
│   ├── hive/                    # Hive mind coordination
│   ├── mcp/                     # Model Context Protocol integration
│   ├── service_bus/             # Service bus connectivity
│   ├── system1/                 # VSM System 1 (Operations)
│   ├── system2/                 # VSM System 2 (Coordination)
│   ├── system3/                 # VSM System 3 (Control)
│   ├── system4/                 # VSM System 4 (Intelligence)
│   └── system5/                 # VSM System 5 (Policy)
├── vsm_phoenix_web/
│   ├── components/              # Phoenix components
│   ├── controllers/             # HTTP controllers
│   ├── live/                    # LiveView modules
│   ├── endpoint.ex              # Phoenix endpoint
│   ├── router.ex                # HTTP routes
│   └── telemetry.ex             # Web telemetry
└── vsm_phoenix_web.ex           # Web module helpers
```

## Test Structure

```
test/
├── coverage/                    # Coverage-focused tests
├── mcp_integration_test.exs     # MCP integration tests
├── server_catalog_test.exs      # ServerCatalog tests
├── telemetry_functions_test.exs # Telemetry tests
├── test_helper.exs              # Test configuration
├── vsm_phoenix_test.exs         # Core functionality tests
└── web_functions_test.exs       # Web module tests
```

## Documentation

```
docs/
├── archive/                     # Historical documentation
├── api/                         # API documentation
├── architecture/                # Architecture documents
├── guides/                      # Implementation guides
├── API_DOCUMENTATION.md         # API reference
├── CYBERNETIC_HIVE_MIND_ARCHITECTURE.md
├── HIVE_MIND_ARCHITECTURE.md
├── README.md                    # Documentation index
└── TEST_RESULTS.md              # Test results
```

## Scripts

```
scripts/
├── demos/                       # Demo scripts
├── mcp_tests/                   # MCP test scripts
├── test/                        # Test utilities
├── test_runners/                # Test execution scripts
└── validation/                  # Validation scripts
```

## Key Features

- **VSM Implementation**: Full Viable System Model with Systems 1-5
- **MCP Integration**: Model Context Protocol for tool execution
- **Hive Mind**: Distributed coordination architecture
- **Phoenix LiveView**: Real-time dashboard and monitoring
- **Comprehensive Testing**: Unit tests with coverage reporting
- **Professional Structure**: Clean, organized, and maintainable

## Running Tests

```bash
# Run tests without starting Phoenix
mix test --no-start

# Run tests with coverage
mix test --no-start --cover
```

## Starting the Application

```bash
# Development mode
mix phx.server

# Interactive console
iex -S mix phx.server
```