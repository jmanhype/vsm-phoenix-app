#!/bin/bash

# VSM Swarm Monitoring Script
# Checks all 5 swarms every 2 minutes and provides comprehensive status

SWARMS=("vsm_queen_swarm" "vsm_intelligence_swarm" "vsm_infra_swarm" "vsm_persistence_swarm" "vsm_resilience_swarm")
CHECK_INTERVAL=120  # 2 minutes in seconds
CHECK_COUNT=1

echo "🚨 VSM SWARM CONTINUOUS MONITORING STARTED"
echo "Checking every 2 minutes..."
echo "Press Ctrl+C to stop monitoring"
echo "=================================="

while true; do
    echo ""
    echo "🔍 VSM SWARM STATUS CHECK #$CHECK_COUNT - $(date)"
    echo "=================================================================="
    
    for swarm in "${SWARMS[@]}"; do
        echo ""
        echo "--- 📊 $swarm STATUS ---"
        
        # Check if session exists
        if tmux has-session -t "$swarm" 2>/dev/null; then
            # Get current activity line (last line with status)
            activity=$(tmux capture-pane -t "$swarm" -p | grep -E "(Brewing|Scheming|Spelunking|Envisioning|tokens)" | tail -1)
            
            # Get FULL pane content
            echo "FULL PANE CONTENT:"
            tmux capture-pane -t "$swarm" -p
            
            # Extract token count if available
            if [[ $activity =~ ([0-9]+\.?[0-9]*[k]?)\s+tokens ]]; then
                tokens="${BASH_REMATCH[1]}"
                echo "💡 Token Usage: $tokens"
            fi
            
            # Extract time if available
            if [[ $activity =~ ([0-9]+)s ]]; then
                time="${BASH_REMATCH[1]}s"
                echo "⏱️  Active Time: $time"
            fi
            
        else
            echo "❌ Session not found!"
        fi
        echo "----------------------------------------"
    done
    
    echo ""
    echo "✅ Status Check #$CHECK_COUNT Complete - Next check in 2 minutes"
    echo "=================================================================="
    
    ((CHECK_COUNT++))
    sleep $CHECK_INTERVAL
done
