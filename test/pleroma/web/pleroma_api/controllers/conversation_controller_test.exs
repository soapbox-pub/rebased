# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ConversationControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Conversation.Participation
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "/api/v1/pleroma/conversations/:id" do
    user = insert(:user)
    %{user: other_user, conn: conn} = oauth_access(["read:statuses"])

    {:ok, _activity} =
      CommonAPI.post(user, %{status: "Hi @#{other_user.nickname}!", visibility: "direct"})

    [participation] = Participation.for_user(other_user)

    result =
      conn
      |> get("/api/v1/pleroma/conversations/#{participation.id}")
      |> json_response_and_validate_schema(200)

    assert result["id"] == participation.id |> to_string()
  end

  test "/api/v1/pleroma/conversations/:id/statuses" do
    user = insert(:user)
    %{user: other_user, conn: conn} = oauth_access(["read:statuses"])
    third_user = insert(:user)

    {:ok, _activity} =
      CommonAPI.post(user, %{status: "Hi @#{third_user.nickname}!", visibility: "direct"})

    {:ok, activity} =
      CommonAPI.post(user, %{status: "Hi @#{other_user.nickname}!", visibility: "direct"})

    [participation] = Participation.for_user(other_user)

    {:ok, activity_two} =
      CommonAPI.post(other_user, %{
        status: "Hi!",
        in_reply_to_status_id: activity.id,
        in_reply_to_conversation_id: participation.id
      })

    result =
      conn
      |> get("/api/v1/pleroma/conversations/#{participation.id}/statuses")
      |> json_response_and_validate_schema(200)

    assert length(result) == 2

    id_one = activity.id
    id_two = activity_two.id
    assert [%{"id" => ^id_one}, %{"id" => ^id_two}] = result

    {:ok, %{id: id_three}} =
      CommonAPI.post(other_user, %{
        status: "Bye!",
        in_reply_to_status_id: activity.id,
        in_reply_to_conversation_id: participation.id
      })

    assert [%{"id" => ^id_two}, %{"id" => ^id_three}] =
             conn
             |> get("/api/v1/pleroma/conversations/#{participation.id}/statuses?limit=2")
             |> json_response_and_validate_schema(:ok)

    assert [%{"id" => ^id_three}] =
             conn
             |> get("/api/v1/pleroma/conversations/#{participation.id}/statuses?min_id=#{id_two}")
             |> json_response_and_validate_schema(:ok)
  end

  test "PATCH /api/v1/pleroma/conversations/:id" do
    %{user: user, conn: conn} = oauth_access(["write:conversations"])
    other_user = insert(:user)

    {:ok, _activity} = CommonAPI.post(user, %{status: "Hi", visibility: "direct"})

    [participation] = Participation.for_user(user)

    participation = Repo.preload(participation, :recipients)

    user = User.get_cached_by_id(user.id)
    assert [user] == participation.recipients
    assert other_user not in participation.recipients

    query = "recipients[]=#{user.id}&recipients[]=#{other_user.id}"

    result =
      conn
      |> patch("/api/v1/pleroma/conversations/#{participation.id}?#{query}")
      |> json_response_and_validate_schema(200)

    assert result["id"] == participation.id |> to_string

    [participation] = Participation.for_user(user)
    participation = Repo.preload(participation, :recipients)

    assert refresh_record(user) in participation.recipients
    assert other_user in participation.recipients
  end

  test "POST /api/v1/pleroma/conversations/read" do
    user = insert(:user)
    %{user: other_user, conn: conn} = oauth_access(["write:conversations"])

    {:ok, _activity} =
      CommonAPI.post(user, %{status: "Hi @#{other_user.nickname}", visibility: "direct"})

    {:ok, _activity} =
      CommonAPI.post(user, %{status: "Hi @#{other_user.nickname}", visibility: "direct"})

    [participation2, participation1] = Participation.for_user(other_user)
    assert Participation.get(participation2.id).read == false
    assert Participation.get(participation1.id).read == false
    assert Participation.unread_count(other_user) == 2

    [%{"unread" => false}, %{"unread" => false}] =
      conn
      |> post("/api/v1/pleroma/conversations/read", %{})
      |> json_response_and_validate_schema(200)

    [participation2, participation1] = Participation.for_user(other_user)
    assert Participation.get(participation2.id).read == true
    assert Participation.get(participation1.id).read == true
    assert Participation.unread_count(other_user) == 0
  end
end
