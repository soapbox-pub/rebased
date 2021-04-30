# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Plugs.AuthenticationPlugTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.User
  alias Pleroma.Web.Plugs.AuthenticationPlug
  alias Pleroma.Web.Plugs.OAuthScopesPlug
  alias Pleroma.Web.Plugs.PlugHelper

  import ExUnit.CaptureLog
  import Pleroma.Factory

  setup %{conn: conn} do
    user = %User{
      id: 1,
      name: "dude",
      password_hash: Pleroma.Password.Pbkdf2.hash_pwd_salt("guy")
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

  test "with a correct password in the credentials, " <>
         "it assigns the auth_user and marks OAuthScopesPlug as skipped",
       %{conn: conn} do
    conn =
      conn
      |> assign(:auth_credentials, %{password: "guy"})
      |> AuthenticationPlug.call(%{})

    assert conn.assigns.user == conn.assigns.auth_user
    assert conn.assigns.token == nil
    assert PlugHelper.plug_skipped?(conn, OAuthScopesPlug)
  end

  test "with a bcrypt hash, it updates to a pkbdf2 hash", %{conn: conn} do
    user = insert(:user, password_hash: Bcrypt.hash_pwd_salt("123"))
    assert "$2" <> _ = user.password_hash

    conn =
      conn
      |> assign(:auth_user, user)
      |> assign(:auth_credentials, %{password: "123"})
      |> AuthenticationPlug.call(%{})

    assert conn.assigns.user.id == conn.assigns.auth_user.id
    assert conn.assigns.token == nil
    assert PlugHelper.plug_skipped?(conn, OAuthScopesPlug)

    user = User.get_by_id(user.id)
    assert "$pbkdf2" <> _ = user.password_hash
  end

  @tag :skip_on_mac
  test "with a crypt hash, it updates to a pkbdf2 hash", %{conn: conn} do
    user =
      insert(:user,
        password_hash:
          "$6$9psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"
      )

    conn =
      conn
      |> assign(:auth_user, user)
      |> assign(:auth_credentials, %{password: "password"})
      |> AuthenticationPlug.call(%{})

    assert conn.assigns.user.id == conn.assigns.auth_user.id
    assert conn.assigns.token == nil
    assert PlugHelper.plug_skipped?(conn, OAuthScopesPlug)

    user = User.get_by_id(user.id)
    assert "$pbkdf2" <> _ = user.password_hash
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

    test "check bcrypt hash" do
      hash = "$2a$10$uyhC/R/zoE1ndwwCtMusK.TLVzkQ/Ugsbqp3uXI.CTTz0gBw.24jS"

      assert AuthenticationPlug.checkpw("password", hash)
      refute AuthenticationPlug.checkpw("password1", hash)
    end

    test "it returns false when hash invalid" do
      hash =
        "psBWV8gxkGOZWBz$PmfCycChoxeJ3GgGzwvhlgacb9mUoZ.KUXNCssekER4SJ7bOK53uXrHNb2e4i8yPFgSKyzaW9CcmrDXWIEMtD1"

      assert capture_log(fn ->
               refute AuthenticationPlug.checkpw("password", hash)
             end) =~ "[error] Password hash not recognized"
    end
  end
end
