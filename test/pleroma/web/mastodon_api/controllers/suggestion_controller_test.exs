# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionControllerTest do
  use Pleroma.Web.ConnCase, async: true
  alias Pleroma.UserRelationship
  alias Pleroma.Web.CommonAPI
  import Pleroma.Factory

  setup do: oauth_access(["read", "write"])

  test "returns empty result", %{conn: conn} do
    res =
      conn
      |> get("/api/v1/suggestions")
      |> json_response_and_validate_schema(200)

    assert res == []
  end

  test "returns v2 suggestions", %{conn: conn} do
    %{id: user_id} = insert(:user, is_suggested: true)

    res =
      conn
      |> get("/api/v2/suggestions")
      |> json_response_and_validate_schema(200)

    assert [%{"source" => "staff", "account" => %{"id" => ^user_id}}] = res
  end

  test "returns v2 suggestions excluding dismissed accounts", %{conn: conn} do
    %{id: user_id} = insert(:user, is_suggested: true)

    conn
    |> delete("/api/v1/suggestions/#{user_id}")
    |> json_response_and_validate_schema(200)

    res =
      conn
      |> get("/api/v2/suggestions")
      |> json_response_and_validate_schema(200)

    assert [] = res
  end

  test "returns v2 suggestions excluding blocked accounts", %{conn: conn, user: blocker} do
    blocked = insert(:user, is_suggested: true)
    {:ok, _} = CommonAPI.block(blocker, blocked)

    res =
      conn
      |> get("/api/v2/suggestions")
      |> json_response_and_validate_schema(200)

    assert [] = res
  end

  test "returns v2 suggestions excluding followed accounts", %{conn: conn, user: follower} do
    followed = insert(:user, is_suggested: true)
    {:ok, _, _, _} = CommonAPI.follow(follower, followed)

    res =
      conn
      |> get("/api/v2/suggestions")
      |> json_response_and_validate_schema(200)

    assert [] = res
  end

  test "dismiss suggestion", %{conn: conn, user: source} do
    target = insert(:user, is_suggested: true)

    res =
      conn
      |> delete("/api/v1/suggestions/#{target.id}")
      |> json_response_and_validate_schema(200)

    assert res == %{}
    assert UserRelationship.exists?(:suggestion_dismiss, source, target)
  end
end
