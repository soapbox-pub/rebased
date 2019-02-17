# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.HellthreadPolicyTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  import Pleroma.Web.ActivityPub.MRF.HellthreadPolicy

  describe "hellthread filter tests" do
    setup do
      user = insert(:user)

      message = %{
        "actor" => user.ap_id,
        "cc" => [user.follower_address],
        "type" => "Create",
        "to" => [
          "https://www.w3.org/ns/activitystreams#Public",
          "https://instace.tld/users/user1",
          "https://instace.tld/users/user2",
          "https://instace.tld/users/user3"
        ]
      }

      [user: user, message: message]
    end

    test "reject test", %{message: message} do
      Pleroma.Config.put([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 2})

      {:reject, nil} = filter(message)
    end

    test "delist test", %{user: user, message: message} do
      Pleroma.Config.put([:mrf_hellthread], %{delist_threshold: 2, reject_threshold: 0})

      {:ok, message} = filter(message)
      assert user.follower_address in message["to"]
      assert "https://www.w3.org/ns/activitystreams#Public" in message["cc"]
    end

    test "excludes follower collection and public URI from threshold count", %{message: message} do
      Pleroma.Config.put([:mrf_hellthread], %{delist_threshold: 0, reject_threshold: 3})

      {:ok, _} = filter(message)
    end
  end
end
