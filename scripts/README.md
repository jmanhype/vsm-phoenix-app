# VSM Phoenix Test Scripts

This directory contains consolidated test scripts for the VSM Phoenix application.

## Directory Structure

```
scripts/
├── mcp_tests/      # MCP protocol and tool testing
├── demos/          # System demonstrations and integration tests
└── README.md       # This file
```

## MCP Tests (`mcp_tests/`)

### Core Test Suite
- **`test_vsm_mcp_core.sh`** - Primary MCP test suite
  - Tests all VSM tools (scan, viability, policy, spawn)
  - Tests all Hive tools (discover, route, coordinate)
  - Full stdio protocol compliance testing
  - Replaces: bulletproof_proof.sh, prove_mcp_works.sh, test_mcp_direct.sh

### External Integration
- **`test_external_integration.sh`** - External MCP server testing
  - NPM package availability
  - Filesystem/SQLite server integration
  - Variety acquisition testing
  - Replaces: validate_mcp_integration.sh, verify_mcp_npm.sh

### Legacy Tests (kept for reference)
- Various other `.sh` scripts testing specific MCP functionality
- Most functionality is now in the consolidated scripts above

## System Demos (`demos/`)

### Primary Test Suites

1. **`vsm_test_suite.sh`** - Comprehensive VSM testing
   ```bash
   ./vsm_test_suite.sh {cascade|health|api|reality|all}
   ```
   - `cascade`: Test full S1→S5→S1 signal flow
   - `health`: System health and operational status
   - `api`: Test all VSM API endpoints
   - `reality`: Reality check on actual vs claimed capabilities
   - `all`: Run all tests in sequence

2. **`variety_acquisition_demo.exs`** - Variety acquisition demonstration
   ```bash
   ./variety_acquisition_demo.exs [--mode simple|live|full]
   ```
   - `simple`: Basic conceptual demo (default)
   - `live`: Interactive step-by-step walkthrough
   - `full`: Complete demo with real MCP integration

3. **`test_vsm_systems.exs`** - Direct system verification
   ```bash
   ./test_vsm_systems.exs [all|s1|s2|s3|s4|s5]
   ```
   - Tests each VSM system's GenServer directly
   - Verifies actual data is returned
   - Can test individual systems or all at once

### Specialized Tests
- **`test_bulletproof_supervisor.exs`** - Supervisor isolation testing
  - Shows fault tolerance and graceful degradation
  - Demonstrates how system survives component failures

## Running Tests

### Prerequisites
1. Start Phoenix application: `mix phx.server`
2. Ensure PostgreSQL is running
3. For MCP tests, ensure `start_vsm_mcp_server.exs` is available

### Quick Test Everything
```bash
# Test MCP functionality
cd scripts/mcp_tests
./test_vsm_mcp_core.sh

# Test system health and integration
cd scripts/demos
./vsm_test_suite.sh all

# Test variety acquisition
./variety_acquisition_demo.exs --mode full
```

### CI/CD Integration
The consolidated test scripts return proper exit codes:
- 0 = all tests passed
- 1 = one or more tests failed

Example GitHub Actions workflow:
```yaml
- name: Run VSM Tests
  run: |
    cd scripts/mcp_tests
    ./test_vsm_mcp_core.sh
    cd ../demos
    ./vsm_test_suite.sh all
```

## Test Coverage

| Component | Test Script | Coverage |
|-----------|------------|----------|
| MCP Protocol | test_vsm_mcp_core.sh | ✅ Full |
| VSM Tools | test_vsm_mcp_core.sh | ✅ Full |
| Hive Tools | test_vsm_mcp_core.sh | ✅ Full |
| System Health | vsm_test_suite.sh | ✅ Full |
| API Endpoints | vsm_test_suite.sh | ⚠️ Partial |
| Variety Acquisition | variety_acquisition_demo.exs | ✅ Full |
| GenServer Operations | test_vsm_systems.exs | ✅ Full |
| Supervisor Isolation | test_bulletproof_supervisor.exs | ✅ Full |

## Maintenance Notes

1. **Consolidation**: These scripts consolidate ~50 individual test files into 7 focused test suites
2. **Duplication**: Eliminated redundant tests while maintaining full coverage
3. **Extensibility**: Each script is designed to be easily extended with new tests
4. **Documentation**: Each script includes inline documentation and usage instructions