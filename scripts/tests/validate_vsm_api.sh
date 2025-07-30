#!/bin/bash

echo "=== VSM API Validation Script ==="
echo ""

# Base URL
BASE_URL="http://localhost:4000/api/vsm"

# 1. Check System Health
echo "1. System Health Check:"
curl -s $BASE_URL/health | jq '.' || echo "No health endpoint"
echo ""

# 2. Test System 5 Decision Endpoint
echo "2. System 5 Decision Making:"
curl -X POST $BASE_URL/system5/decision \
  -H "Content-Type: application/json" \
  -d '{
    "decision_type": "resource_allocation",
    "context": "test_decision",
    "options": ["option1", "option2"],
    "urgency": "medium"
  }' | jq '.'
echo ""

# 3. Test System 4 Adaptation
echo "3. System 4 Adaptation Request:"
curl -X POST $BASE_URL/system4/adaptation \
  -H "Content-Type: application/json" \
  -d '{
    "challenge": {
      "type": "variety_imbalance",
      "urgency": "high",
      "variety_ratio": 3.2,
      "context": "external_disruption"
    }
  }' | jq '.' || echo "No adaptation endpoint"
echo ""

# 4. Test Meta-System Spawning
echo "4. Meta-System Spawning Check:"
curl -X POST $BASE_URL/system4/meta \
  -H "Content-Type: application/json" \
  -d '{
    "recursion_level": 2,
    "domain": "test_domain",
    "variety_overload": true
  }' | jq '.' || echo "No meta endpoint"
echo ""

# 5. Test high intensity pain (should trigger MCP)
echo "5. High Intensity Pain Signal (MCP Trigger):"
curl -X POST $BASE_URL/algedonic/pain \
  -H "Content-Type: application/json" \
  -d '{"intensity": 0.85, "context": "critical_variety_overload"}'
echo ""

# 6. Check viability after signals
echo "6. Current Viability Score:"
curl -s http://localhost:4000 | grep -A5 'Viability Score' | grep -oE '[0-9]+\.[0-9]%' | head -1
echo ""

# 7. Test System 3 Resource Allocation
echo "7. System 3 Resource Request:"
curl -X POST $BASE_URL/system3/allocate \
  -H "Content-Type: application/json" \
  -d '{
    "resource_type": "compute",
    "amount": 0.5,
    "context": "operations_scaling",
    "priority": "high"
  }' | jq '.' || echo "No allocation endpoint"
echo ""

# 8. Test System 2 Coordination
echo "8. System 2 Coordination Status:"
curl -s $BASE_URL/system2/status | jq '.' || echo "No coordination status endpoint"
echo ""

# 9. Test System 1 Operations
echo "9. System 1 Operations Metrics:"
curl -s $BASE_URL/system1/metrics | jq '.' || echo "No operations metrics endpoint"
echo ""

echo "=== Validation Complete ==="
echo "Check server logs for:"
echo "- '🧠 TRIGGERING LLM POLICY SYNTHESIS FROM PAIN SIGNAL'"
echo "- '✅ MCP Policy synthesized'"
echo "- '📡 Falling back to direct policy synthesis'"
echo "- MCP server errors or successful tool calls"