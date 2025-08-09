defmodule VsmPhoenix.CRDT.ORSet do
  @moduledoc """
  Observed-Remove Set (OR-Set) CRDT implementation.
  
  An OR-Set allows both add and remove operations on sets while
  maintaining convergence. Each element is tagged with a unique
  identifier when added, allowing proper tracking of add/remove
  operations.
  """
  
  @type element :: term()
  @type unique_tag :: {node_id :: term(), counter :: non_neg_integer()}
  @type t :: %{
    elements: %{element() => MapSet.t(unique_tag())},
    counter: non_neg_integer(),
    node_id: term()
  }
  
  @doc """
  Create a new empty OR-Set
  """
  @spec new() :: t()
  def new do
    %{
      elements: %{},
      counter: 0,
      node_id: nil
    }
  end
  
  @doc """
  Add an element to the set
  """
  @spec add(t(), element(), term()) :: t()
  def add(set, element, node_id) do
    counter = set.counter + 1
    tag = {node_id, counter}
    
    elements = Map.update(
      set.elements,
      element,
      MapSet.new([tag]),
      &MapSet.put(&1, tag)
    )
    
    %{set | 
      elements: elements, 
      counter: counter,
      node_id: node_id
    }
  end
  
  @doc """
  Remove an element from the set
  """
  @spec remove(t(), element()) :: t()
  def remove(set, element) do
    elements = Map.delete(set.elements, element)
    %{set | elements: elements}
  end
  
  @doc """
  Get all elements in the set
  """
  @spec value(t()) :: MapSet.t(element())
  def value(set) do
    set.elements
    |> Map.keys()
    |> MapSet.new()
  end
  
  @doc """
  Check if an element exists in the set
  """
  @spec member?(t(), element()) :: boolean()
  def member?(set, element) do
    Map.has_key?(set.elements, element) && 
    MapSet.size(set.elements[element]) > 0
  end
  
  @doc """
  Merge two OR-Sets
  """
  @spec merge(t(), t()) :: t()
  def merge(set1, set2) do
    merged_elements = merge_elements(set1.elements, set2.elements)
    max_counter = max(set1.counter, set2.counter)
    
    %{
      elements: merged_elements,
      counter: max_counter,
      node_id: set1.node_id  # Keep the first set's node_id
    }
  end
  
  defp merge_elements(elements1, elements2) do
    all_keys = MapSet.union(
      MapSet.new(Map.keys(elements1)),
      MapSet.new(Map.keys(elements2))
    )
    
    Enum.reduce(all_keys, %{}, fn key, acc ->
      tags1 = Map.get(elements1, key, MapSet.new())
      tags2 = Map.get(elements2, key, MapSet.new())
      merged_tags = MapSet.union(tags1, tags2)
      
      if MapSet.size(merged_tags) > 0 do
        Map.put(acc, key, merged_tags)
      else
        acc
      end
    end)
  end
  
  @doc """
  Compare two OR-Sets for causal ordering
  """
  @spec compare(t(), t()) :: :equal | :concurrent | :before | :after
  def compare(set1, set2) do
    # Compare based on element tags
    tags1 = all_tags(set1)
    tags2 = all_tags(set2)
    
    cond do
      MapSet.equal?(tags1, tags2) -> :equal
      MapSet.subset?(tags1, tags2) -> :before
      MapSet.subset?(tags2, tags1) -> :after
      true -> :concurrent
    end
  end
  
  defp all_tags(set) do
    set.elements
    |> Map.values()
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end
end