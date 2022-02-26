# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.UpdateOban do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 4)
  end

  def down do
    Oban.Migrations.down(version: 3)
  end
end
