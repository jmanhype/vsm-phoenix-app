#!/bin/bash

# VSM Phoenix Server Stop Script

echo "=== VSM Phoenix Server Shutdown Script ==="
echo "Stopping at $(date)"

PID_FILE="vsm_phoenix.pid"
RABBITMQ_PID_FILE="rabbitmq.pid"

# Function to stop a process gracefully
stop_process() {
    local pid_file=$1
    local name=$2
    
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Stopping $name (PID: $pid)..."
            kill -TERM "$pid"
            
            # Wait up to 10 seconds for graceful shutdown
            for i in {1..10}; do
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    echo "✓ $name stopped gracefully"
                    rm -f "$pid_file"
                    return 0
                fi
                sleep 1
            done
            
            # Force kill if still running
            echo "Force killing $name..."
            kill -9 "$pid" 2>/dev/null || true
            rm -f "$pid_file"
        else
            echo "$name is not running (stale PID file)"
            rm -f "$pid_file"
        fi
    else
        echo "$name PID file not found"
    fi
}

# Stop VSM Phoenix server
stop_process "$PID_FILE" "VSM Phoenix server"

# Stop any remaining Phoenix processes
pkill -f "beam.smp.*phx.server" 2>/dev/null || true
pkill -f "mix phx.server" 2>/dev/null || true

# Stop RabbitMQ
echo "Stopping RabbitMQ..."
rabbitmqctl stop 2>/dev/null || true
sleep 2

# Clean up any remaining beam processes
pkill -f "beam.smp" 2>/dev/null || true

echo "✓ All VSM services stopped"