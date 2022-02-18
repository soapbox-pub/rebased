# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.BlockNotificationPolicyTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.MRF.BlockNotificationPolicy

  import Pleroma.Factory

  setup do:
          clear_config(:mrf_block_notification_policy,
            message: "@{actor} {action} @{target}",
            user: "beholder",
            visibility: "public"
          )

  setup do
    %{
      beholder: insert(:user, nickname: "beholder"),
      butthurt: insert(:user, nickname: "butthurt"),
      sneed: insert(:user, nickname: "sneed")
    }
  end

  test "creates messages when user blocks other user", %{
    butthurt: butthurt,
    sneed: sneed,
    beholder: beholder
  } do
    activities = ActivityPub.fetch_user_activities(beholder, beholder, %{})
    assert length(activities) == 0

    message = %{
      "type" => "Block",
      "object" => sneed.ap_id,
      "actor" => butthurt.ap_id
    }

    assert {:ok, _object} = BlockNotificationPolicy.filter(message)

    activities = ActivityPub.fetch_user_activities(beholder, beholder, %{})
    assert length(activities) == 1

    [head | _tail] = activities

    assert head.object.data["source"] == "@butthurt blocked @sneed"
  end

  test "creates messages when user unblocks other user", %{
    butthurt: butthurt,
    sneed: sneed,
    beholder: beholder
  } do
    activities = ActivityPub.fetch_user_activities(beholder, beholder, %{})
    assert length(activities) == 0

    message = %{
      "type" => "Undo",
      "object" => %{"type" => "Block", "object" => sneed.ap_id},
      "actor" => butthurt.ap_id
    }

    assert {:ok, _object} = BlockNotificationPolicy.filter(message)

    activities = ActivityPub.fetch_user_activities(beholder, beholder, %{})
    assert length(activities) == 1

    [head | _tail] = activities

    assert head.object.data["source"] == "@butthurt unblocked @sneed"
  end

  test "creates no message when the action type isn't block or unblock", %{
    butthurt: butthurt,
    sneed: sneed,
    beholder: beholder
  } do
    activities = ActivityPub.fetch_user_activities(beholder, beholder, %{})
    assert length(activities) == 0

    message = %{
      "type" => "Note",
      "object" => sneed.ap_id,
      "actor" => butthurt.ap_id
    }

    assert {:ok, _object} = BlockNotificationPolicy.filter(message)

    activities = ActivityPub.fetch_user_activities(beholder, beholder, %{})
    assert length(activities) == 0
  end
end
