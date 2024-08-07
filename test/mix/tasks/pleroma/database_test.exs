# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Mix.Tasks.Pleroma.DatabaseTest do
  use Pleroma.DataCase, async: true
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Activity
  alias Pleroma.Bookmark
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

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
      {:ok, activity} = CommonAPI.post(user, %{status: "test"})
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
    setup do
      deadline = Pleroma.Config.get([:instance, :remote_post_retention_days]) + 1

      old_insert_date =
        Timex.now()
        |> Timex.shift(days: -deadline)
        |> Timex.to_naive_datetime()
        |> NaiveDateTime.truncate(:second)

      %{old_insert_date: old_insert_date}
    end

    test "it prunes old objects from the database", %{old_insert_date: old_insert_date} do
      insert(:note)

      %{id: note_remote_public_id} =
        :note
        |> insert()
        |> Ecto.Changeset.change(%{updated_at: old_insert_date})
        |> Repo.update!()

      note_remote_non_public =
        %{id: note_remote_non_public_id, data: note_remote_non_public_data} =
        :note
        |> insert()

      note_remote_non_public
      |> Ecto.Changeset.change(%{
        updated_at: old_insert_date,
        data: note_remote_non_public_data |> update_in(["to"], fn _ -> [] end)
      })
      |> Repo.update!()

      assert length(Repo.all(Object)) == 3

      Mix.Tasks.Pleroma.Database.run(["prune_objects"])

      assert length(Repo.all(Object)) == 1
      refute Object.get_by_id(note_remote_public_id)
      refute Object.get_by_id(note_remote_non_public_id)
    end

    test "it cleans up bookmarks", %{old_insert_date: old_insert_date} do
      user = insert(:user)
      {:ok, old_object_activity} = CommonAPI.post(user, %{status: "yadayada"})

      Repo.one(Object)
      |> Ecto.Changeset.change(%{updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, new_object_activity} = CommonAPI.post(user, %{status: "yadayada"})

      {:ok, _} = Bookmark.create(user.id, old_object_activity.id)
      {:ok, _} = Bookmark.create(user.id, new_object_activity.id)

      assert length(Repo.all(Object)) == 2
      assert length(Repo.all(Bookmark)) == 2

      Mix.Tasks.Pleroma.Database.run(["prune_objects"])

      assert length(Repo.all(Object)) == 1
      assert length(Repo.all(Bookmark)) == 1
      refute Bookmark.get(user.id, old_object_activity.id)
    end

    test "with the --keep-non-public option it still keeps non-public posts even if they are not local",
         %{old_insert_date: old_insert_date} do
      insert(:note)

      %{id: note_remote_id} =
        :note
        |> insert()
        |> Ecto.Changeset.change(%{updated_at: old_insert_date})
        |> Repo.update!()

      note_remote_non_public =
        %{data: note_remote_non_public_data} =
        :note
        |> insert()

      note_remote_non_public
      |> Ecto.Changeset.change(%{
        updated_at: old_insert_date,
        data: note_remote_non_public_data |> update_in(["to"], fn _ -> [] end)
      })
      |> Repo.update!()

      assert length(Repo.all(Object)) == 3

      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--keep-non-public"])

      assert length(Repo.all(Object)) == 2
      refute Object.get_by_id(note_remote_id)
    end

    test "with the --keep-threads and --keep-non-public option it keeps old threads with non-public replies even if the interaction is not local",
         %{old_insert_date: old_insert_date} do
      # For non-public we only check Create Activities because only these are relevant for threads
      # Flags are always non-public, Announces from relays can be non-public...

      remote_user1 = insert(:user, local: false)
      remote_user2 = insert(:user, local: false)

      # Old remote non-public reply (should be kept)
      {:ok, old_remote_post1_activity} =
        CommonAPI.post(remote_user1, %{status: "some thing", local: false})

      old_remote_post1_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_remote_non_public_reply_activity} =
        CommonAPI.post(remote_user2, %{
          status: "some reply",
          in_reply_to_status_id: old_remote_post1_activity.id
        })

      old_remote_non_public_reply_activity
      |> Ecto.Changeset.change(%{
        local: false,
        updated_at: old_insert_date,
        data: old_remote_non_public_reply_activity.data |> update_in(["to"], fn _ -> [] end)
      })
      |> Repo.update!()

      # Old remote non-public Announce (should be removed)
      {:ok, old_remote_post2_activity = %{data: %{"object" => old_remote_post2_id}}} =
        CommonAPI.post(remote_user1, %{status: "some thing", local: false})

      old_remote_post2_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_remote_non_public_repeat_activity} =
        CommonAPI.repeat(old_remote_post2_activity.id, remote_user2)

      old_remote_non_public_repeat_activity
      |> Ecto.Changeset.change(%{
        local: false,
        updated_at: old_insert_date,
        data: old_remote_non_public_repeat_activity.data |> update_in(["to"], fn _ -> [] end)
      })
      |> Repo.update!()

      assert length(Repo.all(Object)) == 3

      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--keep-threads", "--keep-non-public"])

      Repo.all(Pleroma.Activity)
      assert length(Repo.all(Object)) == 2
      refute Object.get_by_ap_id(old_remote_post2_id)
    end

    test "with the --keep-threads option it still keeps non-old threads even with no local interactions" do
      remote_user = insert(:user, local: false)
      remote_user2 = insert(:user, local: false)

      {:ok, remote_post_activity} =
        CommonAPI.post(remote_user, %{status: "some thing", local: false})

      {:ok, remote_post_reply_activity} =
        CommonAPI.post(remote_user2, %{
          status: "some reply",
          in_reply_to_status_id: remote_post_activity.id
        })

      remote_post_activity
      |> Ecto.Changeset.change(%{local: false})
      |> Repo.update!()

      remote_post_reply_activity
      |> Ecto.Changeset.change(%{local: false})
      |> Repo.update!()

      assert length(Repo.all(Object)) == 2

      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--keep-threads"])

      assert length(Repo.all(Object)) == 2
    end

    test "with the --keep-threads option it deletes old threads with no local interaction", %{
      old_insert_date: old_insert_date
    } do
      remote_user = insert(:user, local: false)
      remote_user2 = insert(:user, local: false)

      {:ok, old_remote_post_activity} =
        CommonAPI.post(remote_user, %{status: "some thing", local: false})

      old_remote_post_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_remote_post_reply_activity} =
        CommonAPI.post(remote_user2, %{
          status: "some reply",
          in_reply_to_status_id: old_remote_post_activity.id
        })

      old_remote_post_reply_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_favourite_activity} =
        CommonAPI.favorite(old_remote_post_activity.id, remote_user2)

      old_favourite_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_repeat_activity} = CommonAPI.repeat(old_remote_post_activity.id, remote_user2)

      old_repeat_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      assert length(Repo.all(Object)) == 2

      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--keep-threads"])

      assert length(Repo.all(Object)) == 0
    end

    test "with the --keep-threads option it keeps old threads with local interaction", %{
      old_insert_date: old_insert_date
    } do
      remote_user = insert(:user, local: false)
      local_user = insert(:user, local: true)

      # local reply
      {:ok, old_remote_post1_activity} =
        CommonAPI.post(remote_user, %{status: "some thing", local: false})

      old_remote_post1_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_local_post2_reply_activity} =
        CommonAPI.post(local_user, %{
          status: "some reply",
          in_reply_to_status_id: old_remote_post1_activity.id
        })

      old_local_post2_reply_activity
      |> Ecto.Changeset.change(%{local: true, updated_at: old_insert_date})
      |> Repo.update!()

      # local Like
      {:ok, old_remote_post3_activity} =
        CommonAPI.post(remote_user, %{status: "some thing", local: false})

      old_remote_post3_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_favourite_activity} = CommonAPI.favorite(old_remote_post3_activity.id, local_user)

      old_favourite_activity
      |> Ecto.Changeset.change(%{local: true, updated_at: old_insert_date})
      |> Repo.update!()

      # local Announce
      {:ok, old_remote_post4_activity} =
        CommonAPI.post(remote_user, %{status: "some thing", local: false})

      old_remote_post4_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      {:ok, old_repeat_activity} = CommonAPI.repeat(old_remote_post4_activity.id, local_user)

      old_repeat_activity
      |> Ecto.Changeset.change(%{local: true, updated_at: old_insert_date})
      |> Repo.update!()

      assert length(Repo.all(Object)) == 4

      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--keep-threads"])

      assert length(Repo.all(Object)) == 4
    end

    test "with the --keep-threads option it keeps old threads with bookmarked posts", %{
      old_insert_date: old_insert_date
    } do
      remote_user = insert(:user, local: false)
      local_user = insert(:user, local: true)

      {:ok, old_remote_post_activity} =
        CommonAPI.post(remote_user, %{status: "some thing", local: false})

      old_remote_post_activity
      |> Ecto.Changeset.change(%{local: false, updated_at: old_insert_date})
      |> Repo.update!()

      Pleroma.Bookmark.create(local_user.id, old_remote_post_activity.id)

      assert length(Repo.all(Object)) == 1

      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--keep-threads"])

      assert length(Repo.all(Object)) == 1
    end

    test "We don't have unexpected tables which may contain objects that are referenced by activities" do
      # We can delete orphaned activities. For that we look for the objects
      # they reference in the 'objects', 'activities', and 'users' table.
      # If someone adds another table with objects (idk, maybe with separate
      # relations, or collections or w/e), then we need to make sure we
      # add logic for that in the 'prune_objects' task so that we don't
      # wrongly delete their corresponding activities.
      # So when someone adds (or removes) a table, this test will fail.
      # Either the table contains objects which can be referenced from the
      # activities table
      # => in that case the prune_objects job should be adapted so we don't
      #    delete activities who still have the referenced object.
      # Or it doesn't contain objects which can be referenced from the activities table
      # => in that case you can add/remove the table to/from this (sorted) list.

      assert Repo.query!(
               "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';"
             ).rows
             |> Enum.sort() == [
               ["activities"],
               ["announcement_read_relationships"],
               ["announcements"],
               ["apps"],
               ["backups"],
               ["bookmark_folders"],
               ["bookmarks"],
               ["chat_message_references"],
               ["chats"],
               ["config"],
               ["conversation_participation_recipient_ships"],
               ["conversation_participations"],
               ["conversations"],
               ["counter_cache"],
               ["data_migration_failed_ids"],
               ["data_migrations"],
               ["deliveries"],
               ["filters"],
               ["following_relationships"],
               ["hashtags"],
               ["hashtags_objects"],
               ["instances"],
               ["lists"],
               ["markers"],
               ["mfa_tokens"],
               ["moderation_log"],
               ["notifications"],
               ["oauth_authorizations"],
               ["oauth_tokens"],
               ["oban_jobs"],
               ["oban_peers"],
               ["objects"],
               ["password_reset_tokens"],
               ["push_subscriptions"],
               ["registrations"],
               ["report_notes"],
               ["rich_media_card"],
               ["rules"],
               ["scheduled_activities"],
               ["schema_migrations"],
               ["thread_mutes"],
               # ["user_follows_hashtag"],                  # not in pleroma
               # ["user_frontend_setting_profiles"],        # not in pleroma
               ["user_invite_tokens"],
               ["user_notes"],
               ["user_relationships"],
               ["users"]
             ]
    end

    test "it prunes orphaned activities with the --prune-orphaned-activities" do
      # Add a remote activity which references an Object
      %Object{} |> Map.merge(%{data: %{"id" => "object_for_activity"}}) |> Repo.insert()

      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{"id" => "remote_activity_with_object", "object" => "object_for_activity"}
      })
      |> Repo.insert()

      # Add a remote activity which references an activity
      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{
          "id" => "remote_activity_with_activity",
          "object" => "remote_activity_with_object"
        }
      })
      |> Repo.insert()

      # Add a remote activity which references an Actor
      %User{} |> Map.merge(%{ap_id: "actor"}) |> Repo.insert()

      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{"id" => "remote_activity_with_actor", "object" => "actor"}
      })
      |> Repo.insert()

      # Add a remote activity without existing referenced object, activity or actor
      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{
          "id" => "remote_activity_without_existing_referenced_object",
          "object" => "non_existing"
        }
      })
      |> Repo.insert()

      # Add a local activity without existing referenced object, activity or actor
      %Activity{}
      |> Map.merge(%{
        local: true,
        data: %{"id" => "local_activity_with_actor", "object" => "non_existing"}
      })
      |> Repo.insert()

      # The remote activities without existing reference,
      # and only the remote activities without existing reference, are deleted
      # if, and only if, we provide the --prune-orphaned-activities option
      assert length(Repo.all(Activity)) == 5
      Mix.Tasks.Pleroma.Database.run(["prune_objects"])
      assert length(Repo.all(Activity)) == 5
      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--prune-orphaned-activities"])
      activities = Repo.all(Activity)

      assert "remote_activity_without_existing_referenced_object" not in Enum.map(
               activities,
               fn a -> a.data["id"] end
             )

      assert length(activities) == 4
    end

    test "it prunes orphaned activities with the --prune-orphaned-activities when the objects are referenced from an array" do
      %Object{} |> Map.merge(%{data: %{"id" => "existing_object"}}) |> Repo.insert()
      %User{} |> Map.merge(%{ap_id: "existing_actor"}) |> Repo.insert()

      # Multiple objects, one object exists (keep)
      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{
          "id" => "remote_activity_existing_object",
          "object" => ["non_ existing_object", "existing_object"]
        }
      })
      |> Repo.insert()

      # Multiple objects, one actor exists (keep)
      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{
          "id" => "remote_activity_existing_actor",
          "object" => ["non_ existing_object", "existing_actor"]
        }
      })
      |> Repo.insert()

      # Multiple objects, one activity exists (keep)
      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{
          "id" => "remote_activity_existing_activity",
          "object" => ["non_ existing_object", "remote_activity_existing_actor"]
        }
      })
      |> Repo.insert()

      # Multiple objects none exist (prune)
      %Activity{}
      |> Map.merge(%{
        local: false,
        data: %{
          "id" => "remote_activity_without_existing_referenced_object",
          "object" => ["owo", "whats_this"]
        }
      })
      |> Repo.insert()

      assert length(Repo.all(Activity)) == 4
      Mix.Tasks.Pleroma.Database.run(["prune_objects"])
      assert length(Repo.all(Activity)) == 4
      Mix.Tasks.Pleroma.Database.run(["prune_objects", "--prune-orphaned-activities"])
      activities = Repo.all(Activity)
      assert length(activities) == 3

      assert "remote_activity_without_existing_referenced_object" not in Enum.map(
               activities,
               fn a -> a.data["id"] end
             )

      assert length(activities) == 3
    end
  end

  describe "running update_users_following_followers_counts" do
    test "following and followers count are updated" do
      [user, user2] = insert_pair(:user)
      {:ok, %User{} = user, _user2} = User.follow(user, user2)

      following = User.following(user)

      assert length(following) == 2
      assert user.follower_count == 0

      {:ok, user} =
        user
        |> Ecto.Changeset.change(%{follower_count: 3})
        |> Repo.update()

      assert user.follower_count == 3

      assert {:ok, :ok} ==
               Mix.Tasks.Pleroma.Database.run(["update_users_following_followers_counts"])

      user = User.get_by_id(user.id)

      assert length(User.following(user)) == 2
      assert user.follower_count == 0
    end
  end

  describe "running fix_likes_collections" do
    test "it turns OrderedCollection likes into empty arrays" do
      [user, user2] = insert_pair(:user)

      {:ok, %{id: id, object: object}} = CommonAPI.post(user, %{status: "test"})
      {:ok, %{object: object2}} = CommonAPI.post(user, %{status: "test test"})

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

  describe "ensure_expiration" do
    test "it adds to expiration old statuses" do
      activity1 = insert(:note_activity)

      {:ok, inserted_at, 0} = DateTime.from_iso8601("2015-01-23T23:50:07Z")
      activity2 = insert(:note_activity, %{inserted_at: inserted_at})

      %{id: activity_id3} = insert(:note_activity)

      expires_at = DateTime.add(DateTime.utc_now(), 60 * 61)

      Pleroma.Workers.PurgeExpiredActivity.enqueue(
        %{
          activity_id: activity_id3
        },
        scheduled_at: expires_at
      )

      Mix.Tasks.Pleroma.Database.run(["ensure_expiration"])

      assert_enqueued(
        worker: Pleroma.Workers.PurgeExpiredActivity,
        args: %{activity_id: activity1.id},
        scheduled_at:
          activity1.inserted_at
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.shift(days: 365)
      )

      assert_enqueued(
        worker: Pleroma.Workers.PurgeExpiredActivity,
        args: %{activity_id: activity2.id},
        scheduled_at:
          activity2.inserted_at
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.shift(days: 365)
      )

      assert_enqueued(
        worker: Pleroma.Workers.PurgeExpiredActivity,
        args: %{activity_id: activity_id3},
        scheduled_at: expires_at
      )
    end
  end
end
