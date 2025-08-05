#!/bin/bash

# Phase 2 Integration Test Runner
# Runs comprehensive tests for all Phase 2 VSM components

set -e

echo "================================================"
echo "VSM Phoenix - Phase 2 Integration Test Suite"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to run a test and report results
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Running: ${test_name}${NC}"
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ ${test_name} passed${NC}\n"
        return 0
    else
        echo -e "${RED}✗ ${test_name} failed${NC}\n"
        return 1
    fi
}

# Track overall results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Phase 2 Component Tests
echo "1. Testing GoldRush Pattern Engine"
echo "--------------------------------"

if run_test "Pattern Engine Core" "mix test test/vsm_phoenix/goldrush/pattern_engine_test.exs"; then
    ((PASSED_TESTS++))
else
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo "2. Testing Telegram NLU Integration"
echo "-----------------------------------"

if run_test "NLU Integration" "mix test test/vsm_phoenix/telegram/nlu_integration_test.exs"; then
    ((PASSED_TESTS++))
else
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo "3. Testing AMQP Security Protocol"
echo "---------------------------------"

if run_test "Security Integration" "mix test test/vsm_phoenix/security/security_integration_test.exs"; then
    ((PASSED_TESTS++))
else
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

if run_test "AMQP Semantic Protocol" "mix test test/vsm_phoenix/amqp/semantic_protocol_test.exs"; then
    ((PASSED_TESTS++))
else
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo "4. Testing Complete Phase 2 Integration"
echo "--------------------------------------"

if run_test "Phase 2 Integration" "mix test test/vsm_phoenix/phase2_integration_test.exs"; then
    ((PASSED_TESTS++))
else
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

echo "5. Testing Phase 2 API Endpoints"
echo "--------------------------------"

# Start the server in the background for API tests
echo "Starting Phoenix server for API tests..."
MIX_ENV=test mix phx.server &
SERVER_PID=$!
sleep 5

# Test GoldRush API endpoints
if curl -s -X GET http://localhost:4000/api/goldrush/patterns > /dev/null; then
    echo -e "${GREEN}✓ GoldRush API endpoints available${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ GoldRush API endpoints not available${NC}"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Clean up server
kill $SERVER_PID 2>/dev/null || true

echo ""
echo "================================================"
echo "Phase 2 Integration Test Results"
echo "================================================"
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed: ${RED}${FAILED_TESTS}${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}All Phase 2 tests passed! 🎉${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please check the output above.${NC}"
    exit 1
fi