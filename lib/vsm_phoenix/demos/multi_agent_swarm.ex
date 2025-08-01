defmodule VsmPhoenix.Demos.MultiAgentSwarm do
  @moduledoc """
  Demonstrates multi-agent MCP swarm with deep recursion and AMQP communication.
  
  Architecture:
  - Level 0: Orchestrator Agent (coordinates the swarm)
  - Level 1: Specialist Agents (FileManager, TimeKeeper, DataAnalyst)
  - Level 2: Sub-specialist Agents spawned by Level 1
  - Level 3+: Task-specific agents spawned recursively
  
  Each agent:
  - Connects to a different MCP server for unique capabilities
  - Communicates via AMQP with other agents
  - Can spawn child agents recursively
  """
  
  require Logger
  
  alias VsmPhoenix.System1.Supervisor, as: S1Supervisor
  alias VsmPhoenix.System1.Agents.LLMWorkerAgent
  alias VsmPhoenix.AMQP.ConnectionManager
  
  @doc """
  Launch the multi-agent swarm demonstration
  """
  def launch_swarm do
    Logger.info("🚀 Launching Multi-Agent MCP Swarm...")
    
    # Step 1: Create Orchestrator Agent (Level 0)
    {:ok, orchestrator} = create_orchestrator_agent()
    
    # Step 2: Orchestrator spawns specialist agents (Level 1)
    spawn_specialists(orchestrator)
    
    # Step 3: Demonstrate inter-agent communication
    demonstrate_amqp_communication()
    
    # Step 4: Show deep recursion (3+ levels)
    demonstrate_deep_recursion(orchestrator)
    
    # Step 5: Coordinate a complex task across agents
    execute_swarm_task(orchestrator)
  end
  
  defp create_orchestrator_agent do
    Logger.info("👑 Creating Orchestrator Agent (Level 0)...")
    
    config = %{
      name: "SwarmOrchestrator",
      role: "orchestrator",
      level: 0,
      mcp_servers: [],  # Orchestrator doesn't need MCP, just coordinates
      amqp_routing_key: "vsm.swarm.orchestrator"
    }
    
    S1Supervisor.spawn_agent(:llm_worker, config: config)
  end
  
  defp spawn_specialists(orchestrator) do
    Logger.info("🔧 Orchestrator spawning Level 1 specialists...")
    
    # Command orchestrator to spawn specialists with different MCP servers
    command = %{
      "type" => "spawn_specialists",
      "data" => %{
        "specialists" => [
          %{
            "name" => "FileManager",
            "mcp_server" => "npx -y @modelcontextprotocol/server-filesystem /tmp",
            "routing_key" => "vsm.swarm.filemanager"
          },
          %{
            "name" => "TimeKeeper", 
            "mcp_server" => "npx -y @takanarishimbo/datetime-mcp-server",
            "routing_key" => "vsm.swarm.timekeeper"
          },
          %{
            "name" => "DataAnalyst",
            "mcp_server" => "npx -y @modelcontextprotocol/server-sqlite #{File.cwd!()}/test_vsm.db",
            "routing_key" => "vsm.swarm.dataanalyst"
          }
        ]
      }
    }
    
    LLMWorkerAgent.execute_command(orchestrator.id, command)
  end
  
  defp demonstrate_amqp_communication do
    Logger.info("📡 Demonstrating inter-agent AMQP communication...")
    
    # Set up AMQP message routing between agents
    Task.start(fn ->
      {:ok, channel} = ConnectionManager.get_channel()
      
      # Create swarm exchange for inter-agent communication
      :ok = AMQP.Exchange.declare(channel, "vsm.swarm", :topic, durable: true)
      
      # Set up queues for each specialist
      ["filemanager", "timekeeper", "dataanalyst"] |> Enum.each(fn specialist ->
        queue_name = "vsm.swarm.#{specialist}"
        {:ok, _} = AMQP.Queue.declare(channel, queue_name, durable: true)
        :ok = AMQP.Queue.bind(channel, queue_name, "vsm.swarm", routing_key: "vsm.swarm.#{specialist}")
        
        Logger.info("📬 Created AMQP queue: #{queue_name}")
      end)
      
      # Example: FileManager sends discovery message to others
      message = %{
        from: "FileManager",
        to: "all",
        type: "capability_announcement",
        capabilities: ["read_file", "write_file", "list_directory"],
        timestamp: DateTime.utc_now()
      }
      
      AMQP.Basic.publish(
        channel,
        "vsm.swarm",
        "vsm.swarm.broadcast",
        Jason.encode!(message)
      )
      
      Logger.info("📤 Broadcast capability announcement via AMQP")
    end)
  end
  
  defp demonstrate_deep_recursion(orchestrator) do
    Logger.info("🌳 Demonstrating deep recursion (3+ levels)...")
    
    # Command orchestrator to create a deep hierarchy
    command = %{
      "type" => "create_deep_hierarchy",
      "data" => %{
        "task" => "Analyze and document system state",
        "recursion_depth" => 4,
        "hierarchy" => %{
          "FileManager" => [
            %{"FileReader (Level 2)" => [
              %{"ConfigParser (Level 3)" => [
                "YAMLParser (Level 4)"
              ]}
            ]},
            %{"FileWriter (Level 2)" => [
              %{"ReportGenerator (Level 3)" => [
                "MarkdownFormatter (Level 4)"
              ]}
            ]}
          ]
        }
      }
    }
    
    result = LLMWorkerAgent.execute_command(orchestrator.id, command)
    Logger.info("🎯 Deep hierarchy creation result: #{inspect(result)}")
  end
  
  defp execute_swarm_task(orchestrator) do
    Logger.info("🎪 Executing coordinated swarm task...")
    
    # Complex task that requires multiple agents working together
    task = %{
      "type" => "swarm_task",
      "data" => %{
        "objective" => "Generate timestamped system analysis report",
        "steps" => [
          %{
            "agent" => "TimeKeeper",
            "action" => "get_current_time",
            "output_key" => "report_timestamp"
          },
          %{
            "agent" => "FileManager", 
            "action" => "list_directory",
            "args" => %{"path" => "/tmp"},
            "output_key" => "tmp_files"
          },
          %{
            "agent" => "DataAnalyst",
            "action" => "query_database",
            "args" => %{"query" => "SELECT * FROM agents"},
            "output_key" => "agent_data"
          },
          %{
            "agent" => "FileManager",
            "action" => "write_file",
            "args" => %{
              "path" => "/tmp/swarm_report.md",
              "content" => "# Swarm Analysis Report\n\nGenerated at: {{report_timestamp}}\n\n## Files in /tmp\n{{tmp_files}}\n\n## Agent Data\n{{agent_data}}"
            }
          }
        ],
        "coordination" => "sequential_with_context_passing"
      }
    }
    
    result = LLMWorkerAgent.execute_command(orchestrator.id, task)
    
    Logger.info("✅ Swarm task completed: #{inspect(result)}")
  end
  
  @doc """
  Monitor swarm health and communication
  """
  def monitor_swarm do
    Logger.info("📊 Monitoring swarm health...")
    
    # Get all agents
    agents = VsmPhoenix.System1.Registry.list_agents()
    
    swarm_agents = agents
    |> Enum.filter(fn agent ->
      agent.metadata[:config][:role] in ["orchestrator", "specialist", "sub-specialist"]
    end)
    
    Logger.info("Found #{length(swarm_agents)} swarm agents:")
    
    swarm_agents |> Enum.each(fn agent ->
      level = agent.metadata[:config][:level] || "unknown"
      role = agent.metadata[:config][:role] || "unknown"
      Logger.info("  #{agent.agent_id} - Level: #{level}, Role: #{role}")
    end)
    
    # Check AMQP message flow
    Task.start(fn ->
      {:ok, channel} = ConnectionManager.get_channel()
      
      # Subscribe to swarm broadcast
      {:ok, _consumer_tag} = AMQP.Basic.consume(
        channel,
        "vsm.swarm.broadcast",
        nil,
        no_ack: true
      )
      
      receive do
        {:basic_deliver, payload, _meta} ->
          message = Jason.decode!(payload)
          Logger.info("📨 Intercepted swarm message: #{inspect(message)}")
      after
        5000 ->
          Logger.info("No swarm messages in last 5 seconds")
      end
    end)
  end
end