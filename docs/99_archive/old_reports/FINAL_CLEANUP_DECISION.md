# Final Cleanup Decision

## Keep It Simple:

### ✅ KEEP:
- `bulletproof_proof.sh` - The ONLY test that actually tests the MCP stdio protocol
- `start_vsm_mcp_server.exs` - The actual MCP server
- Core Phoenix app (lib/, config/, assets/, etc.)

### ❌ DELETE:
- ALL other .sh files (they're redundant)
- ALL test_*.exs files in root
- ALL bulletproof_*.exs files (except the .sh)
- ALL documentation except README.md
- ALL log .txt files

### 📁 Final Structure:
```
vsm_phoenix_app/
├── README.md
├── mix.exs
├── mix.lock
├── .formatter.exs
├── .gitignore
├── bulletproof_proof.sh      # The ONE test that matters
├── start_vsm_mcp_server.exs  # The MCP server
├── assets/
├── config/
├── lib/
├── priv/
└── test/                     # Regular Phoenix tests
```

## Why This Works:

1. **Dog fooding**: `bulletproof_proof.sh` actually uses the MCP server via stdio
2. **Simple**: No complex test frameworks for something that's just JSON over stdio
3. **Honest**: It tests what Claude Code will actually use
4. **Fast**: Takes seconds to verify everything works

The existing tests in `test/vsm_phoenix/mcp/` can stay because they test internal modules, but they don't replace the need for `bulletproof_proof.sh` which tests the actual MCP protocol.