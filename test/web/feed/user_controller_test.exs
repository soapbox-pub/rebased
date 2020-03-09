# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.UserControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import SweetXml

  alias Pleroma.Config
  alias Pleroma.Object
  alias Pleroma.User

  clear_config([:instance, :federating]) do
    Config.put([:instance, :federating], true)
  end

  describe "feed" do
    clear_config([:feed])

    test "gets a feed", %{conn: conn} do
      Config.put(
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
                "url" => [
                  %{"mediaType" => "image/png", "href" => "https://pleroma.gov/image.png"}
                ]
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
          data: %{
            "content" => "42 This is :moominmamma: note ",
            "inReplyTo" => activity.data["id"]
          }
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
               Fallback.RedirectController.redirector_with_meta(
                 conn,
                 %{user: user}
               ).resp_body
    end

    test "with html format, it returns error when user is not found", %{conn: conn} do
      response =
        conn
        |> get("/users/jimm")
        |> json_response(404)

      assert response == %{"error" => "Not found"}
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
      assert redirected_to(conn) == "#{Pleroma.Web.base_url()}/users/#{user.nickname}/feed.atom"
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
end
