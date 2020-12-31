# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ConfirmLoggedInUsers do
  use Ecto.Migration
  import Ecto.Query
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token

  def up do
    User
    |> where([u], u.confirmation_pending == true)
    |> join(:inner, [u], t in Token, on: t.user_id == u.id)
    |> Repo.update_all(set: [confirmation_pending: false])
  end

  def down do
    :noop
  end
end
