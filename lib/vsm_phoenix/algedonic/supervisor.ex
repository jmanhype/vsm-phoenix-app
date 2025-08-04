defmodule VsmPhoenix.Algedonic.Supervisor do
  @moduledoc """
  Supervisor for the Algedonic Signal Subsystem.
  
  Manages:
  - AlgedonicChannel: Direct S1→S5 emergency communication
  - PainProcessor: Critical alert handling
  - PleasureProcessor: Positive reinforcement
  - AutonomicResponse: Immediate reflexive reactions
  """
  
  use Supervisor
  require Logger
  
  def start_link(init_arg) do
    Logger.info("Starting Algedonic Supervisor")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  @impl true
  def init(_init_arg) do
    children = [
      # Main algedonic channel for S1→S5 communication
      {VsmPhoenix.Algedonic.AlgedonicChannel, []},
      
      # Pain processor for critical issues
      {VsmPhoenix.Algedonic.PainProcessor, []},
      
      # Pleasure processor for positive reinforcement
      {VsmPhoenix.Algedonic.PleasureProcessor, []},
      
      # Autonomic response system for reflexes
      {VsmPhoenix.Algedonic.AutonomicResponse, []},
      
      # Telemetry poller for monitoring
      telemetry_poller_spec()
    ]
    
    # One-for-one strategy: if one component fails, only restart that one
    # This prevents cascade failures in the algedonic system itself
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  defp telemetry_poller_spec do
    %{
      id: :algedonic_telemetry_poller,
      start: {:telemetry_poller, :start_link, [
        [
          measurements: [
            {__MODULE__, :collect_measurements, []}
          ],
          period: :timer.seconds(10),
          name: :algedonic_telemetry_poller
        ]
      ]}
    }
  end
  
  @doc """
  Collect measurements for algedonic system monitoring
  """
  def collect_measurements do
    # Collect pain state
    pain_state = try do
      VsmPhoenix.Algedonic.PainProcessor.pain_state()
    rescue
      _ -> %{pain_level: :unknown, active_pains: []}
    end
    
    # Collect autonomic state
    autonomic_state = try do
      VsmPhoenix.Algedonic.AutonomicResponse.autonomic_state()
    rescue
      _ -> %{emergency_mode: false, active_responses: 0}
    end
    
    # Collect recent signals
    recent_signals = try do
      VsmPhoenix.Algedonic.AlgedonicChannel.recent_signals(10)
    rescue
      _ -> []
    end
    
    # Calculate signal rates
    pain_count = Enum.count(recent_signals, fn s -> s.type == :pain end)
    pleasure_count = Enum.count(recent_signals, fn s -> s.type == :pleasure end)
    
    # Emit telemetry events
    :telemetry.execute(
      [:vsm, :algedonic, :health],
      %{
        pain_signals: pain_count,
        pleasure_signals: pleasure_count,
        active_pains: length(pain_state.active_pains),
        emergency_mode: if(autonomic_state.emergency_mode, do: 1, else: 0),
        active_responses: autonomic_state.active_responses
      },
      %{
        pain_level: pain_state[:pain_level] || :unknown,
        cascade_risk: pain_state[:cascade_risk] || :unknown
      }
    )
  end
  
  @doc """
  Emergency shutdown of algedonic system (last resort)
  """
  def emergency_shutdown do
    Logger.error("EMERGENCY SHUTDOWN OF ALGEDONIC SYSTEM")
    Supervisor.stop(__MODULE__, :shutdown)
  end
  
  @doc """
  Restart a specific component
  """
  def restart_component(component) when component in [:channel, :pain, :pleasure, :autonomic] do
    child_id = case component do
      :channel -> VsmPhoenix.Algedonic.AlgedonicChannel
      :pain -> VsmPhoenix.Algedonic.PainProcessor
      :pleasure -> VsmPhoenix.Algedonic.PleasureProcessor
      :autonomic -> VsmPhoenix.Algedonic.AutonomicResponse
    end
    
    Supervisor.restart_child(__MODULE__, child_id)
  end
  
  @doc """
  Get status of all algedonic components
  """
  def status do
    children = Supervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {id, child, type, modules} ->
      %{
        id: id,
        pid: child,
        type: type,
        modules: modules,
        alive: is_pid(child) and Process.alive?(child)
      }
    end)
  end
end