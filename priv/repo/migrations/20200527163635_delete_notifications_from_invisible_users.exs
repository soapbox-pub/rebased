# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.DeleteNotificationsFromInvisibleUsers do
  use Ecto.Migration

  import Ecto.Query
  alias Pleroma.Repo

  def up do
    Pleroma.Notification
    |> join(:inner, [n], activity in assoc(n, :activity))
    |> where(
      [n, a],
      fragment("? in (SELECT ap_id FROM users WHERE invisible = true)", a.actor)
    )
    |> Repo.delete_all()
  end

  def down, do: :ok
end
