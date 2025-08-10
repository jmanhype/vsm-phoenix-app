# System 4 Intelligence Tests Directory

Test suite for the System 4 intelligence components that scan the environment and propose adaptations.

## Test Files

- **scanner_test.exs** - Tests environmental scanning capabilities
- **analyzer_test.exs** - Tests pattern analysis and threat detection
- **adaptation_engine_test.exs** - Tests adaptation proposal generation
- **intelligence_test.exs** - Integration tests for the full intelligence system

## Testing Focus Areas

### Environmental Scanning
Tests verify the scanner can:
- Detect environmental changes
- Identify emerging threats
- Discover new opportunities
- Monitor boundary conditions
- Track temporal patterns

### Pattern Analysis
Tests ensure the analyzer can:
- Recognize complex patterns
- Correlate multiple signals
- Filter noise from signals
- Predict future trends
- Score threat severity

### Adaptation Generation
Tests validate the engine can:
- Generate viable adaptations
- Prioritize by impact
- Consider resource constraints
- Track adaptation success
- Learn from outcomes

## Intelligence Test Patterns

### Scenario Testing
```elixir
test "detects market disruption pattern" do
  signals = generate_disruption_signals()
  {:ok, threats} = Scanner.scan(signals)
  assert Enum.any?(threats, &(&1.type == :market_disruption))
end
```

### Adaptation Testing
```elixir
test "proposes valid adaptation for threat" do
  threat = %{type: :competitor_entry, severity: :high}
  {:ok, adaptations} = AdaptationEngine.propose(threat)
  assert length(adaptations) > 0
  assert Enum.all?(adaptations, &valid_adaptation?/1)
end
```

## Integration with Attention Engine

These tests also verify that intelligence outputs integrate properly with the Cortical Attention-Engine for prioritization.