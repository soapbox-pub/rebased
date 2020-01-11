# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  setup do: oauth_access(["read:statuses"])

  test "returns a list of conversations", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    user_three = insert(:user)

    {:ok, user_two} = User.follow(user_two, user_one)

    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 0

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}, @#{user_three.nickname}!",
        "visibility" => "direct"
      })

    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 1

    {:ok, _follower_only} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "private"
      })

    res_conn = get(conn, "/api/v1/conversations")

    assert response = json_response(res_conn, 200)

    assert [
             %{
               "id" => res_id,
               "accounts" => res_accounts,
               "last_status" => res_last_status,
               "unread" => unread
             }
           ] = response

    account_ids = Enum.map(res_accounts, & &1["id"])
    assert length(res_accounts) == 2
    assert user_two.id in account_ids
    assert user_three.id in account_ids
    assert is_binary(res_id)
    assert unread == false
    assert res_last_status["id"] == direct.id
    assert User.get_cached_by_id(user_one.id).unread_conversation_count == 0
  end

  test "filters conversations by recipients", %{user: user_one, conn: conn} do
    user_two = insert(:user)
    user_three = insert(:user)

    {:ok, direct1} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "direct"
      })

    {:ok, _direct2} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_three.nickname}!",
        "visibility" => "direct"
      })

    {:ok, direct3} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}, @#{user_three.nickname}!",
        "visibility" => "direct"
      })

    {:ok, _direct4} =
      CommonAPI.post(user_two, %{
        "status" => "Hi @#{user_three.nickname}!",
        "visibility" => "direct"
      })

    {:ok, direct5} =
      CommonAPI.post(user_two, %{
        "status" => "Hi @#{user_one.nickname}!",
        "visibility" => "direct"
      })

    [conversation1, conversation2] =
      conn
      |> get("/api/v1/conversations", %{"recipients" => [user_two.id]})
      |> json_response(200)

    assert conversation1["last_status"]["id"] == direct5.id
    assert conversation2["last_status"]["id"] == direct1.id

    [conversation1] =
      conn
      |> get("/api/v1/conversations", %{"recipients" => [user_two.id, user_three.id]})
      |> json_response(200)

    assert conversation1["last_status"]["id"] == direct3.id
  end

  test "updates the last_status on reply", %{user: user_one, conn: conn} do
    user_two = insert(:user)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}",
        "visibility" => "direct"
      })

    {:ok, direct_reply} =
      CommonAPI.post(user_two, %{
        "status" => "reply",
        "visibility" => "direct",
        "in_reply_to_status_id" => direct.id
      })

    [%{"last_status" => res_last_status}] =
      conn
      |> get("/api/v1/conversations")
      |> json_response(200)

    assert res_last_status["id"] == direct_reply.id
  end

  test "the user marks a conversation as read", %{user: user_one, conn: conn} do
    user_two = insert(:user)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}",
        "visibility" => "direct"
      })

    assert User.get_cached_by_id(user_one.id).unread_conversation_count == 0
    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 1

    user_two_conn =
      build_conn()
      |> assign(:user, user_two)
      |> assign(
        :token,
        insert(:oauth_token, user: user_two, scopes: ["read:statuses", "write:conversations"])
      )

    [%{"id" => direct_conversation_id, "unread" => true}] =
      user_two_conn
      |> get("/api/v1/conversations")
      |> json_response(200)

    %{"unread" => false} =
      user_two_conn
      |> post("/api/v1/conversations/#{direct_conversation_id}/read")
      |> json_response(200)

    assert User.get_cached_by_id(user_one.id).unread_conversation_count == 0
    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 0

    # The conversation is marked as unread on reply
    {:ok, _} =
      CommonAPI.post(user_two, %{
        "status" => "reply",
        "visibility" => "direct",
        "in_reply_to_status_id" => direct.id
      })

    [%{"unread" => true}] =
      conn
      |> get("/api/v1/conversations")
      |> json_response(200)

    assert User.get_cached_by_id(user_one.id).unread_conversation_count == 1
    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 0

    # A reply doesn't increment the user's unread_conversation_count if the conversation is unread
    {:ok, _} =
      CommonAPI.post(user_two, %{
        "status" => "reply",
        "visibility" => "direct",
        "in_reply_to_status_id" => direct.id
      })

    assert User.get_cached_by_id(user_one.id).unread_conversation_count == 1
    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 0
  end

  test "(vanilla) Mastodon frontend behaviour", %{user: user_one, conn: conn} do
    user_two = insert(:user)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "direct"
      })

    res_conn = get(conn, "/api/v1/statuses/#{direct.id}/context")

    assert %{"ancestors" => [], "descendants" => []} == json_response(res_conn, 200)
  end
end
