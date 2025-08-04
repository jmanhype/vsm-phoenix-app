defmodule VsmPhoenix.Repo.Migrations.CreateSecurityAudit do
  use Ecto.Migration

  def up do
    create table(:security_audit_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :event_type, :string, null: false # "login", "logout", "api_access", "permission_change", etc.
      add :severity, :string, null: false, default: "info" # "low", "medium", "high", "critical"
      add :user_id, references(:users, type: :uuid)
      add :session_id, :string
      add :ip_address, :string
      add :user_agent, :text
      add :resource, :string # Resource being accessed
      add :action, :string # Action being performed
      add :result, :string, null: false # "success", "failure", "blocked"
      add :details, :map, default: %{}
      add :risk_score, :integer, default: 0
      
      # Request context
      add :request_id, :string
      add :correlation_id, :uuid
      add :method, :string
      add :path, :string
      add :params, :map
      add :headers, :map
      
      # Response information
      add :status_code, :integer
      add :response_time_ms, :integer
      
      # Geolocation (if available)
      add :country, :string
      add :region, :string
      add :city, :string
      add :latitude, :float
      add :longitude, :float
      
      # Detection information
      add :detection_rules, {:array, :string}, default: []
      add :false_positive, :boolean, default: false
      add :investigated, :boolean, default: false
      add :investigated_by_id, references(:users, type: :uuid)
      add :investigation_notes, :text
      
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:security_audit_logs, [:event_type])
    create index(:security_audit_logs, [:severity])
    create index(:security_audit_logs, [:user_id])
    create index(:security_audit_logs, [:ip_address])
    create index(:security_audit_logs, [:result])
    create index(:security_audit_logs, [:risk_score])
    create index(:security_audit_logs, [:inserted_at])
    create index(:security_audit_logs, [:session_id])
    create index(:security_audit_logs, [:correlation_id])
    
    # Compound indexes for common security queries
    create index(:security_audit_logs, [:user_id, :event_type, :inserted_at])
    create index(:security_audit_logs, [:ip_address, :result, :inserted_at])
    create index(:security_audit_logs, [:severity, :investigated, :inserted_at])
    create index(:security_audit_logs, [:event_type, :result, :inserted_at])
  end

  def down do
    drop table(:security_audit_logs)
  end
end