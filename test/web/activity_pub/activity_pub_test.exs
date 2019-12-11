# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Activity
  alias Pleroma.Builders.ActivityBuilder
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory
  import Tesla.Mock
  import Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  clear_config([:instance, :federating])

  describe "streaming out participations" do
    test "it streams them out" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})

      {:ok, conversation} = Pleroma.Conversation.create_or_bump_for(activity)

      participations =
        conversation.participations
        |> Repo.preload(:user)

      with_mock Pleroma.Web.Streamer,
        stream: fn _, _ -> nil end do
        ActivityPub.stream_out_participations(conversation.participations)

        assert called(Pleroma.Web.Streamer.stream("participation", participations))
      end
    end

    test "streams them out on activity creation" do
      user_one = insert(:user)
      user_two = insert(:user)

      with_mock Pleroma.Web.Streamer,
        stream: fn _, _ -> nil end do
        {:ok, activity} =
          CommonAPI.post(user_one, %{
            "status" => "@#{user_two.nickname}",
            "visibility" => "direct"
          })

        conversation =
          activity.data["context"]
          |> Pleroma.Conversation.get_for_ap_id()
          |> Repo.preload(participations: :user)

        assert called(Pleroma.Web.Streamer.stream("participation", conversation.participations))
      end
    end
  end

  describe "fetching restricted by visibility" do
    test "it restricts by the appropriate visibility" do
      user = insert(:user)

      {:ok, public_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "public"})

      {:ok, direct_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})

      {:ok, unlisted_activity} =
        CommonAPI.post(user, %{"status" => ".", "visibility" => "unlisted"})

      {:ok, private_activity} =
        CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})

      activities =
        ActivityPub.fetch_activities([], %{:visibility => "direct", "actor_id" => user.ap_id})

      assert activities == [direct_activity]

      activities =
        ActivityPub.fetch_activities([], %{:visibility => "unlisted", "actor_id" => user.ap_id})

      assert activities == [unlisted_activity]

      activities =
        ActivityPub.fetch_activities([], %{:visibility => "private", "actor_id" => user.ap_id})

      assert activities == [private_activity]

      activities =
        ActivityPub.fetch_activities([], %{:visibility => "public", "actor_id" => user.ap_id})

      assert activities == [public_activity]

      activities =
        ActivityPub.fetch_activities([], %{
          :visibility => ~w[private public],
          "actor_id" => user.ap_id
        })

      assert activities == [public_activity, private_activity]
    end
  end

  describe "fetching excluded by visibility" do
    test "it excludes by the appropriate visibility" do
      user = insert(:user)

      {:ok, public_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "public"})

      {:ok, direct_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "direct"})

      {:ok, unlisted_activity} =
        CommonAPI.post(user, %{"status" => ".", "visibility" => "unlisted"})

      {:ok, private_activity} =
        CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})

      activities =
        ActivityPub.fetch_activities([], %{
          "exclude_visibilities" => "direct",
          "actor_id" => user.ap_id
        })

      assert public_activity in activities
      assert unlisted_activity in activities
      assert private_activity in activities
      refute direct_activity in activities

      activities =
        ActivityPub.fetch_activities([], %{
          "exclude_visibilities" => "unlisted",
          "actor_id" => user.ap_id
        })

      assert public_activity in activities
      refute unlisted_activity in activities
      assert private_activity in activities
      assert direct_activity in activities

      activities =
        ActivityPub.fetch_activities([], %{
          "exclude_visibilities" => "private",
          "actor_id" => user.ap_id
        })

      assert public_activity in activities
      assert unlisted_activity in activities
      refute private_activity in activities
      assert direct_activity in activities

      activities =
        ActivityPub.fetch_activities([], %{
          "exclude_visibilities" => "public",
          "actor_id" => user.ap_id
        })

      refute public_activity in activities
      assert unlisted_activity in activities
      assert private_activity in activities
      assert direct_activity in activities
    end
  end

  describe "building a user from his ap id" do
    test "it returns a user" do
      user_id = "http://mastodon.example.org/users/admin"
      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)
      assert user.ap_id == user_id
      assert user.nickname == "admin@mastodon.example.org"
      assert user.source_data
      assert user.ap_enabled
      assert user.follower_address == "http://mastodon.example.org/users/admin/followers"
    end

    test "it returns a user that is invisible" do
      user_id = "http://mastodon.example.org/users/relay"
      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)
      assert User.invisible?(user)
    end

    test "it fetches the appropriate tag-restricted posts" do
      user = insert(:user)

      {:ok, status_one} = CommonAPI.post(user, %{"status" => ". #test"})
      {:ok, status_two} = CommonAPI.post(user, %{"status" => ". #essais"})
      {:ok, status_three} = CommonAPI.post(user, %{"status" => ". #test #reject"})

      fetch_one = ActivityPub.fetch_activities([], %{"type" => "Create", "tag" => "test"})

      fetch_two =
        ActivityPub.fetch_activities([], %{"type" => "Create", "tag" => ["test", "essais"]})

      fetch_three =
        ActivityPub.fetch_activities([], %{
          "type" => "Create",
          "tag" => ["test", "essais"],
          "tag_reject" => ["reject"]
        })

      fetch_four =
        ActivityPub.fetch_activities([], %{
          "type" => "Create",
          "tag" => ["test"],
          "tag_all" => ["test", "reject"]
        })

      assert fetch_one == [status_one, status_three]
      assert fetch_two == [status_one, status_two, status_three]
      assert fetch_three == [status_one, status_two]
      assert fetch_four == [status_three]
    end
  end

  describe "insertion" do
    test "drops activities beyond a certain limit" do
      limit = Pleroma.Config.get([:instance, :remote_limit])

      random_text =
        :crypto.strong_rand_bytes(limit + 1)
        |> Base.encode64()
        |> binary_part(0, limit + 1)

      data = %{
        "ok" => true,
        "object" => %{
          "content" => random_text
        }
      }

      assert {:error, {:remote_limit_error, _}} = ActivityPub.insert(data)
    end

    test "doesn't drop activities with content being null" do
      user = insert(:user)

      data = %{
        "actor" => user.ap_id,
        "to" => [],
        "object" => %{
          "actor" => user.ap_id,
          "to" => [],
          "type" => "Note",
          "content" => nil
        }
      }

      assert {:ok, _} = ActivityPub.insert(data)
    end

    test "returns the activity if one with the same id is already in" do
      activity = insert(:note_activity)
      {:ok, new_activity} = ActivityPub.insert(activity.data)

      assert activity.id == new_activity.id
    end

    test "inserts a given map into the activity database, giving it an id if it has none." do
      user = insert(:user)

      data = %{
        "actor" => user.ap_id,
        "to" => [],
        "object" => %{
          "actor" => user.ap_id,
          "to" => [],
          "type" => "Note",
          "content" => "hey"
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data["ok"] == data["ok"]
      assert is_binary(activity.data["id"])

      given_id = "bla"

      data = %{
        "id" => given_id,
        "actor" => user.ap_id,
        "to" => [],
        "context" => "blabla",
        "object" => %{
          "actor" => user.ap_id,
          "to" => [],
          "type" => "Note",
          "content" => "hey"
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert activity.data["ok"] == data["ok"]
      assert activity.data["id"] == given_id
      assert activity.data["context"] == "blabla"
      assert activity.data["context_id"]
    end

    test "adds a context when none is there" do
      user = insert(:user)

      data = %{
        "actor" => user.ap_id,
        "to" => [],
        "object" => %{
          "actor" => user.ap_id,
          "to" => [],
          "type" => "Note",
          "content" => "hey"
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      object = Pleroma.Object.normalize(activity)

      assert is_binary(activity.data["context"])
      assert is_binary(object.data["context"])
      assert activity.data["context_id"]
      assert object.data["context_id"]
    end

    test "adds an id to a given object if it lacks one and is a note and inserts it to the object database" do
      user = insert(:user)

      data = %{
        "actor" => user.ap_id,
        "to" => [],
        "object" => %{
          "actor" => user.ap_id,
          "to" => [],
          "type" => "Note",
          "content" => "hey"
        }
      }

      {:ok, %Activity{} = activity} = ActivityPub.insert(data)
      assert object = Object.normalize(activity)
      assert is_binary(object.data["id"])
    end
  end

  describe "listen activities" do
    test "does not increase user note count" do
      user = insert(:user)

      {:ok, activity} =
        ActivityPub.listen(%{
          to: ["https://www.w3.org/ns/activitystreams#Public"],
          actor: user,
          context: "",
          object: %{
            "actor" => user.ap_id,
            "to" => ["https://www.w3.org/ns/activitystreams#Public"],
            "artist" => "lain",
            "title" => "lain radio episode 1",
            "length" => 180_000,
            "type" => "Audio"
          }
        })

      assert activity.actor == user.ap_id

      user = User.get_cached_by_id(user.id)
      assert user.note_count == 0
    end

    test "can be fetched into a timeline" do
      _listen_activity_1 = insert(:listen)
      _listen_activity_2 = insert(:listen)
      _listen_activity_3 = insert(:listen)

      timeline = ActivityPub.fetch_activities([], %{"type" => ["Listen"]})

      assert length(timeline) == 3
    end
  end

  describe "create activities" do
    test "removes doubled 'to' recipients" do
      user = insert(:user)

      {:ok, activity} =
        ActivityPub.create(%{
          to: ["user1", "user1", "user2"],
          actor: user,
          context: "",
          object: %{
            "to" => ["user1", "user1", "user2"],
            "type" => "Note",
            "content" => "testing"
          }
        })

      assert activity.data["to"] == ["user1", "user2"]
      assert activity.actor == user.ap_id
      assert activity.recipients == ["user1", "user2", user.ap_id]
    end

    test "increases user note count only for public activities" do
      user = insert(:user)

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "1",
          "visibility" => "public"
        })

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "2",
          "visibility" => "unlisted"
        })

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "2",
          "visibility" => "private"
        })

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "3",
          "visibility" => "direct"
        })

      user = User.get_cached_by_id(user.id)
      assert user.note_count == 2
    end

    test "increases replies count" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "1", "visibility" => "public"})
      ap_id = activity.data["id"]
      reply_data = %{"status" => "1", "in_reply_to_status_id" => activity.id}

      # public
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "public"))
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 1

      # unlisted
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "unlisted"))
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2

      # private
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "private"))
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2

      # direct
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "direct"))
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2
    end
  end

  describe "fetch activities for recipients" do
    test "retrieve the activities for certain recipients" do
      {:ok, activity_one} = ActivityBuilder.insert(%{"to" => ["someone"]})
      {:ok, activity_two} = ActivityBuilder.insert(%{"to" => ["someone_else"]})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"to" => ["noone"]})

      activities = ActivityPub.fetch_activities(["someone", "someone_else"])
      assert length(activities) == 2
      assert activities == [activity_one, activity_two]
    end
  end

  describe "fetch activities in context" do
    test "retrieves activities that have a given context" do
      {:ok, activity} = ActivityBuilder.insert(%{"type" => "Create", "context" => "2hu"})
      {:ok, activity_two} = ActivityBuilder.insert(%{"type" => "Create", "context" => "2hu"})
      {:ok, _activity_three} = ActivityBuilder.insert(%{"type" => "Create", "context" => "3hu"})
      {:ok, _activity_four} = ActivityBuilder.insert(%{"type" => "Announce", "context" => "2hu"})
      activity_five = insert(:note_activity)
      user = insert(:user)

      {:ok, _user_relationship} = User.block(user, %{ap_id: activity_five.data["actor"]})

      activities = ActivityPub.fetch_activities_for_context("2hu", %{"blocking_user" => user})
      assert activities == [activity_two, activity]
    end
  end

  test "doesn't return blocked activities" do
    activity_one = insert(:note_activity)
    activity_two = insert(:note_activity)
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)
    {:ok, _user_relationship} = User.block(user, %{ap_id: activity_one.data["actor"]})

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => user, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_one)

    {:ok, _user_block} = User.unblock(user, %{ap_id: activity_one.data["actor"]})

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => user, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    {:ok, _user_relationship} = User.block(user, %{ap_id: activity_three.data["actor"]})
    {:ok, _announce, %{data: %{"id" => id}}} = CommonAPI.repeat(activity_three.id, booster)
    %Activity{} = boost_activity = Activity.get_create_by_object_ap_id(id)
    activity_three = Activity.get_by_id(activity_three.id)

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => user, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => nil, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)
  end

  test "doesn't return transitive interactions concerning blocked users" do
    blocker = insert(:user)
    blockee = insert(:user)
    friend = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:ok, activity_one} = CommonAPI.post(friend, %{"status" => "hey!"})

    {:ok, activity_two} = CommonAPI.post(friend, %{"status" => "hey! @#{blockee.nickname}"})

    {:ok, activity_three} = CommonAPI.post(blockee, %{"status" => "hey! @#{friend.nickname}"})

    {:ok, activity_four} = CommonAPI.post(blockee, %{"status" => "hey! @#{blocker.nickname}"})

    activities = ActivityPub.fetch_activities([], %{"blocking_user" => blocker})

    assert Enum.member?(activities, activity_one)
    refute Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_four)
  end

  test "doesn't return announce activities concerning blocked users" do
    blocker = insert(:user)
    blockee = insert(:user)
    friend = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:ok, activity_one} = CommonAPI.post(friend, %{"status" => "hey!"})

    {:ok, activity_two} = CommonAPI.post(blockee, %{"status" => "hey! @#{friend.nickname}"})

    {:ok, activity_three, _} = CommonAPI.repeat(activity_two.id, friend)

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => blocker})
      |> Enum.map(fn act -> act.id end)

    assert Enum.member?(activities, activity_one.id)
    refute Enum.member?(activities, activity_two.id)
    refute Enum.member?(activities, activity_three.id)
  end

  test "doesn't return activities from blocked domains" do
    domain = "dogwhistle.zone"
    domain_user = insert(:user, %{ap_id: "https://#{domain}/@pundit"})
    note = insert(:note, %{data: %{"actor" => domain_user.ap_id}})
    activity = insert(:note_activity, %{note: note})
    user = insert(:user)
    {:ok, user} = User.block_domain(user, domain)

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => user, "skip_preload" => true})

    refute activity in activities

    followed_user = insert(:user)
    ActivityPub.follow(user, followed_user)
    {:ok, repeat_activity, _} = CommonAPI.repeat(activity.id, followed_user)

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => user, "skip_preload" => true})

    refute repeat_activity in activities
  end

  test "does return activities from followed users on blocked domains" do
    domain = "meanies.social"
    domain_user = insert(:user, %{ap_id: "https://#{domain}/@pundit"})
    blocker = insert(:user)

    {:ok, blocker} = User.follow(blocker, domain_user)
    {:ok, blocker} = User.block_domain(blocker, domain)

    assert User.following?(blocker, domain_user)
    assert User.blocks_domain?(blocker, domain_user)
    refute User.blocks?(blocker, domain_user)

    note = insert(:note, %{data: %{"actor" => domain_user.ap_id}})
    activity = insert(:note_activity, %{note: note})

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => blocker, "skip_preload" => true})

    assert activity in activities

    # And check that if the guy we DO follow boosts someone else from their domain,
    # that should be hidden
    another_user = insert(:user, %{ap_id: "https://#{domain}/@meanie2"})
    bad_note = insert(:note, %{data: %{"actor" => another_user.ap_id}})
    bad_activity = insert(:note_activity, %{note: bad_note})
    {:ok, repeat_activity, _} = CommonAPI.repeat(bad_activity.id, domain_user)

    activities =
      ActivityPub.fetch_activities([], %{"blocking_user" => blocker, "skip_preload" => true})

    refute repeat_activity in activities
  end

  test "doesn't return muted activities" do
    activity_one = insert(:note_activity)
    activity_two = insert(:note_activity)
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)

    activity_one_actor = User.get_by_ap_id(activity_one.data["actor"])
    {:ok, _user_relationships} = User.mute(user, activity_one_actor)

    activities =
      ActivityPub.fetch_activities([], %{"muting_user" => user, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_one)

    # Calling with 'with_muted' will deliver muted activities, too.
    activities =
      ActivityPub.fetch_activities([], %{
        "muting_user" => user,
        "with_muted" => true,
        "skip_preload" => true
      })

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    {:ok, _user_mute} = User.unmute(user, activity_one_actor)

    activities =
      ActivityPub.fetch_activities([], %{"muting_user" => user, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    activity_three_actor = User.get_by_ap_id(activity_three.data["actor"])
    {:ok, _user_relationships} = User.mute(user, activity_three_actor)
    {:ok, _announce, %{data: %{"id" => id}}} = CommonAPI.repeat(activity_three.id, booster)
    %Activity{} = boost_activity = Activity.get_create_by_object_ap_id(id)
    activity_three = Activity.get_by_id(activity_three.id)

    activities =
      ActivityPub.fetch_activities([], %{"muting_user" => user, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)

    activities = ActivityPub.fetch_activities([], %{"muting_user" => nil, "skip_preload" => true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)
  end

  test "doesn't return thread muted activities" do
    user = insert(:user)
    _activity_one = insert(:note_activity)
    note_two = insert(:note, data: %{"context" => "suya.."})
    activity_two = insert(:note_activity, note: note_two)

    {:ok, _activity_two} = CommonAPI.add_mute(user, activity_two)

    assert [_activity_one] = ActivityPub.fetch_activities([], %{"muting_user" => user})
  end

  test "returns thread muted activities when with_muted is set" do
    user = insert(:user)
    _activity_one = insert(:note_activity)
    note_two = insert(:note, data: %{"context" => "suya.."})
    activity_two = insert(:note_activity, note: note_two)

    {:ok, _activity_two} = CommonAPI.add_mute(user, activity_two)

    assert [_activity_two, _activity_one] =
             ActivityPub.fetch_activities([], %{"muting_user" => user, "with_muted" => true})
  end

  test "does include announces on request" do
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)

    {:ok, user} = User.follow(user, booster)

    {:ok, announce, _object} = CommonAPI.repeat(activity_three.id, booster)

    [announce_activity] = ActivityPub.fetch_activities([user.ap_id | User.following(user)])

    assert announce_activity.id == announce.id
  end

  test "excludes reblogs on request" do
    user = insert(:user)
    {:ok, expected_activity} = ActivityBuilder.insert(%{"type" => "Create"}, %{:user => user})
    {:ok, _} = ActivityBuilder.insert(%{"type" => "Announce"}, %{:user => user})

    [activity] = ActivityPub.fetch_user_activities(user, nil, %{"exclude_reblogs" => "true"})

    assert activity == expected_activity
  end

  describe "public fetch activities" do
    test "doesn't retrieve unlisted activities" do
      user = insert(:user)

      {:ok, _unlisted_activity} =
        CommonAPI.post(user, %{"status" => "yeah", "visibility" => "unlisted"})

      {:ok, listed_activity} = CommonAPI.post(user, %{"status" => "yeah"})

      [activity] = ActivityPub.fetch_public_activities()

      assert activity == listed_activity
    end

    test "retrieves public activities" do
      _activities = ActivityPub.fetch_public_activities()

      %{public: public} = ActivityBuilder.public_and_non_public()

      activities = ActivityPub.fetch_public_activities()
      assert length(activities) == 1
      assert Enum.at(activities, 0) == public
    end

    test "retrieves a maximum of 20 activities" do
      ActivityBuilder.insert_list(10)
      expected_activities = ActivityBuilder.insert_list(20)

      activities = ActivityPub.fetch_public_activities()

      assert collect_ids(activities) == collect_ids(expected_activities)
      assert length(activities) == 20
    end

    test "retrieves ids starting from a since_id" do
      activities = ActivityBuilder.insert_list(30)
      expected_activities = ActivityBuilder.insert_list(10)
      since_id = List.last(activities).id

      activities = ActivityPub.fetch_public_activities(%{"since_id" => since_id})

      assert collect_ids(activities) == collect_ids(expected_activities)
      assert length(activities) == 10
    end

    test "retrieves ids up to max_id" do
      ActivityBuilder.insert_list(10)
      expected_activities = ActivityBuilder.insert_list(20)

      %{id: max_id} =
        10
        |> ActivityBuilder.insert_list()
        |> List.first()

      activities = ActivityPub.fetch_public_activities(%{"max_id" => max_id})

      assert length(activities) == 20
      assert collect_ids(activities) == collect_ids(expected_activities)
    end

    test "paginates via offset/limit" do
      _first_part_activities = ActivityBuilder.insert_list(10)
      second_part_activities = ActivityBuilder.insert_list(10)

      later_activities = ActivityBuilder.insert_list(10)

      activities =
        ActivityPub.fetch_public_activities(%{"page" => "2", "page_size" => "20"}, :offset)

      assert length(activities) == 20

      assert collect_ids(activities) ==
               collect_ids(second_part_activities) ++ collect_ids(later_activities)
    end

    test "doesn't return reblogs for users for whom reblogs have been muted" do
      activity = insert(:note_activity)
      user = insert(:user)
      booster = insert(:user)
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(user, booster)

      {:ok, activity, _} = CommonAPI.repeat(activity.id, booster)

      activities = ActivityPub.fetch_activities([], %{"muting_user" => user})

      refute Enum.any?(activities, fn %{id: id} -> id == activity.id end)
    end

    test "returns reblogs for users for whom reblogs have not been muted" do
      activity = insert(:note_activity)
      user = insert(:user)
      booster = insert(:user)
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(user, booster)
      {:ok, _reblog_mute} = CommonAPI.show_reblogs(user, booster)

      {:ok, activity, _} = CommonAPI.repeat(activity.id, booster)

      activities = ActivityPub.fetch_activities([], %{"muting_user" => user})

      assert Enum.any?(activities, fn %{id: id} -> id == activity.id end)
    end
  end

  describe "react to an object" do
    test_with_mock "sends an activity to federation", Pleroma.Web.Federator, [:passthrough], [] do
      Pleroma.Config.put([:instance, :federating], true)
      user = insert(:user)
      reactor = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "YASSSS queen slay"})
      assert object = Object.normalize(activity)

      {:ok, reaction_activity, _object} = ActivityPub.react_with_emoji(reactor, object, "🔥")

      assert called(Pleroma.Web.Federator.publish(reaction_activity))
    end

    test "adds an emoji reaction activity to the db" do
      user = insert(:user)
      reactor = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "YASSSS queen slay"})
      assert object = Object.normalize(activity)

      {:ok, reaction_activity, object} = ActivityPub.react_with_emoji(reactor, object, "🔥")

      assert reaction_activity

      assert reaction_activity.data["actor"] == reactor.ap_id
      assert reaction_activity.data["type"] == "EmojiReaction"
      assert reaction_activity.data["content"] == "🔥"
      assert reaction_activity.data["object"] == object.data["id"]
      assert reaction_activity.data["to"] == [User.ap_followers(reactor), activity.data["actor"]]
      assert reaction_activity.data["context"] == object.data["context"]
      assert object.data["reaction_count"] == 1
      assert object.data["reactions"]["🔥"] == [reactor.ap_id]
    end
  end

  describe "unreacting to an object" do
    test_with_mock "sends an activity to federation", Pleroma.Web.Federator, [:passthrough], [] do
      Pleroma.Config.put([:instance, :federating], true)
      user = insert(:user)
      reactor = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "YASSSS queen slay"})
      assert object = Object.normalize(activity)

      {:ok, reaction_activity, _object} = ActivityPub.react_with_emoji(reactor, object, "🔥")

      assert called(Pleroma.Web.Federator.publish(reaction_activity))

      {:ok, unreaction_activity, _object} =
        ActivityPub.unreact_with_emoji(reactor, reaction_activity.data["id"])

      assert called(Pleroma.Web.Federator.publish(unreaction_activity))
    end

    test "adds an undo activity to the db" do
      user = insert(:user)
      reactor = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "YASSSS queen slay"})
      assert object = Object.normalize(activity)

      {:ok, reaction_activity, _object} = ActivityPub.react_with_emoji(reactor, object, "🔥")

      {:ok, unreaction_activity, _object} =
        ActivityPub.unreact_with_emoji(reactor, reaction_activity.data["id"])

      assert unreaction_activity.actor == reactor.ap_id
      assert unreaction_activity.data["object"] == reaction_activity.data["id"]

      object = Object.get_by_ap_id(object.data["id"])
      assert object.data["reaction_count"] == 0
      assert object.data["reactions"] == %{}
    end
  end

  describe "like an object" do
    test_with_mock "sends an activity to federation", Pleroma.Web.Federator, [:passthrough], [] do
      Pleroma.Config.put([:instance, :federating], true)
      note_activity = insert(:note_activity)
      assert object_activity = Object.normalize(note_activity)

      user = insert(:user)

      {:ok, like_activity, _object} = ActivityPub.like(user, object_activity)
      assert called(Pleroma.Web.Federator.publish(like_activity))
    end

    test "returns exist activity if object already liked" do
      note_activity = insert(:note_activity)
      assert object_activity = Object.normalize(note_activity)

      user = insert(:user)

      {:ok, like_activity, _object} = ActivityPub.like(user, object_activity)

      {:ok, like_activity_exist, _object} = ActivityPub.like(user, object_activity)
      assert like_activity == like_activity_exist
    end

    test "adds a like activity to the db" do
      note_activity = insert(:note_activity)
      assert object = Object.normalize(note_activity)

      user = insert(:user)
      user_two = insert(:user)

      {:ok, like_activity, object} = ActivityPub.like(user, object)

      assert like_activity.data["actor"] == user.ap_id
      assert like_activity.data["type"] == "Like"
      assert like_activity.data["object"] == object.data["id"]
      assert like_activity.data["to"] == [User.ap_followers(user), note_activity.data["actor"]]
      assert like_activity.data["context"] == object.data["context"]
      assert object.data["like_count"] == 1
      assert object.data["likes"] == [user.ap_id]

      # Just return the original activity if the user already liked it.
      {:ok, same_like_activity, object} = ActivityPub.like(user, object)

      assert like_activity == same_like_activity
      assert object.data["likes"] == [user.ap_id]
      assert object.data["like_count"] == 1

      {:ok, _like_activity, object} = ActivityPub.like(user_two, object)
      assert object.data["like_count"] == 2
    end
  end

  describe "unliking" do
    test_with_mock "sends an activity to federation", Pleroma.Web.Federator, [:passthrough], [] do
      Pleroma.Config.put([:instance, :federating], true)

      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      user = insert(:user)

      {:ok, object} = ActivityPub.unlike(user, object)
      refute called(Pleroma.Web.Federator.publish())

      {:ok, _like_activity, object} = ActivityPub.like(user, object)
      assert object.data["like_count"] == 1

      {:ok, unlike_activity, _, object} = ActivityPub.unlike(user, object)
      assert object.data["like_count"] == 0

      assert called(Pleroma.Web.Federator.publish(unlike_activity))
    end

    test "unliking a previously liked object" do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      user = insert(:user)

      # Unliking something that hasn't been liked does nothing
      {:ok, object} = ActivityPub.unlike(user, object)
      assert object.data["like_count"] == 0

      {:ok, like_activity, object} = ActivityPub.like(user, object)
      assert object.data["like_count"] == 1

      {:ok, unlike_activity, _, object} = ActivityPub.unlike(user, object)
      assert object.data["like_count"] == 0

      assert Activity.get_by_id(like_activity.id) == nil
      assert note_activity.actor in unlike_activity.recipients
    end
  end

  describe "announcing an object" do
    test "adds an announce activity to the db" do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      user = insert(:user)

      {:ok, announce_activity, object} = ActivityPub.announce(user, object)
      assert object.data["announcement_count"] == 1
      assert object.data["announcements"] == [user.ap_id]

      assert announce_activity.data["to"] == [
               User.ap_followers(user),
               note_activity.data["actor"]
             ]

      assert announce_activity.data["object"] == object.data["id"]
      assert announce_activity.data["actor"] == user.ap_id
      assert announce_activity.data["context"] == object.data["context"]
    end
  end

  describe "announcing a private object" do
    test "adds an announce activity to the db if the audience is not widened" do
      user = insert(:user)
      {:ok, note_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})
      object = Object.normalize(note_activity)

      {:ok, announce_activity, object} = ActivityPub.announce(user, object, nil, true, false)

      assert announce_activity.data["to"] == [User.ap_followers(user)]

      assert announce_activity.data["object"] == object.data["id"]
      assert announce_activity.data["actor"] == user.ap_id
      assert announce_activity.data["context"] == object.data["context"]
    end

    test "does not add an announce activity to the db if the audience is widened" do
      user = insert(:user)
      {:ok, note_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})
      object = Object.normalize(note_activity)

      assert {:error, _} = ActivityPub.announce(user, object, nil, true, true)
    end

    test "does not add an announce activity to the db if the announcer is not the author" do
      user = insert(:user)
      announcer = insert(:user)
      {:ok, note_activity} = CommonAPI.post(user, %{"status" => ".", "visibility" => "private"})
      object = Object.normalize(note_activity)

      assert {:error, _} = ActivityPub.announce(announcer, object, nil, true, false)
    end
  end

  describe "unannouncing an object" do
    test "unannouncing a previously announced object" do
      note_activity = insert(:note_activity)
      object = Object.normalize(note_activity)
      user = insert(:user)

      # Unannouncing an object that is not announced does nothing
      # {:ok, object} = ActivityPub.unannounce(user, object)
      # assert object.data["announcement_count"] == 0

      {:ok, announce_activity, object} = ActivityPub.announce(user, object)
      assert object.data["announcement_count"] == 1

      {:ok, unannounce_activity, object} = ActivityPub.unannounce(user, object)
      assert object.data["announcement_count"] == 0

      assert unannounce_activity.data["to"] == [
               User.ap_followers(user),
               object.data["actor"]
             ]

      assert unannounce_activity.data["type"] == "Undo"
      assert unannounce_activity.data["object"] == announce_activity.data
      assert unannounce_activity.data["actor"] == user.ap_id
      assert unannounce_activity.data["context"] == announce_activity.data["context"]

      assert Activity.get_by_id(announce_activity.id) == nil
    end
  end

  describe "uploading files" do
    test "copies the file to the configured folder" do
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == "an_image.jpg"
    end

    test "works with base64 encoded images" do
      file = %{
        "img" => data_uri()
      }

      {:ok, %Object{}} = ActivityPub.upload(file)
    end
  end

  describe "fetch the latest Follow" do
    test "fetches the latest Follow activity" do
      %Activity{data: %{"type" => "Follow"}} = activity = insert(:follow_activity)
      follower = Repo.get_by(User, ap_id: activity.data["actor"])
      followed = Repo.get_by(User, ap_id: activity.data["object"])

      assert activity == Utils.fetch_latest_follow(follower, followed)
    end
  end

  describe "following / unfollowing" do
    test "creates a follow activity" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, activity} = ActivityPub.follow(follower, followed)
      assert activity.data["type"] == "Follow"
      assert activity.data["actor"] == follower.ap_id
      assert activity.data["object"] == followed.ap_id
    end

    test "creates an undo activity for the last follow" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, follow_activity} = ActivityPub.follow(follower, followed)
      {:ok, activity} = ActivityPub.unfollow(follower, followed)

      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == follower.ap_id

      embedded_object = activity.data["object"]
      assert is_map(embedded_object)
      assert embedded_object["type"] == "Follow"
      assert embedded_object["object"] == followed.ap_id
      assert embedded_object["id"] == follow_activity.data["id"]
    end
  end

  describe "blocking / unblocking" do
    test "creates a block activity" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, activity} = ActivityPub.block(blocker, blocked)

      assert activity.data["type"] == "Block"
      assert activity.data["actor"] == blocker.ap_id
      assert activity.data["object"] == blocked.ap_id
    end

    test "creates an undo activity for the last block" do
      blocker = insert(:user)
      blocked = insert(:user)

      {:ok, block_activity} = ActivityPub.block(blocker, blocked)
      {:ok, activity} = ActivityPub.unblock(blocker, blocked)

      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == blocker.ap_id

      embedded_object = activity.data["object"]
      assert is_map(embedded_object)
      assert embedded_object["type"] == "Block"
      assert embedded_object["object"] == blocked.ap_id
      assert embedded_object["id"] == block_activity.data["id"]
    end
  end

  describe "deletion" do
    test "it creates a delete activity and deletes the original object" do
      note = insert(:note_activity)
      object = Object.normalize(note)
      {:ok, delete} = ActivityPub.delete(object)

      assert delete.data["type"] == "Delete"
      assert delete.data["actor"] == note.data["actor"]
      assert delete.data["object"] == object.data["id"]

      assert Activity.get_by_id(delete.id) != nil

      assert Repo.get(Object, object.id).data["type"] == "Tombstone"
    end

    test "decrements user note count only for public activities" do
      user = insert(:user, note_count: 10)

      {:ok, a1} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "yeah",
          "visibility" => "public"
        })

      {:ok, a2} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "yeah",
          "visibility" => "unlisted"
        })

      {:ok, a3} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "yeah",
          "visibility" => "private"
        })

      {:ok, a4} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          "status" => "yeah",
          "visibility" => "direct"
        })

      {:ok, _} = Object.normalize(a1) |> ActivityPub.delete()
      {:ok, _} = Object.normalize(a2) |> ActivityPub.delete()
      {:ok, _} = Object.normalize(a3) |> ActivityPub.delete()
      {:ok, _} = Object.normalize(a4) |> ActivityPub.delete()

      user = User.get_cached_by_id(user.id)
      assert user.note_count == 10
    end

    test "it creates a delete activity and checks that it is also sent to users mentioned by the deleted object" do
      user = insert(:user)
      note = insert(:note_activity)
      object = Object.normalize(note)

      {:ok, object} =
        object
        |> Object.change(%{
          data: %{
            "actor" => object.data["actor"],
            "id" => object.data["id"],
            "to" => [user.ap_id],
            "type" => "Note"
          }
        })
        |> Object.update_and_set_cache()

      {:ok, delete} = ActivityPub.delete(object)

      assert user.ap_id in delete.data["to"]
    end

    test "decreases reply count" do
      user = insert(:user)
      user2 = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{"status" => "1", "visibility" => "public"})
      reply_data = %{"status" => "1", "in_reply_to_status_id" => activity.id}
      ap_id = activity.data["id"]

      {:ok, public_reply} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "public"))
      {:ok, unlisted_reply} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "unlisted"))
      {:ok, private_reply} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "private"))
      {:ok, direct_reply} = CommonAPI.post(user2, Map.put(reply_data, "visibility", "direct"))

      _ = CommonAPI.delete(direct_reply.id, user2)
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2

      _ = CommonAPI.delete(private_reply.id, user2)
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2

      _ = CommonAPI.delete(public_reply.id, user2)
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 1

      _ = CommonAPI.delete(unlisted_reply.id, user2)
      assert %{data: data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 0
    end

    test "it passes delete activity through MRF before deleting the object" do
      rewrite_policy = Pleroma.Config.get([:instance, :rewrite_policy])
      Pleroma.Config.put([:instance, :rewrite_policy], Pleroma.Web.ActivityPub.MRF.DropPolicy)

      on_exit(fn -> Pleroma.Config.put([:instance, :rewrite_policy], rewrite_policy) end)

      note = insert(:note_activity)
      object = Object.normalize(note)

      {:error, {:reject, _}} = ActivityPub.delete(object)

      assert Activity.get_by_id(note.id)
      assert Repo.get(Object, object.id).data["type"] == object.data["type"]
    end
  end

  describe "timeline post-processing" do
    test "it filters broken threads" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      {:ok, user1} = User.follow(user1, user3)
      assert User.following?(user1, user3)

      {:ok, user2} = User.follow(user2, user3)
      assert User.following?(user2, user3)

      {:ok, user3} = User.follow(user3, user2)
      assert User.following?(user3, user2)

      {:ok, public_activity} = CommonAPI.post(user3, %{"status" => "hi 1"})

      {:ok, private_activity_1} =
        CommonAPI.post(user3, %{"status" => "hi 2", "visibility" => "private"})

      {:ok, private_activity_2} =
        CommonAPI.post(user2, %{
          "status" => "hi 3",
          "visibility" => "private",
          "in_reply_to_status_id" => private_activity_1.id
        })

      {:ok, private_activity_3} =
        CommonAPI.post(user3, %{
          "status" => "hi 4",
          "visibility" => "private",
          "in_reply_to_status_id" => private_activity_2.id
        })

      activities =
        ActivityPub.fetch_activities([user1.ap_id | User.following(user1)])
        |> Enum.map(fn a -> a.id end)

      private_activity_1 = Activity.get_by_ap_id_with_object(private_activity_1.data["id"])

      assert [public_activity.id, private_activity_1.id, private_activity_3.id] == activities

      assert length(activities) == 3

      activities =
        ActivityPub.fetch_activities([user1.ap_id | User.following(user1)], %{"user" => user1})
        |> Enum.map(fn a -> a.id end)

      assert [public_activity.id, private_activity_1.id] == activities
      assert length(activities) == 2
    end
  end

  describe "update" do
    test "it creates an update activity with the new user data" do
      user = insert(:user)
      {:ok, user} = User.ensure_keys_present(user)
      user_data = Pleroma.Web.ActivityPub.UserView.render("user.json", %{user: user})

      {:ok, update} =
        ActivityPub.update(%{
          actor: user_data["id"],
          to: [user.follower_address],
          cc: [],
          object: user_data
        })

      assert update.data["actor"] == user.ap_id
      assert update.data["to"] == [user.follower_address]
      assert embedded_object = update.data["object"]
      assert embedded_object["id"] == user_data["id"]
      assert embedded_object["type"] == user_data["type"]
    end
  end

  test "returned pinned statuses" do
    Pleroma.Config.put([:instance, :max_pinned_statuses], 3)
    user = insert(:user)

    {:ok, activity_one} = CommonAPI.post(user, %{"status" => "HI!!!"})
    {:ok, activity_two} = CommonAPI.post(user, %{"status" => "HI!!!"})
    {:ok, activity_three} = CommonAPI.post(user, %{"status" => "HI!!!"})

    CommonAPI.pin(activity_one.id, user)
    user = refresh_record(user)

    CommonAPI.pin(activity_two.id, user)
    user = refresh_record(user)

    CommonAPI.pin(activity_three.id, user)
    user = refresh_record(user)

    activities = ActivityPub.fetch_user_activities(user, nil, %{"pinned" => "true"})

    assert 3 = length(activities)
  end

  describe "flag/1" do
    setup do
      reporter = insert(:user)
      target_account = insert(:user)
      content = "foobar"
      {:ok, activity} = CommonAPI.post(target_account, %{"status" => content})
      context = Utils.generate_context_id()

      reporter_ap_id = reporter.ap_id
      target_ap_id = target_account.ap_id
      activity_ap_id = activity.data["id"]

      activity_with_object = Activity.get_by_ap_id_with_object(activity_ap_id)

      {:ok,
       %{
         reporter: reporter,
         context: context,
         target_account: target_account,
         reported_activity: activity,
         content: content,
         activity_ap_id: activity_ap_id,
         activity_with_object: activity_with_object,
         reporter_ap_id: reporter_ap_id,
         target_ap_id: target_ap_id
       }}
    end

    test "it can create a Flag activity",
         %{
           reporter: reporter,
           context: context,
           target_account: target_account,
           reported_activity: reported_activity,
           content: content,
           activity_ap_id: activity_ap_id,
           activity_with_object: activity_with_object,
           reporter_ap_id: reporter_ap_id,
           target_ap_id: target_ap_id
         } do
      assert {:ok, activity} =
               ActivityPub.flag(%{
                 actor: reporter,
                 context: context,
                 account: target_account,
                 statuses: [reported_activity],
                 content: content
               })

      note_obj = %{
        "type" => "Note",
        "id" => activity_ap_id,
        "content" => content,
        "published" => activity_with_object.object.data["published"],
        "actor" => AccountView.render("show.json", %{user: target_account})
      }

      assert %Activity{
               actor: ^reporter_ap_id,
               data: %{
                 "type" => "Flag",
                 "content" => ^content,
                 "context" => ^context,
                 "object" => [^target_ap_id, ^note_obj]
               }
             } = activity
    end

    test_with_mock "strips status data from Flag, before federating it",
                   %{
                     reporter: reporter,
                     context: context,
                     target_account: target_account,
                     reported_activity: reported_activity,
                     content: content
                   },
                   Utils,
                   [:passthrough],
                   [] do
      {:ok, activity} =
        ActivityPub.flag(%{
          actor: reporter,
          context: context,
          account: target_account,
          statuses: [reported_activity],
          content: content
        })

      new_data =
        put_in(activity.data, ["object"], [target_account.ap_id, reported_activity.data["id"]])

      assert_called(Utils.maybe_federate(%{activity | data: new_data}))
    end
  end

  test "fetch_activities/2 returns activities addressed to a list " do
    user = insert(:user)
    member = insert(:user)
    {:ok, list} = Pleroma.List.create("foo", user)
    {:ok, list} = Pleroma.List.follow(list, member)

    {:ok, activity} =
      CommonAPI.post(user, %{"status" => "foobar", "visibility" => "list:#{list.id}"})

    activity = Repo.preload(activity, :bookmark)
    activity = %Activity{activity | thread_muted?: !!activity.thread_muted?}

    assert ActivityPub.fetch_activities([], %{"user" => user}) == [activity]
  end

  def data_uri do
    File.read!("test/fixtures/avatar_data_uri")
  end

  describe "fetch_activities_bounded" do
    test "fetches private posts for followed users" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "thought I looked cute might delete later :3",
          "visibility" => "private"
        })

      [result] = ActivityPub.fetch_activities_bounded([user.follower_address], [])
      assert result.id == activity.id
    end

    test "fetches only public posts for other users" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{"status" => "#cofe", "visibility" => "public"})

      {:ok, _private_activity} =
        CommonAPI.post(user, %{
          "status" => "why is tenshi eating a corndog so cute?",
          "visibility" => "private"
        })

      [result] = ActivityPub.fetch_activities_bounded([], [user.follower_address])
      assert result.id == activity.id
    end
  end

  describe "fetch_follow_information_for_user" do
    test "syncronizes following/followers counters" do
      user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/fuser2/followers",
          following_address: "http://localhost:4001/users/fuser2/following"
        )

      {:ok, info} = ActivityPub.fetch_follow_information_for_user(user)
      assert info.follower_count == 527
      assert info.following_count == 267
    end

    test "detects hidden followers" do
      mock(fn env ->
        case env.url do
          "http://localhost:4001/users/masto_closed/followers?page=1" ->
            %Tesla.Env{status: 403, body: ""}

          _ ->
            apply(HttpRequestMock, :request, [env])
        end
      end)

      user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following"
        )

      {:ok, follow_info} = ActivityPub.fetch_follow_information_for_user(user)
      assert follow_info.hide_followers == true
      assert follow_info.hide_follows == false
    end

    test "detects hidden follows" do
      mock(fn env ->
        case env.url do
          "http://localhost:4001/users/masto_closed/following?page=1" ->
            %Tesla.Env{status: 403, body: ""}

          _ ->
            apply(HttpRequestMock, :request, [env])
        end
      end)

      user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_closed/followers",
          following_address: "http://localhost:4001/users/masto_closed/following"
        )

      {:ok, follow_info} = ActivityPub.fetch_follow_information_for_user(user)
      assert follow_info.hide_followers == false
      assert follow_info.hide_follows == true
    end

    test "detects hidden follows/followers for friendica" do
      user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:8080/followers/fuser3",
          following_address: "http://localhost:8080/following/fuser3"
        )

      {:ok, follow_info} = ActivityPub.fetch_follow_information_for_user(user)
      assert follow_info.hide_followers == true
      assert follow_info.follower_count == 296
      assert follow_info.following_count == 32
      assert follow_info.hide_follows == true
    end
  end

  describe "fetch_favourites/3" do
    test "returns a favourite activities sorted by adds to favorite" do
      user = insert(:user)
      other_user = insert(:user)
      user1 = insert(:user)
      user2 = insert(:user)
      {:ok, a1} = CommonAPI.post(user1, %{"status" => "bla"})
      {:ok, _a2} = CommonAPI.post(user2, %{"status" => "traps are happy"})
      {:ok, a3} = CommonAPI.post(user2, %{"status" => "Trees Are "})
      {:ok, a4} = CommonAPI.post(user2, %{"status" => "Agent Smith "})
      {:ok, a5} = CommonAPI.post(user1, %{"status" => "Red or Blue "})

      {:ok, _, _} = CommonAPI.favorite(a4.id, user)
      {:ok, _, _} = CommonAPI.favorite(a3.id, other_user)
      Process.sleep(1000)
      {:ok, _, _} = CommonAPI.favorite(a3.id, user)
      {:ok, _, _} = CommonAPI.favorite(a5.id, other_user)
      Process.sleep(1000)
      {:ok, _, _} = CommonAPI.favorite(a5.id, user)
      {:ok, _, _} = CommonAPI.favorite(a4.id, other_user)
      Process.sleep(1000)
      {:ok, _, _} = CommonAPI.favorite(a1.id, user)
      {:ok, _, _} = CommonAPI.favorite(a1.id, other_user)
      result = ActivityPub.fetch_favourites(user)

      assert Enum.map(result, & &1.id) == [a1.id, a5.id, a3.id, a4.id]

      result = ActivityPub.fetch_favourites(user, %{"limit" => 2})
      assert Enum.map(result, & &1.id) == [a1.id, a5.id]
    end
  end

  describe "Move activity" do
    test "create" do
      %{ap_id: old_ap_id} = old_user = insert(:user)
      %{ap_id: new_ap_id} = new_user = insert(:user, also_known_as: [old_ap_id])
      follower = insert(:user)
      follower_move_opted_out = insert(:user, allow_following_move: false)

      User.follow(follower, old_user)
      User.follow(follower_move_opted_out, old_user)

      assert User.following?(follower, old_user)
      assert User.following?(follower_move_opted_out, old_user)

      assert {:ok, activity} = ActivityPub.move(old_user, new_user)

      assert %Activity{
               actor: ^old_ap_id,
               data: %{
                 "actor" => ^old_ap_id,
                 "object" => ^old_ap_id,
                 "target" => ^new_ap_id,
                 "type" => "Move"
               },
               local: true
             } = activity

      params = %{
        "op" => "move_following",
        "origin_id" => old_user.id,
        "target_id" => new_user.id
      }

      assert_enqueued(worker: Pleroma.Workers.BackgroundWorker, args: params)

      Pleroma.Workers.BackgroundWorker.perform(params, nil)

      refute User.following?(follower, old_user)
      assert User.following?(follower, new_user)

      assert User.following?(follower_move_opted_out, old_user)
      refute User.following?(follower_move_opted_out, new_user)

      activity = %Activity{activity | object: nil}

      assert [%Notification{activity: ^activity}] =
               Notification.for_user(follower, %{with_move: true})

      assert [%Notification{activity: ^activity}] =
               Notification.for_user(follower_move_opted_out, %{with_move: true})
    end

    test "old user must be in the new user's `also_known_as` list" do
      old_user = insert(:user)
      new_user = insert(:user)

      assert {:error, "Target account must have the origin in `alsoKnownAs`"} =
               ActivityPub.move(old_user, new_user)
    end
  end
end
