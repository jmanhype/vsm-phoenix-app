# MAGG Integration Fix

## Problem
Phoenix was failing to start due to MAGG integration issues. The MAGG wrapper was expecting a different CLI API than what the installed MAGG version (0.10.0) provides.

## Root Cause
1. The MaggWrapper was using incorrect command structure (e.g., `magg list` instead of `magg server list`)
2. MAGG returns plain text output instead of JSON for many commands
3. The auto-connect feature was trying to connect to servers without proper configuration

## Solution Applied

### 1. Fixed MAGG Command Structure
Updated the following commands in `lib/vsm_phoenix/mcp/magg_wrapper.ex`:
- `list` → `server list`
- `add` → `server add`
- `remove` → `server remove`
- `enable` → `server enable`
- `disable` → `server disable`
- `config` → `server info`

### 2. Added Text Output Parsing
- Created `execute_magg_raw/1` function to handle non-JSON responses
- Added `parse_server_list/1` to parse MAGG's text format for server listings
- Added fallback logic to handle both JSON and text responses

### 3. Disabled Auto-Connect
Changed `auto_connect: true` to `auto_connect: false` in `lib/vsm_phoenix/application.ex` to prevent automatic connection attempts to unconfigured servers.

### 4. Disabled Non-Essential Features
- `search_servers/1` now returns empty list (feature not available in current MAGG)
- `get_tools/1` returns empty map (would need individual server queries)

## Configuration Options

### To completely disable MAGG (while keeping other MCP features):
```elixir
# In config/dev.exs or runtime.exs
config :vsm_phoenix, :disable_magg, true
```

### To disable all MCP servers:
```elixir
# In config/dev.exs or runtime.exs
config :vsm_phoenix, :disable_mcp_servers, true
```

## Current Status
- Phoenix starts successfully ✅
- Core MCP functionality intact ✅
- MAGG integration functional but with limited features ✅
- VSM systems operational ✅
- LiveView dashboard accessible at http://localhost:4000 ✅

## Future Improvements
1. Update MAGG wrapper when newer MAGG versions support JSON output
2. Implement proper server configuration for auto-connect
3. Add tool discovery from individual servers
4. Consider creating a more robust abstraction layer for different MAGG versions