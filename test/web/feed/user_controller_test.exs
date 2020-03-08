# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.UserControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import SweetXml

  alias Pleroma.Object
  alias Pleroma.User

  clear_config([:feed])

  test "gets a feed", %{conn: conn} do
    Pleroma.Config.put(
      [:feed, :post_title],
      %{max_length: 10, omission: "..."}
    )

    activity = insert(:note_activity)

    note =
      insert(:note,
        data: %{
          "content" => "This is :moominmamma: note ",
          "attachment" => [
            %{
              "url" => [%{"mediaType" => "image/png", "href" => "https://pleroma.gov/image.png"}]
            }
          ],
          "inReplyTo" => activity.data["id"]
        }
      )

    note_activity = insert(:note_activity, note: note)
    user = User.get_cached_by_ap_id(note_activity.data["actor"])

    note2 =
      insert(:note,
        user: user,
        data: %{"content" => "42 This is :moominmamma: note ", "inReplyTo" => activity.data["id"]}
      )

    _note_activity2 = insert(:note_activity, note: note2)
    object = Object.normalize(note_activity)

    resp =
      conn
      |> put_req_header("content-type", "application/atom+xml")
      |> get(user_feed_path(conn, :feed, user.nickname))
      |> response(200)

    activity_titles =
      resp
      |> SweetXml.parse()
      |> SweetXml.xpath(~x"//entry/title/text()"l)

    assert activity_titles == ['42 This...', 'This is...']
    assert resp =~ object.data["content"]
  end

  test "returns 404 for a missing feed", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/atom+xml")
      |> get(user_feed_path(conn, :feed, "nonexisting"))

    assert response(conn, 404)
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
        |> get(user_feed_path(conn, :feed, "jimm"))
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
end
