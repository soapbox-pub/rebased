# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.DatabaseTest do
  alias Pleroma.Activity
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

  describe "running remove_embedded_objects" do
    test "it replaces objects with references" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "test"})
      new_data = Map.put(activity.data, "object", activity.object.data)

      {:ok, activity} =
        activity
        |> Activity.change(%{data: new_data})
        |> Repo.update()

      assert is_map(activity.data["object"])

      Mix.Tasks.Pleroma.Database.run(["remove_embedded_objects"])

      activity = Activity.get_by_id_with_object(activity.id)
      assert is_binary(activity.data["object"])
    end
  end

  describe "prune_objects" do
    test "it prunes old objects from the database" do
      insert(:note)
      deadline = Pleroma.Config.get([:instance, :remote_post_retention_days]) + 1

      date =
        Timex.now()
        |> Timex.shift(days: -deadline)
        |> Timex.to_naive_datetime()
        |> NaiveDateTime.truncate(:second)

      %{id: id} =
        :note
        |> insert()
        |> Ecto.Changeset.change(%{inserted_at: date})
        |> Repo.update!()

      assert length(Repo.all(Object)) == 2

      Mix.Tasks.Pleroma.Database.run(["prune_objects"])

      assert length(Repo.all(Object)) == 1
      refute Object.get_by_id(id)
    end
  end

  describe "running update_users_following_followers_counts" do
    test "following and followers count are updated" do
      [user, user2] = insert_pair(:user)
      {:ok, %User{} = user} = User.follow(user, user2)

      following = User.following(user)

      assert length(following) == 2
      assert user.follower_count == 0

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{follower_count: 3})
        |> Repo.update()

      assert user.follower_count == 3

      assert :ok == Mix.Tasks.Pleroma.Database.run(["update_users_following_followers_counts"])

      user = User.get_by_id(user.id)

      assert length(User.following(user)) == 2
      assert user.follower_count == 0
    end
  end

  describe "running fix_likes_collections" do
    test "it turns OrderedCollection likes into empty arrays" do
      [user, user2] = insert_pair(:user)

      {:ok, %{id: id, object: object}} = CommonAPI.post(user, %{"status" => "test"})
      {:ok, %{object: object2}} = CommonAPI.post(user, %{"status" => "test test"})

      CommonAPI.favorite(user2, id)

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
