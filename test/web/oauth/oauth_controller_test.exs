# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.OAuthController
  alias Pleroma.Web.OAuth.Token

  @session_opts [
    store: :cookie,
    key: "_test",
    signing_salt: "cooldude"
  ]
  clear_config_all([:instance, :account_activation_required])

  describe "in OAuth consumer mode, " do
    setup do
      [
        app: insert(:oauth_app),
        conn:
          build_conn()
          |> Plug.Session.call(Plug.Session.init(@session_opts))
          |> fetch_session()
      ]
    end

    clear_config([:auth, :oauth_consumer_strategies]) do
      Pleroma.Config.put(
        [:auth, :oauth_consumer_strategies],
        ~w(twitter facebook)
      )
    end

    test "GET /oauth/authorize renders auth forms, including OAuth consumer form", %{
      app: app,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/oauth/authorize",
          %{
            "response_type" => "code",
            "client_id" => app.client_id,
            "redirect_uri" => OAuthController.default_redirect_uri(app),
            "scope" => "read"
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ "Sign in with Twitter"
      assert response =~ o_auth_path(conn, :prepare_request)
    end

    test "GET /oauth/prepare_request encodes parameters as `state` and redirects", %{
      app: app,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/oauth/prepare_request",
          %{
            "provider" => "twitter",
            "authorization" => %{
              "scope" => "read follow",
              "client_id" => app.client_id,
              "redirect_uri" => OAuthController.default_redirect_uri(app),
              "state" => "a_state"
            }
          }
        )

      assert response = html_response(conn, 302)

      redirect_query = URI.parse(redirected_to(conn)).query
      assert %{"state" => state_param} = URI.decode_query(redirect_query)
      assert {:ok, state_components} = Poison.decode(state_param)

      expected_client_id = app.client_id
      expected_redirect_uri = app.redirect_uris

      assert %{
               "scope" => "read follow",
               "client_id" => ^expected_client_id,
               "redirect_uri" => ^expected_redirect_uri,
               "state" => "a_state"
             } = state_components
    end

    test "with user-bound registration, GET /oauth/<provider>/callback redirects to `redirect_uri` with `code`",
         %{app: app, conn: conn} do
      registration = insert(:registration)
      redirect_uri = OAuthController.default_redirect_uri(app)

      state_params = %{
        "scope" => Enum.join(app.scopes, " "),
        "client_id" => app.client_id,
        "redirect_uri" => redirect_uri,
        "state" => ""
      }

      conn =
        conn
        |> assign(:ueberauth_auth, %{provider: registration.provider, uid: registration.uid})
        |> get(
          "/oauth/twitter/callback",
          %{
            "oauth_token" => "G-5a3AAAAAAAwMH9AAABaektfSM",
            "oauth_verifier" => "QZl8vUqNvXMTKpdmUnGejJxuHG75WWWs",
            "provider" => "twitter",
            "state" => Poison.encode!(state_params)
          }
        )

      assert response = html_response(conn, 302)
      assert redirected_to(conn) =~ ~r/#{redirect_uri}\?code=.+/
    end

    test "with user-unbound registration, GET /oauth/<provider>/callback renders registration_details page",
         %{app: app, conn: conn} do
      user = insert(:user)

      state_params = %{
        "scope" => "read write",
        "client_id" => app.client_id,
        "redirect_uri" => OAuthController.default_redirect_uri(app),
        "state" => "a_state"
      }

      conn =
        conn
        |> assign(:ueberauth_auth, %{
          provider: "twitter",
          uid: "171799000",
          info: %{nickname: user.nickname, email: user.email, name: user.name, description: nil}
        })
        |> get(
          "/oauth/twitter/callback",
          %{
            "oauth_token" => "G-5a3AAAAAAAwMH9AAABaektfSM",
            "oauth_verifier" => "QZl8vUqNvXMTKpdmUnGejJxuHG75WWWs",
            "provider" => "twitter",
            "state" => Poison.encode!(state_params)
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ ~r/name="op" type="submit" value="register"/
      assert response =~ ~r/name="op" type="submit" value="connect"/
      assert response =~ user.email
      assert response =~ user.nickname
    end

    test "on authentication error, GET /oauth/<provider>/callback redirects to `redirect_uri`", %{
      app: app,
      conn: conn
    } do
      state_params = %{
        "scope" => Enum.join(app.scopes, " "),
        "client_id" => app.client_id,
        "redirect_uri" => OAuthController.default_redirect_uri(app),
        "state" => ""
      }

      conn =
        conn
        |> assign(:ueberauth_failure, %{errors: [%{message: "(error description)"}]})
        |> get(
          "/oauth/twitter/callback",
          %{
            "oauth_token" => "G-5a3AAAAAAAwMH9AAABaektfSM",
            "oauth_verifier" => "QZl8vUqNvXMTKpdmUnGejJxuHG75WWWs",
            "provider" => "twitter",
            "state" => Poison.encode!(state_params)
          }
        )

      assert response = html_response(conn, 302)
      assert redirected_to(conn) == app.redirect_uris
      assert get_flash(conn, :error) == "Failed to authenticate: (error description)."
    end

    test "GET /oauth/registration_details renders registration details form", %{
      app: app,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/oauth/registration_details",
          %{
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => OAuthController.default_redirect_uri(app),
              "state" => "a_state",
              "nickname" => nil,
              "email" => "john@doe.com"
            }
          }
        )

      assert response = html_response(conn, 200)
      assert response =~ ~r/name="op" type="submit" value="register"/
      assert response =~ ~r/name="op" type="submit" value="connect"/
    end

    test "with valid params, POST /oauth/register?op=register redirects to `redirect_uri` with `code`",
         %{
           app: app,
           conn: conn
         } do
      registration = insert(:registration, user: nil, info: %{"nickname" => nil, "email" => nil})
      redirect_uri = OAuthController.default_redirect_uri(app)

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "register",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => redirect_uri,
              "state" => "a_state",
              "nickname" => "availablenick",
              "email" => "available@email.com"
            }
          }
        )

      assert response = html_response(conn, 302)
      assert redirected_to(conn) =~ ~r/#{redirect_uri}\?code=.+/
    end

    test "with unlisted `redirect_uri`, POST /oauth/register?op=register results in HTTP 401",
         %{
           app: app,
           conn: conn
         } do
      registration = insert(:registration, user: nil, info: %{"nickname" => nil, "email" => nil})
      unlisted_redirect_uri = "http://cross-site-request.com"

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "register",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => unlisted_redirect_uri,
              "state" => "a_state",
              "nickname" => "availablenick",
              "email" => "available@email.com"
            }
          }
        )

      assert response = html_response(conn, 401)
    end

    test "with invalid params, POST /oauth/register?op=register renders registration_details page",
         %{
           app: app,
           conn: conn
         } do
      another_user = insert(:user)
      registration = insert(:registration, user: nil, info: %{"nickname" => nil, "email" => nil})

      params = %{
        "op" => "register",
        "authorization" => %{
          "scopes" => app.scopes,
          "client_id" => app.client_id,
          "redirect_uri" => OAuthController.default_redirect_uri(app),
          "state" => "a_state",
          "nickname" => "availablenickname",
          "email" => "available@email.com"
        }
      }

      for {bad_param, bad_param_value} <-
            [{"nickname", another_user.nickname}, {"email", another_user.email}] do
        bad_registration_attrs = %{
          "authorization" => Map.put(params["authorization"], bad_param, bad_param_value)
        }

        bad_params = Map.merge(params, bad_registration_attrs)

        conn =
          conn
          |> put_session(:registration_id, registration.id)
          |> post("/oauth/register", bad_params)

        assert html_response(conn, 403) =~ ~r/name="op" type="submit" value="register"/
        assert get_flash(conn, :error) == "Error: #{bad_param} has already been taken."
      end
    end

    test "with valid params, POST /oauth/register?op=connect redirects to `redirect_uri` with `code`",
         %{
           app: app,
           conn: conn
         } do
      user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt("testpassword"))
      registration = insert(:registration, user: nil)
      redirect_uri = OAuthController.default_redirect_uri(app)

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "connect",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => redirect_uri,
              "state" => "a_state",
              "name" => user.nickname,
              "password" => "testpassword"
            }
          }
        )

      assert response = html_response(conn, 302)
      assert redirected_to(conn) =~ ~r/#{redirect_uri}\?code=.+/
    end

    test "with unlisted `redirect_uri`, POST /oauth/register?op=connect results in HTTP 401`",
         %{
           app: app,
           conn: conn
         } do
      user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt("testpassword"))
      registration = insert(:registration, user: nil)
      unlisted_redirect_uri = "http://cross-site-request.com"

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post(
          "/oauth/register",
          %{
            "op" => "connect",
            "authorization" => %{
              "scopes" => app.scopes,
              "client_id" => app.client_id,
              "redirect_uri" => unlisted_redirect_uri,
              "state" => "a_state",
              "name" => user.nickname,
              "password" => "testpassword"
            }
          }
        )

      assert response = html_response(conn, 401)
    end

    test "with invalid params, POST /oauth/register?op=connect renders registration_details page",
         %{
           app: app,
           conn: conn
         } do
      user = insert(:user)
      registration = insert(:registration, user: nil)

      params = %{
        "op" => "connect",
        "authorization" => %{
          "scopes" => app.scopes,
          "client_id" => app.client_id,
          "redirect_uri" => OAuthController.default_redirect_uri(app),
          "state" => "a_state",
          "name" => user.nickname,
          "password" => "wrong password"
        }
      }

      conn =
        conn
        |> put_session(:registration_id, registration.id)
        |> post("/oauth/register", params)

      assert html_response(conn, 401) =~ ~r/name="op" type="submit" value="connect"/
      assert get_flash(conn, :error) == "Invalid Username/Password"
    end
  end

  describe "GET /oauth/authorize" do
    setup do
      [
        app: insert(:oauth_app, redirect_uris: "https://redirect.url"),
        conn:
          build_conn()
          |> Plug.Session.call(Plug.Session.init(@session_opts))
          |> fetch_session()
      ]
    end

    test "renders authentication page", %{app: app, conn: conn} do
      conn =
        get(
          conn,
          "/oauth/authorize",
          %{
            "response_type" => "code",
            "client_id" => app.client_id,
            "redirect_uri" => OAuthController.default_redirect_uri(app),
            "scope" => "read"
          }
        )

      assert html_response(conn, 200) =~ ~s(type="submit")
    end

    test "properly handles internal calls with `authorization`-wrapped params", %{
      app: app,
      conn: conn
    } do
      conn =
        get(
          conn,
          "/oauth/authorize",
          %{
            "authorization" => %{
              "response_type" => "code",
              "client_id" => app.client_id,
              "redirect_uri" => OAuthController.default_redirect_uri(app),
              "scope" => "read"
            }
          }
        )

      assert html_response(conn, 200) =~ ~s(type="submit")
    end

    test "renders authentication page if user is already authenticated but `force_login` is tru-ish",
         %{app: app, conn: conn} do
      token = insert(:oauth_token, app_id: app.id)

      conn =
        conn
        |> put_session(:oauth_token, token.token)
        |> get(
          "/oauth/authorize",
          %{
            "response_type" => "code",
            "client_id" => app.client_id,
            "redirect_uri" => OAuthController.default_redirect_uri(app),
            "scope" => "read",
            "force_login" => "true"
          }
        )

      assert html_response(conn, 200) =~ ~s(type="submit")
    end

    test "with existing authentication and non-OOB `redirect_uri`, redirects to app with `token` and `state` params",
         %{
           app: app,
           conn: conn
         } do
      token = insert(:oauth_token, app_id: app.id)

      conn =
        conn
        |> put_session(:oauth_token, token.token)
        |> get(
          "/oauth/authorize",
          %{
            "response_type" => "code",
            "client_id" => app.client_id,
            "redirect_uri" => OAuthController.default_redirect_uri(app),
            "state" => "specific_client_state",
            "scope" => "read"
          }
        )

      assert URI.decode(redirected_to(conn)) ==
               "https://redirect.url?access_token=#{token.token}&state=specific_client_state"
    end

    test "with existing authentication and unlisted non-OOB `redirect_uri`, redirects without credentials",
         %{
           app: app,
           conn: conn
         } do
      unlisted_redirect_uri = "http://cross-site-request.com"
      token = insert(:oauth_token, app_id: app.id)

      conn =
        conn
        |> put_session(:oauth_token, token.token)
        |> get(
          "/oauth/authorize",
          %{
            "response_type" => "code",
            "client_id" => app.client_id,
            "redirect_uri" => unlisted_redirect_uri,
            "state" => "specific_client_state",
            "scope" => "read"
          }
        )

      assert redirected_to(conn) == unlisted_redirect_uri
    end

    test "with existing authentication and OOB `redirect_uri`, redirects to app with `token` and `state` params",
         %{
           app: app,
           conn: conn
         } do
      token = insert(:oauth_token, app_id: app.id)

      conn =
        conn
        |> put_session(:oauth_token, token.token)
        |> get(
          "/oauth/authorize",
          %{
            "response_type" => "code",
            "client_id" => app.client_id,
            "redirect_uri" => "urn:ietf:wg:oauth:2.0:oob",
            "scope" => "read"
          }
        )

      assert html_response(conn, 200) =~ "Authorization exists"
    end
  end

  describe "POST /oauth/authorize" do
    test "redirects with oauth authorization" do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write", "follow"])
      redirect_uri = OAuthController.default_redirect_uri(app)

      conn =
        build_conn()
        |> post("/oauth/authorize", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "test",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "scope" => "read:subscope write",
            "state" => "statepassed"
          }
        })

      target = redirected_to(conn)
      assert target =~ redirect_uri

      query = URI.parse(target).query |> URI.query_decoder() |> Map.new()

      assert %{"state" => "statepassed", "code" => code} = query
      auth = Repo.get_by(Authorization, token: code)
      assert auth
      assert auth.scopes == ["read:subscope", "write"]
    end

    test "returns 401 for wrong credentials", %{conn: conn} do
      user = insert(:user)
      app = insert(:oauth_app)
      redirect_uri = OAuthController.default_redirect_uri(app)

      result =
        conn
        |> post("/oauth/authorize", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "wrong",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "state" => "statepassed",
            "scope" => Enum.join(app.scopes, " ")
          }
        })
        |> html_response(:unauthorized)

      # Keep the details
      assert result =~ app.client_id
      assert result =~ redirect_uri

      # Error message
      assert result =~ "Invalid Username/Password"
    end

    test "returns 401 for missing scopes", %{conn: conn} do
      user = insert(:user)
      app = insert(:oauth_app)
      redirect_uri = OAuthController.default_redirect_uri(app)

      result =
        conn
        |> post("/oauth/authorize", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "test",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "state" => "statepassed",
            "scope" => ""
          }
        })
        |> html_response(:unauthorized)

      # Keep the details
      assert result =~ app.client_id
      assert result =~ redirect_uri

      # Error message
      assert result =~ "This action is outside the authorized scopes"
    end

    test "returns 401 for scopes beyond app scopes hierarchy", %{conn: conn} do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])
      redirect_uri = OAuthController.default_redirect_uri(app)

      result =
        conn
        |> post("/oauth/authorize", %{
          "authorization" => %{
            "name" => user.nickname,
            "password" => "test",
            "client_id" => app.client_id,
            "redirect_uri" => redirect_uri,
            "state" => "statepassed",
            "scope" => "read write follow"
          }
        })
        |> html_response(:unauthorized)

      # Keep the details
      assert result =~ app.client_id
      assert result =~ redirect_uri

      # Error message
      assert result =~ "This action is outside the authorized scopes"
    end
  end

  describe "POST /oauth/token" do
    test "issues a token for an all-body request" do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])

      {:ok, auth} = Authorization.create_authorization(app, user, ["write"])

      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => auth.token,
          "redirect_uri" => OAuthController.default_redirect_uri(app),
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert %{"access_token" => token, "me" => ap_id} = json_response(conn, 200)

      token = Repo.get_by(Token, token: token)
      assert token
      assert token.scopes == auth.scopes
      assert user.ap_id == ap_id
    end

    test "issues a token for `password` grant_type with valid credentials, with full permissions by default" do
      password = "testpassword"
      user = insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt(password))

      app = insert(:oauth_app, scopes: ["read", "write"])

      # Note: "scope" param is intentionally omitted
      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert %{"access_token" => token} = json_response(conn, 200)

      token = Repo.get_by(Token, token: token)
      assert token
      assert token.scopes == app.scopes
    end

    test "issues a token for request with HTTP basic auth client credentials" do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["scope1", "scope2", "scope3"])

      {:ok, auth} = Authorization.create_authorization(app, user, ["scope1", "scope2"])
      assert auth.scopes == ["scope1", "scope2"]

      app_encoded =
        (URI.encode_www_form(app.client_id) <> ":" <> URI.encode_www_form(app.client_secret))
        |> Base.encode64()

      conn =
        build_conn()
        |> put_req_header("authorization", "Basic " <> app_encoded)
        |> post("/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => auth.token,
          "redirect_uri" => OAuthController.default_redirect_uri(app)
        })

      assert %{"access_token" => token, "scope" => scope} = json_response(conn, 200)

      assert scope == "scope1 scope2"

      token = Repo.get_by(Token, token: token)
      assert token
      assert token.scopes == ["scope1", "scope2"]
    end

    test "issue a token for client_credentials grant type" do
      app = insert(:oauth_app, scopes: ["read", "write"])

      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "client_credentials",
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert %{"access_token" => token, "refresh_token" => refresh, "scope" => scope} =
               json_response(conn, 200)

      assert token
      token_from_db = Repo.get_by(Token, token: token)
      assert token_from_db
      assert refresh
      assert scope == "read write"
    end

    test "rejects token exchange with invalid client credentials" do
      user = insert(:user)
      app = insert(:oauth_app)

      {:ok, auth} = Authorization.create_authorization(app, user)

      conn =
        build_conn()
        |> put_req_header("authorization", "Basic JTIxOiVGMCU5RiVBNCVCNwo=")
        |> post("/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => auth.token,
          "redirect_uri" => OAuthController.default_redirect_uri(app)
        })

      assert resp = json_response(conn, 400)
      assert %{"error" => _} = resp
      refute Map.has_key?(resp, "access_token")
    end

    test "rejects token exchange for valid credentials belonging to unconfirmed user and confirmation is required" do
      Pleroma.Config.put([:instance, :account_activation_required], true)
      password = "testpassword"

      {:ok, user} =
        insert(:user, password_hash: Comeonin.Pbkdf2.hashpwsalt(password))
        |> User.confirmation_changeset(need_confirmation: true)
        |> User.update_and_set_cache()

      refute Pleroma.User.auth_active?(user)

      app = insert(:oauth_app)

      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert resp = json_response(conn, 403)
      assert %{"error" => _} = resp
      refute Map.has_key?(resp, "access_token")
    end

    test "rejects token exchange for valid credentials belonging to deactivated user" do
      password = "testpassword"

      user =
        insert(:user,
          password_hash: Comeonin.Pbkdf2.hashpwsalt(password),
          deactivated: true
        )

      app = insert(:oauth_app)

      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert resp = json_response(conn, 403)
      assert %{"error" => _} = resp
      refute Map.has_key?(resp, "access_token")
    end

    test "rejects token exchange for user with password_reset_pending set to true" do
      password = "testpassword"

      user =
        insert(:user,
          password_hash: Comeonin.Pbkdf2.hashpwsalt(password),
          password_reset_pending: true
        )

      app = insert(:oauth_app, scopes: ["read", "write"])

      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "password",
          "username" => user.nickname,
          "password" => password,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert resp = json_response(conn, 403)

      assert resp["error"] == "Password reset is required"
      assert resp["identifier"] == "password_reset_required"
      refute Map.has_key?(resp, "access_token")
    end

    test "rejects an invalid authorization code" do
      app = insert(:oauth_app)

      conn =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "authorization_code",
          "code" => "Imobviouslyinvalid",
          "redirect_uri" => OAuthController.default_redirect_uri(app),
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })

      assert resp = json_response(conn, 400)
      assert %{"error" => _} = json_response(conn, 400)
      refute Map.has_key?(resp, "access_token")
    end
  end

  describe "POST /oauth/token - refresh token" do
    clear_config([:oauth2, :issue_new_refresh_token])

    test "issues a new access token with keep fresh token" do
      Pleroma.Config.put([:oauth2, :issue_new_refresh_token], true)
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])

      {:ok, auth} = Authorization.create_authorization(app, user, ["write"])
      {:ok, token} = Token.exchange_token(app, auth)

      response =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "refresh_token",
          "refresh_token" => token.refresh_token,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(200)

      ap_id = user.ap_id

      assert match?(
               %{
                 "scope" => "write",
                 "token_type" => "Bearer",
                 "expires_in" => 600,
                 "access_token" => _,
                 "refresh_token" => _,
                 "me" => ^ap_id
               },
               response
             )

      refute Repo.get_by(Token, token: token.token)
      new_token = Repo.get_by(Token, token: response["access_token"])
      assert new_token.refresh_token == token.refresh_token
      assert new_token.scopes == auth.scopes
      assert new_token.user_id == user.id
      assert new_token.app_id == app.id
    end

    test "issues a new access token with new fresh token" do
      Pleroma.Config.put([:oauth2, :issue_new_refresh_token], false)
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])

      {:ok, auth} = Authorization.create_authorization(app, user, ["write"])
      {:ok, token} = Token.exchange_token(app, auth)

      response =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "refresh_token",
          "refresh_token" => token.refresh_token,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(200)

      ap_id = user.ap_id

      assert match?(
               %{
                 "scope" => "write",
                 "token_type" => "Bearer",
                 "expires_in" => 600,
                 "access_token" => _,
                 "refresh_token" => _,
                 "me" => ^ap_id
               },
               response
             )

      refute Repo.get_by(Token, token: token.token)
      new_token = Repo.get_by(Token, token: response["access_token"])
      refute new_token.refresh_token == token.refresh_token
      assert new_token.scopes == auth.scopes
      assert new_token.user_id == user.id
      assert new_token.app_id == app.id
    end

    test "returns 400 if we try use access token" do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])

      {:ok, auth} = Authorization.create_authorization(app, user, ["write"])
      {:ok, token} = Token.exchange_token(app, auth)

      response =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "refresh_token",
          "refresh_token" => token.token,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(400)

      assert %{"error" => "Invalid credentials"} == response
    end

    test "returns 400 if refresh_token invalid" do
      app = insert(:oauth_app, scopes: ["read", "write"])

      response =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "refresh_token",
          "refresh_token" => "token.refresh_token",
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(400)

      assert %{"error" => "Invalid credentials"} == response
    end

    test "issues a new token if token expired" do
      user = insert(:user)
      app = insert(:oauth_app, scopes: ["read", "write"])

      {:ok, auth} = Authorization.create_authorization(app, user, ["write"])
      {:ok, token} = Token.exchange_token(app, auth)

      change =
        Ecto.Changeset.change(
          token,
          %{valid_until: NaiveDateTime.add(NaiveDateTime.utc_now(), -86_400 * 30)}
        )

      {:ok, access_token} = Repo.update(change)

      response =
        build_conn()
        |> post("/oauth/token", %{
          "grant_type" => "refresh_token",
          "refresh_token" => access_token.refresh_token,
          "client_id" => app.client_id,
          "client_secret" => app.client_secret
        })
        |> json_response(200)

      ap_id = user.ap_id

      assert match?(
               %{
                 "scope" => "write",
                 "token_type" => "Bearer",
                 "expires_in" => 600,
                 "access_token" => _,
                 "refresh_token" => _,
                 "me" => ^ap_id
               },
               response
             )

      refute Repo.get_by(Token, token: token.token)
      token = Repo.get_by(Token, token: response["access_token"])
      assert token
      assert token.scopes == auth.scopes
      assert token.user_id == user.id
      assert token.app_id == app.id
    end
  end

  describe "POST /oauth/token - bad request" do
    test "returns 500" do
      response =
        build_conn()
        |> post("/oauth/token", %{})
        |> json_response(500)

      assert %{"error" => "Bad request"} == response
    end
  end

  describe "POST /oauth/revoke - bad request" do
    test "returns 500" do
      response =
        build_conn()
        |> post("/oauth/revoke", %{})
        |> json_response(500)

      assert %{"error" => "Bad request"} == response
    end
  end
end
