# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "returns a list of conversations", %{conn: conn} do
    user_one = insert(:user)
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

    res_conn =
      conn
      |> assign(:user, user_one)
      |> get("/api/v1/conversations")

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

  test "updates the last_status on reply", %{conn: conn} do
    user_one = insert(:user)
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
      |> assign(:user, user_one)
      |> get("/api/v1/conversations")
      |> json_response(200)

    assert res_last_status["id"] == direct_reply.id
  end

  test "the user marks a conversation as read", %{conn: conn} do
    user_one = insert(:user)
    user_two = insert(:user)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}",
        "visibility" => "direct"
      })

    assert User.get_cached_by_id(user_one.id).unread_conversation_count == 0
    assert User.get_cached_by_id(user_two.id).unread_conversation_count == 1

    [%{"id" => direct_conversation_id, "unread" => true}] =
      conn
      |> assign(:user, user_two)
      |> get("/api/v1/conversations")
      |> json_response(200)

    %{"unread" => false} =
      conn
      |> assign(:user, user_two)
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
      |> assign(:user, user_one)
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

  test "(vanilla) Mastodon frontend behaviour", %{conn: conn} do
    user_one = insert(:user)
    user_two = insert(:user)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}!",
        "visibility" => "direct"
      })

    res_conn =
      conn
      |> assign(:user, user_one)
      |> get("/api/v1/statuses/#{direct.id}/context")

    assert %{"ancestors" => [], "descendants" => []} == json_response(res_conn, 200)
  end
end
