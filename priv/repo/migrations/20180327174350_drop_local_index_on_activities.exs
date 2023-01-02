# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DropLocalIndexOnActivities do
  use Ecto.Migration

  def change do
    drop_if_exists(index(:users, [:local]))
  end
end
