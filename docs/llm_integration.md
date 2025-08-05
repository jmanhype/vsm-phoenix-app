# LLM Integration for VSM System 4

## Overview

The LLM integration provides System 4 (Intelligence) with advanced environmental scanning, anomaly explanation, and future scenario planning capabilities using OpenAI and Anthropic Claude APIs.

## Architecture

### Components

1. **VsmPhoenix.LLM.Client** - Unified API client with fallback support
2. **VsmPhoenix.LLM.Cache** - Semantic caching to reduce API calls
3. **VsmPhoenix.LLM.PromptTemplates** - Structured prompts for consistent outputs
4. **VsmPhoenix.System4.LLMIntelligence** - High-level intelligence functions
5. **VsmPhoenix.System4.LLMVarietySource** - Variety amplification via LLM

### Features

- **Multi-provider support**: OpenAI (GPT-4) and Anthropic (Claude) with automatic fallback
- **Rate limiting**: Prevents API rate limit violations
- **Cost tracking**: Monitors token usage and estimated costs
- **Response caching**: Semantic similarity matching reduces redundant API calls
- **Retry logic**: Exponential backoff for transient failures
- **Streaming support**: Real-time analysis of data streams

## Configuration

### Environment Variables

Add to your `.env` file:

```bash
# OpenAI API Key
OPENAI_API_KEY=sk-...

# Anthropic API Key  
ANTHROPIC_API_KEY=sk-ant-...

# Enable LLM variety analysis
ENABLE_LLM_VARIETY=true

# Rate limits (requests per minute)
LLM_RATE_LIMIT=60

# Cache TTL (hours)
LLM_CACHE_TTL=24

# Default provider (openai or anthropic)
DEFAULT_LLM_PROVIDER=openai
```

### Application Config

The system automatically loads configuration from environment variables. See `config/config.exs` for details.

## Usage

### Environmental Scanning

```elixir
# Analyze environmental scan data
scan_data = %{
  market_signals: [...],
  technology_trends: [...],
  regulatory_updates: [...],
  competitive_moves: [...]
}

{:ok, analysis} = VsmPhoenix.System4.LLMIntelligence.analyze_environmental_scan(scan_data)
```

### Anomaly Explanation

```elixir
# Explain detected anomaly
anomaly = %{
  type: :variety_explosion,
  severity: 0.8,
  description: "Unusual pattern detected",
  data: %{...}
}

{:ok, explanation} = VsmPhoenix.System4.LLMIntelligence.explain_anomaly(anomaly)
```

### Scenario Planning

```elixir
# Generate future scenarios
{:ok, scenarios} = VsmPhoenix.System4.LLMIntelligence.generate_scenarios(
  system_state,
  environmental_data
)
```

### Policy Synthesis

```elixir
# Generate new policies for System 5
{:ok, policy} = VsmPhoenix.System4.LLMIntelligence.synthesize_policy(
  anomalies,
  system_state
)
```

### Variety Amplification

```elixir
# Discover hidden patterns and variety
{:ok, variety} = VsmPhoenix.System4.LLMIntelligence.amplify_variety(
  system_data,
  known_patterns
)
```

## Prompt Templates

The system uses structured prompt templates for consistent outputs:

1. **environmental_scan** - Analyzes market signals and trends
2. **anomaly_explanation** - Provides natural language explanations
3. **scenario_planning** - Generates future scenarios
4. **policy_synthesis** - Creates new system policies
5. **variety_amplification** - Discovers hidden patterns

### Custom Templates

To add a new template:

```elixir
defmodule MyTemplate do
  def my_custom_template do
    %{
      name: "my_template",
      system_prompt: "You are an expert...",
      user_prompt: "Analyze <%= data %>...",
      output_schema: %{
        field1: "description",
        field2: "description"
      }
    }
  end
end
```

## Cost Optimization

### Strategies

1. **Caching**: Responses are cached with semantic similarity matching
2. **Model Selection**: Use appropriate models for each task
   - GPT-4 Turbo for complex analysis
   - GPT-3.5 Turbo for simple tasks
   - Claude 3 Sonnet for creative scenarios
3. **Token Limits**: Configure max_tokens per request
4. **Temperature**: Lower values for deterministic outputs

### Usage Monitoring

```elixir
# Get current usage stats
stats = VsmPhoenix.System4.LLMIntelligence.get_usage_stats()
# => %{
#   requests: %{openai: 150, anthropic: 50},
#   tokens: %{openai: %{...}, anthropic: %{...}},
#   costs: %{openai: %{total_cost: 5.43}, anthropic: %{total_cost: 2.31}},
#   rate_limits: %{openai: %{remaining: 40}, anthropic: %{remaining: 55}}
# }
```

## Error Handling

The integration handles various error scenarios:

1. **Rate Limiting**: Automatic retry with exponential backoff
2. **API Errors**: Falls back to alternative provider
3. **Network Issues**: Retry with configurable attempts
4. **Invalid Responses**: Structured data extraction fallback

## Integration with System 4

The LLM integration enhances System 4's capabilities:

1. **Environmental Scanning**: Deeper insights from scan data
2. **Anomaly Detection**: Natural language explanations
3. **Adaptation Planning**: AI-powered scenario generation
4. **Variety Management**: Discovery of hidden patterns
5. **Policy Generation**: Dynamic policy synthesis

### Workflow

1. System 4 performs regular environmental scans
2. LLM analyzes scan data for novel patterns
3. Anomalies trigger explanation generation
4. System 5 receives synthesized policies
5. Variety explosion triggers meta-system considerations

## Testing

Run tests with:

```bash
mix test test/vsm_phoenix/llm/
```

## Performance Considerations

- Cache hit rate typically 30-40% for similar queries
- Average response time: 1-3 seconds (cached: <100ms)
- Token usage varies by task complexity
- Streaming reduces perceived latency for long operations

## Security

- API keys stored in environment variables
- No sensitive data logged
- Responses sanitized before caching
- Rate limiting prevents abuse

## Future Enhancements

1. **Fine-tuned Models**: Custom models for VSM-specific tasks
2. **Multi-modal Analysis**: Image and document analysis
3. **Real-time Streaming**: Continuous environmental monitoring
4. **Advanced Caching**: Vector database for semantic search
5. **Cost Optimization**: Dynamic model selection based on complexity