defmodule VsmPhoenix.QuantumVariety.QuantumTunnel do
  @moduledoc """
  Quantum Tunneling for Emergency Message Bypass in VSM.
  
  Implements quantum tunneling effects to allow high-priority messages
  to bypass normal variety constraints through quantum mechanical tunneling.
  
  Key Features:
  - Barrier Penetration: Messages tunnel through variety barriers
  - Probability-based Success: Tunneling probability depends on barrier height
  - Energy Conservation: Maintains system equilibrium
  - Emergency Override: Critical messages can force tunneling
  """

  use GenServer
  require Logger
  alias VsmPhoenix.QuantumVariety.{QuantumState, WaveFunction}

  @type tunnel :: %{
    id: String.t(),
    source: String.t(),
    target: String.t(),
    barrier_height: float(),
    tunnel_probability: float(),
    energy_cost: float(),
    created_at: DateTime.t(),
    metadata: map()
  }

  @type tunneling_event :: %{
    tunnel_id: String.t(),
    message: any(),
    success: boolean(),
    energy_used: float(),
    time_taken: float(),
    timestamp: DateTime.t()
  }

  # Tunneling constants
  @planck_reduced 1.054571817e-34  # ħ = h/2π
  @electron_mass 9.1093837015e-31   # kg
  @base_barrier_height 1.0          # Normalized units
  @critical_threshold 0.95          # Emergency override threshold
  @max_tunnel_distance 100          # Maximum tunneling distance
  @energy_budget 1000.0             # Total energy budget

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Creates a quantum tunnel between source and target.
  """
  def create_tunnel(source, target, capacity \\ 1.0) do
    GenServer.call(__MODULE__, {:create_tunnel, source, target, capacity})
  end

  @doc """
  Attempts to tunnel a message through quantum barriers.
  Returns success probability and actual result.
  """
  def tunnel_message(message, tunnel_id, priority \\ :normal) do
    GenServer.call(__MODULE__, {:tunnel_message, message, tunnel_id, priority})
  end

  @doc """
  Forces emergency tunneling for critical messages.
  Consumes significant energy but guarantees passage.
  """
  def emergency_tunnel(message, target) do
    GenServer.call(__MODULE__, {:emergency_tunnel, message, target})
  end

  @doc """
  Calculates tunneling probability for a given barrier.
  """
  def calculate_tunnel_probability(barrier_height, particle_energy) do
    GenServer.call(__MODULE__, {:calculate_probability, barrier_height, particle_energy})
  end

  @doc """
  Sets up resonant tunneling for enhanced probability.
  """
  def setup_resonant_tunneling(tunnel_id, frequency) do
    GenServer.call(__MODULE__, {:setup_resonance, tunnel_id, frequency})
  end

  @doc """
  Monitors tunnel stability and coherence.
  """
  def monitor_tunnel(tunnel_id) do
    GenServer.call(__MODULE__, {:monitor_tunnel, tunnel_id})
  end

  ## GenServer Callbacks

  def init(opts) do
    # Start tunnel monitoring
    schedule_tunnel_maintenance()
    schedule_energy_recovery()
    
    state = %{
      tunnels: %{},
      tunneling_events: [],
      energy_pool: @energy_budget,
      resonant_frequencies: %{},
      barrier_map: initialize_barrier_map(),
      stats: %{
        total_tunnels: 0,
        successful_tunnels: 0,
        failed_tunnels: 0,
        emergency_tunnels: 0,
        total_energy_used: 0.0,
        average_success_rate: 0.0
      }
    }
    
    Logger.info("🌌 Quantum Tunnel Manager initialized with energy budget: #{@energy_budget}")
    {:ok, state}
  end

  def handle_call({:create_tunnel, source, target, capacity}, _from, state) do
    case establish_tunnel(source, target, capacity, state) do
      {:ok, tunnel, new_state} ->
        {:reply, {:ok, tunnel}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:tunnel_message, message, tunnel_id, priority}, _from, state) do
    case attempt_tunneling(message, tunnel_id, priority, state) do
      {:ok, event, new_state} ->
        {:reply, {:ok, event}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:emergency_tunnel, message, target}, _from, state) do
    case force_emergency_tunnel(message, target, state) do
      {:ok, event, new_state} ->
        {:reply, {:ok, event}, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:calculate_probability, barrier_height, particle_energy}, _from, state) do
    probability = calculate_wkb_probability(barrier_height, particle_energy)
    {:reply, {:ok, probability}, state}
  end

  def handle_call({:setup_resonance, tunnel_id, frequency}, _from, state) do
    case setup_resonant_frequency(tunnel_id, frequency, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:monitor_tunnel, tunnel_id}, _from, state) do
    case get_tunnel(tunnel_id, state) do
      {:ok, tunnel} ->
        status = analyze_tunnel_status(tunnel, state)
        {:reply, {:ok, status}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info(:tunnel_maintenance, state) do
    new_state = perform_tunnel_maintenance(state)
    schedule_tunnel_maintenance()
    {:noreply, new_state}
  end

  def handle_info(:energy_recovery, state) do
    new_state = recover_energy(state)
    schedule_energy_recovery()
    {:noreply, new_state}
  end

  def handle_info({:tunnel_collapsed, tunnel_id}, state) do
    new_state = handle_tunnel_collapse(tunnel_id, state)
    {:noreply, new_state}
  end

  ## Private Functions

  defp establish_tunnel(source, target, capacity, state) do
    distance = calculate_tunnel_distance(source, target)
    
    if distance > @max_tunnel_distance do
      {:error, :distance_too_large}
    else
      id = generate_tunnel_id()
      barrier_height = calculate_barrier_height(source, target, state)
      
      tunnel = %{
        id: id,
        source: source,
        target: target,
        distance: distance,
        barrier_height: barrier_height,
        tunnel_probability: calculate_base_probability(barrier_height, distance),
        energy_cost: calculate_energy_cost(barrier_height, distance),
        capacity: capacity,
        stability: 1.0,
        created_at: DateTime.utc_now(),
        metadata: %{
          resonant: false,
          uses: 0,
          last_use: nil
        }
      }
      
      new_state = state
      |> put_in([:tunnels, id], tunnel)
      |> update_in([:stats, :total_tunnels], &(&1 + 1))
      
      Logger.info("🌌 Created quantum tunnel #{id}: #{source} -> #{target} (P=#{Float.round(tunnel.tunnel_probability, 3)})")
      {:ok, tunnel, new_state}
    end
  end

  defp attempt_tunneling(message, tunnel_id, priority, state) do
    with {:ok, tunnel} <- get_tunnel(tunnel_id, state),
         {:ok, :sufficient_energy} <- check_energy(tunnel.energy_cost, state),
         {:ok, :stable} <- check_tunnel_stability(tunnel) do
      
      # Adjust probability based on priority
      adjusted_probability = adjust_probability_for_priority(tunnel.tunnel_probability, priority)
      
      # Check for resonant enhancement
      final_probability = case get_in(state.resonant_frequencies, [tunnel_id]) do
        nil -> adjusted_probability
        freq -> enhance_with_resonance(adjusted_probability, freq)
      end
      
      # Attempt tunneling
      success = :rand.uniform() < final_probability
      
      event = %{
        tunnel_id: tunnel_id,
        message: message,
        success: success,
        probability: final_probability,
        energy_used: if(success, do: tunnel.energy_cost, else: tunnel.energy_cost * 0.1),
        time_taken: calculate_tunnel_time(tunnel.distance),
        timestamp: DateTime.utc_now()
      }
      
      new_state = state
      |> update_energy_pool(event.energy_used)
      |> update_tunnel_usage(tunnel_id)
      |> update_tunneling_stats(success)
      |> update_in([:tunneling_events], &([event | &1]))
      
      if success do
        # Successfully tunneled - deliver message
        deliver_tunneled_message(message, tunnel.target)
        Logger.info("✅ Message successfully tunneled through #{tunnel_id} (P=#{Float.round(final_probability, 3)})")
      else
        Logger.debug("❌ Tunneling failed for #{tunnel_id} (P=#{Float.round(final_probability, 3)})")
      end
      
      {:ok, event, new_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp force_emergency_tunnel(message, target, state) do
    # Find or create direct tunnel
    tunnel_result = find_existing_tunnel(target, state)
    |> case do
      {:ok, tunnel} -> {:ok, tunnel}
      _ -> establish_tunnel("emergency_source", target, 1.0, state)
    end
    
    case tunnel_result do
      {:ok, tunnel, new_state} ->
        # Calculate emergency energy cost (much higher)
        emergency_cost = tunnel.energy_cost * 10
        
        if new_state.energy_pool >= emergency_cost do
          event = %{
            tunnel_id: tunnel.id,
            message: message,
            success: true,  # Emergency tunneling always succeeds if energy available
            probability: 1.0,
            energy_used: emergency_cost,
            time_taken: 0.001,  # Near-instantaneous
            timestamp: DateTime.utc_now(),
            emergency: true
          }
          
          final_state = new_state
          |> update_energy_pool(emergency_cost)
          |> update_in([:stats, :emergency_tunnels], &(&1 + 1))
          |> update_in([:stats, :successful_tunnels], &(&1 + 1))
          |> update_in([:tunneling_events], &([event | &1]))
          
          # Deliver with highest priority
          deliver_tunneled_message(message, target, :emergency)
          
          Logger.warn("🆘 Emergency tunnel activated for #{target} (Energy: #{emergency_cost})")
          {:ok, event, final_state}
        else
          {:error, :insufficient_energy_for_emergency}
        end
      
      {:ok, tunnel} ->
        # Use existing tunnel for emergency
        force_emergency_tunnel(message, target, %{state | tunnels: %{tunnel.id => tunnel}})
      
      error -> error
    end
  end

  defp calculate_wkb_probability(barrier_height, particle_energy) do
    # WKB approximation for tunneling probability
    # T ≈ exp(-2γ) where γ = (2m(V-E))^(1/2) * width / ħ
    
    if particle_energy >= barrier_height do
      1.0  # Classical passage
    else
      # Simplified calculation with normalized units
      gamma = 2 * :math.sqrt(2 * (barrier_height - particle_energy))
      :math.exp(-gamma)
    end
  end

  defp setup_resonant_frequency(tunnel_id, frequency, state) do
    case get_tunnel(tunnel_id, state) do
      {:ok, tunnel} ->
        # Store resonant frequency for enhancement
        new_state = put_in(state, [:resonant_frequencies, tunnel_id], frequency)
        
        # Update tunnel metadata
        updated_tunnel = %{tunnel |
          metadata: Map.put(tunnel.metadata, :resonant, true)
        }
        
        final_state = put_in(new_state, [:tunnels, tunnel_id], updated_tunnel)
        
        Logger.info("🎉 Resonant frequency #{frequency} Hz set for tunnel #{tunnel_id}")
        {:ok, final_state}
      
      {:error, reason} -> {:error, reason}
    end
  end

  defp analyze_tunnel_status(tunnel, state) do
    %{
      id: tunnel.id,
      stability: tunnel.stability,
      probability: tunnel.tunnel_probability,
      energy_cost: tunnel.energy_cost,
      uses: tunnel.metadata.uses,
      resonant: tunnel.metadata.resonant,
      energy_available: state.energy_pool >= tunnel.energy_cost,
      efficiency: calculate_tunnel_efficiency(tunnel, state)
    }
  end

  defp perform_tunnel_maintenance(state) do
    # Maintain tunnel stability and clean up collapsed tunnels
    updated_tunnels = state.tunnels
    |> Enum.map(fn {id, tunnel} ->
      # Decay stability based on usage and time
      time_decay = calculate_time_decay(tunnel.created_at)
      usage_decay = tunnel.metadata.uses * 0.01
      new_stability = max(0, tunnel.stability - time_decay - usage_decay)
      
      if new_stability < 0.1 do
        send(self(), {:tunnel_collapsed, id})
        {id, %{tunnel | stability: 0}}
      else
        # Update probability based on stability
        new_probability = tunnel.tunnel_probability * new_stability
        {id, %{tunnel | stability: new_stability, tunnel_probability: new_probability}}
      end
    end)
    |> Map.new()
    
    %{state | tunnels: updated_tunnels}
  end

  defp recover_energy(state) do
    # Gradually recover energy pool
    recovery_rate = 10.0  # Energy units per cycle
    new_energy = min(@energy_budget, state.energy_pool + recovery_rate)
    
    if new_energy != state.energy_pool do
      Logger.debug("⚡ Energy recovered: #{Float.round(state.energy_pool, 1)} -> #{Float.round(new_energy, 1)}")
    end
    
    %{state | energy_pool: new_energy}
  end

  defp handle_tunnel_collapse(tunnel_id, state) do
    case get_tunnel(tunnel_id, state) do
      {:ok, tunnel} ->
        Logger.warn("💥 Tunnel #{tunnel_id} collapsed (#{tunnel.source} -> #{tunnel.target})")
        
        new_state = state
        |> update_in([:tunnels], &Map.delete(&1, tunnel_id))
        |> update_in([:resonant_frequencies], &Map.delete(&1, tunnel_id))
        
        # Notify affected systems
        notify_tunnel_collapse(tunnel.source, tunnel.target)
        
        new_state
      
      _ -> state
    end
  end

  defp calculate_tunnel_distance(source, target) do
    # Simplified distance calculation
    # In production, would use actual topology metrics
    :rand.uniform(50) + 10
  end

  defp calculate_barrier_height(source, target, state) do
    # Get barrier from map or calculate default
    base_barrier = Map.get(state.barrier_map, {source, target}, @base_barrier_height)
    
    # Add noise and fluctuations
    fluctuation = (:rand.uniform() - 0.5) * 0.2
    base_barrier + fluctuation
  end

  defp calculate_base_probability(barrier_height, distance) do
    # Base tunneling probability
    distance_factor = :math.exp(-distance / 20)
    barrier_factor = :math.exp(-barrier_height)
    
    min(1.0, distance_factor * barrier_factor)
  end

  defp calculate_energy_cost(barrier_height, distance) do
    # Energy cost increases with barrier height and distance
    base_cost = 1.0
    barrier_cost = barrier_height * 5
    distance_cost = distance * 0.1
    
    base_cost + barrier_cost + distance_cost
  end

  defp adjust_probability_for_priority(base_probability, priority) do
    case priority do
      :critical -> min(1.0, base_probability * 3)
      :high -> min(1.0, base_probability * 2)
      :normal -> base_probability
      :low -> base_probability * 0.5
      _ -> base_probability
    end
  end

  defp enhance_with_resonance(probability, frequency) do
    # Resonant enhancement increases tunneling probability
    resonance_factor = 1 + (:math.sin(frequency * :math.pi() / 1000) + 1) / 2
    min(1.0, probability * resonance_factor)
  end

  defp check_energy(required_energy, state) do
    if state.energy_pool >= required_energy do
      {:ok, :sufficient_energy}
    else
      {:error, :insufficient_energy}
    end
  end

  defp check_tunnel_stability(tunnel) do
    if tunnel.stability > 0.2 do
      {:ok, :stable}
    else
      {:error, :tunnel_unstable}
    end
  end

  defp calculate_tunnel_time(distance) do
    # Time increases with distance (in milliseconds)
    base_time = 0.1
    distance_time = distance * 0.01
    
    base_time + distance_time
  end

  defp deliver_tunneled_message(message, target, priority \\ :normal) do
    # Send tunneled message to target system
    # This would integrate with the main VSM message routing
    
    event = %{
      type: :tunneled_message,
      message: message,
      target: target,
      priority: priority,
      timestamp: DateTime.utc_now()
    }
    
    # Broadcast to interested parties
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "quantum:tunneling",
      event
    )
    
    # Also send directly if process exists
    case Process.whereis(String.to_atom(target)) do
      nil -> :ok
      pid -> send(pid, {:tunneled_message, message, priority})
    end
  end

  defp find_existing_tunnel(target, state) do
    state.tunnels
    |> Enum.find(fn {_id, tunnel} ->
      tunnel.target == target and tunnel.stability > 0.5
    end)
    |> case do
      {id, tunnel} -> {:ok, tunnel}
      nil -> {:error, :no_tunnel_found}
    end
  end

  defp update_energy_pool(state, energy_used) do
    new_pool = max(0, state.energy_pool - energy_used)
    
    state
    |> Map.put(:energy_pool, new_pool)
    |> update_in([:stats, :total_energy_used], &(&1 + energy_used))
  end

  defp update_tunnel_usage(state, tunnel_id) do
    update_in(state, [:tunnels, tunnel_id], fn
      nil -> nil
      tunnel ->
        %{tunnel |
          metadata: tunnel.metadata
          |> Map.update(:uses, 1, &(&1 + 1))
          |> Map.put(:last_use, DateTime.utc_now())
        }
    end)
  end

  defp update_tunneling_stats(state, success) do
    state
    |> update_in([:stats, if(success, do: :successful_tunnels, else: :failed_tunnels)], &(&1 + 1))
    |> update_average_success_rate()
  end

  defp update_average_success_rate(state) do
    total = state.stats.successful_tunnels + state.stats.failed_tunnels
    
    if total > 0 do
      rate = state.stats.successful_tunnels / total
      put_in(state, [:stats, :average_success_rate], rate)
    else
      state
    end
  end

  defp calculate_tunnel_efficiency(tunnel, state) do
    if tunnel.metadata.uses > 0 do
      # Efficiency = success rate / energy cost
      success_rate = tunnel.tunnel_probability
      energy_efficiency = 1 / (1 + tunnel.energy_cost / 10)
      
      success_rate * energy_efficiency * tunnel.stability
    else
      tunnel.tunnel_probability  # Theoretical efficiency
    end
  end

  defp calculate_time_decay(created_at) do
    # Decay based on age (simplified)
    hours_elapsed = DateTime.diff(DateTime.utc_now(), created_at, :hour)
    hours_elapsed * 0.001
  end

  defp notify_tunnel_collapse(source, target) do
    # Notify relevant systems about tunnel collapse
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "quantum:tunneling",
      %{
        type: :tunnel_collapsed,
        source: source,
        target: target,
        timestamp: DateTime.utc_now()
      }
    )
  end

  defp get_tunnel(tunnel_id, state) do
    case get_in(state.tunnels, [tunnel_id]) do
      nil -> {:error, :tunnel_not_found}
      tunnel -> {:ok, tunnel}
    end
  end

  defp initialize_barrier_map do
    # Initialize with some default barriers
    %{
      {"system1", "system2"} => 0.8,
      {"system2", "system3"} => 1.2,
      {"system3", "system4"} => 0.6,
      {"system4", "system5"} => 1.5
    }
  end

  defp generate_tunnel_id do
    "tunnel_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp schedule_tunnel_maintenance do
    Process.send_after(self(), :tunnel_maintenance, 5000)  # Every 5 seconds
  end

  defp schedule_energy_recovery do
    Process.send_after(self(), :energy_recovery, 1000)  # Every second
  end

end