#!/bin/bash

# VSM Phoenix Server Startup Script
# Ensures all dependencies are running and starts the server with proper logging

set -e

echo "=== VSM Phoenix Server Startup Script ==="
echo "Starting at $(date)"

# Configuration
LOG_DIR="logs"
PID_FILE="vsm_phoenix.pid"
RABBITMQ_PID_FILE="rabbitmq.pid"

# Create logs directory
mkdir -p "$LOG_DIR"

# Function to check if a process is running
is_running() {
    if [ -f "$1" ]; then
        pid=$(cat "$1")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Stop existing processes
echo "Cleaning up existing processes..."
if is_running "$PID_FILE"; then
    echo "Stopping existing VSM Phoenix server (PID: $(cat $PID_FILE))..."
    kill -TERM $(cat "$PID_FILE") 2>/dev/null || true
    sleep 2
fi

# Kill any stray beam processes
pkill -f "beam.smp.*phx.server" 2>/dev/null || true
pkill -f "mix phx.server" 2>/dev/null || true

# Start RabbitMQ
echo "Starting RabbitMQ..."
rabbitmq-server -detached
echo $! > "$RABBITMQ_PID_FILE"
sleep 5

# Verify RabbitMQ is running
if ! rabbitmqctl status > /dev/null 2>&1; then
    echo "ERROR: RabbitMQ failed to start"
    exit 1
fi
echo "✓ RabbitMQ is running"

# Configure log file with timestamp
LOG_FILE="$LOG_DIR/vsm_phoenix_$(date +%Y%m%d_%H%M%S).log"
echo "Log file: $LOG_FILE"

# Load environment variables if .env file exists
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    export $(grep -v '^#' .env | xargs)
fi

# Start VSM Phoenix server
echo "Starting VSM Phoenix server..."
nohup mix phx.server > "$LOG_FILE" 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > "$PID_FILE"

# Wait and check if server started successfully
echo "Waiting for server to initialize..."
sleep 10

# Check if the process is still running
if ! ps -p $SERVER_PID > /dev/null 2>&1; then
    echo "ERROR: VSM Phoenix server failed to start"
    echo "Check log file for details: $LOG_FILE"
    tail -50 "$LOG_FILE"
    exit 1
fi

# Create a symlink to latest log
cd "$LOG_DIR" && ln -sf "$(basename "$LOG_FILE")" "vsm_phoenix_latest.log" && cd ..

echo "✓ VSM Phoenix server started successfully!"
echo "  PID: $SERVER_PID"
echo "  Log: $LOG_FILE"
echo "  Latest log symlink: $LOG_DIR/vsm_phoenix_latest.log"
echo ""
echo "Phase 2 Components Running:"
echo "  ✓ CRDT-based Context Persistence"
echo "  ✓ Cryptographic Security Layer"
echo "  ✓ Cortical Attention Engine"
echo "  ✓ Advanced aMCP Protocol Extensions"
echo "  ✓ Circuit Breakers & Resilience"
echo "  ✓ Analog-Signal Telemetry"
echo ""
echo "To monitor: tail -f $LOG_DIR/vsm_phoenix_latest.log"
echo "To stop: ./stop_vsm_server.sh"