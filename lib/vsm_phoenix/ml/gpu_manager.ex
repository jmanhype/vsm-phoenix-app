defmodule VsmPhoenix.ML.GPUManager do
  @moduledoc """
  GPU Resource Manager for ML training and inference.
  Handles GPU allocation, memory management, and multi-GPU coordination.
  """

  use GenServer
  require Logger

  defstruct [
    gpu_devices: [],
    gpu_memory: %{},
    allocations: %{},
    gpu_enabled: false,
    memory_pool: %{}
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Initializing GPU Manager")
    
    gpu_enabled = detect_gpu_availability()
    gpu_devices = if gpu_enabled, do: enumerate_gpu_devices(), else: []
    
    state = %__MODULE__{
      gpu_enabled: gpu_enabled,
      gpu_devices: gpu_devices,
      gpu_memory: initialize_gpu_memory(gpu_devices),
      allocations: %{},
      memory_pool: %{}
    }

    if gpu_enabled do
      Logger.info("GPU support enabled with #{length(gpu_devices)} device(s)")
      initialize_exla_gpu()
    else
      Logger.info("GPU support disabled - using CPU backend")
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_gpu_status, _from, state) do
    status = %{
      gpu_enabled: state.gpu_enabled,
      device_count: length(state.gpu_devices),
      devices: state.gpu_devices,
      memory_usage: state.gpu_memory,
      active_allocations: map_size(state.allocations)
    }
    
    {:reply, {:ok, status}, state}
  end

  @impl true
  def handle_call({:allocate_gpu, process_id, memory_mb}, _from, state) do
    case allocate_gpu_memory(process_id, memory_mb, state) do
      {:ok, allocation, new_state} ->
        Logger.info("GPU allocated to process #{inspect(process_id)}: #{memory_mb}MB")
        {:reply, {:ok, allocation}, new_state}
      
      {:error, reason} ->
        Logger.warn("GPU allocation failed for process #{inspect(process_id)}: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:deallocate_gpu, process_id}, _from, state) do
    case deallocate_gpu_memory(process_id, state) do
      {:ok, new_state} ->
        Logger.info("GPU deallocated for process #{inspect(process_id)}")
        {:reply, {:ok, "GPU deallocated"}, new_state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_optimal_device, _from, state) do
    case find_optimal_gpu_device(state) do
      {:ok, device_id} ->
        {:reply, {:ok, device_id}, state}
      
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:create_tensor_backend, device_id}, _from, state) do
    if state.gpu_enabled and device_id < length(state.gpu_devices) do
      try do
        backend = create_gpu_backend(device_id)
        {:reply, {:ok, backend}, state}
      rescue
        error ->
          Logger.error("Failed to create GPU backend: #{inspect(error)}")
          {:reply, {:error, Exception.message(error)}, state}
      end
    else
      {:reply, {:ok, Nx.BinaryBackend}, state}
    end
  end

  @impl true
  def handle_call(:cleanup_gpu_memory, _from, state) do
    try do
      # Force garbage collection on GPU
      if state.gpu_enabled do
        cleanup_gpu_memory()
      end
      
      new_state = %{state | memory_pool: %{}}
      Logger.info("GPU memory cleanup completed")
      {:reply, {:ok, "Memory cleaned"}, new_state}
    rescue
      error ->
        Logger.error("GPU memory cleanup failed: #{inspect(error)}")
        {:reply, {:error, Exception.message(error)}, state}
    end
  end

  # Public API
  def get_gpu_status do
    GenServer.call(__MODULE__, :get_gpu_status)
  end

  def allocate_gpu(process_id, memory_mb) do
    GenServer.call(__MODULE__, {:allocate_gpu, process_id, memory_mb})
  end

  def deallocate_gpu(process_id) do
    GenServer.call(__MODULE__, {:deallocate_gpu, process_id})
  end

  def get_optimal_device do
    GenServer.call(__MODULE__, :get_optimal_device)
  end

  def create_tensor_backend(device_id \\ 0) do
    GenServer.call(__MODULE__, {:create_tensor_backend, device_id})
  end

  def cleanup_gpu_memory do
    GenServer.call(__MODULE__, :cleanup_gpu_memory)
  end

  def gpu_available? do
    case GenServer.call(__MODULE__, :get_gpu_status) do
      {:ok, status} -> status.gpu_enabled
      _ -> false
    end
  end

  # Private functions
  
  defp detect_gpu_availability do
    try do
      # Check if EXLA with GPU support is available
      case Application.get_env(:exla, :clients, []) do
        [] -> 
          Logger.info("No EXLA clients configured")
          false
        
        clients ->
          gpu_clients = Enum.filter(clients, fn {_name, opts} -> 
            opts[:platform] == :gpu 
          end)
          
          if length(gpu_clients) > 0 do
            Logger.info("Found #{length(gpu_clients)} GPU client(s) configured")
            true
          else
            Logger.info("No GPU clients configured, using CPU")
            false
          end
      end
    rescue
      error ->
        Logger.warn("Error detecting GPU: #{inspect(error)}")
        false
    end
  end

  defp enumerate_gpu_devices do
    try do
      # In a real implementation, this would query CUDA/OpenCL devices
      case Application.get_env(:exla, :clients, []) do
        [] -> []
        clients ->
          clients
          |> Enum.filter(fn {_name, opts} -> opts[:platform] == :gpu end)
          |> Enum.with_index()
          |> Enum.map(fn {{name, _opts}, index} ->
            %{
              id: index,
              name: name,
              compute_capability: "unknown",
              memory_total: 8192,  # Mock 8GB
              memory_free: 8192,
              utilization: 0
            }
          end)
      end
    rescue
      error ->
        Logger.warn("Failed to enumerate GPU devices: #{inspect(error)}")
        []
    end
  end

  defp initialize_gpu_memory(gpu_devices) do
    gpu_devices
    |> Enum.map(fn device ->
      {device.id, %{
        total_mb: device.memory_total,
        allocated_mb: 0,
        free_mb: device.memory_total
      }}
    end)
    |> Map.new()
  end

  defp initialize_exla_gpu do
    try do
      # Configure EXLA for GPU usage
      Application.put_env(:exla, :default_client, :gpu)
      
      # Optionally set memory growth to avoid allocating all GPU memory
      Application.put_env(:exla, :memory_fraction, 0.8)
      
      Logger.info("EXLA GPU configuration initialized")
    rescue
      error ->
        Logger.warn("Failed to initialize EXLA GPU: #{inspect(error)}")
    end
  end

  defp allocate_gpu_memory(process_id, memory_mb, state) do
    if not state.gpu_enabled do
      {:error, "GPU not available"}
    else
      case find_available_gpu(memory_mb, state) do
        {:ok, device_id} ->
          # Update memory allocation
          new_gpu_memory = update_in(state.gpu_memory[device_id], fn memory ->
            %{memory | 
              allocated_mb: memory.allocated_mb + memory_mb,
              free_mb: memory.free_mb - memory_mb
            }
          end)
          
          allocation = %{
            device_id: device_id,
            memory_mb: memory_mb,
            allocated_at: DateTime.utc_now(),
            backend: create_gpu_backend(device_id)
          }
          
          new_allocations = Map.put(state.allocations, process_id, allocation)
          new_state = %{state | 
            gpu_memory: new_gpu_memory,
            allocations: new_allocations
          }
          
          {:ok, allocation, new_state}
        
        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp deallocate_gpu_memory(process_id, state) do
    case Map.get(state.allocations, process_id) do
      nil ->
        {:error, "No GPU allocation found for process"}
      
      allocation ->
        # Free GPU memory
        device_id = allocation.device_id
        memory_mb = allocation.memory_mb
        
        new_gpu_memory = update_in(state.gpu_memory[device_id], fn memory ->
          %{memory | 
            allocated_mb: memory.allocated_mb - memory_mb,
            free_mb: memory.free_mb + memory_mb
          }
        end)
        
        new_allocations = Map.delete(state.allocations, process_id)
        new_state = %{state | 
          gpu_memory: new_gpu_memory,
          allocations: new_allocations
        }
        
        {:ok, new_state}
    end
  end

  defp find_available_gpu(memory_mb, state) do
    # Find GPU with enough free memory
    available_device = 
      state.gpu_memory
      |> Enum.find(fn {_device_id, memory} ->
        memory.free_mb >= memory_mb
      end)
    
    case available_device do
      nil -> {:error, "Not enough GPU memory available"}
      {device_id, _memory} -> {:ok, device_id}
    end
  end

  defp find_optimal_gpu_device(state) do
    if not state.gpu_enabled or length(state.gpu_devices) == 0 do
      {:error, "No GPU devices available"}
    else
      # Find device with most free memory
      {optimal_device_id, _memory} = 
        state.gpu_memory
        |> Enum.max_by(fn {_device_id, memory} -> memory.free_mb end)
      
      {:ok, optimal_device_id}
    end
  end

  defp create_gpu_backend(device_id) do
    try do
      # Create EXLA backend for specific GPU device
      case Application.get_env(:exla, :clients, []) do
        [] -> 
          Nx.BinaryBackend
        
        clients ->
          gpu_clients = Enum.filter(clients, fn {_name, opts} -> 
            opts[:platform] == :gpu 
          end)
          
          if length(gpu_clients) > device_id do
            {client_name, _} = Enum.at(gpu_clients, device_id)
            {EXLA.Backend, client: client_name}
          else
            {EXLA.Backend, client: :gpu}
          end
      end
    rescue
      error ->
        Logger.warn("Failed to create GPU backend: #{inspect(error)}")
        Nx.BinaryBackend
    end
  end

end