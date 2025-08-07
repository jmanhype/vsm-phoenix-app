defmodule VsmPhoenix.System1.LLMWorkerInit do
  @moduledoc """
  Automatically spawns LLM worker agents on startup.
  Ensures there are workers available to handle conversation requests.
  """
  
  use GenServer
  require Logger
  
  @default_worker_count 2
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    # Schedule initialization after system is ready
    Process.send_after(self(), :spawn_workers, 8_000)
    {:ok, %{workers: []}}
  end
  
  @impl true
  def handle_info(:spawn_workers, state) do
    # Get configuration for worker count
    config = Application.get_env(:vsm_phoenix, :vsm, %{})
    llm_config = config[:llm] || %{}
    worker_count = llm_config[:worker_count] || @default_worker_count
    
    Logger.info("🤖 Auto-spawning #{worker_count} LLM workers...")
    
    # Spawn the workers
    workers = Enum.map(1..worker_count, fn i ->
      worker_id = "llm_worker_#{i}"
      
      case VsmPhoenix.System1.Supervisor.spawn_agent(:llm_worker, 
        id: worker_id,
        config: %{
          mcp_servers: llm_config[:mcp_servers] || []
        }
      ) do
        {:ok, agent} ->
          Logger.info("✅ Spawned LLM worker: #{worker_id}")
          {worker_id, agent}
          
        {:error, reason} ->
          Logger.error("❌ Failed to spawn LLM worker #{worker_id}: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    
    if Enum.empty?(workers) do
      # Retry if all workers failed to spawn
      Logger.warning("⚠️  All LLM workers failed to spawn, retrying in 30 seconds...")
      Process.send_after(self(), :spawn_workers, 30_000)
    else
      Logger.info("✅ Successfully spawned #{length(workers)} LLM workers")
    end
    
    {:noreply, %{state | workers: workers}}
  end
  
  @impl true
  def handle_call(:get_workers, _from, state) do
    {:reply, state.workers, state}
  end
  
  # Public API
  def get_workers do
    GenServer.call(__MODULE__, :get_workers)
  end
end