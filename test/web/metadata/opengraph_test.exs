# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.OpenGraphTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.Metadata.Providers.OpenGraph

  clear_config([Pleroma.Web.Metadata, :unfurl_nsfw])

  test "it renders all supported types of attachments and skips unknown types" do
    user = insert(:user)

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "tag" => [],
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "pleroma in a nutshell",
          "attachment" => [
            %{
              "url" => [
                %{"mediaType" => "image/png", "href" => "https://pleroma.gov/tenshi.png"}
              ]
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
            },
            %{
              "url" => [
                %{
                  "mediaType" => "audio/basic",
                  "href" => "http://www.gnu.org/music/free-software-song.au"
                }
              ]
            }
          ]
        }
      })

    result = OpenGraph.build_tags(%{object: note, url: note.data["id"], user: user})

    assert Enum.all?(
             [
               {:meta, [property: "og:image", content: "https://pleroma.gov/tenshi.png"], []},
               {:meta,
                [property: "og:audio", content: "http://www.gnu.org/music/free-software-song.au"],
                []},
               {:meta, [property: "og:video", content: "https://pleroma.gov/about/juche.webm"],
                []}
             ],
             fn element -> element in result end
           )
  end

  test "it does not render attachments if post is nsfw" do
    Pleroma.Config.put([Pleroma.Web.Metadata, :unfurl_nsfw], false)
    user = insert(:user, avatar: %{"url" => [%{"href" => "https://pleroma.gov/tenshi.png"}]})

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "#cuteposting #nsfw #hambaga",
          "tag" => ["cuteposting", "nsfw", "hambaga"],
          "sensitive" => true,
          "attachment" => [
            %{
              "url" => [
                %{"mediaType" => "image/png", "href" => "https://misskey.microsoft/corndog.png"}
              ]
            }
          ]
        }
      })

    result = OpenGraph.build_tags(%{object: note, url: note.data["id"], user: user})

    assert {:meta, [property: "og:image", content: "https://pleroma.gov/tenshi.png"], []} in result

    refute {:meta, [property: "og:image", content: "https://misskey.microsoft/corndog.png"], []} in result
  end
end
