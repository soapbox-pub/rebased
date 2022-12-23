# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ActivityTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Object
  alias Pleroma.Tests.ObanHelpers
  alias Pleroma.ThreadMute
  import Pleroma.Factory

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  test "returns an activity by it's AP id" do
    activity = insert(:note_activity)
    found_activity = Activity.get_by_ap_id(activity.data["id"])

    assert activity == found_activity
  end

  test "returns activities by it's objects AP ids" do
    activity = insert(:note_activity)
    object_data = Object.normalize(activity, fetch: false).data

    [found_activity] = Activity.get_all_create_by_object_ap_id(object_data["id"])

    assert activity == found_activity
  end

  test "returns the activity that created an object" do
    activity = insert(:note_activity)
    object_data = Object.normalize(activity, fetch: false).data

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
          "attributedTo" => "http://mastodon.example.org/users/admin",
          "to" => ["https://www.w3.org/ns/activitystreams#Public"]
        },
        "to" => ["https://www.w3.org/ns/activitystreams#Public"]
      }

      {:ok, local_activity} = Pleroma.Web.CommonAPI.post(user, %{status: "find me!"})
      {:ok, japanese_activity} = Pleroma.Web.CommonAPI.post(user, %{status: "更新情報"})
      {:ok, job} = Pleroma.Web.Federator.incoming_ap_doc(params)
      {:ok, remote_activity} = ObanHelpers.perform(job)
      remote_activity = Activity.get_by_id_with_object(remote_activity.id)

      %{
        japanese_activity: japanese_activity,
        local_activity: local_activity,
        remote_activity: remote_activity,
        user: user
      }
    end

    setup do: clear_config([:instance, :limit_to_local_content])

    @tag :skip_on_mac
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
      clear_config([:instance, :limit_to_local_content], :all)
      assert [^local_activity] = Activity.search(nil, "find me")
    end

    test "find all statuses for unauthenticated users when `limit_to_local_content` is `false`",
         %{
           local_activity: local_activity,
           remote_activity: remote_activity
         } do
      clear_config([:instance, :limit_to_local_content], false)

      activities = Enum.sort_by(Activity.search(nil, "find me"), & &1.id)

      assert [^local_activity, ^remote_activity] = activities
    end
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

  test "get_by_id_with_user_actor/1" do
    user = insert(:user)
    activity = insert(:note_activity, note: insert(:note, user: user))

    assert Activity.get_by_id_with_user_actor(activity.id).user_actor == user
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

    {:ok, %{id: id1}} = Pleroma.Web.CommonAPI.post(user, %{status: "cofe"})
    {:ok, %{id: id2}} = Pleroma.Web.CommonAPI.post(user, %{status: "cofefe"})

    assert [] == Activity.all_by_actor_and_id(user, [])

    activities =
      user.ap_id
      |> Activity.all_by_actor_and_id([id1, id2])
      |> Enum.sort(&(&1.id < &2.id))

    assert [%Activity{id: ^id1}, %Activity{id: ^id2}] = activities
  end

  test "get_by_object_ap_id_with_object/1" do
    user = insert(:user)
    another = insert(:user)

    {:ok, %{id: id, object: %{data: %{"id" => obj_id}}}} =
      Pleroma.Web.CommonAPI.post(user, %{status: "cofe"})

    Pleroma.Web.CommonAPI.favorite(another, id)

    assert obj_id
           |> Pleroma.Activity.Queries.by_object_id()
           |> Repo.aggregate(:count, :id) == 2

    assert %{id: ^id} = Activity.get_by_object_ap_id_with_object(obj_id)
  end

  test "add_by_params_query/3" do
    user = insert(:user)

    note = insert(:note_activity, user: user)

    insert(:add_activity, user: user, note: note)
    insert(:add_activity, user: user, note: note)
    insert(:add_activity, user: user)

    assert Repo.aggregate(Activity, :count, :id) == 4

    add_query =
      Activity.add_by_params_query(note.data["object"], user.ap_id, user.featured_address)

    assert Repo.aggregate(add_query, :count, :id) == 2

    Repo.delete_all(add_query)
    assert Repo.aggregate(add_query, :count, :id) == 0

    assert Repo.aggregate(Activity, :count, :id) == 2
  end

  describe "associated_object_id() sql function" do
    test "with json object" do
      %{rows: [[object_id]]} =
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          select associated_object_id('{"object": {"id":"foobar"}}'::jsonb);
          """
        )

      assert object_id == "foobar"
    end

    test "with string object" do
      %{rows: [[object_id]]} =
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          select associated_object_id('{"object": "foobar"}'::jsonb);
          """
        )

      assert object_id == "foobar"
    end

    test "with array object" do
      %{rows: [[object_id]]} =
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          select associated_object_id('{"object": ["foobar", {}]}'::jsonb);
          """
        )

      assert object_id == "foobar"
    end

    test "invalid" do
      %{rows: [[object_id]]} =
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          select associated_object_id('{"object": {}}'::jsonb);
          """
        )

      assert is_nil(object_id)
    end

    test "invalid object id" do
      %{rows: [[object_id]]} =
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          select associated_object_id('{"object": {"id": 123}}'::jsonb);
          """
        )

      assert is_nil(object_id)
    end

    test "no object field" do
      %{rows: [[object_id]]} =
        Ecto.Adapters.SQL.query!(
          Pleroma.Repo,
          """
          select associated_object_id('{}'::jsonb);
          """
        )

      assert is_nil(object_id)
    end
  end
end
