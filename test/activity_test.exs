# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.ThreadMute
  import Pleroma.Factory

  test "returns an activity by it's AP id" do
    activity = insert(:note_activity)
    found_activity = Activity.get_by_ap_id(activity.data["id"])

    assert activity == found_activity
  end

  test "returns activities by it's objects AP ids" do
    activity = insert(:note_activity)
    object_data = Object.normalize(activity).data

    [found_activity] = Activity.get_all_create_by_object_ap_id(object_data["id"])

    assert activity == found_activity
  end

  test "returns the activity that created an object" do
    activity = insert(:note_activity)
    object_data = Object.normalize(activity).data

    found_activity = Activity.get_create_by_object_ap_id(object_data["id"])

    assert activity == found_activity
  end

  test "preloading a bookmark" do
    user = insert(:user)
    user2 = insert(:user)
    user3 = insert(:user)
    activity = insert(:note_activity)
    {:ok, _bookmark} = Bookmark.create(user.id, activity.id)
    {:ok, _bookmark2} = Bookmark.create(user2.id, activity.id)
    {:ok, bookmark3} = Bookmark.create(user3.id, activity.id)

    queried_activity =
      Ecto.Query.from(Pleroma.Activity)
      |> Activity.with_preloaded_bookmark(user3)
      |> Repo.one()

    assert queried_activity.bookmark == bookmark3
  end

  test "setting thread_muted?" do
    activity = insert(:note_activity)
    user = insert(:user)
    annoyed_user = insert(:user)
    {:ok, _} = ThreadMute.add_mute(annoyed_user.id, activity.data["context"])

    activity_with_unset_thread_muted_field =
      Ecto.Query.from(Activity)
      |> Repo.one()

    activity_for_user =
      Ecto.Query.from(Activity)
      |> Activity.with_set_thread_muted_field(user)
      |> Repo.one()

    activity_for_annoyed_user =
      Ecto.Query.from(Activity)
      |> Activity.with_set_thread_muted_field(annoyed_user)
      |> Repo.one()

    assert activity_with_unset_thread_muted_field.thread_muted? == nil
    assert activity_for_user.thread_muted? == false
    assert activity_for_annoyed_user.thread_muted? == true
  end

  describe "getting a bookmark" do
    test "when association is loaded" do
      user = insert(:user)
      activity = insert(:note_activity)
      {:ok, bookmark} = Bookmark.create(user.id, activity.id)

      queried_activity =
        Ecto.Query.from(Pleroma.Activity)
        |> Activity.with_preloaded_bookmark(user)
        |> Repo.one()

      assert Activity.get_bookmark(queried_activity, user) == bookmark
    end

    test "when association is not loaded" do
      user = insert(:user)
      activity = insert(:note_activity)
      {:ok, bookmark} = Bookmark.create(user.id, activity.id)

      queried_activity =
        Ecto.Query.from(Pleroma.Activity)
        |> Repo.one()

      assert Activity.get_bookmark(queried_activity, user) == bookmark
    end
  end

  describe "search" do
    setup do
      Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

      user = insert(:user)

      params = %{
        "@context" => "https://www.w3.org/ns/activitystreams",
        "actor" => "http://mastodon.example.org/users/admin",
        "type" => "Create",
        "id" => "http://mastodon.example.org/users/admin/activities/1",
        "object" => %{
          "type" => "Note",
          "content" => "find me!",
          "id" => "http://mastodon.example.org/users/admin/objects/1",
          "attributedTo" => "http://mastodon.example.org/users/admin"
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      {:ok, local_activity} = Pleroma.Web.CommonAPI.post(user, %{"status" => "find me!"})
      {:ok, japanese_activity} = Pleroma.Web.CommonAPI.post(user, %{"status" => "更新情報"})
      {:ok, job} = Pleroma.Web.Federator.incoming_ap_doc(params)
      {:ok, remote_activity} = ObanHelpers.perform(job)

      %{
        japanese_activity: japanese_activity,
        local_activity: local_activity,
        remote_activity: remote_activity,
        user: user
      }
    end

    clear_config([:instance, :limit_to_local_content])

    test "finds utf8 text in statuses", %{
      japanese_activity: japanese_activity,
      user: user
    } do
      activities = Activity.search(user, "更新情報")

      assert [^japanese_activity] = activities
    end

    test "find local and remote statuses for authenticated users", %{
      local_activity: local_activity,
      remote_activity: remote_activity,
      user: user
    } do
      activities = Enum.sort_by(Activity.search(user, "find me"), & &1.id)

      assert [^local_activity, ^remote_activity] = activities
    end

    test "find only local statuses for unauthenticated users", %{local_activity: local_activity} do
      assert [^local_activity] = Activity.search(nil, "find me")
    end

    test "find only local statuses for unauthenticated users  when `limit_to_local_content` is `:all`",
         %{local_activity: local_activity} do
      Pleroma.Config.put([:instance, :limit_to_local_content], :all)
      assert [^local_activity] = Activity.search(nil, "find me")
    end

    test "find all statuses for unauthenticated users when `limit_to_local_content` is `false`",
         %{
           local_activity: local_activity,
           remote_activity: remote_activity
         } do
      Pleroma.Config.put([:instance, :limit_to_local_content], false)

      activities = Enum.sort_by(Activity.search(nil, "find me"), & &1.id)

      assert [^local_activity, ^remote_activity] = activities
    end
  end

  test "add an activity with an expiration" do
    activity = insert(:note_activity)
    insert(:expiration_in_the_future, %{activity_id: activity.id})

    Pleroma.ActivityExpiration
    |> where([a], a.activity_id == ^activity.id)
    |> Repo.one!()
  end

  test "all_by_ids_with_object/1" do
    %{id: id1} = insert(:note_activity)
    %{id: id2} = insert(:note_activity)

    activities =
      [id1, id2]
      |> Activity.all_by_ids_with_object()
      |> Enum.sort(&(&1.id < &2.id))

    assert [%{id: ^id1, object: %Object{}}, %{id: ^id2, object: %Object{}}] = activities
  end

  test "get_by_id_with_object/1" do
    %{id: id} = insert(:note_activity)

    assert %Activity{id: ^id, object: %Object{}} = Activity.get_by_id_with_object(id)
  end

  test "get_by_ap_id_with_object/1" do
    %{data: %{"id" => ap_id}} = insert(:note_activity)

    assert %Activity{data: %{"id" => ^ap_id}, object: %Object{}} =
             Activity.get_by_ap_id_with_object(ap_id)
  end

  test "get_by_id/1" do
    %{id: id} = insert(:note_activity)

    assert %Activity{id: ^id} = Activity.get_by_id(id)
  end

  test "all_by_actor_and_id/2" do
    user = insert(:user)

    {:ok, %{id: id1}} = Pleroma.Web.CommonAPI.post(user, %{"status" => "cofe"})
    {:ok, %{id: id2}} = Pleroma.Web.CommonAPI.post(user, %{"status" => "cofefe"})

    assert [] == Activity.all_by_actor_and_id(user, [])

    activities =
      user.ap_id
      |> Activity.all_by_actor_and_id([id1, id2])
      |> Enum.sort(&(&1.id < &2.id))

    assert [%Activity{id: ^id1}, %Activity{id: ^id2}] = activities
  end
end
