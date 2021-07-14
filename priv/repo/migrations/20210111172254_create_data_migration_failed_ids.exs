defmodule Pleroma.Repo.Migrations.CreateDataMigrationFailedIds do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:data_migration_failed_ids, primary_key: false) do
      add(:data_migration_id, references(:data_migrations), null: false, primary_key: true)
      add(:record_id, :bigint, null: false, primary_key: true)
    end

    create_if_not_exists(
      unique_index(:data_migration_failed_ids, [:data_migration_id, :record_id])
    )
  end
end
