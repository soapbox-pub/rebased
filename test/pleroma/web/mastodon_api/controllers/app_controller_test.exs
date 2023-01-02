# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.AppControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Repo
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.Push

  import Pleroma.Factory

  test "apps/verify_credentials", %{conn: conn} do
    user_bound_token = insert(:oauth_token)
    app_bound_token = insert(:oauth_token, user: nil)
    refute app_bound_token.user

    for token <- [app_bound_token, user_bound_token] do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token.token}")
        |> get("/api/v1/apps/verify_credentials")

      app = Repo.preload(token, :app).app

      expected = %{
        "name" => app.client_name,
        "website" => app.website,
        "vapid_key" => Push.vapid_config() |> Keyword.get(:public_key)
      }

      assert expected == json_response_and_validate_schema(conn, 200)
    end
  end

  test "creates an oauth app", %{conn: conn} do
    app_attrs = build(:oauth_app)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/apps", %{
        client_name: app_attrs.client_name,
        redirect_uris: app_attrs.redirect_uris
      })

    [app] = Repo.all(App)

    expected = %{
      "name" => app.client_name,
      "website" => app.website,
      "client_id" => app.client_id,
      "client_secret" => app.client_secret,
      "id" => app.id |> to_string(),
      "redirect_uri" => app.redirect_uris,
      "vapid_key" => Push.vapid_config() |> Keyword.get(:public_key)
    }

    assert expected == json_response_and_validate_schema(conn, 200)
    assert app.user_id == nil
  end

  test "creates an oauth app with a user", %{conn: conn} do
    user = insert(:user)
    app_attrs = build(:oauth_app)

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> assign(:user, user)
      |> post("/api/v1/apps", %{
        client_name: app_attrs.client_name,
        redirect_uris: app_attrs.redirect_uris
      })

    [app] = Repo.all(App)

    expected = %{
      "name" => app.client_name,
      "website" => app.website,
      "client_id" => app.client_id,
      "client_secret" => app.client_secret,
      "id" => app.id |> to_string(),
      "redirect_uri" => app.redirect_uris,
      "vapid_key" => Push.vapid_config() |> Keyword.get(:public_key)
    }

    assert expected == json_response_and_validate_schema(conn, 200)
    assert app.user_id == user.id
  end
end
