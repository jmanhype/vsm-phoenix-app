# VSM Phoenix API Documentation

## Base URL
`http://localhost:4000`

## Available Endpoints

### 1. System Status
**GET** `/api/vsm/status`
- Returns overall system health and status of all 5 systems

### 2. Individual System Status
**GET** `/api/vsm/system/:level`
- Get status of a specific system (1-5)
- Example: `/api/vsm/system/5` for Queen status

### 3. Queen Policy Decision
**POST** `/api/vsm/system5/decision`
- Submit a decision request to System 5 (Queen)
- Body:
```json
{
  "type": "resource_allocation",
  "priority": "high",
  "context": {
    "resource": "compute",
    "amount": 50
  }
}
```

### 4. Algedonic Signals
**POST** `/api/vsm/algedonic/:signal`
- Send pleasure or pain signals to the system
- Signal types: `pleasure` or `pain`
- Body:
```json
{
  "intensity": 0.8,
  "context": "User satisfaction feedback"
}
```

## Example Usage

### Using curl:
```bash
# Get system status
curl http://localhost:4000/api/vsm/status

# Send pleasure signal
curl -X POST http://localhost:4000/api/vsm/algedonic/pleasure \
  -H "Content-Type: application/json" \
  -d '{"intensity": 0.9, "context": "Great performance"}'

# Request policy decision
curl -X POST http://localhost:4000/api/vsm/system5/decision \
  -H "Content-Type: application/json" \
  -d '{"type": "adaptation", "priority": "medium", "context": {"reason": "Load increase"}}'
```

### Using a REST client:
You can use tools like:
- Postman
- Insomnia
- Thunder Client (VS Code extension)
- Or any HTTP client library in your preferred language

## Dashboard
The real-time dashboard is available at: `http://localhost:4000`

The dashboard will automatically update every 5 seconds to reflect any changes made through the API.