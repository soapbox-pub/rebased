defmodule Pleroma.Repo.Migrations.DataMigrationDeleteContextObjects do
  use Ecto.Migration

  require Logger

  @doc "This migration removes objects created exclusively for contexts, containing only an `id` field."

  def change do
    Logger.warn(
      "This migration can take a very long time to execute, depending on your database size. Please be patient, Pleroma-tan is doing her best!\n"
    )

    execute("DELETE FROM objects WHERE (data->>'type') IS NULL;")
  end
end
