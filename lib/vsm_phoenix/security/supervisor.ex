defmodule VsmPhoenix.Security.Supervisor do
  @moduledoc """
  Supervisor for all security components, ensuring high availability and fault tolerance.
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = [
      # Bloom filter for nonce tracking
      {VsmPhoenix.Security.BloomFilter, 
       name: VsmPhoenix.Security.BloomFilter,
       size: opts[:bloom_filter_size] || 10_000_000,
       hash_count: 4,
       ttl_ms: :timer.minutes(5)},
      
      # Message validator
      {VsmPhoenix.Security.MessageValidator,
       name: VsmPhoenix.Security.MessageValidator,
       signature_algorithm: opts[:signature_algorithm] || :hmac,
       signing_key: opts[:signing_key],
       bloom_filter_size: 10_000_000},
      
      # Audit logger
      {VsmPhoenix.Security.AuditLogger,
       name: VsmPhoenix.Security.AuditLogger,
       archive_path: opts[:audit_archive_path] || "priv/security_logs",
       auth_failure_threshold: 5,
       replay_attack_threshold: 3}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end