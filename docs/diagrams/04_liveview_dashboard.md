# LiveView Dashboard Architecture

## Overview
This diagram shows the Phoenix LiveView dashboard implementation with real PubSub channels, working algedonic signal display, and comprehensive system monitoring. The dashboard uses direct GenServer calls for data fetching rather than event streaming.

```mermaid
graph TB
    subgraph "Phoenix LiveView Frontend"
        Dashboard[VSM Dashboard LiveView<br/>vsm_dashboard_live.ex]
        
        subgraph "Implemented Components"
            SystemCards[System Status Cards<br/>S5-S1 Metrics]
            AlgedonicList[Algedonic Signal List<br/>Recent 20 Signals]
            AlertPanel[System Alerts<br/>Last 10 Alerts]
            AgentGrid[S1 Agent Registry<br/>Live Agent List]
            AuditPanel[S3 Audit Results<br/>Efficiency Metrics]
            PulseRates[Algedonic Pulse Rates<br/>Per Agent Hz]
            LatencyMetrics[Command Latency<br/>Avg/P95/P99]
        end

        subgraph "Real-time Features"
            AutoUpdate[5s Update Timer<br/>:update_dashboard]
            LatencyUpdate[1s Latency Timer<br/>:update_latency_metrics]
            WebSocketConn[WebSocket<br/>Connection]
        end
    end

    subgraph "PubSub System"
        PubSubCore[Phoenix.PubSub<br/>VsmPhoenix.PubSub]
        
        subgraph "Active Subscription Channels"
            HealthChan["vsm:health"]
            MetricsChan["vsm:metrics"]
            CoordChan["vsm:coordination"]
            PolicyChan["vsm:policy"]
            AlgChan["vsm:algedonic"]
            RegChan["vsm.registry.events"]
            AMQPChan["vsm:amqp"]
        end
    end

    subgraph "Data Sources (Direct GenServer Calls)"
        subgraph "System 5 Data"
            QueenCalls[Queen.get_identity_metrics()<br/>Queen.evaluate_viability()]
        end

        subgraph "System 4 Data"
            IntelCalls[Intelligence.get_system_health()]
        end

        subgraph "System 3 Data"
            ControlCalls[Control.get_resource_metrics()<br/>Control.audit_resource_usage()]
        end

        subgraph "System 2 Data"
            CoordCalls[Coordinator.get_coordination_status()]
        end

        subgraph "System 1 Data"
            OpsCalls[GenServer.call(:operations_context, :get_metrics)<br/>Registry.list_agents()]
        end
    end

    subgraph "Handle_info Patterns"
        UpdateDash[":update_dashboard" => Full refresh]
        UpdateLat[":update_latency_metrics" => Latency only]
        AgentReg["{:agent_registered, ...}" => Update agents]
        AgentUnreg["{:agent_unregistered, ...}" => Update agents]
        AgentCrash["{:agent_crashed, ...}" => Alert + Update]
        AlgSignal["{:algedonic_signal, ...}" => Signal list]
        PolicyUp["{:policy_update, ...}" => Policy alert]
        ViabilityUp["{:viability_update, ...}" => Viability score]
    end

    %% Dashboard to Components
    Dashboard --> SystemCards
    Dashboard --> AlgedonicList
    Dashboard --> AlertPanel
    Dashboard --> AgentGrid
    Dashboard --> AuditPanel
    Dashboard --> PulseRates
    Dashboard --> LatencyMetrics

    %% Real-time Infrastructure
    Dashboard <--> WebSocketConn
    Dashboard --> AutoUpdate
    Dashboard --> LatencyUpdate

    %% PubSub Subscriptions
    Dashboard --> PubSubCore
    PubSubCore --> HealthChan
    PubSubCore --> MetricsChan
    PubSubCore --> CoordChan
    PubSubCore --> PolicyChan
    PubSubCore --> AlgChan
    PubSubCore --> RegChan
    PubSubCore --> AMQPChan

    %% Direct GenServer Calls (No PubSub!)
    SystemCards --> QueenCalls
    SystemCards --> IntelCalls
    SystemCards --> ControlCalls
    SystemCards --> CoordCalls
    SystemCards --> OpsCalls
    
    AgentGrid --> OpsCalls
    AuditPanel --> ControlCalls

    %% Handle_info routing
    RegChan --> AgentReg
    RegChan --> AgentUnreg
    RegChan --> AgentCrash
    AlgChan --> AlgSignal
    PolicyChan --> PolicyUp
    
    UpdateDash --> SystemCards
    UpdateLat --> LatencyMetrics
    ViabilityUp --> SystemCards
    AlgSignal --> AlgedonicList

    %% Styling
    classDef dashboard fill:#e1f5fe,stroke:#333,stroke-width:3px
    classDef component fill:#90EE90,stroke:#333,stroke-width:2px
    classDef pubsub fill:#e8f5e8,stroke:#333,stroke-width:2px
    classDef channel fill:#FFE4B5,stroke:#333,stroke-width:2px
    classDef datasource fill:#fce4ec,stroke:#333,stroke-width:2px
    classDef handler fill:#E6E6FA,stroke:#333,stroke-width:2px

    class Dashboard dashboard
    class SystemCards,AlgedonicList,AlertPanel,AgentGrid,AuditPanel,PulseRates,LatencyMetrics component
    class PubSubCore pubsub
    class HealthChan,MetricsChan,CoordChan,PolicyChan,AlgChan,RegChan,AMQPChan channel
    class QueenCalls,IntelCalls,ControlCalls,CoordCalls,OpsCalls datasource
    class UpdateDash,UpdateLat,AgentReg,AgentUnreg,AgentCrash,AlgSignal,PolicyUp,ViabilityUp handler
```

