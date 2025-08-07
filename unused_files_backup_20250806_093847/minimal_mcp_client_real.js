#!/usr/bin/env node

/**
 * REAL Minimal MCP Client for Hermes
 * Based on ACTUAL k6 test patterns - NO fake modules!
 */

const http = require('http');
const https = require('https');

class MinimalMCPClient {
  constructor(baseUrl = 'http://localhost:3001') {
    this.baseUrl = baseUrl;
    this.mcpEndpoint = `${baseUrl}/mcp`;
    this.sessionId = null;
    this.protocolVersion = '2025-06-18';
  }

  /**
   * Make HTTP request to MCP endpoint
   * This is how Hermes ACTUALLY works - no SDK needed!
   */
  async request(method, params = {}) {
    const requestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    const payload = JSON.stringify({
      jsonrpc: '2.0',
      method,
      params,
      id: requestId
    });

    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      'MCP-Protocol-Version': this.protocolVersion
    };

    if (this.sessionId) {
      headers['Mcp-Session-Id'] = this.sessionId;
    }

    return new Promise((resolve, reject) => {
      const url = new URL(this.mcpEndpoint);
      const client = url.protocol === 'https:' ? https : http;

      const req = client.request({
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: 'POST',
        headers
      }, (res) => {
        let data = '';

        // Capture session ID from headers
        if (res.headers['mcp-session-id']) {
          this.sessionId = res.headers['mcp-session-id'];
        }

        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const response = JSON.parse(data);
            if (response.error) {
              reject(new Error(`MCP Error: ${response.error.message}`));
            } else {
              resolve(response.result);
            }
          } catch (e) {
            reject(new Error(`Invalid response: ${data}`));
          }
        });
      });

      req.on('error', reject);
      req.write(payload);
      req.end();
    });
  }

  /**
   * Initialize MCP session
   */
  async initialize(clientInfo = {}) {
    const result = await this.request('initialize', {
      protocolVersion: this.protocolVersion,
      clientInfo: {
        name: clientInfo.name || 'minimal-mcp-client',
        version: clientInfo.version || '1.0.0'
      },
      capabilities: {}
    });

    // Send initialized notification
    await this.request('notifications/initialized', {});
    
    return result;
  }

  /**
   * Call a tool
   */
  async callTool(name, args = {}) {
    return this.request('tools/call', {
      name,
      arguments: args
    });
  }

  /**
   * List available tools
   */
  async listTools() {
    return this.request('tools/list', {});
  }

  /**
   * Get a prompt
   */
  async getPrompt(name, args = {}) {
    return this.request('prompts/get', {
      name,
      arguments: args
    });
  }

  /**
   * List available prompts
   */
  async listPrompts() {
    return this.request('prompts/list', {});
  }

  /**
   * Read a resource
   */
  async readResource(uri) {
    return this.request('resources/read', { uri });
  }

  /**
   * List available resources
   */
  async listResources() {
    return this.request('resources/list', {});
  }
}

// Example usage matching k6 test patterns
async function main() {
  const client = new MinimalMCPClient();

  try {
    console.log('🚀 Initializing MCP client (the REAL way - just HTTP!)...');
    const initResult = await client.initialize({
      name: 'hermes-minimal-client',
      version: '1.0.0'
    });
    console.log('✅ Initialized:', initResult);

    console.log('\n📋 Listing available tools...');
    const tools = await client.listTools();
    console.log('Available tools:', tools);

    // Example: Call uppercase tool
    console.log('\n🔧 Calling uppercase tool...');
    try {
      const result = await client.callTool('uppercase', {
        text: 'hello from real mcp'
      });
      console.log('Uppercase result:', result);
    } catch (e) {
      console.log('Error:', e.message);
    }

    // Example: Call reverse tool
    console.log('\n🔧 Calling reverse tool...');
    try {
      const result = await client.callTool('reverse', {
        text: 'reality-based'
      });
      console.log('Reverse result:', result);
    } catch (e) {
      console.log('Error:', e.message);
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Export for use as module
module.exports = MinimalMCPClient;

// Run if called directly
if (require.main === module) {
  main();
}