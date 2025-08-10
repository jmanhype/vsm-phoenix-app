defmodule VsmPhoenix.TelegramBot.EnhancedSupervisor do
  @moduledoc """
  Supervisor for enhanced Telegram bot components with CRDT persistence.
  Add this to your application supervision tree to enable persistent conversations.
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    Logger.info("🤖 Starting Enhanced Telegram Bot Supervisor")
    
    children = [
      # Start the CRDT-based Conversation Manager
      {VsmPhoenix.TelegramBot.ConversationManager, []},
      
      # Start the Command Orchestrator for sub-agent delegation
      {VsmPhoenix.TelegramBot.CommandOrchestrator, []},
      
      # Start the Prompt Optimizer for XML-based prompts
      {VsmPhoenix.TelegramBot.PromptOptimizer, []},
      
      # Start the Enhanced Stub for backward compatibility
      {VsmPhoenix.TelegramBot.EnhancedStub, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end