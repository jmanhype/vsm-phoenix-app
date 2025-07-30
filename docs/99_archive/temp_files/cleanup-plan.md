# VSM Phoenix App - Cleanup Plan

## Current State: 108 files in root directory (way too many!)

## Files to Move/Organize:

### 1. Test Scripts → `test/scripts/`
- bulletproof_*.exs (6 files)
- test_*.exs (24 files)
- debug_*.exs
- trace_*.exs
- verify_*.exs
- simple_debug.exs
- ultimate_bulletproof_demo.exs
- live_proof_test.exs

### 2. Shell Scripts → `scripts/`
- *.sh files (20+ files)
- These are validation/proof scripts

### 3. Documentation → `docs/`
- All *.md files except README.md
- CYBERNETIC_HIVE_MIND_ARCHITECTURE.md
- ENGINEERING_FIXES_SUMMARY.md
- FINAL_MCP_INTEGRATION_REPORT.md
- VSM_HIVE_MIND_IMPLEMENTATION_COMPLETE.md
- etc.

### 4. Examples → `examples/`
- make_it_real.exs
- mcp_direct_demo.exs
- demonstrate_variety_acquisition.exs
- (already has some examples there)

### 5. MCP Server Scripts → `priv/mcp/`
- start_vsm_mcp_server.exs
- mcp_http_proxy.exs
- vsm_server.js

### 6. Files to Remove:
- *.txt log files (keep only essential ones)
- full_cascade_logs.txt
- live_logs.txt (unless actively used)
- vsm_live_logs.txt (unless actively used)
- Duplicate test files

### 7. Special Directories to Clean:
- `.magg/` - Check if needed
- `.swarm/` - Check if needed  
- `.hive-mind/` - Check if needed

### 8. Create Proper .gitignore:
```
# Dependencies
/deps
/_build
/node_modules

# Generated files
*.log
*.txt
.DS_Store

# Runtime files
/.magg
/.swarm
/.hive-mind

# IDE
.vscode/
.idea/

# Test artifacts
/test/reports/
/cover/

# Temporary files
*.tmp
*~
```

## Recommended Directory Structure:
```
vsm_phoenix_app/
├── README.md
├── mix.exs
├── mix.lock
├── .gitignore
├── .formatter.exs
├── assets/
├── config/
├── deps/
├── docs/
│   ├── architecture/
│   ├── api/
│   └── guides/
├── examples/
├── lib/
├── priv/
│   ├── mcp/
│   ├── repo/
│   └── static/
├── scripts/
│   ├── test/
│   └── validation/
└── test/
    ├── scripts/
    └── vsm_phoenix/
```