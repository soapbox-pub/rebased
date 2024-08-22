# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Notification
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "GET /api/v1/markers" do
    test "gets markers with correct scopes", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, user: user, scopes: ["read:statuses"])
      insert_list(7, :notification, user: user, activity: insert(:note_activity))

      {:ok, %{"notifications" => marker}} =
        Pleroma.Marker.upsert(
          user,
          %{"notifications" => %{"last_read_id" => "69420"}}
        )

      response =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> get("/api/v1/markers?timeline[]=notifications")
        |> json_response_and_validate_schema(200)

      assert response == %{
               "notifications" => %{
                 "last_read_id" => "69420",
                 "updated_at" => NaiveDateTime.to_iso8601(marker.updated_at),
                 "version" => 0,
                 "pleroma" => %{"unread_count" => 7}
               }
             }
    end

    test "gets markers with missed scopes", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, user: user, scopes: [])

      Pleroma.Marker.upsert(user, %{"notifications" => %{"last_read_id" => "69420"}})

      response =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> get("/api/v1/markers", %{timeline: ["notifications"]})
        |> json_response_and_validate_schema(403)

      assert response == %{"error" => "Insufficient permissions: read:statuses."}
    end
  end

  describe "POST /api/v1/markers" do
    test "creates a marker with correct scopes", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, user: user, scopes: ["write:statuses"])

      response =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/markers", %{
          home: %{last_read_id: "777"},
          notifications: %{"last_read_id" => "69420"}
        })
        |> json_response_and_validate_schema(200)

      assert %{
               "notifications" => %{
                 "last_read_id" => "69420",
                 "updated_at" => _,
                 "version" => 0,
                 "pleroma" => %{"unread_count" => 0}
               }
             } = response
    end

    test "updates exist marker", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, user: user, scopes: ["write:statuses"])

      {:ok, %{"notifications" => marker}} =
        Pleroma.Marker.upsert(
          user,
          %{"notifications" => %{"last_read_id" => "69477"}}
        )

      response =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/markers", %{
          home: %{last_read_id: "777"},
          notifications: %{"last_read_id" => "69888"}
        })
        |> json_response_and_validate_schema(200)

      assert response == %{
               "notifications" => %{
                 "last_read_id" => "69888",
                 "updated_at" => NaiveDateTime.to_iso8601(marker.updated_at),
                 "version" => 0,
                 "pleroma" => %{"unread_count" => 0}
               }
             }
    end

    test "creates a marker with missed scopes", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, user: user, scopes: [])

      response =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/markers", %{
          home: %{last_read_id: "777"},
          notifications: %{"last_read_id" => "69420"}
        })
        |> json_response_and_validate_schema(403)

      assert response == %{"error" => "Insufficient permissions: write:statuses."}
    end

    test "marks notifications as read", %{conn: conn} do
      user1 = insert(:user)
      token = insert(:oauth_token, user: user1, scopes: ["write:statuses"])

      user2 = insert(:user)
      {:ok, _activity1} = CommonAPI.post(user2, %{status: "hi @#{user1.nickname}"})
      {:ok, _activity2} = CommonAPI.post(user2, %{status: "hi @#{user1.nickname}"})
      {:ok, _activity3} = CommonAPI.post(user2, %{status: "HIE @#{user1.nickname}"})

      [notification3, notification2, notification1] = Notification.for_user(user1, %{limit: 3})

      refute Repo.get(Notification, notification1.id).seen
      refute Repo.get(Notification, notification2.id).seen
      refute Repo.get(Notification, notification3.id).seen

      conn
      |> assign(:user, user1)
      |> assign(:token, token)
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/markers", %{
        notifications: %{last_read_id: to_string(notification2.id)}
      })
      |> json_response_and_validate_schema(200)

      [notification3, notification2, notification1] = Notification.for_user(user1, %{limit: 3})

      assert Repo.get(Notification, notification1.id).seen
      assert Repo.get(Notification, notification2.id).seen
      refute Repo.get(Notification, notification3.id).seen
    end
  end
end
