# Advanced aMCP Protocol Extensions - Message Flows

## 1. Agent Discovery Flow

```mermaid
sequenceDiagram
    participant A as New Agent
    participant D as Discovery Module
    participant E as AMQP Exchange
    participant O as Other Agents
    
    A->>D: announce(agent_id, capabilities)
    D->>D: Store in local_agents
    D->>E: Publish ANNOUNCE to vsm.discovery
    E->>O: Broadcast ANNOUNCE
    O->>O: Store in remote_agents
    
    loop Every 5 seconds
        D->>E: Broadcast all local agents
    end
    
    loop Every 2 seconds
        D->>E: Send HEARTBEAT
        O->>O: Update last_seen
    end
    
    Note over O: After 15s no heartbeat
    O->>O: Remove stale agent
```

## 2. Consensus Decision Flow

```mermaid
sequenceDiagram
    participant T as Telegram Bot
    participant I as Integration Layer
    participant C as Consensus Module
    participant P as Participants
    participant CA as CorticalAttention
    
    T->>I: Critical command "/restart"
    I->>CA: Calculate attention score
    CA-->>I: score: 0.85
    I->>C: propose(action, quorum: majority)
    
    C->>C: Create Proposal
    C->>P: Broadcast PROPOSE
    
    P->>P: Evaluate proposal
    Note over P: if attention_score > 0.6
    P->>C: VOTE: YES
    
    C->>C: Count votes
    alt Quorum reached
        C->>P: Broadcast COMMIT
        C-->>I: {:ok, :committed}
        I-->>T: "✅ Command approved"
    else Quorum failed
        C->>P: Broadcast ABORT
        C-->>I: {:error, :insufficient_votes}
        I-->>T: "❌ Command rejected"
    end
```

## 3. Distributed Lock Flow

```mermaid
stateDiagram-v2
    [*] --> Available
    Available --> Locked: request_lock(agent_1)
    Locked --> Contended: request_lock(agent_2)
    
    state Contended {
        [*] --> Waiting
        Waiting --> Priority_Queue
        Priority_Queue --> [*]
    }
    
    Locked --> Available: release_lock(agent_1)
    Contended --> Locked: grant_to_next_waiter
```

## 4. Network Optimization Flow

```mermaid
flowchart TD
    A[Incoming Message] --> B{Priority?}
    B -->|Critical| C[Send Immediately]
    B -->|Normal| D[Add to Batch]
    
    D --> E{Batch Full?}
    E -->|Yes| F[Compress & Send]
    E -->|No| G{Timeout?}
    G -->|Yes| F
    G -->|No| D
    
    F --> H[AMQP Channel]
    C --> H
    
    H --> I[Network]
    
    style C fill:#f96,stroke:#333,stroke-width:4px
    style F fill:#9f6,stroke:#333,stroke-width:2px
```

## 5. Security Integration Flow

```mermaid
sequenceDiagram
    participant A as Agent
    participant S as Security Layer
    participant P as Protocol
    participant N as Network
    
    A->>P: Send message
    P->>S: wrap_secure_message()
    S->>S: Generate nonce
    S->>S: Create HMAC signature
    S->>S: Add timestamp
    S-->>P: Secured message
    
    P->>N: Transmit
    
    N->>P: Receive message
    P->>S: verify_secure_message()
    S->>S: Check nonce (replay)
    S->>S: Verify HMAC
    S->>S: Check timestamp (TTL)
    
    alt Valid
        S-->>P: {:ok, payload}
        P->>A: Process message
    else Invalid
        S-->>P: {:error, reason}
        P->>P: Drop message
    end
```

## 6. Complete Telegram Command Flow

