defmodule VsmPhoenix.MCP.Architecture.ModuleTemplates do
  @moduledoc """
  Module templates for the clean MCP implementation.
  These serve as starting points for actual implementation.
  """

  @doc """
  Transport behaviour module template.
  """
  def transport_behaviour_template do
    """
    defmodule VsmPhoenix.MCP.Transport.Behaviour do
      @moduledoc \"\"\"
      Defines the behaviour for MCP transport implementations.
      All transports must implement this behaviour for protocol abstraction.
      \"\"\"
      
      @type transport :: pid()
      @type message :: binary()
      @type handler :: (message -> :ok)
      
      @callback start_link(opts :: keyword()) :: GenServer.on_start()
      @callback send(transport, message) :: :ok | {:error, term()}
      @callback receive_loop(handler) :: no_return()
      @callback close(transport) :: :ok
      @callback connected?(transport) :: boolean()
      @callback info(transport) :: map()
    end
    """
  end

  @doc """
  Core server module template.
  """
  def core_server_template do
    """
    defmodule VsmPhoenix.MCP.Core.Server do
      @moduledoc \"\"\"
      Core MCP server implementation with clean architecture.
      Coordinates all MCP operations with proper separation of concerns.
      \"\"\"
      
      use GenServer
      require Logger
      
      alias VsmPhoenix.MCP.{
        Protocol,
        Core.Dispatcher,
        Core.StateManager,
        Core.Registry,
        Transport
      }
      
      defstruct [
        :transport,
        :transport_mod,
        :state_manager,
        :registry,
        :session_id,
        :capabilities,
        :metadata
      ]
      
      # Client API
      
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
      end
      
      def register_tool(server \\\\ __MODULE__, tool_mod, opts \\\\ []) do
        GenServer.call(server, {:register_tool, tool_mod, opts})
      end
      
      def execute_tool(server \\\\ __MODULE__, tool_name, params) do
        GenServer.call(server, {:execute_tool, tool_name, params})
      end
      
      # Server Callbacks
      
      @impl true
      def init(opts) do
        transport_mod = Keyword.fetch!(opts, :transport)
        transport_opts = Keyword.get(opts, :transport_opts, [])
        
        {:ok, transport} = transport_mod.start_link(transport_opts)
        {:ok, state_manager} = StateManager.start_link()
        {:ok, registry} = Registry.start_link()
        
        # Start transport receive loop
        Task.start_link(fn ->
          transport_mod.receive_loop(&handle_message/1)
        end)
        
        state = %__MODULE__{
          transport: transport,
          transport_mod: transport_mod,
          state_manager: state_manager,
          registry: registry,
          session_id: generate_session_id(),
          capabilities: build_capabilities(opts),
          metadata: %{started_at: DateTime.utc_now()}
        }
        
        {:ok, state}
      end
      
      @impl true
      def handle_call({:register_tool, tool_mod, opts}, _from, state) do
        case Registry.register(state.registry, tool_mod, opts) do
          :ok -> {:reply, :ok, state}
          error -> {:reply, error, state}
        end
      end
      
      @impl true
      def handle_call({:execute_tool, tool_name, params}, _from, state) do
        result = Dispatcher.dispatch_tool(tool_name, params, state)
        {:reply, result, state}
      end
      
      @impl true
      def handle_info({:mcp_message, message}, state) do
        handle_message(message)
        {:noreply, state}
      end
      
      # Private Functions
      
      defp handle_message(raw_message) do
        with {:ok, request} <- Protocol.parse(raw_message),
             {:ok, response} <- process_request(request) do
          send_response(response)
        else
          {:error, error} ->
            send_error_response(error)
        end
      end
      
      defp process_request(request) do
        GenServer.call(__MODULE__, {:process_request, request})
      end
      
      defp send_response(response) do
        GenServer.cast(__MODULE__, {:send_response, response})
      end
      
      defp generate_session_id do
        :crypto.strong_rand_bytes(16) |> Base.encode16()
      end
      
      defp build_capabilities(opts) do
        Keyword.get(opts, :capabilities, %{
          experimental: true,
          tool_discovery: true
        })
      end
    end
    """
  end

  @doc """
  JSON-RPC protocol handler template.
  """
  def json_rpc_template do
    """
    defmodule VsmPhoenix.MCP.Protocol.JsonRpc do
      @moduledoc \"\"\"
      JSON-RPC 2.0 protocol implementation for MCP.
      Handles parsing, validation, and response building.
      \"\"\"
      
      require Logger
      
      @json_rpc_version "2.0"
      
      # Request parsing
      
      def parse(message) when is_binary(message) do
        with {:ok, json} <- Jason.decode(message),
             {:ok, request} <- validate_request(json) do
          {:ok, request}
        else
          {:error, %Jason.DecodeError{}} ->
            {:error, parse_error()}
          {:error, error} ->
            {:error, error}
        end
      end
      
      # Response building
      
      def build_response(id, result) do
        %{
          jsonrpc: @json_rpc_version,
          id: id,
          result: result
        }
        |> Jason.encode!()
      end
      
      def build_error_response(id, error) do
        %{
          jsonrpc: @json_rpc_version,
          id: id,
          error: format_error(error)
        }
        |> Jason.encode!()
      end
      
      # Request validation
      
      defp validate_request(%{"jsonrpc" => "2.0"} = request) do
        with :ok <- validate_id(request),
             :ok <- validate_method(request),
             :ok <- validate_params(request) do
          {:ok, normalize_request(request)}
        end
      end
      
      defp validate_request(_), do: {:error, invalid_request()}
      
      defp validate_id(%{"id" => id}) when is_binary(id) or is_number(id), do: :ok
      defp validate_id(%{"id" => _}), do: {:error, invalid_request()}
      defp validate_id(_), do: :ok # Notification
      
      defp validate_method(%{"method" => method}) when is_binary(method), do: :ok
      defp validate_method(_), do: {:error, invalid_request()}
      
      defp validate_params(%{"params" => params}) when is_map(params) or is_list(params), do: :ok
      defp validate_params(%{"params" => _}), do: {:error, invalid_params()}
      defp validate_params(_), do: :ok # No params
      
      # Error definitions
      
      defp parse_error do
        %{code: -32700, message: "Parse error"}
      end
      
      defp invalid_request do
        %{code: -32600, message: "Invalid Request"}
      end
      
      defp method_not_found do
        %{code: -32601, message: "Method not found"}
      end
      
      defp invalid_params do
        %{code: -32602, message: "Invalid params"}
      end
      
      defp internal_error(data \\\\ nil) do
        error = %{code: -32603, message: "Internal error"}
        if data, do: Map.put(error, :data, data), else: error
      end
      
      # Helpers
      
      defp normalize_request(request) do
        %{
          id: Map.get(request, "id"),
          method: request["method"],
          params: Map.get(request, "params", %{})
        }
      end
      
      defp format_error(%{code: _, message: _} = error), do: error
      defp format_error(error), do: internal_error(inspect(error))
    end
    """
  end

  @doc """
  Tool registry template.
  """
  def tool_registry_template do
    """
    defmodule VsmPhoenix.MCP.Tools.Registry do
      @moduledoc \"\"\"
      Dynamic tool registry for MCP.
      Manages tool registration, discovery, and metadata.
      \"\"\"
      
      use GenServer
      require Logger
      
      defstruct tools: %{}, metadata: %{}
      
      # Client API
      
      def start_link(opts \\\\ []) do
        GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
      end
      
      def register(registry \\\\ __MODULE__, tool_mod, opts \\\\ []) do
        GenServer.call(registry, {:register, tool_mod, opts})
      end
      
      def unregister(registry \\\\ __MODULE__, tool_name) do
        GenServer.call(registry, {:unregister, tool_name})
      end
      
      def get_tool(registry \\\\ __MODULE__, tool_name) do
        GenServer.call(registry, {:get_tool, tool_name})
      end
      
      def list_tools(registry \\\\ __MODULE__) do
        GenServer.call(registry, :list_tools)
      end
      
      # Server Callbacks
      
      @impl true
      def init(_opts) do
        {:ok, %__MODULE__{}}
      end
      
      @impl true
      def handle_call({:register, tool_mod, opts}, _from, state) do
        with {:ok, tool_info} <- validate_tool(tool_mod),
             :ok <- check_conflicts(tool_info.name, state.tools) do
          
          new_tools = Map.put(state.tools, tool_info.name, %{
            module: tool_mod,
            info: tool_info,
            opts: opts,
            registered_at: DateTime.utc_now()
          })
          
          Logger.info("Registered tool: \#{tool_info.name}")
          {:reply, :ok, %{state | tools: new_tools}}
        else
          {:error, reason} = error ->
            {:reply, error, state}
        end
      end
      
      @impl true
      def handle_call({:unregister, tool_name}, _from, state) do
        new_tools = Map.delete(state.tools, tool_name)
        {:reply, :ok, %{state | tools: new_tools}}
      end
      
      @impl true
      def handle_call({:get_tool, tool_name}, _from, state) do
        case Map.get(state.tools, tool_name) do
          nil -> {:reply, {:error, :not_found}, state}
          tool -> {:reply, {:ok, tool}, state}
        end
      end
      
      @impl true
      def handle_call(:list_tools, _from, state) do
        tools = Enum.map(state.tools, fn {name, tool} ->
          %{
            name: name,
            description: tool.info.description,
            inputSchema: tool.info.input_schema
          }
        end)
        
        {:reply, tools, state}
      end
      
      # Private Functions
      
      defp validate_tool(tool_mod) do
        if Code.ensure_loaded?(tool_mod) do
          tool_info = %{
            name: tool_mod.name(),
            description: tool_mod.description(),
            input_schema: tool_mod.input_schema()
          }
          {:ok, tool_info}
        else
          {:error, :module_not_loaded}
        end
      rescue
        _ -> {:error, :invalid_tool_module}
      end
      
      defp check_conflicts(tool_name, existing_tools) do
        if Map.has_key?(existing_tools, tool_name) do
          {:error, :already_registered}
        else
          :ok
        end
      end
    end
    """
  end

  @doc """
  Example tool implementation template.
  """
  def tool_implementation_template do
    """
    defmodule VsmPhoenix.MCP.Tools.ExampleTool do
      @moduledoc \"\"\"
      Example tool implementation following the tool behaviour.
      \"\"\"
      
      @behaviour VsmPhoenix.MCP.Tools.Behaviour
      
      @impl true
      def name, do: "example_tool"
      
      @impl true
      def description do
        "An example tool that demonstrates the tool interface"
      end
      
      @impl true
      def input_schema do
        %{
          type: "object",
          properties: %{
            message: %{type: "string", description: "Message to process"},
            options: %{
              type: "object",
              properties: %{
                uppercase: %{type: "boolean", default: false}
              }
            }
          },
          required: ["message"]
        }
      end
      
      @impl true
      def validate(params) do
        # Custom validation logic beyond schema
        if String.length(params["message"] || "") > 0 do
          {:ok, params}
        else
          {:error, ["message cannot be empty"]}
        end
      end
      
      @impl true
      def execute(params) do
        message = params["message"]
        uppercase = get_in(params, ["options", "uppercase"]) || false
        
        result = if uppercase, do: String.upcase(message), else: message
        
        {:ok, %{processed_message: result, timestamp: DateTime.utc_now()}}
      rescue
        error -> {:error, Exception.message(error)}
      end
    end
    """
  end
end