## Implementation Details

### Dashboard Components

#### System Status Cards
Each system (S5-S1) has its own card displaying:
- **System 5**: Policy coherence, identity preservation, strategic alignment, active policies
- **System 4**: Environmental scan coverage, adaptation readiness, innovation index
- **System 3**: Resource efficiency, utilization, active allocations, resource bars (CPU/Memory/Network/Storage)
- **System 2**: Coordination effectiveness, message flows, synchronization level, oscillation risks
- **System 1**: Success rate, orders processed, customer satisfaction, inventory accuracy

#### Real-time Updates
```elixir
# 5-second full dashboard refresh
:timer.send_interval(5000, self(), :update_dashboard)

# 1-second latency metrics update
:timer.send_interval(1000, self(), :update_latency_metrics)
```

### PubSub Channels

**Actual Channels**:
- `"vsm:health"` - Health reports from contexts
- `"vsm:metrics"` - General metrics updates  
- `"vsm:coordination"` - Coordination events
- `"vsm:policy"` - Policy updates
- `"vsm:algedonic"` - Algedonic signals
- `"vsm.registry.events"` - Agent registry changes
- `"vsm:amqp"` - AMQP events

### Data Flow Pattern

Instead of systems publishing to PubSub, the dashboard uses **direct GenServer calls** on timers:

```elixir
defp update_system_metrics(socket) do
  # Direct calls - no fallbacks, fail fast
  queen_metrics = Queen.get_identity_metrics()
  intelligence_status = Intelligence.get_system_health()
  control_metrics = Control.get_resource_metrics()
  coordination_status = Coordinator.get_coordination_status()
  operations_metrics = GenServer.call(:operations_context, :get_metrics)
  
  socket
  |> assign(:queen_metrics, queen_metrics)
  |> assign(:intelligence_status, intelligence_status)
  # ... etc
end
```

### Algedonic Signal Display

