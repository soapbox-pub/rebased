# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMentionsInContentTest do
  alias Pleroma.Web.ActivityPub.MRF.ForceMentionsInContent
  import Pleroma.Factory
  use Pleroma.DataCase

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
             "<span class=\"recipients-inline\"><span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{lain.id}\" href=\"https://lain.com/users/lain\" rel=\"ugc\">@<span>lain</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{coolboymew.id}\" href=\"https://shitposter.club/users/coolboymew\" rel=\"ugc\">@<span>coolboymew</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{dielan.id}\" href=\"https://shitposter.club/users/dielan\" rel=\"ugc\">@<span>dielan</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{hakui.id}\" href=\"https://tuusin.misono-ya.info/users/hakui\" rel=\"ugc\">@<span>hakui</span></a></span> <span class=\"h-card\"><a class=\"u-url mention\" data-user=\"#{fence.id}\" href=\"https://xyzzy.link/users/fence\" rel=\"ugc\">@<span>fence</span></a></span> </span><p>Haha yeah, you can control who you reply to.</p>"
  end
end
