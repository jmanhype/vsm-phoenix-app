#!/bin/bash

# VSM MCP Core Test Suite
# Consolidated from: bulletproof_proof.sh, prove_mcp_works.sh, test_mcp_direct.sh
# Tests all VSM and Hive MCP tools via stdio protocol

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# MCP server script
MCP_SERVER="../start_vsm_mcp_server.exs"

echo "🧪 VSM MCP Core Test Suite"
echo "=========================="
echo ""

# Helper function to run a test
run_test() {
    local test_name="$1"
    local request="$2"
    local expected_pattern="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $test_name... "
    
    local response=$(echo "$request" | timeout 5s "$MCP_SERVER" 2>/dev/null | grep -v "^[0-9]" | grep "{" || echo "{}")
    
    if echo "$response" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        echo "  Expected pattern: $expected_pattern"
        echo "  Got response: $response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test 1: Initialize
echo "📋 Protocol Tests"
echo "-----------------"
run_test "MCP Initialize" \
    '{"jsonrpc": "2.0", "method": "initialize", "id": 1, "params": {"protocolVersion": "2024-11-05", "capabilities": {}}}' \
    '"protocolVersion":"2024-11-05"'

# Test 2: List tools
run_test "List Tools" \
    '{"jsonrpc": "2.0", "method": "tools/list", "id": 2}' \
    '"name":"vsm_scan_environment"'

echo ""
echo "🔧 VSM Tool Tests"
echo "-----------------"

# Test 3: Environmental scan
run_test "vsm_scan_environment" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 3, "params": {"name": "vsm_scan_environment", "arguments": {"scope": "targeted"}}}' \
    '"status":"completed"'

# Test 4: Check viability
run_test "vsm_check_viability" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 4, "params": {"name": "vsm_check_viability", "arguments": {}}}' \
    '"overall_viability"'

# Test 5: Synthesize policy
run_test "vsm_synthesize_policy" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 5, "params": {"name": "vsm_synthesize_policy", "arguments": {"anomaly_type": "test_anomaly", "severity": 0.7}}}' \
    '"policy_id":"POL'

# Test 6: Spawn meta-system
run_test "vsm_spawn_meta_system" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 6, "params": {"name": "vsm_spawn_meta_system", "arguments": {"identity": "TEST_VSM", "purpose": "testing"}}}' \
    '"spawn_status":"successful"'

echo ""
echo "🐝 Hive Tool Tests"
echo "-------------------"

# Test 7: Discover nodes
run_test "hive_discover_nodes" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 7, "params": {"name": "hive_discover_nodes", "arguments": {}}}' \
    '"total_nodes"'

# Test 8: Route message
run_test "hive_route_message" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 8, "params": {"name": "hive_route_message", "arguments": {"target": "TEST_VSM", "message": "test"}}}' \
    '"routing_status"'

# Test 9: Coordinate swarm
run_test "hive_coordinate_swarm" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 9, "params": {"name": "hive_coordinate_swarm", "arguments": {"task": "test_coordination", "vsm_count": 3}}}' \
    '"coordination_id"'

# Test 10: Spawn child VSM
run_test "hive_spawn_vsm" \
    '{"jsonrpc": "2.0", "method": "tools/call", "id": 10, "params": {"name": "hive_spawn_vsm", "arguments": {"config": {"identity": "CHILD_VSM", "parent": "TEST_VSM"}}}}' \
    '"vsm_id"'

echo ""
echo "📊 Test Summary"
echo "==============="
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Some tests failed${NC}"
    exit 1
fi