# Intelligence Module Decomposition Plan

## Phase 2B: Decompose Intelligence God Object

### Overview
The Intelligence module (915 lines) is being decomposed into three focused modules:
- **Scanner**: Environmental data collection and external integration
- **Analyzer**: Pattern detection, trend analysis, and anomaly detection
- **AdaptationEngine**: Adaptation proposal generation, implementation, and monitoring

### Current Architecture Issues
- Single Responsibility Principle violation
- Difficult to test individual components
- Complex state management
- High coupling between scanning, analysis, and adaptation

### New Architecture Benefits
- Clear separation of concerns
- Easier testing and maintenance
- Better scalability
- Reduced coupling

## Implementation Strategy

### Phase 1: Create New Modules (COMPLETED)
✅ Created Scanner module (`intelligence/scanner.ex`)
✅ Created Analyzer module (`intelligence/analyzer.ex`)
✅ Created AdaptationEngine module (`intelligence/adaptation_engine.ex`)
✅ Created coordinator module (`intelligence_refactored.ex`)

### Phase 2: Gradual Migration
1. **Update Application Supervisor**
   - Add new modules to supervision tree
   - Keep old Intelligence module running initially

2. **Feature Flag Implementation**
   ```elixir
   config :vsm_phoenix, :use_refactored_intelligence, false
   ```

3. **Dual-Mode Operation**
   - Route calls through coordinator based on feature flag
   - Test in parallel with existing system

### Phase 3: Migration Steps

#### Step 1: Update Supervisor
```elixir
# In lib/vsm_phoenix/application.ex
children = [
  # ... existing children ...
  {VsmPhoenix.System4.Intelligence.Scanner, []},
  {VsmPhoenix.System4.Intelligence.Analyzer, []},
  {VsmPhoenix.System4.Intelligence.AdaptationEngine, []},
  # Conditionally start based on feature flag
  if Application.get_env(:vsm_phoenix, :use_refactored_intelligence, false) do
    {VsmPhoenix.System4.IntelligenceRefactored, name: VsmPhoenix.System4.Intelligence}
  else
    {VsmPhoenix.System4.Intelligence, []}
  end
]
```

#### Step 2: Update References
Modules that reference Intelligence:
- `VsmPhoenix.System5.Queen`
- `VsmPhoenix.System3.Control`
- Any AMQP message handlers

No changes needed - the refactored module maintains the same API.

#### Step 3: Testing Strategy
1. Unit tests for each new module
2. Integration tests for module communication
3. A/B testing with feature flag
4. Performance comparison

#### Step 4: Data Migration
- Scanner: Maintains own scan history
- Analyzer: Maintains pattern detection history
- AdaptationEngine: Maintains adaptation history
- Coordinator: Maintains AMQP and overall metrics

### Phase 4: Cutover Plan

1. **Pre-cutover Checklist**
   - [ ] All tests passing
   - [ ] Performance metrics equal or better
   - [ ] No AMQP message loss
   - [ ] State persistence verified

2. **Cutover Steps**
   ```bash
   # 1. Enable feature flag in staging
   config :vsm_phoenix, :use_refactored_intelligence, true
   
   # 2. Monitor for 24 hours
   # 3. Enable in production during low-traffic period
   # 4. Remove old Intelligence module after 1 week
   ```

3. **Rollback Plan**
   - Disable feature flag
   - Old module resumes operation
   - No data loss due to parallel operation

### Phase 5: Cleanup
1. Remove old Intelligence module
2. Remove feature flag
3. Update documentation
4. Archive migration artifacts

## Risk Mitigation

### Identified Risks
1. **AMQP Message Loss**
   - Mitigation: Dual consumption during transition
   
2. **State Inconsistency**
   - Mitigation: Shared state through coordinator
   
3. **Performance Degradation**
   - Mitigation: Benchmark before/after
   
4. **API Breaking Changes**
   - Mitigation: Maintain exact same public API

### Monitoring During Migration
- Log all module transitions
- Track message processing times
- Monitor memory usage
- Alert on any errors

## Success Criteria
- [ ] All existing functionality preserved
- [ ] Response times within 5% of original
- [ ] Memory usage reduced by at least 10%
- [ ] Test coverage increased to 90%+
- [ ] No production incidents during migration

## Timeline
- Week 1: Module creation and testing ✅
- Week 2: Integration testing and performance tuning
- Week 3: Staging deployment and monitoring
- Week 4: Production deployment and stabilization
- Week 5: Cleanup and documentation

## Communication Plan
1. Notify team of migration start
2. Daily status updates during active migration
3. Post-mortem after completion

## Notes
- The refactored architecture follows the Single Responsibility Principle
- Each module can be independently scaled if needed
- Future enhancements can be added to specific modules without affecting others
- The coordinator pattern allows for easy addition of new analysis or adaptation strategies