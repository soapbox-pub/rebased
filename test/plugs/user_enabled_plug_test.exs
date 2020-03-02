# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.UserEnabledPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.UserEnabledPlug
  import Pleroma.Factory

  clear_config([:instance, :account_activation_required])

  test "doesn't do anything if the user isn't set", %{conn: conn} do
    ret_conn =
      conn
      |> UserEnabledPlug.call(%{})

    assert ret_conn == conn
  end

  test "with a user that's not confirmed and a config requiring confirmation, it removes that user",
       %{conn: conn} do
    Pleroma.Config.put([:instance, :account_activation_required], true)

    user = insert(:user, confirmation_pending: true)

    conn =
      conn
      |> assign(:user, user)
      |> UserEnabledPlug.call(%{})

    assert conn.assigns.user == nil
  end

  test "with a user that is deactivated, it removes that user", %{conn: conn} do
    user = insert(:user, deactivated: true)

    conn =
      conn
      |> assign(:user, user)
      |> UserEnabledPlug.call(%{})

    assert conn.assigns.user == nil
  end

  test "with a user that is not deactivated, it does nothing", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)

    ret_conn =
      conn
      |> UserEnabledPlug.call(%{})

    assert conn == ret_conn
  end
end
