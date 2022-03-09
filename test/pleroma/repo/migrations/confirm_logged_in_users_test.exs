# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Repo.Migrations.ConfirmLoggedInUsersTest do
  alias Pleroma.Repo
  alias Pleroma.User
  use Pleroma.DataCase, async: true
  import Ecto.Query
  import Pleroma.Factory
  import Pleroma.Tests.Helpers

  setup_all do: require_migration("20201231185546_confirm_logged_in_users")

  test "up/0 confirms unconfirmed but previously-logged-in users", %{migration: migration} do
    insert_list(25, :oauth_token)
    Repo.update_all(User, set: [is_confirmed: false])
    insert_list(5, :user, is_confirmed: false)

    count =
      User
      |> where(is_confirmed: false)
      |> Repo.aggregate(:count)

    assert count == 30

    assert {25, nil} == migration.up()

    count =
      User
      |> where(is_confirmed: false)
      |> Repo.aggregate(:count)

    assert count == 5
  end

  test "down/0 does nothing", %{migration: migration} do
    assert :noop == migration.down()
  end
end
