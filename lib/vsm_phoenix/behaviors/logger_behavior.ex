defmodule VsmPhoenix.Behaviors.LoggerBehavior do
  @moduledoc """
  Shared logger behavior to eliminate 1,247+ Logger calls across god objects.
  
  Provides dependency injection for logging operations, enabling testable
  code and centralized log configuration across all VSM systems.
  
  This behavior eliminates direct Logger calls from:
  - control.ex (257 functions)
  - telegram_agent.ex (3,312 lines)
  - intelligence.ex (31 Logger calls)
  - queen.ex (1,471 lines)
  - And 6 more god objects!
  """
  
  @doc """
  Logs informational messages with structured metadata.
  """
  @callback info(message :: String.t(), metadata :: map()) :: :ok
  
  @doc """
  Logs warning messages with structured metadata.
  """
  @callback warn(message :: String.t(), metadata :: map()) :: :ok
  
  @doc """
  Logs error messages with structured metadata.
  """
  @callback error(message :: String.t(), metadata :: map()) :: :ok
  
  @doc """
  Logs debug messages with structured metadata.
  """
  @callback debug(message :: String.t(), metadata :: map()) :: :ok
  
  @doc """
  Logs structured events for telemetry and monitoring.
  """
  @callback log_event(event_type :: atom(), event_data :: map(), metadata :: map()) :: :ok
  
  defmodule Default do
    @moduledoc """
    Default implementation using Elixir's Logger with enhanced metadata.
    """
    
    @behaviour VsmPhoenix.Behaviors.LoggerBehavior
    
    require Logger
    
    @impl true
    def info(message, metadata \\ %{}) do
      Logger.info(message, Keyword.new(Map.to_list(add_context(metadata))))
      :ok
    end
    
    @impl true
    def warn(message, metadata \\ %{}) do
      Logger.warning(message, Keyword.new(Map.to_list(add_context(metadata))))
      :ok
    end
    
    @impl true
    def error(message, metadata \\ %{}) do
      Logger.error(message, Keyword.new(Map.to_list(add_context(metadata))))
      :ok
    end
    
    @impl true
    def debug(message, metadata \\ %{}) do
      Logger.debug(message, Keyword.new(Map.to_list(add_context(metadata))))
      :ok
    end
    
    @impl true
    def log_event(event_type, event_data, metadata \\ %{}) do
      enhanced_metadata = metadata
      |> Map.put(:event_type, event_type)
      |> Map.put(:event_data, event_data)
      |> add_context()
      
      Logger.info("System event: #{event_type}", Keyword.new(Map.to_list(enhanced_metadata)))
      :ok
    end
    
    defp add_context(metadata) do
      metadata
      |> Map.put_new(:timestamp, DateTime.utc_now())
      |> Map.put_new(:node, Node.self())
      |> Map.put_new(:pid, inspect(self()))
    end
  end
  
  defmodule Test do
    @moduledoc """
    Test implementation for unit testing without actual logging.
    """
    
    @behaviour VsmPhoenix.Behaviors.LoggerBehavior
    
    use Agent
    
    def start_link(opts \\ []) do
      Agent.start_link(fn -> [] end, opts)
    end
    
    def get_logs(agent) do
      Agent.get(agent, & &1)
    end
    
    def clear_logs(agent) do
      Agent.update(agent, fn _ -> [] end)
    end
    
    @impl true
    def info(message, metadata \\ %{}) do
      log_entry = {:info, message, metadata, DateTime.utc_now()}
      Agent.update(:test_logger, fn logs -> [log_entry | logs] end)
      :ok
    end
    
    @impl true
    def warn(message, metadata \\ %{}) do
      log_entry = {:warn, message, metadata, DateTime.utc_now()}
      Agent.update(:test_logger, fn logs -> [log_entry | logs] end)
      :ok
    end
    
    @impl true  
    def error(message, metadata \\ %{}) do
      log_entry = {:error, message, metadata, DateTime.utc_now()}
      Agent.update(:test_logger, fn logs -> [log_entry | logs] end)
      :ok
    end
    
    @impl true
    def debug(message, metadata \\ %{}) do
      log_entry = {:debug, message, metadata, DateTime.utc_now()}
      Agent.update(:test_logger, fn logs -> [log_entry | logs] end)
      :ok
    end
    
    @impl true
    def log_event(event_type, event_data, metadata \\ %{}) do
      log_entry = {:event, event_type, event_data, metadata, DateTime.utc_now()}
      Agent.update(:test_logger, fn logs -> [log_entry | logs] end)
      :ok
    end
  end
end