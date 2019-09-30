# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Web.MastodonAPI.FilterView

  import Pleroma.Factory

  test "creating a filter", %{conn: conn} do
    user = insert(:user)

    filter = %Pleroma.Filter{
      phrase: "knights",
      context: ["home"]
    }

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/filters", %{"phrase" => filter.phrase, context: filter.context})

    assert response = json_response(conn, 200)
    assert response["phrase"] == filter.phrase
    assert response["context"] == filter.context
    assert response["irreversible"] == false
    assert response["id"] != nil
    assert response["id"] != ""
  end

  test "fetching a list of filters", %{conn: conn} do
    user = insert(:user)

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
      |> assign(:user, user)
      |> get("/api/v1/filters")
      |> json_response(200)

    assert response ==
             render_json(
               FilterView,
               "filters.json",
               filters: [filter_two, filter_one]
             )
  end

  test "get a filter", %{conn: conn} do
    user = insert(:user)

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "knight",
      context: ["home"]
    }

    {:ok, filter} = Pleroma.Filter.create(query)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/filters/#{filter.filter_id}")

    assert _response = json_response(conn, 200)
  end

  test "update a filter", %{conn: conn} do
    user = insert(:user)

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "knight",
      context: ["home"]
    }

    {:ok, _filter} = Pleroma.Filter.create(query)

    new = %Pleroma.Filter{
      phrase: "nii",
      context: ["home"]
    }

    conn =
      conn
      |> assign(:user, user)
      |> put("/api/v1/filters/#{query.filter_id}", %{
        phrase: new.phrase,
        context: new.context
      })

    assert response = json_response(conn, 200)
    assert response["phrase"] == new.phrase
    assert response["context"] == new.context
  end

  test "delete a filter", %{conn: conn} do
    user = insert(:user)

    query = %Pleroma.Filter{
      user_id: user.id,
      filter_id: 2,
      phrase: "knight",
      context: ["home"]
    }

    {:ok, filter} = Pleroma.Filter.create(query)

    conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/filters/#{filter.filter_id}")

    assert response = json_response(conn, 200)
    assert response == %{}
  end
end
