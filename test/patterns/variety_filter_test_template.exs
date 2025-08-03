defmodule VsmPhoenix.VarietyEngineering.FilterTest do
  @moduledoc """
  Test suite for Variety Engineering Filters.
  Tests message filtering, pattern matching, and variety reduction.
  """
  
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias VsmPhoenix.VarietyEngineering.Filter
  alias VsmPhoenix.VarietyEngineering.FilterChain
  alias VsmPhoenix.MCP.VarietyAnalyzer
  
  describe "Basic filter operations" do
    test "creates filter with criteria" do
      filter = Filter.new(:type_filter, fn msg -> msg.type == :telemetry end)
      
      assert filter.name == :type_filter
      assert is_function(filter.predicate, 1)
    end
    
    test "filters messages based on predicate" do
      messages = [
        %{id: 1, type: :telemetry, value: 10},
        %{id: 2, type: :command, value: 20},
        %{id: 3, type: :telemetry, value: 30},
        %{id: 4, type: :status, value: 40}
      ]
      
      filter = Filter.new(:telemetry_only, fn msg -> msg.type == :telemetry end)
      filtered = Filter.apply(filter, messages)
      
      assert length(filtered) == 2
      assert Enum.all?(filtered, fn msg -> msg.type == :telemetry end)
    end
    
    test "handles empty message list" do
      filter = Filter.new(:any, fn _ -> true end)
      assert Filter.apply(filter, []) == []
    end
  end
  
  describe "Filter composition" do
    test "chains multiple filters" do
      filters = [
        Filter.new(:type_filter, fn msg -> msg.type == :telemetry end),
        Filter.new(:value_filter, fn msg -> msg.value > 15 end),
        Filter.new(:id_filter, fn msg -> rem(msg.id, 2) == 1 end)
      ]
      
      chain = FilterChain.new(filters)
      
      messages = [
        %{id: 1, type: :telemetry, value: 10},  # Fails value filter
        %{id: 2, type: :telemetry, value: 20},  # Fails id filter
        %{id: 3, type: :telemetry, value: 30},  # Passes all
        %{id: 4, type: :command, value: 40},    # Fails type filter
        %{id: 5, type: :telemetry, value: 25}   # Passes all
      ]
      
      result = FilterChain.apply(chain, messages)
      
      assert length(result) == 2
      assert Enum.map(result, & &1.id) == [3, 5]
    end
    
    test "preserves order in filter chain" do
      # Order matters - more selective filters first is more efficient
      filters = [
        Filter.new(:rare_filter, fn msg -> msg.rare == true end),
        Filter.new(:expensive_filter, fn msg -> 
          # Simulate expensive computation
          Process.sleep(1)
          msg.value > 50
        end)
      ]
      
      chain = FilterChain.new(filters)
      
      messages = for i <- 1..100, do: %{
        id: i,
        rare: i > 98,  # Only 2 messages are rare
        value: i
      }
      
      # Should be fast because expensive filter only runs on rare messages
      {time, result} = :timer.tc(fn ->
        FilterChain.apply(chain, messages)
      end)
      
      assert length(result) == 1  # Only message 99 passes both filters
      assert time < 5000  # Should be much faster than 100ms
    end
  end
  
  describe "Pattern-based filtering" do
    test "filters by message pattern matching" do
      pattern_filter = Filter.new(:pattern, fn
        %{type: :telemetry, sensor: sensor} when sensor in [:temperature, :pressure] -> true
        %{type: :command, action: :emergency} -> true
        _ -> false
      end)
      
      messages = [
        %{type: :telemetry, sensor: :temperature, value: 25},     # Match
        %{type: :telemetry, sensor: :humidity, value: 60},        # No match
        %{type: :command, action: :emergency, target: :shutdown}, # Match
        %{type: :command, action: :normal, target: :restart},     # No match
        %{type: :status, state: :running}                         # No match
      ]
      
      result = Filter.apply(pattern_filter, messages)
      assert length(result) == 2
    end
    
    test "complex nested pattern matching" do
      filter = Filter.new(:complex, fn
        %{data: %{readings: readings}} when is_list(readings) and length(readings) > 0 ->
          Enum.any?(readings, fn r -> r[:critical] == true end)
        _ -> false
      end)
      
      messages = [
        %{id: 1, data: %{readings: [%{value: 10, critical: false}]}},
        %{id: 2, data: %{readings: [%{value: 90, critical: true}]}},  # Match
        %{id: 3, data: %{readings: []}},
        %{id: 4, data: %{status: :ok}},
        %{id: 5, data: %{readings: [%{value: 50, critical: true}, %{value: 20}]}}  # Match
      ]
      
      result = Filter.apply(filter, messages)
      assert Enum.map(result, & &1.id) == [2, 5]
    end
  end
  
  describe "Variety reduction measurement" do
    test "measures variety before and after filtering" do
      # Generate messages with high variety
      messages = for i <- 1..1000 do
        %{
          id: i,
          type: Enum.random([:telemetry, :command, :status, :alert, :metric]),
          source: "agent_#{rem(i, 20)}",
          priority: Enum.random(1..5),
          value: :rand.uniform() * 100
        }
      end
      
      # Measure initial variety
      initial_variety = VarietyAnalyzer.calculate_message_variety(messages)
      
      # Apply filters to reduce variety
      filters = [
        Filter.new(:type, fn msg -> msg.type in [:telemetry, :alert] end),
        Filter.new(:priority, fn msg -> msg.priority >= 3 end),
        Filter.new(:source, fn msg -> String.ends_with?(msg.source, "0") end)
      ]
      
      chain = FilterChain.new(filters)
      filtered = FilterChain.apply(chain, messages)
      
      # Measure reduced variety
      reduced_variety = VarietyAnalyzer.calculate_message_variety(filtered)
      
      # Verify variety reduction
      assert reduced_variety < initial_variety
      assert length(filtered) < length(messages)
      
      # Calculate reduction percentage
      reduction_pct = (1 - reduced_variety / initial_variety) * 100
      assert reduction_pct > 50  # Should achieve > 50% variety reduction
    end
  end
  
  describe "Performance characteristics" do
    property "filter performance scales linearly with message count" do
      check all message_count <- integer(100..10_000),
                max_runs: 10 do
        
        messages = for i <- 1..message_count, do: %{id: i, value: :rand.uniform()}
        filter = Filter.new(:half, fn msg -> msg.value > 0.5 end)
        
        {time, _result} = :timer.tc(fn ->
          Filter.apply(filter, messages)
        end)
        
        # Time should scale roughly linearly
        time_per_message = time / message_count
        assert time_per_message < 10  # Less than 10 microseconds per message
      end
    end
    
    test "filter chain short-circuits on first false" do
      call_count = :counters.new(1, [:atomics])
      
      filters = [
        Filter.new(:always_false, fn _ -> false end),
        Filter.new(:counter, fn msg ->
          :counters.add(call_count, 1, 1)
          msg.value > 50
        end)
      ]
      
      chain = FilterChain.new(filters)
      messages = for i <- 1..100, do: %{id: i, value: i}
      
      _result = FilterChain.apply(chain, messages)
      
      # Second filter should never be called due to short-circuit
      assert :counters.get(call_count, 1) == 0
    end
  end
  
  describe "Statistical filters" do
    test "filters by statistical thresholds" do
      # Moving average filter
      window_size = 10
      threshold = 50
      
      moving_avg_filter = Filter.new(:moving_avg, fn messages ->
        # This is a stateful filter that needs the full list
        messages
        |> Enum.chunk_every(window_size, 1, :discard)
        |> Enum.flat_map(fn window ->
          avg = Enum.sum(Enum.map(window, & &1.value)) / length(window)
          if avg > threshold do
            [List.last(window)]
          else
            []
          end
        end)
      end)
      
      # Generate trending data
      messages = for i <- 1..100, do: %{
        id: i,
        value: i * 0.8 + :rand.uniform() * 20  # Upward trend with noise
      }
      
      result = Filter.apply_stateful(moving_avg_filter, messages)
      
      # Should start filtering in messages after the trend crosses threshold
      assert length(result) > 0
      assert length(result) < length(messages)
      assert Enum.all?(result, fn msg -> msg.id > 50 end)
    end
    
    test "outlier detection filter" do
      outlier_filter = Filter.new(:outlier, fn messages ->
        values = Enum.map(messages, & &1.value)
        mean = Enum.sum(values) / length(values)
        std_dev = :math.sqrt(
          Enum.sum(Enum.map(values, fn v -> :math.pow(v - mean, 2) end)) / length(values)
        )
        
        # Filter messages > 2 standard deviations from mean
        Enum.filter(messages, fn msg ->
          abs(msg.value - mean) > 2 * std_dev
        end)
      end)
      
      # Normal distribution with outliers
      normal_messages = for i <- 1..95, do: %{
        id: i,
        value: 50 + :rand.normal() * 10
      }
      
      outlier_messages = [
        %{id: 96, value: 150},  # High outlier
        %{id: 97, value: -50},  # Low outlier  
        %{id: 98, value: 200},  # High outlier
        %{id: 99, value: 0},    # Low outlier
        %{id: 100, value: 51}   # Normal value
      ]
      
      all_messages = normal_messages ++ outlier_messages
      result = Filter.apply_stateful(outlier_filter, all_messages)
      
      # Should detect most outliers
      outlier_ids = Enum.map(result, & &1.id)
      assert 96 in outlier_ids
      assert 97 in outlier_ids
      assert 98 in outlier_ids
      assert 99 in outlier_ids
      assert 100 not in outlier_ids
    end
  end
  
  describe "Integration with S2 Coordinator" do
    test "filters messages before coordination" do
      # Simulate S2 coordination filter
      coordination_filter = Filter.new(:s2_coordination, fn msg ->
        # Only coordinate messages that need multi-system involvement
        case msg do
          %{type: :command, scope: :global} -> true
          %{type: :alert, priority: p} when p >= 4 -> true
          %{type: :telemetry, anomaly: true} -> true
          _ -> false
        end
      end)
      
      messages = [
        %{type: :command, scope: :local, action: :restart},      # No
        %{type: :command, scope: :global, action: :shutdown},    # Yes
        %{type: :alert, priority: 3, message: "Warning"},        # No
        %{type: :alert, priority: 5, message: "Critical"},       # Yes
        %{type: :telemetry, anomaly: false, value: 50},         # No
        %{type: :telemetry, anomaly: true, value: 99}          # Yes
      ]
      
      result = Filter.apply(coordination_filter, messages)
      assert length(result) == 3
      
      # Verify only high-importance messages pass
      assert Enum.all?(result, fn msg ->
        msg.type == :command && msg.scope == :global ||
        msg.type == :alert && msg.priority >= 4 ||
        msg.type == :telemetry && msg.anomaly == true
      end)
    end
  end
end