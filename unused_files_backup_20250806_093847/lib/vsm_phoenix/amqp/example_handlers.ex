defmodule VsmPhoenix.AMQP.ExampleHandlers do
  @moduledoc """
  Example command handlers for different VSM systems showing bidirectional RPC usage.

  This demonstrates how each system can:
  1. Register as a command handler to receive RPC calls
  2. Make RPC calls to other systems
  3. Publish events through fan-out exchanges
  """

  require Logger
  alias VsmPhoenix.AMQP.{CommandRPC, CommandRouter}

  @doc """
  Initialize example handlers for all VSM systems
  """
  def setup_all do
    setup_system1_handler()
    setup_system3_handler()
    setup_system5_handler()
    Logger.info("✅ Example VSM command handlers registered")
  end

  @doc """
  System 1 (Operations) command handler
  """
  def setup_system1_handler do
    CommandRPC.register_handler(:system1, fn command, _meta ->
      case command["action"] do
        "get_operational_status" ->
          # S1 returns operational status
          %{
            status: "operational",
            subsystems: %{
              (command["subsystem"] || "all") => %{
                health: "green",
                metrics: %{
                  throughput: 850,
                  efficiency: 0.92,
                  errors: 3
                }
              }
            },
            timestamp: DateTime.utc_now()
          }

        "execute_operation" ->
          # S1 executes operational command
          operation_id = "op_#{:rand.uniform(10000)}"

          %{
            operation_id: operation_id,
            status: "executing",
            estimated_completion: 30
          }

        "get_sensor_data" ->
          # S1 returns sensor readings
          %{
            sensors:
              Enum.map(command["sensor_ids"] || [], fn sensor_id ->
                %{
                  id: sensor_id,
                  value: :rand.uniform(100),
                  unit: "units",
                  timestamp: DateTime.utc_now()
                }
              end)
          }

        _ ->
          {:error, "Unknown S1 action: #{command["action"]}"}
      end
    end)
  end

  @doc """
  System 3 (Control) command handler
  """
  def setup_system3_handler do
    handler =
      CommandRPC.with_validation(
        fn command, _meta ->
          case command["action"] do
            "allocate_resources" ->
              # S3 allocates resources based on command
              resource_id = "res_#{:rand.uniform(10000)}"

              # S3 might query S1 for current load before allocating
              {:ok, s1_status} =
                CommandRPC.call(:system1, %{
                  "action" => "get_operational_status",
                  "subsystem" => "resource_pool"
                })

              allocation = %{
                resource_id: resource_id,
                type: command["resource_type"],
                amount: command["amount"],
                allocated_to: command["requester"] || "system",
                current_pool_status: s1_status,
                timestamp: DateTime.utc_now()
              }

              # Publish allocation event
              CommandRouter.publish_event(:control, %{
                event: "resource_allocated",
                details: allocation
              })

              allocation

            "optimize_distribution" ->
              # S3 optimizes resource distribution
              %{
                optimization_id: "opt_#{:rand.uniform(10000)}",
                status: "optimizing",
                expected_improvement: "15%",
                affecting_systems: ["system1", "system2"]
              }

            "emergency_shutdown" ->
              # S3 can command S1 to shutdown operations
              {:ok, shutdown_result} =
                CommandRPC.call(:system1, %{
                  "action" => "execute_operation",
                  "operation" => "emergency_shutdown",
                  "reason" => command["reason"]
                })

              %{
                shutdown_initiated: true,
                s1_response: shutdown_result,
                timestamp: DateTime.utc_now()
              }

            _ ->
              {:error, "Unknown S3 action: #{command["action"]}"}
          end
        end,
        required: ["action"],
        values: {"resource_type", ["compute", "memory", "network", "storage"]}
      )

    CommandRPC.register_handler(:system3, handler)
  end

  @doc """
  System 5 (Policy) command handler
  """
  def setup_system5_handler do
    CommandRPC.register_handler(:system5, fn command, _meta ->
      case command["action"] do
        "set_policy" ->
          # S5 sets system-wide policy
          policy_id = "policy_#{:rand.uniform(10000)}"

          # S5 commands S3 to adjust resource allocation based on new policy
          if command["policy_type"] == "resource_conservation" do
            {:ok, s3_result} =
              CommandRPC.call(:system3, %{
                "action" => "optimize_distribution",
                "optimization_goal" => "minimize_resource_usage",
                "policy_id" => policy_id
              })

            %{
              policy_id: policy_id,
              type: command["policy_type"],
              parameters: command["parameters"],
              s3_optimization: s3_result,
              status: "active"
            }
          else
            %{
              policy_id: policy_id,
              type: command["policy_type"],
              parameters: command["parameters"],
              status: "active"
            }
          end

        "get_system_health" ->
          # S5 queries multiple systems for overall health
          {:ok, s1_status} =
            CommandRPC.call(:system1, %{
              "action" => "get_operational_status"
            })

          {:ok, s3_resources} =
            CommandRPC.call(:system3, %{
              "action" => "get_resource_status"
            })

          %{
            overall_health: "green",
            systems: %{
              system1: s1_status,
              system3: s3_resources,
              system5: %{status: "operational", policies_active: 5}
            },
            timestamp: DateTime.utc_now()
          }

        "emergency_override" ->
          # S5 can override and command any system
          target = String.to_atom(command["target_system"])
          {:ok, result} = CommandRPC.call(target, command["override_command"])

          # Publish policy event
          CommandRouter.publish_event(:policy, %{
            event: "emergency_override_executed",
            target: target,
            command: command["override_command"],
            result: result
          })

          %{
            override_executed: true,
            target: target,
            result: result
          }

        _ ->
          {:error, "Unknown S5 action: #{command["action"]}"}
      end
    end)
  end

  @doc """
  Example of S5 issuing commands to lower systems
  """
  def example_s5_commands do
    Logger.info("📍 S5 Policy System issuing commands...")

    # S5 queries overall system health
    {:ok, health} =
      CommandRPC.call(:system5, %{
        "action" => "get_system_health"
      })

    Logger.info("System health: #{inspect(health)}")

    # S5 sets a conservation policy
    {:ok, policy} =
      CommandRPC.call(:system5, %{
        "action" => "set_policy",
        "policy_type" => "resource_conservation",
        "parameters" => %{"threshold" => 0.8, "mode" => "aggressive"}
      })

    Logger.info("Policy set: #{inspect(policy)}")

    # S5 directly commands S3 to allocate resources
    {:ok, allocation} =
      CommandRPC.call(:system3, %{
        "action" => "allocate_resources",
        "resource_type" => "compute",
        "amount" => 20,
        "requester" => "policy_enforcement"
      })

    Logger.info("Resources allocated: #{inspect(allocation)}")
  end

  @doc """
  Example of S3 querying S1 and controlling operations
  """
  def example_s3_control do
    Logger.info("🎮 S3 Control System managing operations...")

    # S3 queries S1 sensor data
    {:ok, sensors} =
      CommandRPC.call(:system1, %{
        "action" => "get_sensor_data",
        "sensor_ids" => ["temp_001", "pressure_002", "flow_003"]
      })

    Logger.info("Sensor data: #{inspect(sensors)}")

    # Based on sensor data, S3 might execute an operation
    if Enum.any?(sensors["sensors"], &(&1.value > 80)) do
      {:ok, operation} =
        CommandRPC.call(:system1, %{
          "action" => "execute_operation",
          "operation" => "reduce_throughput",
          "reason" => "high_sensor_readings"
        })

      Logger.info("Operation executed: #{inspect(operation)}")
    end
  end
end
