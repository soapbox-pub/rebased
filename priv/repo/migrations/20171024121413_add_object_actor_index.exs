# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddObjectActorIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(
      index(:objects, ["(data->>'actor')", "(data->>'type')"],
        concurrently: true,
        name: :objects_actor_type
      )
    )
  end
end
