# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  import Pleroma.Web.ActivityPub.MRF.HellthreadPolicy

  alias Pleroma.Web.CommonAPI

  setup do
    user = insert(:user)

    message = %{
      "actor" => user.ap_id,
      "cc" => [user.follower_address],
      "type" => "Create",
      "to" => [
        "https://www.w3.org/ns/activitystreams#Public",
        "https://instance.tld/users/user1",
        "https://instance.tld/users/user2",
        "https://instance.tld/users/user3"
      ],
      "object" => %{
        "type" => "Note"
      }
    }

    [user: user, message: message]
  end

  setup do: clear_config(:mrf_hellthread)

  test "doesn't die on chat messages" do
    clear_config([:mrf_hellthread], %{delist_threshold: 2, reject_threshold: 0})

    user = insert(:user)
    other_user = insert(:user)

    {:ok, activity} = CommonAPI.post_chat_message(user, other_user, "moin")

    assert {:ok, _} = filter(activity.data)
  end

  describe "reject" do
    test "rejects the message if the recipient count is above reject_threshold", %{
      message: message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 2})

      assert {:reject, "[HellthreadPolicy] 3 recipients is over the limit of 2"} ==
               filter(message)
    end

    test "does not reject the message if the recipient count is below reject_threshold", %{
      message: message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 3})

      assert {:ok, ^message} = filter(message)
    end
  end

  describe "delist" do
    test "delists the message if the recipient count is above delist_threshold", %{
      user: user,
      message: message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 2, reject_threshold: 0})

      {:ok, message} = filter(message)
      assert user.follower_address in message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in message["cc"]
    end

    test "does not delist the message if the recipient count is below delist_threshold", %{
      message: message
    } do
      clear_config([:mrf_hellthread], %{delist_threshold: 4, reject_threshold: 0})

      assert {:ok, ^message} = filter(message)
    end
  end

  test "excludes follower collection and public URI from threshold count", %{message: message} do
    clear_config([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 3})

    assert {:ok, ^message} = filter(message)
  end
end
