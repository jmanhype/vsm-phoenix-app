defmodule VsmPhoenix.CRDT.PNCounter do
  @moduledoc """
  Positive-Negative Counter (PN-Counter) CRDT implementation.
  
  A PN-Counter combines two G-Counters: one for increments (P)
  and one for decrements (N). The value is P - N.
  """
  
  alias VsmPhoenix.CRDT.GCounter
  
  @type t :: %{
    p: GCounter.t(),
    n: GCounter.t()
  }
  @type node_id :: term()
  
  @doc """
  Create a new empty PN-Counter
  """
  @spec new() :: t()
  def new do
    %{
      p: GCounter.new(),
      n: GCounter.new()
    }
  end
  
  @doc """
  Increment the counter for a specific node
  """
  @spec increment(t(), node_id(), non_neg_integer()) :: t()
  def increment(counter, node_id, value \\ 1) when value >= 0 do
    %{counter | p: GCounter.increment(counter.p, node_id, value)}
  end
  
  @doc """
  Decrement the counter for a specific node
  """
  @spec decrement(t(), node_id(), non_neg_integer()) :: t()
  def decrement(counter, node_id, value \\ 1) when value >= 0 do
    %{counter | n: GCounter.increment(counter.n, node_id, value)}
  end
  
  @doc """
  Get the total value of the counter
  """
  @spec value(t()) :: integer()
  def value(counter) do
    GCounter.value(counter.p) - GCounter.value(counter.n)
  end
  
  @doc """
  Merge two PN-Counters
  """
  @spec merge(t(), t()) :: t()
  def merge(counter1, counter2) do
    %{
      p: GCounter.merge(counter1.p, counter2.p),
      n: GCounter.merge(counter1.n, counter2.n)
    }
  end
  
  @doc """
  Compare two PN-Counters for causal ordering
  """
  @spec compare(t(), t()) :: :equal | :concurrent | :before | :after
  def compare(counter1, counter2) do
    p_comp = GCounter.compare(counter1.p, counter2.p)
    n_comp = GCounter.compare(counter1.n, counter2.n)
    
    case {p_comp, n_comp} do
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
end