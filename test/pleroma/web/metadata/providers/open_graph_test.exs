# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Metadata.Providers.OpenGraphTest do
  use Pleroma.DataCase
  import Mox
  import Pleroma.Factory

  alias Pleroma.UnstubbedConfigMock, as: ConfigMock
  alias Pleroma.Web.Metadata.Providers.OpenGraph
  alias Pleroma.Web.Metadata.Utils

  setup do
    ConfigMock
    |> stub_with(Pleroma.Test.StaticConfig)

    :ok
  end

  setup do: clear_config([Pleroma.Web.Metadata, :unfurl_nsfw])

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
                %{
                  "mediaType" => "image/png",
                  "href" => "https://pleroma.gov/tenshi.png",
                  "height" => 1024,
                  "width" => 1280
                }
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
                %{
                  "mediaType" => "video/webm",
                  "href" => "https://pleroma.gov/about/juche.webm",
                  "height" => 600,
                  "width" => 800
                }
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
               {:meta, [property: "og:image:width", content: "1280"], []},
               {:meta, [property: "og:image:height", content: "1024"], []},
               {:meta,
                [property: "og:audio", content: "http://www.gnu.org/music/free-software-song.au"],
                []},
               {:meta, [property: "og:video", content: "https://pleroma.gov/about/juche.webm"],
                []},
               {:meta, [property: "og:video:width", content: "800"], []},
               {:meta, [property: "og:video:height", content: "600"], []}
             ],
             fn element -> element in result end
           )
  end

  test "it does not render attachments if post is nsfw" do
    clear_config([Pleroma.Web.Metadata, :unfurl_nsfw], false)
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

  test "video attachments have image thumbnail with WxH metadata with Preview Proxy enabled" do
    clear_config([:media_proxy, :enabled], true)
    clear_config([:media_preview_proxy, :enabled], true)
    user = insert(:user)

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "test video post",
          "sensitive" => false,
          "attachment" => [
            %{
              "url" => [
                %{
                  "mediaType" => "video/webm",
                  "href" => "https://pleroma.gov/about/juche.webm",
                  "height" => 600,
                  "width" => 800
                }
              ]
            }
          ]
        }
      })

    result = OpenGraph.build_tags(%{object: note, url: note.data["id"], user: user})

    assert {:meta, [property: "og:image:width", content: "800"], []} in result
    assert {:meta, [property: "og:image:height", content: "600"], []} in result

    assert {:meta,
            [
              property: "og:image",
              content:
                "http://localhost:4001/proxy/preview/YyXfYXyaEAGVHVfKF-HRc4GrFMY03Smi7effZ8WKow8/aHR0cHM6Ly9wbGVyb21hLmdvdi9hYm91dC9qdWNoZS53ZWJt/juche.webm"
            ], []} in result
  end

  test "video attachments have no image thumbnail with Preview Proxy disabled" do
    clear_config([:media_proxy, :enabled], true)
    clear_config([:media_preview_proxy, :enabled], false)
    user = insert(:user)

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "id" => "https://pleroma.gov/objects/whatever",
          "content" => "test video post",
          "sensitive" => false,
          "attachment" => [
            %{
              "url" => [
                %{
                  "mediaType" => "video/webm",
                  "href" => "https://pleroma.gov/about/juche.webm",
                  "height" => 600,
                  "width" => 800
                }
              ]
            }
          ]
        }
      })

    result = OpenGraph.build_tags(%{object: note, url: note.data["id"], user: user})

    refute {:meta, [property: "og:image:width", content: "800"], []} in result
    refute {:meta, [property: "og:image:height", content: "600"], []} in result

    refute {:meta,
            [
              property: "og:image",
              content:
                "http://localhost:4001/proxy/preview/LzAnlke-l5oZbNzWsrHfprX1rGw/aHR0cHM6Ly9wbGVyb21hLmdvdi9hYm91dC9qdWNoZS53ZWJt/juche.webm"
            ], []} in result
  end

  test "meta tag ordering matches attachment order" do
    user = insert(:user, name: "Jimmy Hendriks", bio: "born 19 March 1994")

    note =
      insert(:note, %{
        data: %{
          "actor" => user.ap_id,
          "tag" => [],
          "id" => "https://pleroma.gov/objects/whatever",
          "summary" => "",
          "content" => "pleroma in a nutshell",
          "attachment" => [
            %{
              "url" => [
                %{
                  "mediaType" => "image/png",
                  "href" => "https://example.com/first.png",
                  "height" => 1024,
                  "width" => 1280
                }
              ]
            },
            %{
              "url" => [
                %{
                  "mediaType" => "image/png",
                  "href" => "https://example.com/second.png",
                  "height" => 1024,
                  "width" => 1280
                }
              ]
            }
          ]
        }
      })

    result = OpenGraph.build_tags(%{object: note, url: note.data["id"], user: user})

    assert [
             {:meta, [property: "og:title", content: Utils.user_name_string(user)], []},
             {:meta, [property: "og:url", content: "https://pleroma.gov/objects/whatever"], []},
             {:meta, [property: "og:description", content: "pleroma in a nutshell"], []},
             {:meta, [property: "og:type", content: "article"], []},
             {:meta, [property: "og:image", content: "https://example.com/first.png"], []},
             {:meta, [property: "og:image:alt", content: nil], []},
             {:meta, [property: "og:image:width", content: "1280"], []},
             {:meta, [property: "og:image:height", content: "1024"], []},
             {:meta, [property: "og:image", content: "https://example.com/second.png"], []},
             {:meta, [property: "og:image:alt", content: nil], []},
             {:meta, [property: "og:image:width", content: "1280"], []},
             {:meta, [property: "og:image:height", content: "1024"], []}
           ] == result
  end
end
