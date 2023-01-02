# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemovePinnedActivitiesFromUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      remove(:pinned_activities)
    end
  end

  def down do
    alter table(:users) do
      add(:pinned_activities, {:array, :string}, default: [])
    end
  end
end
