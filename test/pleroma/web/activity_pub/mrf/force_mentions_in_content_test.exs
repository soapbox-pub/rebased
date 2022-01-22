# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMentionsInContentTest do
  alias Pleroma.Web.ActivityPub.MRF.ForceMentionsInContent
  import Pleroma.Factory
  use Pleroma.DataCase

  test "adds mentions to post content" do
    users = %{
      "lain@lain.com" => "https://lain.com/users/lain",
      "coolboymew@shitposter.club" => "https://shitposter.club/users/coolboymew",
      "dielan@shitposter.club" => "https://shitposter.club/users/dielan",
      "hakui@tuusin.misono-ya.info" => "https://tuusin.misono-ya.info/users/hakui",
      "fence@xyzzy.link" => "https://xyzzy.link/users/fence"
    }

    Enum.each(users, fn {nickname, ap_id} ->
      insert(:user, ap_id: ap_id, nickname: nickname, local: false)
    end)

    object = File.read!("test/fixtures/soapbox_no_mentions_in_content.json") |> Jason.decode!()

    activity = %{
      "type" => "Create",
      "actor" => "https://gleasonator.com/users/alex",
      "object" => object
    }

    {:ok, %{"object" => %{"content" => filtered}}} = ForceMentionsInContent.filter(activity)
    Enum.each(users, fn {nickname, _} -> assert filtered =~ nickname end)
  end
end
