defmodule VsmPhoenix.MCP.Application do
  @moduledoc """
  Supervisor for the MCP subsystem.

  Manages all MCP-related processes including:
  - MCP servers (stdio, HTTP)
  - MCP clients
  - Tool registry
  - Transport processes
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("🚀 Starting MCP Application Supervisor")

    # Determine which components to start
    config = Application.get_env(:vsm_phoenix, :mcp, [])

    children = build_children(config, opts)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp build_children(config, _opts) do
    children = []

    # Tool Registry (always started)
    children = [
      {VsmPhoenix.MCP.Tools.VsmToolRegistry, []}
      | children
    ]

    # MCP Server (if enabled)
    children =
      if Keyword.get(config, :server_enabled, true) do
        server_children =
          case Keyword.get(config, :server_transport, :stdio) do
            :stdio ->
              [
                # STDIO transport
                {VsmPhoenix.MCP.Transports.StdioTransport, [name: :vsm_stdio_transport]},
                # MCP Server using stdio
                {VsmPhoenix.MCP.Servers.VsmHermesServer,
                 [
                   transport: [
                     layer: VsmPhoenix.MCP.Transports.StdioTransport,
                     name: :vsm_stdio_transport
                   ],
                   name: :vsm_mcp_server
                 ]}
              ]

            :http ->
              [
                # HTTP Server
                {VsmPhoenix.MCP.Servers.VsmHermesServer,
                 [
                   transport: [
                     layer: Hermes.Transport.StreamableHTTP,
                     name: :vsm_http_transport
                   ],
                   name: :vsm_mcp_server,
                   port: Keyword.get(config, :server_port, 8080)
                 ]}
              ]

            _ ->
              []
          end

        server_children ++ children
      else
        children
      end

    # MCP Client (if enabled)
    children =
      if Keyword.get(config, :client_enabled, true) do
        client_config =
          case Keyword.get(config, :client_transport, :stdio) do
            :stdio ->
              [transport: :stdio]

            {:http, url} ->
              [transport: {:http, url}]

            _ ->
              []
          end

        if client_config != [] do
          [{VsmPhoenix.MCP.Clients.VsmHermesClient, client_config} | children]
        else
          children
        end
      else
        children
      end

    # Registry for tracking MCP connections
    children =
      if Keyword.get(config, :registry_enabled, true) do
        [
          {Registry, keys: :unique, name: VsmPhoenix.MCP.Registry}
          | children
        ]
      else
        children
      end

    Enum.reverse(children)
  end

  @doc """
  Start an MCP server dynamically
  """
  def start_server(transport_type, opts \\ []) do
    spec =
      case transport_type do
        :stdio ->
          %{
            id: :dynamic_stdio_server,
            start:
              {VsmPhoenix.MCP.Servers.VsmHermesServer, :start_link,
               [
                 Keyword.merge(
                   [
                     transport: [
                       layer: VsmPhoenix.MCP.Transports.StdioTransport,
                       name: :dynamic_stdio_transport
                     ]
                   ],
                   opts
                 )
               ]}
          }

        {:http, port} ->
          %{
            id: :dynamic_http_server,
            start:
              {VsmPhoenix.MCP.Servers.VsmHermesServer, :start_link,
               [
                 Keyword.merge(
                   [
                     transport: [
                       layer: Hermes.Transport.StreamableHTTP,
                       name: :dynamic_http_transport
                     ],
                     port: port
                   ],
                   opts
                 )
               ]}
          }
      end

    Supervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Start an MCP client dynamically
  """
  def start_client(server_url, opts \\ []) do
    spec = %{
      id: {:dynamic_client, server_url},
      start:
        {VsmPhoenix.MCP.Clients.VsmHermesClient, :start_link,
         [
           Keyword.merge(
             [
               transport: {:http, server_url}
             ],
             opts
           )
         ]}
    }

    Supervisor.start_child(__MODULE__, spec)
  end
end
