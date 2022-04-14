# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddActorIndexToActivity do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:activities, ["(data->>'actor')", "inserted_at desc"], name: :activities_actor_index)
    )
  end
end
