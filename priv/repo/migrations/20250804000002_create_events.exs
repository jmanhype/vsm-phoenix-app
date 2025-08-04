defmodule VsmPhoenix.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def up do
    create table(:events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :event_type, :string, null: false
      add :event_source, :string, null: false
      add :aggregate_id, :uuid
      add :aggregate_type, :string
      add :event_version, :integer, default: 1
      add :correlation_id, :uuid
      add :causation_id, :uuid
      add :data, :map, null: false
      add :metadata, :map, default: %{}
      add :stream_name, :string
      add :stream_version, :integer
      add :global_position, :bigserial
      
      # VSM-specific fields
      add :vsm_system, :integer # 1-5 for VSM systems
      add :vsm_component, :string
      add :viability_impact, :float
      add :variety_level, :integer
      
      # Processing status
      add :processed, :boolean, default: false
      add :processed_at, :utc_datetime
      add :failed_attempts, :integer, default: 0
      add :last_error, :text
      
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:events, [:event_type])
    create index(:events, [:event_source])
    create index(:events, [:aggregate_id])
    create index(:events, [:aggregate_type])
    create index(:events, [:correlation_id])
    create index(:events, [:causation_id])
    create index(:events, [:stream_name])
    create index(:events, [:global_position])
    create index(:events, [:vsm_system])
    create index(:events, [:processed])
    create index(:events, [:inserted_at])
    
    # Create compound indexes for common queries
    create index(:events, [:aggregate_id, :aggregate_type])
    create index(:events, [:stream_name, :stream_version])
    create index(:events, [:vsm_system, :vsm_component])
    create index(:events, [:event_type, :inserted_at])
  end

  def down do
    drop table(:events)
  end
end