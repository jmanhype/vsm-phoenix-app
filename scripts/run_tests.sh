#!/bin/bash

# VSM Phoenix Test Runner
# Comprehensive test execution with proper categorization

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test categories
TEST_MODE=${1:-unit}

echo -e "${BLUE}🧪 VSM Phoenix Test Runner${NC}"
echo -e "${BLUE}=========================${NC}"
echo -e "Mode: ${YELLOW}$TEST_MODE${NC}\n"

case $TEST_MODE in
  unit)
    echo -e "${GREEN}Running unit tests only...${NC}"
    echo "These tests run quickly and don't require external services."
    echo
    mix test --only unit
    ;;
    
  integration)
    echo -e "${YELLOW}Running integration tests...${NC}"
    echo "These tests may require the Phoenix app to be running."
    echo "Starting Phoenix in the background..."
    
    # Start Phoenix in background
    mix phx.server &
    PHX_PID=$!
    
    # Wait for Phoenix to start
    sleep 5
    
    # Run integration tests
    mix test --only integration
    
    # Stop Phoenix
    kill $PHX_PID 2>/dev/null || true
    ;;
    
  external)
    echo -e "${YELLOW}Running external dependency tests...${NC}"
    echo "These tests require MAGG to be installed."
    echo
    
    # Check if MAGG is installed
    if ! command -v magg &> /dev/null; then
      echo -e "${RED}❌ MAGG is not installed!${NC}"
      echo "Install with: npm install -g @magg"
      exit 1
    fi
    
    mix test --only external
    ;;
    
  all)
    echo -e "${GREEN}Running all tests...${NC}"
    echo "This includes unit, integration, and external tests."
    echo
    
    # Run all tests without exclusions
    mix test --include external --include integration
    ;;
    
  fast)
    echo -e "${GREEN}Running fast tests only...${NC}"
    echo "Excludes slow, external, and integration tests."
    echo
    mix test
    ;;
    
  mcp)
    echo -e "${BLUE}Running MCP-specific tests...${NC}"
    echo "Testing Model Context Protocol functionality."
    echo
    mix test test/vsm_phoenix/mcp/
    ;;
    
  stdio)
    echo -e "${BLUE}Running stdio protocol tests...${NC}"
    echo "These test the actual MCP stdio interface."
    echo
    
    # Run the shell script tests
    cd scripts/mcp_tests
    ./test_vsm_mcp_core.sh
    cd ../..
    ;;
    
  *)
    echo -e "${RED}Invalid test mode: $TEST_MODE${NC}"
    echo
    echo "Usage: $0 [mode]"
    echo
    echo "Available modes:"
    echo "  unit        - Run only unit tests (default)"
    echo "  integration - Run integration tests (starts Phoenix)"
    echo "  external    - Run tests requiring external services"
    echo "  all         - Run all tests"
    echo "  fast        - Run only fast tests"
    echo "  mcp         - Run MCP-specific tests"
    echo "  stdio       - Run stdio protocol tests"
    exit 1
    ;;
esac

echo
echo -e "${GREEN}✅ Test run complete!${NC}"