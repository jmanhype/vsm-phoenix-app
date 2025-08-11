# Intelligence.ex God Object Refactoring Plan

## 🚨 CRITICAL ANALYSIS

### Current State
- **File**: `lib/vsm_phoenix/system4/intelligence.ex`
- **Lines**: 1,755 lines (GOD OBJECT!)
- **Functions**: 106 functions
- **Logger calls**: 31 (should use shared behavior)
- **Try/rescue blocks**: 14 (should use resilience behavior)
- **Case/cond statements**: 26 (needs polymorphism)

### Architectural Violations

1. **Single Responsibility Principle (SRP)**: Intelligence.ex handles:
   - Environmental scanning
   - Trend analysis
   - Adaptation generation
   - Pattern matching
   - Tidewave integration
   - Health monitoring
   - AMQP communication
   - State management

2. **Open/Closed Principle (OCP)**: No extension points, all behavior hardcoded

3. **Dependency Inversion Principle (DIP)**: Direct dependencies on:
   - AMQP
   - Tidewave
   - Specific data structures
   - Hardcoded algorithms

## 🎯 REFACTORING STRATEGY

### Phase 1: Extract Core Behaviors

#### 1.1 Environmental Scanning Behavior
**Extract to**: `lib/vsm_phoenix/system4/intelligence/environmental_scanner.ex`

**Functions to extract** (lines 493-603):
```elixir
- perform_environmental_scan/2
- analyze_competition/0
- analyze_market_conditions/1
- analyze_technology_trends/1
- analyze_regulatory_environment/1
- analyze_economic_indicators/1
```

**Behavior Module**:
```elixir
defmodule VsmPhoenix.System4.Intelligence.EnvironmentalScanner do
  @behaviour VsmPhoenix.System4.Intelligence.ScannerBehaviour
  
  @moduledoc """
  Handles all environmental scanning operations with pluggable data sources.
  """
  
  def scan(scope, data_source), do: # Implementation
  def analyze_results(results), do: # Implementation
end
```

#### 1.2 Pattern Analysis Behavior
**Extract to**: `lib/vsm_phoenix/system4/intelligence/pattern_analyzer.ex`

**Functions to extract** (lines 670-731):
```elixir
- match_patterns/2
- analyze_internal_trends/1
- detect_environmental_changes/2
- calculate_anomaly_score/2
- update_pattern_baseline/2
```

**Behavior Module**:
```elixir
defmodule VsmPhoenix.System4.Intelligence.PatternAnalyzer do
  @behaviour VsmPhoenix.System4.Intelligence.AnalyzerBehaviour
  
  @moduledoc """
  Cortical attention-based pattern analysis with learning capabilities.
  """
  
  def analyze_patterns(data, baseline), do: # Implementation
  def detect_anomalies(data, baseline), do: # Implementation
  def update_learning(patterns), do: # Implementation
end
```

#### 1.3 Adaptation Engine Behavior  
**Extract to**: `lib/vsm_phoenix/system4/intelligence/adaptation_engine.ex`

**Functions to extract** (lines 471-492, 732-850):
```elixir
- generate_internal_adaptation_proposal/2
- select_adaptation_model/2
- generate_adaptation_from_model/2
- create_adaptation_proposal/3
```

**Behavior Module**:
```elixir
defmodule VsmPhoenix.System4.Intelligence.AdaptationEngine do
  @behaviour VsmPhoenix.System4.Intelligence.AdaptationBehaviour
  
  @moduledoc """
  Generates adaptation proposals using configurable strategies.
  """
  
  def generate_proposal(challenge, context), do: # Implementation
  def evaluate_proposal(proposal, metrics), do: # Implementation
  def implement_adaptation(proposal), do: # Implementation
end
```

### Phase 2: Create Behavior Contracts

#### 2.1 Scanner Behaviour
```elixir
defmodule VsmPhoenix.System4.Intelligence.ScannerBehaviour do
  @callback scan(scope :: atom(), data_source :: term()) :: 
    {:ok, scan_results :: map()} | {:error, reason :: term()}
    
  @callback analyze_results(results :: map()) ::
    {:ok, analysis :: map()} | {:error, reason :: term()}
end
```

#### 2.2 Analyzer Behaviour
```elixir
defmodule VsmPhoenix.System4.Intelligence.AnalyzerBehaviour do
  @callback analyze_patterns(data :: map(), baseline :: map()) ::
    {:ok, patterns :: map()} | {:error, reason :: term()}
    
  @callback detect_anomalies(data :: map(), baseline :: map()) ::
    {:ok, anomalies :: list()} | {:error, reason :: term()}
end
```

#### 2.3 Adaptation Behaviour
```elixir
defmodule VsmPhoenix.System4.Intelligence.AdaptationBehaviour do
  @callback generate_proposal(challenge :: map(), context :: map()) ::
    {:ok, proposal :: map()} | {:error, reason :: term()}
    
  @callback evaluate_proposal(proposal :: map(), metrics :: map()) ::
    {:ok, evaluation :: map()} | {:error, reason :: term()}
end
```

### Phase 3: Implement Dependency Injection

#### 3.1 Intelligence Coordinator
```elixir
defmodule VsmPhoenix.System4.Intelligence.Coordinator do
  @moduledoc """
  Coordinates intelligence operations using injected dependencies.
  """
  
  defstruct [
    :scanner,
    :analyzer, 
    :adaptation_engine,
    :logger,
    :resilience_manager
  ]
  
  def new(opts \\ []) do
    %__MODULE__{
      scanner: Keyword.get(opts, :scanner, EnvironmentalScanner),
      analyzer: Keyword.get(opts, :analyzer, PatternAnalyzer),
      adaptation_engine: Keyword.get(opts, :adaptation_engine, AdaptationEngine),
      logger: Keyword.get(opts, :logger, VsmPhoenix.Behaviors.LoggerBehavior),
      resilience_manager: Keyword.get(opts, :resilience, VsmPhoenix.Behaviors.ResilienceBehavior)
    }
  end
end
```

