# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.PasswordControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Config
  alias Pleroma.PasswordResetToken
  alias Pleroma.Repo
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  import Pleroma.Factory
  import Swoosh.TestAssertions

  describe "GET /api/pleroma/password_reset/token" do
    test "it returns error when token invalid", %{conn: conn} do
      response =
        conn
        |> get("/api/pleroma/password_reset/token")
        |> html_response(:ok)

      assert response =~ "<h2>Invalid Token</h2>"
    end

    test "it shows password reset form", %{conn: conn} do
      user = insert(:user)
      {:ok, token} = PasswordResetToken.create_token(user)

      response =
        conn
        |> get("/api/pleroma/password_reset/#{token.token}")
        |> html_response(:ok)

      assert response =~ "<h2>Password Reset for #{user.nickname}</h2>"
    end

    test "it returns an error when the token has expired", %{conn: conn} do
      clear_config([:instance, :password_reset_token_validity], 0)

      user = insert(:user)
      {:ok, token} = PasswordResetToken.create_token(user)
      {:ok, token} = time_travel(token, -2)

      response =
        conn
        |> get("/api/pleroma/password_reset/#{token.token}")
        |> html_response(:ok)

      assert response =~ "<h2>Invalid Token</h2>"
    end
  end

  describe "POST /api/pleroma/password_reset" do
    test "it fails for an expired token", %{conn: conn} do
      clear_config([:instance, :password_reset_token_validity], 0)

      user = insert(:user)
      {:ok, token} = PasswordResetToken.create_token(user)
      {:ok, token} = time_travel(token, -2)
      {:ok, _access_token} = Token.create(insert(:oauth_app), user, %{})

      params = %{
        "password" => "test",
        password_confirmation: "test",
        token: token.token
      }

      response =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/password_reset", %{data: params})
        |> html_response(:ok)

      refute response =~ "<h2>Password changed!</h2>"
    end

    test "it returns HTTP 200", %{conn: conn} do
      user = insert(:user)
      {:ok, token} = PasswordResetToken.create_token(user)
      {:ok, _access_token} = Token.create(insert(:oauth_app), user, %{})

      params = %{
        "password" => "test",
        password_confirmation: "test",
        token: token.token
      }

      response =
        conn
        |> assign(:user, user)
        |> post("/api/pleroma/password_reset", %{data: params})
        |> html_response(:ok)

      assert response =~ "<h2>Password changed!</h2>"

      user = refresh_record(user)
      assert Pleroma.Password.Pbkdf2.verify_pass("test", user.password_hash)
      assert Enum.empty?(Token.get_user_tokens(user))
    end

    test "it sets password_reset_pending to false", %{conn: conn} do
      user = insert(:user, password_reset_pending: true)

      {:ok, token} = PasswordResetToken.create_token(user)
      {:ok, _access_token} = Token.create(insert(:oauth_app), user, %{})

      params = %{
        "password" => "test",
        password_confirmation: "test",
        token: token.token
      }

      conn
      |> assign(:user, user)
      |> post("/api/pleroma/password_reset", %{data: params})
      |> html_response(:ok)

      assert User.get_by_id(user.id).password_reset_pending == false
    end
  end

  describe "POST /auth/password, with valid parameters" do
    setup %{conn: conn} do
      user = insert(:user)
      conn = post(conn, "/auth/password?email=#{user.email}")
      %{conn: conn, user: user}
    end

    test "it returns 204", %{conn: conn} do
      assert empty_json_response(conn)
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

  describe "POST /auth/password, with nickname" do
    test "it returns 204", %{conn: conn} do
      user = insert(:user)

      assert conn
             |> post("/auth/password?nickname=#{user.nickname}")
             |> empty_json_response()

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

    test "it doesn't fail when a user has no email", %{conn: conn} do
      user = insert(:user, %{email: nil})

      assert conn
             |> post("/auth/password?nickname=#{user.nickname}")
             |> empty_json_response()
    end
  end

  describe "POST /auth/password, with invalid parameters" do
    setup do
      user = insert(:user)
      {:ok, user: user}
    end

    test "it returns 204 when user is not found", %{conn: conn, user: user} do
      conn = post(conn, "/auth/password?email=nonexisting_#{user.email}")

      assert empty_json_response(conn)
    end

    test "it returns 204 when user is not local", %{conn: conn, user: user} do
      {:ok, user} = Repo.update(Ecto.Changeset.change(user, local: false))
      conn = post(conn, "/auth/password?email=#{user.email}")

      assert empty_json_response(conn)
    end

    test "it returns 204 when user is deactivated", %{conn: conn, user: user} do
      {:ok, user} = Repo.update(Ecto.Changeset.change(user, is_active: false, local: true))
      conn = post(conn, "/auth/password?email=#{user.email}")

      assert empty_json_response(conn)
    end
  end
end
