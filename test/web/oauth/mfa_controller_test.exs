# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.MFAControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  alias Pleroma.MFA
  alias Pleroma.MFA.BackupCodes
  alias Pleroma.MFA.TOTP
  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.OAuthController

  setup %{conn: conn} do
    otp_secret = TOTP.generate_secret()

    user =
      insert(:user,
        multi_factor_authentication_settings: %MFA.Settings{
          enabled: true,
          backup_codes: [Comeonin.Pbkdf2.hashpwsalt("test-code")],
          totp: %MFA.Settings.TOTP{secret: otp_secret, confirmed: true}
        }
      )

    app = insert(:oauth_app)
    {:ok, conn: conn, user: user, app: app}
  end

  describe "show" do
    setup %{conn: conn, user: user, app: app} do
      mfa_token =
        insert(:mfa_token,
          user: user,
          authorization: build(:oauth_authorization, app: app, scopes: ["write"])
        )

      {:ok, conn: conn, mfa_token: mfa_token}
    end

    test "GET /oauth/mfa renders mfa forms", %{conn: conn, mfa_token: mfa_token} do
      conn =
        get(
          conn,
          "/oauth/mfa",
          %{
            "mfa_token" => mfa_token.token,
            "state" => "a_state",
            "redirect_uri" => "http://localhost:8080/callback"
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ "Two-factor authentication"
      assert response =~ mfa_token.token
      assert response =~ "http://localhost:8080/callback"
    end

    test "GET /oauth/mfa renders mfa recovery forms", %{conn: conn, mfa_token: mfa_token} do
      conn =
        get(
          conn,
          "/oauth/mfa",
          %{
            "mfa_token" => mfa_token.token,
            "state" => "a_state",
            "redirect_uri" => "http://localhost:8080/callback",
            "challenge_type" => "recovery"
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ "Two-factor recovery"
      assert response =~ mfa_token.token
      assert response =~ "http://localhost:8080/callback"
    end
  end

  describe "verify" do
    setup %{conn: conn, user: user, app: app} do
      mfa_token =
        insert(:mfa_token,
          user: user,
          authorization: build(:oauth_authorization, app: app, scopes: ["write"])
        )

      {:ok, conn: conn, user: user, mfa_token: mfa_token, app: app}
    end

    test "POST /oauth/mfa/verify, verify totp code", %{
      conn: conn,
      user: user,
      mfa_token: mfa_token,
      app: app
    } do
      otp_token = TOTP.generate_token(user.multi_factor_authentication_settings.totp.secret)

      conn =
        conn
        |> post("/oauth/mfa/verify", %{
          "mfa" => %{
            "mfa_token" => mfa_token.token,
            "challenge_type" => "totp",
            "code" => otp_token,
            "state" => "a_state",
            "redirect_uri" => OAuthController.default_redirect_uri(app)
          }
        })

      target = redirected_to(conn)
      target_url = %URI{URI.parse(target) | query: nil} |> URI.to_string()
      query = URI.parse(target).query |> URI.query_decoder() |> Map.new()
      assert %{"state" => "a_state", "code" => code} = query
      assert target_url == OAuthController.default_redirect_uri(app)
      auth = Repo.get_by(Authorization, token: code)
      assert auth.scopes == ["write"]
    end

    test "POST /oauth/mfa/verify, verify recovery code", %{
      conn: conn,
      mfa_token: mfa_token,
      app: app
    } do
      conn =
        conn
        |> post("/oauth/mfa/verify", %{
          "mfa" => %{
            "mfa_token" => mfa_token.token,
            "challenge_type" => "recovery",
            "code" => "test-code",
            "state" => "a_state",
            "redirect_uri" => OAuthController.default_redirect_uri(app)
          }
        })

      target = redirected_to(conn)
      target_url = %URI{URI.parse(target) | query: nil} |> URI.to_string()
      query = URI.parse(target).query |> URI.query_decoder() |> Map.new()
      assert %{"state" => "a_state", "code" => code} = query
      assert target_url == OAuthController.default_redirect_uri(app)
      auth = Repo.get_by(Authorization, token: code)
      assert auth.scopes == ["write"]
    end
  end

  describe "challenge/totp" do
    test "returns access token with valid code", %{conn: conn, user: user, app: app} do
      otp_token = TOTP.generate_token(user.multi_factor_authentication_settings.totp.secret)

      mfa_token =
        insert(:mfa_token,
          user: user,
          authorization: build(:oauth_authorization, app: app, scopes: ["write"])
        )

      response =
        conn
        |> post("/oauth/mfa/challenge", %{
          "mfa_token" => mfa_token.token,
          "challenge_type" => "totp",
          "code" => otp_token,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(:ok)

      ap_id = user.ap_id

      assert match?(
               %{
                 "access_token" => _,
                 "expires_in" => 600,
                 "me" => ^ap_id,
                 "refresh_token" => _,
                 "scope" => "write",
                 "token_type" => "Bearer"
               },
               response
             )
    end

    test "returns errors when mfa token invalid", %{conn: conn, user: user, app: app} do
      otp_token = TOTP.generate_token(user.multi_factor_authentication_settings.totp.secret)

      response =
        conn
        |> post("/oauth/mfa/challenge", %{
          "mfa_token" => "XXX",
          "challenge_type" => "totp",
          "code" => otp_token,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(400)

      assert response == %{"error" => "Invalid code"}
    end

    test "returns error when otp code is invalid", %{conn: conn, user: user, app: app} do
      mfa_token = insert(:mfa_token, user: user)

      response =
        conn
        |> post("/oauth/mfa/challenge", %{
          "mfa_token" => mfa_token.token,
          "challenge_type" => "totp",
          "code" => "XXX",
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(400)

      assert response == %{"error" => "Invalid code"}
    end

    test "returns error when client credentails is wrong ", %{conn: conn, user: user} do
      otp_token = TOTP.generate_token(user.multi_factor_authentication_settings.totp.secret)
      mfa_token = insert(:mfa_token, user: user)

      response =
        conn
        |> post("/oauth/mfa/challenge", %{
          "mfa_token" => mfa_token.token,
          "challenge_type" => "totp",
          "code" => otp_token,
          "client_id" => "xxx",
          "client_secret" => "xxx"
        })
        |> json_response(400)

      assert response == %{"error" => "Invalid code"}
    end
  end

  describe "challenge/recovery" do
    setup %{conn: conn} do
      app = insert(:oauth_app)
      {:ok, conn: conn, app: app}
    end

    test "returns access token with valid code", %{conn: conn, app: app} do
      otp_secret = TOTP.generate_secret()

      [code | _] = backup_codes = BackupCodes.generate()

      hashed_codes =
        backup_codes
        |> Enum.map(&Comeonin.Pbkdf2.hashpwsalt(&1))

      user =
        insert(:user,
          multi_factor_authentication_settings: %MFA.Settings{
            enabled: true,
            backup_codes: hashed_codes,
            totp: %MFA.Settings.TOTP{secret: otp_secret, confirmed: true}
          }
        )

      mfa_token =
        insert(:mfa_token,
          user: user,
          authorization: build(:oauth_authorization, app: app, scopes: ["write"])
        )

      response =
        conn
        |> post("/oauth/mfa/challenge", %{
          "mfa_token" => mfa_token.token,
          "challenge_type" => "recovery",
          "code" => code,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(:ok)

      ap_id = user.ap_id

      assert match?(
               %{
                 "access_token" => _,
                 "expires_in" => 600,
                 "me" => ^ap_id,
                 "refresh_token" => _,
                 "scope" => "write",
                 "token_type" => "Bearer"
               },
               response
             )

      error_response =
        conn
        |> post("/oauth/mfa/challenge", %{
          "mfa_token" => mfa_token.token,
          "challenge_type" => "recovery",
          "code" => code,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(400)

      assert error_response == %{"error" => "Invalid code"}
    end
  end
end