### Phase 4: Extract Shared Behaviors (Coordinate with Other Swarms)

#### 4.1 Logger Behavior (31 Logger calls)
```elixir
defmodule VsmPhoenix.Behaviors.LoggerBehavior do
  @callback info(message :: String.t(), metadata :: map()) :: :ok
  @callback warn(message :: String.t(), metadata :: map()) :: :ok  
  @callback error(message :: String.t(), metadata :: map()) :: :ok
end
```

#### 4.2 Resilience Behavior (14 try/rescue blocks)
```elixir
defmodule VsmPhoenix.Behaviors.ResilienceBehavior do
  @callback with_circuit_breaker(operation :: function()) :: 
    {:ok, result :: term()} | {:error, reason :: term()}
    
  @callback with_retry(operation :: function(), opts :: keyword()) ::
    {:ok, result :: term()} | {:error, reason :: term()}
    
  @callback with_bulkhead(resource :: atom(), operation :: function()) ::
    {:ok, result :: term()} | {:error, reason :: term()}
end
```

### Phase 5: Cortical Attention Integration

#### 5.1 Attention-Based Prioritization
```elixir
defmodule VsmPhoenix.System4.Intelligence.AttentionManager do
  @moduledoc """
  Integrates cortical attention patterns for intelligent priority management.
  """
  
  alias VsmPhoenix.System2.CorticalAttentionEngine
  
  def prioritize_scan_results(results, context) do
    # Apply attention scoring to scan results
    # Boost high-relevance environmental changes
    # Filter low-attention patterns
  end
  
  def route_adaptation_requests(requests) do
    # Use attention scoring for adaptation routing
    # Prioritize critical environmental changes
    # Balance adaptation resources based on attention scores
  end
end
```

## 🔄 COORDINATION WITH OTHER SWARMS

### Dependencies on Other God Object Refactoring

1. **Control.ex Swarm** (3,442 lines):
   - Share resilience behaviors
   - Extract common AMQP patterns
   - Coordinate resource management

2. **Queen.ex Swarm** (1,471 lines):  
   - Share policy evaluation patterns
   - Extract decision-making behaviors
   - Coordinate adaptation approvals

3. **Resilience Swarm**:
   - Provide shared circuit breaker patterns
   - Implement bulkhead isolation
   - Create retry mechanisms

### Shared Behavior Modules

All swarms should use:
- `VsmPhoenix.Behaviors.LoggerBehavior` (eliminates 1,247 Logger calls)
- `VsmPhoenix.Behaviors.ResilienceBehavior` (eliminates 142 try/rescue blocks)
- `VsmPhoenix.Behaviors.AMQPBehavior` (eliminates hardcoded AMQP)

## 📋 IMPLEMENTATION CHECKLIST

### Phase 1: Behavior Extraction
- [ ] Create `EnvironmentalScanner` module
- [ ] Create `PatternAnalyzer` module  
- [ ] Create `AdaptationEngine` module
- [ ] Extract 31 Logger calls to behavior
- [ ] Extract 14 try/rescue blocks to resilience behavior
- [ ] Extract 26 case/cond statements to polymorphic behaviors

### Phase 2: Dependency Injection
- [ ] Create behavior contracts (3 behaviours)
- [ ] Implement dependency injection in coordinator
- [ ] Replace hardcoded dependencies
- [ ] Create factory patterns for behavior creation

### Phase 3: Testing & Validation
- [ ] Unit tests for each extracted behavior
- [ ] Integration tests for coordinator
- [ ] Performance benchmarks
- [ ] Regression testing

### Phase 4: Documentation
- [ ] Behavior contract documentation
- [ ] Migration guide from god object
- [ ] Architecture decision records (ADRs)
- [ ] API documentation

## 🎯 SUCCESS METRICS

### Code Quality Metrics
- **Lines per module**: < 200 lines (from 1,755)
- **Functions per module**: < 15 functions (from 106)
- **Cyclomatic complexity**: < 10 per function
- **Test coverage**: > 90% for each behavior

### Architecture Metrics  
- **SOLID compliance**: All principles followed
- **Dependency count**: < 5 per module (injectable)
- **Code duplication**: < 5% across modules
- **Coupling**: Low coupling, high cohesion

### Performance Metrics
- **Memory usage**: Reduced by 30% (smaller modules)
- **Processing time**: Maintained or improved
- **Resource utilization**: Better isolation with bulkheads

## 🚀 COORDINATION COMMANDS

### For Intelligence Swarm:
```bash
claude-flow hive-mind task create "Extract EnvironmentalScanner from intelligence.ex lines 493-603"
claude-flow hive-mind task create "Create PatternAnalyzer behavior with attention integration"
claude-flow hive-mind task create "Implement AdaptationEngine with dependency injection"
```

### For Cross-Swarm Coordination:
```bash  
claude-flow hive-mind coordinate "Share LoggerBehavior implementation across all swarms"
claude-flow hive-mind coordinate "Implement ResilienceBehavior for try/rescue block elimination"
claude-flow hive-mind coordinate "Create AMQPBehavior abstraction for hardcoded exchanges"
```

This refactoring plan provides a clear roadmap for transforming the intelligence.ex god object into a set of focused, testable, and maintainable behaviors that follow SOLID principles and coordinate with other swarm refactoring efforts.