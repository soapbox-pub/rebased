# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.MarkerControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  describe "GET /api/v1/markers" do
    test "gets markers with correct scopes", %{conn: conn} do
      user = insert(:user)
      token = insert(:oauth_token, user: user, scopes: ["read:statuses"])
      insert_list(7, :notification, user: user)

      {:ok, %{"notifications" => marker}} =
        Pleroma.Marker.upsert(
          user,
          %{"notifications" => %{"last_read_id" => "69420"}}
        )

      response =
        conn
        |> assign(:user, user)
        |> assign(:token, token)
        |> get("/api/v1/markers", %{timeline: ["notifications"]})
        |> json_response(200)

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
        |> json_response(403)

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
        |> post("/api/v1/markers", %{
          home: %{last_read_id: "777"},
          notifications: %{"last_read_id" => "69420"}
        })
        |> json_response(200)

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
        |> post("/api/v1/markers", %{
          home: %{last_read_id: "777"},
          notifications: %{"last_read_id" => "69888"}
        })
        |> json_response(200)

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
        |> post("/api/v1/markers", %{
          home: %{last_read_id: "777"},
          notifications: %{"last_read_id" => "69420"}
        })
        |> json_response(403)

      assert response == %{"error" => "Insufficient permissions: write:statuses."}
    end
  end
end
