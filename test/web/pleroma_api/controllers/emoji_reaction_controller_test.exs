# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiReactionControllerTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "PUT /api/v1/pleroma/statuses/:id/reactions/:emoji", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})

    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> put("/api/v1/pleroma/statuses/#{activity.id}/reactions/☕")
      |> json_response_and_validate_schema(200)

    # We return the status, but this our implementation detail.
    assert %{"id" => id} = result
    assert to_string(activity.id) == id

    assert result["pleroma"]["emoji_reactions"] == [
             %{"name" => "☕", "count" => 1, "me" => true}
           ]
  end

  test "DELETE /api/v1/pleroma/statuses/:id/reactions/:emoji", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})
    {:ok, _reaction_activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

    ObanHelpers.perform_all()

    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> delete("/api/v1/pleroma/statuses/#{activity.id}/reactions/☕")

    assert %{"id" => id} = json_response_and_validate_schema(result, 200)
    assert to_string(activity.id) == id

    ObanHelpers.perform_all()

    object = Object.get_by_ap_id(activity.data["object"])

    assert object.data["reaction_count"] == 0
  end

  test "GET /api/v1/pleroma/statuses/:id/reactions", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)
    doomed_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})

    result =
      conn
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    assert result == []

    {:ok, _} = CommonAPI.react_with_emoji(activity.id, other_user, "🎅")
    {:ok, _} = CommonAPI.react_with_emoji(activity.id, doomed_user, "🎅")

    User.perform(:delete, doomed_user)

    result =
      conn
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    [%{"name" => "🎅", "count" => 1, "accounts" => [represented_user], "me" => false}] = result

    assert represented_user["id"] == other_user.id

    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["read:statuses"]))
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    assert [%{"name" => "🎅", "count" => 1, "accounts" => [_represented_user], "me" => true}] =
             result
  end

  test "GET /api/v1/pleroma/statuses/:id/reactions/:emoji", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})

    result =
      conn
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions/🎅")
      |> json_response_and_validate_schema(200)

    assert result == []

    {:ok, _} = CommonAPI.react_with_emoji(activity.id, other_user, "🎅")
    {:ok, _} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")

    assert [%{"name" => "🎅", "count" => 1, "accounts" => [represented_user], "me" => false}] =
             conn
             |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions/🎅")
             |> json_response_and_validate_schema(200)

    assert represented_user["id"] == other_user.id
  end
end
