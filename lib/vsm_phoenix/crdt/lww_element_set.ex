defmodule VsmPhoenix.CRDT.LWWElementSet do
  @moduledoc """
  Last-Write-Wins Element Set (LWW-Element-Set) CRDT implementation.
  
  An LWW-Element-Set uses timestamps to resolve conflicts. When the same
  element is added/removed concurrently, the operation with the highest
  timestamp wins. In case of timestamp ties, node_id is used as tiebreaker.
  """
  
  @type element :: term()
  @type timestamp :: non_neg_integer()
  @type node_id :: term()
  @type entry :: {timestamp(), node_id()}
  @type t :: %{
    add_set: %{element() => entry()},
    remove_set: %{element() => entry()}
  }
  
  @doc """
  Create a new empty LWW-Element-Set
  """
  @spec new() :: t()
  def new do
    %{
      add_set: %{},
      remove_set: %{}
    }
  end
  
  @doc """
  Add an element to the set
  """
  @spec add(t(), element(), timestamp(), node_id()) :: t()
  def add(set, element, timestamp, node_id) do
    entry = {timestamp, node_id}
    
    add_set = case Map.get(set.add_set, element) do
      nil -> 
        Map.put(set.add_set, element, entry)
      {old_ts, old_node} = old_entry ->
        if compare_entries(entry, old_entry) == :after do
          Map.put(set.add_set, element, entry)
        else
          set.add_set
        end
    end
    
    %{set | add_set: add_set}
  end
  
  @doc """
  Remove an element from the set
  """
  @spec remove(t(), element(), timestamp(), node_id()) :: t()
  def remove(set, element, timestamp, node_id) do
    entry = {timestamp, node_id}
    
    remove_set = case Map.get(set.remove_set, element) do
      nil -> 
        Map.put(set.remove_set, element, entry)
      {old_ts, old_node} = old_entry ->
        if compare_entries(entry, old_entry) == :after do
          Map.put(set.remove_set, element, entry)
        else
          set.remove_set
        end
    end
    
    %{set | remove_set: remove_set}
  end
  
  @doc """
  Get all elements currently in the set
  """
  @spec value(t()) :: MapSet.t(element())
  def value(set) do
    set.add_set
    |> Enum.filter(fn {element, add_entry} ->
      case Map.get(set.remove_set, element) do
        nil -> true
        remove_entry -> compare_entries(add_entry, remove_entry) == :after
      end
    end)
    |> Enum.map(fn {element, _} -> element end)
    |> MapSet.new()
  end
  
  @doc """
  Check if an element is in the set
  """
  @spec member?(t(), element()) :: boolean()
  def member?(set, element) do
    case {Map.get(set.add_set, element), Map.get(set.remove_set, element)} do
      {nil, _} -> false
      {add_entry, nil} -> true
      {add_entry, remove_entry} -> compare_entries(add_entry, remove_entry) == :after
    end
  end
  
  @doc """
  Merge two LWW-Element-Sets
  """
  @spec merge(t(), t()) :: t()
  def merge(set1, set2) do
    %{
      add_set: merge_entry_maps(set1.add_set, set2.add_set),
      remove_set: merge_entry_maps(set1.remove_set, set2.remove_set)
    }
  end
  
  defp merge_entry_maps(map1, map2) do
    Map.merge(map1, map2, fn _element, entry1, entry2 ->
      if compare_entries(entry1, entry2) == :after do
        entry1
      else
        entry2
      end
    end)
  end
  
  @doc """
  Compare two LWW-Element-Sets for causal ordering
  """
  @spec compare(t(), t()) :: :equal | :concurrent | :before | :after
  def compare(set1, set2) do
    add_comp = compare_entry_maps(set1.add_set, set2.add_set)
    remove_comp = compare_entry_maps(set1.remove_set, set2.remove_set)
    
    case {add_comp, remove_comp} do
      {:equal, :equal} -> :equal
      {:before, :before} -> :before
      {:after, :after} -> :after
      {:before, :equal} -> :before
      {:equal, :before} -> :before
      {:after, :equal} -> :after
      {:equal, :after} -> :after
      _ -> :concurrent
    end
  end
  
  defp compare_entry_maps(map1, map2) do
    all_keys = MapSet.union(
      MapSet.new(Map.keys(map1)),
      MapSet.new(Map.keys(map2))
    )
    
    comparisons = Enum.map(all_keys, fn key ->
      case {Map.get(map1, key), Map.get(map2, key)} do
        {nil, nil} -> :equal
        {nil, _} -> :before
        {_, nil} -> :after
        {entry1, entry2} -> compare_entries(entry1, entry2)
      end
    end)
    
    cond do
      Enum.all?(comparisons, &(&1 == :equal)) -> :equal
      Enum.all?(comparisons, &(&1 in [:equal, :before])) -> :before
      Enum.all?(comparisons, &(&1 in [:equal, :after])) -> :after
      true -> :concurrent
    end
  end
  
  defp compare_entries({ts1, node1}, {ts2, node2}) do
    cond do
      ts1 > ts2 -> :after
      ts1 < ts2 -> :before
      node1 > node2 -> :after
      node1 < node2 -> :before
      true -> :equal
    end
  end
end