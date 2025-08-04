defmodule VsmPhoenixWeb.AgentController do
  @moduledoc """
  HTTP API for S1 Agent Management - The missing bridge between HTTP and AMQP!
  
  This controller provides the critical HTTP interface that was missing
  from the VSMCP Phase 1 implementation. All S1 agent infrastructure 
  exists, but couldn't be accessed from the running Phoenix server.
  """
  
  use VsmPhoenixWeb, :controller
  require Logger
  
  alias VsmPhoenix.System1.Supervisor, as: S1Supervisor
  alias VsmPhoenix.System1.Registry
  alias VsmPhoenix.System1.Agents.{SensorAgent, WorkerAgent, ApiAgent, LLMWorkerAgent}
  alias VsmPhoenix.System3.AuditChannel

  @doc """
  POST /api/vsm/agents
  Spawn a new S1 agent on the running Phoenix server.
  
  Body: {"type": "sensor|worker|api|llm_worker", "config": {...}}
  """
  def create(conn, %{"type" => agent_type} = params) do
    agent_type_atom = String.to_atom(agent_type)
    config = Map.get(params, "config", %{})
    
    Logger.info("🚀 HTTP Request: Spawning #{agent_type} agent...")
    
    # Convert string keys to atoms for config
    atom_config = if is_map(config) do
      Map.new(config, fn {k, v} -> {String.to_atom(k), v} end)
    else
      config
    end
    
    Logger.info("🔄 Passing config to spawn_agent: #{inspect(atom_config)}")
    
    case S1Supervisor.spawn_agent(agent_type_atom, config: atom_config) do
      {:ok, %{id: agent_id, pid: pid, type: type}} ->
        Logger.info("✅ HTTP Success: Spawned #{type} agent #{agent_id}")
        
        conn
        |> put_status(201)
        |> json(%{
          success: true,
          agent: %{
            id: agent_id,
            pid: inspect(pid),
            type: type,
            spawned_at: DateTime.utc_now() |> DateTime.to_iso8601(),
            status: "active"
          }
        })
        
      {:error, reason} ->
        Logger.error("❌ HTTP Error: Failed to spawn agent: #{inspect(reason)}")
        
        conn
        |> put_status(400)
        |> json(%{
          success: false,
          error: "Failed to spawn agent",
          reason: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/vsm/agents
  List all active S1 agents on the running Phoenix server.
  """
  def index(conn, _params) do
    Logger.info("📋 HTTP Request: Listing all S1 agents...")
    
    try do
      # Get raw agents from Registry
      agents_data = VsmPhoenix.System1.Registry.list_agents()
      Logger.info("🔍 Found #{length(agents_data)} agents in registry")
      
      # Create simple response without metrics for now
      agents = Enum.map(agents_data, fn agent ->
        %{
          id: agent.agent_id,
          pid: inspect(agent.pid),
          type: agent.metadata.type,
          alive: agent.alive,
          started_at: if agent.metadata.started_at do
            DateTime.to_iso8601(agent.metadata.started_at)
          else
            nil
          end,
          config: agent.metadata.config || %{}
        }
      end)
      
      Logger.info("✅ Successfully processed #{length(agents)} agents")
      
      conn
      |> json(%{
        success: true,
        count: length(agents),
        agents: agents
      })
      
    rescue
      error ->
        Logger.error("❌ Error in index: #{inspect(error)}")
        
        conn
        |> put_status(500)
        |> json(%{
          success: false,
          error: "Internal server error",
          details: inspect(error)
        })
    end
  end

  @doc """
  GET /api/vsm/agents/:id
  Get specific agent details and metrics.
  """
  def show(conn, %{"id" => agent_id}) do
    Logger.info("🔍 HTTP Request: Getting agent #{agent_id} details...")
    
    case Registry.lookup(agent_id) do
      {:ok, pid, metadata} ->
        # Get basic safe metrics without any complex structures
        metrics = case get_agent_metrics(agent_id, metadata.type) do
          {:ok, raw_metrics} -> 
            # Create completely safe metrics - only basic types
            %{
              commands_processed: Map.get(raw_metrics, :commands_processed, 0),
              commands_failed: Map.get(raw_metrics, :commands_failed, 0),
              total_processing_time: Map.get(raw_metrics, :total_processing_time, 0),
              work_queue_length: Map.get(raw_metrics, :work_queue_length, 0),
              average_processing_time: Map.get(raw_metrics, :average_processing_time, 0.0),
              last_command_at: case Map.get(raw_metrics, :last_command_at) do
                nil -> nil
                %DateTime{} = dt -> DateTime.to_iso8601(dt)
                _ -> nil
              end
            }
          {:error, reason} -> %{error: inspect(reason)}
        end
        
        # Create completely safe config - only basic types
        safe_config = case metadata.config do
          config when is_map(config) ->
            config
            |> Enum.filter(fn {_k, v} -> is_binary(v) or is_number(v) or is_boolean(v) or is_atom(v) end)
            |> Enum.into(%{})
          _ -> %{}
        end
        
        # Build response with only JSON-safe data
        response = %{
          success: true,
          agent: %{
            id: agent_id,
            pid: inspect(pid),
            type: metadata.type,
            started_at: metadata.started_at |> DateTime.to_iso8601(),
            config: safe_config,
            alive: Process.alive?(pid),
            metrics: metrics
          }
        }
        
        Logger.info("🔧 Agent response prepared, sending JSON...")
        conn |> json(response)
        
      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          success: false,
          error: "Agent not found",
          agent_id: agent_id
        })
    end
  end

  @doc """
  POST /api/vsm/agents/:id/command
  Execute command on specific agent via HTTP -> AMQP bridge.
  
  Body: {"type": "process_data", "data": {...}}
  """
  def execute_command(conn, %{"id" => agent_id} = params) do
    command_type = Map.get(params, "type", "unknown")
    command_data = Map.get(params, "data", %{})
    
    Logger.info("⚡ HTTP Request: Executing #{command_type} on agent #{agent_id}")
    
    case Registry.lookup(agent_id) do
      {:ok, _pid, metadata} ->
        # Include all params in the command, not just data
        command = params
        |> Map.put("id", generate_command_id())
        |> Map.put("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())
        |> Map.put("data", command_data)
        
        # Execute command based on agent type
        result = case metadata.type do
          :worker ->
            WorkerAgent.execute_command(agent_id, command)
          :llm_worker ->
            # LLM workers have their own execute_command implementation
            LLMWorkerAgent.execute_command(agent_id, command)
          :api ->
            ApiAgent.handle_request(agent_id, command)
          :sensor ->
            # Sensors don't execute commands, just update config
            SensorAgent.update_sensor_config(agent_id, command_data)
            {:ok, %{message: "Sensor config updated"}}
        end
        
        case result do
          {:ok, response} ->
            Logger.info("✅ HTTP Success: Command executed on #{agent_id}")
            
            conn
            |> json(%{
              success: true,
              command_id: command["id"],
              agent_id: agent_id,
              result: response
            })
            
          {:error, reason} ->
            Logger.error("❌ HTTP Error: Command failed on #{agent_id}: #{inspect(reason)}")
            
            conn
            |> put_status(400)
            |> json(%{
              success: false,
              error: "Command execution failed",
              reason: inspect(reason)
            })
        end
        
      {:error, :not_found} ->
        conn
        |> put_status(404)
        |> json(%{
          success: false,
          error: "Agent not found",
          agent_id: agent_id
        })
    end
  end

  @doc """
  DELETE /api/vsm/agents/:id
  Terminate specific S1 agent.
  """
  def delete(conn, %{"id" => agent_id}) do
    Logger.info("🗑️ HTTP Request: Terminating agent #{agent_id}")
    
    case S1Supervisor.terminate_agent(agent_id) do
      :ok ->
        Logger.info("✅ HTTP Success: Terminated agent #{agent_id}")
        
        conn
        |> json(%{
          success: true,
          message: "Agent terminated",
          agent_id: agent_id
        })
        
      {:error, reason} ->
        Logger.error("❌ HTTP Error: Failed to terminate #{agent_id}: #{inspect(reason)}")
        
        conn
        |> put_status(400)
        |> json(%{
          success: false,
          error: "Failed to terminate agent",
          reason: inspect(reason)
        })
    end
  end

  @doc """
  POST /api/vsm/audit/bypass
  S3 Audit Bypass - Direct agent inspection bypassing S2 coordination.
  
  Body: {"agent_id": "s1_worker_123", "query": "status|metrics|health"}
  """
  def audit_bypass(conn, params) do
    # Handle both "agent_id" and "target" fields for compatibility
    agent_id = params["agent_id"] || params["target"]
    query = Map.get(params, "query", Map.get(params, "audit_type", "status"))
    
    Logger.info("🔍 S3 Audit Bypass: Direct inspection of #{agent_id} (#{query})")
    
    case AuditChannel.send_audit_command(agent_id, %{operation: String.to_atom(query)}) do
      {:ok, audit_data} ->
        Logger.info("✅ S3 Audit Success: Retrieved #{query} for #{agent_id}")
        
        conn
        |> json(%{
          success: true,
          audit_type: "s3_bypass",
          agent_id: agent_id,
          query: query,
          data: audit_data,
          bypassed_s2: true,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })
        
      {:error, reason} ->
        Logger.error("❌ S3 Audit Failed: #{inspect(reason)}")
        
        conn
        |> put_status(400)
        |> json(%{
          success: false,
          error: "Audit bypass failed",
          reason: inspect(reason)
        })
    end
  end

  # Private Functions

  defp get_agent_metrics(agent_id, agent_type) do
    try do
      result = case agent_type do
        :sensor ->
          SensorAgent.get_metrics(agent_id)
        :worker ->
          WorkerAgent.get_work_metrics(agent_id)
        :api ->
          ApiAgent.get_api_metrics(agent_id)
        _ ->
          {:error, :unknown_agent_type}
      end
      
      # Clean up any queue structures that can't be JSON encoded
      case result do
        {:ok, metrics} when is_map(metrics) ->
          cleaned_metrics = clean_queue_structures(metrics)
          {:ok, cleaned_metrics}
        other ->
          other
      end
    rescue
      error ->
        {:error, Exception.format(:error, error)}
    end
  end

  # Recursively clean queue structures from nested maps
  defp clean_queue_structures(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} ->
      {key, clean_queue_structures(value)}
    end)
    |> Map.new()
  end
  
  defp clean_queue_structures({[], []} = _queue_tuple) do
    # This is an empty Erlang queue, replace with length
    0
  end
  
  defp clean_queue_structures(data) when is_tuple(data) do
    # Check if this looks like a queue structure
    case data do
      {in_list, out_list} when is_list(in_list) and is_list(out_list) ->
        # This is likely a queue, return its length
        length(in_list) + length(out_list)
      _ ->
        # Convert any tuple to a string representation to avoid JSON encoding issues
        "tuple_#{tuple_size(data)}_elements"
    end
  end
  
  defp clean_queue_structures(data) when is_list(data) do
    Enum.map(data, &clean_queue_structures/1)
  end
  
  defp clean_queue_structures(data), do: data

  defp generate_command_id do
    "cmd-#{:erlang.system_time(:millisecond)}-#{:rand.uniform(9999)}"
  end
end