# Configuration Directory

Runtime and compile-time configuration for VSM Phoenix, including storage, persistence, and database settings.

## Files in this directory:

### Core Configuration
- `config.exs` - Main configuration entry point
- `runtime.exs` - Runtime environment configuration
- `dev.exs` - Development environment settings
- `test.exs` - Test environment configuration
- `test_isolated.exs` - Isolated test configuration

### Feature-Specific Configs
- `infrastructure.exs` - Infrastructure and storage settings
- `security.exs` - Cryptographic and security configuration
- `resilience.exs` - Circuit breaker and fault tolerance
- `variety_engineering.exs` - Variety thresholds and metrics
- `bulletproof.exs` - Bulletproof mode configuration
- `no_mcp.exs` - Configuration without MCP servers

## Storage Configuration:

### Database Settings (runtime.exs)
- PostgreSQL connection pooling
- SSL configuration
- Connection timeout settings
- Migration configuration

### ETS Tables (infrastructure.exs)
- Table initialization settings
- Memory limits
- Persistence options
- Backup configuration

### CRDT Storage (infrastructure.exs)
- Node discovery settings
- Replication factor
- Sync intervals
- Conflict resolution

### Message Queue (infrastructure.exs)
- RabbitMQ connection settings
- Queue durability options
- Message persistence
- Dead letter configuration

## Persistence Patterns:

### Development (dev.exs)
```elixir
# Local file storage for development
config :vsm_phoenix, :storage,
  adapter: :file,
  path: "priv/storage/dev"
```

### Production (runtime.exs)
```elixir
# Distributed storage for production
config :vsm_phoenix, :storage,
  adapter: :s3,
  bucket: System.get_env("STORAGE_BUCKET")
```

### Test (test.exs)
```elixir
# In-memory storage for tests
config :vsm_phoenix, :storage,
  adapter: :memory,
  cleanup: :after_each
```

## Key Storage Variables:
- `DATABASE_URL` - PostgreSQL connection
- `STORAGE_BUCKET` - S3 bucket name
- `REDIS_URL` - Redis cache connection
- `CRDT_NODES` - CRDT cluster nodes