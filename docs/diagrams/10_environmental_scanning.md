# Environmental Scanning Process

## Overview
This diagram shows System 4's comprehensive environmental scanning process, including intelligence gathering, LLM variety amplification, anomaly detection, and the feedback loops that maintain the organization's environmental awareness.

```mermaid
sequenceDiagram
    participant Timer as 60s Fixed Timer
    participant S4 as System 4 Intelligence
    participant Tidewave as Tidewave Connection
    participant LLM as LLM Variety Source
    participant Hermes as Hermes MCP
    participant Claude as Claude API
    participant S5 as System 5 Queen
    participant S1 as System 1 Operations
    participant AMQP as AMQP Publisher

    Note over Timer,AMQP: Continuous Environmental Scanning Cycle

    %% Scan Initiation
    Timer->>S4: :scheduled_scan
    S4->>S4: handle_call({:scan_environment, :scheduled})
    
    %% Environmental Scan
    S4->>S4: perform_environmental_scan(scope, _tidewave)
    Note over S4,Tidewave: Tidewave parameter present but not utilized
    
    %% Data Generation
    S4->>S4: generate_market_signals()
    S4->>S4: detect_technology_trends()
    S4->>S4: check_regulatory_changes()
    S4->>S4: analyze_competition()
    Note over S4: Environmental data synthesis
    
    %% Optional LLM Variety Analysis
    opt LLM Variety Analysis Enabled
        S4->>LLM: analyze_for_variety(base_scan)
        
        alt Hermes MCP Available
            LLM->>Hermes: analyze_variety(context)
            Hermes->>LLM: variety_expansion with patterns
            Hermes->>Hermes: check_meta_system_need()
            Hermes->>LLM: meta_system_config (if needed)
        else Hermes Timeout or Error
            LLM->>Claude: Direct API call
            Claude->>LLM: insights
            LLM->>LLM: extract_patterns()
            LLM->>LLM: generate_meta_seeds()
        end
        
        LLM->>S4: variety_expansion
        
        Note over S4,S1: Meta-system spawning check
        S4->>S1: pipe_to_system1_meta_generation()
        S1->>S1: spawn_meta_system()
        Note over S1: Creates recursive VSM with own S3-4-5!
    end
    
    %% Anomaly Detection
    S4->>S4: detect_anomalies(scan_results)
    
    alt Anomalies Detected
        loop Each anomaly
            S4->>S5: anomaly_detected(anomaly)
            Note over S5: Triggers policy synthesis
        end
    end
    
    %% Adaptation Check
    S4->>S4: analyze_scan_results()
    
    alt Adaptation Required
        S4->>S4: generate_internal_adaptation_proposal()
        S4->>S5: Queen.approve_adaptation(proposal)
    end
    
    %% Alert Publishing
    alt High or Critical Alert
        S4->>AMQP: publish_environmental_alert()
    end
    
    %% Schedule Next Scan
    S4->>Timer: Process.send_after(:scheduled_scan, 60_000)
```

## Scanning Architecture Components

### Environmental Intelligence Sources
```mermaid
graph TB
    S4[System 4 Intelligence] --> Sources[Intelligence Sources]
    
    Sources --> MarketSig[Market Signal Generator]
    Sources --> TechTrends[Technology Trend Detector]  
    Sources --> RegMonitor[Regulatory Monitor]
    Sources --> CompAnalysis[Competition Analyzer]
    Sources --> LLMVariety[LLM Variety Amplifier]
    
    MarketSig --> MarketData[Market Intelligence<br/>- Demand signals<br/>- Price pressures<br/>- Emerging segments]
    TechTrends --> TechData[Technology Trends<br/>- AI/ML advances<br/>- Blockchain adoption<br/>- Cloud migration]
    RegMonitor --> RegData[Regulatory Updates<br/>- Compliance changes<br/>- Policy shifts<br/>- Legal requirements]
    CompAnalysis --> CompData[Competitive Intelligence<br/>- Market moves<br/>- New entrants<br/>- Strategic shifts]
    LLMVariety --> VarietyData[Variety Expansion<br/>- Novel patterns<br/>- Emergent properties<br/>- Recursive potential]
    
    MarketData --> Aggregator[Intelligence Aggregator]
    TechData --> Aggregator
    RegData --> Aggregator
    CompData --> Aggregator
    VarietyData --> Aggregator
    
    Aggregator --> ScanResults[Environmental Scan Results]
    ScanResults --> AnomalyDetector[Anomaly Detector]
    AnomalyDetector --> S4Output[System 4 Intelligence Output]
    
    classDef source fill:#e3f2fd,stroke:#333,stroke-width:2px
    classDef processor fill:#f3e5f5,stroke:#333,stroke-width:2px
    classDef output fill:#e8f5e8,stroke:#333,stroke-width:2px
    
    class MarketSig,TechTrends,RegMonitor,CompAnalysis,LLMVariety source
    class Aggregator,AnomalyDetector processor
    class ScanResults,S4Output output
```

