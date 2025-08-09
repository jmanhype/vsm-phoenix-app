defmodule VsmPhoenix.CRDT.GCounter do
  @moduledoc """
  Grow-only Counter (G-Counter) CRDT implementation.
  
  A G-Counter is a state-based increment-only counter CRDT.
  Each node maintains its own counter, and the total value
  is the sum of all node counters.
  """
  
  @type t :: %{required(node_id :: term()) => non_neg_integer()}
  @type node_id :: term()
  
  @doc """
  Create a new empty G-Counter
  """
  @spec new() :: t()
  def new do
    %{}
  end
  
  @doc """
  Increment the counter for a specific node
  """
  @spec increment(t(), node_id(), non_neg_integer()) :: t()
  def increment(counter, node_id, value \\ 1) when value >= 0 do
    Map.update(counter, node_id, value, &(&1 + value))
  end
  
  @doc """
  Get the total value of the counter
  """
  @spec value(t()) :: non_neg_integer()
  def value(counter) do
    counter
    |> Map.values()
    |> Enum.sum()
  end
  
  @doc """
  Merge two G-Counters by taking the maximum value for each node
  """
  @spec merge(t(), t()) :: t()
  def merge(counter1, counter2) do
    Map.merge(counter1, counter2, fn _node, val1, val2 ->
      max(val1, val2)
    end)
  end
  
  @doc """
  Compare two G-Counters to determine causal ordering
  Returns :equal, :concurrent, :before, or :after
  """
  @spec compare(t(), t()) :: :equal | :concurrent | :before | :after
  def compare(counter1, counter2) do
    all_nodes = MapSet.union(
      MapSet.new(Map.keys(counter1)),
      MapSet.new(Map.keys(counter2))
    )
    
    comparisons = Enum.map(all_nodes, fn node ->
      val1 = Map.get(counter1, node, 0)
      val2 = Map.get(counter2, node, 0)
      
      cond do
        val1 == val2 -> :equal
        val1 < val2 -> :before
        val1 > val2 -> :after
      end
    end)
    
    cond do
      Enum.all?(comparisons, &(&1 == :equal)) -> :equal
      Enum.all?(comparisons, &(&1 in [:equal, :before])) -> :before
      Enum.all?(comparisons, &(&1 in [:equal, :after])) -> :after
      true -> :concurrent
    end
  end
end