# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.SearchControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  import Pleroma.Factory

  test "GET /api/v1/pleroma/search/location" do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    user = insert(:user)
    %{conn: conn} = oauth_access([], user: user)

    conn =
      conn
      |> get("/api/v1/pleroma/search/location?q=Benis")

    assert [result | _] = json_response_and_validate_schema(conn, 200)

    assert result == %{
             "country" => "Iran",
             "description" => "Benis",
             "geom" => %{"coordinates" => [45.7285348, 38.212263], "srid" => 4326},
             "locality" => "بخش مرکزی",
             "origin_id" => "3726208425",
             "origin_provider" => "nominatim",
             "postal_code" => nil,
             "region" => "East Azerbaijan Province",
             "street" => " ",
             "timezone" => nil,
             "type" => "city",
             "url" => nil
           }
  end
end