### LLM Variety Amplification Process
```mermaid
graph TB
    Context[Environmental Context] --> LLMVariety[LLM Variety Source]
    
    LLMVariety --> HermesCheck{Hermes MCP<br/>Available?}
    
    HermesCheck -->|Yes + 2s Timeout OK| HermesAnalysis[Hermes MCP Analysis]
    HermesCheck -->|No/Timeout| ClaudeFallback[Claude API Fallback]
    
    HermesAnalysis --> VarietyExpansion[Variety Expansion]
    HermesAnalysis --> MetaCheck[check_meta_system_need]
    
    ClaudeFallback --> Prompt[build_variety_prompt]
    ClaudeFallback --> ExtractPatterns[extract_patterns]
    ClaudeFallback --> MetaSeeds[generate_meta_seeds]
    
    MetaCheck -->|needs_meta_system| MetaConfig[Meta System Config]
    MetaSeeds -->|seeds exist| MetaSpawn[Spawn Meta VSM]
    
    VarietyExpansion --> Results[Novel Patterns<br/>Emergent Properties<br/>Recursive Potential<br/>Meta System Seeds]
    MetaConfig --> MetaSpawn
    
    MetaSpawn --> S1[System 1 Operations]
    S1 --> RecursiveVSM[New Recursive VSM<br/>with own S3-4-5!]
    
    RecursiveVSM --> SubS5[Sub-System 5<br/>Policy]
    RecursiveVSM --> SubS4[Sub-System 4<br/>Intelligence]
    RecursiveVSM --> SubS3[Sub-System 3<br/>Control]
    
    classDef implemented fill:#90EE90,stroke:#333,stroke-width:2px
    classDef optional fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef simulated fill:#FFA07A,stroke:#333,stroke-width:2px
    classDef meta fill:#E6E6FA,stroke:#333,stroke-width:2px
    
    class HermesAnalysis,ClaudeFallback,VarietyExpansion,MetaSpawn,RecursiveVSM implemented
    class LLMVariety,MetaCheck,MetaSeeds optional
    class Context simulated
    class SubS5,SubS4,SubS3 meta
```

## Detailed Scanning Implementation

### System 4 Environmental Scanner State Machine
```mermaid
stateDiagram-v2
    [*] --> Idle : Initialize
    
    Idle --> Scanning : Timer Trigger (60s)
    
    Scanning --> DataGeneration : Start Scan
    DataGeneration --> MarketSignals : Generate
    MarketSignals --> TechTrends : Generate
    TechTrends --> Regulatory : Generate
    Regulatory --> Competition : Generate
    Competition --> LLMCheck : Check Config
    
    LLMCheck --> LLMAnalysis : LLM Enabled
    LLMCheck --> AnomalyDetection : LLM Disabled
    
    LLMAnalysis --> HermesTry : Attempt MCP
    HermesTry --> HermesSuccess : Success
    HermesTry --> ClaudeFallback : Timeout/Error
    HermesSuccess --> VarietyExpansion : Process
    ClaudeFallback --> VarietyExpansion : Process
    
    VarietyExpansion --> MetaSystemCheck : Check Seeds
    MetaSystemCheck --> SpawnMetaVSM : Seeds Exist
    MetaSystemCheck --> AnomalyDetection : No Seeds
    SpawnMetaVSM --> AnomalyDetection : Complete
    
    AnomalyDetection --> AdaptationCheck : Process
    AdaptationCheck --> GenerateProposal : Required
    AdaptationCheck --> AlertCheck : Not Required
    GenerateProposal --> SubmitToQueen : Send
    SubmitToQueen --> AlertCheck : Complete
    
    AlertCheck --> PublishAlert : High/Critical
    AlertCheck --> ScheduleNext : Normal
    PublishAlert --> ScheduleNext : Complete
    
    ScheduleNext --> Idle : Set Timer
```

