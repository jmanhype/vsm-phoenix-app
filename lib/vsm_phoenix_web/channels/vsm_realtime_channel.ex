defmodule VsmPhoenixWeb.VsmRealtimeChannel do
  @moduledoc """
  WebSocket channel for real-time VSM system updates.
  
  Provides live updates for:
  - Chaos engineering experiments
  - Quantum state changes
  - Emergent behavior evolution
  - Meta-VSM operations
  - Algedonic signals and responses
  
  Usage:
    // JavaScript client
    import { Socket } from "phoenix"
    
    let socket = new Socket("/socket", {params: {token: window.userToken}})
    socket.connect()
    
    let channel = socket.channel("vsm_realtime:lobby", {})
    channel.join()
      .receive("ok", resp => { console.log("Joined successfully", resp) })
      .receive("error", resp => { console.log("Unable to join", resp) })
    
    // Subscribe to specific system updates
    channel.push("subscribe", {system: "chaos", experiment_id: "exp_123"})
    channel.push("subscribe", {system: "quantum", state_id: "q_456"})
    channel.push("subscribe", {system: "emergent", swarm_id: "swarm_789"})
    
    // Listen for updates
    channel.on("chaos_update", payload => console.log("Chaos update:", payload))
    channel.on("quantum_update", payload => console.log("Quantum update:", payload))
    channel.on("emergent_update", payload => console.log("Emergent update:", payload))
    channel.on("meta_vsm_update", payload => console.log("Meta-VSM update:", payload))
    channel.on("algedonic_update", payload => console.log("Algedonic update:", payload))
  """
  
  use VsmPhoenixWeb, :channel
  
  alias VsmPhoenix.VSM.ChaosEngineering
  alias VsmPhoenix.VSM.QuantumLogic
  alias VsmPhoenix.VSM.EmergentIntelligence
  alias VsmPhoenix.VSM.MetaSystem
  alias VsmPhoenix.VSM.AlgedonicSystem
  
  require Logger

  @doc """
  Join the VSM realtime channel.
  """
  def join("vsm_realtime:lobby", _payload, socket) do
    Logger.info("Client joined VSM realtime channel: #{inspect(socket.assigns[:user_id])}")
    
    # Send initial system status
    initial_status = %{
      chaos: ChaosEngineering.get_system_status(),
      quantum: QuantumLogic.get_system_status(),
      emergent: EmergentIntelligence.get_system_status(),
      meta_vsm: MetaSystem.get_system_status(),
      algedonic: AlgedonicSystem.get_system_status(),
      timestamp: DateTime.utc_now()
    }
    
    {:ok, %{system_status: initial_status}, socket}
  end

  def join("vsm_realtime:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  @doc """
  Subscribe to specific system updates.
  """
  def handle_in("subscribe", %{"system" => system} = params, socket) do
    case subscribe_to_system(system, params, socket) do
      {:ok, subscription_id} ->
        Logger.info("Client subscribed to #{system}: #{subscription_id}")
        
        {:reply, {:ok, %{
          subscribed: true,
          system: system,
          subscription_id: subscription_id,
          params: params
        }}, socket}
      
      {:error, reason} ->
        Logger.warning("Subscription failed for #{system}: #{reason}")
        
        {:reply, {:error, %{
          subscribed: false,
          reason: reason
        }}, socket}
    end
  end

  @doc """
  Unsubscribe from system updates.
  """
  def handle_in("unsubscribe", %{"system" => system, "subscription_id" => sub_id}, socket) do
    case unsubscribe_from_system(system, sub_id, socket) do
      :ok ->
        Logger.info("Client unsubscribed from #{system}: #{sub_id}")
        {:reply, {:ok, %{unsubscribed: true}}, socket}
      
      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  @doc """
  Get current status of all systems.
  """
  def handle_in("get_status", _params, socket) do
    status = %{
      chaos: %{
        active_experiments: ChaosEngineering.count_active_experiments(),
        active_faults: ChaosEngineering.count_active_faults(),
        system_resilience: ChaosEngineering.get_resilience_score()
      },
      quantum: %{
        active_states: QuantumLogic.count_active_states(),
        entangled_pairs: QuantumLogic.count_entanglements(),
        coherence_average: QuantumLogic.get_avg_coherence_time()
      },
      emergent: %{
        active_swarms: EmergentIntelligence.count_active_swarms(),
        total_agents: EmergentIntelligence.count_total_agents(),
        collective_iq: EmergentIntelligence.get_global_collective_iq()
      },
      meta_vsm: %{
        active_vsms: MetaSystem.count_active_vsms(),
        total_hierarchy_depth: MetaSystem.get_max_hierarchy_depth(),
        genetic_diversity: MetaSystem.measure_genetic_diversity()
      },
      algedonic: %{
        active_signals: AlgedonicSystem.count_active_signals(),
        pain_to_pleasure_ratio: AlgedonicSystem.get_pain_pleasure_ratio(),
        autonomic_responses: AlgedonicSystem.count_autonomic_responses()
      },
      timestamp: DateTime.utc_now()
    }
    
    {:reply, {:ok, status}, socket}
  end

  @doc """
  Broadcast chaos engineering updates.
  """
  def broadcast_chaos_update(experiment_id, update_type, data) do
    VsmPhoenixWeb.Endpoint.broadcast("vsm_realtime:lobby", "chaos_update", %{
      experiment_id: experiment_id,
      update_type: update_type,
      data: data,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Broadcast quantum system updates.
  """
  def broadcast_quantum_update(state_id, update_type, data) do
    VsmPhoenixWeb.Endpoint.broadcast("vsm_realtime:lobby", "quantum_update", %{
      state_id: state_id,
      update_type: update_type,
      data: data,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Broadcast emergent intelligence updates.
  """
  def broadcast_emergent_update(swarm_id, update_type, data) do
    VsmPhoenixWeb.Endpoint.broadcast("vsm_realtime:lobby", "emergent_update", %{
      swarm_id: swarm_id,
      update_type: update_type,
      data: data,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Broadcast meta-VSM updates.
  """
  def broadcast_meta_vsm_update(vsm_id, update_type, data) do
    VsmPhoenixWeb.Endpoint.broadcast("vsm_realtime:lobby", "meta_vsm_update", %{
      vsm_id: vsm_id,
      update_type: update_type,
      data: data,
      timestamp: DateTime.utc_now()
    })
  end

  @doc """
  Broadcast algedonic system updates.
  """
  def broadcast_algedonic_update(signal_id, update_type, data) do
    VsmPhoenixWeb.Endpoint.broadcast("vsm_realtime:lobby", "algedonic_update", %{
      signal_id: signal_id,
      update_type: update_type,
      data: data,
      timestamp: DateTime.utc_now()
    })
  end

  # Private helper functions

  defp subscribe_to_system("chaos", %{"experiment_id" => exp_id}, _socket) do
    case ChaosEngineering.subscribe_to_experiment(exp_id) do
      {:ok, sub_id} -> {:ok, sub_id}
      error -> error
    end
  end

  defp subscribe_to_system("quantum", %{"state_id" => state_id}, _socket) do
    case QuantumLogic.subscribe_to_state(state_id) do
      {:ok, sub_id} -> {:ok, sub_id}
      error -> error
    end
  end

  defp subscribe_to_system("emergent", %{"swarm_id" => swarm_id}, _socket) do
    case EmergentIntelligence.subscribe_to_swarm(swarm_id) do
      {:ok, sub_id} -> {:ok, sub_id}
      error -> error
    end
  end

  defp subscribe_to_system("meta_vsm", %{"vsm_id" => vsm_id}, _socket) do
    case MetaSystem.subscribe_to_vsm(vsm_id) do
      {:ok, sub_id} -> {:ok, sub_id}
      error -> error
    end
  end

  defp subscribe_to_system("algedonic", params, _socket) do
    case AlgedonicSystem.subscribe_to_signals(params) do
      {:ok, sub_id} -> {:ok, sub_id}
      error -> error
    end
  end

  defp subscribe_to_system(system, _params, _socket) do
    {:error, "Unknown system: #{system}"}
  end

  defp unsubscribe_from_system("chaos", sub_id, _socket) do
    ChaosEngineering.unsubscribe(sub_id)
  end

  defp unsubscribe_from_system("quantum", sub_id, _socket) do
    QuantumLogic.unsubscribe(sub_id)
  end

  defp unsubscribe_from_system("emergent", sub_id, _socket) do
    EmergentIntelligence.unsubscribe(sub_id)
  end

  defp unsubscribe_from_system("meta_vsm", sub_id, _socket) do
    MetaSystem.unsubscribe(sub_id)
  end

  defp unsubscribe_from_system("algedonic", sub_id, _socket) do
    AlgedonicSystem.unsubscribe(sub_id)
  end

  defp unsubscribe_from_system(_system, _sub_id, _socket) do
    {:error, "Unknown system"}
  end
end