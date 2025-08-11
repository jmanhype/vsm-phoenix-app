defmodule VsmPhoenix.Behaviors.Loggable do
  @moduledoc """
  DRY: Shared logging behavior to eliminate duplicate logging code
  """
  
  require Logger
  
  defmacro __using__(opts) do
    quote do
      require Logger
      
      @log_prefix unquote(opts[:prefix]) || ""
      
      # DRY: Single logging interface instead of 108 separate Logger calls
      defp log_info(message, metadata \\ []) do
        Logger.info("#{@log_prefix} #{message}", metadata)
      end
      
      defp log_error(message, metadata \\ []) do
        Logger.error("#{@log_prefix} ❌ #{message}", metadata)
      end
      
      defp log_warning(message, metadata \\ []) do
        Logger.warning("#{@log_prefix} ⚠️ #{message}", metadata)
      end
      
      defp log_debug(message, metadata \\ []) do
        Logger.debug("#{@log_prefix} 🔍 #{message}", metadata)
      end
      
      # DRY: Common operation logging patterns
      defp log_operation(operation, result) do
        case result do
          {:ok, data} -> 
            log_info("✅ #{operation} succeeded")
            {:ok, data}
          {:error, reason} -> 
            log_error("#{operation} failed: #{inspect(reason)}")
            {:error, reason}
        end
      end
    end
  end
end