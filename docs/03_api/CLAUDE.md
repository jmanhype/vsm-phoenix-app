# API Directory

API documentation and integration guides.

## Files in this directory:

- `readme.md` - API overview

## Subdirectories:

### integrations/
External integration documentation:
- `telegram_integration.md` - Telegram bot API integration

### reference/
API reference documentation:
- `endpoints.md` - HTTP endpoint reference

## Purpose:
Documents all APIs exposed by VSM Phoenix:
- REST API endpoints
- WebSocket connections
- MCP protocol interfaces
- Integration APIs
- Internal service APIs

## API Categories:

### External APIs
- HTTP REST endpoints
- WebSocket real-time APIs
- MCP tool interfaces
- Telegram bot commands

### Internal APIs
- Inter-system communication
- AMQP message contracts
- Service discovery APIs
- Health check endpoints

## Quick Reference:
```bash
# Get system status
GET /api/status

# Execute VSM tool
POST /api/mcp/tools/execute

# WebSocket connection
ws://localhost:4000/socket/websocket
```

## Integration Guides:
- How to integrate with Telegram
- MCP client implementation
- WebSocket event handling
- Authentication patterns