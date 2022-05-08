# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiFollowbotPolicyTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory

  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.MRF.AntiFollowbotPolicy

  describe "blocking based on attributes" do
    test "matches followbots by nickname" do
      actor = insert(:user, %{nickname: "followbot@example.com"})
      target = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Follow",
        "actor" => actor.ap_id,
        "object" => target.ap_id,
        "id" => "https://example.com/activities/1234"
      }

      assert {:reject, "[AntiFollowbotPolicy]" <> _} = AntiFollowbotPolicy.filter(message)
    end

    test "matches followbots by display name" do
      actor = insert(:user, %{name: "Federation Bot"})
      target = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Follow",
        "actor" => actor.ap_id,
        "object" => target.ap_id,
        "id" => "https://example.com/activities/1234"
      }

      assert {:reject, "[AntiFollowbotPolicy]" <> _} = AntiFollowbotPolicy.filter(message)
    end

    test "matches followbots by actor_type" do
      actor = insert(:user, %{actor_type: "Service"})
      target = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Follow",
        "actor" => actor.ap_id,
        "object" => target.ap_id,
        "id" => "https://example.com/activities/1234"
      }

      assert {:reject, "[AntiFollowbotPolicy]" <> _} = AntiFollowbotPolicy.filter(message)
    end
  end

  describe "it allows" do
    test "non-followbots" do
      actor = insert(:user)
      target = insert(:user)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Follow",
        "actor" => actor.ap_id,
        "object" => target.ap_id,
        "id" => "https://example.com/activities/1234"
      }

      {:ok, _} = AntiFollowbotPolicy.filter(message)
    end

    test "bots if the target follows the bots" do
      actor = insert(:user, %{actor_type: "Service"})
      target = insert(:user)

      User.follow(target, actor)

      message = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "type" => "Follow",
        "actor" => actor.ap_id,
        "object" => target.ap_id,
        "id" => "https://example.com/activities/1234"
      }

      {:ok, _} = AntiFollowbotPolicy.filter(message)
    end
  end

  test "it gracefully handles nil display names" do
    actor = insert(:user, %{name: nil})
    target = insert(:user)

    message = %{
      "@context" => "https://www.w3.org/ns/activitystreams",
      "type" => "Follow",
      "actor" => actor.ap_id,
      "object" => target.ap_id,
      "id" => "https://example.com/activities/1234"
    }

    {:ok, _} = AntiFollowbotPolicy.filter(message)
  end
end
