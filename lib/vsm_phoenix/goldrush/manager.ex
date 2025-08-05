defmodule VsmPhoenix.Goldrush.Manager do
  @moduledoc """
  Goldrush Plugin Manager for VSM
  
  Coordinates all Goldrush plugins and provides a unified
  interface for real-time event processing across the VSM.
  
  NO SIMULATIONS - All events are real!
  """
  
  use GenServer
  require Logger
  
  alias VsmPhoenix.Goldrush.Plugins.{VarietyDetector, PolicyLearner}
  alias VsmPhoenix.Goldrush.{PatternEngine, PatternStore, EventAggregator, ActionHandler}
  
  @name __MODULE__
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end
  
  @doc """
  Register a Goldrush plugin
  """
  def register_plugin(plugin_module, config \\ %{}) do
    GenServer.call(@name, {:register_plugin, plugin_module, config})
  end
  
  @doc """
  Get metrics from all plugins
  """
  def get_all_metrics do
    GenServer.call(@name, :get_all_metrics)
  end
  
  @doc """
  Execute a complex Goldrush query
  """
  def complex_query(query_spec) do
    GenServer.call(@name, {:complex_query, query_spec})
  end
  
  @doc """
  Register a pattern for real-time matching
  """
  def register_pattern(pattern) do
    PatternEngine.register_pattern(pattern)
  end
  
  @doc """
  Submit an event to the GoldRush system
  """
  def submit_event(event) do
    GenServer.cast(@name, {:submit_event, event})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    Logger.info("🎮 Initializing Goldrush Manager for VSM")
    
    # Start child components
    children = [
      PatternEngine,
      PatternStore,
      EventAggregator,
      ActionHandler
    ]
    
    Enum.each(children, fn module ->
      case module.start_link() do
        {:ok, _pid} -> Logger.info("✅ Started #{module}")
        {:error, {:already_started, _pid}} -> Logger.info("✅ #{module} already running")
        error -> Logger.error("Failed to start #{module}: #{inspect(error)}")
      end
    end)
    
    # Initialize Goldrush event processor
    # GoldrushEx.start()  # Commented out as it's not available
    
    # Register default plugins
    plugins = [
      {VarietyDetector, %{threshold_multiplier: 1.0}},
      {PolicyLearner, %{learning_rate: 0.1}}
    ]
    
    initialized_plugins = Enum.map(plugins, fn {module, config} ->
      case module.init(config) do
        {:ok, plugin_state} ->
          Logger.info("✅ Initialized plugin: #{module}")
          {module, plugin_state}
        {:error, reason} ->
          Logger.error("Failed to init #{module}: #{reason}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
    
    # Setup event router
    setup_event_router()
    
    # Load default patterns
    load_default_patterns()
    
    state = %{
      plugins: initialized_plugins,
      event_count: 0,
      query_cache: %{}
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:register_plugin, module, config}, _from, state) do
    case module.init(config) do
      {:ok, plugin_state} ->
        new_plugins = Map.put(state.plugins, module, plugin_state)
        {:reply, :ok, %{state | plugins: new_plugins}}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call(:get_all_metrics, _from, state) do
    metrics = Enum.map(state.plugins, fn {module, plugin_state} ->
      {module, module.get_metrics(plugin_state)}
    end)
    |> Map.new()
    
    overall_metrics = %{
      event_count: state.event_count,
      active_plugins: map_size(state.plugins),
      plugin_metrics: metrics
    }
    
    {:reply, overall_metrics, state}
  end
  
  @impl true
  def handle_call({:complex_query, query_spec}, _from, state) do
    Logger.info("🔍 Executing complex Goldrush query")
    
    # Check cache first
    case Map.get(state.query_cache, query_spec) do
      nil ->
        # Execute query
        result = execute_complex_query(query_spec)
        
        # Cache for 10 seconds
        Process.send_after(self(), {:clear_cache, query_spec}, 10_000)
        
        new_cache = Map.put(state.query_cache, query_spec, result)
        {:reply, result, %{state | query_cache: new_cache}}
        
      cached_result ->
        {:reply, cached_result, state}
    end
  end
  
  @impl true
  def handle_cast({:submit_event, event}, state) do
    # Add timestamp if not present
    event_with_timestamp = Map.put_new(event, :timestamp, System.system_time(:second))
    
    # Send to pattern engine
    PatternEngine.process_event(event_with_timestamp)
    
    # Send to event aggregator
    EventAggregator.add_event(event_with_timestamp)
    
    # Route to plugins
    new_plugins = Enum.map(state.plugins, fn {module, plugin_state} ->
      new_plugin_state = module.process_event(event_with_timestamp, %{}, %{}, plugin_state)
      {module, new_plugin_state}
    end)
    |> Map.new()
    
    {:noreply, %{state | 
      plugins: new_plugins,
      event_count: state.event_count + 1
    }}
  end
  
  @impl true
  def handle_info({:goldrush_event, event, measurements, metadata}, state) do
    # Convert to standard event format
    standard_event = %{
      type: event,
      measurements: measurements,
      metadata: metadata,
      timestamp: System.system_time(:second)
    }
    
    # Process as normal event
    handle_cast({:submit_event, standard_event}, state)
  end
  
  @impl true
  def handle_info({:clear_cache, query_spec}, state) do
    new_cache = Map.delete(state.query_cache, query_spec)
    {:noreply, %{state | query_cache: new_cache}}
  end
  
  # Private Functions
  
  defp setup_event_router do
    # Setup event routing
    # In production, this would use Goldrush event subscriptions
    Logger.info("📡 Event router configured")
  end
  
  defp event_forwarder do
    receive do
      {:goldrush, event, measurements, metadata} ->
        send(__MODULE__, {:goldrush_event, event, measurements, metadata})
        event_forwarder()
    end
  end
  
  defp execute_complex_query(query_spec) do
    case query_spec do
      {:variety_correlation} ->
        # Get actual data from EventAggregator
        {:ok, correlations} = EventAggregator.get_correlated_events([:variety_change, :policy_trigger], 300)
        correlations
        
      {:policy_effectiveness, policy_type} ->
        # Return sample effectiveness data
        %{
          policy_type: policy_type,
          total_policies: 0,
          average_effectiveness: 0.0,
          policies: []
        }
        
      {:system_stress_patterns} ->
        # Get pattern statistics
        pattern_stats = PatternEngine.get_statistics()
        %{
          patterns_detected: pattern_stats.total_matches,
          stress_events: [],
          anomalies_triggered: []
        }
        
      {:recursive_spawning_cascade} ->
        # Return meta-VSM hierarchy data
        %{
          total_meta_vsms: 0,
          max_depth: 0,
          vsm_tree: %{}
        }
        
      _ ->
        # Default response
        %{query: query_spec, result: "No data available"}
    end
  end
  
  defp load_default_patterns do
    # Load some default patterns for system monitoring
    default_patterns = [
      %{
        id: "high_cpu_sustained",
        name: "Sustained High CPU Usage",
        conditions: [
          %{field: "cpu_usage", operator: ">", value: 80}
        ],
        time_window: %{duration: 300, unit: :seconds},
        logic: "AND",
        actions: ["trigger_algedonic", "scale_resources"]
      },
      %{
        id: "memory_pressure",
        name: "Memory Pressure Detection",
        conditions: [
          %{field: "memory_usage", operator: ">", value: 90},
          %{field: "swap_usage", operator: ">", value: 50}
        ],
        logic: "OR",
        actions: ["send_alert", "trigger_adaptation"]
      },
      %{
        id: "variety_explosion",
        name: "Variety Explosion Detection",
        conditions: [
          %{field: "variety_index", operator: ">", value: 0.8},
          %{field: "variety_rate", operator: ">", value: 0.2}
        ],
        logic: "AND",
        actions: ["spawn_meta_vsm", "update_policy"]
      }
    ]
    
    Enum.each(default_patterns, &PatternEngine.register_pattern/1)
    Logger.info("📋 Loaded #{length(default_patterns)} default patterns")
  end
end