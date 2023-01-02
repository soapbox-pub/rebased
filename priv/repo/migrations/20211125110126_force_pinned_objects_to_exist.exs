# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ForcePinnedObjectsToExist do
  use Ecto.Migration

  def change do
    execute("UPDATE users SET pinned_objects = '{}' WHERE pinned_objects IS NULL")

    alter table("users") do
      modify(:pinned_objects, :map, null: false, default: %{})
    end
  end
end
