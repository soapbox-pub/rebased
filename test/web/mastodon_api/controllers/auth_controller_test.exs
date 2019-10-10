# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AuthControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Config
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers

  import Pleroma.Factory
  import Swoosh.TestAssertions

  describe "GET /web/login" do
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

    test "redirects to the saved path after log in", %{conn: conn, path: path} do
      app = insert(:oauth_app, client_name: "Mastodon-Local", redirect_uris: ".")
      auth = insert(:oauth_authorization, app: app)

      conn =
        conn
        |> put_session(:return_to, path)
        |> get("/web/login", %{code: auth.token})

      assert conn.status == 302
      assert redirected_to(conn) == path
    end

    test "redirects to the getting-started page when referer is not present", %{conn: conn} do
      app = insert(:oauth_app, client_name: "Mastodon-Local", redirect_uris: ".")
      auth = insert(:oauth_authorization, app: app)

      conn = get(conn, "/web/login", %{code: auth.token})

      assert conn.status == 302
      assert redirected_to(conn) == "/web/getting-started"
    end
  end

  describe "POST /auth/password, with valid parameters" do
    setup %{conn: conn} do
      user = insert(:user)
      conn = post(conn, "/auth/password?email=#{user.email}")
      %{conn: conn, user: user}
    end

    test "it returns 204", %{conn: conn} do
      assert json_response(conn, :no_content)
    end

    test "it creates a PasswordResetToken record for user", %{user: user} do
      token_record = Repo.get_by(Pleroma.PasswordResetToken, user_id: user.id)
      assert token_record
    end

    test "it sends an email to user", %{user: user} do
      ObanHelpers.perform_all()
      token_record = Repo.get_by(Pleroma.PasswordResetToken, user_id: user.id)

      email = Pleroma.Emails.UserEmail.password_reset_email(user, token_record.token)
      notify_email = Config.get([:instance, :notify_email])
      instance_name = Config.get([:instance, :name])

      assert_email_sent(
        from: {instance_name, notify_email},
        to: {user.name, user.email},
        html_body: email.html_body
      )
    end
  end

  describe "POST /auth/password, with invalid parameters" do
    setup do
      user = insert(:user)
      {:ok, user: user}
    end

    test "it returns 404 when user is not found", %{conn: conn, user: user} do
      conn = post(conn, "/auth/password?email=nonexisting_#{user.email}")
      assert conn.status == 404
      assert conn.resp_body == ""
    end

    test "it returns 400 when user is not local", %{conn: conn, user: user} do
      {:ok, user} = Repo.update(Ecto.Changeset.change(user, local: false))
      conn = post(conn, "/auth/password?email=#{user.email}")
      assert conn.status == 400
      assert conn.resp_body == ""
    end
  end

  describe "DELETE /auth/sign_out" do
    test "redirect to root page", %{conn: conn} do
      user = insert(:user)

      conn =
        conn
        |> assign(:user, user)
        |> delete("/auth/sign_out")

      assert conn.status == 302
      assert redirected_to(conn) == "/"
    end
  end
end
