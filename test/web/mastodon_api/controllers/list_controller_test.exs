# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ListControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Repo

  import Pleroma.Factory

  test "creating a list", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/lists", %{"title" => "cuties"})

    assert %{"title" => title} = json_response(conn, 200)
    assert title == "cuties"
  end

  test "renders error for invalid params", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/lists", %{"title" => nil})

    assert %{"error" => "can't be blank"} == json_response(conn, :unprocessable_entity)
  end

  test "listing a user's lists", %{conn: conn} do
    user = insert(:user)

    conn
    |> assign(:user, user)
    |> post("/api/v1/lists", %{"title" => "cuties"})

    conn
    |> assign(:user, user)
    |> post("/api/v1/lists", %{"title" => "cofe"})

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/lists")

    assert [
             %{"id" => _, "title" => "cofe"},
             %{"id" => _, "title" => "cuties"}
           ] = json_response(conn, :ok)
  end

  test "adding users to a list", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)

    conn =
      conn
      |> assign(:user, user)
      |> post("/api/v1/lists/#{list.id}/accounts", %{"account_ids" => [other_user.id]})

    assert %{} == json_response(conn, 200)
    %Pleroma.List{following: following} = Pleroma.List.get(list.id, user)
    assert following == [other_user.follower_address]
  end

  test "removing users from a list", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)
    third_user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)
    {:ok, list} = Pleroma.List.follow(list, other_user)
    {:ok, list} = Pleroma.List.follow(list, third_user)

    conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/lists/#{list.id}/accounts", %{"account_ids" => [other_user.id]})

    assert %{} == json_response(conn, 200)
    %Pleroma.List{following: following} = Pleroma.List.get(list.id, user)
    assert following == [third_user.follower_address]
  end

  test "listing users in a list", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)
    {:ok, list} = Pleroma.List.follow(list, other_user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/lists/#{list.id}/accounts", %{"account_ids" => [other_user.id]})

    assert [%{"id" => id}] = json_response(conn, 200)
    assert id == to_string(other_user.id)
  end

  test "retrieving a list", %{conn: conn} do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/lists/#{list.id}")

    assert %{"id" => id} = json_response(conn, 200)
    assert id == to_string(list.id)
  end

  test "renders 404 if list is not found", %{conn: conn} do
    user = insert(:user)

    conn =
      conn
      |> assign(:user, user)
      |> get("/api/v1/lists/666")

    assert %{"error" => "List not found"} = json_response(conn, :not_found)
  end

  test "renaming a list", %{conn: conn} do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)

    conn =
      conn
      |> assign(:user, user)
      |> put("/api/v1/lists/#{list.id}", %{"title" => "newname"})

    assert %{"title" => name} = json_response(conn, 200)
    assert name == "newname"
  end

  test "validates title when renaming a list", %{conn: conn} do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)

    conn =
      conn
      |> assign(:user, user)
      |> put("/api/v1/lists/#{list.id}", %{"title" => "  "})

    assert %{"error" => "can't be blank"} == json_response(conn, :unprocessable_entity)
  end

  test "deleting a list", %{conn: conn} do
    user = insert(:user)
    {:ok, list} = Pleroma.List.create("name", user)

    conn =
      conn
      |> assign(:user, user)
      |> delete("/api/v1/lists/#{list.id}")

    assert %{} = json_response(conn, 200)
    assert is_nil(Repo.get(Pleroma.List, list.id))
  end
end
