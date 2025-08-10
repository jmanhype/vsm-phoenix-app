#!/bin/bash

# VSM Phoenix Server Monitoring Script

PID_FILE="vsm_phoenix.pid"
LOG_FILE="logs/vsm_phoenix_latest.log"

echo "=== VSM Phoenix Server Monitor ==="
echo "Time: $(date)"
echo ""

# Check if server is running
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "✓ VSM Phoenix server is running (PID: $pid)"
        
        # Get process info
        ps aux | grep "$pid" | grep -v grep | head -1
        echo ""
        
        # Check RabbitMQ
        if rabbitmqctl status > /dev/null 2>&1; then
            echo "✓ RabbitMQ is running"
            rabbitmq_pid=$(rabbitmqctl eval 'os:getpid().' 2>/dev/null | tr -d '"')
            echo "  PID: $rabbitmq_pid"
        else
            echo "✗ RabbitMQ is not running"
        fi
        echo ""
        
        # Show Phase 2 component status from logs
        echo "Phase 2 Components Status:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check for CRDT
        if grep -q "CRDT AMQP synchronization established" "$LOG_FILE" 2>/dev/null; then
            echo "✓ CRDT Context Persistence - Active"
            crdt_count=$(grep -c "CRDT sync" "$LOG_FILE" 2>/dev/null || echo "0")
            echo "  Sync operations: $crdt_count"
        else
            echo "? CRDT Context Persistence - Unknown"
        fi
        
        # Check for Security
        if grep -q "Initializing Enhanced Crypto Layer" "$LOG_FILE" 2>/dev/null; then
            echo "✓ Cryptographic Security Layer - Active"
            crypto_ops=$(grep -c "encrypt\|decrypt" "$LOG_FILE" 2>/dev/null || echo "0")
            echo "  Crypto operations: $crypto_ops"
        else
            echo "? Cryptographic Security Layer - Unknown"
        fi
        
        # Check for Cortical Attention Engine
        if grep -q "Cortical Attention-Engine initializing" "$LOG_FILE" 2>/dev/null; then
            echo "✓ Cortical Attention Engine - Active"
        else
            echo "? Cortical Attention Engine - Unknown"
        fi
        
        # Check for aMCP Extensions
        if grep -q "Discovery: Initializing agent discovery protocol" "$LOG_FILE" 2>/dev/null; then
            echo "✓ Advanced aMCP Extensions - Active"
            echo "  - Discovery Service"
            echo "  - Consensus Protocol"
            echo "  - Network Optimizer"
            echo "  - Protocol Integration"
        else
            echo "? Advanced aMCP Extensions - Unknown"
        fi
        
        # Check for Resilience
        if grep -q "Starting VSM Resilience Supervisor" "$LOG_FILE" 2>/dev/null; then
            echo "✓ Circuit Breakers & Resilience - Active"
        else
            echo "? Circuit Breakers & Resilience - Unknown"
        fi
        
        echo ""
        echo "Recent Activity (last 10 lines):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        tail -10 "$LOG_FILE" 2>/dev/null | grep -v "Discovery: Unknown message type"
        
    else
        echo "✗ VSM Phoenix server is not running (PID $pid not found)"
    fi
else
    echo "✗ VSM Phoenix server is not running (no PID file)"
fi

echo ""
echo "Log file: $LOG_FILE"
echo "To view live logs: tail -f $LOG_FILE"