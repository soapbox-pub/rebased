# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UserFetcherPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.UserFetcherPlug
  import Pleroma.Factory

  setup do
    user = insert(:user)
    %{user: user}
  end

  test "if an auth_credentials assign is present, it tries to fetch the user and assigns it", %{
    conn: conn,
    user: user
  } do
    conn =
      conn
      |> assign(:auth_credentials, %{
        username: user.nickname,
        password: nil
      })

    conn =
      conn
      |> UserFetcherPlug.call(%{})

    assert conn.assigns[:auth_user] == user
  end

  test "without a credential assign it doesn't do anything", %{conn: conn} do
    ret_conn =
      conn
      |> UserFetcherPlug.call(%{})

    assert conn == ret_conn
  end
end
