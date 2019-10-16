# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MastoFEController do
  use Pleroma.Web.ConnCase

  alias Pleroma.Config
  alias Pleroma.User

  import Pleroma.Factory

  clear_config([:instance, :public])

  test "put settings", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> put("/api/web/settings", %{"data" => %{"programming" => "socks"}})

    assert _result = json_response(conn, 200)

    user = User.get_cached_by_ap_id(user.ap_id)
    assert user.settings == %{"programming" => "socks"}
  end

  describe "index/2 redirections" do
    setup %{conn: conn} do
      session_opts = [
        store: :cookie,
        key: "_test",
        signing_salt: "cooldude"
      ]

      conn =
        conn
        |> Plug.Session.call(Plug.Session.init(session_opts))
        |> fetch_session()

      test_path = "/web/statuses/test"
      %{conn: conn, path: test_path}
    end

    test "redirects not logged-in users to the login page", %{conn: conn, path: path} do
      conn = get(conn, path)

      assert conn.status == 302
      assert redirected_to(conn) == "/web/login"
    end

    test "redirects not logged-in users to the login page on private instances", %{
      conn: conn,
      path: path
    } do
      Config.put([:instance, :public], false)

      conn = get(conn, path)

      assert conn.status == 302
      assert redirected_to(conn) == "/web/login"
    end

    test "does not redirect logged in users to the login page", %{conn: conn, path: path} do
      token = insert(:oauth_token)

      conn =
        conn
        |> assign(:user, token.user)
        |> put_session(:oauth_token, token.token)
        |> get(path)

      assert conn.status == 200
    end

    test "saves referer path to session", %{conn: conn, path: path} do
      conn = get(conn, path)
      return_to = Plug.Conn.get_session(conn, :return_to)

      assert return_to == path
    end
  end
end
