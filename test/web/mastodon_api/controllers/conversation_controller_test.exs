# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ConversationControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "Conversations", %{conn: conn} do
    user_one = insert(:user)
    user_two = insert(:user)
    user_three = insert(:user)

    {:ok, user_two} = User.follow(user_two, user_one)

    {:ok, direct} =
      CommonAPI.post(user_one, %{
        "status" => "Hi @#{user_two.nickname}, @#{user_three.nickname}!",
        "visibility" => "direct"
      })

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
    assert unread == true
    assert res_last_status["id"] == direct.id

    # Apparently undocumented API endpoint
    res_conn =
      conn
      |> assign(:user, user_one)
      |> post("/api/v1/conversations/#{res_id}/read")

    assert response = json_response(res_conn, 200)
    assert length(response["accounts"]) == 2
    assert response["last_status"]["id"] == direct.id
    assert response["unread"] == false

    # (vanilla) Mastodon frontend behaviour
    res_conn =
      conn
      |> assign(:user, user_one)
      |> get("/api/v1/statuses/#{res_last_status["id"]}/context")

    assert %{"ancestors" => [], "descendants" => []} == json_response(res_conn, 200)
  end
end
