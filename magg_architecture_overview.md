# MAGG Architecture Overview

## Project Overview

**MAGG (The MCP Aggregator)** is a meta-server for managing multiple Model Context Protocol (MCP) servers. It enables LLMs to dynamically discover, configure, and extend their own capabilities through a unified interface.

- **Version**: 0.10.0
- **License**: AGPL-3.0-or-later
- **Language**: Python 3.12+
- **Author**: Phillip Sitbon

## Core Architecture

### 1. Overall Design Patterns

MAGG employs several sophisticated architectural patterns:

- **Proxy Pattern**: Dynamic tool interception and forwarding to managed servers
- **Plugin Architecture**: Extensible server management with hot-reloading
- **Async Message Bus**: Non-blocking communication between components
- **Configuration-Driven Design**: Pydantic-based settings with validation
- **Mixin-Based Composition**: Flexible capability extension through mixins

### 2. Core Components

#### MaggServer (server/server.py)
- Main server implementation inheriting from ManagedServer
- Handles dynamic server addition/removal
- Implements smart configuration using LLM sampling
- Manages tool registration and discovery
- Provides health checks and status monitoring

#### ConfigManager (settings.py)
- Centralized configuration management
- Environment variable handling with MAGG_ prefix
- Server configuration persistence
- Kit and authentication settings
- Path resolution and validation

#### ServerManager (server/manager.py)
- Server lifecycle management (start/stop/restart)
- Transport abstraction (stdio/HTTP)
- Process management for child servers
- Connection pooling and resource management

#### ProxyMCP Mixin (proxy/mixin.py)
- Tool call interception and routing
- Namespace management with 'proxy:' prefix
- Support for tools, resources, and prompts
- Type-safe validation and error handling
- Async backend client communication

#### MessageRouter (messaging.py)
- Real-time notification handling
- Server message coordination
- Callback-based event system
- Thread-safe async message processing
- Support for multiple message types

#### KitManager (kit.py)
- Bundle management for related servers
- Dynamic kit discovery and loading
- Server-kit relationship management
- JSON-based kit configuration
- Metadata and versioning support

### 3. Entry Points and Workflows

#### CLI Entry Points (cli.py)
```
magg serve [stdio|http|hybrid]  # Start MAGG server
magg server [list|add|remove]   # Manage servers
magg config [show|export]        # Configuration management
magg kit [list|load|export]      # Kit management
magg auth [init|generate]        # Authentication
```

#### Main Workflows

1. **Server Management Flow**:
   - CLI command → ConfigManager → ServerManager → Process spawn
   - Configuration validation → Transport setup → Server registration

2. **Tool Proxy Flow**:
   - Tool call → ProxyMCP intercept → Route to target server
   - Response processing → Type validation → Return to client

3. **Configuration Flow**:
   - Load settings → Validate → Apply environment variables
   - Watch for changes → Hot reload → Update running servers

4. **Message Flow**:
   - Server notification → MessageRouter → Handler dispatch
   - Async processing → Callback execution → Client update

### 4. Technology Stack

#### Core Dependencies
- **fastmcp**: MCP protocol implementation
- **aiohttp**: Async HTTP client/server
- **pydantic/pydantic-settings**: Configuration and validation
- **rich/prompt-toolkit**: CLI interface
- **cryptography/pyjwt**: Authentication
- **watchdog**: File system monitoring
- **art**: ASCII art generation

#### Build System
- **Hatchling**: Modern Python packaging
- **uv**: Recommended package manager
- **Docker**: Container support

### 5. Project Structure

```
magg/
├── __init__.py
├── __main__.py         # Package entry point
├── cli.py              # Command-line interface
├── settings.py         # Configuration management
├── auth.py             # Authentication handling
├── kit.py              # Kit management
├── messaging.py        # Real-time messaging
├── process.py          # Process management
├── reload.py           # Hot reload functionality
├── server/
│   ├── server.py       # Main server implementation
│   ├── manager.py      # Server lifecycle management
│   ├── runner.py       # Server execution
│   ├── response.py     # Response handling
│   └── defaults.py     # Default configurations
├── proxy/
│   ├── mixin.py        # Proxy functionality
│   ├── client.py       # Proxy client
│   ├── server.py       # Proxy server
│   └── types.py        # Type definitions
├── discovery/
│   ├── catalog.py      # Tool catalog management
│   ├── metadata.py     # Server metadata collection
│   └── search.py       # Tool search functionality
├── logs/               # Logging utilities
├── util/               # Helper functions
└── contrib/            # Community contributions
```

## Key Features

### Dynamic Tool Management
- Automatic tool discovery from managed servers
- Tool namespacing to prevent conflicts
- Hot-reloading of server configurations
- Smart configuration with LLM assistance

### Transport Flexibility
- **stdio**: Standard input/output communication
- **HTTP/SSE**: HTTP with Server-Sent Events
- **Hybrid**: Combined stdio and HTTP modes
- Configurable per-server transport

### Security Features
- Bearer token authentication
- JWT-based token generation
- Public/private key management
- Per-server authentication settings

### Organization Features
- Kit-based server grouping
- Tagging and categorization
- Metadata management
- Import/export capabilities

### Developer Experience
- Rich CLI with color output
- Comprehensive error messages
- Configuration validation
- Auto-completion support

## Integration Points

### MCP Protocol
- Full MCP specification compliance
- Tool, resource, and prompt support
- Notification handling
- Progress tracking

### External Services
- Git repository support for server sources
- HTTP/HTTPS server endpoints
- Local file system servers
- Docker container support

### Configuration Sources
- JSON configuration files
- Environment variables
- Command-line arguments
- Kit definitions

## Performance Considerations

- Async architecture for non-blocking operations
- Connection pooling for HTTP transports
- Lazy loading of server configurations
- Efficient message routing
- Caching for tool discovery

## Summary

MAGG provides a sophisticated, extensible architecture for managing multiple MCP servers. Its proxy-based design allows transparent tool forwarding while maintaining strong typing and validation. The configuration-driven approach with hot-reloading makes it highly adaptable to changing requirements. The kit system provides excellent organization capabilities for complex server ecosystems.

The architecture emphasizes:
- **Flexibility**: Multiple transports, extensible design
- **Safety**: Strong validation, authentication support
- **Developer Experience**: Rich CLI, clear error messages
- **Performance**: Async operations, efficient routing
- **Organization**: Kits, tags, metadata management