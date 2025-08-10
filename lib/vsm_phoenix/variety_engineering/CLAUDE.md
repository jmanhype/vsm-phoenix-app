# Variety Engineering Directory

Implementation of Ashby's Law of Requisite Variety across VSM hierarchy.

## Files in this directory:

- `supervisor.ex` - Supervises variety components

## Subdirectories:
- `amplifiers/` - Increase variety from lower to higher systems
- `filters/` - Reduce variety from higher to lower systems  
- `metrics/` - Measure and monitor variety

## Purpose:
Ensures each VSM level has sufficient variety to handle its environment while preventing overload.

## Amplifiers (S→S+1):
- `s1_to_s2.ex` - Amplify S1 operational variety for S2
- `s2_to_s3.ex` - Amplify S2 coordination for S3
- `s3_to_s4.ex` - Amplify S3 control for S4
- `s4_to_s5.ex` - Amplify S4 intelligence for S5

## Filters (S→S-1):
- `s5_to_s4.ex` - Filter S5 policy to S4 directives
- `s4_to_s3.ex` - Filter S4 adaptations to S3 controls
- `s3_to_s2.ex` - Filter S3 resource decisions to S2
- `s2_to_s1.ex` - Filter S2 coordination to S1 commands

## Metrics:
- `variety_calculator.ex` - Calculate variety measures
- `balance_monitor.ex` - Monitor variety equilibrium