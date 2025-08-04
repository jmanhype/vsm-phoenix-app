defmodule VsmPhoenix.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def up do
    # Enable UUID extension
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :email, :string, null: false
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :role, :string, null: false, default: "user"
      add :status, :string, null: false, default: "active"
      add :permissions, :map, default: %{}
      
      # Security fields
      add :failed_login_attempts, :integer, default: 0
      add :locked_at, :utc_datetime
      add :force_password_change, :boolean, default: false
      add :password_changed_at, :utc_datetime
      add :last_login_at, :utc_datetime
      add :last_login_ip, :string
      
      # API Key fields
      add :api_key, :string
      add :api_key_expires_at, :utc_datetime
      
      # MFA fields
      add :mfa_enabled, :boolean, default: false
      add :mfa_secret, :string
      add :backup_codes, {:array, :string}, default: []
      
      # Audit fields
      add :created_by_id, references(:users, type: :uuid)
      add :updated_by_id, references(:users, type: :uuid)
      
      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
    create unique_index(:users, [:api_key])
    create index(:users, [:role])
    create index(:users, [:status])
    create index(:users, [:last_login_at])
  end

  def down do
    drop table(:users)
  end
end