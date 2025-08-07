defmodule VsmPhoenix.System5.Components.AlgedonicProcessor do
  @moduledoc """
  Algedonic Processor Component - Handles pain and pleasure signals for System 5

  Responsibilities:
  - Process incoming algedonic signals (pain/pleasure)
  - Update viability metrics based on signals
  - Trigger policy synthesis for severe pain signals
  - Manage AMQP communication for algedonic channels
  - Maintain signal history and patterns
  - Coordinate emergency responses to critical signals
  """

  use GenServer
  require Logger

  alias VsmPhoenix.System5.PolicySynthesizer
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.Components.{PolicyManager, ViabilityEvaluator}
  alias AMQP

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_pleasure_signal(intensity, context) do
    GenServer.cast(__MODULE__, {:pleasure_signal, intensity, context})
  end

  def send_pain_signal(intensity, context) do
    GenServer.cast(__MODULE__, {:pain_signal, intensity, context})
  end

  def get_signal_history(limit \\ 100) do
    GenServer.call(__MODULE__, {:get_signal_history, limit})
  end

  def get_algedonic_state do
    GenServer.call(__MODULE__, :get_algedonic_state)
  end

  def analyze_signal_patterns do
    GenServer.call(__MODULE__, :analyze_signal_patterns)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("AlgedonicProcessor initializing...")

    state = %{
      algedonic_signals: [],
      signal_patterns: %{
        pain_frequency: 0,
        pleasure_frequency: 0,
        last_pain_intensity: 0,
        last_pleasure_intensity: 0
      },
      thresholds: %{
        pain_critical: 0.7,
        pain_warning: 0.5,
        pleasure_reinforcement: 0.6
      },
      amqp_channel: nil,
      consumer_tag: nil
    }

    # Set up AMQP consumer for algedonic signals
    state_with_amqp = setup_algedonic_consumer(state)

    {:ok, state_with_amqp}
  end

  @impl true
  def handle_cast({:pleasure_signal, intensity, context}, state) do
    Logger.info(
      "AlgedonicProcessor: Processing pleasure signal (#{intensity}) from #{inspect(context)}"
    )

    # Record the signal
    new_signal = {:pleasure, intensity, context, DateTime.utc_now()}
    new_signals = [new_signal | state.algedonic_signals] |> Enum.take(1000)

    # Update signal patterns
    new_patterns = update_signal_patterns(state.signal_patterns, :pleasure, intensity)

    # Update viability metrics
    ViabilityEvaluator.update_from_signal(:pleasure, intensity)

    # Reinforce successful policies if intensity is high
    if intensity > state.thresholds.pleasure_reinforcement do
      reinforce_current_policies(context, intensity)
    end

    # Broadcast the signal
    broadcast_algedonic_signal(:pleasure, intensity, context)

    new_state = %{state | algedonic_signals: new_signals, signal_patterns: new_patterns}

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:pain_signal, intensity, context}, state) do
    Logger.warning(
      "AlgedonicProcessor: Processing pain signal (#{intensity}) from #{inspect(context)}"
    )

    # Record the signal
    new_signal = {:pain, intensity, context, DateTime.utc_now()}
    new_signals = [new_signal | state.algedonic_signals] |> Enum.take(1000)

    # Update signal patterns
    new_patterns = update_signal_patterns(state.signal_patterns, :pain, intensity)

    # Update viability metrics
    ViabilityEvaluator.update_from_signal(:pain, intensity)

    # Handle critical pain signals
    if intensity > state.thresholds.pain_critical do
      handle_critical_pain(intensity, context, state)
    else
      if intensity > state.thresholds.pain_warning do
        handle_warning_pain(intensity, context)
      end
    end

    # Broadcast the signal
    broadcast_algedonic_signal(:pain, intensity, context)

    new_state = %{state | algedonic_signals: new_signals, signal_patterns: new_patterns}

    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_signal_history, limit}, _from, state) do
    history =
      state.algedonic_signals
      |> Enum.take(limit)
      |> Enum.map(fn {type, intensity, context, timestamp} ->
        %{
          type: type,
          intensity: intensity,
          context: context,
          timestamp: timestamp
        }
      end)

    {:reply, {:ok, history}, state}
  end

  @impl true
  def handle_call(:get_algedonic_state, _from, state) do
    algedonic_state = %{
      recent_signals: Enum.take(state.algedonic_signals, 10),
      patterns: state.signal_patterns,
      pain_level: calculate_current_pain_level(state.algedonic_signals),
      pleasure_level: calculate_current_pleasure_level(state.algedonic_signals),
      trend: analyze_signal_trend(state.algedonic_signals)
    }

    {:reply, {:ok, algedonic_state}, state}
  end

  @impl true
  def handle_call(:analyze_signal_patterns, _from, state) do
    patterns = analyze_patterns(state.algedonic_signals)
    {:reply, {:ok, patterns}, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    # Handle AMQP message from algedonic channel
    case Jason.decode(payload) do
      {:ok, message} ->
        Logger.info("AlgedonicProcessor: Received AMQP signal: #{message["signal_type"]}")

        # Process the algedonic signal
        new_state = process_amqp_signal(message, state)

        # Acknowledge the message
        if state.amqp_channel do
          AMQP.Basic.ack(state.amqp_channel, meta.delivery_tag)
        end

        {:noreply, new_state}

      {:error, _} ->
        Logger.error("AlgedonicProcessor: Failed to decode algedonic message")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    Logger.info("AlgedonicProcessor: AMQP consumer registered successfully")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_cancel, _meta}, state) do
    Logger.warning("AlgedonicProcessor: AMQP consumer cancelled")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_cancel_ok, _meta}, state) do
    Logger.info("AlgedonicProcessor: AMQP consumer cancel confirmed")
    {:noreply, state}
  end

  @impl true
  def handle_info(:retry_amqp_setup, state) do
    Logger.info("AlgedonicProcessor: Retrying AMQP setup...")
    new_state = setup_algedonic_consumer(state)
    {:noreply, new_state}
  end

  # Private Functions

  defp setup_algedonic_consumer(state) do
    case VsmPhoenix.AMQP.ConnectionManager.get_channel(:algedonic_processor) do
      {:ok, channel} ->
        try do
          # Ensure queue exists
          {:ok, _queue} = AMQP.Queue.declare(channel, "vsm.system5.algedonic", durable: true)

          # Bind queue to algedonic exchange
          :ok = AMQP.Queue.bind(channel, "vsm.system5.algedonic", "vsm.algedonic")

          # Set up consumer
          {:ok, consumer_tag} = AMQP.Basic.consume(channel, "vsm.system5.algedonic")

          Logger.info("AlgedonicProcessor: AMQP consumer active! Tag: #{consumer_tag}")

          %{state | amqp_channel: channel, consumer_tag: consumer_tag}
        rescue
          error ->
            Logger.error("AlgedonicProcessor: Failed to set up AMQP consumer: #{inspect(error)}")
            Process.send_after(self(), :retry_amqp_setup, 5000)
            state
        end

      {:error, reason} ->
        Logger.error("AlgedonicProcessor: Could not get AMQP channel: #{inspect(reason)}")
        Process.send_after(self(), :retry_amqp_setup, 5000)
        state
    end
  end

  defp process_amqp_signal(message, state) do
    signal_type = String.to_atom(message["signal_type"])
    intensity = abs(message["viability_delta"] || message["intensity"] || 0.5)
    context = message["context"]

    case signal_type do
      :pain ->
        GenServer.cast(self(), {:pain_signal, intensity, context})

      :pleasure ->
        GenServer.cast(self(), {:pleasure_signal, intensity, context})

      _ ->
        Logger.warning("AlgedonicProcessor: Unknown signal type: #{signal_type}")
    end

    state
  end

  defp update_signal_patterns(patterns, :pain, intensity) do
    %{patterns | pain_frequency: patterns.pain_frequency + 1, last_pain_intensity: intensity}
  end

  defp update_signal_patterns(patterns, :pleasure, intensity) do
    %{
      patterns
      | pleasure_frequency: patterns.pleasure_frequency + 1,
        last_pleasure_intensity: intensity
    }
  end

  defp handle_critical_pain(intensity, context, state) do
    Logger.error("🚨 CRITICAL PAIN SIGNAL - Immediate intervention required!")

    # Request immediate adaptation with error handling
    try do
      Intelligence.generate_adaptation_proposal(%{
        type: :algedonic_response,
        urgency: :critical,
        pain_level: intensity,
        context: context
      })
    rescue
      e ->
        Logger.error("Failed to generate adaptation proposal for critical pain: #{inspect(e)}")
    end

    # Trigger LLM-based policy synthesis with supervision
    Task.Supervisor.start_child(VsmPhoenix.TaskSupervisor, fn ->
      try do
        Logger.info("🧠 TRIGGERING LLM POLICY SYNTHESIS FROM CRITICAL PAIN")
        
        # Add timeout protection for policy synthesis
        task = Task.async(fn ->
          anomaly_data = %{
            type: :pain_signal,
            intensity: intensity,
            context: context,
            severity: intensity,
            timestamp: DateTime.utc_now(),
            system_state: summarize_system_state(state)
          }

          PolicySynthesizer.synthesize_policy_from_anomaly(anomaly_data)
        end)
        
        case Task.yield(task, 30_000) || Task.shutdown(task, :brutal_kill) do
          {:ok, {:ok, policy}} ->
            Logger.info("✅ EMERGENCY POLICY SYNTHESIZED: #{policy.id}")
            # Apply the new policy immediately with error handling
            try do
              PolicyManager.synthesize_policy(policy)
            rescue
              e ->
                Logger.error("Failed to apply emergency policy: #{inspect(e)}")
            end

          {:ok, {:error, reason}} ->
            Logger.error("Emergency policy synthesis failed: #{inspect(reason)}")
            
          nil ->
            Logger.error("Emergency policy synthesis timed out after 30 seconds")
            
          {:exit, reason} ->
            Logger.error("Emergency policy synthesis crashed: #{inspect(reason)}")
        end
      rescue
        e ->
          Logger.error("Critical error in policy synthesis task: #{inspect(e)}")
      end
    end)

    # Broadcast emergency with error handling
    try do
      Phoenix.PubSub.broadcast(
        VsmPhoenix.PubSub,
        "vsm:emergency",
        {:critical_pain, intensity, context}
      )
    rescue
      e ->
        Logger.error("Failed to broadcast emergency: #{inspect(e)}")
    end
  end

  defp handle_warning_pain(intensity, context) do
    Logger.warning("⚠️  WARNING PAIN SIGNAL - Monitoring required")

    # Request high-priority adaptation
    Intelligence.generate_adaptation_proposal(%{
      type: :algedonic_response,
      urgency: :high,
      pain_level: intensity,
      context: context
    })
  end

  defp reinforce_current_policies(context, intensity) do
    Logger.info("💚 Reinforcing policies due to pleasure signal")

    # In a full implementation, this would analyze which policies
    # contributed to the positive outcome and strengthen them
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:policy",
      {:reinforce_policies, context, intensity}
    )
  end

  defp broadcast_algedonic_signal(type, intensity, context) do
    message = %{
      signal_type: type,
      intensity: intensity,
      context: context,
      timestamp: DateTime.utc_now()
    }

    # PubSub broadcast
    Phoenix.PubSub.broadcast(
      VsmPhoenix.PubSub,
      "vsm:algedonic",
      {:algedonic_signal, message}
    )

    # AMQP broadcast if available
    # (Note: We receive from AMQP but might also want to publish processed signals)
  end

  defp calculate_current_pain_level(signals) do
    recent_pain =
      signals
      |> Enum.take(10)
      |> Enum.filter(fn {type, _, _, _} -> type == :pain end)
      |> Enum.map(fn {_, intensity, _, _} -> 
        # Validate intensity is numeric and in valid range
        case intensity do
          n when is_number(n) -> min(max(n, 0.0), 1.0)
          _ -> 0.0
        end
      end)

    if Enum.empty?(recent_pain), do: 0.0, else: Enum.sum(recent_pain) / length(recent_pain)
  end

  defp calculate_current_pleasure_level(signals) do
    recent_pleasure =
      signals
      |> Enum.take(10)
      |> Enum.filter(fn {type, _, _, _} -> type == :pleasure end)
      |> Enum.map(fn {_, intensity, _, _} -> 
        # Validate intensity is numeric and in valid range
        case intensity do
          n when is_number(n) -> min(max(n, 0.0), 1.0)
          _ -> 0.0
        end
      end)

    if Enum.empty?(recent_pleasure),
      do: 0.0,
      else: Enum.sum(recent_pleasure) / length(recent_pleasure)
  end

  defp analyze_signal_trend(signals) do
    recent = Enum.take(signals, 20)

    if length(recent) < 2 do
      :stable
    else
      pain_count = Enum.count(recent, fn {type, _, _, _} -> type == :pain end)
      pleasure_count = Enum.count(recent, fn {type, _, _, _} -> type == :pleasure end)

      cond do
        pain_count > pleasure_count * 2 -> :deteriorating
        pleasure_count > pain_count * 2 -> :improving
        true -> :stable
      end
    end
  end

  defp analyze_patterns(signals) do
    total = length(signals)
    pain_signals = Enum.filter(signals, fn {type, _, _, _} -> type == :pain end)
    pleasure_signals = Enum.filter(signals, fn {type, _, _, _} -> type == :pleasure end)

    %{
      total_signals: total,
      pain_count: length(pain_signals),
      pleasure_count: length(pleasure_signals),
      pain_ratio: if(total > 0, do: length(pain_signals) / total, else: 0),
      pleasure_ratio: if(total > 0, do: length(pleasure_signals) / total, else: 0),
      average_pain_intensity: calculate_average_intensity(pain_signals),
      average_pleasure_intensity: calculate_average_intensity(pleasure_signals),
      temporal_patterns: analyze_temporal_patterns(signals),
      context_patterns: analyze_context_patterns(signals)
    }
  end

  defp calculate_average_intensity(signals) do
    intensities = Enum.map(signals, fn {_, intensity, _, _} -> 
      # Validate intensity
      case intensity do
        n when is_number(n) -> min(max(n, 0.0), 1.0)
        _ -> 0.0
      end
    end)
    if Enum.empty?(intensities), do: 0.0, else: Enum.sum(intensities) / length(intensities)
  end

  defp analyze_temporal_patterns(signals) do
    # Group signals by hour to find patterns
    hourly_groups =
      signals
      |> Enum.group_by(fn {_, _, _, timestamp} ->
        timestamp.hour
      end)
      |> Enum.map(fn {hour, sigs} -> {hour, length(sigs)} end)
      |> Enum.sort()

    %{
      peak_hours: find_peak_hours(hourly_groups),
      quiet_hours: find_quiet_hours(hourly_groups)
    }
  end

  defp find_peak_hours(hourly_groups) do
    if Enum.empty?(hourly_groups) do
      []
    else
      max_count = hourly_groups |> Enum.map(fn {_, count} -> count end) |> Enum.max()

      hourly_groups
      |> Enum.filter(fn {_, count} -> count == max_count end)
      |> Enum.map(fn {hour, _} -> hour end)
    end
  end

  defp find_quiet_hours(hourly_groups) do
    if Enum.empty?(hourly_groups) do
      []
    else
      min_count = hourly_groups |> Enum.map(fn {_, count} -> count end) |> Enum.min()

      hourly_groups
      |> Enum.filter(fn {_, count} -> count == min_count end)
      |> Enum.map(fn {hour, _} -> hour end)
    end
  end

  defp analyze_context_patterns(signals) do
    # Group by context to find common sources
    context_groups =
      signals
      |> Enum.group_by(fn {_, _, context, _} ->
        case context do
          %{} -> Map.get(context, :source, "unknown")
          _ -> "unknown"
        end
      end)
      |> Enum.map(fn {source, sigs} ->
        {source,
         %{
           count: length(sigs),
           pain_count: Enum.count(sigs, fn {type, _, _, _} -> type == :pain end),
           pleasure_count: Enum.count(sigs, fn {type, _, _, _} -> type == :pleasure end)
         }}
      end)
      |> Map.new()

    context_groups
  end

  defp summarize_system_state(state) do
    %{
      recent_signals: Enum.take(state.algedonic_signals, 5),
      signal_patterns: state.signal_patterns,
      signal_count: length(state.algedonic_signals)
    }
  end
end
