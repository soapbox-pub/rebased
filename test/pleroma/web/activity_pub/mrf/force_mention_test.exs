# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.ForceMentionTest do
  use Pleroma.DataCase
  require Pleroma.Constants

  alias Pleroma.Web.ActivityPub.MRF.ForceMention

  import Pleroma.Factory

  test "adds mention to a reply" do
    lain =
      insert(:user, ap_id: "https://lain.com/users/lain", nickname: "lain@lain.com", local: false)

    niobleoum =
      insert(:user,
        ap_id: "https://www.minds.com/api/activitypub/users/1198929502760083472",
        nickname: "niobleoum@minds.com",
        local: false
      )

    status = File.read!("test/fixtures/minds-pleroma-mentioned-post.json") |> Jason.decode!()

    status_activity = %{
      "type" => "Create",
      "actor" => lain.ap_id,
      "object" => status
    }

    Pleroma.Web.ActivityPub.Transmogrifier.handle_incoming(status_activity)

    reply = File.read!("test/fixtures/minds-invalid-mention-post.json") |> Jason.decode!()

    reply_activity = %{
      "type" => "Create",
      "actor" => niobleoum.ap_id,
      "object" => reply
    }

    {:ok, %{"object" => %{"tag" => tag}}} = ForceMention.filter(reply_activity)

    assert Enum.find(tag, fn %{"href" => href} -> href == lain.ap_id end)
  end

  test "adds mention to a quote" do
    user1 = insert(:user, ap_id: "https://misskey.io/users/83ssedkv53")
    user2 = insert(:user, ap_id: "https://misskey.io/users/7rkrarq81i")

    status = File.read!("test/fixtures/tesla_mock/misskey.io_8vs6wxufd0.json") |> Jason.decode!()

    status_activity = %{
      "type" => "Create",
      "actor" => user1.ap_id,
      "object" => status
    }

    Pleroma.Web.ActivityPub.Transmogrifier.handle_incoming(status_activity)

    quote_post = File.read!("test/fixtures/quote_post/misskey_quote_post.json") |> Jason.decode!()

    quote_activity = %{
      "type" => "Create",
      "actor" => user2.ap_id,
      "object" => quote_post
    }

    {:ok, %{"object" => %{"tag" => tag}}} = ForceMention.filter(quote_activity)

    assert Enum.find(tag, fn %{"href" => href} -> href == user1.ap_id end)
  end
end
