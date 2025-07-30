# Available MCP Servers Catalog

## Overview

This document catalogs all discovered MCP (Model Context Protocol) servers from various sources. These servers provide variety engineering capabilities for VSM Phoenix.

## Discovery Sources

1. **NPM Registry** - Official and community packages
2. **GitHub Repositories** - Open source implementations
3. **MAGG Kits** - Pre-configured server collections
4. **Commercial Providers** - Enterprise solutions

## Official MCP Servers

### Core Infrastructure

#### 1. Filesystem Server
- **Package**: `@modelcontextprotocol/server-filesystem`
- **Capabilities**: File read/write, directory operations, access control
- **Install**: `npm install -g @modelcontextprotocol/server-filesystem`
- **Use Case**: Secure file system access for AI applications

#### 2. Git Server
- **Package**: `@modelcontextprotocol/server-git`
- **Capabilities**: Repository operations, commit history, diff analysis
- **Install**: `npm install -g @modelcontextprotocol/server-git`
- **Use Case**: Version control integration

#### 3. GitHub Server
- **Package**: `@modelcontextprotocol/server-github`
- **Capabilities**: Repository management, PR operations, issue tracking
- **Install**: `npm install -g @modelcontextprotocol/server-github`
- **Use Case**: GitHub platform integration

#### 4. Memory Server
- **Package**: `@modelcontextprotocol/server-memory`
- **Capabilities**: Persistent storage, knowledge graphs, context retention
- **Install**: `npm install -g @modelcontextprotocol/server-memory`
- **Use Case**: Long-term memory and context management

## Community Servers

### Data & Analytics

#### 5. SQLite Server
- **Package**: `@modelcontextprotocol/server-sqlite`
- **Capabilities**: Database queries, schema management, data analysis
- **Install**: `npm install -g @modelcontextprotocol/server-sqlite`
- **Use Case**: Local database operations

#### 6. Astra DB Server
- **Repository**: Community maintained
- **Capabilities**: NoSQL operations, collection management, vector search
- **Use Case**: DataStax Astra DB integration

### Communication & Collaboration

#### 7. Slack Server
- **Maintainer**: Zencoder
- **Capabilities**: Channel management, messaging, user interactions
- **Use Case**: Slack workspace integration

#### 8. Notion Server
- **Package**: `@notionhq/notion-mcp-server`
- **Version**: 1.8.1
- **Capabilities**: Page management, database operations, content creation
- **Install**: `npm install -g @notionhq/notion-mcp-server`
- **Use Case**: Notion workspace integration

### Development Tools

#### 9. Heroku Server
- **Package**: `@heroku/mcp-server`
- **Version**: 1.0.7
- **Capabilities**: App management, deployment, configuration
- **Install**: `npm install -g @heroku/mcp-server`
- **Use Case**: Heroku platform operations

#### 10. Sentry Server
- **Package**: `@sentry/mcp-server`
- **Version**: 0.17.1
- **Capabilities**: Error tracking, performance monitoring, issue management
- **Install**: `npm install -g @sentry/mcp-server`
- **Use Case**: Application monitoring

#### 11. HubSpot Server
- **Package**: `@hubspot/mcp-server`
- **Version**: 0.4.0
- **Capabilities**: CRM operations, marketing automation, sales tools
- **Install**: `npm install -g @hubspot/mcp-server`
- **Use Case**: HubSpot platform integration

### Specialized Servers

#### 12. Code Runner Server
- **Package**: `mcp-server-code-runner`
- **Version**: 0.1.7
- **Capabilities**: Code execution, multi-language support, sandboxing
- **Install**: `npm install -g mcp-server-code-runner`
- **Use Case**: Safe code execution

#### 13. YouTube Data Server
- **Package**: `youtube-data-mcp-server`
- **Version**: 1.0.16
- **Capabilities**: Video data, channel info, analytics
- **Install**: `npm install -g youtube-data-mcp-server`
- **Use Case**: YouTube API integration

#### 14. Graphlit Server
- **Package**: `graphlit-mcp-server`
- **Capabilities**: Knowledge graphs, RAG, document parsing, web scraping
- **Install**: `npm install -g graphlit-mcp-server`
- **Use Case**: Advanced document processing

