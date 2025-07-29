defmodule VsmPhoenix.System1.Operations do
  @moduledoc """
  System 1 - Operations: Example operational context
  
  Demonstrates a concrete System 1 implementation for
  core business operations.
  """
  
  use VsmPhoenix.System1.Context,
    name: :operations_context,
    type: :operations
  
  alias VsmPhoenix.System3.Control
  alias VsmPhoenix.System4.Intelligence
  alias VsmPhoenix.System5.Queen
  
  # Public API for meta-system spawning
  
  def spawn_meta_system(meta_config) do
    Logger.info("🌀 SPAWNING META-VSM: #{meta_config.identity}")
    
    # Create a new supervision tree for the meta-VSM
    children = [
      # Meta-S3: Control for the specialized domain
      {Control, name: :"#{meta_config.identity}_control", meta: true},
      
      # Meta-S4: Intelligence specialized for this domain
      {Intelligence, name: :"#{meta_config.identity}_intelligence", meta: true},
      
      # Meta-S5: Queen for autonomous governance
      {Queen, name: :"#{meta_config.identity}_queen", meta: true}
    ]
    
    # Start the meta-VSM supervisor
    case Supervisor.start_link(children, strategy: :one_for_one, name: :"#{meta_config.identity}_supervisor") do
      {:ok, supervisor_pid} ->
        Logger.info("✅ META-VSM SPAWNED: #{meta_config.identity} (PID: #{inspect(supervisor_pid)})")
        
        # Store meta-VSM reference
        GenServer.cast(@context_name, {:register_meta_vsm, meta_config.identity, supervisor_pid})
        
        # Initialize with parent policy constraints
        if meta_config[:parent_policy] do
          GenServer.cast(:"#{meta_config.identity}_queen", {:inherit_policy, meta_config})
        end
        
        {:ok, %{
          identity: meta_config.identity,
          supervisor: supervisor_pid,
          specialization: meta_config[:specialization],
          recursive_depth: meta_config[:recursive_depth]
        }}
        
      error ->
        Logger.error("❌ Failed to spawn meta-VSM: #{inspect(error)}")
        error
    end
  end
  
  # Override callbacks
  
  @impl true
  def capabilities do
    [
      :order_processing,
      :inventory_management,
      :customer_service,
      :data_processing
    ]
  end
  
  @impl true
  def initial_metrics do
    %{
      orders_processed: 0,
      average_processing_time: 0,
      success_rate: 1.0,
      customer_satisfaction: 0.95,
      inventory_accuracy: 0.98
    }
  end
  
  @impl true
  def initialize_context(state, opts) do
    Map.merge(state, %{
      operational_data: %{
        orders: %{},
        inventory: initialize_inventory(),
        customers: %{},
        processing_queue: :queue.new()
      },
      configuration: Keyword.get(opts, :config, default_config())
    })
  end
  
  @impl true
  def execute_context_operation(operation, state) do
    case operation.type do
      :process_order ->
        process_order(operation.data, state)
        
      :update_inventory ->
        update_inventory(operation.data, state)
        
      :serve_customer ->
        serve_customer(operation.data, state)
        
      :analyze_data ->
        analyze_operational_data(operation.data, state)
        
      _ ->
        {:error, :unknown_operation, state}
    end
  end
  
  @impl true
  def estimate_resources(operation) do
    case operation.type do
      :process_order -> %{compute: 0.1, memory: 0.05}
      :update_inventory -> %{compute: 0.05, memory: 0.1, storage: 0.01}
      :serve_customer -> %{compute: 0.15, memory: 0.05, network: 0.1}
      :analyze_data -> %{compute: 0.3, memory: 0.2}
      _ -> %{}
    end
  end
  
  @impl true
  def calculate_context_health(state) do
    metrics = state.metrics
    
    # Weight different factors
    weights = %{
      success_rate: 0.4,
      customer_satisfaction: 0.3,
      inventory_accuracy: 0.2,
      performance: 0.1
    }
    
    performance = if metrics.average_processing_time > 0 do
      min(1.0, 100 / metrics.average_processing_time)  # Target: 100ms
    else
      1.0
    end
    
    weighted_health = 
      metrics.success_rate * weights.success_rate +
      metrics.customer_satisfaction * weights.customer_satisfaction +
      metrics.inventory_accuracy * weights.inventory_accuracy +
      performance * weights.performance
    
    weighted_health
  end
  
  @impl true
  def handle_coordinated_message(message, state) do
    case message do
      {:order_sync, order_data} ->
        # Synchronize order data with other contexts
        sync_order_data(order_data, state)
        
      {:inventory_update, inventory_data} ->
        # Update inventory based on coordination
        apply_inventory_update(inventory_data, state)
        
      _ ->
        state
    end
  end
  
  # Private Functions
  
  defp process_order(order_data, state) do
    order_id = generate_order_id()
    
    # Validate order
    case validate_order(order_data, state) do
      :ok ->
        # Check inventory
        case check_inventory(order_data.items, state) do
          {:ok, reserved_items} ->
            # Create order record
            order = %{
              id: order_id,
              customer_id: order_data.customer_id,
              items: order_data.items,
              reserved_items: reserved_items,
              status: :processing,
              created_at: DateTime.utc_now()
            }
            
            # Update state
            new_orders = Map.put(state.operational_data.orders, order_id, order)
            new_inventory = deduct_inventory(reserved_items, state.operational_data.inventory)
            
            new_operational_data = %{state.operational_data |
              orders: new_orders,
              inventory: new_inventory
            }
            
            # Update metrics
            new_metrics = update_order_metrics(state.metrics, :success)
            
            new_state = %{state |
              operational_data: new_operational_data,
              metrics: new_metrics
            }
            
            # Coordinate with other contexts
            coordinate_order_processing(order, new_state)
            
            {:ok, %{order_id: order_id, status: :processing}, new_state}
            
          {:error, :insufficient_inventory} ->
            new_metrics = update_order_metrics(state.metrics, :inventory_failure)
            {:error, :insufficient_inventory, %{state | metrics: new_metrics}}
        end
        
      {:error, reason} ->
        new_metrics = update_order_metrics(state.metrics, :validation_failure)
        {:error, reason, %{state | metrics: new_metrics}}
    end
  end
  
  defp update_inventory(inventory_update, state) do
    Logger.info("Operations: Updating inventory")
    
    updated_inventory = apply_inventory_changes(
      inventory_update,
      state.operational_data.inventory
    )
    
    new_operational_data = %{state.operational_data |
      inventory: updated_inventory
    }
    
    # Calculate new accuracy
    accuracy = calculate_inventory_accuracy(updated_inventory)
    new_metrics = %{state.metrics | inventory_accuracy: accuracy}
    
    new_state = %{state |
      operational_data: new_operational_data,
      metrics: new_metrics
    }
    
    {:ok, %{items_updated: map_size(inventory_update)}, new_state}
  end
  
  defp serve_customer(customer_request, state) do
    Logger.info("Operations: Serving customer request")
    
    response = case customer_request.type do
      :order_status ->
        get_order_status(customer_request.order_id, state)
        
      :product_inquiry ->
        check_product_availability(customer_request.product_id, state)
        
      :support ->
        handle_support_request(customer_request, state)
    end
    
    # Update satisfaction based on response time
    satisfaction_delta = calculate_satisfaction_impact(customer_request)
    new_satisfaction = state.metrics.customer_satisfaction * 0.99 + satisfaction_delta * 0.01
    
    new_metrics = %{state.metrics | customer_satisfaction: new_satisfaction}
    new_state = %{state | metrics: new_metrics}
    
    {:ok, response, new_state}
  end
  
  defp analyze_operational_data(analysis_request, state) do
    Logger.info("Operations: Analyzing operational data")
    
    analysis = case analysis_request.type do
      :performance ->
        analyze_performance_trends(state)
        
      :inventory ->
        analyze_inventory_patterns(state)
        
      :customer ->
        analyze_customer_behavior(state)
    end
    
    {:ok, analysis, state}
  end
  
  defp initialize_inventory do
    # Initialize with sample inventory
    %{
      "PROD-001" => %{quantity: 100, reserved: 0, reorder_point: 20},
      "PROD-002" => %{quantity: 50, reserved: 0, reorder_point: 10},
      "PROD-003" => %{quantity: 200, reserved: 0, reorder_point: 50}
    }
  end
  
  defp default_config do
    %{
      max_processing_time: 1000,  # milliseconds
      inventory_threshold: 0.2,
      customer_response_target: 500  # milliseconds
    }
  end
  
  defp validate_order(order_data, _state) do
    cond do
      is_nil(order_data.customer_id) -> {:error, :missing_customer}
      Enum.empty?(order_data.items) -> {:error, :empty_order}
      true -> :ok
    end
  end
  
  defp check_inventory(items, state) do
    inventory = state.operational_data.inventory
    
    # Check if all items are available
    availability = Enum.map(items, fn {product_id, quantity} ->
      case Map.get(inventory, product_id) do
        nil -> 
          {:error, product_id, :not_found}
        %{quantity: available, reserved: reserved} ->
          if available - reserved >= quantity do
            {:ok, product_id, quantity}
          else
            {:error, product_id, :insufficient}
          end
      end
    end)
    
    if Enum.all?(availability, fn {status, _, _} -> status == :ok end) do
      reserved = Enum.map(availability, fn {:ok, id, qty} -> {id, qty} end)
      {:ok, reserved}
    else
      {:error, :insufficient_inventory}
    end
  end
  
  defp deduct_inventory(reserved_items, inventory) do
    Enum.reduce(reserved_items, inventory, fn {product_id, quantity}, acc ->
      update_in(acc, [product_id, :reserved], &(&1 + quantity))
    end)
  end
  
  defp coordinate_order_processing(order, state) do
    # Notify other contexts about the order
    VsmPhoenix.System2.Coordinator.broadcast_coordination(
      "vsm:orders",
      {:new_order, order}
    )
  end
  
  defp update_order_metrics(metrics, result) do
    new_count = metrics.orders_processed + 1
    
    new_success_rate = case result do
      :success -> 
        (metrics.success_rate * metrics.orders_processed + 1) / new_count
      _ ->
        (metrics.success_rate * metrics.orders_processed) / new_count
    end
    
    %{metrics |
      orders_processed: new_count,
      success_rate: new_success_rate
    }
  end
  
  defp apply_inventory_changes(changes, inventory) do
    Enum.reduce(changes, inventory, fn {product_id, change}, acc ->
      case change do
        {:add, quantity} ->
          update_in(acc, [product_id, :quantity], &(&1 + quantity))
        {:set, quantity} ->
          put_in(acc, [product_id, :quantity], quantity)
        _ ->
          acc
      end
    end)
  end
  
  defp calculate_inventory_accuracy(inventory) do
    # Simplified accuracy calculation
    0.97
  end
  
  defp get_order_status(order_id, state) do
    case Map.get(state.operational_data.orders, order_id) do
      nil -> %{status: :not_found}
      order -> %{status: order.status, created_at: order.created_at}
    end
  end
  
  defp check_product_availability(product_id, state) do
    case Map.get(state.operational_data.inventory, product_id) do
      nil -> %{available: false}
      %{quantity: qty, reserved: res} -> %{available: true, quantity: qty - res}
    end
  end
  
  defp handle_support_request(_request, _state) do
    %{response: "Support ticket created", ticket_id: generate_ticket_id()}
  end
  
  defp calculate_satisfaction_impact(_request) do
    # Simplified - in reality would consider response time, resolution, etc.
    0.95
  end
  
  defp analyze_performance_trends(state) do
    %{
      orders_per_minute: calculate_order_rate(state),
      success_rate: state.metrics.success_rate,
      average_processing_time: state.metrics.average_processing_time
    }
  end
  
  defp analyze_inventory_patterns(_state) do
    %{
      turnover_rate: 0.85,
      stockout_risk: :low,
      optimization_opportunities: []
    }
  end
  
  defp analyze_customer_behavior(state) do
    %{
      satisfaction_trend: :stable,
      satisfaction_score: state.metrics.customer_satisfaction,
      common_requests: [:order_status, :product_inquiry]
    }
  end
  
  defp calculate_order_rate(_state) do
    # Simplified - would calculate based on time window
    10.5
  end
  
  defp sync_order_data(order_data, state) do
    # Synchronize order data
    state
  end
  
  defp apply_inventory_update(inventory_data, state) do
    # Apply coordinated inventory update
    state
  end
  
  defp generate_order_id do
    "ORD-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(1000)}"
  end
  
  defp generate_ticket_id do
    "TKT-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(1000)}"
  end
end