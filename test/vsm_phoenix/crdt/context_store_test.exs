defmodule VsmPhoenix.CRDT.ContextStoreTest do
  use ExUnit.Case, async: false
  
  alias VsmPhoenix.CRDT.{ContextStore, GCounter, PNCounter, ORSet, LWWElementSet}
  
  setup do
    # Ensure clean state
    :ok
  end
  
  describe "CRDT Context Store" do
    test "initializes with empty state" do
      {:ok, state} = ContextStore.get_state()
      
      assert state.node_id != nil
      assert state.gcounters == %{}
      assert state.pncounters == %{}
      assert state.orsets == %{}
      assert state.lww_sets == %{}
    end
    
    test "increments G-Counter correctly" do
      key = "test_counter_#{:rand.uniform(1000)}"
      
      {:ok, value1} = ContextStore.increment_counter(key, 5)
      assert value1 == 5
      
      {:ok, value2} = ContextStore.increment_counter(key, 3)
      assert value2 == 8
      
      {:ok, retrieved} = ContextStore.get(key)
      assert retrieved == 8
    end
    
    test "handles PN-Counter increment and decrement" do
      key = "test_pn_counter_#{:rand.uniform(1000)}"
      
      {:ok, value1} = ContextStore.update_pn_counter(key, 10)
      assert value1 == 10
      
      {:ok, value2} = ContextStore.update_pn_counter(key, -3)
      assert value2 == 7
      
      {:ok, value3} = ContextStore.update_pn_counter(key, -10)
      assert value3 == -3
    end
    
    test "manages OR-Set operations" do
      key = "test_set_#{:rand.uniform(1000)}"
      
      {:ok, set1} = ContextStore.add_to_set(key, "item1")
      assert MapSet.member?(set1, "item1")
      
      {:ok, set2} = ContextStore.add_to_set(key, "item2")
      assert MapSet.member?(set2, "item1")
      assert MapSet.member?(set2, "item2")
      
      {:ok, set3} = ContextStore.remove_from_set(key, "item1")
      assert not MapSet.member?(set3, "item1")
      assert MapSet.member?(set3, "item2")
    end
    
    test "handles LWW-Element-Set operations" do
      key = "test_lww_#{:rand.uniform(1000)}"
      
      {:ok, "value1"} = ContextStore.set_lww(key, "value1")
      {:ok, retrieved1} = ContextStore.get(key)
      assert retrieved1 == [{key, "value1"}]
      
      # Update with new value
      {:ok, "value2"} = ContextStore.set_lww(key, "value2")
      {:ok, retrieved2} = ContextStore.get(key)
      assert retrieved2 == [{key, "value2"}]
    end
    
    test "merges states correctly" do
      # Create a simulated remote state
      remote_state = %{
        node_id: "remote_node",
        vector_clock: %{"remote_node" => 5},
        gcounters: %{
          "shared_counter" => %{"remote_node" => 10}
        },
        pncounters: %{},
        orsets: %{},
        lww_sets: %{}
      }
      
      # Add some local data
      {:ok, _} = ContextStore.increment_counter("shared_counter", 5)
      
      # Merge remote state
      ContextStore.merge_state(remote_state)
      
      # Allow time for async merge
      Process.sleep(100)
      
      # Check merged value
      {:ok, merged_value} = ContextStore.get("shared_counter")
      assert merged_value == 15  # 5 local + 10 remote
    end
  end
  
  describe "CRDT Type Tests" do
    test "G-Counter merge takes maximum" do
      counter1 = GCounter.new()
      |> GCounter.increment("node1", 5)
      |> GCounter.increment("node2", 3)
      
      counter2 = GCounter.new()
      |> GCounter.increment("node1", 2)
      |> GCounter.increment("node2", 7)
      
      merged = GCounter.merge(counter1, counter2)
      
      assert GCounter.value(merged) == 12  # max(5,2) + max(3,7) = 5 + 7
    end
    
    test "PN-Counter handles negative values" do
      counter = PNCounter.new()
      |> PNCounter.increment("node1", 10)
      |> PNCounter.decrement("node1", 15)
      
      assert PNCounter.value(counter) == -5
    end
    
    test "OR-Set handles concurrent add/remove" do
      set1 = ORSet.new()
      |> ORSet.add("item", "node1")
      
      set2 = ORSet.new()
      |> ORSet.add("item", "node2")
      |> ORSet.remove("item")
      
      merged = ORSet.merge(set1, set2)
      
      # Item should exist because node1's add is concurrent with node2's remove
      assert ORSet.member?(merged, "item")
    end
    
    test "LWW-Element-Set respects timestamps" do
      now = :erlang.system_time(:microsecond)
      
      set = LWWElementSet.new()
      |> LWWElementSet.add("key", now, "node1")
      |> LWWElementSet.remove("key", now + 1000, "node2")
      |> LWWElementSet.add("key", now + 500, "node3")
      
      # Remove at now+1000 wins over add at now+500
      assert not LWWElementSet.member?(set, "key")
    end
  end
  
  describe "Vector Clock Behavior" do
    test "vector clock increments on updates" do
      {:ok, initial_state} = ContextStore.get_state()
      initial_clock = initial_state.vector_clock[initial_state.node_id] || 0
      
      # Perform an update
      ContextStore.increment_counter("clock_test", 1)
      
      {:ok, updated_state} = ContextStore.get_state()
      updated_clock = updated_state.vector_clock[updated_state.node_id]
      
      assert updated_clock == initial_clock + 1
    end
  end
end