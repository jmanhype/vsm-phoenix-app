defmodule VsmPhoenix.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def up do
    create table(:api_tokens, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :token_hash, :string, null: false
      add :token_type, :string, null: false # "access", "refresh", "api_key", "password_reset", "mfa"
      add :user_id, references(:users, type: :uuid), null: false
      add :name, :string # Human-readable name for the token
      add :description, :text
      
      # Token lifecycle
      add :issued_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :revoked_by_id, references(:users, type: :uuid)
      add :revocation_reason, :string
      
      # Access control
      add :scopes, {:array, :string}, default: []
      add :permissions, :map, default: %{}
      add :ip_restrictions, {:array, :string}, default: []
      add :rate_limit, :integer # requests per hour
      
      # Usage tracking
      add :usage_count, :integer, default: 0
      add :last_ip, :string
      add :last_user_agent, :text
      
      # Security
      add :fingerprint, :string
      add :created_from_ip, :string
      add :created_user_agent, :text
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_tokens, [:token_hash])
    create index(:api_tokens, [:user_id])
    create index(:api_tokens, [:token_type])
    create index(:api_tokens, [:expires_at])
    create index(:api_tokens, [:revoked_at])
    create index(:api_tokens, [:last_used_at])
    create index(:api_tokens, [:issued_at])
    
    # Compound indexes for common queries
    create index(:api_tokens, [:user_id, :token_type, :revoked_at])
    create index(:api_tokens, [:token_type, :expires_at, :revoked_at])
  end

  def down do
    drop table(:api_tokens)
  end
end