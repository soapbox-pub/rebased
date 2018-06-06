defmodule Pleroma.Web.OAuth.OAuthControllerTest do
  use Pleroma.Web.ConnCase
  import Pleroma.Factory

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.{Authorization, Token}

  test "redirects with oauth authorization" do
    user = insert(:user)
    app = insert(:oauth_app)

    conn =
      build_conn()
      |> post("/oauth/authorize", %{
        "authorization" => %{
          "name" => user.nickname,
          "password" => "test",
          "client_id" => app.client_id,
          "redirect_uri" => app.redirect_uris,
          "state" => "statepassed"
        }
      })

    target = redirected_to(conn)
    assert target =~ app.redirect_uris

    query = URI.parse(target).query |> URI.query_decoder() |> Map.new()

    assert %{"state" => "statepassed", "code" => code} = query
    assert Repo.get_by(Authorization, token: code)
  end

  test "issues a token for an all-body request" do
    user = insert(:user)
    app = insert(:oauth_app)

    {:ok, auth} = Authorization.create_authorization(app, user)

    conn =
      build_conn()
      |> post("/oauth/token", %{
        "grant_type" => "authorization_code",
        "code" => auth.token,
        "redirect_uri" => app.redirect_uris,
        "client_id" => app.client_id,
        "client_secret" => app.client_secret
      })

    assert %{"access_token" => token} = json_response(conn, 200)
    assert Repo.get_by(Token, token: token)
  end

  test "issues a token for request with HTTP basic auth client credentials" do
    user = insert(:user)
    app = insert(:oauth_app)

    {:ok, auth} = Authorization.create_authorization(app, user)

    app_encoded =
      (URI.encode_www_form(app.client_id) <> ":" <> URI.encode_www_form(app.client_secret))
      |> Base.encode64()

    conn =
      build_conn()
      |> put_req_header("authorization", "Basic " <> app_encoded)
      |> post("/oauth/token", %{
        "grant_type" => "authorization_code",
        "code" => auth.token,
        "redirect_uri" => app.redirect_uris
      })

    assert %{"access_token" => token} = json_response(conn, 200)
    assert Repo.get_by(Token, token: token)
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
        "redirect_uri" => app.redirect_uris
      })

    assert resp = json_response(conn, 400)
    assert %{"error" => _} = resp
    refute Map.has_key?(resp, "access_token")
  end

  test "rejects an invalid authorization code" do
    app = insert(:oauth_app)

    conn =
      build_conn()
      |> post("/oauth/token", %{
        "grant_type" => "authorization_code",
        "code" => "Imobviouslyinvalid",
        "redirect_uri" => app.redirect_uris,
        "client_id" => app.client_id,
        "client_secret" => app.client_secret
      })

    assert resp = json_response(conn, 400)
    assert %{"error" => _} = json_response(conn, 400)
    refute Map.has_key?(resp, "access_token")
  end
end
