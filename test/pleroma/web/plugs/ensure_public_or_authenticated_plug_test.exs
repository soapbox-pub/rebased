# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlugTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.Plugs.EnsurePublicOrAuthenticatedPlug

  setup do: clear_config([:instance, :public])

  test "it halts if not public and no user is assigned", %{conn: conn} do
    clear_config([:instance, :public], false)

    conn =
      conn
      |> EnsurePublicOrAuthenticatedPlug.call(%{})

    assert conn.status == 403
    assert conn.halted == true
  end

  test "it continues if public", %{conn: conn} do
    clear_config([:instance, :public], true)

    ret_conn =
      conn
      |> EnsurePublicOrAuthenticatedPlug.call(%{})

    refute ret_conn.halted
  end

  test "it continues if a user is assigned, even if not public", %{conn: conn} do
    clear_config([:instance, :public], false)

    conn =
      conn
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> EnsurePublicOrAuthenticatedPlug.call(%{})

    refute ret_conn.halted
  end
end