```mermaid
graph TB
    U[User: /deploy v2.0] --> T[Telegram Bot]
    T --> TC{Critical Command?}
    
    TC -->|Yes| TI[TelegramProtocolIntegration]
    TC -->|No| TE[Execute Directly]
    
    TI --> CA[CorticalAttentionEngine]
    CA --> |score: 0.9| PI[ProtocolIntegration]
    
    PI --> S[Security Wrapper]
    S --> D[Discovery: Find agents]
    
    D --> C[Consensus: Propose]
    C --> V[Voting Phase]
    
    V --> Q{Quorum?}
    Q -->|Yes| CM[COMMIT]
    Q -->|No| AB[ABORT]
    
    CM --> EX[Execute Command]
    EX --> R1[✅ Success Response]
    AB --> R2[❌ Rejected Response]
    
    R1 --> T
    R2 --> T
    T --> U
    
    style U fill:#bbf,stroke:#333,stroke-width:2px
    style CM fill:#9f6,stroke:#333,stroke-width:2px
    style AB fill:#f96,stroke:#333,stroke-width:2px
```

## Message Routing Patterns

### Discovery Exchange Routing
```
vsm.discovery
├── discovery.announce     → All agents
├── discovery.query        → Query processors
├── discovery.respond      → Query initiator
├── discovery.heartbeat    → All agents
└── discovery.goodbye      → All agents
```

### Consensus Exchange Routing
```
vsm.consensus
├── consensus.propose      → All participants
├── consensus.vote         → Proposal coordinator
├── consensus.commit       → All participants
├── consensus.abort        → All participants
├── lock.request          → Lock manager
└── lock.grant            → Waiting agents
```

## Performance Optimization Strategies

### 1. Message Batching Logic
```elixir
# Batch decision factors
batch_decision = fn message ->
  cond do
    message.priority >= 0.9 -> :send_now
    batch.message_count >= 50 -> :flush_batch
    batch.total_bytes >= 64_000 -> :flush_batch
    batch.age >= 100 -> :flush_batch
    true -> :add_to_batch
  end
end
```

### 2. Compression Strategy
```elixir
# Compression decision
compress? = fn payload ->
  byte_size(payload) > 1024 and 
  not is_already_compressed?(payload)
end
```

### 3. Gossip Propagation
```elixir
# Select random peers for gossip
peers_to_gossip = fn all_peers ->
  all_peers
  |> Enum.reject(&(&1 == self()))
  |> Enum.take_random(@gossip_fanout)
end
```

## Error Handling Patterns

### 1. Discovery Failures
- **Missing Heartbeat**: Agent marked as dead after 15s
- **Network Partition**: Gossip ensures eventual consistency
- **Invalid Announcement**: Logged and dropped

### 2. Consensus Failures
- **Timeout**: Proposal aborted, requester notified
- **Split Vote**: Follows quorum rules (majority/all)
- **Leader Failure**: New election triggered

### 3. Network Failures
- **Channel Loss**: Automatic reconnection via ConnectionManager
- **Message Loss**: Application-level acknowledgments
- **Overload**: Circuit breaker pattern prevents cascade

## Integration Points

### With Existing VSM Components

1. **CorticalAttentionEngine**
   - Calculates message priorities
   - Influences consensus voting
   - Determines batch urgency

2. **Security Infrastructure**
   - All messages HMAC signed
   - Nonce validation prevents replay
   - TTL enforcement

3. **CRDT Store**
   - State synchronization between agents
   - Conflict-free replicated data
   - Eventually consistent

4. **Causality Tracking**
   - Message correlation
   - Event chain tracking
   - Debugging support

## Monitoring and Observability

### Key Metrics to Track

```elixir
# Discovery health
- agents.discovered.count
- agents.active.count
- heartbeats.sent.rate
- gossip.messages.rate

# Consensus performance
- proposals.total.count
- proposals.accepted.rate
- consensus.latency.p99
- elections.triggered.count

# Network efficiency
- messages.batched.count
- compression.ratio.avg
- bandwidth.saved.bytes
- latency.adaptive.current

# Integration usage
- secure.operations.count
- telegram.consensus.commands
- crdt.syncs.performed
- vsm.spawns.coordinated
```

## Best Practices

1. **Always use Protocol Integration** for cross-agent coordination
2. **Set appropriate priorities** based on operation criticality
3. **Monitor consensus latency** and adjust timeouts accordingly
4. **Enable compression** for large payloads
5. **Use discovery queries** sparingly (cache results)
6. **Implement custom voting logic** for domain-specific decisions
7. **Handle all error cases** in consensus callbacks