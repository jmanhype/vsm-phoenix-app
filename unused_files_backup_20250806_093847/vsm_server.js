#!/usr/bin/env node
/**
 * VSM-Phoenix Simulation Server
 * Simulates the Viable Systems Model hierarchy with real-time dashboard
 */

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// VSM State Management
let vsmState = {
  system5: {
    status: 'active',
    viability_score: 85,
    policy_decisions: [],
    last_intervention: null
  },
  system4: {
    status: 'scanning',
    intelligence_reports: [],
    tidewave_connected: true,
    adaptations_proposed: 0
  },
  system3: {
    status: 'monitoring',
    resource_allocation: { cpu: 45, memory: 62, network: 33 },
    performance_metrics: { throughput: 1250, latency: 45 },
    conflicts_resolved: 3
  },
  system2: {
    status: 'coordinating',
    message_flow: 1847,
    oscillations_detected: 0,
    coordination_efficiency: 94
  },
  system1: {
    status: 'operational',
    active_contexts: 5,
    operations_completed: 2341,
    health_score: 92
  },
  algedonic: {
    pain_signals: 0,
    pleasure_signals: 12,
    escalations_today: 1
  }
};

// Serve static files
app.use(express.static('public'));
app.use(express.json());

// VSM Dashboard HTML
const dashboardHTML = `
<!DOCTYPE html>
<html>
<head>
    <title>VSM-Phoenix Dashboard</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 0; background: #1a1a1a; color: #fff; }
        .header { background: #ef4444; padding: 20px; text-align: center; }
        .systems-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; padding: 20px; }
        .system-card { background: #2a2a2a; border-radius: 8px; padding: 20px; border: 2px solid #444; }
        .system5 { border-color: #ef4444; }
        .system4 { border-color: #3b82f6; }
        .system3 { border-color: #10b981; }
        .system2 { border-color: #f59e0b; }
        .system1 { border-color: #8b5cf6; }
        .metric { margin: 10px 0; }
        .metric-label { font-weight: bold; color: #ccc; }
        .metric-value { font-size: 1.2em; color: #fff; }
        .status-active { color: #10b981; }
        .status-warning { color: #f59e0b; }
        .status-critical { color: #ef4444; }
        .algedonic { background: #1f2937; margin: 20px; padding: 20px; border-radius: 8px; }
        .real-time { font-size: 0.8em; color: #888; }
        .progress-bar { width: 100%; height: 10px; background: #444; border-radius: 5px; overflow: hidden; }
        .progress-fill { height: 100%; transition: width 0.3s ease; }
        .queen-crown { font-size: 2em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>👑 VSM-Phoenix Cybernetic Dashboard</h1>
        <p>Viable Systems Model - Real-time Monitoring</p>
    </div>
    
    <div class="systems-grid">
        <div class="system-card system5">
            <h2><span class="queen-crown">👑</span> System 5 - The Queen</h2>
            <div class="metric">
                <div class="metric-label">Status:</div>
                <div class="metric-value status-active" id="s5-status">Active</div>
            </div>
            <div class="metric">
                <div class="metric-label">Viability Score:</div>
                <div class="metric-value" id="s5-viability">85%</div>
                <div class="progress-bar">
                    <div class="progress-fill" id="s5-viability-bar" style="width: 85%; background: #ef4444;"></div>
                </div>
            </div>
            <div class="metric">
                <div class="metric-label">Policy Decisions Today:</div>
                <div class="metric-value" id="s5-decisions">3</div>
            </div>
        </div>
        
        <div class="system-card system4">
            <h2>🔍 System 4 - Intelligence</h2>
            <div class="metric">
                <div class="metric-label">Status:</div>
                <div class="metric-value status-active" id="s4-status">Scanning</div>
            </div>
            <div class="metric">
                <div class="metric-label">Tidewave Connection:</div>
                <div class="metric-value status-active" id="s4-tidewave">Connected</div>
            </div>
            <div class="metric">
                <div class="metric-label">Intelligence Reports:</div>
                <div class="metric-value" id="s4-reports">17</div>
            </div>
            <div class="metric">
                <div class="metric-label">Adaptations Proposed:</div>
                <div class="metric-value" id="s4-adaptations">5</div>
            </div>
        </div>
        
        <div class="system-card system3">
            <h2>🎯 System 3 - Control</h2>
            <div class="metric">
                <div class="metric-label">Resource Allocation:</div>
                <div>CPU: <span id="s3-cpu">45%</span></div>
                <div class="progress-bar">
                    <div class="progress-fill" id="s3-cpu-bar" style="width: 45%; background: #10b981;"></div>
                </div>
                <div>Memory: <span id="s3-memory">62%</span></div>
                <div class="progress-bar">
                    <div class="progress-fill" id="s3-memory-bar" style="width: 62%; background: #10b981;"></div>
                </div>
            </div>
            <div class="metric">
                <div class="metric-label">Performance:</div>
                <div class="metric-value" id="s3-performance">Optimal</div>
            </div>
        </div>
        
        <div class="system-card system2">
            <h2>🔄 System 2 - Coordination</h2>
            <div class="metric">
                <div class="metric-label">Message Flow:</div>
                <div class="metric-value" id="s2-messages">1,847/min</div>
            </div>
            <div class="metric">
                <div class="metric-label">Oscillations:</div>
                <div class="metric-value status-active" id="s2-oscillations">0 detected</div>
            </div>
            <div class="metric">
                <div class="metric-label">Coordination Efficiency:</div>
                <div class="metric-value" id="s2-efficiency">94%</div>
            </div>
        </div>
        
        <div class="system-card system1">
            <h2>⚙️ System 1 - Operations</h2>
            <div class="metric">
                <div class="metric-label">Active Contexts:</div>
                <div class="metric-value" id="s1-contexts">5</div>
            </div>
            <div class="metric">
                <div class="metric-label">Operations Completed:</div>
                <div class="metric-value" id="s1-operations">2,341</div>
            </div>
            <div class="metric">
                <div class="metric-label">Health Score:</div>
                <div class="metric-value status-active" id="s1-health">92%</div>
            </div>
        </div>
    </div>
    
    <div class="algedonic">
        <h2>⚡ Algedonic Channels</h2>
        <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px;">
            <div>
                <div class="metric-label">Pain Signals:</div>
                <div class="metric-value status-active" id="pain-signals">0</div>
            </div>
            <div>
                <div class="metric-label">Pleasure Signals:</div>
                <div class="metric-value status-active" id="pleasure-signals">12</div>
            </div>
            <div>
                <div class="metric-label">Escalations Today:</div>
                <div class="metric-value" id="escalations">1</div>
            </div>
        </div>
    </div>
    
    <div style="text-align: center; padding: 20px; color: #666;">
        <div class="real-time">Last updated: <span id="last-update">--</span></div>
        <div class="real-time">VSM-Phoenix v1.0.0 | WebSocket: <span id="ws-status">Connecting...</span></div>
    </div>

    <script>
        const ws = new WebSocket('ws://localhost:4000');
        
        ws.onopen = function() {
            document.getElementById('ws-status').textContent = 'Connected';
            document.getElementById('ws-status').className = 'status-active';
        };
        
        ws.onmessage = function(event) {
            const data = JSON.parse(event.data);
            updateDashboard(data);
            document.getElementById('last-update').textContent = new Date().toLocaleTimeString();
        };
        
        function updateDashboard(state) {
            // System 5
            document.getElementById('s5-viability').textContent = state.system5.viability_score + '%';
            document.getElementById('s5-viability-bar').style.width = state.system5.viability_score + '%';
            
            // System 4
            document.getElementById('s4-reports').textContent = state.system4.intelligence_reports.length;
            document.getElementById('s4-adaptations').textContent = state.system4.adaptations_proposed;
            
            // System 3
            document.getElementById('s3-cpu').textContent = state.system3.resource_allocation.cpu + '%';
            document.getElementById('s3-cpu-bar').style.width = state.system3.resource_allocation.cpu + '%';
            document.getElementById('s3-memory').textContent = state.system3.resource_allocation.memory + '%';
            document.getElementById('s3-memory-bar').style.width = state.system3.resource_allocation.memory + '%';
            
            // System 2
            document.getElementById('s2-messages').textContent = state.system2.message_flow.toLocaleString() + '/min';
            document.getElementById('s2-efficiency').textContent = state.system2.coordination_efficiency + '%';
            
            // System 1
            document.getElementById('s1-contexts').textContent = state.system1.active_contexts;
            document.getElementById('s1-operations').textContent = state.system1.operations_completed.toLocaleString();
            
            // Algedonic
            document.getElementById('pain-signals').textContent = state.algedonic.pain_signals;
            document.getElementById('pleasure-signals').textContent = state.algedonic.pleasure_signals;
            document.getElementById('escalations').textContent = state.algedonic.escalations_today;
        }
    </script>
</body>
</html>
`;

