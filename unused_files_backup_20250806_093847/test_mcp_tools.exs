#!/usr/bin/env elixir

# Test script to verify MCP tool names and execution

IO.puts("🔧 Testing MCP Filesystem Tools")

# The filesystem server actually uses these tool names:
tool_info = """
Correct tool names for @modelcontextprotocol/server-filesystem:

1. read_text_file (not read_file!)
   - path: string
   - head: optional number
   - tail: optional number

2. write_file
   - path: string  
   - content: string

3. list_directory
   - path: string

4. create_directory
   - path: string

5. get_file_info
   - path: string

Example curl commands:

# List tools (should show read_text_file, not read_file):
curl -X GET http://localhost:4000/api/vsm/agents/AGENT_ID/command \\
  -H "Content-Type: application/json" \\
  -d '{"type": "list_tools"}'

# Read a text file:
curl -X POST http://localhost:4000/api/vsm/agents/AGENT_ID/command \\
  -H "Content-Type: application/json" \\
  -d '{
    "type": "direct_tool",
    "tool": "read_text_file",
    "arguments": {"path": "/tmp/test.txt"}
  }'

# List directory:
curl -X POST http://localhost:4000/api/vsm/agents/AGENT_ID/command \\
  -H "Content-Type: application/json" \\
  -d '{
    "type": "direct_tool", 
    "tool": "list_directory",
    "arguments": {"path": "/tmp"}
  }'
"""

IO.puts(tool_info)

IO.puts("\n📝 The issue was using 'read_file' instead of 'read_text_file'!")
IO.puts("The MCP filesystem server has specific tool names that must be used exactly.")