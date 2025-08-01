defmodule VsmPhoenix.MCP.Protocol do
  @moduledoc """
  Real MCP protocol implementation. No hardcoding.
  """
  
  require Logger
  
  @doc """
  Send initialize request to MCP server
  """
  def initialize(transport) do
    request = %{
      jsonrpc: "2.0",
      id: generate_id(),
      method: "initialize",
      params: %{
        protocolVersion: "2024-11-05",
        capabilities: %{
          tools: %{
            listChanged: true
          },
          resources: %{
            subscribe: true,
            listChanged: true
          }
        },
        clientInfo: %{
          name: "vsm_phoenix",
          version: "1.0.0"
        }
      }
    }
    
    send_request(transport, request)
  end
  
  @doc """
  List available tools from server
  """
  def list_tools(transport) do
    request = %{
      jsonrpc: "2.0",
      id: generate_id(),
      method: "tools/list",
      params: %{}
    }
    
    send_request(transport, request)
  end
  
  @doc """
  Execute a tool
  """
  def call_tool(transport, tool_name, arguments) do
    request = %{
      jsonrpc: "2.0",
      id: generate_id(),
      method: "tools/call",
      params: %{
        name: tool_name,
        arguments: arguments
      }
    }
    
    send_request(transport, request)
  end
  
  @doc """
  List available resources
  """
  def list_resources(transport) do
    request = %{
      jsonrpc: "2.0",
      id: generate_id(),
      method: "resources/list",
      params: %{}
    }
    
    send_request(transport, request)
  end
  
  @doc """
  Read a resource
  """
  def read_resource(transport, uri) do
    request = %{
      jsonrpc: "2.0",
      id: generate_id(),
      method: "resources/read",
      params: %{
        uri: uri
      }
    }
    
    send_request(transport, request)
  end
  
  defp send_request(transport, request) do
    # transport is a PID, not a module
    VsmPhoenix.MCP.StdioTransport.send(transport, request)
  end
  
  defp generate_id do
    System.unique_integer([:positive, :monotonic])
  end
end