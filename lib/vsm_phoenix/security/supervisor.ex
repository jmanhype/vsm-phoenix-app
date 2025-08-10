defmodule VsmPhoenix.Security.Supervisor do
  @moduledoc """
  Supervisor for the cryptographic security layer components.
  
  Manages:
  - CryptoLayer for enhanced cryptographic operations
  - Integration with existing Security infrastructure
  """
  
  use Supervisor
  require Logger
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(opts) do
    Logger.info("🔐 Starting Security Supervisor")
    
    # Get master key from environment or config
    master_key = get_master_key()
    
    children = [
      # Enhanced Crypto Layer
      {VsmPhoenix.Security.CryptoLayer, [master_key: master_key] ++ opts}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  defp get_master_key do
    # In production, this should come from a secure key management service
    case System.get_env("VSM_MASTER_KEY") do
      nil ->
        # Generate and log a warning in development
        Logger.warning("⚠️  No VSM_MASTER_KEY found, generating temporary key")
        :crypto.strong_rand_bytes(32)
      key_base64 ->
        Base.decode64!(key_base64)
    end
  end
end