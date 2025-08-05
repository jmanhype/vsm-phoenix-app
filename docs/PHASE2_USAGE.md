# Phase 2 Advanced VSM Cybernetics - Usage Guide

## Overview

Phase 2 introduces advanced cybernetic capabilities to the VSM Phoenix system, including:
- **GoldRush Pattern Detection**: Complex event pattern matching and aggregation
- **Telegram NLU**: Natural language understanding for conversational commands
- **AMQP Security**: Enhanced messaging security with encryption and signatures
- **LLM Integration**: Intelligent analysis and variety amplification

## Table of Contents

1. [GoldRush Pattern Syntax](#goldrush-pattern-syntax)
2. [Telegram NLU Usage](#telegram-nlu-usage)
3. [Security Configuration](#security-configuration)
4. [LLM Prompt Engineering](#llm-prompt-engineering)
5. [Integration Examples](#integration-examples)

## GoldRush Pattern Syntax

### Basic Pattern Structure

```json
{
  "name": "high_cpu_alert",
  "category": "performance",
  "type": "simple",
  "expressions": [
    {
      "field": "cpu_usage",
      "operator": "greater_than",
      "value": 80
    }
  ],
  "actions": ["notify_ops", "trigger_scaling"]
}
```

### Supported Operators

- **Comparison**: `equals`, `not_equals`, `greater_than`, `less_than`, `greater_or_equal`, `less_or_equal`
- **String**: `contains`, `starts_with`, `ends_with`, `matches_regex`
- **List**: `in`, `not_in`, `contains_any`, `contains_all`
- **Temporal**: `within_last`, `outside_last`, `change_rate`, `trending`

### Complex Pattern Examples

#### 1. Composite Pattern with Multiple Conditions

```json
{
  "name": "system_overload_detection",
  "type": "composite",
  "expressions": [
    {
      "field": "cpu_usage",
      "operator": "greater_than",
      "value": 85
    },
    {
      "field": "memory_usage",
      "operator": "greater_than",
      "value": 90
    },
    {
      "field": "response_time",
      "operator": "greater_than",
      "value": 1000,
      "unit": "milliseconds"
    }
  ],
  "logic": "AND",
  "time_window": {
    "duration": 5,
    "unit": "minutes"
  },
  "aggregations": [
    {
      "function": "avg",
      "field": "cpu_usage",
      "window": "5m",
      "threshold": 80
    }
  ],
  "alerts": [
    {
      "condition": "match_count > 3",
      "action": "escalate_to_system5",
      "severity": "critical"
    }
  ]
}
```

#### 2. Temporal Pattern for Trend Detection

```json
{
  "name": "variety_degradation_trend",
  "type": "temporal",
  "expressions": [
    {
      "field": "variety_index",
      "operator": "trending",
      "value": "decreasing",
      "window": "15m",
      "rate": -0.1
    }
  ],
  "correlation": {
    "with": ["error_rate", "latency"],
    "window": "10m"
  },
  "actions": ["amplify_variety", "notify_system4"]
}
```

#### 3. Cross-System Pattern

```json
{
  "name": "cascade_failure_detection",
  "type": "distributed",
  "expressions": [
    {
      "system": "system1",
      "field": "error_rate",
      "operator": "greater_than",
      "value": 0.05
    },
    {
      "system": "system2",
      "field": "sync_failures",
      "operator": "greater_than",
      "value": 10,
      "delay": "30s"
    },
    {
      "system": "system3",
      "field": "optimization_status",
      "operator": "equals",
      "value": "failed",
      "delay": "60s"
    }
  ],
  "sequence": "ordered",
  "actions": ["emergency_response", "isolate_systems"]
}
```

### Pattern API Usage

#### Create a Pattern
```bash
curl -X POST http://localhost:4000/api/goldrush/patterns \
  -H "Content-Type: application/json" \
  -d '{
    "name": "high_variety_deficit",
    "expressions": [
      {"field": "variety_ratio", "operator": "less_than", "value": 0.6}
    ],
    "actions": ["trigger_llm_analysis"]
  }'
```

#### Test a Pattern
```bash
curl -X POST http://localhost:4000/api/goldrush/test \
  -H "Content-Type: application/json" \
  -d '{
    "pattern": {
      "expressions": [
        {"field": "cpu", "operator": "greater_than", "value": 80}
      ],
      "logic": "AND"
    },
    "event": {
      "cpu": 85,
      "memory": 70
    }
  }'
```

## Telegram NLU Usage

### Natural Language Command Examples

#### System Status Queries
```
/natural Show me the overall system health
/natural What's the current variety level in System 4?
/natural Are there any algedonic signals active?
/natural Display System 3 optimization status
```

#### Pattern and Alert Management
```
/natural Set an alert if CPU usage exceeds 80% for more than 5 minutes
/natural Show me all active patterns matching "performance"
/natural Disable the high memory alert temporarily
/natural What patterns triggered in the last hour?
```

#### Variety Analysis
```
/natural Analyze variety requirements for System 2
/natural Compare variety levels across all systems
/natural Suggest variety amplification strategies
/natural What's causing the variety deficit in operations?
```

#### Complex Queries
```
/natural Correlate error rates with variety levels over the past 24 hours
/natural Show me the trend of algedonic signals this week
/natural Predict system load for the next hour based on current patterns
/natural Analyze the cascade effect of the last System 1 failure
```

### Conversation Context

The NLU system maintains conversation context, allowing follow-up questions:

```
User: Show me System 4 status
Bot: System 4 - Intelligence: Variety: 0.75, Adaptation: Active, Environmental Scan: Normal

User: What about its recent decisions?
Bot: System 4 recent decisions:
- 14:32: Recommended scaling based on predicted load
- 14:45: Triggered variety amplification for System 2
- 15:01: Adapted strategy based on new market data

User: Compare with yesterday
Bot: System 4 comparison (Today vs Yesterday):
- Decision Count: 47 vs 52 (-9.6%)
- Accuracy: 92% vs 89% (+3.4%)
- Response Time: 230ms vs 310ms (-25.8%)
```

### Custom Intents

You can register custom intents for domain-specific commands:

```elixir
# In your configuration
config :vsm_phoenix, :telegram_nlu,
  custom_intents: [
    %{
      name: "deployment_check",
      patterns: ["deploy", "release", "rollout"],
      handler: {MyApp.DeploymentHandler, :check_status}
    }
  ]
```

## Security Configuration

### AMQP Message Security

#### 1. Basic Configuration

```elixir
# config/config.exs
config :vsm_phoenix, :phase2,
  amqp_security: [
    enabled: true,
    encryption_algorithm: "aes-256-gcm",
    signature_algorithm: "ed25519",
    key_rotation_hours: 24,
    require_encryption: true,
    require_signatures: true
  ]
```

#### 2. Access Control Rules

```elixir
# Define access control matrix
config :vsm_phoenix, :amqp_access_control,
  rules: [
    # System 1 can send to System 2 and 3
    %{source: "system1", destinations: ["system2", "system3"], actions: :all},
    
    # System 3 can send control messages to all systems
    %{source: "system3", destinations: :all, actions: ["control", "optimize"]},
    
    # System 5 can send policy updates to all systems
    %{source: "system5", destinations: :all, actions: ["policy", "directive"]},
    
    # External sources need explicit permission
    %{source: "external", destinations: ["system4"], actions: ["data"], requires_auth: true}
  ]
```

#### 3. Message Encryption Example

```elixir
# Sending an encrypted message
message = %{
  type: "variety_request",
  data: %{system: "system2", metric: "variety_index"}
}

{:ok, encrypted} = VsmPhoenix.AMQP.SecurityProtocol.encrypt_and_sign(message)
VsmPhoenix.AMQP.Publisher.publish("vsm.system4", encrypted)
```

### Key Management

```bash
# Rotate keys manually
mix vsm.security.rotate_keys

# Check key status
mix vsm.security.key_status

# Export public keys for external systems
mix vsm.security.export_public_keys --output keys.json
```

## LLM Prompt Engineering

### Effective Prompts for VSM Analysis

#### 1. Variety Analysis Prompt Template

```elixir
defmodule VsmPhoenix.LLM.Prompts do
  def variety_analysis_prompt(system_data) do
    """
    You are a VSM (Viable System Model) expert analyzing variety requirements.
    
    Current System State:
    - System: #{system_data.system_id}
    - Current Variety: #{system_data.variety}
    - Required Variety: #{system_data.required_variety}
    - Recent Disturbances: #{inspect(system_data.disturbances)}
    
    Task: Analyze the variety gap and recommend specific amplification strategies.
    
    Consider:
    1. Environmental complexity and rate of change
    2. Current system capacity and constraints
    3. Available variety amplification mechanisms
    4. Cost-benefit of each strategy
    
    Provide response in JSON format:
    {
      "analysis": "detailed analysis",
      "variety_gap": number,
      "recommendations": [
        {"action": "action_name", "impact": 0.1, "cost": "low|medium|high"}
      ],
      "priority": "immediate|short_term|long_term"
    }
    """
  end
end
```

#### 2. Pattern Detection Enhancement

```elixir
def pattern_analysis_prompt(patterns, context) do
  """
  Analyze these detected patterns in the context of VSM operations:
  
  Patterns: #{Jason.encode!(patterns)}
  
  Context:
  - Time Range: #{context.time_range}
  - Affected Systems: #{context.systems}
  - Current Algedonic State: #{context.algedonic_state}
  
  Identify:
  1. Root causes and correlations
  2. Potential cascade effects
  3. Early warning indicators
  4. Recommended interventions
  
  Focus on systemic issues rather than symptoms.
  """
end
```

### LLM Configuration Tips

#### 1. Context Window Optimization

```elixir
# Configure context window management
config :vsm_phoenix, :llm,
  context_window_optimization: true,
  max_context_tokens: 4000,
  summary_strategy: :hierarchical,
  preserve_critical_context: ["algedonic_signals", "system_boundaries"]
```

#### 2. Multi-Model Strategies

```elixir
# Use different models for different tasks
config :vsm_phoenix, :llm_models,
  variety_analysis: %{
    provider: :openai,
    model: "gpt-4-turbo",
    temperature: 0.3  # Lower for analytical tasks
  },
  natural_language: %{
    provider: :anthropic,
    model: "claude-3-sonnet",
    temperature: 0.7  # Higher for conversational tasks
  },
  pattern_detection: %{
    provider: :openai,
    model: "gpt-4-vision",  # If analyzing visual patterns
    temperature: 0.5
  }
```

## Integration Examples

### 1. Complete Integration Flow

```elixir
defmodule MyApp.VSMIntegration do
  alias VsmPhoenix.{Goldrush, Telegram, AMQP, LLM}
  
  def automated_variety_management do
    # 1. Set up pattern for variety monitoring
    {:ok, pattern_id} = Goldrush.PatternEngine.create_pattern(%{
      name: "variety_monitor",
      expressions: [
        %{field: "variety_ratio", operator: "less_than", value: 0.7}
      ],
      actions: ["analyze_with_llm"]
    })
    
    # 2. Subscribe to pattern matches
    Goldrush.EventBus.subscribe(pattern_id, &handle_variety_deficit/1)
    
    # 3. Configure Telegram notifications
    Telegram.NLU.register_handler(
      "variety_alert",
      &send_variety_alert/1
    )
  end
  
  defp handle_variety_deficit(match) do
    # Get LLM recommendations
    {:ok, analysis} = LLM.analyze_variety(match.data)
    
    # Send secure message to System 4
    AMQP.SecurityProtocol.send_encrypted(
      to: "system4",
      type: "variety_amplification_request",
      data: analysis
    )
    
    # Notify via Telegram
    Telegram.send_message(
      "@admin",
      "🚨 Variety deficit detected: #{analysis.summary}"
    )
  end
end
```

### 2. Cross-System Pattern Correlation

```elixir
# Define correlated patterns across systems
patterns = [
  %{
    system: "system1",
    pattern: "high_error_rate",
    threshold: 0.05
  },
  %{
    system: "system3",
    pattern: "optimization_failure",
    delay: "30s"
  },
  %{
    system: "system4",
    pattern: "adaptation_timeout",
    delay: "60s"
  }
]

# Create cascade detection
{:ok, cascade_id} = Goldrush.create_cascade_pattern(
  "system_cascade_failure",
  patterns,
  actions: ["emergency_intervention", "notify_all_systems"]
)
```

### 3. Intelligent Conversation Flow

```elixir
# Telegram bot with context-aware responses
defmodule MyApp.IntelligentBot do
  use VsmPhoenix.Telegram.Handler
  
  def handle_message(message, context) do
    # Use NLU to understand intent
    {:ok, intent} = analyze_intent(message.text)
    
    # Get relevant data based on intent
    data = gather_vsm_data(intent, context)
    
    # Generate intelligent response with LLM
    {:ok, response} = generate_response(intent, data, context)
    
    # Send formatted response
    send_reply(message.chat_id, response, parse_mode: "Markdown")
  end
end
```

## Best Practices

1. **Pattern Design**: Start simple and add complexity gradually
2. **NLU Training**: Provide diverse examples for better understanding
3. **Security**: Always encrypt sensitive data and rotate keys regularly
4. **LLM Usage**: Use appropriate models and temperatures for each task
5. **Monitoring**: Set up alerts for pattern performance and LLM costs

## Troubleshooting

### Common Issues

1. **Pattern not matching**: Check operator syntax and field names
2. **NLU confusion**: Add more specific examples or adjust confidence threshold
3. **Encryption failures**: Verify key configuration and algorithm support
4. **LLM timeouts**: Reduce context size or use streaming responses

### Debug Mode

Enable debug logging for Phase 2 components:

```elixir
config :logger, :console,
  level: :debug,
  metadata: [:goldrush, :telegram_nlu, :amqp_security, :llm]
```

## Performance Considerations

- **Pattern Complexity**: Each additional condition adds ~0.1ms processing time
- **NLU Latency**: Expect 200-500ms for intent classification
- **Encryption Overhead**: AES-256-GCM adds ~2ms per message
- **LLM Response Time**: 1-3s for standard prompts, 5-10s for complex analysis

## Future Enhancements

- **Pattern Learning**: ML-based pattern discovery
- **Voice Integration**: Telegram voice message support
- **Quantum-Resistant Encryption**: Post-quantum cryptography
- **Multi-Modal LLM**: Image and chart analysis for VSM dashboards