# Environmental Scanning Process (Actual Implementation)

## Overview
This diagram shows the actual System 4 environmental scanning implementation. Notable differences: fixed 60-second intervals (not adaptive), simulated data sources, optional LLM variety analysis, and functional anomaly detection that triggers policy synthesis.

```mermaid
sequenceDiagram
    participant Timer as 60s Fixed Timer
    participant S4 as System 4 Intelligence
    participant Tidewave as Tidewave (Mock Data)
    participant LLM as LLM Variety Source
    participant Hermes as Hermes MCP
    participant Claude as Claude API
    participant S5 as System 5 Queen
    participant S1 as System 1 Operations
    participant AMQP as AMQP Publisher

    Note over Timer,AMQP: Fixed 60-second Environmental Scanning

    %% Scan Initiation
    Timer->>S4: :scheduled_scan
    S4->>S4: handle_call({:scan_environment, :scheduled})
    
    %% Environmental Scan (Mostly Simulated)
    S4->>S4: perform_environmental_scan()
    Note over S4: Generate simulated data:<br/>- market_signals<br/>- technology_trends<br/>- regulatory_updates<br/>- competitive_moves
    
    %% Optional LLM Variety Analysis
    opt enable_llm_variety == true
        S4->>LLM: analyze_for_variety(base_scan)
        
        alt Hermes MCP Available (2s timeout)
            LLM->>Hermes: {:analyze_variety, context}
            Hermes->>LLM: variety_expansion with patterns
            Hermes->>Hermes: check_meta_system_need()
            
            opt needs_meta_system == true
                Hermes->>LLM: meta_system_config
            end
        else Hermes Timeout or Error
            LLM->>Claude: Direct API call
            Claude->>LLM: insights
            LLM->>LLM: extract_patterns()
            LLM->>LLM: generate_meta_seeds()
        end
        
        LLM->>S4: variety_expansion
        
        opt meta_system_seeds != {}
            S4->>S1: pipe_to_system1_meta_generation()
            S1->>S1: spawn_meta_system()
            Note over S1: Creates recursive VSM!
        end
    end
    
    %% Anomaly Detection
    S4->>S4: detect_anomalies(scan_results)
    
    alt Anomalies Detected
        loop For each anomaly
            S4->>S5: {:anomaly_detected, anomaly}
            Note over S5: Triggers policy synthesis
        end
    end
    
    %% Adaptation Check
    S4->>S4: analyze_scan_results()
    
    alt requires_adaptation == true
        S4->>S4: generate_internal_adaptation_proposal()
        S4->>S5: Queen.approve_adaptation(proposal)
    end
    
    %% Alert Publishing
    alt alert_level in [:high, :critical]
        S4->>AMQP: publish_environmental_alert()
    end
    
    %% Schedule Next Scan
    S4->>Timer: Process.send_after(:scheduled_scan, 60_000)
```

## Actual Scanning Implementation (40% Accurate)

### Key Differences from Design

1. **Fixed Intervals**: Always 60 seconds, not adaptive based on variety
2. **Mock Data**: No real Tidewave integration, generates simulated data
3. **Optional LLM**: Disabled by default (`enable_llm_variety` config)
4. **Simple Anomaly Detection**: Basic implementation, limited criteria
5. **No Parallel Gathering**: Sequential processing, not parallel tasks

### Environmental Scan Function
```elixir
defp perform_environmental_scan(scope, _tidewave) do
  base_scan = %{
    market_signals: generate_market_signals(),      # Simulated
    technology_trends: detect_technology_trends(),   # Simulated
    regulatory_updates: check_regulatory_changes(),  # Simulated
    competitive_moves: analyze_competition(),        # Simulated
    timestamp: DateTime.utc_now()
  }
  
  # LLM analysis only if enabled (default: false)
  if Application.get_env(:vsm_phoenix, :enable_llm_variety, false) do
    # ... LLM variety analysis with 3s timeout
  end
end
```

### Fixed Scanning Schedule
```elixir
defp schedule_environmental_scan do
  Process.send_after(self(), :scheduled_scan, 60_000)  # Always 60 seconds
end
```

## LLM Variety Analysis (Actually Implemented!)

```mermaid
graph TB
    Context[Environmental Context] --> LLMVariety[LLM Variety Source]
    
    LLMVariety --> HermesCheck{Hermes MCP<br/>Available?}
    
    HermesCheck -->|Yes + Timeout OK| HermesAnalysis[Hermes MCP Analysis]
    HermesCheck -->|No/Timeout| ClaudeFallback[Claude API Fallback]
    
    HermesAnalysis --> VarietyExpansion[Variety Expansion]
    HermesAnalysis --> MetaCheck[check_meta_system_need()]
    
    ClaudeFallback --> Prompt[build_variety_prompt()]
    ClaudeFallback --> ExtractPatterns[extract_patterns()]
    ClaudeFallback --> MetaSeeds[generate_meta_seeds()]
    
    MetaCheck -->|needs_meta_system| MetaConfig[Meta System Config]
    MetaSeeds -->|seeds exist| MetaSpawn[Spawn Meta VSM]
    
    VarietyExpansion --> Results[Novel Patterns<br/>Emergent Properties<br/>Recursive Potential]
    MetaConfig --> MetaSpawn
    
    MetaSpawn --> S1[System 1 Operations]
    S1 --> RecursiveVSM[New Recursive VSM<br/>with own S3-4-5!]
    
    classDef implemented fill:#90EE90,stroke:#333,stroke-width:2px
    classDef optional fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef simulated fill:#FFA07A,stroke:#333,stroke-width:2px
    
    class HermesAnalysis,ClaudeFallback,VarietyExpansion,MetaSpawn,RecursiveVSM implemented
    class LLMVariety,MetaCheck,MetaSeeds optional
    class Context simulated
```

