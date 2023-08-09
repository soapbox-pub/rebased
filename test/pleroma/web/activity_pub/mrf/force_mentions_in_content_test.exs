# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMentionsInContentTest do
  use Pleroma.DataCase
  require Pleroma.Constants

  alias Pleroma.Constants
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.MRF.ForceMentionsInContent
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "adds mentions to post content" do
    [lain, coolboymew, dielan, hakui, fence] = [
      insert(:user, ap_id: "https://lain.com/users/lain", nickname: "lain@lain.com", local: false),
      insert(:user,
        ap_id: "https://shitposter.club/users/coolboymew",
        nickname: "coolboymew@shitposter.club",
        local: false
      ),
      insert(:user,
        ap_id: "https://shitposter.club/users/dielan",
        nickname: "dielan@shitposter.club",
        local: false
      ),
      insert(:user,
        ap_id: "https://tuusin.misono-ya.info/users/hakui",
        nickname: "hakui@tuusin.misono-ya.info",
        local: false
      ),
      insert(:user,
        ap_id: "https://xyzzy.link/users/fence",
        nickname: "fence@xyzzy.link",
        local: false
      )
    ]

    object = File.read!("test/fixtures/soapbox_no_mentions_in_content.json") |> Jason.decode!()

    activity = %{
      "type" => "Create",
      "actor" => "https://gleasonator.com/users/alex",
      "object" => object
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)

    assert filtered ==
             "<p><span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{dielan.id}\" href=\"https://shitposter.club/users/dielan\" rel=\"ugc\">@<span>dielan</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{coolboymew.id}\" href=\"https://shitposter.club/users/coolboymew\" rel=\"ugc\">@<span>coolboymew</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{fence.id}\" href=\"https://xyzzy.link/users/fence\" rel=\"ugc\">@<span>fence</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{hakui.id}\" href=\"https://tuusin.misono-ya.info/users/hakui\" rel=\"ugc\">@<span>hakui</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{lain.id}\" href=\"https://lain.com/users/lain\" rel=\"ugc\">@<span>lain</span></a></span> </span>Haha yeah, you can control who you reply to.</p>"
  end

  test "the replied-to user is sorted to the left" do
    [mario, luigi, wario] = [
      insert(:user, nickname: "mario"),
      insert(:user, nickname: "luigi"),
      insert(:user, nickname: "wario")
    ]

    {:ok, post1} = CommonAPI.post(mario, %{status: "Letsa go!"})

    {:ok, post2} =
      CommonAPI.post(luigi, %{status: "Oh yaah", in_reply_to_id: post1.id, to: [mario.ap_id]})

    activity = %{
      "type" => "Create",
      "actor" => wario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => wario.ap_id,
        "content" => "WHA-HA!",
        "to" => [
          mario.ap_id,
          luigi.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => Object.normalize(post2).data["id"]
      }
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)

    assert filtered ==
             "<span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{luigi.id}\" href=\"#{luigi.ap_id}\" rel=\"ugc\">@<span>luigi</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{mario.id}\" href=\"#{mario.ap_id}\" rel=\"ugc\">@<span>mario</span></a></span> </span>WHA-HA!"
  end

  test "supports mulitlang" do
    [mario, luigi, wario] = [
      insert(:user, nickname: "mario"),
      insert(:user, nickname: "luigi"),
      insert(:user, nickname: "wario")
    ]

    {:ok, post1} = CommonAPI.post(mario, %{status: "Letsa go!"})

    {:ok, post2} =
      CommonAPI.post(luigi, %{status: "Oh yaah", in_reply_to_id: post1.id, to: [mario.ap_id]})

    activity = %{
      "type" => "Create",
      "actor" => wario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => wario.ap_id,
        "content" => "WHA-HA!",
        "contentMap" => %{
          "a" => "mew mew",
          "b" => "lol lol"
        },
        "to" => [
          mario.ap_id,
          luigi.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => Object.normalize(post2).data["id"]
      }
    }

    {:ok,
     %{
       "object" => %{
         "content" => content,
         "contentMap" =>
           %{
             "a" => content_a,
             "b" => content_b
           } = content_map
       }
     }} = ForceMentionsInContent.filter(activity)

    mentions_part =
      "<span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{luigi.id}\" href=\"#{luigi.ap_id}\" rel=\"ugc\">@<span>luigi</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{mario.id}\" href=\"#{mario.ap_id}\" rel=\"ugc\">@<span>mario</span></a></span> </span>"

    assert content_a == mentions_part <> "mew mew"
    assert content_b == mentions_part <> "lol lol"
    assert content == Pleroma.MultiLanguage.map_to_str(content_map, multiline: true)
  end

  test "don't mention self" do
    mario = insert(:user, nickname: "mario")

    {:ok, post} = CommonAPI.post(mario, %{status: "Mama mia"})

    activity = %{
      "type" => "Create",
      "actor" => mario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => mario.ap_id,
        "content" => "I'ma tired...",
        "to" => [
          mario.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)
    assert filtered == "I'ma tired..."
  end

  test "don't mention in top-level posts" do
    mario = insert(:user, nickname: "mario")
    luigi = insert(:user, nickname: "luigi")

    {:ok, post} = CommonAPI.post(mario, %{status: "Letsa go"})

    activity = %{
      "type" => "Create",
      "actor" => mario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => mario.ap_id,
        "content" => "Mama mia!",
        "to" => [
          luigi.ap_id,
          Constants.as_public()
        ],
        "quoteUrl" => Object.normalize(post).data["id"]
      }
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)
    assert filtered == "Mama mia!"
  end

  test "with markdown formatting" do
    mario = insert(:user, nickname: "mario")
    luigi = insert(:user, nickname: "luigi")

    {:ok, post} = CommonAPI.post(luigi, %{status: "Mama mia"})

    activity = %{
      "type" => "Create",
      "actor" => mario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => mario.ap_id,
        "content" => "<p>I'ma tired...</p>",
        "to" => [
          luigi.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)

    assert filtered ==
             "<p><span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{luigi.id}\" href=\"#{luigi.ap_id}\" rel=\"ugc\">@<span>luigi</span></a></span> </span>I'ma tired...</p>"
  end

  test "aware of history" do
    mario = insert(:user, nickname: "mario")
    wario = insert(:user, nickname: "wario")

    {:ok, post1} = CommonAPI.post(mario, %{status: "Letsa go!"})

    activity = %{
      "type" => "Create",
      "actor" => wario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => wario.ap_id,
        "content" => "WHA-HA!",
        "to" => [
          mario.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => post1.object.data["id"],
        "formerRepresentations" => %{
          "orderedItems" => [
            %{
              "type" => "Note",
              "actor" => wario.ap_id,
              "content" => "WHA-HA!",
              "to" => [
                mario.ap_id,
                Constants.as_public()
              ],
              "inReplyTo" => post1.object.data["id"]
            }
          ]
        }
      }
    }

    expected =
      "<span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{mario.id}\" href=\"#{mario.ap_id}\" rel=\"ugc\">@<span>mario</span></a></span> </span>WHA-HA!"

    assert {:ok,
            %{
              "object" => %{
                "content" => ^expected,
                "formerRepresentations" => %{"orderedItems" => [%{"content" => ^expected}]}
              }
            }} = MRF.filter_one(ForceMentionsInContent, activity)
  end

  test "works with Updates" do
    mario = insert(:user, nickname: "mario")
    wario = insert(:user, nickname: "wario")

    {:ok, post1} = CommonAPI.post(mario, %{status: "Letsa go!"})

    activity = %{
      "type" => "Update",
      "actor" => wario.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => wario.ap_id,
        "content" => "WHA-HA!",
        "to" => [
          mario.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => post1.object.data["id"],
        "formerRepresentations" => %{
          "orderedItems" => [
            %{
              "type" => "Note",
              "actor" => wario.ap_id,
              "content" => "WHA-HA!",
              "to" => [
                mario.ap_id,
                Constants.as_public()
              ],
              "inReplyTo" => post1.object.data["id"]
            }
          ]
        }
      }
    }

    expected =
      "<span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{mario.id}\" href=\"#{mario.ap_id}\" rel=\"ugc\">@<span>mario</span></a></span> </span>WHA-HA!"

    assert {:ok,
            %{
              "object" => %{
                "content" => ^expected,
                "formerRepresentations" => %{"orderedItems" => [%{"content" => ^expected}]}
              }
            }} = MRF.filter_one(ForceMentionsInContent, activity)
  end

  test "don't add duplicate mentions for mastodon or misskey posts" do
    [zero, rogerick, greg] = [
      insert(:user,
        ap_id: "https://pleroma.example.com/users/zero",
        uri: "https://pleroma.example.com/users/zero",
        nickname: "zero@pleroma.example.com",
        local: false
      ),
      insert(:user,
        ap_id: "https://misskey.example.com/users/104ab42f11",
        uri: "https://misskey.example.com/@rogerick",
        nickname: "rogerick@misskey.example.com",
        local: false
      ),
      insert(:user,
        ap_id: "https://mastodon.example.com/users/greg",
        uri: "https://mastodon.example.com/@greg",
        nickname: "greg@mastodon.example.com",
        local: false
      )
    ]

    {:ok, post} = CommonAPI.post(rogerick, %{status: "eugh"})

    inline_mentions = [
      "<span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{rogerick.id}\" href=\"#{rogerick.ap_id}\" rel=\"ugc\">@<span>rogerick</span></a></span>",
      "<span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{greg.id}\" href=\"#{greg.uri}\" rel=\"ugc\">@<span>greg</span></a></span>"
    ]

    activity = %{
      "type" => "Create",
      "actor" => zero.ap_id,
      "object" => %{
        "type" => "Note",
        "actor" => zero.ap_id,
        "content" => "#{Enum.at(inline_mentions, 0)} #{Enum.at(inline_mentions, 1)} erm",
        "to" => [
          rogerick.ap_id,
          greg.ap_id,
          Constants.as_public()
        ],
        "inReplyTo" => Object.normalize(post).data["id"]
      }
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)

    assert filtered ==
             "#{Enum.at(inline_mentions, 0)} #{Enum.at(inline_mentions, 1)} erm"
  end
end
