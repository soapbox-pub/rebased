# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiMentionSpamPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.ActivityPub.MRF.AntiMentionSpamPolicy

  test "it allows posts without mentions" do
    user = insert(:user, local: false)
    assert user.note_count == 0

    message = %{
      "type" => "Create",
      "actor" => user.ap_id
    }

    {:ok, _message} = AntiMentionSpamPolicy.filter(message)
  end

  test "it allows posts from users with followers, posts, and age" do
    user =
      insert(:user,
        local: false,
        follower_count: 1,
        note_count: 1,
        inserted_at: ~N[1970-01-01 00:00:00]
      )

    message = %{
      "type" => "Create",
      "actor" => user.ap_id
    }

    {:ok, _message} = AntiMentionSpamPolicy.filter(message)
  end

  test "it allows posts from local users" do
    user = insert(:user, local: true)

    message = %{
      "type" => "Create",
      "actor" => user.ap_id
    }

    {:ok, _message} = AntiMentionSpamPolicy.filter(message)
  end

  test "it rejects posts with mentions from users without followers" do
    user = insert(:user, local: false, follower_count: 0)

    message = %{
      "type" => "Create",
      "actor" => user.ap_id,
      "object" => %{
        "to" => ["https://pleroma.soykaf.com/users/1"],
        "cc" => ["https://pleroma.soykaf.com/users/1"],
        "actor" => user.ap_id
      }
    }

    {:reject, _message} = AntiMentionSpamPolicy.filter(message)
  end
end
