# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Feed.TagControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory
  import SweetXml

  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Feed.FeedView

  clear_config([:feed])

  test "gets a feed (ATOM)", %{conn: conn} do
    Pleroma.Config.put(
      [:feed, :post_title],
      %{max_length: 25, omission: "..."}
    )

    user = insert(:user)
    {:ok, activity1} = CommonAPI.post(user, %{"status" => "yeah #PleromaArt"})

    object = Object.normalize(activity1)

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

    {:ok, activity2} = CommonAPI.post(user, %{"status" => "42 This is :moominmamma #PleromaArt"})

    {:ok, _activity3} = CommonAPI.post(user, %{"status" => "This is :moominmamma"})

    response =
      conn
      |> put_req_header("accept", "application/atom+xml")
      |> get(tag_feed_path(conn, :feed, "pleromaart.atom"))
      |> response(200)

    xml = parse(response)

    assert xpath(xml, ~x"//feed/title/text()") == '#pleromaart'

    assert xpath(xml, ~x"//feed/entry/title/text()"l) == [
             '42 This is :moominmamm...',
             'yeah #PleromaArt'
           ]

    assert xpath(xml, ~x"//feed/entry/author/name/text()"ls) == [user.nickname, user.nickname]
    assert xpath(xml, ~x"//feed/entry/author/id/text()"ls) == [user.ap_id, user.ap_id]

    conn =
      conn
      |> put_req_header("accept", "application/atom+xml")
      |> get("/tags/pleromaart.atom", %{"max_id" => activity2.id})

    assert get_resp_header(conn, "content-type") == ["application/atom+xml; charset=utf-8"]
    resp = response(conn, 200)
    xml = parse(resp)

    assert xpath(xml, ~x"//feed/title/text()") == '#pleromaart'

    assert xpath(xml, ~x"//feed/entry/title/text()"l) == [
             'yeah #PleromaArt'
           ]
  end

  test "gets a feed (RSS)", %{conn: conn} do
    Pleroma.Config.put(
      [:feed, :post_title],
      %{max_length: 25, omission: "..."}
    )

    user = insert(:user)
    {:ok, activity1} = CommonAPI.post(user, %{"status" => "yeah #PleromaArt"})

    object = Object.normalize(activity1)

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

    {:ok, activity2} = CommonAPI.post(user, %{"status" => "42 This is :moominmamma #PleromaArt"})

    {:ok, _activity3} = CommonAPI.post(user, %{"status" => "This is :moominmamma"})

    response =
      conn
      |> put_req_header("accept", "application/rss+xml")
      |> get(tag_feed_path(conn, :feed, "pleromaart.rss"))
      |> response(200)

    xml = parse(response)
    assert xpath(xml, ~x"//channel/title/text()") == '#pleromaart'

    assert xpath(xml, ~x"//channel/description/text()"s) ==
             "These are public toots tagged with #pleromaart. You can interact with them if you have an account anywhere in the fediverse."

    assert xpath(xml, ~x"//channel/link/text()") ==
             '#{Pleroma.Web.base_url()}/tags/pleromaart.rss'

    assert xpath(xml, ~x"//channel/webfeeds:logo/text()") ==
             '#{Pleroma.Web.base_url()}/static/logo.png'

    assert xpath(xml, ~x"//channel/item/title/text()"l) == [
             '42 This is :moominmamm...',
             'yeah #PleromaArt'
           ]

    assert xpath(xml, ~x"//channel/item/pubDate/text()"sl) == [
             FeedView.pub_date(activity1.data["published"]),
             FeedView.pub_date(activity2.data["published"])
           ]

    assert xpath(xml, ~x"//channel/item/enclosure/@url"sl) == [
             "https://peertube.moe/static/webseed/df5f464b-be8d-46fb-ad81-2d4c2d1630e3-480.mp4"
           ]

    obj1 = Object.normalize(activity1)
    obj2 = Object.normalize(activity2)

    assert xpath(xml, ~x"//channel/item/description/text()"sl) == [
             HtmlEntities.decode(FeedView.activity_content(obj2)),
             HtmlEntities.decode(FeedView.activity_content(obj1))
           ]

    response =
      conn
      |> put_req_header("accept", "application/rss+xml")
      |> get(tag_feed_path(conn, :feed, "pleromaart"))
      |> response(200)

    xml = parse(response)
    assert xpath(xml, ~x"//channel/title/text()") == '#pleromaart'

    assert xpath(xml, ~x"//channel/description/text()"s) ==
             "These are public toots tagged with #pleromaart. You can interact with them if you have an account anywhere in the fediverse."

    conn =
      conn
      |> put_req_header("accept", "application/rss+xml")
      |> get("/tags/pleromaart.rss", %{"max_id" => activity2.id})

    assert get_resp_header(conn, "content-type") == ["application/rss+xml; charset=utf-8"]
    resp = response(conn, 200)
    xml = parse(resp)

    assert xpath(xml, ~x"//channel/title/text()") == '#pleromaart'

    assert xpath(xml, ~x"//channel/item/title/text()"l) == [
             'yeah #PleromaArt'
           ]
  end
end
