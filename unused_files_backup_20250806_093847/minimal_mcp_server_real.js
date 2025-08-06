#!/usr/bin/env node

/**
 * REAL Minimal MCP Server Implementation
 * Based on how Hermes ACTUALLY handles MCP - as HTTP endpoints!
 * 
 * This is what we SHOULD have built instead of fake modules.
 */

const http = require('http');
const crypto = require('crypto');

class MinimalMCPServer {
  constructor(port = 3000) {
    this.port = port;
    this.sessions = new Map();
    this.tools = new Map();
    this.prompts = new Map();
    this.resources = new Map();
    
    // Register some example tools
    this.registerTool('uppercase', {
      description: 'Convert text to uppercase',
      inputSchema: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'Text to convert' }
        },
        required: ['text']
      }
    }, async (args) => {
      return args.text.toUpperCase();
    });

    this.registerTool('reverse', {
      description: 'Reverse text',
      inputSchema: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'Text to reverse' }
        },
        required: ['text']
      }
    }, async (args) => {
      return args.text.split('').reverse().join('');
    });
  }

  /**
   * Register a tool (following Hermes component pattern)
   */
  registerTool(name, schema, handler) {
    this.tools.set(name, { name, ...schema, handler });
  }

  /**
   * Handle JSON-RPC request (the REAL MCP way)
   */
  async handleRequest(request) {
    const { jsonrpc, method, params, id } = request;

    if (jsonrpc !== '2.0') {
      return {
        jsonrpc: '2.0',
        error: { code: -32600, message: 'Invalid Request' },
        id
      };
    }

    try {
      let result;

      switch (method) {
        case 'initialize':
          result = await this.handleInitialize(params);
          break;
        case 'notifications/initialized':
          // Just acknowledge
          return { jsonrpc: '2.0', result: {}, id };
        case 'tools/list':
          result = await this.handleToolsList();
          break;
        case 'tools/call':
          result = await this.handleToolCall(params);
          break;
        case 'prompts/list':
          result = { prompts: Array.from(this.prompts.values()) };
          break;
        case 'resources/list':
          result = { resources: Array.from(this.resources.values()) };
          break;
        default:
          throw new Error(`Method not found: ${method}`);
      }

      return { jsonrpc: '2.0', result, id };
    } catch (error) {
      return {
        jsonrpc: '2.0',
        error: { code: -32603, message: error.message },
        id
      };
    }
  }

  async handleInitialize(params) {
    const sessionId = `session_${crypto.randomBytes(16).toString('hex')}`;
    this.sessions.set(sessionId, {
      clientInfo: params.clientInfo,
      capabilities: params.capabilities,
      createdAt: new Date()
    });

    return {
      protocolVersion: '2025-06-18',
      capabilities: {},
      serverInfo: {
        name: 'minimal-mcp-server',
        version: '1.0.0'
      },
      sessionId
    };
  }

  async handleToolsList() {
    const tools = Array.from(this.tools.values()).map(({ handler, ...tool }) => tool);
    return { tools };
  }

  async handleToolCall(params) {
    const tool = this.tools.get(params.name);
    if (!tool) {
      throw new Error(`Tool not found: ${params.name}`);
    }

    const result = await tool.handler(params.arguments || {});
    return {
      content: [
        {
          type: 'text',
          text: String(result)
        }
      ]
    };
  }

  /**
   * Start HTTP server (like Hermes StreamableHTTP transport)
   */
  start() {
    const server = http.createServer(async (req, res) => {
      // CORS headers for browser compatibility
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, MCP-Protocol-Version, Mcp-Session-Id');

      if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
      }

      if (req.method !== 'POST' || req.url !== '/mcp') {
        res.writeHead(404);
        res.end(JSON.stringify({ error: 'Not found' }));
        return;
      }

      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', async () => {
        try {
          const request = JSON.parse(body);
          const response = await this.handleRequest(request);

          // Set session ID in response header if present
          const sessionId = response.result?.sessionId;
          if (sessionId) {
            res.setHeader('Mcp-Session-Id', sessionId);
          }

          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(response));
        } catch (error) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            jsonrpc: '2.0',
            error: { code: -32700, message: 'Parse error' }
          }));
        }
      });
    });

    server.listen(this.port, () => {
      console.log(`🚀 MCP Server running at http://localhost:${this.port}/mcp`);
      console.log('📋 Available endpoints:');
      console.log('   POST /mcp - MCP JSON-RPC endpoint');
      console.log('\n🔧 Available tools:');
      this.tools.forEach((tool, name) => {
        console.log(`   - ${name}: ${tool.description}`);
      });
    });

    return server;
  }
}

// Run server if called directly
if (require.main === module) {
  const server = new MinimalMCPServer(3001);
  server.start();
  
  console.log('\n💡 Test with:');
  console.log('   curl -X POST http://localhost:3001/mcp \\');
  console.log('     -H "Content-Type: application/json" \\');
  console.log('     -d \'{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"test","version":"1.0"}},"id":1}\'');
}

module.exports = MinimalMCPServer;