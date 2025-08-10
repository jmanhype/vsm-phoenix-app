# Test Runners Directory

Specialized test execution scripts for different testing scenarios.

## Files in this directory:

- `run_isolated_tests.sh` - Runs tests in isolated environments
- `run_passing_tests.sh` - Executes only known passing tests
- `run_tests_with_phoenix.sh` - Tests with full Phoenix framework
- `test_final_check.sh` - Final validation before deployment

## Purpose:
Provides different test execution strategies for various development and CI/CD scenarios.

## Test Strategies:

### Isolated Tests
- Runs tests without external dependencies
- Uses in-memory databases
- Mocks external services
- Fast execution for rapid feedback

### Passing Tests Only
- Maintains list of stable tests
- Useful during refactoring
- Ensures no regression in working code
- Gradually adds fixed tests back

### Phoenix Integration
- Full framework testing
- Real database connections
- Live WebSocket testing
- End-to-end scenarios

### Final Validation
- Comprehensive test suite
- Performance benchmarks
- Security scans
- Release readiness check

## Usage:
```bash
# Run isolated unit tests
./run_isolated_tests.sh

# Run only stable tests
./run_passing_tests.sh

# Full integration tests
./run_tests_with_phoenix.sh

# Pre-deployment validation
./test_final_check.sh
```

## CI/CD Integration:
These scripts are designed to be used in continuous integration pipelines for different stages of validation.