### Environmental Scan Function Implementation
```elixir
defp perform_environmental_scan(scope, _tidewave) do
  # Base scan structure
  base_scan = %{
    market_signals: generate_market_signals(),
    technology_trends: detect_technology_trends(),
    regulatory_updates: check_regulatory_changes(),
    competitive_moves: analyze_competition(),
    timestamp: DateTime.utc_now()
  }
  
  # LLM variety amplification (optional)
  final_scan = if Application.get_env(:vsm_phoenix, :enable_llm_variety, false) do
    task = Task.async(fn ->
      try do
        LLMVarietySource.analyze_for_variety(base_scan)
      rescue
        e -> 
          Logger.error("LLM variety analysis failed: #{inspect(e)}")
          {:error, :llm_unavailable}
      end
    end)
    
    case Task.yield(task, 3000) || Task.shutdown(task) do
      {:ok, {:ok, variety_expansion}} ->
        Logger.info("🔥 LLM VARIETY EXPLOSION: #{inspect(variety_expansion)}")
        
        if variety_expansion.meta_system_seeds != %{} do
          Logger.info("🌀 RECURSIVE META-SYSTEM OPPORTUNITY DETECTED!")
          spawn(fn -> LLMVarietySource.pipe_to_system1_meta_generation(variety_expansion) end)
        end
        
        Map.merge(base_scan, %{variety_expansion: variety_expansion})
        
      _ ->
        base_scan
    end
  else
    base_scan
  end
  
  final_scan
end
```

### Market Signal Generation
```elixir
defp generate_market_signals do
  [
    %{signal: "increased_demand", strength: 0.7, source: "sales_data"},
    %{signal: "price_pressure", strength: 0.4, source: "market_analysis"},
    %{signal: "new_segment_emerging", strength: 0.6, source: "tidewave"}
  ]
end
```

## Anomaly Detection Engine

### Multi-Level Anomaly Detection Flow
```mermaid
flowchart TD
    ScanData[Scan Results] --> DetectAnom[detect_anomalies]
    
    DetectAnom --> MarketAnom[Market Anomaly Check]
    DetectAnom --> TechAnom[Technology Anomaly Check]
    DetectAnom --> RegAnom[Regulatory Anomaly Check]
    DetectAnom --> CompAnom[Competition Anomaly Check]
    DetectAnom --> VarietyAnom[Variety Anomaly Check]
    
    MarketAnom --> MarketThreshold{Threshold Check}
    TechAnom --> TechThreshold{Threshold Check}
    RegAnom --> RegThreshold{Threshold Check}
    CompAnom --> CompThreshold{Threshold Check}
    VarietyAnom --> VarietyThreshold{Threshold Check}
    
    MarketThreshold -->|Exceeded| AnomalyList[Anomaly List]
    TechThreshold -->|Exceeded| AnomalyList
    RegThreshold -->|Exceeded| AnomalyList
    CompThreshold -->|Exceeded| AnomalyList
    VarietyThreshold -->|Exceeded| AnomalyList
    
    AnomalyList --> LoopAnom{For Each<br/>Anomaly}
    
    LoopAnom --> ClassifyAnom[Classify Severity]
    ClassifyAnom --> CastQueen[GenServer.cast to Queen<br/>anomaly_detected]
    
    CastQueen --> PolicySynth[Triggers Policy<br/>Synthesis in S5]
    
    LoopAnom --> LoopAnom
    
    classDef check fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef action fill:#90EE90,stroke:#333,stroke-width:2px
    classDef decision fill:#E6E6FA,stroke:#333,stroke-width:2px
    
    class MarketAnom,TechAnom,RegAnom,CompAnom,VarietyAnom check
    class DetectAnom,ClassifyAnom,CastQueen,PolicySynth action
    class MarketThreshold,TechThreshold,RegThreshold,CompThreshold,VarietyThreshold,LoopAnom decision
```

### Anomaly Detection Implementation
```elixir
defp detect_anomalies(scan_data) do
  anomalies = []
  
  # Market signal anomalies
  market_anomalies = scan_data.market_signals
    |> Enum.filter(fn signal -> signal.strength > 0.8 end)
    |> Enum.map(fn signal -> 
      %{
        type: :market_anomaly,
        severity: calculate_severity(signal.strength),
        signal: signal,
        timestamp: DateTime.utc_now()
      }
    end)
  
  # Variety explosion detection
  variety_anomalies = if scan_data[:variety_expansion] do
    if scan_data.variety_expansion.variety_score > 0.8 do
      [%{
        type: :variety_explosion,
        severity: :critical,
        score: scan_data.variety_expansion.variety_score,
        description: "Environmental variety exceeds system capacity"
      }]
    else
      []
    end
  else
    []
  end
  
  anomalies ++ market_anomalies ++ variety_anomalies
end
```

## Adaptation Proposal Lifecycle

