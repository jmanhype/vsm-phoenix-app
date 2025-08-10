# VSM Phoenix Server Management

## Quick Start

The VSM Phoenix server is now running in the background with all Phase 2 implementations active.

### Server Control Scripts

1. **Start Server**: `./start_vsm_server.sh`
   - Starts RabbitMQ
   - Starts VSM Phoenix with nohup
   - Creates timestamped log files
   - Saves PID for management

2. **Stop Server**: `./stop_vsm_server.sh`
   - Gracefully stops VSM Phoenix
   - Stops RabbitMQ
   - Cleans up processes

3. **Monitor Server**: `./monitor_vsm_server.sh`
   - Shows server status
   - Displays Phase 2 component health
   - Shows recent activity

### Current Status

- **Server PID**: 41423
- **RabbitMQ PID**: 41316
- **Log File**: `logs/vsm_phoenix_20250809_084519.log`
- **Latest Log**: `logs/vsm_phoenix_latest.log`

### Monitoring Commands

```bash
# View live logs
tail -f logs/vsm_phoenix_latest.log

# Check server status
./monitor_vsm_server.sh

# Check specific component logs
grep "CRDT" logs/vsm_phoenix_latest.log
grep "Security" logs/vsm_phoenix_latest.log
grep "Discovery" logs/vsm_phoenix_latest.log

# Check process
ps aux | grep $(cat vsm_phoenix.pid)
```

### Phase 2 Components Running

All Phase 2 implementations are active and integrated:

1. **CRDT-based Context Persistence**
   - Distributed state synchronization
   - No central coordination required
   - Automatic conflict resolution

2. **Cryptographic Security Layer**
   - AES-256-GCM encryption
   - Automatic key rotation
   - Replay attack protection

3. **Cortical Attention Engine**
   - Message prioritization
   - Attention-based routing
   - High-priority bypass

4. **Advanced aMCP Protocol Extensions**
   - Agent discovery service
   - Distributed consensus
   - Network optimization
   - Protocol integration

5. **Circuit Breakers & Resilience**
   - Fault isolation
   - Graceful degradation
   - Health monitoring

6. **Analog-Signal Telemetry**
   - Real-time metrics
   - System monitoring
   - Performance tracking

### Troubleshooting

If the server fails to start:

1. Check RabbitMQ: `rabbitmqctl status`
2. Check logs: `tail -100 logs/vsm_phoenix_latest.log`
3. Kill stray processes: `pkill -f beam.smp`
4. Restart: `./stop_vsm_server.sh && ./start_vsm_server.sh`

### API Endpoints

The server exposes the following endpoints:

- **Status**: `GET http://localhost:4000/api/vsm/status`
- **System Status**: `GET http://localhost:4000/api/vsm/system/:level`
- **Agent Management**: `POST/GET/DELETE http://localhost:4000/api/vsm/agents`

### Log Management

Logs are stored in the `logs/` directory with timestamps:
- Format: `vsm_phoenix_YYYYMMDD_HHMMSS.log`
- Symlink to latest: `vsm_phoenix_latest.log`

To rotate logs:
```bash
find logs/ -name "vsm_phoenix_*.log" -mtime +7 -delete
```

### Performance

The server is optimized for:
- Low latency CRDT operations
- High-throughput message processing
- Efficient cryptographic operations
- Resilient to failures

## Summary

The VSM Phoenix server is running persistently in the background with comprehensive logging and monitoring. All Phase 2 implementations are active and integrated, providing industrial-strength distributed systems capabilities.