# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.UserControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import SweetXml

  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Feed.FeedView

  setup do: clear_config([:static_fe, :enabled], false)

  describe "feed" do
    setup do: clear_config([:feed])

    setup do
      clear_config(
        [:feed, :post_title],
        %{max_length: 15, omission: "..."}
      )

      activity = insert(:note_activity)

      note =
        insert(:note,
          data: %{
            "content" => "This & this is :moominmamma: note ",
            "source" => "This & this is :moominmamma: note ",
            "attachment" => [
              %{
                "url" => [
                  %{"mediaType" => "image/png", "href" => "https://pleroma.gov/image.png"}
                ]
              }
            ],
            "inReplyTo" => activity.data["id"],
            "context" => "2hu & as",
            "summary" => "2hu & as"
          }
        )

      note_activity = insert(:note_activity, note: note)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      note2 =
        insert(:note,
          user: user,
          data: %{
            "content" => "42 & This is :moominmamma: note ",
            "inReplyTo" => activity.data["id"]
          }
        )

      note_activity2 = insert(:note_activity, note: note2)
      object = Object.normalize(note_activity, fetch: false)

      [user: user, object: object, max_id: note_activity2.id]
    end

    test "gets an atom feed", %{conn: conn, user: user, object: object, max_id: max_id} do
      resp =
        conn
        |> put_req_header("accept", "application/atom+xml")
        |> get(user_feed_path(conn, :feed, user.nickname))
        |> response(200)

      activity_titles =
        resp
        |> SweetXml.parse()
        |> SweetXml.xpath(~x"//entry/title/text()"l)

      assert activity_titles == ['42 &amp; Thi...', 'This &amp; t...']
      assert resp =~ FeedView.escape(object.data["content"])
      assert resp =~ FeedView.escape(object.data["summary"])
      assert resp =~ FeedView.escape(object.data["context"])

      resp =
        conn
        |> put_req_header("accept", "application/atom+xml")
        |> get("/users/#{user.nickname}/feed", %{"max_id" => max_id})
        |> response(200)

      activity_titles =
        resp
        |> SweetXml.parse()
        |> SweetXml.xpath(~x"//entry/title/text()"l)

      assert activity_titles == ['This &amp; t...']
    end

    test "gets a rss feed", %{conn: conn, user: user, object: object, max_id: max_id} do
      resp =
        conn
        |> put_req_header("accept", "application/rss+xml")
        |> get("/users/#{user.nickname}/feed.rss")
        |> response(200)

      activity_titles =
        resp
        |> SweetXml.parse()
        |> SweetXml.xpath(~x"//item/title/text()"l)

      assert activity_titles == ['42 &amp; Thi...', 'This &amp; t...']
      assert resp =~ FeedView.escape(object.data["content"])
      assert resp =~ FeedView.escape(object.data["summary"])
      assert resp =~ FeedView.escape(object.data["context"])

      resp =
        conn
        |> put_req_header("accept", "application/rss+xml")
        |> get("/users/#{user.nickname}/feed.rss", %{"max_id" => max_id})
        |> response(200)

      activity_titles =
        resp
        |> SweetXml.parse()
        |> SweetXml.xpath(~x"//item/title/text()"l)

      assert activity_titles == ['This &amp; t...']
    end

    test "returns 404 for a missing feed", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/atom+xml")
        |> get(user_feed_path(conn, :feed, "nonexisting"))

      assert response(conn, 404)
    end

    test "returns feed with public and unlisted activities", %{conn: conn} do
      user = insert(:user)

      {:ok, _} = CommonAPI.post(user, %{status: "public", visibility: "public"})
      {:ok, _} = CommonAPI.post(user, %{status: "direct", visibility: "direct"})
      {:ok, _} = CommonAPI.post(user, %{status: "unlisted", visibility: "unlisted"})
      {:ok, _} = CommonAPI.post(user, %{status: "private", visibility: "private"})

      resp =
        conn
        |> put_req_header("accept", "application/atom+xml")
        |> get(user_feed_path(conn, :feed, user.nickname))
        |> response(200)

      activity_titles =
        resp
        |> SweetXml.parse()
        |> SweetXml.xpath(~x"//entry/title/text()"l)
        |> Enum.sort()

      assert activity_titles == ['public', 'unlisted']
    end

    test "returns 404 when the user is remote", %{conn: conn} do
      user = insert(:user, local: false)

      {:ok, _} = CommonAPI.post(user, %{status: "test"})

      assert conn
             |> put_req_header("accept", "application/atom+xml")
             |> get(user_feed_path(conn, :feed, user.nickname))
             |> response(404)
    end

    test "does not require authentication on non-federating instances", %{conn: conn} do
      clear_config([:instance, :federating], false)
      user = insert(:user)

      conn
      |> put_req_header("accept", "application/rss+xml")
      |> get("/users/#{user.nickname}/feed.rss")
      |> response(200)
    end
  end

  # Note: see ActivityPubControllerTest for JSON format tests
  describe "feed_redirect" do
    test "with html format, it redirects to user feed", %{conn: conn} do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      response =
        conn
        |> get("/users/#{user.nickname}")
        |> response(200)

      assert response ==
               Pleroma.Web.Fallback.RedirectController.redirector_with_meta(
                 conn,
                 %{user: user}
               ).resp_body
    end

    test "with html format, it falls back to frontend when user is remote", %{conn: conn} do
      user = insert(:user, local: false)

      {:ok, _} = CommonAPI.post(user, %{status: "test"})

      response =
        conn
        |> get("/users/#{user.nickname}")
        |> response(200)

      assert response =~ "</html>"
    end

    test "with html format, it falls back to frontend when user is not found", %{conn: conn} do
      response =
        conn
        |> get("/users/jimm")
        |> response(200)

      assert response =~ "</html>"
    end

    test "with non-html / non-json format, it redirects to user feed in atom format", %{
      conn: conn
    } do
      note_activity = insert(:note_activity)
      user = User.get_cached_by_ap_id(note_activity.data["actor"])

      conn =
        conn
        |> put_req_header("accept", "application/xml")
        |> get("/users/#{user.nickname}")

      assert conn.status == 302

      assert redirected_to(conn) ==
               "#{Pleroma.Web.Endpoint.url()}/users/#{user.nickname}/feed.atom"
    end

    test "with non-html / non-json format, it returns error when user is not found", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "application/xml")
        |> get(user_feed_path(conn, :feed, "jimm"))
        |> response(404)

      assert response == ~S({"error":"Not found"})
    end
  end

  describe "private instance" do
    setup do: clear_config([:instance, :public])

    test "returns 404 for user feed", %{conn: conn} do
      clear_config([:instance, :public], false)
      user = insert(:user)

      {:ok, _} = CommonAPI.post(user, %{status: "test"})

      assert conn
             |> put_req_header("accept", "application/atom+xml")
             |> get(user_feed_path(conn, :feed, user.nickname))
             |> response(404)
    end
  end
end
