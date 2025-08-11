defmodule VsmPhoenix.System5.Algedonic.SignalProcessor do
  @moduledoc """
  Algedonic Signal Processor - Handles pain and pleasure signals for System 5.
  
  Extracted from Queen god object to follow Single Responsibility Principle.
  Responsible ONLY for:
  - Processing pain and pleasure signals
  - Managing algedonic state
  - Signal pattern analysis
  - Signal-based viability updates
  """
  
  use GenServer
  require Logger
  
  @behaviour VsmPhoenix.System5.Behaviors.AlgedonicProcessor
  
  alias VsmPhoenix.System5.Algedonic.AlgedonicState
  alias Phoenix.PubSub
  
  @name __MODULE__
  @max_signal_history 1000
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Send a pleasure signal to the system.
  """
  def send_pleasure_signal(intensity, context) do
    GenServer.cast(@name, {:pleasure_signal, intensity, context})
    :ok
  rescue
    e -> {:error, e}
  end
  
  @doc """
  Send a pain signal to the system.
  """
  def send_pain_signal(intensity, context) do
    GenServer.cast(@name, {:pain_signal, intensity, context})
    :ok
  rescue
    e -> {:error, e}
  end
  
  @doc """
  Get current algedonic state.
  """
  def get_algedonic_state do
    GenServer.call(@name, :get_algedonic_state)
  end
  
  @doc """
  Process a raw algedonic signal.
  """
  def process_signal(signal_type, intensity, context) do
    GenServer.cast(@name, {:process_signal, signal_type, intensity, context})
    :ok
  rescue
    e -> {:error, e}
  end
  
  @doc """
  Check if intervention is required.
  """
  def requires_intervention? do
    case GenServer.call(@name, :requires_intervention) do
      result when is_boolean(result) -> result
      _ -> false
    end
  rescue
    _ -> false
  end
  
  @doc """
  Get signal history for analysis.
  """
  def get_signal_history(limit \\ 100) do
    GenServer.call(@name, {:get_signal_history, limit})
  rescue
    e -> {:error, e}
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    state = %{
      current_state: AlgedonicState.new(),
      signal_history: [],
      processed_count: 0,
      last_intervention: nil,
      pattern_cache: %{}
    }
    
    Logger.info("🧠 Algedonic Signal Processor initialized")
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:pleasure_signal, intensity, context}, state) do
    signal = create_signal(:pleasure, intensity, context)
    new_state = process_algedonic_signal(signal, state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:pain_signal, intensity, context}, state) do
    signal = create_signal(:pain, intensity, context)
    new_state = process_algedonic_signal(signal, state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_cast({:process_signal, signal_type, intensity, context}, state) do
    signal = create_signal(signal_type, intensity, context)
    new_state = process_algedonic_signal(signal, state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_algedonic_state, _from, state) do
    {:reply, state.current_state, state}
  end
  
  @impl true
  def handle_call(:requires_intervention, _from, state) do
    needs_intervention = AlgedonicState.requires_intervention?(state.current_state)
    {:reply, needs_intervention, state}
  end
  
  @impl true
  def handle_call({:get_signal_history, limit}, _from, state) do
    history = Enum.take(state.signal_history, limit)
    {:reply, {:ok, history}, state}
  end
  
  # Private Functions
  
  defp create_signal(type, intensity, context) do
    %{
      type: type,
      intensity: clamp_intensity(intensity),
      context: context || %{},
      timestamp: System.system_time(:millisecond),
      id: generate_signal_id()
    }
  end
  
  defp process_algedonic_signal(signal, state) do
    Logger.debug("🧠 Processing #{signal.type} signal (intensity: #{signal.intensity})")
    
    # Update signal history
    new_history = [signal | state.signal_history] |> Enum.take(@max_signal_history)
    
    # Update algedonic state
    new_algedonic_state = AlgedonicState.update(state.current_state, signal)
    
    # Check for intervention triggers
    intervention_needed = should_trigger_intervention?(new_algedonic_state, new_history)
    
    # Broadcast signal if significant
    if signal.intensity >= 0.7 do
      broadcast_signal(signal, new_algedonic_state)
    end
    
    # Update state
    new_state = %{state |
      current_state: new_algedonic_state,
      signal_history: new_history,
      processed_count: state.processed_count + 1,
      last_intervention: if(intervention_needed, do: signal.timestamp, else: state.last_intervention)
    }
    
    # Trigger intervention if needed
    if intervention_needed do
      trigger_intervention(signal, new_algedonic_state)
    end
    
    new_state
  end
  
  defp should_trigger_intervention?(algedonic_state, signal_history) do
    # Check for critical pain levels
    critical_pain = algedonic_state.pain_level >= 0.8
    
    # Check for persistent pain pattern
    recent_signals = Enum.take(signal_history, 10)
    persistent_pain = recent_signals
                     |> Enum.filter(&(&1.type == :pain))
                     |> length() >= 7
    
    # Check for system degradation
    system_degraded = algedonic_state.viability_impact <= 0.3
    
    critical_pain or persistent_pain or system_degraded
  end
  
  defp trigger_intervention(signal, algedonic_state) do
    Logger.warn("🚨 Algedonic intervention triggered: #{signal.type} (#{signal.intensity})")
    
    intervention = %{
      trigger_signal: signal,
      algedonic_state: algedonic_state,
      intervention_type: determine_intervention_type(signal, algedonic_state),
      timestamp: System.system_time(:millisecond)
    }
    
    # Notify other systems
    PubSub.broadcast(VsmPhoenix.PubSub, "vsm:algedonic", {:intervention_triggered, intervention})
  end
  
  defp determine_intervention_type(signal, algedonic_state) do
    cond do
      algedonic_state.pain_level >= 0.9 -> :emergency
      algedonic_state.pain_level >= 0.7 -> :urgent
      algedonic_state.pleasure_level <= 0.2 -> :maintenance
      true -> :preventive
    end
  end
  
  defp broadcast_signal(signal, algedonic_state) do
    message = {:algedonic_signal, signal, algedonic_state}
    PubSub.broadcast(VsmPhoenix.PubSub, "vsm:system5", message)
  end
  
  defp clamp_intensity(intensity) when is_number(intensity) do
    min(max(intensity, 0.0), 1.0)
  end
  defp clamp_intensity(_), do: 0.0
  
  defp generate_signal_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end