### Adaptation Flow from Environmental Scan
```mermaid
sequenceDiagram
    participant Scan as Environmental Scan
    participant Analysis as Scan Analysis
    participant Proposal as Proposal Generator
    participant Queen as System 5 Queen
    participant Control as System 3 Control
    participant Ops as System 1 Operations
    
    Scan->>Analysis: analyze_scan_results()
    
    Analysis->>Analysis: Check adaptation triggers
    Note over Analysis: - Variety gap > threshold<br/>- Critical anomalies<br/>- Performance degradation
    
    alt Adaptation Required
        Analysis->>Proposal: generate_internal_adaptation_proposal()
        
        Proposal->>Proposal: Select adaptation type
        Note over Proposal: - Incremental<br/>- Transformational<br/>- Defensive
        
        Proposal->>Queen: Queen.approve_adaptation(proposal)
        
        Queen->>Queen: Evaluate proposal
        
        alt Approved
            Queen->>Control: Allocate resources
            Queen->>Ops: Implement adaptation
            Control->>Ops: Resource allocation
            Ops->>Ops: Execute adaptation
            Ops->>Queen: Report completion
        else Rejected
            Queen->>Proposal: Request revision
        end
    end
```

## AMQP Alert Distribution

### Environmental Alert Message Flow
```mermaid
graph TB
    S4[System 4 Intelligence] --> AlertGen[Alert Generator]
    
    AlertGen --> AlertLevel{Alert Level<br/>Assessment}
    
    AlertLevel -->|Normal| NoPublish[No Publication]
    AlertLevel -->|High| PublishHigh[Publish High Alert]
    AlertLevel -->|Critical| PublishCrit[Publish Critical Alert]
    
    PublishHigh --> AMQP[AMQP Exchange<br/>vsm.intelligence]
    PublishCrit --> AMQP
    
    AMQP --> S5Queue[System 5 Queue]
    AMQP --> S3Queue[System 3 Queue]
    AMQP --> DashQueue[Dashboard Queue]
    
    S5Queue --> S5Handler[S5 Alert Handler]
    S3Queue --> S3Handler[S3 Resource Handler]
    DashQueue --> DashHandler[Dashboard Update]
    
    S5Handler --> PolicyTrigger[Policy Synthesis Trigger]
    S3Handler --> ResourceAdj[Resource Adjustment]
    DashHandler --> UIUpdate[UI Alert Display]
    
    classDef publisher fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef exchange fill:#E6E6FA,stroke:#333,stroke-width:2px
    classDef consumer fill:#90EE90,stroke:#333,stroke-width:2px
    
    class AlertGen,PublishHigh,PublishCrit publisher
    class AMQP exchange
    class S5Handler,S3Handler,DashHandler consumer
```

### Alert Message Structure
```elixir
%{
  type: "environmental_alert",
  level: :critical,  # :normal, :high, :critical
  source: "system4_intelligence",
  timestamp: DateTime.utc_now(),
  scan_id: "SCAN-12345",
  
  alert_data: %{
    anomaly_count: 3,
    variety_score: 0.85,
    adaptation_required: true,
    critical_signals: [
      %{type: "market_disruption", impact: 0.9},
      %{type: "variety_explosion", impact: 0.85}
    ]
  },
  
  recommendations: [
    "Spawn meta-VSM for market segment",
    "Increase resource allocation by 30%",
    "Activate defensive adaptation mode"
  ]
}
```

## Tidewave Integration Architecture

### Mock Tidewave Connection Flow
```mermaid
graph TB
    S4Init[System 4 Init] --> TideInit[init_tidewave_connection]
    
    TideInit --> MockConn[Create Mock Connection]
    MockConn --> ConnState[Connection State<br/>status: :connected<br/>endpoint: tidewave://localhost:4000]
    
    ConnState --> S4State[Store in S4 State]
    
    S4State --> ScanCall[Environmental Scan Called]
    ScanCall --> TideParam[_tidewave Parameter]
    
    TideParam -->|Ignored| InternalGen[Internal Data Generation]
    
    Note over TideParam,InternalGen: Parameter exists but unused
    
    InternalGen --> MarketGen[generate_market_signals]
    MarketGen --> TideRef[One signal references<br/>source: tidewave]
    
    subgraph "Future Integration Point"
        FutureTide[Real Tidewave API]
        FutureTide -.-> MarketData[Market Intelligence]
        FutureTide -.-> Insights[Business Insights]
        FutureTide -.-> Predictions[Predictive Analytics]
    end
    
    classDef current fill:#90EE90,stroke:#333,stroke-width:2px
    classDef mock fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef future fill:#E6E6FA,stroke:#333,stroke-width:2px,stroke-dasharray: 5 5
    
    class S4Init,ScanCall current
    class TideInit,MockConn,ConnState,TideParam mock
    class FutureTide,MarketData,Insights,Predictions future
```

