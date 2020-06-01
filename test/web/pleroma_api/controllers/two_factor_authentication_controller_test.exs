defmodule Pleroma.Web.PleromaAPI.TwoFactorAuthenticationControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  alias Pleroma.MFA.Settings
  alias Pleroma.MFA.TOTP

  describe "GET /api/pleroma/accounts/mfa/settings" do
    test "returns user mfa settings for new user", %{conn: conn} do
      token = insert(:oauth_token, scopes: ["read", "follow"])
      token2 = insert(:oauth_token, scopes: ["write"])

      assert conn
             |> put_req_header("authorization", "Bearer #{token.token}")
             |> get("/api/pleroma/accounts/mfa")
             |> json_response(:ok) == %{
               "settings" => %{"enabled" => false, "totp" => false}
             }

      assert conn
             |> put_req_header("authorization", "Bearer #{token2.token}")
             |> get("/api/pleroma/accounts/mfa")
             |> json_response(403) == %{
               "error" => "Insufficient permissions: read:security."
             }
    end

    test "returns user mfa settings with enabled totp", %{conn: conn} do
      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{
            enabled: true,
            totp: %Settings.TOTP{secret: "XXX", delivery_type: "app", confirmed: true}
          }
        )

      token = insert(:oauth_token, scopes: ["read", "follow"], user: user)

      assert conn
             |> put_req_header("authorization", "Bearer #{token.token}")
             |> get("/api/pleroma/accounts/mfa")
             |> json_response(:ok) == %{
               "settings" => %{"enabled" => true, "totp" => true}
             }
    end
  end

  describe "GET /api/pleroma/accounts/mfa/backup_codes" do
    test "returns backup codes", %{conn: conn} do
      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{
            backup_codes: ["1", "2", "3"],
            totp: %Settings.TOTP{secret: "secret"}
          }
        )

      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)
      token2 = insert(:oauth_token, scopes: ["read"])

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token.token}")
        |> get("/api/pleroma/accounts/mfa/backup_codes")
        |> json_response(:ok)

      assert [<<_::bytes-size(6)>>, <<_::bytes-size(6)>>] = response["codes"]
      user = refresh_record(user)
      mfa_settings = user.multi_factor_authentication_settings
      assert mfa_settings.totp.secret == "secret"
      refute mfa_settings.backup_codes == ["1", "2", "3"]
      refute mfa_settings.backup_codes == []

      assert conn
             |> put_req_header("authorization", "Bearer #{token2.token}")
             |> get("/api/pleroma/accounts/mfa/backup_codes")
             |> json_response(403) == %{
               "error" => "Insufficient permissions: write:security."
             }
    end
  end

  describe "GET /api/pleroma/accounts/mfa/setup/totp" do
    test "return errors when method is invalid", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token.token}")
        |> get("/api/pleroma/accounts/mfa/setup/torf")
        |> json_response(400)

      assert response == %{"error" => "undefined method"}
    end

    test "returns key and provisioning_uri", %{conn: conn} do
      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{backup_codes: ["1", "2", "3"]}
        )

      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)
      token2 = insert(:oauth_token, scopes: ["read"])

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token.token}")
        |> get("/api/pleroma/accounts/mfa/setup/totp")
        |> json_response(:ok)

      user = refresh_record(user)
      mfa_settings = user.multi_factor_authentication_settings
      secret = mfa_settings.totp.secret
      refute mfa_settings.enabled
      assert mfa_settings.backup_codes == ["1", "2", "3"]

      assert response == %{
               "key" => secret,
               "provisioning_uri" => TOTP.provisioning_uri(secret, "#{user.email}")
             }

      assert conn
             |> put_req_header("authorization", "Bearer #{token2.token}")
             |> get("/api/pleroma/accounts/mfa/setup/totp")
             |> json_response(403) == %{
               "error" => "Insufficient permissions: write:security."
             }
    end
  end

  describe "GET /api/pleroma/accounts/mfa/confirm/totp" do
    test "returns success result", %{conn: conn} do
      secret = TOTP.generate_secret()
      code = TOTP.generate_token(secret)

      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{
            backup_codes: ["1", "2", "3"],
            totp: %Settings.TOTP{secret: secret}
          }
        )

      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)
      token2 = insert(:oauth_token, scopes: ["read"])

      assert conn
             |> put_req_header("authorization", "Bearer #{token.token}")
             |> post("/api/pleroma/accounts/mfa/confirm/totp", %{password: "test", code: code})
             |> json_response(:ok)

      settings = refresh_record(user).multi_factor_authentication_settings
      assert settings.enabled
      assert settings.totp.secret == secret
      assert settings.totp.confirmed
      assert settings.backup_codes == ["1", "2", "3"]

      assert conn
             |> put_req_header("authorization", "Bearer #{token2.token}")
             |> post("/api/pleroma/accounts/mfa/confirm/totp", %{password: "test", code: code})
             |> json_response(403) == %{
               "error" => "Insufficient permissions: write:security."
             }
    end

    test "returns error if password incorrect", %{conn: conn} do
      secret = TOTP.generate_secret()
      code = TOTP.generate_token(secret)

      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{
            backup_codes: ["1", "2", "3"],
            totp: %Settings.TOTP{secret: secret}
          }
        )

      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token.token}")
        |> post("/api/pleroma/accounts/mfa/confirm/totp", %{password: "xxx", code: code})
        |> json_response(422)

      settings = refresh_record(user).multi_factor_authentication_settings
      refute settings.enabled
      refute settings.totp.confirmed
      assert settings.backup_codes == ["1", "2", "3"]
      assert response == %{"error" => "Invalid password."}
    end

    test "returns error if code incorrect", %{conn: conn} do
      secret = TOTP.generate_secret()

      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{
            backup_codes: ["1", "2", "3"],
            totp: %Settings.TOTP{secret: secret}
          }
        )

      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)
      token2 = insert(:oauth_token, scopes: ["read"])

      response =
        conn
        |> put_req_header("authorization", "Bearer #{token.token}")
        |> post("/api/pleroma/accounts/mfa/confirm/totp", %{password: "test", code: "code"})
        |> json_response(422)

      settings = refresh_record(user).multi_factor_authentication_settings
      refute settings.enabled
      refute settings.totp.confirmed
      assert settings.backup_codes == ["1", "2", "3"]
      assert response == %{"error" => "invalid_token"}

      assert conn
             |> put_req_header("authorization", "Bearer #{token2.token}")
             |> post("/api/pleroma/accounts/mfa/confirm/totp", %{password: "test", code: "code"})
             |> json_response(403) == %{
               "error" => "Insufficient permissions: write:security."
             }
    end
  end

  describe "DELETE /api/pleroma/accounts/mfa/totp" do
    test "returns success result", %{conn: conn} do
      user =
        insert(:user,
          multi_factor_authentication_settings: %Settings{
            backup_codes: ["1", "2", "3"],
            totp: %Settings.TOTP{secret: "secret"}
          }
        )

      token = insert(:oauth_token, scopes: ["write", "follow"], user: user)
      token2 = insert(:oauth_token, scopes: ["read"])

      assert conn
             |> put_req_header("authorization", "Bearer #{token.token}")
             |> delete("/api/pleroma/accounts/mfa/totp", %{password: "test"})
             |> json_response(:ok)

      settings = refresh_record(user).multi_factor_authentication_settings
      refute settings.enabled
      assert settings.totp.secret == nil
      refute settings.totp.confirmed

      assert conn
             |> put_req_header("authorization", "Bearer #{token2.token}")
             |> delete("/api/pleroma/accounts/mfa/totp", %{password: "test"})
             |> json_response(403) == %{
               "error" => "Insufficient permissions: write:security."
             }
    end
  end
end
