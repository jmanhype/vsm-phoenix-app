defmodule VsmPhoenix.AMQP.CommandRPC do
  @moduledoc """
  Simple RPC interface for VSM command communication.
  
  Provides a blocking call/2 function that sends commands and waits for responses
  using RabbitMQ's Direct-reply-to pattern for efficient RPC.
  
  ## Usage
  
      # From S5, issue a command to S3
      {:ok, result} = CommandRPC.call(:system3, %{
        action: "allocate_resources",
        resource_type: "compute",
        amount: 10
      })
      
      # From S3, query S1 operations
      {:ok, status} = CommandRPC.call(:system1, %{
        action: "get_operational_status",
        subsystem: "production_line_1"
      })
      
  ## Direct-reply-to Pattern
  
  This module uses RabbitMQ's special 'amq.rabbitmq.reply-to' pseudo-queue:
  - No need to declare a response queue
  - Automatic cleanup
  - High performance
  - Built-in correlation
  """
  
  require Logger
  
  alias VsmPhoenix.AMQP.{ConnectionManager, CommandRouter}
  alias AMQP
  
  @default_timeout 5000
  
  @doc """
  Send a command to a target VSM system and wait for response.
  
  ## Parameters
    - target: The target system atom (:system1, :system2, :system3, :system4, :system5)
    - command: Map containing the command details
    - opts: Options including :timeout (default: 5000ms)
    
  ## Returns
    - {:ok, result} - Command executed successfully
    - {:error, reason} - Command failed or timed out
    
  ## Examples
  
      # S5 commanding S3 to allocate resources
      CommandRPC.call(:system3, %{
        action: "allocate_resources",
        resource_type: "compute",
        amount: 10,
        priority: "high"
      })
      
      # S4 querying S1 for sensor data
      CommandRPC.call(:system1, %{
        action: "get_sensor_data",
        sensor_ids: ["temp_001", "pressure_002"],
        time_range: "last_hour"
      })
  """
  def call(target, command, opts \\ []) when is_atom(target) and is_map(command) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    
    # Use the CommandRouter for RPC
    case CommandRouter.send_command(target, command, timeout) do
      {:ok, result} ->
        Logger.debug("✅ RPC call to #{target} succeeded")
        {:ok, result}
        
      {:error, :timeout} ->
        Logger.warning("⏱️  RPC call to #{target} timed out after #{timeout}ms")
        {:error, :timeout}
        
      {:error, reason} = error ->
        Logger.error("❌ RPC call to #{target} failed: #{inspect(reason)}")
        error
    end
  end
  
  @doc """
  Send a command without waiting for response (fire-and-forget).
  
  Useful for non-critical commands or when response is not needed.
  """
  def cast(target, command) when is_atom(target) and is_map(command) do
    Task.start(fn ->
      case ConnectionManager.get_channel(:command_cast) do
        {:ok, channel} ->
          message = Jason.encode!(%{
            type: "command",
            command: command,
            timestamp: DateTime.utc_now(),
            source: node(),
            mode: "fire_and_forget"
          })
          
          target_queue = "vsm.#{target}.commands"
          AMQP.Basic.publish(channel, "", target_queue, message)
          Logger.debug("📤 Cast command to #{target}")
          
        {:error, reason} ->
          Logger.error("Failed to cast command: #{inspect(reason)}")
      end
    end)
    
    :ok
  end
  
  @doc """
  Perform a batch RPC call to multiple targets.
  
  Sends commands in parallel and collects all responses.
  """
  def multi_call(targets_and_commands, opts \\ []) when is_list(targets_and_commands) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    
    # Start all RPC calls in parallel
    tasks = Enum.map(targets_and_commands, fn {target, command} ->
      Task.async(fn ->
        {target, call(target, command, timeout: timeout)}
      end)
    end)
    
    # Collect results
    Task.await_many(tasks, timeout + 1000)
  end
  
  @doc """
  Register this system as a command handler.
  
  The handler function receives (command_map, metadata_map) and should
  return the result to be sent back to the caller.
  
  ## Example
  
      # In System3
      CommandRPC.register_handler(:system3, fn command, _meta ->
        case command["action"] do
          "allocate_resources" ->
            # Perform allocation
            %{allocated: true, resource_id: "res_123"}
            
          "get_status" ->
            # Return current status
            %{status: "operational", load: 0.65}
        end
      end)
  """
  def register_handler(system, handler_fn) when is_atom(system) and is_function(handler_fn, 2) do
    CommandRouter.register_handler(system, handler_fn)
  end
  
  @doc """
  Middleware for command handlers to validate and process commands.
  """
  def with_validation(handler_fn, validations) do
    fn command, meta ->
      case validate_command(command, validations) do
        :ok ->
          handler_fn.(command, meta)
          
        {:error, reason} ->
          {:error, {:validation_failed, reason}}
      end
    end
  end
  
  # Private functions
  
  defp validate_command(command, validations) do
    Enum.reduce_while(validations, :ok, fn
      {:required, fields}, :ok ->
        missing = Enum.filter(fields, &(not Map.has_key?(command, &1)))
        if missing == [] do
          {:cont, :ok}
        else
          {:halt, {:error, {:missing_fields, missing}}}
        end
        
      {:values, field, allowed}, :ok ->
        if command[field] in allowed do
          {:cont, :ok}
        else
          {:halt, {:error, {:invalid_value, field, command[field]}}}
        end
    end)
  end
end