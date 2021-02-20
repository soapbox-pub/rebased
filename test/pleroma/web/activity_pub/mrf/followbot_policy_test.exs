# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.FollowbotPolicyTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF.FollowbotPolicy

  import Pleroma.Factory

  describe "FollowBotPolicy" do
    test "follows remote users" do
      bot = insert(:user, actor_type: "Service")
      remote_user = insert(:user, local: false)
      clear_config([:mrf_follow_bot, :follower_nickname], bot.nickname)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "to" => [remote_user.follower_address],
        "cc" => ["https://www.w3.org/ns/activitystreams#Public"],
        "type" => "Create",
        "object" => %{
          "content" => "Test post",
          "type" => "Note",
          "attributedTo" => remote_user.ap_id,
          "inReplyTo" => nil
        },
        "actor" => remote_user.ap_id
      }

      refute User.following?(bot, remote_user)

      assert User.get_follow_requests(remote_user) |> length == 0

      FollowbotPolicy.filter(message)

      assert User.get_follow_requests(remote_user) |> length == 1
    end
  end
end
