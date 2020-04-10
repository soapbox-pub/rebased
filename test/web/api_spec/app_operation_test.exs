# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ApiSpec.AppOperationTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.ApiSpec
  alias Pleroma.Web.ApiSpec.Schemas.AppCreateRequest
  alias Pleroma.Web.ApiSpec.Schemas.AppCreateResponse

  import OpenApiSpex.TestAssertions
  import Pleroma.Factory

  test "AppCreateRequest example matches schema" do
    api_spec = ApiSpec.spec()
    schema = AppCreateRequest.schema()
    assert_schema(schema.example, "AppCreateRequest", api_spec)
  end

  test "AppCreateResponse example matches schema" do
    api_spec = ApiSpec.spec()
    schema = AppCreateResponse.schema()
    assert_schema(schema.example, "AppCreateResponse", api_spec)
  end

  test "AppController produces a AppCreateResponse", %{conn: conn} do
    api_spec = ApiSpec.spec()
    app_attrs = build(:oauth_app)

    json =
      conn
      |> put_req_header("content-type", "application/json")
      |> post(
        "/api/v1/apps",
        Jason.encode!(%{
          client_name: app_attrs.client_name,
          redirect_uris: app_attrs.redirect_uris
        })
      )
      |> json_response(200)

    assert_schema(json, "AppCreateResponse", api_spec)
  end
end
