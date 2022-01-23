# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AppControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.Push

  import Pleroma.Factory

  test "apps", %{conn: conn} do
    user = insert(:user)
    app_attrs = build(:oauth_app)

    creation =
      conn
      |> put_req_header("content-type", "application/json")
      |> assign(:user, user)
      |> post("/api/v1/apps", %{
        client_name: app_attrs.client_name,
        redirect_uris: app_attrs.redirect_uris
      })

    [app] = App.get_user_apps(user)

    expected = %{
      "name" => app.client_name,
      "website" => app.website,
      "client_id" => app.client_id,
      "client_secret" => app.client_secret,
      "id" => app.id |> to_string(),
      "redirect_uri" => app.redirect_uris,
      "vapid_key" => Push.vapid_config() |> Keyword.get(:public_key)
    }

    assert expected == json_response_and_validate_schema(creation, 200)

    response =
      conn
      |> put_req_header("content-type", "application/json")
      |> assign(:user, user)
      |> assign(:token, insert(:oauth_token, user: user, scopes: ["read", "follow"]))
      |> get("/api/v1/pleroma/apps")
      |> json_response_and_validate_schema(200)

    [apps] = response

    assert length(response) == 1
    assert apps["client_id"] == app.client_id
  end
end