### Working LLM Integration

**File**: `lib/vsm_phoenix/system4/llm_variety_source.ex`

```elixir
def analyze_for_variety(context) do
  # Try Hermes MCP first (2s timeout)
  case GenServer.call(HermesClient, {:analyze_variety, context}, 2000) do
    {:ok, variety_expansion} ->
      # Check for meta-system need
      case HermesClient.check_meta_system_need(variety_expansion) do
        {:ok, %{needs_meta_system: true} = meta_info} ->
          # Add meta-system config to expansion
      end
      
    {:error, _} ->
      # Fallback to Claude API
      call_claude(build_variety_prompt(context))
  end
end
```

## Anomaly Detection (Simplified)

```mermaid
flowchart TD
    ScanData[Scan Results] --> DetectAnom[detect_anomalies()]
    
    DetectAnom --> BasicChecks[Basic Anomaly Checks<br/>(Very Limited)]
    
    BasicChecks --> AnomalyList[Anomaly List]
    
    AnomalyList --> LoopAnom{For Each<br/>Anomaly}
    
    LoopAnom --> CastQueen[GenServer.cast(Queen,<br/>{:anomaly_detected, anomaly})]
    
    CastQueen --> PolicySynth[Triggers Policy<br/>Synthesis in S5]
    
    LoopAnom --> LoopAnom
    
    classDef simple fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef working fill:#90EE90,stroke:#333,stroke-width:2px
    
    class BasicChecks simple
    class CastQueen,PolicySynth working
```

### Actual Anomaly Detection
```elixir
defp detect_anomalies(scan_data) do
  anomalies = []
  
  # Very basic implementation
  # Only checks limited criteria
  # Most anomaly detection logic is placeholder
  
  anomalies
end
```

## Data Flow Patterns

### Simulated Data Generation
All environmental data is **simulated**, not real:
- `generate_market_signals()` - Returns random market data
- `detect_technology_trends()` - Returns hardcoded trends
- `check_regulatory_changes()` - Returns empty or mock data
- `analyze_competition()` - Returns placeholder competitive data

### AMQP Alert Publishing
```elixir
# Only publishes for high/critical alerts
alert_level = cond do
  insights.requires_adaptation && insights.challenge.urgency == :high -> :critical
  insights.requires_adaptation -> :high
  true -> :normal
end

if alert_level in [:high, :critical] do
  GenServer.cast(self(), {:publish_environmental_alert, alert_message})
end
```

## Missing Components

1. **Adaptive Scanning**: No frequency adjustment based on variety
2. **Real Data Sources**: No actual Tidewave or external API integration
3. **Parallel Processing**: No Task.async for concurrent data gathering
4. **Comprehensive Anomaly Detection**: Very basic implementation
5. **Variety Calculations**: No Ashby's Law calculations
6. **Environmental Baseline**: No baseline tracking or learning
7. **Performance Metrics**: No telemetry or monitoring

## Working Features

1. **✅ Regular Scanning**: Every 60 seconds reliably
2. **✅ LLM Integration**: Both Hermes MCP and Claude API work (when enabled)
3. **✅ Meta-System Spawning**: Can trigger recursive VSM creation!
4. **✅ S5 Integration**: Anomalies sent to Queen for policy synthesis
5. **✅ AMQP Publishing**: Environmental alerts published (high/critical only)

## Performance Characteristics

- **Scan Frequency**: Fixed 60 seconds (not adaptive)
- **LLM Timeout**: 2 seconds for Hermes, 3 seconds for variety task
- **Processing Time**: <1 second for simulated scan
- **Memory Usage**: Minimal (no data persistence)

## Configuration

```elixir
# In config.exs
config :vsm_phoenix,
  enable_llm_variety: false,  # Disabled by default
  tidewave_api_key: nil,      # Not used
  environmental_scan_interval: 60_000  # Not configurable
```

## Notes

1. **Simulated but Functional**: Despite mock data, the scanning loop works
2. **LLM Ready**: Full LLM integration exists but disabled by default
3. **Recursive Capability**: Can spawn meta-VSMs when variety explodes
4. **Simple but Effective**: Basic implementation still triggers adaptations
5. **Room for Enhancement**: Structure exists for real data sources