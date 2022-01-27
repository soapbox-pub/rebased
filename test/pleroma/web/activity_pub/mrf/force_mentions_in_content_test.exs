# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMentionsInContentTest do
  use Pleroma.DataCase
  require Pleroma.Constants

  alias Pleroma.Constants
  alias Pleroma.Object
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
end
