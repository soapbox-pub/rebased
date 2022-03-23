# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.OStatusControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Endpoint

  require Pleroma.Constants

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:static_fe, :enabled], false)

  describe "Mastodon compatibility routes" do
    setup %{conn: conn} do
      conn = put_req_header(conn, "accept", "text/html")

      {:ok, object} =
        %{
          "type" => "Note",
          "content" => "hey",
          "id" => Endpoint.url() <> "/users/raymoo/statuses/999999999",
          "actor" => Endpoint.url() <> "/users/raymoo",
          "to" => [Pleroma.Constants.as_public()]
        }
        |> Object.create()

      {:ok, activity, _} =
        %{
          "id" => object.data["id"] <> "/activity",
          "type" => "Create",
          "object" => object.data["id"],
          "actor" => object.data["actor"],
          "to" => object.data["to"]
        }
        |> ActivityPub.persist(local: true)

      %{conn: conn, activity: activity}
    end

    test "redirects to /notice/:id for html format", %{conn: conn, activity: activity} do
      conn = get(conn, "/users/raymoo/statuses/999999999")
      assert redirected_to(conn) == "/notice/#{activity.id}"
    end

    test "redirects to /notice/:id for html format for activity", %{
      conn: conn,
      activity: activity
    } do
      conn = get(conn, "/users/raymoo/statuses/999999999/activity")
      assert redirected_to(conn) == "/notice/#{activity.id}"
    end
  end

  # Note: see ActivityPubControllerTest for JSON format tests
  describe "GET /objects/:uuid (text/html)" do
    setup %{conn: conn} do
      conn = put_req_header(conn, "accept", "text/html")
      %{conn: conn}
    end

    test "redirects to /notice/id for html format", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity, fetch: false)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))
      url = "/objects/#{uuid}"

      conn = get(conn, url)
      assert redirected_to(conn) == "/notice/#{note_activity.id}"
    end

    test "404s on private objects", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      object = Object.normalize(note_activity, fetch: false)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))

      conn
      |> get("/objects/#{uuid}")
      |> response(404)
    end

    test "404s on non-existing objects", %{conn: conn} do
      conn
      |> get("/objects/123")
      |> response(404)
    end
  end

  # Note: see ActivityPubControllerTest for JSON format tests
  describe "GET /activities/:uuid (text/html)" do
    setup %{conn: conn} do
      conn = put_req_header(conn, "accept", "text/html")
      %{conn: conn}
    end

    test "redirects to /notice/id for html format", %{conn: conn} do
      note_activity = insert(:note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))

      conn = get(conn, "/activities/#{uuid}")
      assert redirected_to(conn) == "/notice/#{note_activity.id}"
    end

    test "404s on private activities", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))

      conn
      |> get("/activities/#{uuid}")
      |> response(404)
    end

    test "404s on nonexistent activities", %{conn: conn} do
      conn
      |> get("/activities/123")
      |> response(404)
    end
  end

  describe "GET notice/2" do
    test "redirects to a proper object URL when json requested and the object is local", %{
      conn: conn
    } do
      note_activity = insert(:note_activity)
      expected_redirect_url = Object.normalize(note_activity, fetch: false).data["id"]

      redirect_url =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/notice/#{note_activity.id}")
        |> redirected_to()

      assert redirect_url == expected_redirect_url
    end

    test "redirects to a proper object URL when json requested and the object is remote", %{
      conn: conn
    } do
      note_activity = insert(:note_activity, local: false)
      expected_redirect_url = Object.normalize(note_activity, fetch: false).data["id"]

      redirect_url =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/notice/#{note_activity.id}")
        |> redirected_to()

      assert redirect_url == expected_redirect_url
    end

    test "500s when actor not found", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])
      User.invalidate_cache(user)
      Pleroma.Repo.delete(user)

      conn =
        conn
        |> get("/notice/#{note_activity.id}")

      assert response(conn, 500) == ~S({"error":"Something went wrong"})
    end

    test "render html for redirect for html format", %{conn: conn} do
      note_activity = insert(:note_activity)

      resp =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/notice/#{note_activity.id}")
        |> response(200)

      assert resp =~
               "<meta content=\"#{Pleroma.Web.Endpoint.url()}/notice/#{note_activity.id}\" property=\"og:url\">"

      user = insert(:user)

      {:ok, like_activity} = CommonAPI.favorite(user, note_activity.id)

      assert like_activity.data["type"] == "Like"

      resp =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/notice/#{like_activity.id}")
        |> response(200)

      assert resp =~ "<!--server-generated-meta-->"
    end

    test "404s a private notice", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      url = "/notice/#{note_activity.id}"

      conn =
        conn
        |> get(url)

      assert response(conn, 404)
    end

    test "404s a non-existing notice", %{conn: conn} do
      url = "/notice/123"

      conn =
        conn
        |> get(url)

      assert response(conn, 404)
    end

    test "does not require authentication on non-federating instances", %{
      conn: conn
    } do
      clear_config([:instance, :federating], false)
      note_activity = insert(:note_activity)

      conn
      |> put_req_header("accept", "text/html")
      |> get("/notice/#{note_activity.id}")
      |> response(200)
    end
  end

  describe "GET /notice/:id/embed_player" do
    setup do
      note_activity = insert(:note_activity)
      object = Pleroma.Object.normalize(note_activity, fetch: false)

      object_data =
        Map.put(object.data, "attachment", [
          %{
            "url" => [
              %{
                "href" =>
                  "https://peertube.moe/static/webseed/df5f464b-be8d-46fb-ad81-2d4c2d1630e3-480.mp4",
                "mediaType" => "video/mp4",
                "type" => "Link"
              }
            ]
          }
        ])

      object
      |> Ecto.Changeset.change(data: object_data)
      |> Pleroma.Repo.update()

      %{note_activity: note_activity}
    end

    test "renders embed player", %{conn: conn, note_activity: note_activity} do
      conn = get(conn, "/notice/#{note_activity.id}/embed_player")

      assert Plug.Conn.get_resp_header(conn, "x-frame-options") == ["ALLOW"]

      assert Plug.Conn.get_resp_header(
               conn,
               "content-security-policy"
             ) == [
               "default-src 'none';style-src 'self' 'unsafe-inline';img-src 'self' data: https:; media-src 'self' https:;"
             ]

      assert response(conn, 200) =~
               "<video controls loop><source src=\"https://peertube.moe/static/webseed/df5f464b-be8d-46fb-ad81-2d4c2d1630e3-480.mp4\" type=\"video/mp4\">Your browser does not support video/mp4 playback.</video>"
    end

    test "404s when activity isn't create", %{conn: conn} do
      note_activity = insert(:note_activity, data_attrs: %{"type" => "Like"})

      assert conn
             |> get("/notice/#{note_activity.id}/embed_player")
             |> response(404)
    end

    test "404s when activity is direct message", %{conn: conn} do
      note_activity = insert(:note_activity, data_attrs: %{"directMessage" => true})

      assert conn
             |> get("/notice/#{note_activity.id}/embed_player")
             |> response(404)
    end

    test "404s when attachment is empty", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Pleroma.Object.normalize(note_activity, fetch: false)
      object_data = Map.put(object.data, "attachment", [])

      object
      |> Ecto.Changeset.change(data: object_data)
      |> Pleroma.Repo.update()

      assert conn
             |> get("/notice/#{note_activity.id}/embed_player")
             |> response(404)
    end

    test "404s when attachment isn't audio or video", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Pleroma.Object.normalize(note_activity, fetch: false)

      object_data =
        Map.put(object.data, "attachment", [
          %{
            "url" => [
              %{
                "href" => "https://peertube.moe/static/webseed/480.jpg",
                "mediaType" => "image/jpg",
                "type" => "Link"
              }
            ]
          }
        ])

      object
      |> Ecto.Changeset.change(data: object_data)
      |> Pleroma.Repo.update()

      conn
      |> get("/notice/#{note_activity.id}/embed_player")
      |> response(404)
    end

    test "does not require authentication on non-federating instances", %{
      conn: conn,
      note_activity: note_activity
    } do
      clear_config([:instance, :federating], false)

      conn
      |> put_req_header("accept", "text/html")
      |> get("/notice/#{note_activity.id}/embed_player")
      |> response(200)
    end
  end

  describe "notice compatibility routes" do
    test "Soapbox FE", %{conn: conn} do
      user = insert(:user)
      note_activity = insert(:note_activity, user: user)

      resp =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/@#{user.nickname}/posts/#{note_activity.id}")
        |> response(200)

      expected =
        "<meta content=\"#{Endpoint.url()}/notice/#{note_activity.id}\" property=\"og:url\">"

      assert resp =~ expected
    end

    test "Mastodon", %{conn: conn} do
      user = insert(:user)
      note_activity = insert(:note_activity, user: user)

      resp =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/@#{user.nickname}/#{note_activity.id}")
        |> response(200)

      expected =
        "<meta content=\"#{Endpoint.url()}/notice/#{note_activity.id}\" property=\"og:url\">"

      assert resp =~ expected
    end

    test "Twitter", %{conn: conn} do
      user = insert(:user)
      note_activity = insert(:note_activity, user: user)

      resp =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/#{user.nickname}/status/#{note_activity.id}")
        |> response(200)

      expected =
        "<meta content=\"#{Endpoint.url()}/notice/#{note_activity.id}\" property=\"og:url\">"

      assert resp =~ expected
    end
  end
end
