# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.AntiFollowbotPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

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

      {:reject, nil} = AntiFollowbotPolicy.filter(message)
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

      {:reject, nil} = AntiFollowbotPolicy.filter(message)
    end
  end

  test "it allows non-followbots" do
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
