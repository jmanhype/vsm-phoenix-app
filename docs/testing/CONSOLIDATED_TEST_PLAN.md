# Consolidated MCP Test Structure

## Recommended Test Organization

### 1. **test_vsm_mcp_core.sh**
Comprehensive testing of VSM MCP server functionality:
- Protocol compliance (initialize, tools/list)
- All VSM tools execution:
  - `vsm_scan_environment`
  - `vsm_synthesize_policy`
  - `vsm_spawn_meta_system`
  - `vsm_adapt_variety`
- All Hive tools execution:
  - `hive_discover_nodes`
  - `hive_propagate_pattern`
  - `hive_coordinate_swarm`
  - `hive_collective_decide`
- Response format validation
- Error handling

### 2. **test_external_integration.sh**
Testing variety acquisition through external MCP servers:
- Test multiple external servers:
  - `@modelcontextprotocol/server-filesystem`
  - `@modelcontextprotocol/server-everything-json`
  - Any other relevant servers
- Demonstrate variety gap detection
- Show capability integration
- Execute external tools through VSM
- Measure variety amplification

### 3. **test_tool_execution.sh**
Actual tool execution with real operations:
- Session management testing
- File operations (read, write, list)
- JSON operations (query, update)
- Combined VSM + external tool workflows
- Performance benchmarking
- Concurrent tool execution

### 4. **test_mcp_protocol.sh**
Protocol-level testing:
- Stdio communication
- Request/response format validation
- Error response handling
- Timeout behavior
- Large payload handling
- Protocol version negotiation

## Scripts to Remove/Merge

1. **Remove:**
   - `test_mcp_direct.sh` - Too minimal, covered by others
   - `test_mcp_stdio.sh` - Basic functionality covered elsewhere

2. **Merge:**
   - `bulletproof_proof.sh` + `prove_mcp_works.sh` → `test_vsm_mcp_core.sh`
   - `direct_mcp_proof.sh` + `prove_mcp_curl.sh` → `test_external_integration.sh`
   - Keep `test_mcp_tools_direct.sh` as basis for `test_tool_execution.sh`

## Additional Test Recommendations

### 1. **test_mcp_stress.sh**
- Concurrent requests
- Large-scale operations
- Memory usage monitoring
- Long-running operations

### 2. **test_mcp_security.sh**
- Input validation
- Path traversal prevention
- Resource limits
- Malformed request handling

### 3. **test_mcp_integration_ci.sh**
- Automated test suite for CI/CD
- JSON output for test runners
- Exit codes for pass/fail
- Test coverage reporting

## Test Utilities

Create a `test_utils.sh` with common functions:
```bash
# Initialize MCP server
init_mcp_server() { ... }

# Execute MCP request
execute_mcp_request() { ... }

# Validate JSON response
validate_json_response() { ... }

# Compare expected vs actual
assert_equals() { ... }
```

## Benefits of Consolidation

1. **Reduced Redundancy:** No duplicate tests across scripts
2. **Better Coverage:** Each script has a clear focus area
3. **Easier Maintenance:** Fewer scripts to update
4. **Clearer Purpose:** Each test file has a specific goal
5. **Better Organization:** Logical grouping of related tests
6. **Reusable Components:** Shared utilities reduce code duplication