# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UpgradeObanJobsToV9 do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 9)
  end

  def down do
    Oban.Migrations.down(version: 9)
  end
end
