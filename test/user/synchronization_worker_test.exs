# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.SynchronizationWorkerTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  setup do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    config = Pleroma.Config.get([:instance, :external_user_synchronization])

    for_update = [enabled: true, interval: 1000]

    Pleroma.Config.put([:instance, :external_user_synchronization], for_update)

    on_exit(fn ->
      Pleroma.Config.put([:instance, :external_user_synchronization], config)
    end)

    :ok
  end

  test "sync follow counters" do
    user1 =
      insert(:user,
        local: false,
        ap_id: "http://localhost:4001/users/masto_closed"
      )

    user2 = insert(:user, local: false, ap_id: "http://localhost:4001/users/fuser2")

    {:ok, _} = Pleroma.User.SynchronizationWorker.start_link()
    :timer.sleep(1500)

    %{follower_count: followers, following_count: following} =
      Pleroma.User.get_cached_user_info(user1)

    assert followers == 437
    assert following == 152

    %{follower_count: followers, following_count: following} =
      Pleroma.User.get_cached_user_info(user2)

    assert followers == 527
    assert following == 267
  end
end
