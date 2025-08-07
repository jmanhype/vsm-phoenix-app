defmodule VsmPhoenixWeb.TelegramTestController do
  @moduledoc """
  Test controller for Telegram bot integration
  """
  use VsmPhoenixWeb, :controller
  
  def test(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>VSM Telegram Bot Test</title>
      <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .container { background: #f5f5f5; padding: 20px; border-radius: 8px; }
        h1 { color: #333; }
        .status { padding: 10px; margin: 10px 0; border-radius: 4px; }
        .status.success { background: #d4edda; color: #155724; }
        .status.error { background: #f8d7da; color: #721c24; }
        .bot-info { background: #d1ecf1; color: #0c5460; padding: 10px; border-radius: 4px; margin: 10px 0; }
        .test-section { margin: 20px 0; padding: 15px; background: white; border-radius: 4px; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .log { background: #f8f9fa; padding: 10px; font-family: monospace; font-size: 12px; max-height: 300px; overflow-y: auto; }
        .agent-list { display: flex; gap: 10px; flex-wrap: wrap; }
        .agent { background: #e9ecef; padding: 5px 10px; border-radius: 4px; }
        .agent.llm { background: #d4edda; }
        .agent.telegram { background: #cce5ff; }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>🤖 VSM Telegram Bot Test Interface</h1>
        
        <div class="bot-info">
          <strong>Bot Username:</strong> @VaoAssitantBot<br>
          <strong>Bot Link:</strong> <a href="https://t.me/VaoAssitantBot" target="_blank">https://t.me/VaoAssitantBot</a>
        </div>
        
        <div class="test-section">
          <h2>System Status</h2>
          <div id="system-status">Loading...</div>
        </div>
        
        <div class="test-section">
          <h2>Active Agents</h2>
          <div id="agents" class="agent-list">Loading...</div>
        </div>
        
        <div class="test-section">
          <h2>Test Instructions</h2>
          <ol>
            <li>Open Telegram and search for <strong>@VaoAssitantBot</strong></li>
            <li>Start a conversation by clicking "Start" or sending "/start"</li>
            <li>Send test messages like:
              <ul>
                <li>"Hello"</li>
                <li>"What is the system status?"</li>
                <li>"Show me active agents"</li>
                <li>"Help"</li>
              </ul>
            </li>
            <li>The bot should respond with relevant information</li>
          </ol>
        </div>
        
        <div class="test-section">
          <h2>Recent Activity</h2>
          <button onclick="refreshLogs()">Refresh Logs</button>
          <div id="logs" class="log">Loading...</div>
        </div>
      </div>
      
      <script>
        async function loadStatus() {
          try {
            const response = await fetch('/api/vsm/status');
            const data = await response.json();
            document.getElementById('system-status').innerHTML = `
              <div class="status success">
                <strong>Health:</strong> ${data.system_health.overall_status}<br>
                <strong>Variety Balance:</strong> ${data.variety_balance.status}<br>
                <strong>Active Contexts:</strong> ${data.active_contexts}
              </div>
            `;
          } catch (error) {
            document.getElementById('system-status').innerHTML = `
              <div class="status error">Error loading status: ${error.message}</div>
            `;
          }
        }
        
        async function loadAgents() {
          try {
            const response = await fetch('/api/vsm/agents');
            const data = await response.json();
            const agents = data.agents.map(agent => {
              const className = agent.type === 'llm_worker' ? 'agent llm' : 
                               agent.type === 'telegram' ? 'agent telegram' : 'agent';
              return `<div class="${className}">${agent.type}: ${agent.id}</div>`;
            }).join('');
            document.getElementById('agents').innerHTML = agents || 'No agents active';
          } catch (error) {
            document.getElementById('agents').innerHTML = `
              <div class="status error">Error loading agents: ${error.message}</div>
            `;
          }
        }
        
        async function loadLogs() {
          try {
            const response = await fetch('/api/vsm/telegram/recent_activity');
            const data = await response.json();
            document.getElementById('logs').innerHTML = data.activity.join('\\n') || 'No recent activity';
          } catch (error) {
            document.getElementById('logs').innerHTML = 'Error loading logs';
          }
        }
        
        function refreshLogs() {
          loadLogs();
        }
        
        // Load data on page load
        loadStatus();
        loadAgents();
        loadLogs();
        
        // Auto-refresh logs every 5 seconds
        setInterval(loadLogs, 5000);
      </script>
    </body>
    </html>
    """)
  end
  
  def recent_activity(conn, _params) do
    # Get recent Telegram activity from logs
    {:ok, content} = File.read(Path.join([File.cwd!(), "logs", "vsm_phoenix.log"]))
    
    lines = content
    |> String.split("\n")
    |> Enum.take(-100)  # Last 100 lines
    |> Enum.filter(fn line -> 
      String.contains?(line, ["Telegram", "LLM", "Processing message", "Published", "conversation"])
    end)
    |> Enum.take(-20)  # Last 20 relevant lines
    
    json(conn, %{activity: lines})
  end
end