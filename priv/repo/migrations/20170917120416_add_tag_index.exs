# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddTagIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(
      index(:activities, ["(data #> '{\"object\",\"tag\"}')"],
        concurrently: true,
        using: :gin,
        name: :activities_tags
      )
    )
  end
end
