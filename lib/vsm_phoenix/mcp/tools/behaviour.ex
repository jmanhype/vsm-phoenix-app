defmodule VsmPhoenix.MCP.Tools.Behaviour do
  @moduledoc """
  Behaviour for MCP tool implementations.
  
  All VSM MCP tools must implement this behaviour to ensure
  consistent tool definitions and execution patterns.
  """
  
  @doc """
  Returns the tool definition including name, description, and input schema.
  """
  @callback tool_definition() :: map()
  
  @doc """
  Executes the tool with the given arguments.
  
  Arguments are validated against the input schema before execution.
  Must return {:ok, result} or {:error, reason}.
  """
  @callback execute(arguments :: map()) :: {:ok, any()} | {:error, String.t()}
end