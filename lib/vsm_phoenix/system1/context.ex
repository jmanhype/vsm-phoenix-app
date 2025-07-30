defmodule VsmPhoenix.System1.Context do
  @moduledoc """
  System 1 - Context: Base module for operational contexts
  
  Provides the foundation for autonomous operational units that:
  - Handle specific business functions
  - Operate with high autonomy
  - Coordinate through System 2
  - Report to System 3
  """
  
  defmacro __using__(opts) do
    quote do
      use GenServer
      require Logger
      
      alias Phoenix.PubSub
      alias VsmPhoenix.System2.Coordinator
      alias VsmPhoenix.System3.Control
      
      @context_name unquote(opts[:name]) || __MODULE__
      @context_type unquote(opts[:type]) || :generic
      @pubsub VsmPhoenix.PubSub
      
      # Client API
      
      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: @context_name)
      end
      
      def execute_operation(operation) do
        GenServer.call(@context_name, {:execute_operation, operation})
      end
      
      def get_state do
        GenServer.call(@context_name, :get_state)
      end
      
      def get_metrics do
        GenServer.call(@context_name, :get_metrics)
      end
      
      def coordinate_with(other_context, message) do
        GenServer.call(@context_name, {:coordinate_with, other_context, message})
      end
      
      # Server Callbacks
      
      @impl true
      def init(opts) do
        Logger.info("System 1 Context #{@context_name} initializing...")
        
        # Register with coordinator
        Coordinator.register_context(@context_name, %{
          type: @context_type,
          capabilities: capabilities(),
          started_at: DateTime.utc_now()
        })
        
        # Subscribe to context topics
        PubSub.subscribe(@pubsub, "vsm:context:#{@context_name}")
        PubSub.subscribe(@pubsub, "vsm:system1")
        
        base_state = %{
          context_name: @context_name,
          context_type: @context_type,
          operational_state: :active,
          metrics: initial_metrics(),
          operations_queue: :queue.new(),
          resources: %{},
          coordination_state: %{}
        }
        
        # Allow context to customize initialization
        custom_state = initialize_context(base_state, opts)
        
        # Schedule periodic health check
        schedule_health_check()
        
        {:ok, custom_state}
      end
      
      @impl true
      def handle_call({:execute_operation, operation}, from, state) do
        Logger.debug("#{@context_name}: Executing operation #{inspect(operation)}")
        
        # Check if we have resources
        case request_resources_if_needed(operation, state) do
          {:ok, updated_state} ->
            # Execute the operation
            case execute_context_operation(operation, updated_state) do
              {:ok, result, new_state} ->
                # Report success metrics
                report_operation_success(operation)
                {:reply, {:ok, result}, new_state}
                
              {:error, reason, new_state} ->
                # Report failure metrics
                report_operation_failure(operation, reason)
                {:reply, {:error, reason}, new_state}
            end
            
          {:error, :insufficient_resources} ->
            {:reply, {:error, :insufficient_resources}, state}
        end
      end
      
      @impl true
      def handle_call(:get_state, _from, state) do
        {:reply, state, state}
      end
      
      @impl true
      def handle_call(:get_metrics, _from, state) do
        {:reply, state.metrics, state}
      end
      
      @impl true
      def handle_call(:get_operational_state, _from, state) do
        # Return comprehensive operational state
        operational_state = %{
          context_type: @context_type,
          context_name: @context_name,
          capabilities: capabilities(),
          metrics: state.metrics,
          configuration: state.configuration,
          active_operations: map_size(state.active_operations || %{}),
          operational_status: determine_operational_status(state),
          coordination_links: state.coordination_links || [],
          resource_usage: calculate_resource_usage(state),
          health_status: calculate_context_health(state)
        }
        
        {:reply, {:ok, operational_state}, state}
      end
      
      @impl true
      def handle_call({:coordinate_with, other_context, message}, _from, state) do
        # Use System 2 for coordination
        case Coordinator.coordinate_message(@context_name, other_context, message) do
          {:allow, _} ->
            {:reply, :ok, state}
          {:delay, duration, _} ->
            {:reply, {:delayed, duration}, state}
          {:block, reason} ->
            {:reply, {:blocked, reason}, state}
        end
      end
      
      @impl true
      def handle_call({:spawn_meta_system, meta_config}, _from, state) do
        Logger.info("🌀 SPAWNING RECURSIVE META-SYSTEM IN #{@context_name}")
        
        # THIS IS THE RECURSIVE BREAKTHROUGH!
        # Each S1 contains its own S3-4-5 meta-system
        meta_state = %{
          meta_system3: start_meta_control(meta_config),
          meta_system4: start_meta_intelligence(meta_config),
          meta_system5: start_meta_governance(meta_config),
          recursive_depth: Map.get(meta_config, :recursive_depth, 1)
        }
        
        # Connect via AMQP for infinite recursion
        {:ok, amqp_channel} = establish_recursive_amqp(meta_state)
        
        new_state = Map.put(state, :meta_systems, meta_state)
        |> Map.put(:amqp_recursive_channel, amqp_channel)
        
        Logger.info("🔥 META-SYSTEM ACTIVE: S1 now contains S3-4-5!")
        {:reply, {:ok, meta_state}, new_state}
      end
      
      @impl true
      def handle_cast({:register_meta_vsm, vsm_id, supervisor_pid}, state) do
        Logger.info("#{@context_name}: Registering meta-VSM #{vsm_id}")
        
        meta_vsms = Map.get(state, :meta_vsms, %{})
        new_meta_vsms = Map.put(meta_vsms, vsm_id, %{
          supervisor: supervisor_pid,
          spawned_at: DateTime.utc_now(),
          status: :active
        })
        
        {:noreply, Map.put(state, :meta_vsms, new_meta_vsms)}
      end
      
      @impl true
      def handle_info(:health_check, state) do
        # Perform health check
        health = calculate_health(state)
        
        # Report to System 3
        PubSub.broadcast(@pubsub, "vsm:health", {
          :health_report,
          @context_name,
          health
        })
        
        # Check if intervention needed
        new_state = if health < 0.7 do
          request_intervention(state, health)
        else
          state
        end
        
        schedule_health_check()
        {:noreply, new_state}
      end
      
      @impl true
      def handle_info({:coordinated_message, message}, state) do
        # Handle coordinated message from System 2
        new_state = handle_coordinated_message(message, state)
        {:noreply, new_state}
      end
      
      @impl true
      def handle_info({:resource_reallocation, _}, state) do
        # Handle resource reallocation from System 3
        Logger.warning("#{@context_name}: Resources reallocated")
        new_state = handle_resource_reallocation(state)
        {:noreply, new_state}
      end
      
      @impl true
      def handle_info({:sync, sync_action}, state) do
        # Handle synchronization from System 2
        new_state = apply_synchronization(sync_action, state)
        {:noreply, new_state}
      end
      
      # Private Functions
      
      defp request_resources_if_needed(operation, state) do
        required = estimate_resources(operation)
        
        if has_sufficient_resources?(required, state) do
          {:ok, state}
        else
          case Control.allocate_resources(%{
            context: @context_name,
            resources: required,
            priority: operation[:priority] || :normal
          }) do
            {:ok, allocation_id} ->
              new_resources = Map.merge(state.resources, required)
              {:ok, %{state | resources: new_resources}}
              
            {:error, _reason} ->
              {:error, :insufficient_resources}
          end
        end
      end
      
      defp has_sufficient_resources?(required, state) do
        Enum.all?(required, fn {resource, amount} ->
          Map.get(state.resources, resource, 0) >= amount
        end)
      end
      
      defp report_operation_success(operation) do
        PubSub.broadcast(@pubsub, "vsm:metrics", {
          :operation_complete,
          @context_name,
          operation,
          :success
        })
      end
      
      defp report_operation_failure(operation, reason) do
        PubSub.broadcast(@pubsub, "vsm:metrics", {
          :operation_complete,
          @context_name,
          operation,
          {:failure, reason}
        })
      end
      
      defp calculate_health(state) do
        # Base health calculation
        operational = if state.operational_state == :active, do: 1.0, else: 0.5
        
        # Context-specific health
        context_health = calculate_context_health(state)
        
        (operational + context_health) / 2
      end
      
      defp request_intervention(state, health) do
        Logger.warning("#{@context_name}: Requesting intervention, health: #{health}")
        
        PubSub.broadcast(@pubsub, "vsm:intervention", {
          :intervention_request,
          @context_name,
          health,
          analyze_issues(state)
        })
        
        state
      end
      
      defp analyze_issues(state) do
        # Analyze what's wrong
        []  # Context should override
      end
      
      defp apply_synchronization(sync_action, state) do
        # Apply synchronization action
        %{state | coordination_state: Map.put(state.coordination_state, :last_sync, DateTime.utc_now())}
      end
      
      defp handle_resource_reallocation(state) do
        # Handle resource reallocation
        %{state | resources: %{}}  # Context should implement proper handling
      end
      
      defp schedule_health_check do
        Process.send_after(self(), :health_check, 30_000)  # Every 30 seconds
      end
      
      defp start_meta_control(meta_config) do
        {:ok, pid} = GenServer.start_link(
          VsmPhoenix.System3.Control,
          [meta: true, parent: self(), config: meta_config]
        )
        pid
      end
      
      defp start_meta_intelligence(meta_config) do
        {:ok, pid} = GenServer.start_link(
          VsmPhoenix.System4.Intelligence,
          [meta: true, parent: self(), llm_enabled: true, config: meta_config]
        )
        pid
      end
      
      defp start_meta_governance(meta_config) do
        {:ok, pid} = GenServer.start_link(
          VsmPhoenix.System5.Queen,
          [meta: true, parent: self(), recursive: true, config: meta_config]
        )
        pid
      end
      
      defp establish_recursive_amqp(meta_state) do
        """
        THIS IS THE VSMCP PROTOCOL!
        AMQP enables recursive MCP-like communication between meta-systems
        """
        # TODO: Real AMQP connection
        {:ok, :fake_channel}
      end
      
      # Helper functions
      
      defp determine_operational_status(state) do
        health = calculate_context_health(state)
        
        cond do
          health > 0.9 -> :optimal
          health > 0.7 -> :healthy
          health > 0.5 -> :degraded
          health > 0.3 -> :stressed
          true -> :critical
        end
      end
      
      defp calculate_resource_usage(state) do
        # Calculate resource usage based on active operations
        active_ops = Map.get(state, :active_operations, %{})
        
        if map_size(active_ops) == 0 do
          %{cpu: 0.0, memory: 0.0, io: 0.0}
        else
          # Simulate resource usage calculation
          ops_count = map_size(active_ops)
          %{
            cpu: min(ops_count * 0.1, 1.0),
            memory: min(ops_count * 0.05, 1.0),
            io: min(ops_count * 0.02, 1.0)
          }
        end
      end
      
      # Callbacks for contexts to implement
      
      def capabilities, do: []
      def initial_metrics, do: %{}
      def initialize_context(state, _opts), do: state
      def execute_context_operation(_operation, state), do: {:ok, :not_implemented, state}
      def estimate_resources(_operation), do: %{}
      def calculate_context_health(_state), do: 1.0
      def handle_coordinated_message(_message, state), do: state
      
      defoverridable [
        capabilities: 0,
        initial_metrics: 0,
        initialize_context: 2,
        execute_context_operation: 2,
        estimate_resources: 1,
        calculate_context_health: 1,
        handle_coordinated_message: 2
      ]
    end
  end
end