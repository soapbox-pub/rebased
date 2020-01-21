# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.TwitterAPI.PasswordControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.PasswordResetToken
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Token
  import Pleroma.Factory

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
  end

  describe "POST /api/pleroma/password_reset" do
    test "it returns HTTP 200", %{conn: conn} do
      user = insert(:user)
      {:ok, token} = PasswordResetToken.create_token(user)
      {:ok, _access_token} = Token.create_token(insert(:oauth_app), user, %{})

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
      assert Comeonin.Pbkdf2.checkpw("test", user.password_hash)
      assert Enum.empty?(Token.get_user_tokens(user))
    end

    test "it sets password_reset_pending to false", %{conn: conn} do
      user = insert(:user, password_reset_pending: true)

      {:ok, token} = PasswordResetToken.create_token(user)
      {:ok, _access_token} = Token.create_token(insert(:oauth_app), user, %{})

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
end
