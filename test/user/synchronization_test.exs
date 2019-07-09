# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.SynchronizationTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.User
  alias Pleroma.User.Synchronization

  setup do
    Tesla.Mock.mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "update following/followers counters" do
    user1 =
      insert(:user,
        local: false,
        ap_id: "http://localhost:4001/users/masto_closed"
      )

    user2 = insert(:user, local: false, ap_id: "http://localhost:4001/users/fuser2")

    users = User.external_users()
    assert length(users) == 2
    {user, %{}} = Synchronization.call(users, %{})
    assert user == List.last(users)

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user1)
    assert followers == 437
    assert following == 152

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user2)

    assert followers == 527
    assert following == 267
  end

  test "don't check host if errors exist" do
    user1 = insert(:user, local: false, ap_id: "http://domain-with-errors:4001/users/fuser1")

    user2 = insert(:user, local: false, ap_id: "http://domain-with-errors:4001/users/fuser2")

    users = User.external_users()
    assert length(users) == 2

    {user, %{"domain-with-errors" => 2}} =
      Synchronization.call(users, %{"domain-with-errors" => 2}, max_retries: 2)

    assert user == List.last(users)

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user1)
    assert followers == 0
    assert following == 0

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user2)

    assert followers == 0
    assert following == 0
  end

  test "don't check host if errors appeared" do
    user1 = insert(:user, local: false, ap_id: "http://domain-with-errors:4001/users/fuser1")

    user2 = insert(:user, local: false, ap_id: "http://domain-with-errors:4001/users/fuser2")

    users = User.external_users()
    assert length(users) == 2

    {user, %{"domain-with-errors" => 2}} = Synchronization.call(users, %{}, max_retries: 2)

    assert user == List.last(users)

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user1)
    assert followers == 0
    assert following == 0

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user2)

    assert followers == 0
    assert following == 0
  end

  test "other users after error appeared" do
    user1 = insert(:user, local: false, ap_id: "http://domain-with-errors:4001/users/fuser1")
    user2 = insert(:user, local: false, ap_id: "http://localhost:4001/users/fuser2")

    users = User.external_users()
    assert length(users) == 2

    {user, %{"domain-with-errors" => 2}} = Synchronization.call(users, %{}, max_retries: 2)
    assert user == List.last(users)

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user1)
    assert followers == 0
    assert following == 0

    %{follower_count: followers, following_count: following} = User.get_cached_user_info(user2)

    assert followers == 527
    assert following == 267
  end
end
