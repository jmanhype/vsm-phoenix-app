defmodule VsmPhoenix.TelegramBot.ApplicationPatch do
  @moduledoc """
  Patch instructions to add Enhanced Telegram Bot Supervisor to application.ex
  
  This enables CRDT-based conversation persistence for the Telegram bot.
  """
  
  @doc """
  Add this line to lib/vsm_phoenix/application.ex after line 77 (CRDT Supervisor):
  
      # Start CRDT-based Context Persistence
      VsmPhoenix.CRDT.Supervisor,
      
  +   # Start Enhanced Telegram Bot Components (CRDT persistence)
  +   VsmPhoenix.TelegramBot.EnhancedSupervisor,
      
      # Start Enhanced Security Layer
      VsmPhoenix.Security.Supervisor,
  """
  def patch_location do
    :after_crdt_supervisor
  end
end