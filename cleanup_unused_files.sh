#!/bin/bash

# VSM Phoenix Unused Files Cleanup Script
# Generated after thorough analysis - removes only 100% confirmed unused files

echo "🧹 VSM Phoenix Cleanup Script"
echo "This will remove all confirmed unused files."
echo "Press Ctrl+C to abort, or Enter to continue..."
read

# Create backup directory with timestamp
BACKUP_DIR="unused_files_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "📦 Creating backup in $BACKUP_DIR..."

# Function to safely remove files
safe_remove() {
    local file="$1"
    if [ -f "$file" ]; then
        # Create backup directory structure
        local dir=$(dirname "$file")
        mkdir -p "$BACKUP_DIR/$dir"
        # Move to backup instead of deleting
        mv "$file" "$BACKUP_DIR/$file" 2>/dev/null && echo "✓ Removed: $file" || echo "✗ Failed: $file"
    fi
}

# Function to safely remove directories
safe_remove_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        # Move entire directory to backup
        mkdir -p "$BACKUP_DIR/$(dirname "$dir")"
        mv "$dir" "$BACKUP_DIR/$dir" 2>/dev/null && echo "✓ Removed directory: $dir" || echo "✗ Failed: $dir"
    fi
}

echo ""
echo "🗑️  Removing log files..."
find . -name "*.log" -type f | while read f; do safe_remove "$f"; done

echo ""
echo "🗑️  Removing BEAM files..."
safe_remove "Elixir.VsmPhoenix.Algedonic.AlgedonicChannel.beam"
safe_remove "Elixir.VsmPhoenix.Algedonic.Supervisor.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.CascadeSimulator.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.CascadeSimulator.CascadeModel.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.CascadeSimulator.FailureNode.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.CascadeSimulator.PropagationRule.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.ChaosMetrics.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.ChaosMetrics.MetricPoint.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.FaultInjector.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.FaultInjector.Fault.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.FaultInjector.InjectionPolicy.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.FaultRegistry.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.FaultRegistry.FaultDefinition.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.ResilienceAnalyzer.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.ResilienceAnalyzer.ResilienceMetrics.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.ResilienceAnalyzer.ResilienceReport.beam"
safe_remove "Elixir.VsmPhoenix.ChaosEngineering.ResilienceAnalyzer.ResilienceTest.beam"
safe_remove "Elixir.VsmPhoenix.EmergentIntelligence.CollectiveLearning.beam"
safe_remove "Elixir.VsmPhoenix.EmergentIntelligence.EmergentBehavior.beam"
safe_remove "Elixir.VsmPhoenix.MetaVsm.Demo.beam"
safe_remove "Elixir.VsmPhoenix.QuantumVariety.EntanglementManager.beam"
safe_remove "Elixir.VsmPhoenix.QuantumVariety.QuantumVarietyManager.beam"
safe_remove "Elixir.VsmPhoenix.SelfModifying.AdaptiveBehavior.beam"
safe_remove "Elixir.VsmPhoenix.SelfModifying.ModuleReloader.beam"

echo ""
echo "🗑️  Removing crash dumps and test scripts..."
safe_remove "erl_crash.dump"
safe_remove "proof_amqp_otp27.exs"
safe_remove "test_consumer.exs"
safe_remove "test_mcp_tools.exs"

echo ""
echo "🗑️  Removing JavaScript prototype files..."
safe_remove "hive_monitor.js"
safe_remove "hive_strategy.js"
safe_remove "init_hive_mind.js"
safe_remove "minimal_mcp_client_real.js"
safe_remove "minimal_mcp_server_real.js"
safe_remove "vsm_server.js"

echo ""
echo "🗑️  Removing unused Elixir modules..."
safe_remove "lib/vsm_phoenix/bulletproof_application.ex"
safe_remove "lib/vsm_phoenix/system4/intelligence_god_object_backup.ex"
safe_remove "lib/vsm_phoenix/amqp/example_handlers.ex"
safe_remove "lib/vsm_phoenix/demos/multi_agent_swarm.ex"
safe_remove "lib/vsm_phoenix/mcp/capability_matcher.ex"
safe_remove "lib/vsm_phoenix/mcp/variety_acquisition.ex"
safe_remove "lib/vsm_phoenix/mcp/application.ex"

echo ""
echo "🗑️  Removing backup files..."
safe_remove "lib/vsm_phoenix/mcp/hermes_client.ex.bak"
safe_remove "lib/vsm_phoenix/mcp/hermes_client.ex.bak2"

echo ""
echo "🗑️  Removing directories..."
safe_remove_dir "lib/vsm_phoenix/mcp/archive"
safe_remove_dir "lib/vsm_phoenix/mcp/architecture"
safe_remove_dir "lib/vsm_phoenix/mcp/test"
safe_remove_dir "lib/vsm_phoenix/demos"

echo ""
echo "🗑️  Removing misplaced files..."
safe_remove "lib/vsm_phoenix/system4/intelligence/FINAL_CLEANUP_COMPLETE.md"
safe_remove "lib/vsm_phoenix/variety_engineering/example.exs"

echo ""
echo "🗑️  Removing orphaned test files..."
safe_remove "test/vsm_phoenix/variety_engineering/filters/anomaly_filter_test.exs"
safe_remove "test/vsm_phoenix/variety_engineering/filters/priority_filter_test.exs"
safe_remove "test/vsm_phoenix/variety_engineering/filters/semantic_filter_test.exs"
safe_remove "test/vsm_phoenix/variety_engineering/filters/threshold_filter_test.exs"
safe_remove_dir "test/vsm_phoenix/variety_engineering/aggregators"

echo ""
echo "🗑️  Removing unused config files..."
safe_remove "config/bulletproof.exs"
safe_remove "config/no_mcp.exs"
safe_remove "config/test_isolated.exs"

echo ""
echo "✅ Cleanup complete!"
echo "📦 All removed files backed up to: $BACKUP_DIR"
echo ""
echo "To restore any file, use: mv $BACKUP_DIR/[file_path] [file_path]"
echo "To permanently delete the backup: rm -rf $BACKUP_DIR"