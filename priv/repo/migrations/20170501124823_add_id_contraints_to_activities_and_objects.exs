# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.AddIdContraintsToActivitiesAndObjects do
  use Ecto.Migration

  def change do
    # This was wrong, make it a noop.
    # create index(:objects, ["(data->>\"id\")"], name: :objects_unique_apid_index)
    # create index(:activities, ["(data->>\"id\")"], name: :activities_unique_apid_index)
  end
end
