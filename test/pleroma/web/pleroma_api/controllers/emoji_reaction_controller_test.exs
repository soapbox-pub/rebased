# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EmojiReactionControllerTest do
  use Oban.Testing, repo: Pleroma.Repo
  use Pleroma.Web.ConnCase

  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup do
    Mox.stub_with(Pleroma.UnstubbedConfigMock, Pleroma.Config)
    :ok
  end

  test "PUT /api/v1/pleroma/statuses/:id/reactions/:emoji", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    note = insert(:note, user: user, data: %{"reactions" => [["👍", [other_user.ap_id], nil]]})
    activity = insert(:note_activity, note: note, user: user)

    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> put("/api/v1/pleroma/statuses/#{activity.id}/reactions/\u26A0")
      |> json_response_and_validate_schema(200)

    assert %{"id" => id} = result
    assert to_string(activity.id) == id

    assert result["pleroma"]["emoji_reactions"] == [
             %{
               "name" => "👍",
               "count" => 1,
               "me" => true,
               "url" => nil,
               "account_ids" => [other_user.id]
             },
             %{
               "name" => "\u26A0\uFE0F",
               "count" => 1,
               "me" => true,
               "url" => nil,
               "account_ids" => [other_user.id]
             }
           ]

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})

    ObanHelpers.perform_all()

    # Reacting with a custom emoji
    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> put("/api/v1/pleroma/statuses/#{activity.id}/reactions/:dinosaur:")
      |> json_response_and_validate_schema(200)

    assert %{"id" => id} = result
    assert to_string(activity.id) == id

    assert result["pleroma"]["emoji_reactions"] == [
             %{
               "name" => "dinosaur",
               "count" => 1,
               "me" => true,
               "url" => "http://localhost:4001/emoji/dino walking.gif",
               "account_ids" => [other_user.id]
             }
           ]

    # Reacting with a remote emoji
    note =
      insert(:note,
        user: user,
        data: %{
          "reactions" => [
            ["👍", [other_user.ap_id], nil],
            ["wow", [other_user.ap_id], "https://remote/emoji/wow"]
          ]
        }
      )

    activity = insert(:note_activity, note: note, user: user)

    result =
      conn
      |> assign(:user, user)
      |> assign(:token, insert(:oauth_token, user: user, scopes: ["write:statuses"]))
      |> put("/api/v1/pleroma/statuses/#{activity.id}/reactions/:wow@remote:")
      |> json_response(200)

    assert result["pleroma"]["emoji_reactions"] == [
             %{
               "account_ids" => [other_user.id],
               "count" => 1,
               "me" => false,
               "name" => "👍",
               "url" => nil
             },
             %{
               "name" => "wow@remote",
               "count" => 2,
               "me" => true,
               "url" => "https://remote/emoji/wow",
               "account_ids" => [user.id, other_user.id]
             }
           ]

    # Reacting with a remote custom emoji that hasn't been reacted with yet
    note =
      insert(:note,
        user: user
      )

    activity = insert(:note_activity, note: note, user: user)

    assert conn
           |> assign(:user, user)
           |> assign(:token, insert(:oauth_token, user: user, scopes: ["write:statuses"]))
           |> put("/api/v1/pleroma/statuses/#{activity.id}/reactions/:wow@remote:")
           |> json_response(400)

    # Reacting with a non-emoji
    assert conn
           |> assign(:user, other_user)
           |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
           |> put("/api/v1/pleroma/statuses/#{activity.id}/reactions/x")
           |> json_response_and_validate_schema(400)
  end

  test "DELETE /api/v1/pleroma/statuses/:id/reactions/:emoji", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    note =
      insert(:note,
        user: user,
        data: %{"reactions" => [["wow", [user.ap_id], "https://remote/emoji/wow"]]}
      )

    activity = insert(:note_activity, note: note, user: user)

    ObanHelpers.perform_all()

    {:ok, _reaction_activity} = CommonAPI.react_with_emoji(activity.id, other_user, "☕")
    {:ok, _reaction_activity} = CommonAPI.react_with_emoji(activity.id, other_user, ":dinosaur:")

    {:ok, _reaction_activity} =
      CommonAPI.react_with_emoji(activity.id, other_user, ":wow@remote:")

    ObanHelpers.perform_all()

    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> delete("/api/v1/pleroma/statuses/#{activity.id}/reactions/☕")

    assert %{"id" => id} = json_response_and_validate_schema(result, 200)
    assert to_string(activity.id) == id

    # Remove custom emoji

    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> delete("/api/v1/pleroma/statuses/#{activity.id}/reactions/:dinosaur:")

    assert %{"id" => id} = json_response_and_validate_schema(result, 200)
    assert to_string(activity.id) == id

    ObanHelpers.perform_all()

    object = Object.get_by_ap_id(activity.data["object"])

    assert object.data["reaction_count"] == 2

    # Remove custom remote emoji
    result =
      conn
      |> assign(:user, other_user)
      |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
      |> delete("/api/v1/pleroma/statuses/#{activity.id}/reactions/:wow@remote:")
      |> json_response(200)

    assert result["pleroma"]["emoji_reactions"] == [
             %{
               "name" => "wow@remote",
               "count" => 1,
               "me" => false,
               "url" => "https://remote/emoji/wow",
               "account_ids" => [user.id]
             }
           ]

    # Remove custom remote emoji that hasn't been reacted with yet
    assert conn
           |> assign(:user, other_user)
           |> assign(:token, insert(:oauth_token, user: other_user, scopes: ["write:statuses"]))
           |> delete("/api/v1/pleroma/statuses/#{activity.id}/reactions/:zoop@remote:")
           |> json_response(400)
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

  test "GET /api/v1/pleroma/statuses/:id/reactions with legacy format", %{conn: conn} do
    user = insert(:user)
    other_user = insert(:user)

    note =
      insert(:note,
        user: user,
        data: %{
          "reactions" => [["😿", [other_user.ap_id]]]
        }
      )

    activity = insert(:note_activity, user: user, note: note)

    result =
      conn
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    other_user_id = other_user.id

    assert [
             %{
               "name" => "😿",
               "count" => 1,
               "me" => false,
               "url" => nil,
               "accounts" => [%{"id" => ^other_user_id}]
             }
           ] = result
  end

  test "GET /api/v1/pleroma/statuses/:id/reactions?with_muted=true", %{conn: conn} do
    user = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)

    token = insert(:oauth_token, user: user, scopes: ["read:statuses"])

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})

    {:ok, _} = CommonAPI.react_with_emoji(activity.id, user2, "🎅")
    {:ok, _} = CommonAPI.react_with_emoji(activity.id, user3, "🎅")

    result =
      conn
      |> assign(:user, user)
      |> assign(:token, token)
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    assert [%{"name" => "🎅", "count" => 2}] = result

    User.mute(user, user3)

    result =
      conn
      |> assign(:user, user)
      |> assign(:token, token)
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    assert [%{"name" => "🎅", "count" => 1}] = result

    result =
      conn
      |> assign(:user, user)
      |> assign(:token, token)
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions?with_muted=true")
      |> json_response_and_validate_schema(200)

    assert [%{"name" => "🎅", "count" => 2}] = result
  end

  test "GET /api/v1/pleroma/statuses/:id/reactions with :show_reactions disabled", %{conn: conn} do
    clear_config([:instance, :show_reactions], false)

    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "#cofe"})
    {:ok, _} = CommonAPI.react_with_emoji(activity.id, other_user, "🎅")

    result =
      conn
      |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions")
      |> json_response_and_validate_schema(200)

    assert result == []
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

    assert [
             %{
               "name" => "🎅",
               "count" => 1,
               "accounts" => [represented_user],
               "me" => false,
               "url" => nil
             }
           ] =
             conn
             |> get("/api/v1/pleroma/statuses/#{activity.id}/reactions/🎅")
             |> json_response_and_validate_schema(200)

    assert represented_user["id"] == other_user.id
  end
end
