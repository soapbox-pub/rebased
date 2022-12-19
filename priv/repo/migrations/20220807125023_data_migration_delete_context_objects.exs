defmodule Pleroma.Repo.Migrations.DataMigrationDeleteContextObjects do
  use Ecto.Migration

  require Logger

  def up do
    dt = NaiveDateTime.utc_now()

    execute(
      "INSERT INTO data_migrations(name, inserted_at, updated_at) " <>
        "VALUES ('delete_context_objects', '#{dt}', '#{dt}') ON CONFLICT DO NOTHING;"
    )
  end

  def down do
    execute("DELETE FROM data_migrations WHERE name = 'delete_context_objects';")
  end
end
