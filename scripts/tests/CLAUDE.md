# Scripts/Tests Directory

Validation and testing scripts for VSM Phoenix components.

## Files in this directory:

### Core Validation
- `honest_test.sh` - Basic functionality validation
- `comprehensive_vsm_proof.sh` - Full VSM system validation
- `validate_vsm_api.sh` - API endpoint testing

### MCP Testing
- `test_mcp_direct.sh` - Direct MCP protocol tests
- `test_mcp_stdio.sh` - STDIO transport tests
- `prove_mcp_works.sh` - MCP functionality proof
- `prove_mcp_curl.sh` - MCP via curl testing
- `direct_mcp_proof.sh` - Direct protocol validation
- `test_mcp_tools_direct.sh` - MCP tools testing
- `validate_mcp_integration.sh` - Full MCP integration
- `verify_mcp_npm.sh` - NPM package verification
- `vsm_tool_execution.sh` - VSM tool execution tests

### System Testing
- `bulletproof_proof.sh` - Bulletproof mode validation
- `bulletproof_simple_test.exs` - Simple bulletproof tests
- `cascade_proof.sh` - Cascade failure testing
- `test_vsm_systems.exs` - System hierarchy tests
- `test_dashboard_data.exs` - Dashboard data validation

### Integration Testing
- `test_external_integration.sh` - External service tests
- `test_vsm_cybernetic_acquisition.exs` - Acquisition tests
- `test_vsm_variety_acquisition_live.exs` - Live variety tests

## Purpose:
Comprehensive test scripts that validate:
- Core VSM functionality
- MCP protocol implementation
- System resilience
- External integrations
- Performance characteristics

## Running Tests:
```bash
# Run comprehensive validation
./comprehensive_vsm_proof.sh

# Test specific components
./test_mcp_direct.sh
./validate_vsm_api.sh

# Bulletproof testing
./bulletproof_proof.sh
```