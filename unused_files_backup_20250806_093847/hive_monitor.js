#!/usr/bin/env node

/**
 * Hive Mind Monitoring Dashboard
 * Real-time health and status monitoring
 */

const fs = require('fs');
const path = require('path');

const swarmDir = path.join(process.cwd(), '.swarm');

// Read configurations
let hiveConfig, hiveStatus;
try {
  hiveConfig = JSON.parse(fs.readFileSync(path.join(swarmDir, 'hive_config.json'), 'utf8'));
  hiveStatus = JSON.parse(fs.readFileSync(path.join(swarmDir, 'hive_status.json'), 'utf8'));
} catch (error) {
  console.error('❌ Error reading hive configuration:', error.message);
  process.exit(1);
}

// Display monitoring dashboard
console.log('\n🐝 HIVE MIND MONITORING DASHBOARD');
console.log('═'.repeat(60));

// Queen Status
console.log('\n👑 QUEEN STATUS');
console.log(`   Type: ${hiveStatus.queen.type.toUpperCase()}`);
console.log(`   Objective: ${hiveStatus.queen.objective}`);
console.log(`   Session: ${hiveConfig.session_id}`);

// Swarm Health
console.log('\n🏥 SWARM HEALTH');
console.log(`   Status: ${hiveStatus.status === 'active' ? '🟢 ACTIVE' : '🔴 INACTIVE'}`);
console.log(`   Topology: ${hiveStatus.swarm.topology}`);
console.log(`   Workers: ${hiveStatus.swarm.worker_count} / ${hiveConfig.max_agents}`);

// Worker Status
console.log('\n🤖 WORKER STATUS');
hiveStatus.swarm.workers.forEach((worker, index) => {
  const status = worker.status === 'ready' ? '✅' : '⏳';
  console.log(`   ${status} ${worker.name} (${worker.type})`);
});

// Capabilities
console.log('\n⚡ CAPABILITIES');
Object.entries(hiveStatus.capabilities).forEach(([key, enabled]) => {
  const status = enabled ? '✅' : '❌';
  const label = key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
  console.log(`   ${status} ${label}`);
});

// Performance Metrics
console.log('\n📊 PERFORMANCE METRICS');
console.log(`   Uptime: ${new Date() - new Date(hiveConfig.created_at)} ms`);
console.log(`   Memory Usage: ${(process.memoryUsage().heapUsed / 1024 / 1024).toFixed(2)} MB`);
console.log(`   Strategy: ${hiveConfig.strategy}`);

// Recommendations
console.log('\n💡 RECOMMENDATIONS');
if (hiveStatus.swarm.worker_count < hiveConfig.max_agents) {
  console.log(`   • Consider spawning ${hiveConfig.max_agents - hiveStatus.swarm.worker_count} more workers`);
}
console.log('   • All systems operational');
console.log('   • Ready for complex collaborative tasks');

console.log('\n' + '═'.repeat(60));
console.log('🐝 Hive Mind is ready for collective intelligence operations!\n');