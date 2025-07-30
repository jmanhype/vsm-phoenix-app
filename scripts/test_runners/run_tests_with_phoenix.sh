#!/bin/bash

# Start Phoenix in background
echo "Starting Phoenix server..."
mix phx.server > phoenix.log 2>&1 &
PHX_PID=$!

# Wait for Phoenix to fully start
echo "Waiting for Phoenix to start..."
sleep 15

# Check if Phoenix is running
if ! ps -p $PHX_PID > /dev/null; then
    echo "❌ Phoenix failed to start!"
    cat phoenix.log
    exit 1
fi

echo "✅ Phoenix started with PID $PHX_PID"

# Run the tests
echo "Running unit tests..."
mix test --only unit > test_results.txt 2>&1
TEST_EXIT_CODE=$?

# Extract test results
echo ""
echo "Test Results:"
echo "============="
grep -E "(tests?|passed|failed|error|Finished in)" test_results.txt || cat test_results.txt | tail -50

# Kill Phoenix
echo ""
echo "Stopping Phoenix..."
kill $PHX_PID 2>/dev/null || true

# Check test results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ Tests passed!"
else
    echo ""
    echo "❌ Tests failed with exit code: $TEST_EXIT_CODE"
    echo ""
    echo "Full test output saved in test_results.txt"
fi

exit $TEST_EXIT_CODE