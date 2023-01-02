# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DataMigrationCreatePopulateHashtagsTable do
  use Ecto.Migration

  def up do
    dt = NaiveDateTime.utc_now()

    execute(
      "INSERT INTO data_migrations(name, inserted_at, updated_at) " <>
        "VALUES ('populate_hashtags_table', '#{dt}', '#{dt}') ON CONFLICT DO NOTHING;"
    )
  end

  def down do
    execute("DELETE FROM data_migrations WHERE name = 'populate_hashtags_table';")
  end
end
