# VSM Phoenix API Documentation

## Overview

This directory contains comprehensive API documentation for VSM Phoenix, including both Phase 1 and Phase 2 features.

## Documentation Structure

- `PHASE2_API.md` - Comprehensive Phase 2 API documentation with examples
- Interactive API Explorer - Available at `http://localhost:4000/api/docs`
- OpenAPI Specification - Available at `http://localhost:4000/api/docs/openapi.json`

## Quick Start

### 1. Interactive API Explorer

Visit `http://localhost:4000/api/docs` to access the Swagger UI interface where you can:
- Browse all available endpoints
- Try out API calls directly from the browser
- View request/response schemas
- Download the OpenAPI specification

### 2. Authentication

Most endpoints require JWT authentication:

```bash
# Login to get access token
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Use token in subsequent requests
curl -X GET http://localhost:4000/api/vsm/status \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### 3. Key API Categories

#### VSM Core Operations
- System status monitoring
- Algedonic signal processing
- Multi-level system management

#### GoldRush Pattern Matching
- Event pattern registration
- Real-time event processing
- Complex event queries

#### LLM Integration
- Chat completions
- Embeddings generation
- Model management

#### Agent Management
- S1 agent lifecycle
- Command execution
- Performance monitoring

#### WebSocket Subscriptions
- Real-time event streaming
- Channel-based subscriptions
- Filtered event delivery

## Client Libraries

Example client implementations are available in:
- JavaScript/TypeScript
- Python
- Elixir
- cURL commands

See `PHASE2_API.md` for detailed examples.

## API Endpoints Summary

### Public Endpoints (No Auth Required)
- `GET /api/docs` - API documentation
- `POST /api/auth/login` - User authentication
- `GET /api/vsm/status` - Basic system status

### Protected Endpoints (Auth Required)
- `/api/vsm/*` - VSM system operations
- `/api/goldrush/*` - Pattern matching engine
- `/api/llm/*` - Language model services
- `/api/ws/*` - WebSocket subscriptions

## Development Tools

### Testing with cURL
```bash
# Test system status
curl http://localhost:4000/api/vsm/status

# Test with authentication
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:4000/api/vsm/agents
```

### Testing with HTTPie
```bash
# More user-friendly HTTP client
http GET localhost:4000/api/vsm/status
http POST localhost:4000/api/goldrush/events \
  type=metric data:='{"cpu": 95}'
```

### Postman Collection
Import the OpenAPI specification into Postman:
1. Open Postman
2. Import → Link → `http://localhost:4000/api/docs/openapi.json`
3. Generate collection from OpenAPI

## Rate Limiting

Default limits:
- 1000 requests/hour per API key
- 100 requests/minute burst
- 10 concurrent WebSocket connections

## Support

For API support and questions:
- Check the comprehensive documentation in `PHASE2_API.md`
- Visit the interactive API explorer
- Contact the development team

## Version History

- **v2.0.0** - Phase 2 release with GoldRush, LLM, and enhanced security
- **v1.0.0** - Initial release with core VSM functionality