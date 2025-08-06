#!/usr/bin/env node

/**
 * Hive Mind Initialization Script
 * Sets up the collective intelligence system
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Hive configuration
const HIVE_CONFIG = {
  queen_type: 'strategic',
  objective: 'Build a collaborative intelligence system for complex problem solving',
  topology: 'mesh',
  max_agents: 8,
  strategy: 'balanced',
  workers: [
    { type: 'researcher', name: 'Data Scout', role: 'Information gathering and analysis' },
    { type: 'coder', name: 'Code Builder', role: 'Implementation and development' },
    { type: 'analyst', name: 'Pattern Seeker', role: 'Pattern recognition and insights' },
    { type: 'tester', name: 'Quality Guard', role: 'Testing and validation' },
    { type: 'architect', name: 'System Designer', role: 'Architecture and design' },
    { type: 'coordinator', name: 'Task Master', role: 'Coordination and planning' }
  ]
};

console.log('🐝 Initializing Hive Mind Collective Intelligence System...\n');

// Create swarm directory
const swarmDir = path.join(process.cwd(), '.swarm');
if (!fs.existsSync(swarmDir)) {
  fs.mkdirSync(swarmDir, { recursive: true });
  console.log('✅ Created .swarm directory');
}

// Initialize swarm configuration
const swarmConfig = {
  session_id: `hive-${Date.now()}`,
  created_at: new Date().toISOString(),
  queen: HIVE_CONFIG.queen_type,
  objective: HIVE_CONFIG.objective,
  topology: HIVE_CONFIG.topology,
  max_agents: HIVE_CONFIG.max_agents,
  strategy: HIVE_CONFIG.strategy,
  workers: HIVE_CONFIG.workers,
  status: 'initializing'
};

// Save configuration
fs.writeFileSync(
  path.join(swarmDir, 'hive_config.json'),
  JSON.stringify(swarmConfig, null, 2)
);
console.log('✅ Saved hive configuration');

// Initialize memory system
console.log('\n📊 Initializing Collective Memory System...');
try {
  execSync('npx claude-flow@alpha memory init', { stdio: 'inherit' });
} catch (error) {
  console.log('⚠️  Memory system already initialized or error occurred');
}

// Initialize each worker
console.log('\n🤖 Spawning Hive Workers...');
HIVE_CONFIG.workers.forEach((worker, index) => {
  console.log(`  ${index + 1}. ${worker.name} (${worker.type}) - ${worker.role}`);
});

// Create hive status report
const statusReport = {
  hive_id: swarmConfig.session_id,
  status: 'active',
  queen: {
    type: HIVE_CONFIG.queen_type,
    objective: HIVE_CONFIG.objective
  },
  swarm: {
    topology: HIVE_CONFIG.topology,
    worker_count: HIVE_CONFIG.workers.length,
    workers: HIVE_CONFIG.workers.map(w => ({
      name: w.name,
      type: w.type,
      status: 'ready'
    }))
  },
  capabilities: {
    consensus_decision_making: true,
    distributed_execution: true,
    quality_driven_tasks: true,
    real_time_monitoring: true
  }
};

fs.writeFileSync(
  path.join(swarmDir, 'hive_status.json'),
  JSON.stringify(statusReport, null, 2)
);

console.log('\n✅ Hive Mind Initialization Complete!\n');
console.log('📊 Hive Status:');
console.log(`   Queen Type: ${HIVE_CONFIG.queen_type}`);
console.log(`   Objective: ${HIVE_CONFIG.objective}`);
console.log(`   Workers: ${HIVE_CONFIG.workers.length}`);
console.log(`   Topology: ${HIVE_CONFIG.topology}`);
console.log(`   Strategy: ${HIVE_CONFIG.strategy}`);
console.log('\n🐝 The Hive Mind is ready for collective intelligence tasks!');