defmodule VsmPhoenix.MCP.ExternalClientSupervisor do
  @moduledoc """
  Supervisor for managing external MCP client connections.
  
  Dynamically starts and supervises ExternalClient processes for each
  discovered MCP server.
  """

  use DynamicSupervisor
  require Logger

  alias VsmPhoenix.MCP.ExternalClient

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a new external MCP client for a server.
  """
  def start_client(server_name) do
    child_spec = {ExternalClient, server_name: server_name}
    
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started external MCP client for #{server_name} with PID #{inspect(pid)}")
        {:ok, pid}
      
      {:error, {:already_started, pid}} ->
        Logger.debug("External MCP client already running for #{server_name}")
        {:ok, pid}
      
      error ->
        Logger.error("Failed to start external MCP client for #{server_name}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Stop an external MCP client.
  """
  def stop_client(server_name) do
    case Registry.lookup(VsmPhoenix.MCP.ExternalClientRegistry, server_name) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      
      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  List all active external MCP clients.
  """
  def list_clients do
    children = DynamicSupervisor.which_children(__MODULE__)
    
    Enum.map(children, fn {_, pid, _, _} ->
      case Registry.keys(VsmPhoenix.MCP.ExternalClientRegistry, pid) do
        [server_name] -> 
          case ExternalClient.get_status(server_name) do
            {:ok, status} -> {server_name, status}
            _ -> {server_name, :unknown}
          end
        _ -> 
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Restart a client connection.
  """
  def restart_client(server_name) do
    with :ok <- stop_client(server_name),
         {:ok, pid} <- start_client(server_name) do
      {:ok, pid}
    end
  end
end