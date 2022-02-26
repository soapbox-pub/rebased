# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RemoveTeslaFromConfig do
  use Ecto.Migration

  def up do
    execute("DELETE FROM config WHERE config.group = ':tesla'")
  end

  def down do
  end
end
