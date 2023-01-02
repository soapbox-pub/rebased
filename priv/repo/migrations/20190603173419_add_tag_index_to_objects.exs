# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddTagIndexToObjects do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:activities, ["(data #> '{\"object\",\"tag\"}')"], using: :gin, name: :activities_tags)
    )

    create_if_not_exists(index(:objects, ["(data->'tag')"], using: :gin, name: :objects_tags))
  end
end
