# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.RenameActivityExpirationSetting do
  use Ecto.Migration

  def change do
    config = Pleroma.ConfigDB.get_by_params(%{group: :pleroma, key: Pleroma.ActivityExpiration})

    if config do
      config
      |> Ecto.Changeset.change(key: Pleroma.Workers.PurgeExpiredActivity)
      |> Pleroma.Repo.update()
    end
  end
end
