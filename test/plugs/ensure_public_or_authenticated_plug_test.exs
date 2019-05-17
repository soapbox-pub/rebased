# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.EnsurePublicOrAuthenticatedPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Config
  alias Pleroma.Plugs.EnsurePublicOrAuthenticatedPlug
  alias Pleroma.User

  test "it halts if not public and no user is assigned", %{conn: conn} do
    set_public_to(false)

    conn =
      conn
      |> EnsurePublicOrAuthenticatedPlug.call(%{})

    assert conn.status == 403
    assert conn.halted == true
  end

  test "it continues if public", %{conn: conn} do
    set_public_to(true)

    ret_conn =
      conn
      |> EnsurePublicOrAuthenticatedPlug.call(%{})

    assert ret_conn == conn
  end

  test "it continues if a user is assigned, even if not public", %{conn: conn} do
    set_public_to(false)

    conn =
      conn
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> EnsurePublicOrAuthenticatedPlug.call(%{})

    assert ret_conn == conn
  end

  defp set_public_to(value) do
    orig = Config.get!([:instance, :public])
    Config.put([:instance, :public], value)

    on_exit(fn ->
      Config.put([:instance, :public], orig)
    end)
  end
end
