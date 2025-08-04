# VSM Phoenix Performance Benchmarking Suite

Comprehensive performance benchmarks for the Viable System Model implementation in Phoenix/Elixir.

## Overview

This benchmarking suite provides thorough performance testing for:

- **Variety Processing**: Throughput, complexity handling, and channel capacity
- **Quantum Operations**: Superposition, entanglement, measurement, and quantum gates
- **Recursive Spawning**: Process creation, meta-VSM operations, and hierarchical structures
- **Algedonic Signals**: Signal propagation, attenuation, and feedback loops
- **Load Testing**: Various load patterns including constant, ramp-up, spike, and chaos testing

## Installation

1. Install dependencies:
```bash
mix deps.get
```

2. Create results directory:
```bash
mkdir -p benchmarks/results
```

## Usage

### Quick Start

Run all benchmarks with default settings:
```bash
mix benchmark
```

### Using Profiles

Run with predefined profiles:
```bash
# Quick testing (2s per benchmark)
mix benchmark.quick

# Standard testing (10s per benchmark)
mix benchmark

# Thorough testing (30s per benchmark)
mix run benchmarks/run_benchmarks.exs --profile thorough

# Stress testing (60s per benchmark)
mix benchmark.stress
```

### Running Specific Suites

```bash
# Quantum operations only
mix benchmark.quantum

# Variety processing only
mix benchmark.variety

# Load testing only
mix run benchmarks/run_benchmarks.exs --suite load

# Recursive spawning only
mix run benchmarks/run_benchmarks.exs --suite recursive
```

### Custom Configuration

```bash
# Custom time and warmup
mix run benchmarks/run_benchmarks.exs --time 20 --warmup 5

# Disable memory profiling
mix run benchmarks/run_benchmarks.exs --no-memory

# Verbose output
mix run benchmarks/run_benchmarks.exs --verbose
```

## Benchmark Suites

### 1. Main VSM Benchmarks (`vsm_benchmark.exs`)

- Variety processing (simple, medium, complex)
- Quantum operations (superposition, entanglement, measurement)
- Recursive VSM spawning
- Meta-VSM operations
- Algedonic signal processing

### 2. Load Testing (`scenarios/load_testing.exs`)

- **Constant Load**: Steady request rate
- **Ramp-up Load**: Gradually increasing load
- **Spike Load**: Sudden traffic spikes
- **Wave Load**: Sinusoidal load patterns
- **Stress Testing**: Memory, CPU, and network stress
- **Chaos Testing**: Random failure injection

### 3. Quantum Operations (`scenarios/quantum_benchmarks.exs`)

- **Superposition**: 2-32 qubit states
- **Entanglement**: Bell states, GHZ states, mesh topology
- **Measurement**: Single, batch, partial, weak measurements
- **Gates**: Pauli, CNOT, Toffoli, phase, rotation gates
- **Algorithms**: Grover search, QFT, phase estimation, VQE

### 4. Recursive Spawning (`scenarios/recursive_spawning_benchmarks.exs`)

- **Flat Spawning**: 10-100,000 processes
- **Tree Spawning**: Various depths and branching factors
- **Fractal VSM**: Self-similar hierarchical structures
- **Dynamic Topology**: Random connection patterns
- **Spawn Limits**: Maximum capacity testing
- **Meta-VSM**: Creation, transformation, evolution

### 5. Variety Throughput (`scenarios/variety_throughput_benchmarks.exs`)

- **Serial vs Parallel**: Performance comparison
- **Stream Processing**: Lazy evaluation benchmarks
- **Batch Processing**: Optimal batch size testing
- **Pipeline Processing**: Multi-stage processing
- **Channel Capacity**: Multiplexing and buffering
- **Attenuation/Amplification**: Signal modification

## Output Formats

Results are saved in multiple formats:

- **Console**: Real-time output during execution
- **HTML**: Interactive charts at `benchmarks/results/*.html`
- **JSON**: Machine-readable data at `benchmarks/results/*.json`
- **Benchee**: Native format for comparison at `benchmarks/results/*.benchee`

## Performance Metrics

Each benchmark measures:

- **Throughput**: Operations per second
- **Latency**: Min, max, mean, median, p95, p99
- **Memory Usage**: Allocation and garbage collection
- **CPU Usage**: Processing time and utilization
- **Scalability**: Performance under different loads

## Interpreting Results

### Key Metrics

- **IPS (Iterations Per Second)**: Higher is better
- **Average**: Mean execution time
- **Deviation**: Standard deviation (lower = more consistent)
- **Median**: Middle value (less affected by outliers)
- **99th Percentile**: Worst-case performance

### Performance Targets

- Variety Processing: >10,000 items/second
- Quantum Operations: <1ms for single qubit operations
- Process Spawning: >100,000 processes/second
- Algedonic Signals: <10ms propagation latency
- Channel Capacity: >100,000 messages/second

## Continuous Benchmarking

For CI/CD integration:

```bash
# Quick benchmarks for PR validation
mix benchmark.quick

# Compare with baseline
mix run benchmarks/run_benchmarks.exs --compare

# Generate performance report
mix run benchmarks/run_benchmarks.exs --format json > performance.json
```

## Troubleshooting

### Out of Memory

Reduce concurrent operations:
```bash
mix run benchmarks/run_benchmarks.exs --parallel 1
```

### Timeouts

Increase timeout values:
```bash
mix run benchmarks/run_benchmarks.exs --time 60 --warmup 10
```

### Inconsistent Results

Increase warmup time:
```bash
mix run benchmarks/run_benchmarks.exs --warmup 10
```

## Contributing

To add new benchmarks:

1. Create a new file in `benchmarks/scenarios/`
2. Use the Benchee framework
3. Add to `@benchmark_suites` in `run_benchmarks.exs`
4. Follow existing naming conventions
5. Document expected performance targets

## License

See the main project LICENSE file.