```elixir
def handle_info({:algedonic_signal, signal}, socket) do
  # Add to recent list (keep last 20)
  new_signals = [signal | socket.assigns.algedonic_signals] |> Enum.take(20)
  
  # Create alert for significant signals (delta > 0.2)
  socket = if abs(signal.delta) > 0.2 do
    alert = %{
      type: signal.signal_type,
      message: "#{signal.signal_type} signal from #{signal.context}: delta #{signal.delta}",
      severity: if(signal.signal_type == :pain, do: :warning, else: :info)
    }
    assign(socket, :alerts, [alert | socket.assigns.alerts] |> Enum.take(10))
  end
end
```

### S1 Agent Registry Display

**Working Features**:
- Live agent count
- Agent status indicators (green/red dots)
- Agent metadata (zone)
- Limited to showing first 10 agents
- Updates on registry events

**Registry Events**:
```elixir
{:agent_registered, agent_id, pid, metadata}
{:agent_unregistered, agent_id}
{:agent_crashed, agent_id, reason}
```

### Interactive Features

**Implemented**:
- ✅ "Refresh" button - Triggers full update
- ✅ "Clear All" alerts button
- ✅ "Trigger Adaptation" button - Actually works!

**Not Implemented**:
- ❌ Agent restart/inspect buttons (UI only)
- ❌ Manual resource adjustments
- ❌ Policy management controls
- ❌ Data export features
- ❌ Performance charts (Canvas elements exist but no JS hooks)

### UI Layout

The dashboard uses a **3-column grid** layout with cards:
- System status cards (S5, S4, S3, S2, S1)
- S1 Agent Registry
- S3 Audit Results  
- Algedonic Pulse Rates
- Command Latency
- Algedonic Signals (spans 2 columns)

### Real Viability Display

```elixir
# Viability score with color coding
<div class={["text-lg font-bold", viability_color(@viability_score)]}>
  <%= :erlang.float_to_binary(@viability_score * 100, [decimals: 1]) %>%
</div>

# Color coding
defp viability_color(score) when score >= 0.8, do: "text-green-400"
defp viability_color(score) when score >= 0.6, do: "text-yellow-400"  
defp viability_color(_), do: "text-red-400"
```

## File Structure

```
lib/vsm_phoenix_web/
├── live/
│   └── vsm_dashboard_live.ex  # Entire dashboard (1012 lines)
├── router.ex                   # Route: live "/dashboard", VSMDashboardLive
└── templates/                  # No dashboard-specific templates
```

## Performance Characteristics

- **Update Frequency**: 5-second full refresh (not optimal)
- **Data Fetching**: Synchronous GenServer calls (blocking)
- **Memory Usage**: Keeps last 20 algedonic signals, 10 alerts
- **Connection Recovery**: Phoenix LiveView handles reconnection
- **Error Handling**: Direct calls with no fallbacks (fail fast)

## Implementation Status

### Working Features ✅
- System status display for all 5 levels
- Algedonic signal list with alerts
- Agent registry with live updates
- S3 audit results display
- Command latency metrics
- Real-time updates via timers
- WebSocket connection management
- Interactive "Trigger Adaptation" button

### Simplified Architecture 🟨
- No separate LiveComponents, everything in one file
- Direct GenServer calls instead of PubSub streaming
- Full refresh every 5 seconds instead of selective updates
- No component caching or batch processing

### Not Implemented ❌
- JavaScript hooks for charts
- Telemetry integration
- Advanced interactive controls
- Data export functionality
- Manual resource adjustments
- Component-based architecture

## Key Insights

1. **Simpler Architecture**: Direct GenServer calls instead of PubSub event streaming
2. **Working Core**: Displays real system data despite architectural differences
3. **Missing Polish**: No components, hooks, or advanced features
4. **Functional UI**: Tailwind styling provides good visual design
5. **Real Integration**: Actually triggers system actions (adaptation)

This dashboard provides real-time visibility into the cybernetic VSM system, enabling operators to monitor and manage the autonomous implementation with essential situational awareness.