# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.TwitterCardTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  alias Pleroma.User
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Metadata.Providers.TwitterCard
  alias Pleroma.Web.Metadata.Utils
  alias Pleroma.Web.Router

  clear_config([Pleroma.Web.Metadata, :unfurl_nsfw])

  test "it renders twitter card for user info" do
    user = insert(:user, name: "Jimmy Hendriks", bio: "born 19 March 1994")
    avatar_url = Utils.attachment_url(User.avatar_url(user))
    res = TwitterCard.build_tags(%{user: user})

    assert res == [
             {:meta, [property: "twitter:title", content: Utils.user_name_string(user)], []},
             {:meta, [property: "twitter:description", content: "born 19 March 1994"], []},
             {:meta, [property: "twitter:image", content: avatar_url], []},
             {:meta, [property: "twitter:card", content: "summary"], []}
           ]
  end

  test "it uses summary twittercard if post has no attachment" do
    user = insert(:user, name: "Jimmy Hendriks", bio: "born 19 March 1994")
    {:ok, activity} = CommonAPI.post(user, %{"status" => "HI"})

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "tag" => [],
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "pleroma in a nutshell"
        }
      })

    result = TwitterCard.build_tags(%{object: note, user: user, activity_id: activity.id})

    assert [
             {:meta, [property: "twitter:title", content: Utils.user_name_string(user)], []},
             {:meta, [property: "twitter:description", content: "“pleroma in a nutshell”"], []},
             {:meta, [property: "twitter:image", content: "http://localhost:4001/images/avi.png"],
              []},
             {:meta, [property: "twitter:card", content: "summary"], []}
           ] == result
  end

  test "it renders avatar not attachment if post is nsfw and unfurl_nsfw is disabled" do
    Pleroma.Config.put([Pleroma.Web.Metadata, :unfurl_nsfw], false)
    user = insert(:user, name: "Jimmy Hendriks", bio: "born 19 March 1994")
    {:ok, activity} = CommonAPI.post(user, %{"status" => "HI"})

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "tag" => [],
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "pleroma in a nutshell",
          "sensitive" => true,
          "attachment" => [
            %{
              "url" => [%{"mediaType" => "image/png", "href" => "https://pleroma.gov/tenshi.png"}]
            },
            %{
              "url" => [
                %{
                  "mediaType" => "application/octet-stream",
                  "href" => "https://pleroma.gov/fqa/badapple.sfc"
                }
              ]
            },
            %{
              "url" => [
                %{"mediaType" => "video/webm", "href" => "https://pleroma.gov/about/juche.webm"}
              ]
            }
          ]
        }
      })

    result = TwitterCard.build_tags(%{object: note, user: user, activity_id: activity.id})

    assert [
             {:meta, [property: "twitter:title", content: Utils.user_name_string(user)], []},
             {:meta, [property: "twitter:description", content: "“pleroma in a nutshell”"], []},
             {:meta, [property: "twitter:image", content: "http://localhost:4001/images/avi.png"],
              []},
             {:meta, [property: "twitter:card", content: "summary"], []}
           ] == result
  end

  test "it renders supported types of attachments and skips unknown types" do
    user = insert(:user, name: "Jimmy Hendriks", bio: "born 19 March 1994")
    {:ok, activity} = CommonAPI.post(user, %{"status" => "HI"})

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "tag" => [],
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "pleroma in a nutshell",
          "attachment" => [
            %{
              "url" => [%{"mediaType" => "image/png", "href" => "https://pleroma.gov/tenshi.png"}]
            },
            %{
              "url" => [
                %{
                  "mediaType" => "application/octet-stream",
                  "href" => "https://pleroma.gov/fqa/badapple.sfc"
                }
              ]
            },
            %{
              "url" => [
                %{"mediaType" => "video/webm", "href" => "https://pleroma.gov/about/juche.webm"}
              ]
            }
          ]
        }
      })

    result = TwitterCard.build_tags(%{object: note, user: user, activity_id: activity.id})

    assert [
             {:meta, [property: "twitter:title", content: Utils.user_name_string(user)], []},
             {:meta, [property: "twitter:description", content: "“pleroma in a nutshell”"], []},
             {:meta, [property: "twitter:card", content: "summary_large_image"], []},
             {:meta, [property: "twitter:player", content: "https://pleroma.gov/tenshi.png"], []},
             {:meta, [property: "twitter:card", content: "player"], []},
             {:meta,
              [
                property: "twitter:player",
                content: Router.Helpers.o_status_url(Endpoint, :notice_player, activity.id)
              ], []},
             {:meta, [property: "twitter:player:width", content: "480"], []},
             {:meta, [property: "twitter:player:height", content: "480"], []}
           ] == result
  end
end
