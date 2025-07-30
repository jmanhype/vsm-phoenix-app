#!/bin/bash
# COMPLETE DOCS OVERHAUL - NO COMPROMISES

echo "🔥 STARTING AGGRESSIVE DOCS REORGANIZATION..."

# Create the PROPER structure
mkdir -p docs/{01_start_here,02_architecture/{overview,systems,integrations},03_api/{reference,examples},04_development/{setup,testing,debugging},05_operations/{deployment,monitoring},06_decisions,99_archive/{old_reports,temp_files}}

# Move files to their PROPER homes
echo "📦 Reorganizing documentation..."

# Start Here section
mv docs/00_temp_holding/README.md docs/01_start_here/readme.md 2>/dev/null || echo "# VSM Phoenix Documentation\n\nStart here for all documentation." > docs/01_start_here/readme.md

# Architecture files
mv docs/00_temp_holding/CYBERNETIC_HIVE_MIND_ARCHITECTURE.md docs/02_architecture/systems/hive-mind-cybernetic.md
mv docs/00_temp_holding/HIVE_MIND_ARCHITECTURE.md docs/02_architecture/systems/hive-mind-core.md
mv docs/mcp/HIVE_MIND_ARCHITECTURE.md docs/02_architecture/systems/hive-mind-mcp.md 2>/dev/null || true
mv docs/00_temp_holding/SUPERVISOR_CASCADE_ANALYSIS.md docs/02_architecture/overview/supervisor-cascade-analysis.md

# API Documentation
mv docs/00_temp_holding/API_DOCUMENTATION.md docs/03_api/reference/endpoints.md

# Development/Testing
mv docs/00_temp_holding/TEST_RESULTS.md docs/04_development/testing/test-results-latest.md
mv docs/00_temp_holding/TEST_RESULTS_SUMMARY.md docs/04_development/testing/test-summary.md
mv docs/00_temp_holding/dashboard_test_results.md docs/04_development/testing/dashboard-tests.md

# Archive old planning docs
mv docs/00_temp_holding/CLEANUP_PLAN.md docs/99_archive/temp_files/cleanup-plan.md
mv docs/00_temp_holding/LEAN_VERSION_PLAN.md docs/99_archive/temp_files/lean-version-plan.md
mv docs/00_temp_holding/FINAL_MCP_INTEGRATION_REPORT.md docs/99_archive/old_reports/mcp-integration-final.md

# Move ALL archive files
mv docs/archive/*.md docs/99_archive/old_reports/ 2>/dev/null || true

# MCP docs
mv docs/mcp/*.md docs/02_architecture/integrations/ 2>/dev/null || true

# Clean up
rmdir docs/00_temp_holding 2>/dev/null || true
rmdir docs/archive 2>/dev/null || true
rmdir docs/mcp 2>/dev/null || true
rmdir docs/api docs/architecture docs/guides docs/testing 2>/dev/null || true

echo "✅ File reorganization complete!"