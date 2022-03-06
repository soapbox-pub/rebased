# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.SetVisibleServiceActors do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo

  def up do
    user_nicknames = ["relay", "internal.fetch"]

    from(
      u in "users",
      where: u.nickname in ^user_nicknames,
      update: [
        set: [invisible: true]
      ]
    )
    |> Repo.update_all([])
  end

  def down do
    :ok
  end
end
