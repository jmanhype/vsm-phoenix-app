defmodule VsmPhoenix.Telemetry.Core.SignalRegistry do
  @moduledoc """
  Signal Registry - Single Responsibility for Signal Management
  
  Handles ONLY signal registration, configuration, and lifecycle management.
  Extracted from AnalogArchitect god object to follow Single Responsibility Principle.
  
  Responsibilities:
  - Signal registration and deregistration
  - Configuration validation and defaults
  - Signal metadata management
  - Registration events and notifications
  """

  use GenServer
  use VsmPhoenix.Telemetry.Behaviors.ResilienceBehavior
  use VsmPhoenix.Telemetry.Behaviors.SharedLogging

  alias VsmPhoenix.Telemetry.Abstractions.TelemetryDataStore
  alias VsmPhoenix.Telemetry.Factories.TelemetryFactory

  @sampling_rates %{
    high_frequency: 100,    # 100Hz - for critical real-time metrics
    standard: 10,           # 10Hz - for normal operations
    low_frequency: 1        # 1Hz - for slow-changing metrics
  }

  @default_signal_config %{
    sampling_rate: :standard,
    buffer_size: 1000,
    filters: [],
    analysis_modes: [:basic],
    retention_policy: :default,
    auto_cleanup: true
  }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register a new signal with configuration
  """
  def register_signal(signal_id, config) when is_binary(signal_id) do
    GenServer.call(__MODULE__, {:register_signal, signal_id, config})
  end

  @doc """
  Unregister a signal and cleanup resources
  """
  def unregister_signal(signal_id) when is_binary(signal_id) do
    GenServer.call(__MODULE__, {:unregister_signal, signal_id})
  end

  @doc """
  Get signal configuration
  """
  def get_signal_config(signal_id) when is_binary(signal_id) do
    GenServer.call(__MODULE__, {:get_signal_config, signal_id})
  end

  @doc """
  Update signal configuration
  """
  def update_signal_config(signal_id, config_updates) when is_binary(signal_id) do
    GenServer.call(__MODULE__, {:update_signal_config, signal_id, config_updates})
  end

  @doc """
  List all registered signals
  """
  def list_signals(filter \\ %{}) do
    GenServer.call(__MODULE__, {:list_signals, filter})
  end

  @doc """
  Get signal statistics
  """
  def get_signal_stats(signal_id) when is_binary(signal_id) do
    GenServer.call(__MODULE__, {:get_signal_stats, signal_id})
  end

  # Server Implementation

  @impl true
  def init(opts) do
    log_init_event(__MODULE__, :starting)
    
    data_store = TelemetryFactory.create_data_store(
      Keyword.get(opts, :data_store_type, :ets)
    )
    
    state = %{
      data_store: data_store,
      registered_signals: %{},
      signal_stats: %{},
      registry_events: []
    }
    
    log_init_event(__MODULE__, :initialized, %{data_store: data_store})
    {:ok, state}
  end

  @impl true
  def handle_call({:register_signal, signal_id, config}, _from, state) do
    safe_operation("register_signal", fn ->
      # Validate signal ID
      case validate_signal_id(signal_id) do
        :ok -> 
          register_signal_internal(signal_id, config, state)
        error -> 
          {:error, error}
      end
    end)
    |> case do
      {:ok, {:ok, new_state}} ->
        {:reply, :ok, new_state}
      {:ok, {:error, reason}} ->
        {:reply, {:error, reason}, state}
      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:unregister_signal, signal_id}, _from, state) do
    safe_operation("unregister_signal", fn ->
      unregister_signal_internal(signal_id, state)
    end)
    |> case do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_signal_config, signal_id}, _from, state) do
    case Map.get(state.registered_signals, signal_id) do
      nil -> 
        {:reply, {:error, :signal_not_found}, state}
      config -> 
        {:reply, {:ok, config}, state}
    end
  end

  @impl true
  def handle_call({:update_signal_config, signal_id, config_updates}, _from, state) do
    safe_operation("update_signal_config", fn ->
      update_signal_config_internal(signal_id, config_updates, state)
    end)
    |> case do
      {:ok, new_state} ->
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_signals, filter}, _from, state) do
    signals = state.registered_signals
    |> Enum.filter(fn {_id, config} -> matches_filter?(config, filter) end)
    |> Enum.into(%{})
    
    {:reply, {:ok, signals}, state}
  end

  @impl true
  def handle_call({:get_signal_stats, signal_id}, _from, state) do
    case Map.get(state.signal_stats, signal_id) do
      nil -> 
        {:reply, {:error, :signal_not_found}, state}
      stats -> 
        {:reply, {:ok, stats}, state}
    end
  end

  # Private Implementation

  defp register_signal_internal(signal_id, user_config, state) do
    # Check if signal already exists
    case Map.get(state.registered_signals, signal_id) do
      nil ->
        # Create new signal registration
        config = build_signal_config(user_config)
        validated_config = validate_signal_config(signal_id, config)
        
        case validated_config do
          {:ok, final_config} ->
            # Store signal configuration
            new_registered_signals = Map.put(state.registered_signals, signal_id, final_config)
            
            # Initialize statistics
            initial_stats = create_initial_stats(signal_id, final_config)
            new_signal_stats = Map.put(state.signal_stats, signal_id, initial_stats)
            
            # Record registration event
            registration_event = create_registration_event(signal_id, final_config)
            new_events = [registration_event | state.registry_events] |> Enum.take(100)
            
            # Notify data store
            state.data_store.store_signal_data(signal_id, %{
              type: :signal_registration,
              config: final_config,
              registered_at: DateTime.utc_now()
            })
            
            log_info("Signal registered successfully", %{
              signal_id: signal_id,
              config: final_config
            })
            
            new_state = %{state |
              registered_signals: new_registered_signals,
              signal_stats: new_signal_stats,
              registry_events: new_events
            }
            
            {:ok, new_state}
            
          {:error, reason} ->
            log_warning("Signal registration validation failed", %{
              signal_id: signal_id,
              reason: reason
            })
            {:error, reason}
        end
        
      _existing ->
        log_warning("Signal already registered", %{signal_id: signal_id})
        {:error, :signal_already_exists}
    end
  end

  defp unregister_signal_internal(signal_id, state) do
    case Map.get(state.registered_signals, signal_id) do
      nil ->
        {:error, :signal_not_found}
      
      config ->
        # Remove from registrations
        new_registered_signals = Map.delete(state.registered_signals, signal_id)
        new_signal_stats = Map.delete(state.signal_stats, signal_id)
        
        # Record unregistration event
        unregistration_event = create_unregistration_event(signal_id, config)
        new_events = [unregistration_event | state.registry_events] |> Enum.take(100)
        
        # Cleanup data store (if configured)
        if config.auto_cleanup do
          # This would trigger cleanup in the data store
          state.data_store.store_signal_data(signal_id, %{
            type: :signal_unregistration,
            unregistered_at: DateTime.utc_now()
          })
        end
        
        log_info("Signal unregistered successfully", %{signal_id: signal_id})
        
        %{state |
          registered_signals: new_registered_signals,
          signal_stats: new_signal_stats,
          registry_events: new_events
        }
    end
  end

  defp update_signal_config_internal(signal_id, config_updates, state) do
    case Map.get(state.registered_signals, signal_id) do
      nil ->
        {:error, :signal_not_found}
      
      current_config ->
        updated_config = Map.merge(current_config, config_updates)
        
        case validate_signal_config(signal_id, updated_config) do
          {:ok, validated_config} ->
            new_registered_signals = Map.put(state.registered_signals, signal_id, validated_config)
            
            # Update statistics
            new_stats = Map.update(state.signal_stats, signal_id, %{}, fn stats ->
              Map.merge(stats, %{
                last_config_update: DateTime.utc_now(),
                config_updates_count: Map.get(stats, :config_updates_count, 0) + 1
              })
            end)
            new_signal_stats = Map.put(state.signal_stats, signal_id, new_stats)
            
            # Record update event
            update_event = create_update_event(signal_id, current_config, validated_config)
            new_events = [update_event | state.registry_events] |> Enum.take(100)
            
            log_info("Signal configuration updated", %{
              signal_id: signal_id,
              changes: config_updates
            })
            
            %{state |
              registered_signals: new_registered_signals,
              signal_stats: new_signal_stats,
              registry_events: new_events
            }
            
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Helper Functions

  defp validate_signal_id(signal_id) when is_binary(signal_id) and byte_size(signal_id) > 0, do: :ok
  defp validate_signal_id(_), do: :invalid_signal_id

  defp build_signal_config(user_config) do
    Map.merge(@default_signal_config, user_config)
    |> Map.put(:created_at, DateTime.utc_now())
    |> Map.put(:version, 1)
  end

  defp validate_signal_config(signal_id, config) do
    with :ok <- validate_sampling_rate(config.sampling_rate),
         :ok <- validate_buffer_size(config.buffer_size),
         :ok <- validate_analysis_modes(config.analysis_modes) do
      {:ok, Map.put(config, :validated_at, DateTime.utc_now())}
    else
      error -> {:error, error}
    end
  end

  defp validate_sampling_rate(rate) when rate in [:high_frequency, :standard, :low_frequency], do: :ok
  defp validate_sampling_rate(rate) when is_integer(rate) and rate > 0, do: :ok
  defp validate_sampling_rate(_), do: :invalid_sampling_rate

  defp validate_buffer_size(size) when is_integer(size) and size > 0 and size <= 10_000, do: :ok
  defp validate_buffer_size(_), do: :invalid_buffer_size

  defp validate_analysis_modes(modes) when is_list(modes), do: :ok
  defp validate_analysis_modes(_), do: :invalid_analysis_modes

  defp create_initial_stats(signal_id, config) do
    %{
      signal_id: signal_id,
      registered_at: DateTime.utc_now(),
      samples_received: 0,
      last_sample_at: nil,
      analysis_count: 0,
      config_updates_count: 0,
      health_status: :healthy
    }
  end

  defp create_registration_event(signal_id, config) do
    %{
      event_type: :signal_registered,
      signal_id: signal_id,
      timestamp: DateTime.utc_now(),
      config: config,
      metadata: %{
        sampling_rate: config.sampling_rate,
        buffer_size: config.buffer_size
      }
    }
  end

  defp create_unregistration_event(signal_id, config) do
    %{
      event_type: :signal_unregistered,
      signal_id: signal_id,
      timestamp: DateTime.utc_now(),
      previous_config: config
    }
  end

  defp create_update_event(signal_id, old_config, new_config) do
    changes = find_config_changes(old_config, new_config)
    
    %{
      event_type: :signal_config_updated,
      signal_id: signal_id,
      timestamp: DateTime.utc_now(),
      changes: changes,
      old_config: old_config,
      new_config: new_config
    }
  end

  defp find_config_changes(old_config, new_config) do
    old_config
    |> Enum.reduce(%{}, fn {key, old_value}, changes ->
      new_value = Map.get(new_config, key)
      if old_value != new_value do
        Map.put(changes, key, %{from: old_value, to: new_value})
      else
        changes
      end
    end)
  end

  defp matches_filter?(config, filter) when map_size(filter) == 0, do: true
  
  defp matches_filter?(config, filter) do
    Enum.all?(filter, fn {key, value} ->
      case Map.get(config, key) do
        ^value -> true
        list when is_list(list) -> value in list
        _ -> false
      end
    end)
  end
end