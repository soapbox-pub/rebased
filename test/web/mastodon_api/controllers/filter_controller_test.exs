# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Web.MastodonAPI.FilterView

  test "creating a filter" do
    %{conn: conn} = oauth_access(["write:filters"])

    filter = %Pleroma.Filter{
      phrase: "knights",
      context: ["home"]
    }

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/filters", %{"phrase" => filter.phrase, context: filter.context})

    assert response = json_response_and_validate_schema(conn, 200)
    assert response["phrase"] == filter.phrase
    assert response["context"] == filter.context
    assert response["irreversible"] == false
    assert response["id"] != nil
    assert response["id"] != ""
  end

  test "fetching a list of filters" do
    %{user: user, conn: conn} = oauth_access(["read:filters"])

    query_one = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 1,
      phrase: "knights",
      context: ["home"]
    }

    query_two = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "who",
      context: ["home"]
    }

    {:ok, filter_one} = Pleroma.Filter.create(query_one)
    {:ok, filter_two} = Pleroma.Filter.create(query_two)

    response =
      conn
      |> get("/api/v1/filters")
      |> json_response_and_validate_schema(200)

    assert response ==
             render_json(
               FilterView,
               "index.json",
               filters: [filter_two, filter_one]
             )
  end

  test "get a filter" do
    %{user: user, conn: conn} = oauth_access(["read:filters"])

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "knight",
      context: ["home"]
    }

    {:ok, filter} = Pleroma.Filter.create(query)

    conn = get(conn, "/api/v1/filters/#{filter.filter_id}")

    assert response = json_response_and_validate_schema(conn, 200)
  end

  test "update a filter" do
    %{user: user, conn: conn} = oauth_access(["write:filters"])

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "knight",
      context: ["home"],
      hide: true
    }

    {:ok, _filter} = Pleroma.Filter.create(query)

    new = %Pleroma.Filter{
      phrase: "nii",
      context: ["home"]
    }

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put("/api/v1/filters/#{query.filter_id}", %{
        phrase: new.phrase,
        context: new.context
      })

    assert response = json_response_and_validate_schema(conn, 200)
    assert response["phrase"] == new.phrase
    assert response["context"] == new.context
    assert response["irreversible"] == true
  end

  test "delete a filter" do
    %{user: user, conn: conn} = oauth_access(["write:filters"])

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "knight",
      context: ["home"]
    }

    {:ok, filter} = Pleroma.Filter.create(query)

    conn = delete(conn, "/api/v1/filters/#{filter.filter_id}")

    assert json_response_and_validate_schema(conn, 200) == %{}
  end
end
