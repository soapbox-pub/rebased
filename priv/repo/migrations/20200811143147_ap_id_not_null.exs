# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ApIdNotNull do
  use Ecto.Migration

  require Logger

  def up do
    Logger.warn(
      "If this migration fails please open an issue at https://git.pleroma.social/pleroma/pleroma/-/issues/new \n"
    )

    alter table(:users) do
      modify(:ap_id, :string, null: false)
    end
  end

  def down do
    :ok
  end
end
