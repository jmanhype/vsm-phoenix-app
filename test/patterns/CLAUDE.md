# Test Patterns Directory

Test templates and guides for consistent testing across VSM Phoenix.

## Files in this directory:

- `integration_testing_guide.md` - Guide for writing integration tests
- `testing_patterns_analysis.md` - Analysis of testing patterns and best practices
- `telegram_agent_test_template.exs` - Template for testing Telegram agents
- `variety_aggregator_test_template.exs` - Template for testing variety aggregators
- `variety_filter_test_template.exs` - Template for testing variety filters

## Purpose:
Provides reusable templates and patterns to ensure consistent test coverage across all VSM components. These templates help developers:
- Write tests following established patterns
- Ensure comprehensive coverage
- Maintain consistency across test suites
- Speed up test development

## Using Templates:
```elixir
# Copy a template for your new component
cp test/patterns/variety_filter_test_template.exs test/vsm_phoenix/my_new_filter_test.exs

# Replace placeholders with your module names
# Follow the established test patterns
```

## Test Pattern Categories:
- Agent testing patterns
- Filter/Aggregator patterns
- Integration test patterns
- Performance test patterns
- Security test patterns

## Best Practices:
- Use ExUnit tags for test categorization
- Include both success and failure cases
- Test edge cases and error handling
- Mock external dependencies
- Use test factories for data generation