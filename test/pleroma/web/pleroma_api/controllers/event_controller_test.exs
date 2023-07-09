# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.EventControllerTest do
  use Pleroma.Web.ConnCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "POST /api/v1/pleroma/events" do
    setup do
      user = insert(:user)
      %{user: user, conn: conn} = oauth_access(["write"], user: user)
      [user: user, conn: conn]
    end

    test "creates an event", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/events", %{
          "name" => "Event name",
          "start_time" => "2023-01-01T01:00:00.000Z",
          "end_time" => "2023-01-01T04:00:00.000Z",
          "join_mode" => "free"
        })

      assert %{
               "pleroma" => %{
                 "event" => %{
                   "name" => "Event name",
                   "join_mode" => "free"
                 }
               }
             } = json_response_and_validate_schema(conn, 200)
    end

    test "can't create event that ends before its start", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/events", %{
          "name" => "Event name",
          "start_time" => "2023-01-01T04:00:00.000Z",
          "end_time" => "2022-12-31T04:00:00.000Z",
          "join_mode" => "free"
        })

      assert json_response_and_validate_schema(conn, 422) == %{
               "error" => "Event can't end before its start"
             }
    end

    test "assigns location from location id", %{conn: conn} do
      Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/events", %{
          "name" => "Event name",
          "start_time" => "2023-01-01T01:00:00.000Z",
          "end_time" => "2023-01-01T04:00:00.000Z",
          "join_mode" => "free",
          "location_id" => "3726208425"
        })

      assert %{
               "pleroma" => %{
                 "event" => %{
                   "location" => %{
                     "name" => "Benis",
                     "longitude" => 45.7285348,
                     "latitude" => 38.212263,
                     "street" => " ",
                     "locality" => "بخش مرکزی",
                     "region" => "East Azerbaijan Province",
                     "country" => "Iran"
                   }
                 }
               }
             } = json_response_and_validate_schema(conn, 200)
    end
  end

  test "GET /api/v1/pleroma/events/:id/participations" do
    %{conn: conn} = oauth_access(["read"])

    user_one = insert(:user)
    user_two = insert(:user)
    user_three = insert(:user)

    {:ok, activity} =
      CommonAPI.event(user_one, %{
        name: "test event",
        status: "",
        join_mode: "free",
        start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
      })

    CommonAPI.join(user_two, activity.id)
    CommonAPI.join(user_three, activity.id)

    conn =
      conn
      |> get("/api/v1/pleroma/events/#{activity.id}/participations")

    assert response = json_response_and_validate_schema(conn, 200)
    assert length(response) == 3
  end

  describe "GET /api/v1/pleroma/events/:id/participation_requests" do
    setup do
      user = insert(:user)
      %{user: user, conn: conn} = oauth_access(["read"], user: user)
      [user: user, conn: conn]
    end

    test "show participation requests", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.event(user, %{
          name: "test event",
          status: "",
          join_mode: "restricted",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      CommonAPI.join(other_user, activity.id, %{
        participation_message: "I'm interested in this event"
      })

      conn =
        conn
        |> get("/api/v1/pleroma/events/#{activity.id}/participation_requests")

      assert [
               %{
                 "participation_message" => "I'm interested in this event"
               }
             ] = response = json_response_and_validate_schema(conn, 200)

      assert length(response) == 1
    end

    test "don't display requests if not an author", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.event(other_user, %{
          name: "test event",
          status: "",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      conn =
        conn
        |> get("/api/v1/pleroma/events/#{activity.id}/participation_requests")

      assert %{"error" => "Can't get participation requests"} =
               json_response_and_validate_schema(conn, 403)
    end
  end

  describe "POST /api/v1/pleroma/events/:id/join" do
    setup do
      user = insert(:user)
      %{user: user, conn: conn} = oauth_access(["write"], user: user)
      [user: user, conn: conn]
    end

    test "joins an event", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.event(other_user, %{
          name: "test event",
          status: "",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      conn =
        conn
        |> post("/api/v1/pleroma/events/#{activity.id}/join")

      assert json_response_and_validate_schema(conn, 200)

      assert %{
               data: %{
                 "participation_count" => 2
               }
             } = Object.get_by_ap_id(activity.data["object"])
    end

    test "can't join your own event", %{conn: conn, user: user} do
      {:ok, activity} =
        CommonAPI.event(user, %{
          name: "test event",
          status: "",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      conn =
        conn
        |> post("/api/v1/pleroma/events/#{activity.id}/join")

      assert json_response_and_validate_schema(conn, :bad_request) == %{
               "error" => "Can't join your own event"
             }
    end
  end

  describe "POST /api/v1/pleroma/events/:id/leave" do
    setup do
      user = insert(:user)
      %{user: user, conn: conn} = oauth_access(["write"], user: user)
      [user: user, conn: conn]
    end

    test "leaves an event", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.event(other_user, %{
          name: "test event",
          status: "",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      CommonAPI.join(user, activity.id)

      conn =
        conn
        |> post("/api/v1/pleroma/events/#{activity.id}/leave")

      assert json_response_and_validate_schema(conn, 200)

      assert %{
               data: %{
                 "participation_count" => 1
               }
             } = Object.get_by_ap_id(activity.data["object"])
    end

    test "can't leave event you are not participating in", %{conn: conn} do
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.event(other_user, %{
          name: "test event",
          status: "",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      conn =
        conn
        |> post("/api/v1/pleroma/events/#{activity.id}/leave")

      assert json_response_and_validate_schema(conn, :bad_request) == %{
               "error" => "Not participating in the event"
             }
    end
  end

  describe "POST /api/v1/pleroma/events/:id/participation_requests/:participant_id/authorize" do
    setup do
      user = insert(:user)
      %{user: user, conn: conn} = oauth_access(["write"], user: user)
      [user: user, conn: conn]
    end

    test "accepts a participation request", %{user: user, conn: conn} do
      %{ap_id: ap_id} = other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.event(user, %{
          name: "test event",
          status: "",
          join_mode: "restricted",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      CommonAPI.join(other_user, activity.id)

      conn =
        conn
        |> post(
          "/api/v1/pleroma/events/#{activity.id}/participation_requests/#{other_user.id}/authorize"
        )

      assert json_response_and_validate_schema(conn, 200)

      assert %{
               data: %{
                 "participations" => [^ap_id, _],
                 "participation_count" => 2
               }
             } = Object.get_by_ap_id(activity.data["object"])

      assert %{data: %{"state" => "accept"}} =
               Utils.get_existing_join(other_user.ap_id, activity.data["object"])
    end

    test "it refuses to accept a request when event is not by the user", %{conn: conn} do
      [second_user, third_user] = insert_pair(:user)

      {:ok, activity} =
        CommonAPI.event(second_user, %{
          name: "test event",
          status: "",
          join_mode: "restricted",
          start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
        })

      CommonAPI.join(third_user, activity.id)

      conn =
        conn
        |> post(
          "/api/v1/pleroma/events/#{activity.id}/participation_requests/#{third_user.id}/authorize"
        )

      assert json_response_and_validate_schema(conn, :forbidden)
    end
  end

  test "POST /api/v1/pleroma/events/:id/participation_requests/:participant_id/reject" do
    [user, other_user] = insert_pair(:user)
    %{user: user, conn: conn} = oauth_access(["write"], user: user)

    {:ok, activity} =
      CommonAPI.event(user, %{
        name: "test event",
        status: "",
        join_mode: "restricted",
        start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
      })

    CommonAPI.join(other_user, activity.id)

    conn =
      conn
      |> post(
        "/api/v1/pleroma/events/#{activity.id}/participation_requests/#{other_user.id}/reject"
      )

    assert json_response_and_validate_schema(conn, 200)

    assert %{data: %{"state" => "reject"}} =
             Utils.get_existing_join(other_user.ap_id, activity.data["object"])
  end

  test "GET /api/v1/pleroma/events/:id/ics" do
    %{conn: conn} = oauth_access(["read"])
    user = insert(:user)

    {:ok, activity} =
      CommonAPI.event(user, %{
        name: "test event",
        status: "",
        join_mode: "free",
        start_time: DateTime.from_iso8601("2023-01-01T01:00:00.000Z") |> elem(1)
      })

    conn =
      conn
      |> get("/api/v1/pleroma/events/#{activity.id}/ics")

    assert conn.status == 200

    assert conn.resp_body == """
           BEGIN:VCALENDAR
           CALSCALE:GREGORIAN
           VERSION:2.0
           PRODID:-//Elixir ICalendar//Elixir ICalendar//EN
           BEGIN:VEVENT
           DESCRIPTION:
           DTSTART:20230101T010000Z
           ORGANIZER:#{Pleroma.HTML.strip_tags(user.name || user.nickname)}
           SUMMARY:test event
           UID:#{activity.object.id}
           URL:#{activity.object.data["id"]}
           END:VEVENT
           END:VCALENDAR
           """
  end
end
