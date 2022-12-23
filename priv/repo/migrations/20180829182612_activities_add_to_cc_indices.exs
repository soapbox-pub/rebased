# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ActivitiesAddToCcIndices do
  use Ecto.Migration

  def change do
    create_if_not_exists(
      index(:activities, ["(data->'to')"], name: :activities_to_index, using: :gin)
    )

    create_if_not_exists(
      index(:activities, ["(data->'cc')"], name: :activities_cc_index, using: :gin)
    )
  end
end
