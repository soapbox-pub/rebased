# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.DatabaseTest do
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

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

  describe "running fix_likes_collections" do
    test "it turns OrderedCollection likes into empty arrays" do
      [user, user2] = insert_pair(:user)

      {:ok, %{id: id, object: object}} = CommonAPI.post(user, %{"status" => "test"})
      {:ok, %{object: object2}} = CommonAPI.post(user, %{"status" => "test test"})

      CommonAPI.favorite(id, user2)

      likes = %{
        "first" =>
          "http://mastodon.example.org/objects/dbdbc507-52c8-490d-9b7c-1e1d52e5c132/likes?page=1",
        "id" => "http://mastodon.example.org/objects/dbdbc507-52c8-490d-9b7c-1e1d52e5c132/likes",
        "totalItems" => 3,
        "type" => "OrderedCollection"
      }

      new_data = Map.put(object2.data, "likes", likes)

      object2
      |> Ecto.Changeset.change(%{data: new_data})
      |> Repo.update()

      assert length(Object.get_by_id(object.id).data["likes"]) == 1
      assert is_map(Object.get_by_id(object2.id).data["likes"])

      assert :ok == Mix.Tasks.Pleroma.Database.run(["fix_likes_collections"])

      assert length(Object.get_by_id(object.id).data["likes"]) == 1
      assert Enum.empty?(Object.get_by_id(object2.id).data["likes"])
    end
  end
end
