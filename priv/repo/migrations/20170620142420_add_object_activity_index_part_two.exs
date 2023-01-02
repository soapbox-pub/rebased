# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddObjectActivityIndexPartTwo do
  use Ecto.Migration

  def change do
    drop_if_exists(
      index(:objects, ["(data->'object'->>'id')", "(data->>'type')"],
        name: :activities_create_objects_index
      )
    )

    create_if_not_exists(
      index(:activities, ["(data->'object'->>'id')", "(data->>'type')"],
        name: :activities_create_objects_index
      )
    )
  end
end