// Routes
app.get('/', (req, res) => {
    res.send(dashboardHTML);
});

app.get('/api/vsm/status', (req, res) => {
    res.json(vsmState);
});

app.post('/api/vsm/system5/decision', (req, res) => {
    const decision = {
        id: Date.now(),
        policy: req.body.policy,
        timestamp: new Date().toISOString(),
        authority: 'queen'
    };
    vsmState.system5.policy_decisions.push(decision);
    broadcast({ type: 'system5_decision', decision });
    res.json({ success: true, decision });
});

// WebSocket connections
const clients = new Set();

wss.on('connection', (ws) => {
    clients.add(ws);
    ws.send(JSON.stringify(vsmState));
    
    ws.on('close', () => {
        clients.delete(ws);
    });
});

function broadcast(data) {
    const message = JSON.stringify(data);
    clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}

// Simulate VSM activity
setInterval(() => {
    // Update metrics with realistic variations
    vsmState.system3.resource_allocation.cpu = Math.max(20, Math.min(80, 
        vsmState.system3.resource_allocation.cpu + (Math.random() - 0.5) * 10));
    vsmState.system3.resource_allocation.memory = Math.max(30, Math.min(90, 
        vsmState.system3.resource_allocation.memory + (Math.random() - 0.5) * 8));
    
    vsmState.system2.message_flow += Math.floor((Math.random() - 0.5) * 100);
    vsmState.system1.operations_completed += Math.floor(Math.random() * 5);
    
    vsmState.system5.viability_score = Math.max(70, Math.min(100, 
        vsmState.system5.viability_score + (Math.random() - 0.5) * 3));
    
    // Broadcast updates
    broadcast(vsmState);
}, 2000);

// Start server
const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
    console.log('🐝 VSM-Phoenix Dashboard Server Starting...');
    console.log('👑 System 5 Queen: Policy governance active');
    console.log('🔍 System 4 Intelligence: Environmental scanning enabled');
    console.log('🎯 System 3 Control: Resource allocation optimized');
    console.log('🔄 System 2 Coordination: Message flow coordinated');
    console.log('⚙️ System 1 Operations: Autonomous contexts running');
    console.log('⚡ Algedonic Channels: Pain/pleasure signals active');
    console.log('🌊 Tidewave Integration: Runtime intelligence connected');
    console.log('');
    console.log(`📊 Dashboard available at: http://localhost:${PORT}`);
    console.log('🚀 VSM-Phoenix Cybernetic System Online!');
});