# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OStatus.OStatusControllerTest do
  use Pleroma.Web.ConnCase

  import ExUnit.CaptureLog
  import Pleroma.Factory

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.OStatus.ActivityRepresenter

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config_all([:instance, :federating]) do
    Pleroma.Config.put([:instance, :federating], true)
  end

  describe "salmon_incoming" do
    test "decodes a salmon", %{conn: conn} do
      user = insert(:user)
      salmon = File.read!("test/fixtures/salmon.xml")

      assert capture_log(fn ->
               conn =
                 conn
                 |> put_req_header("content-type", "application/atom+xml")
                 |> post("/users/#{user.nickname}/salmon", salmon)

               assert response(conn, 200)
             end) =~ "[error]"
    end

    test "decodes a salmon with a changed magic key", %{conn: conn} do
      user = insert(:user)
      salmon = File.read!("test/fixtures/salmon.xml")

      assert capture_log(fn ->
               conn =
                 conn
                 |> put_req_header("content-type", "application/atom+xml")
                 |> post("/users/#{user.nickname}/salmon", salmon)

               assert response(conn, 200)
             end) =~ "[error]"

      # Wrong key
      info = %{
        magic_key:
          "RSA.pu0s-halox4tu7wmES1FVSx6u-4wc0YrUFXcqWXZG4-27UmbCOpMQftRCldNRfyA-qLbz-eqiwrong1EwUvjsD4cYbAHNGHwTvDOyx5AKthQUP44ykPv7kjKGh3DWKySJvcs9tlUG87hlo7AvnMo9pwRS_Zz2CacQ-MKaXyDepk=.AQAB"
      }

      # Set a wrong magic-key for a user so it has to refetch
      "http://gs.example.org:4040/index.php/user/1"
      |> User.get_cached_by_ap_id()
      |> User.update_info(&User.Info.remote_user_creation(&1, info))

      assert capture_log(fn ->
               conn =
                 build_conn()
                 |> put_req_header("content-type", "application/atom+xml")
                 |> post("/users/#{user.nickname}/salmon", salmon)

               assert response(conn, 200)
             end) =~ "[error]"
    end
  end

  test "gets a feed", %{conn: conn} do
    note_activity = insert(:note_activity)
    object = Object.normalize(note_activity)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    conn =
      conn
      |> put_req_header("content-type", "application/atom+xml")
      |> get("/users/#{user.nickname}/feed.atom")

    assert response(conn, 200) =~ object.data["content"]
  end

  test "returns 404 for a missing feed", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/atom+xml")
      |> get("/users/nonexisting/feed.atom")

    assert response(conn, 404)
  end

  describe "GET object/2" do
    test "gets an object", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))
      url = "/objects/#{uuid}"

      conn =
        conn
        |> put_req_header("accept", "application/xml")
        |> get(url)

      expected =
        ActivityRepresenter.to_simple_form(note_activity, user, true)
        |> ActivityRepresenter.wrap_with_entry()
        |> :xmerl.export_simple(:xmerl_xml)
        |> to_string

      assert response(conn, 200) == expected
    end

    test "redirects to /notice/id for html format", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))
      url = "/objects/#{uuid}"

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get(url)

      assert redirected_to(conn) == "/notice/#{note_activity.id}"
    end

    test "500s when user not found", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])
      User.invalidate_cache(user)
      Pleroma.Repo.delete(user)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))
      url = "/objects/#{uuid}"

      conn =
        conn
        |> put_req_header("accept", "application/xml")
        |> get(url)

      assert response(conn, 500) == ~S({"error":"Something went wrong"})
    end

    test "404s on private objects", %{conn: conn} do
      note_activity = insert(:direct_note_activity)
      object = Object.normalize(note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))

      conn
      |> get("/objects/#{uuid}")
      |> response(404)
    end

    test "404s on nonexisting objects", %{conn: conn} do
      conn
      |> get("/objects/123")
      |> response(404)
    end
  end

  describe "GET activity/2" do
    test "gets an activity in xml format", %{conn: conn} do
      note_activity = insert(:note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))

      conn
      |> put_req_header("accept", "application/xml")
      |> get("/activities/#{uuid}")
      |> response(200)
    end

    test "redirects to /notice/id for html format", %{conn: conn} do
      note_activity = insert(:note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/activities/#{uuid}")

      assert redirected_to(conn) == "/notice/#{note_activity.id}"
    end

    test "505s when user not found", %{conn: conn} do
      note_activity = insert(:note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))
      user = User.get_cached_by_ap_id(note_activity.data["actor"])
      User.invalidate_cache(user)
      Pleroma.Repo.delete(user)

      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/activities/#{uuid}")

      assert response(conn, 500) == ~S({"error":"Something went wrong"})
    end

    test "404s on deleted objects", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, object.data["id"]))

      conn
      |> put_req_header("accept", "application/xml")
      |> get("/objects/#{uuid}")
      |> response(200)

      Object.delete(object)

      conn
      |> put_req_header("accept", "application/xml")
      |> get("/objects/#{uuid}")
      |> response(404)
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

    test "gets an activity in AS2 format", %{conn: conn} do
      note_activity = insert(:note_activity)
      [_, uuid] = hd(Regex.scan(~r/.+\/([\w-]+)$/, note_activity.data["id"]))
      url = "/activities/#{uuid}"

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(url)

      assert json_response(conn, 200)
    end
  end

  describe "GET notice/2" do
    test "gets a notice in xml format", %{conn: conn} do
      note_activity = insert(:note_activity)

      conn
      |> get("/notice/#{note_activity.id}")
      |> response(200)
    end

    test "gets a notice in AS2 format", %{conn: conn} do
      note_activity = insert(:note_activity)

      conn
      |> put_req_header("accept", "application/activity+json")
      |> get("/notice/#{note_activity.id}")
      |> json_response(200)
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

    test "only gets a notice in AS2 format for Create messages", %{conn: conn} do
      note_activity = insert(:note_activity)
      url = "/notice/#{note_activity.id}"

      conn =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get(url)

      assert json_response(conn, 200)

      user = insert(:user)

      {:ok, like_activity, _} = CommonAPI.favorite(note_activity.id, user)
      url = "/notice/#{like_activity.id}"

      assert like_activity.data["type"] == "Like"

      conn =
        build_conn()
        |> put_req_header("accept", "application/activity+json")
        |> get(url)

      assert response(conn, 404)
    end

    test "render html for redirect for html format", %{conn: conn} do
      note_activity = insert(:note_activity)

      resp =
        conn
        |> put_req_header("accept", "text/html")
        |> get("/notice/#{note_activity.id}")
        |> response(200)

      assert resp =~
               "<meta content=\"#{Pleroma.Web.base_url()}/notice/#{note_activity.id}\" property=\"og:url\">"

      user = insert(:user)

      {:ok, like_activity, _} = CommonAPI.favorite(note_activity.id, user)

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

    test "404s a nonexisting notice", %{conn: conn} do
      url = "/notice/123"

      conn =
        conn
        |> get(url)

      assert response(conn, 404)
    end
  end

  describe "feed_redirect" do
    test "undefined format. it redirects to feed", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      response =
        conn
        |> put_req_header("accept", "application/xml")
        |> get("/users/#{user.nickname}")
        |> response(302)

      assert response ==
               "<html><body>You are being <a href=\"#{Pleroma.Web.base_url()}/users/#{
                 user.nickname
               }/feed.atom\">redirected</a>.</body></html>"
    end

    test "undefined format. it returns error when user not found", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/xml")
        |> get("/users/jimm")
        |> response(404)

      assert response == ~S({"error":"Not found"})
    end

    test "activity+json format. it redirects on actual feed of user", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      response =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}")
        |> json_response(200)

      assert response["endpoints"] == %{
               "oauthAuthorizationEndpoint" => "#{Pleroma.Web.base_url()}/oauth/authorize",
               "oauthRegistrationEndpoint" => "#{Pleroma.Web.base_url()}/api/v1/apps",
               "oauthTokenEndpoint" => "#{Pleroma.Web.base_url()}/oauth/token",
               "sharedInbox" => "#{Pleroma.Web.base_url()}/inbox",
               "uploadMedia" => "#{Pleroma.Web.base_url()}/api/ap/upload_media"
             }

      assert response["@context"] == [
               "https://www.w3.org/ns/activitystreams",
               "http://localhost:4001/schemas/litepub-0.1.jsonld",
               %{"@language" => "und"}
             ]

      assert Map.take(response, [
               "followers",
               "following",
               "id",
               "inbox",
               "manuallyApprovesFollowers",
               "name",
               "outbox",
               "preferredUsername",
               "summary",
               "tag",
               "type",
               "url"
             ]) == %{
               "followers" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/followers",
               "following" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/following",
               "id" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}",
               "inbox" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/inbox",
               "manuallyApprovesFollowers" => false,
               "name" => user.name,
               "outbox" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/outbox",
               "preferredUsername" => user.nickname,
               "summary" => user.bio,
               "tag" => [],
               "type" => "Person",
               "url" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}"
             }
    end

    test "activity+json format. it returns error whe use not found", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/jimm")
        |> json_response(404)

      assert response == "Not found"
    end

    test "json format. it redirects on actual feed of user", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/#{user.nickname}")
        |> json_response(200)

      assert response["endpoints"] == %{
               "oauthAuthorizationEndpoint" => "#{Pleroma.Web.base_url()}/oauth/authorize",
               "oauthRegistrationEndpoint" => "#{Pleroma.Web.base_url()}/api/v1/apps",
               "oauthTokenEndpoint" => "#{Pleroma.Web.base_url()}/oauth/token",
               "sharedInbox" => "#{Pleroma.Web.base_url()}/inbox",
               "uploadMedia" => "#{Pleroma.Web.base_url()}/api/ap/upload_media"
             }

      assert response["@context"] == [
               "https://www.w3.org/ns/activitystreams",
               "http://localhost:4001/schemas/litepub-0.1.jsonld",
               %{"@language" => "und"}
             ]

      assert Map.take(response, [
               "followers",
               "following",
               "id",
               "inbox",
               "manuallyApprovesFollowers",
               "name",
               "outbox",
               "preferredUsername",
               "summary",
               "tag",
               "type",
               "url"
             ]) == %{
               "followers" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/followers",
               "following" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/following",
               "id" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}",
               "inbox" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/inbox",
               "manuallyApprovesFollowers" => false,
               "name" => user.name,
               "outbox" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}/outbox",
               "preferredUsername" => user.nickname,
               "summary" => user.bio,
               "tag" => [],
               "type" => "Person",
               "url" => "#{Pleroma.Web.base_url()}/users/#{user.nickname}"
             }
    end

    test "json format. it returns error whe use not found", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/users/jimm")
        |> json_response(404)

      assert response == "Not found"
    end

    test "html format. it redirects on actual feed of user", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      response =
        conn
        |> get("/users/#{user.nickname}")
        |> response(200)

      assert response ==
               Fallback.RedirectController.redirector_with_meta(
                 conn,
                 %{user: user}
               ).resp_body
    end

    test "html format. it returns error when user not found", %{conn: conn} do
      response =
        conn
        |> get("/users/jimm")
        |> json_response(404)

      assert response == %{"error" => "Not found"}
    end
  end

  describe "GET /notice/:id/embed_player" do
    test "render embed player", %{conn: conn} do
      note_activity = insert(:note_activity)
      object = Pleroma.Object.normalize(note_activity)

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

      conn =
        conn
        |> get("/notice/#{note_activity.id}/embed_player")

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
      object = Pleroma.Object.normalize(note_activity)
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
      object = Pleroma.Object.normalize(note_activity)

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

      assert conn
             |> get("/notice/#{note_activity.id}/embed_player")
             |> response(404)
    end
  end
end
