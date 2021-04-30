# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.NotificationControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "POST /api/v1/pleroma/notifications/read" do
    setup do: oauth_access(["write:notifications"])

    test "it marks a single notification as read", %{user: user1, conn: conn} do
      user2 = insert(:user)
      {:ok, activity1} = CommonAPI.post(user2, %{status: "hi @#{user1.nickname}"})
      {:ok, activity2} = CommonAPI.post(user2, %{status: "hi @#{user1.nickname}"})
      {:ok, [notification1]} = Notification.create_notifications(activity1)
      {:ok, [notification2]} = Notification.create_notifications(activity2)

      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/notifications/read", %{id: notification1.id})
        |> json_response_and_validate_schema(:ok)

      assert %{"pleroma" => %{"is_seen" => true}} = response
      assert Repo.get(Notification, notification1.id).seen
      refute Repo.get(Notification, notification2.id).seen
    end

    test "it marks multiple notifications as read", %{user: user1, conn: conn} do
      user2 = insert(:user)
      {:ok, _activity1} = CommonAPI.post(user2, %{status: "hi @#{user1.nickname}"})
      {:ok, _activity2} = CommonAPI.post(user2, %{status: "hi @#{user1.nickname}"})
      {:ok, _activity3} = CommonAPI.post(user2, %{status: "HIE @#{user1.nickname}"})

      [notification3, notification2, notification1] = Notification.for_user(user1, %{limit: 3})

      [response1, response2] =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/notifications/read", %{max_id: notification2.id})
        |> json_response_and_validate_schema(:ok)

      assert %{"pleroma" => %{"is_seen" => true}} = response1
      assert %{"pleroma" => %{"is_seen" => true}} = response2
      assert Repo.get(Notification, notification1.id).seen
      assert Repo.get(Notification, notification2.id).seen
      refute Repo.get(Notification, notification3.id).seen
    end

    test "it returns error when notification not found", %{conn: conn} do
      response =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/notifications/read", %{
          id: 22_222_222_222_222
        })
        |> json_response_and_validate_schema(:bad_request)

      assert response == %{"error" => "Cannot get notification"}
    end
  end
end
