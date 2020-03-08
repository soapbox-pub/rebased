# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.AuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Plugs.AuthenticationPlug
  alias Pleroma.User

  import ExUnit.CaptureLog

  setup %{conn: conn} do
    user = %User{
      id: 1,
      name: "dude",
      password_hash: Comeonin.Pbkdf2.hashpwsalt("guy")
    }

    conn =
      conn
      |> assign(:auth_user, user)

    %{user: user, conn: conn}
  end

  test "it does nothing if a user is assigned", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %User{})

    ret_conn =
      conn
      |> AuthenticationPlug.call(%{})

    assert ret_conn == conn
  end

  test "with a correct password in the credentials, it assigns the auth_user", %{conn: conn} do
    conn =
      conn
      |> assign(:auth_credentials, %{password: "guy"})
      |> AuthenticationPlug.call(%{})

    assert conn.assigns.user == conn.assigns.auth_user
  end

  test "with a wrong password in the credentials, it does nothing", %{conn: conn} do
    conn =
      conn
      |> assign(:auth_credentials, %{password: "wrong"})

    ret_conn =
      conn
      |> AuthenticationPlug.call(%{})

    assert conn == ret_conn
  end

  describe "checkpw/2" do
    test "check pbkdf2 hash" do
      hash =
        "$pbkdf2-sha512$160000$loXqbp8GYls43F0i6lEfIw$AY.Ep.2pGe57j2hAPY635sI/6w7l9Q9u9Bp02PkPmF3OrClDtJAI8bCiivPr53OKMF7ph6iHhN68Rom5nEfC2A"

      assert AuthenticationPlug.checkpw("test-password", hash)
      refute AuthenticationPlug.checkpw("test-password1", hash)
    end

    @tag :skip_on_mac
    test "check sha512-crypt hash" do
      hash =
        "$6$9psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"

      assert AuthenticationPlug.checkpw("password", hash)
    end

    test "it returns false when hash invalid" do
      hash =
        "psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"

      assert capture_log(fn ->
               refute Pleroma.Plugs.AuthenticationPlug.checkpw("password", hash)
             end) =~ "[error] Password hash not recognized"
    end
  end
end
