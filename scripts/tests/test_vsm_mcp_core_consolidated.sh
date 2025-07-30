#!/bin/bash

# Consolidated VSM MCP Core Functionality Test
# Combines bulletproof_proof.sh and prove_mcp_works.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}🎯 VSM MCP CORE FUNCTIONALITY TEST${NC}"
echo "===================================="
echo ""

# Helper function to run a test
run_test() {
    local test_name="$1"
    local request="$2"
    local expected_check="$3"
    
    echo -e "${YELLOW}🧪 TEST: $test_name${NC}"
    
    # Execute request
    local result=$(echo "$request" | timeout 5s ./start_vsm_mcp_server.exs 2>/dev/null | grep -v "info\|warning" | tail -1)
    
    # Check if we got a result
    if [ -z "$result" ]; then
        echo -e "${RED}❌ FAILED: No response received${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Validate JSON
    if ! echo "$result" | jq . >/dev/null 2>&1; then
        echo -e "${RED}❌ FAILED: Invalid JSON response${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
    
    # Run custom check
    if eval "$expected_check"; then
        echo -e "${GREEN}✅ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAILED: Check failed${NC}"
        echo "Response: $result"
        ((TESTS_FAILED++))
    fi
    echo ""
}

# Test 1: Protocol Initialization
run_test "MCP Protocol Initialize" \
    '{"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}' \
    'echo "$result" | jq -e ".result.protocolVersion == \"2024-11-05\"" >/dev/null'

# Test 2: Tools Listing
run_test "Tools Listing (8 tools expected)" \
    '{"jsonrpc": "2.0", "method": "tools/list", "id": 2}' \
    '[[ $(echo "$result" | jq ".result.tools | length") -eq 8 ]]'

# Test 3: VSM Environmental Scan
run_test "VSM Environmental Scan" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 3, "params": {"name": "vsm_scan_environment", "arguments": {"scope": "targeted"}}}' \
    'echo "$result" | jq -e ".result.content[0].text" | jq -e ".scan_result.status == \"completed\"" >/dev/null'

# Test 4: Policy Synthesis with High Severity
run_test "Policy Synthesis (auto-execute for severity > 0.7)" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 4, "params": {"name": "vsm_synthesize_policy", "arguments": {"anomaly_type": "security_breach", "severity": 0.9}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".synthesized_policy.auto_execute == true" >/dev/null'

# Test 5: Policy Synthesis with Low Severity
run_test "Policy Synthesis (no auto-execute for severity < 0.7)" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 5, "params": {"name": "vsm_synthesize_policy", "arguments": {"anomaly_type": "minor_anomaly", "severity": 0.3}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".synthesized_policy.auto_execute == false" >/dev/null'

# Test 6: VSM Meta-System Spawning
run_test "VSM Meta-System Spawning" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 6, "params": {"name": "vsm_spawn_meta_system", "arguments": {"identity": "TEST_VSM", "purpose": "testing"}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".spawned_vsm.spawn_status == \"successful\"" >/dev/null'

# Test 7: Variety Adaptation
run_test "VSM Variety Adaptation" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 7, "params": {"name": "vsm_adapt_variety", "arguments": {"gap_analysis": {"required": 10, "current": 7}}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".adaptation_result.variety_acquired > 0" >/dev/null'

# Test 8: Hive Node Discovery
run_test "Hive Node Discovery" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 8, "params": {"name": "hive_discover_nodes", "arguments": {}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".total_nodes >= 0" >/dev/null'

# Test 9: Hive Pattern Propagation
run_test "Hive Pattern Propagation" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 9, "params": {"name": "hive_propagate_pattern", "arguments": {"pattern": {"type": "test_pattern", "data": "test"}}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".propagation_status == \"initiated\"" >/dev/null'

# Test 10: Hive Swarm Coordination
run_test "Hive Swarm Coordination" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 10, "params": {"name": "hive_coordinate_swarm", "arguments": {"task": "test_coordination", "topology": "mesh"}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".coordination_active == true" >/dev/null'

# Test 11: Hive Collective Decision
run_test "Hive Collective Decision" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 11, "params": {"name": "hive_collective_decide", "arguments": {"decision_type": "consensus", "options": ["A", "B", "C"]}}}' \
    'echo "$result" | jq -r ".result.content[0].text" | jq -e ".decision_made == true" >/dev/null'

# Summary
echo -e "${BLUE}📊 TEST SUMMARY${NC}"
echo "================"
echo -e "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo -e "${GREEN}✅ Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo "VSM MCP Server is fully functional!"
    exit 0
else
    echo -e "${RED}⚠️  SOME TESTS FAILED${NC}"
    echo "Please check the failed tests above for details."
    exit 1
fi