# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.DatabaseTest do
  alias Pleroma.Repo
  alias Pleroma.User
  use Pleroma.DataCase

  import Pleroma.Factory

  setup_all do
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
    end)

    :ok
  end

  describe "running update_users_following_followers_counts" do
    test "following and followers count are updated" do
      [user, user2] = insert_pair(:user)
      {:ok, %User{following: following, info: info} = user} = User.follow(user, user2)

      assert length(following) == 2
      assert info.follower_count == 0

      info_cng = Ecto.Changeset.change(info, %{follower_count: 3})

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{following: following ++ following})
        |> Ecto.Changeset.put_embed(:info, info_cng)
        |> Repo.update()

      assert length(user.following) == 4
      assert user.info.follower_count == 3

      assert :ok == Mix.Tasks.Pleroma.Database.run(["update_users_following_followers_counts"])

      user = User.get_by_id(user.id)

      assert length(user.following) == 2
      assert user.info.follower_count == 0
    end
  end
end
