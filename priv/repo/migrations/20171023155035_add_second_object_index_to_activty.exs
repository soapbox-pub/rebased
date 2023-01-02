# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddSecondObjectIndexToActivty do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    drop_if_exists(
      index(:activities, ["(data->'object'->>'id')", "(data->>'type')"],
        name: :activities_create_objects_index
      )
    )

    create(
      index(:activities, ["(coalesce(data->'object'->>'id', data->>'object'))"],
        name: :activities_create_objects_index,
        concurrently: true
      )
    )
  end
end