#### 15. Alchemy Server
- **Package**: `@alchemy/mcp-server`
- **Version**: 0.1.8
- **Capabilities**: Blockchain operations, Web3 integration
- **Install**: `npm install -g @alchemy/mcp-server`
- **Use Case**: Ethereum and blockchain interactions

#### 16. AMap Server
- **Package**: `@amap/amap-maps-mcp-server`
- **Version**: 0.0.8
- **Capabilities**: Mapping, geolocation, route planning
- **Install**: `npm install -g @amap/amap-maps-mcp-server`
- **Use Case**: Chinese mapping services

#### 17. Context7 Server
- **Package**: `@upstash/context7-mcp`
- **Version**: 1.0.14
- **Capabilities**: Redis operations, caching, real-time data
- **Install**: `npm install -g @upstash/context7-mcp`
- **Use Case**: Upstash Redis integration

## Enterprise Solutions

### Microsoft MCP Catalog
- **Repository**: `microsoft/mcp`
- **Servers**: Multiple Azure and Microsoft 365 integrations
- **Capabilities**: Cloud services, AI tools, Office integration

### Docker MCP Servers
- **Repository**: `docker/mcp-servers`
- **Servers**: Container management, image operations
- **Capabilities**: Docker ecosystem integration

## MAGG Kit Servers

### Example Kit
- **Servers**: 2 (filesystem, memory)
- **Install**: `magg kit load example`
- **Use Case**: Quick start development

## Discovery Patterns

### By Capability

**File Operations**:
- Filesystem Server
- Git Server
- GitHub Server

**Data Storage**:
- SQLite Server
- Astra DB Server
- Memory Server

**Communication**:
- Slack Server
- Notion Server

**Development**:
- Code Runner
- Heroku Server
- Sentry Server

**Specialized**:
- YouTube Data
- Graphlit
- Alchemy (blockchain)

### By Installation Method

**NPM Global**:
```bash
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @modelcontextprotocol/server-git
npm install -g @notionhq/notion-mcp-server
```

**MAGG Kits**:
```bash
magg kit load example
magg server add <server-name>
```

**Direct Repository**:
```bash
git clone https://github.com/modelcontextprotocol/servers
cd servers/<server-name>
npm install && npm start
```

## Integration Strategy

### For VSM Phoenix

1. **Core Servers** (Priority 1):
   - Filesystem (file operations)
   - Memory (state persistence)
   - SQLite (local data)

2. **Extended Servers** (Priority 2):
   - Git/GitHub (version control)
   - Slack/Notion (collaboration)
   - Code Runner (execution)

3. **Specialized Servers** (Priority 3):
   - Based on specific variety gaps
   - Custom implementations
   - Enterprise integrations

## Testing Approach

### Local Testing
```elixir
# Test filesystem server
{:ok, fs_server} = VsmPhoenix.MCP.ServerManager.start_server("filesystem", %{
  allowed_paths: ["/tmp/test"]
})

# Test memory server
{:ok, mem_server} = VsmPhoenix.MCP.ServerManager.start_server("memory", %{
  namespace: "test"
})
```

### Integration Testing
```elixir
# Run discovery
servers = VsmPhoenix.MCP.DiscoveryEngine.discover_all()

# Test each server
Enum.each(servers, fn {id, server} ->
  IO.puts("Testing #{id}: #{server.description}")
  # Run capability tests
end)
```

## Future Additions

### Potential Servers
- PostgreSQL MCP Server
- Redis MCP Server
- Kafka MCP Server
- Elasticsearch MCP Server
- AWS Services MCP Server
- Google Cloud MCP Server

### Custom Implementations
- VSM-specific servers
- Phoenix framework integration
- Elixir ecosystem bridges

## References

- [Model Context Protocol Docs](https://modelcontextprotocol.io)
- [Official MCP GitHub](https://github.com/modelcontextprotocol)
- [Awesome MCP Servers](https://github.com/wong2/awesome-mcp-servers)
- [MCP Server Examples](https://modelcontextprotocol.io/examples)