## Performance Monitoring

### Scan Performance Metrics
```mermaid
graph LR
    Scan[Environmental Scan] --> Metrics[Performance Metrics]
    
    Metrics --> Frequency[Scan Frequency<br/>Fixed: 60s]
    Metrics --> Duration[Scan Duration<br/>~1s typical]
    Metrics --> LLMLatency[LLM Latency<br/>2-3s when enabled]
    Metrics --> Memory[Memory Usage<br/>Minimal, no persistence]
    
    Duration --> Components[Component Timing]
    Components --> GenTime[Data Generation: ~100ms]
    Components --> LLMTime[LLM Analysis: 2-3s]
    Components --> AnomalyTime[Anomaly Detection: ~50ms]
    Components --> AlertTime[Alert Publishing: ~20ms]
    
    LLMLatency --> Timeouts[Timeout Settings]
    Timeouts --> HermesTO[Hermes MCP: 2s]
    Timeouts --> VarietyTO[Variety Task: 3s]
    
    Memory --> Storage[Data Storage]
    Storage --> NoCache[No result caching]
    Storage --> NoHistory[No scan history]
    Storage --> Ephemeral[Ephemeral only]
```

## Configuration and Deployment

### System Configuration
```elixir
# In config/config.exs or runtime.exs
config :vsm_phoenix,
  # LLM Variety Analysis
  enable_llm_variety: false,  # Set to true to enable
  
  # API Keys (if LLM enabled)
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  
  # Tidewave (placeholder for future)
  tidewave_api_key: nil,
  tidewave_endpoint: "tidewave://localhost:4000",
  
  # Scanning Configuration
  environmental_scan_interval: 60_000,  # Fixed at 60 seconds
  
  # Anomaly Thresholds
  market_anomaly_threshold: 0.8,
  variety_explosion_threshold: 0.8,
  
  # Alert Levels
  alert_publication_levels: [:high, :critical]
```

### Enabling LLM Variety Analysis
```bash
# Set environment variable
export ANTHROPIC_API_KEY="your-api-key"

# Enable in config
config :vsm_phoenix, enable_llm_variety: true
```

## Implementation Files

### Core Components
- **Environmental Scanner**: `/lib/vsm_phoenix/system4/intelligence.ex`
  - Main scanning loop and coordination
  - Anomaly detection logic
  - Adaptation proposal generation
  
- **LLM Variety Source**: `/lib/vsm_phoenix/system4/llm_variety_source.ex`
  - Hermes MCP integration
  - Claude API fallback
  - Variety pattern extraction
  - Meta-system spawning triggers

### Data Generators
- **Market Signals**: `generate_market_signals/0` in `intelligence.ex`
- **Technology Trends**: `detect_technology_trends/0` in `intelligence.ex`
- **Regulatory Updates**: `check_regulatory_changes/0` in `intelligence.ex`
- **Competition Analysis**: `analyze_competition/0` in `intelligence.ex`

### Integration Points
- **AMQP Publishing**: `publish_environmental_alert/1` via `vsm.intelligence` exchange
- **Queen Integration**: Direct GenServer calls for anomaly reporting
- **S1 Integration**: Meta-system spawning via `Operations.spawn_meta_system/1`

## Advanced Features

### Recursive VSM Spawning
When environmental variety exceeds system capacity:
1. LLM analysis detects variety explosion
2. Meta-system seeds are generated
3. System 1 spawns a new VSM with its own S3-4-5
4. New VSM specializes in handling specific variety domain
5. Parent and child VSMs coordinate via AMQP

### Policy Synthesis Integration
Environmental anomalies trigger automatic policy generation:
1. Anomalies sent to System 5 Queen
2. Queen invokes PolicySynthesizer
3. LLM generates context-appropriate policies
4. Policies distributed via AMQP to all systems

### Future Enhancement Opportunities
1. **Real Tidewave Integration**: Connect to actual market intelligence API
2. **Adaptive Scanning**: Vary frequency based on environmental volatility
3. **Historical Analysis**: Store and analyze scan history for trends
4. **External API Integration**: Connect to real regulatory and competitive data sources
5. **Advanced Anomaly Detection**: Machine learning-based pattern recognition
6. **Distributed Scanning**: Multiple S4 instances for different domains

This environmental scanning system provides VSM with comprehensive situational awareness, enabling proactive adaptation and maintaining requisite variety for effective cybernetic control.