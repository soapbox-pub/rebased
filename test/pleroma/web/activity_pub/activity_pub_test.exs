# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ActivityPubTest do
  use Pleroma.DataCase
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Activity
  alias Pleroma.Builders.ActivityBuilder
  alias Pleroma.Config
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.AdminAPI.AccountView
  alias Pleroma.Web.CommonAPI

  import ExUnit.CaptureLog
  import Mock
  import Pleroma.Factory
  import Tesla.Mock

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do: clear_config([:instance, :federating])

  describe "streaming out participations" do
    test "it streams them out" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})

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
            status: "@#{user_two.nickname}",
            visibility: "direct"
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

      {:ok, public_activity} = CommonAPI.post(user, %{status: ".", visibility: "public"})

      {:ok, direct_activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})

      {:ok, unlisted_activity} = CommonAPI.post(user, %{status: ".", visibility: "unlisted"})

      {:ok, private_activity} = CommonAPI.post(user, %{status: ".", visibility: "private"})

      activities = ActivityPub.fetch_activities([], %{visibility: "direct", actor_id: user.ap_id})

      assert activities == [direct_activity]

      activities =
        ActivityPub.fetch_activities([], %{visibility: "unlisted", actor_id: user.ap_id})

      assert activities == [unlisted_activity]

      activities =
        ActivityPub.fetch_activities([], %{visibility: "private", actor_id: user.ap_id})

      assert activities == [private_activity]

      activities = ActivityPub.fetch_activities([], %{visibility: "public", actor_id: user.ap_id})

      assert activities == [public_activity]

      activities =
        ActivityPub.fetch_activities([], %{
          visibility: ~w[private public],
          actor_id: user.ap_id
        })

      assert activities == [public_activity, private_activity]
    end
  end

  describe "fetching excluded by visibility" do
    test "it excludes by the appropriate visibility" do
      user = insert(:user)

      {:ok, public_activity} = CommonAPI.post(user, %{status: ".", visibility: "public"})

      {:ok, direct_activity} = CommonAPI.post(user, %{status: ".", visibility: "direct"})

      {:ok, unlisted_activity} = CommonAPI.post(user, %{status: ".", visibility: "unlisted"})

      {:ok, private_activity} = CommonAPI.post(user, %{status: ".", visibility: "private"})

      activities =
        ActivityPub.fetch_activities([], %{
          exclude_visibilities: "direct",
          actor_id: user.ap_id
        })

      assert public_activity in activities
      assert unlisted_activity in activities
      assert private_activity in activities
      refute direct_activity in activities

      activities =
        ActivityPub.fetch_activities([], %{
          exclude_visibilities: "unlisted",
          actor_id: user.ap_id
        })

      assert public_activity in activities
      refute unlisted_activity in activities
      assert private_activity in activities
      assert direct_activity in activities

      activities =
        ActivityPub.fetch_activities([], %{
          exclude_visibilities: "private",
          actor_id: user.ap_id
        })

      assert public_activity in activities
      assert unlisted_activity in activities
      refute private_activity in activities
      assert direct_activity in activities

      activities =
        ActivityPub.fetch_activities([], %{
          exclude_visibilities: "public",
          actor_id: user.ap_id
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
      assert user.ap_enabled
      assert user.follower_address == "http://mastodon.example.org/users/admin/followers"
    end

    test "it returns a user that is invisible" do
      user_id = "http://mastodon.example.org/users/relay"
      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)
      assert User.invisible?(user)
    end

    test "it returns a user that accepts chat messages" do
      user_id = "http://mastodon.example.org/users/admin"
      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)

      assert user.accepts_chat_messages
    end

    test "works for guppe actors" do
      user_id = "https://gup.pe/u/bernie2020"

      Tesla.Mock.mock(fn
        %{method: :get, url: ^user_id} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/guppe-actor.json"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)

      assert user.name == "Bernie2020 group"
      assert user.actor_type == "Group"
    end

    test "works for bridgy actors" do
      user_id = "https://fed.brid.gy/jk.nipponalba.scot"

      Tesla.Mock.mock(fn
        %{method: :get, url: ^user_id} ->
          %Tesla.Env{
            status: 200,
            body: File.read!("test/fixtures/bridgy/actor.json"),
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = ActivityPub.make_user_from_ap_id(user_id)

      assert user.actor_type == "Person"

      assert user.avatar == %{
               "type" => "Image",
               "url" => [%{"href" => "https://jk.nipponalba.scot/images/profile.jpg"}]
             }

      assert user.banner == %{
               "type" => "Image",
               "url" => [%{"href" => "https://jk.nipponalba.scot/images/profile.jpg"}]
             }
    end

    test "fetches user featured collection" do
      ap_id = "https://example.com/users/lain"

      featured_url = "https://example.com/users/lain/collections/featured"

      user_data =
        "test/fixtures/users_mock/user.json"
        |> File.read!()
        |> String.replace("{{nickname}}", "lain")
        |> Jason.decode!()
        |> Map.put("featured", featured_url)
        |> Jason.encode!()

      object_id = Ecto.UUID.generate()

      featured_data =
        "test/fixtures/mastodon/collections/featured.json"
        |> File.read!()
        |> String.replace("{{domain}}", "example.com")
        |> String.replace("{{nickname}}", "lain")
        |> String.replace("{{object_id}}", object_id)

      object_url = "https://example.com/objects/#{object_id}"

      object_data =
        "test/fixtures/statuses/note.json"
        |> File.read!()
        |> String.replace("{{object_id}}", object_id)
        |> String.replace("{{nickname}}", "lain")

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: ^ap_id
        } ->
          %Tesla.Env{
            status: 200,
            body: user_data,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{
          method: :get,
          url: ^featured_url
        } ->
          %Tesla.Env{
            status: 200,
            body: featured_data,
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      Tesla.Mock.mock_global(fn
        %{
          method: :get,
          url: ^object_url
        } ->
          %Tesla.Env{
            status: 200,
            body: object_data,
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = ActivityPub.make_user_from_ap_id(ap_id)
      Process.sleep(50)

      assert user.featured_address == featured_url
      assert Map.has_key?(user.pinned_objects, object_url)

      in_db = Pleroma.User.get_by_ap_id(ap_id)
      assert in_db.featured_address == featured_url
      assert Map.has_key?(user.pinned_objects, object_url)

      assert %{data: %{"id" => ^object_url}} = Object.get_by_ap_id(object_url)
    end

    test "fetches user featured collection without embedded object" do
      ap_id = "https://example.com/users/lain"

      featured_url = "https://example.com/users/lain/collections/featured"

      user_data =
        "test/fixtures/users_mock/user.json"
        |> File.read!()
        |> String.replace("{{nickname}}", "lain")
        |> Jason.decode!()
        |> Map.put("featured", featured_url)
        |> Jason.encode!()

      object_id = Ecto.UUID.generate()

      featured_data =
        "test/fixtures/mastodon/collections/external_featured.json"
        |> File.read!()
        |> String.replace("{{domain}}", "example.com")
        |> String.replace("{{nickname}}", "lain")
        |> String.replace("{{object_id}}", object_id)

      object_url = "https://example.com/objects/#{object_id}"

      object_data =
        "test/fixtures/statuses/note.json"
        |> File.read!()
        |> String.replace("{{object_id}}", object_id)
        |> String.replace("{{nickname}}", "lain")

      Tesla.Mock.mock(fn
        %{
          method: :get,
          url: ^ap_id
        } ->
          %Tesla.Env{
            status: 200,
            body: user_data,
            headers: [{"content-type", "application/activity+json"}]
          }

        %{
          method: :get,
          url: ^featured_url
        } ->
          %Tesla.Env{
            status: 200,
            body: featured_data,
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      Tesla.Mock.mock_global(fn
        %{
          method: :get,
          url: ^object_url
        } ->
          %Tesla.Env{
            status: 200,
            body: object_data,
            headers: [{"content-type", "application/activity+json"}]
          }
      end)

      {:ok, user} = ActivityPub.make_user_from_ap_id(ap_id)
      Process.sleep(50)

      assert user.featured_address == featured_url
      assert Map.has_key?(user.pinned_objects, object_url)

      in_db = Pleroma.User.get_by_ap_id(ap_id)
      assert in_db.featured_address == featured_url
      assert Map.has_key?(user.pinned_objects, object_url)

      assert %{data: %{"id" => ^object_url}} = Object.get_by_ap_id(object_url)
    end
  end

  test "it fetches the appropriate tag-restricted posts" do
    user = insert(:user)

    {:ok, status_one} = CommonAPI.post(user, %{status: ". #TEST"})
    {:ok, status_two} = CommonAPI.post(user, %{status: ". #essais"})
    {:ok, status_three} = CommonAPI.post(user, %{status: ". #test #Reject"})

    {:ok, status_four} = CommonAPI.post(user, %{status: ". #Any1 #any2"})
    {:ok, status_five} = CommonAPI.post(user, %{status: ". #Any2 #any1"})

    for hashtag_timeline_strategy <- [:enabled, :disabled] do
      clear_config([:features, :improved_hashtag_timeline], hashtag_timeline_strategy)

      fetch_one = ActivityPub.fetch_activities([], %{type: "Create", tag: "test"})

      fetch_two = ActivityPub.fetch_activities([], %{type: "Create", tag: ["TEST", "essais"]})

      fetch_three =
        ActivityPub.fetch_activities([], %{
          type: "Create",
          tag: ["test", "Essais"],
          tag_reject: ["reject"]
        })

      fetch_four =
        ActivityPub.fetch_activities([], %{
          type: "Create",
          tag: ["test"],
          tag_all: ["test", "REJECT"]
        })

      # Testing that deduplication (if needed) is done on DB (not Ecto) level; :limit is important
      fetch_five =
        ActivityPub.fetch_activities([], %{
          type: "Create",
          tag: ["ANY1", "any2"],
          limit: 2
        })

      fetch_six =
        ActivityPub.fetch_activities([], %{
          type: "Create",
          tag: ["any1", "Any2"],
          tag_all: [],
          tag_reject: []
        })

      # Regression test: passing empty lists as filter options shouldn't affect the results
      assert fetch_five == fetch_six

      [fetch_one, fetch_two, fetch_three, fetch_four, fetch_five] =
        Enum.map([fetch_one, fetch_two, fetch_three, fetch_four, fetch_five], fn statuses ->
          Enum.map(statuses, fn s -> Repo.preload(s, object: :hashtags) end)
        end)

      assert fetch_one == [status_one, status_three]
      assert fetch_two == [status_one, status_two, status_three]
      assert fetch_three == [status_one, status_two]
      assert fetch_four == [status_three]
      assert fetch_five == [status_four, status_five]
    end
  end

  describe "insertion" do
    test "drops activities beyond a certain limit" do
      limit = Config.get([:instance, :remote_limit])

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

      assert {:error, :remote_limit} = ActivityPub.insert(data)
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
      object = Pleroma.Object.normalize(activity, fetch: false)

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
      assert object = Object.normalize(activity, fetch: false)
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

      timeline = ActivityPub.fetch_activities([], %{type: ["Listen"]})

      assert length(timeline) == 3
    end
  end

  describe "create activities" do
    setup do
      [user: insert(:user)]
    end

    test "it reverts create", %{user: user} do
      with_mock(Utils, [:passthrough], maybe_federate: fn _ -> {:error, :reverted} end) do
        assert {:error, :reverted} =
                 ActivityPub.create(%{
                   to: ["user1", "user2"],
                   actor: user,
                   context: "",
                   object: %{
                     "to" => ["user1", "user2"],
                     "type" => "Note",
                     "content" => "testing"
                   }
                 })
      end

      assert Repo.aggregate(Activity, :count, :id) == 0
      assert Repo.aggregate(Object, :count, :id) == 0
    end

    test "creates activity if expiration is not configured and expires_at is not passed", %{
      user: user
    } do
      clear_config([Pleroma.Workers.PurgeExpiredActivity, :enabled], false)

      assert {:ok, _} =
               ActivityPub.create(%{
                 to: ["user1", "user2"],
                 actor: user,
                 context: "",
                 object: %{
                   "to" => ["user1", "user2"],
                   "type" => "Note",
                   "content" => "testing"
                 }
               })
    end

    test "rejects activity if expires_at present but expiration is not configured", %{user: user} do
      clear_config([Pleroma.Workers.PurgeExpiredActivity, :enabled], false)

      assert {:error, :expired_activities_disabled} =
               ActivityPub.create(%{
                 to: ["user1", "user2"],
                 actor: user,
                 context: "",
                 object: %{
                   "to" => ["user1", "user2"],
                   "type" => "Note",
                   "content" => "testing"
                 },
                 additional: %{
                   "expires_at" => DateTime.utc_now()
                 }
               })

      assert Repo.aggregate(Activity, :count, :id) == 0
      assert Repo.aggregate(Object, :count, :id) == 0
    end

    test "removes doubled 'to' recipients", %{user: user} do
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

    test "increases user note count only for public activities", %{user: user} do
      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          status: "1",
          visibility: "public"
        })

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          status: "2",
          visibility: "unlisted"
        })

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          status: "2",
          visibility: "private"
        })

      {:ok, _} =
        CommonAPI.post(User.get_cached_by_id(user.id), %{
          status: "3",
          visibility: "direct"
        })

      user = User.get_cached_by_id(user.id)
      assert user.note_count == 2
    end

    test "increases replies count", %{user: user} do
      user2 = insert(:user)

      {:ok, activity} = CommonAPI.post(user, %{status: "1", visibility: "public"})
      ap_id = activity.data["id"]
      reply_data = %{status: "1", in_reply_to_status_id: activity.id}

      # public
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, :visibility, "public"))
      assert %{data: _data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 1

      # unlisted
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, :visibility, "unlisted"))
      assert %{data: _data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2

      # private
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, :visibility, "private"))
      assert %{data: _data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
      assert object.data["repliesCount"] == 2

      # direct
      {:ok, _} = CommonAPI.post(user2, Map.put(reply_data, :visibility, "direct"))
      assert %{data: _data, object: object} = Activity.get_by_ap_id_with_object(ap_id)
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

      activities = ActivityPub.fetch_activities_for_context("2hu", %{blocking_user: user})
      assert activities == [activity_two, activity]
    end

    test "doesn't return activities with filtered words" do
      user = insert(:user)
      user_two = insert(:user)
      insert(:filter, user: user, phrase: "test", hide: true)

      {:ok, %{id: id1, data: %{"context" => context}}} = CommonAPI.post(user, %{status: "1"})

      {:ok, %{id: id2}} = CommonAPI.post(user_two, %{status: "2", in_reply_to_status_id: id1})

      {:ok, %{id: id3} = user_activity} =
        CommonAPI.post(user, %{status: "3 test?", in_reply_to_status_id: id2})

      {:ok, %{id: id4} = filtered_activity} =
        CommonAPI.post(user_two, %{status: "4 test!", in_reply_to_status_id: id3})

      {:ok, _} = CommonAPI.post(user, %{status: "5", in_reply_to_status_id: id4})

      activities =
        context
        |> ActivityPub.fetch_activities_for_context(%{user: user})
        |> Enum.map(& &1.id)

      assert length(activities) == 4
      assert user_activity.id in activities
      refute filtered_activity.id in activities
    end
  end

  test "doesn't return blocked activities" do
    activity_one = insert(:note_activity)
    activity_two = insert(:note_activity)
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)
    {:ok, _user_relationship} = User.block(user, %{ap_id: activity_one.data["actor"]})

    activities = ActivityPub.fetch_activities([], %{blocking_user: user, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_one)

    {:ok, _user_block} = User.unblock(user, %{ap_id: activity_one.data["actor"]})

    activities = ActivityPub.fetch_activities([], %{blocking_user: user, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    {:ok, _user_relationship} = User.block(user, %{ap_id: activity_three.data["actor"]})
    {:ok, %{data: %{"object" => id}}} = CommonAPI.repeat(activity_three.id, booster)
    %Activity{} = boost_activity = Activity.get_create_by_object_ap_id(id)
    activity_three = Activity.get_by_id(activity_three.id)

    activities = ActivityPub.fetch_activities([], %{blocking_user: user, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)

    activities = ActivityPub.fetch_activities([], %{blocking_user: nil, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)
  end

  test "doesn't return activities from deactivated users" do
    _user = insert(:user)
    deactivated = insert(:user)
    active = insert(:user)
    {:ok, activity_one} = CommonAPI.post(deactivated, %{status: "hey!"})
    {:ok, activity_two} = CommonAPI.post(active, %{status: "yay!"})
    {:ok, _updated_user} = User.set_activation(deactivated, false)

    activities = ActivityPub.fetch_activities([], %{})

    refute Enum.member?(activities, activity_one)
    assert Enum.member?(activities, activity_two)
  end

  test "always see your own posts even when they address people you block" do
    user = insert(:user)
    blockee = insert(:user)

    {:ok, _} = User.block(user, blockee)
    {:ok, activity} = CommonAPI.post(user, %{status: "hey! @#{blockee.nickname}"})

    activities = ActivityPub.fetch_activities([], %{blocking_user: user})

    assert Enum.member?(activities, activity)
  end

  test "doesn't return transitive interactions concerning blocked users" do
    blocker = insert(:user)
    blockee = insert(:user)
    friend = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:ok, activity_one} = CommonAPI.post(friend, %{status: "hey!"})

    {:ok, activity_two} = CommonAPI.post(friend, %{status: "hey! @#{blockee.nickname}"})

    {:ok, activity_three} = CommonAPI.post(blockee, %{status: "hey! @#{friend.nickname}"})

    {:ok, activity_four} = CommonAPI.post(blockee, %{status: "hey! @#{blocker.nickname}"})

    activities = ActivityPub.fetch_activities([], %{blocking_user: blocker})

    assert Enum.member?(activities, activity_one)
    refute Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_four)
  end

  test "doesn't return announce activities with blocked users in 'to'" do
    blocker = insert(:user)
    blockee = insert(:user)
    friend = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:ok, activity_one} = CommonAPI.post(friend, %{status: "hey!"})

    {:ok, activity_two} = CommonAPI.post(blockee, %{status: "hey! @#{friend.nickname}"})

    {:ok, activity_three} = CommonAPI.repeat(activity_two.id, friend)

    activities =
      ActivityPub.fetch_activities([], %{blocking_user: blocker})
      |> Enum.map(fn act -> act.id end)

    assert Enum.member?(activities, activity_one.id)
    refute Enum.member?(activities, activity_two.id)
    refute Enum.member?(activities, activity_three.id)
  end

  test "doesn't return announce activities with blocked users in 'cc'" do
    blocker = insert(:user)
    blockee = insert(:user)
    friend = insert(:user)

    {:ok, _user_relationship} = User.block(blocker, blockee)

    {:ok, activity_one} = CommonAPI.post(friend, %{status: "hey!"})

    {:ok, activity_two} = CommonAPI.post(blockee, %{status: "hey! @#{friend.nickname}"})

    assert object = Pleroma.Object.normalize(activity_two, fetch: false)

    data = %{
      "actor" => friend.ap_id,
      "object" => object.data["id"],
      "context" => object.data["context"],
      "type" => "Announce",
      "to" => ["https://www.w3.org/ns/activitystreams#Public"],
      "cc" => [blockee.ap_id]
    }

    assert {:ok, activity_three} = ActivityPub.insert(data)

    activities =
      ActivityPub.fetch_activities([], %{blocking_user: blocker})
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

    activities = ActivityPub.fetch_activities([], %{blocking_user: user, skip_preload: true})

    refute activity in activities

    followed_user = insert(:user)
    CommonAPI.follow(user, followed_user)
    {:ok, repeat_activity} = CommonAPI.repeat(activity.id, followed_user)

    activities = ActivityPub.fetch_activities([], %{blocking_user: user, skip_preload: true})

    refute repeat_activity in activities
  end

  test "see your own posts even when they adress actors from blocked domains" do
    user = insert(:user)

    domain = "dogwhistle.zone"
    domain_user = insert(:user, %{ap_id: "https://#{domain}/@pundit"})

    {:ok, user} = User.block_domain(user, domain)

    {:ok, activity} = CommonAPI.post(user, %{status: "hey! @#{domain_user.nickname}"})

    activities = ActivityPub.fetch_activities([], %{blocking_user: user})

    assert Enum.member?(activities, activity)
  end

  test "does return activities from followed users on blocked domains" do
    domain = "meanies.social"
    domain_user = insert(:user, %{ap_id: "https://#{domain}/@pundit"})
    blocker = insert(:user)

    {:ok, blocker, domain_user} = User.follow(blocker, domain_user)
    {:ok, blocker} = User.block_domain(blocker, domain)

    assert User.following?(blocker, domain_user)
    assert User.blocks_domain?(blocker, domain_user)
    refute User.blocks?(blocker, domain_user)

    note = insert(:note, %{data: %{"actor" => domain_user.ap_id}})
    activity = insert(:note_activity, %{note: note})

    activities = ActivityPub.fetch_activities([], %{blocking_user: blocker, skip_preload: true})

    assert activity in activities

    # And check that if the guy we DO follow boosts someone else from their domain,
    # that should be hidden
    another_user = insert(:user, %{ap_id: "https://#{domain}/@meanie2"})
    bad_note = insert(:note, %{data: %{"actor" => another_user.ap_id}})
    bad_activity = insert(:note_activity, %{note: bad_note})
    {:ok, repeat_activity} = CommonAPI.repeat(bad_activity.id, domain_user)

    activities = ActivityPub.fetch_activities([], %{blocking_user: blocker, skip_preload: true})

    refute repeat_activity in activities
  end

  test "returns your own posts regardless of mute" do
    user = insert(:user)
    muted = insert(:user)

    {:ok, muted_post} = CommonAPI.post(muted, %{status: "Im stupid"})

    {:ok, reply} =
      CommonAPI.post(user, %{status: "I'm muting you", in_reply_to_status_id: muted_post.id})

    {:ok, _} = User.mute(user, muted)

    [activity] = ActivityPub.fetch_activities([], %{muting_user: user, skip_preload: true})

    assert activity.id == reply.id
  end

  test "doesn't return muted activities" do
    activity_one = insert(:note_activity)
    activity_two = insert(:note_activity)
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)

    activity_one_actor = User.get_by_ap_id(activity_one.data["actor"])
    {:ok, _user_relationships} = User.mute(user, activity_one_actor)

    activities = ActivityPub.fetch_activities([], %{muting_user: user, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    refute Enum.member?(activities, activity_one)

    # Calling with 'with_muted' will deliver muted activities, too.
    activities =
      ActivityPub.fetch_activities([], %{
        muting_user: user,
        with_muted: true,
        skip_preload: true
      })

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    {:ok, _user_mute} = User.unmute(user, activity_one_actor)

    activities = ActivityPub.fetch_activities([], %{muting_user: user, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    assert Enum.member?(activities, activity_three)
    assert Enum.member?(activities, activity_one)

    activity_three_actor = User.get_by_ap_id(activity_three.data["actor"])
    {:ok, _user_relationships} = User.mute(user, activity_three_actor)
    {:ok, %{data: %{"object" => id}}} = CommonAPI.repeat(activity_three.id, booster)
    %Activity{} = boost_activity = Activity.get_create_by_object_ap_id(id)
    activity_three = Activity.get_by_id(activity_three.id)

    activities = ActivityPub.fetch_activities([], %{muting_user: user, skip_preload: true})

    assert Enum.member?(activities, activity_two)
    refute Enum.member?(activities, activity_three)
    refute Enum.member?(activities, boost_activity)
    assert Enum.member?(activities, activity_one)

    activities = ActivityPub.fetch_activities([], %{muting_user: nil, skip_preload: true})

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

    assert [_activity_one] = ActivityPub.fetch_activities([], %{muting_user: user})
  end

  test "returns thread muted activities when with_muted is set" do
    user = insert(:user)
    _activity_one = insert(:note_activity)
    note_two = insert(:note, data: %{"context" => "suya.."})
    activity_two = insert(:note_activity, note: note_two)

    {:ok, _activity_two} = CommonAPI.add_mute(user, activity_two)

    assert [_activity_two, _activity_one] =
             ActivityPub.fetch_activities([], %{muting_user: user, with_muted: true})
  end

  test "does include announces on request" do
    activity_three = insert(:note_activity)
    user = insert(:user)
    booster = insert(:user)

    {:ok, user, booster} = User.follow(user, booster)

    {:ok, announce} = CommonAPI.repeat(activity_three.id, booster)

    [announce_activity] = ActivityPub.fetch_activities([user.ap_id | User.following(user)])

    assert announce_activity.id == announce.id
  end

  test "excludes reblogs on request" do
    user = insert(:user)
    {:ok, expected_activity} = ActivityBuilder.insert(%{"type" => "Create"}, %{:user => user})
    {:ok, _} = ActivityBuilder.insert(%{"type" => "Announce"}, %{:user => user})

    [activity] = ActivityPub.fetch_user_activities(user, nil, %{exclude_reblogs: true})

    assert activity == expected_activity
  end

  describe "irreversible filters" do
    setup do
      user = insert(:user)
      user_two = insert(:user)

      insert(:filter, user: user_two, phrase: "cofe", hide: true)
      insert(:filter, user: user_two, phrase: "ok boomer", hide: true)
      insert(:filter, user: user_two, phrase: "test", hide: false)

      params = %{
        type: ["Create", "Announce"],
        user: user_two
      }

      {:ok, %{user: user, user_two: user_two, params: params}}
    end

    test "it returns statuses if they don't contain exact filter words", %{
      user: user,
      params: params
    } do
      {:ok, _} = CommonAPI.post(user, %{status: "hey"})
      {:ok, _} = CommonAPI.post(user, %{status: "got cofefe?"})
      {:ok, _} = CommonAPI.post(user, %{status: "I am not a boomer"})
      {:ok, _} = CommonAPI.post(user, %{status: "ok boomers"})
      {:ok, _} = CommonAPI.post(user, %{status: "ccofee is not a word"})
      {:ok, _} = CommonAPI.post(user, %{status: "this is a test"})

      activities = ActivityPub.fetch_activities([], params)

      assert Enum.count(activities) == 6
    end

    test "it does not filter user's own statuses", %{user_two: user_two, params: params} do
      {:ok, _} = CommonAPI.post(user_two, %{status: "Give me some cofe!"})
      {:ok, _} = CommonAPI.post(user_two, %{status: "ok boomer"})

      activities = ActivityPub.fetch_activities([], params)

      assert Enum.count(activities) == 2
    end

    test "it excludes statuses with filter words", %{user: user, params: params} do
      {:ok, _} = CommonAPI.post(user, %{status: "Give me some cofe!"})
      {:ok, _} = CommonAPI.post(user, %{status: "ok boomer"})
      {:ok, _} = CommonAPI.post(user, %{status: "is it a cOfE?"})
      {:ok, _} = CommonAPI.post(user, %{status: "cofe is all I need"})
      {:ok, _} = CommonAPI.post(user, %{status: "— ok BOOMER\n"})

      activities = ActivityPub.fetch_activities([], params)

      assert Enum.empty?(activities)
    end

    test "it returns all statuses if user does not have any filters" do
      another_user = insert(:user)
      {:ok, _} = CommonAPI.post(another_user, %{status: "got cofe?"})
      {:ok, _} = CommonAPI.post(another_user, %{status: "test!"})

      activities =
        ActivityPub.fetch_activities([], %{
          type: ["Create", "Announce"],
          user: another_user
        })

      assert Enum.count(activities) == 2
    end
  end

  describe "public fetch activities" do
    test "doesn't retrieve unlisted activities" do
      user = insert(:user)

      {:ok, _unlisted_activity} = CommonAPI.post(user, %{status: "yeah", visibility: "unlisted"})

      {:ok, listed_activity} = CommonAPI.post(user, %{status: "yeah"})

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

      activities = ActivityPub.fetch_public_activities(%{since_id: since_id})

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

      activities = ActivityPub.fetch_public_activities(%{max_id: max_id})

      assert length(activities) == 20
      assert collect_ids(activities) == collect_ids(expected_activities)
    end

    test "paginates via offset/limit" do
      _first_part_activities = ActivityBuilder.insert_list(10)
      second_part_activities = ActivityBuilder.insert_list(10)

      later_activities = ActivityBuilder.insert_list(10)

      activities = ActivityPub.fetch_public_activities(%{page: "2", page_size: "20"}, :offset)

      assert length(activities) == 20

      assert collect_ids(activities) ==
               collect_ids(second_part_activities) ++ collect_ids(later_activities)
    end

    test "doesn't return reblogs for users for whom reblogs have been muted" do
      activity = insert(:note_activity)
      user = insert(:user)
      booster = insert(:user)
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(user, booster)

      {:ok, activity} = CommonAPI.repeat(activity.id, booster)

      activities = ActivityPub.fetch_activities([], %{muting_user: user})

      refute Enum.any?(activities, fn %{id: id} -> id == activity.id end)
    end

    test "returns reblogs for users for whom reblogs have not been muted" do
      activity = insert(:note_activity)
      user = insert(:user)
      booster = insert(:user)
      {:ok, _reblog_mute} = CommonAPI.hide_reblogs(user, booster)
      {:ok, _reblog_mute} = CommonAPI.show_reblogs(user, booster)

      {:ok, activity} = CommonAPI.repeat(activity.id, booster)

      activities = ActivityPub.fetch_activities([], %{muting_user: user})

      assert Enum.any?(activities, fn %{id: id} -> id == activity.id end)
    end
  end

  describe "uploading files" do
    setup do
      test_file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      %{test_file: test_file}
    end

    test "sets a description if given", %{test_file: file} do
      {:ok, %Object{} = object} = ActivityPub.upload(file, description: "a cool file")
      assert object.data["name"] == "a cool file"
    end

    test "it sets the default description depending on the configuration", %{test_file: file} do
      clear_config([Pleroma.Upload, :default_description])

      clear_config([Pleroma.Upload, :default_description], nil)
      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == ""

      clear_config([Pleroma.Upload, :default_description], :filename)
      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == "an_image.jpg"

      clear_config([Pleroma.Upload, :default_description], "unnamed attachment")
      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == "unnamed attachment"
    end

    test "copies the file to the configured folder", %{test_file: file} do
      clear_config([Pleroma.Upload, :default_description], :filename)
      {:ok, %Object{} = object} = ActivityPub.upload(file)
      assert object.data["name"] == "an_image.jpg"
    end

    test "works with base64 encoded images" do
      file = %{
        img: data_uri()
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

  describe "unfollowing" do
    test "it reverts unfollow activity" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)

      with_mock(Utils, [:passthrough], maybe_federate: fn _ -> {:error, :reverted} end) do
        assert {:error, :reverted} = ActivityPub.unfollow(follower, followed)
      end

      activity = Activity.get_by_id(follow_activity.id)
      assert activity.data["type"] == "Follow"
      assert activity.data["actor"] == follower.ap_id

      assert activity.data["object"] == followed.ap_id
    end

    test "creates an undo activity for the last follow" do
      follower = insert(:user)
      followed = insert(:user)

      {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)
      {:ok, activity} = ActivityPub.unfollow(follower, followed)

      assert activity.data["type"] == "Undo"
      assert activity.data["actor"] == follower.ap_id

      embedded_object = activity.data["object"]
      assert is_map(embedded_object)
      assert embedded_object["type"] == "Follow"
      assert embedded_object["object"] == followed.ap_id
      assert embedded_object["id"] == follow_activity.data["id"]
    end

    test "creates an undo activity for a pending follow request" do
      follower = insert(:user)
      followed = insert(:user, %{is_locked: true})

      {:ok, _, _, follow_activity} = CommonAPI.follow(follower, followed)
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

  describe "timeline post-processing" do
    test "it filters broken threads" do
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)

      {:ok, user1, user3} = User.follow(user1, user3)
      assert User.following?(user1, user3)

      {:ok, user2, user3} = User.follow(user2, user3)
      assert User.following?(user2, user3)

      {:ok, user3, user2} = User.follow(user3, user2)
      assert User.following?(user3, user2)

      {:ok, public_activity} = CommonAPI.post(user3, %{status: "hi 1"})

      {:ok, private_activity_1} = CommonAPI.post(user3, %{status: "hi 2", visibility: "private"})

      {:ok, private_activity_2} =
        CommonAPI.post(user2, %{
          status: "hi 3",
          visibility: "private",
          in_reply_to_status_id: private_activity_1.id
        })

      {:ok, private_activity_3} =
        CommonAPI.post(user3, %{
          status: "hi 4",
          visibility: "private",
          in_reply_to_status_id: private_activity_2.id
        })

      activities =
        ActivityPub.fetch_activities([user1.ap_id | User.following(user1)])
        |> Enum.map(fn a -> a.id end)

      private_activity_1 = Activity.get_by_ap_id_with_object(private_activity_1.data["id"])

      assert [public_activity.id, private_activity_1.id, private_activity_3.id] == activities

      assert length(activities) == 3

      activities =
        ActivityPub.fetch_activities([user1.ap_id | User.following(user1)], %{user: user1})
        |> Enum.map(fn a -> a.id end)

      assert [public_activity.id, private_activity_1.id] == activities
      assert length(activities) == 2
    end
  end

  describe "flag/1" do
    setup do
      reporter = insert(:user)
      target_account = insert(:user)
      content = "foobar"
      {:ok, activity} = CommonAPI.post(target_account, %{status: content})
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
        "actor" =>
          AccountView.render("show.json", %{user: target_account, skip_visibility_check: true})
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

    test_with_mock "reverts on error",
                   %{
                     reporter: reporter,
                     context: context,
                     target_account: target_account,
                     reported_activity: reported_activity,
                     content: content
                   },
                   Utils,
                   [:passthrough],
                   maybe_federate: fn _ -> {:error, :reverted} end do
      assert {:error, :reverted} =
               ActivityPub.flag(%{
                 actor: reporter,
                 context: context,
                 account: target_account,
                 statuses: [reported_activity],
                 content: content
               })

      assert Repo.aggregate(Activity, :count, :id) == 1
      assert Repo.aggregate(Object, :count, :id) == 2
      assert Repo.aggregate(Notification, :count, :id) == 0
    end
  end

  test "fetch_activities/2 returns activities addressed to a list " do
    user = insert(:user)
    member = insert(:user)
    {:ok, list} = Pleroma.List.create("foo", user)
    {:ok, list} = Pleroma.List.follow(list, member)

    {:ok, activity} = CommonAPI.post(user, %{status: "foobar", visibility: "list:#{list.id}"})

    activity = Repo.preload(activity, :bookmark)
    activity = %Activity{activity | thread_muted?: !!activity.thread_muted?}

    assert ActivityPub.fetch_activities([], %{user: user}) == [activity]
  end

  def data_uri do
    File.read!("test/fixtures/avatar_data_uri")
  end

  describe "fetch_activities_bounded" do
    test "fetches private posts for followed users" do
      user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          status: "thought I looked cute might delete later :3",
          visibility: "private"
        })

      [result] = ActivityPub.fetch_activities_bounded([user.follower_address], [])
      assert result.id == activity.id
    end

    test "fetches only public posts for other users" do
      user = insert(:user)
      {:ok, activity} = CommonAPI.post(user, %{status: "#cofe", visibility: "public"})

      {:ok, _private_activity} =
        CommonAPI.post(user, %{
          status: "why is tenshi eating a corndog so cute?",
          visibility: "private"
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

    test "doesn't crash when follower and following counters are hidden" do
      mock(fn env ->
        case env.url do
          "http://localhost:4001/users/masto_hidden_counters/following" ->
            json(
              %{
                "@context" => "https://www.w3.org/ns/activitystreams",
                "id" => "http://localhost:4001/users/masto_hidden_counters/followers"
              },
              headers: HttpRequestMock.activitypub_object_headers()
            )

          "http://localhost:4001/users/masto_hidden_counters/following?page=1" ->
            %Tesla.Env{status: 403, body: ""}

          "http://localhost:4001/users/masto_hidden_counters/followers" ->
            json(
              %{
                "@context" => "https://www.w3.org/ns/activitystreams",
                "id" => "http://localhost:4001/users/masto_hidden_counters/following"
              },
              headers: HttpRequestMock.activitypub_object_headers()
            )

          "http://localhost:4001/users/masto_hidden_counters/followers?page=1" ->
            %Tesla.Env{status: 403, body: ""}
        end
      end)

      user =
        insert(:user,
          local: false,
          follower_address: "http://localhost:4001/users/masto_hidden_counters/followers",
          following_address: "http://localhost:4001/users/masto_hidden_counters/following"
        )

      {:ok, follow_info} = ActivityPub.fetch_follow_information_for_user(user)

      assert follow_info.hide_followers == true
      assert follow_info.follower_count == 0
      assert follow_info.hide_follows == true
      assert follow_info.following_count == 0
    end
  end

  describe "fetch_favourites/3" do
    test "returns a favourite activities sorted by adds to favorite" do
      user = insert(:user)
      other_user = insert(:user)
      user1 = insert(:user)
      user2 = insert(:user)
      {:ok, a1} = CommonAPI.post(user1, %{status: "bla"})
      {:ok, _a2} = CommonAPI.post(user2, %{status: "traps are happy"})
      {:ok, a3} = CommonAPI.post(user2, %{status: "Trees Are "})
      {:ok, a4} = CommonAPI.post(user2, %{status: "Agent Smith "})
      {:ok, a5} = CommonAPI.post(user1, %{status: "Red or Blue "})

      {:ok, _} = CommonAPI.favorite(user, a4.id)
      {:ok, _} = CommonAPI.favorite(other_user, a3.id)
      {:ok, _} = CommonAPI.favorite(user, a3.id)
      {:ok, _} = CommonAPI.favorite(other_user, a5.id)
      {:ok, _} = CommonAPI.favorite(user, a5.id)
      {:ok, _} = CommonAPI.favorite(other_user, a4.id)
      {:ok, _} = CommonAPI.favorite(user, a1.id)
      {:ok, _} = CommonAPI.favorite(other_user, a1.id)
      result = ActivityPub.fetch_favourites(user)

      assert Enum.map(result, & &1.id) == [a1.id, a5.id, a3.id, a4.id]

      result = ActivityPub.fetch_favourites(user, %{limit: 2})
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

      Pleroma.Workers.BackgroundWorker.perform(%Oban.Job{args: params})

      refute User.following?(follower, old_user)
      assert User.following?(follower, new_user)

      assert User.following?(follower_move_opted_out, old_user)
      refute User.following?(follower_move_opted_out, new_user)

      activity = %Activity{activity | object: nil}

      assert [%Notification{activity: ^activity}] = Notification.for_user(follower)

      assert [%Notification{activity: ^activity}] = Notification.for_user(follower_move_opted_out)
    end

    test "old user must be in the new user's `also_known_as` list" do
      old_user = insert(:user)
      new_user = insert(:user)

      assert {:error, "Target account must have the origin in `alsoKnownAs`"} =
               ActivityPub.move(old_user, new_user)
    end
  end

  test "doesn't retrieve replies activities with exclude_replies" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "yeah"})

    {:ok, _reply} = CommonAPI.post(user, %{status: "yeah", in_reply_to_status_id: activity.id})

    [result] = ActivityPub.fetch_public_activities(%{exclude_replies: true})

    assert result.id == activity.id

    assert length(ActivityPub.fetch_public_activities()) == 2
  end

  describe "replies filtering with public messages" do
    setup :public_messages

    test "public timeline", %{users: %{u1: user}} do
      activities_ids =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:local_only, false)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_filtering_user, user)
        |> ActivityPub.fetch_public_activities()
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 16
    end

    test "public timeline with reply_visibility `following`", %{
      users: %{u1: user},
      u1: u1,
      u2: u2,
      u3: u3,
      u4: u4,
      activities: activities
    } do
      activities_ids =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:local_only, false)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_visibility, "following")
        |> Map.put(:reply_filtering_user, user)
        |> ActivityPub.fetch_public_activities()
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 14

      visible_ids =
        Map.values(u1) ++ Map.values(u2) ++ Map.values(u4) ++ Map.values(activities) ++ [u3[:r1]]

      assert Enum.all?(visible_ids, &(&1 in activities_ids))
    end

    test "public timeline with reply_visibility `self`", %{
      users: %{u1: user},
      u1: u1,
      u2: u2,
      u3: u3,
      u4: u4,
      activities: activities
    } do
      activities_ids =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:local_only, false)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_visibility, "self")
        |> Map.put(:reply_filtering_user, user)
        |> ActivityPub.fetch_public_activities()
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 10
      visible_ids = Map.values(u1) ++ [u2[:r1], u3[:r1], u4[:r1]] ++ Map.values(activities)
      assert Enum.all?(visible_ids, &(&1 in activities_ids))
    end

    test "home timeline", %{
      users: %{u1: user},
      activities: activities,
      u1: u1,
      u2: u2,
      u3: u3,
      u4: u4
    } do
      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)
        |> Map.put(:reply_filtering_user, user)

      activities_ids =
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], params)
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 13

      visible_ids =
        Map.values(u1) ++
          Map.values(u3) ++
          [
            activities[:a1],
            activities[:a2],
            activities[:a4],
            u2[:r1],
            u2[:r3],
            u4[:r1],
            u4[:r2]
          ]

      assert Enum.all?(visible_ids, &(&1 in activities_ids))
    end

    test "home timeline with reply_visibility `following`", %{
      users: %{u1: user},
      activities: activities,
      u1: u1,
      u2: u2,
      u3: u3,
      u4: u4
    } do
      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)
        |> Map.put(:reply_visibility, "following")
        |> Map.put(:reply_filtering_user, user)

      activities_ids =
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], params)
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 11

      visible_ids =
        Map.values(u1) ++
          [
            activities[:a1],
            activities[:a2],
            activities[:a4],
            u2[:r1],
            u2[:r3],
            u3[:r1],
            u4[:r1],
            u4[:r2]
          ]

      assert Enum.all?(visible_ids, &(&1 in activities_ids))
    end

    test "home timeline with reply_visibility `self`", %{
      users: %{u1: user},
      activities: activities,
      u1: u1,
      u2: u2,
      u3: u3,
      u4: u4
    } do
      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)
        |> Map.put(:reply_visibility, "self")
        |> Map.put(:reply_filtering_user, user)

      activities_ids =
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], params)
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 9

      visible_ids =
        Map.values(u1) ++
          [
            activities[:a1],
            activities[:a2],
            activities[:a4],
            u2[:r1],
            u3[:r1],
            u4[:r1]
          ]

      assert Enum.all?(visible_ids, &(&1 in activities_ids))
    end

    test "filtering out announces where the user is the actor of the announced message" do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)
      User.follow(user, other_user)

      {:ok, post} = CommonAPI.post(user, %{status: "yo"})
      {:ok, other_post} = CommonAPI.post(third_user, %{status: "yo"})
      {:ok, _announce} = CommonAPI.repeat(post.id, other_user)
      {:ok, _announce} = CommonAPI.repeat(post.id, third_user)
      {:ok, announce} = CommonAPI.repeat(other_post.id, other_user)

      params = %{
        type: ["Announce"]
      }

      results =
        [user.ap_id | User.following(user)]
        |> ActivityPub.fetch_activities(params)

      assert length(results) == 3

      params = %{
        type: ["Announce"],
        announce_filtering_user: user
      }

      [result] =
        [user.ap_id | User.following(user)]
        |> ActivityPub.fetch_activities(params)

      assert result.id == announce.id
    end
  end

  describe "replies filtering with private messages" do
    setup :private_messages

    test "public timeline", %{users: %{u1: user}} do
      activities_ids =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:local_only, false)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)
        |> ActivityPub.fetch_public_activities()
        |> Enum.map(& &1.id)

      assert activities_ids == []
    end

    test "public timeline with default reply_visibility `following`", %{users: %{u1: user}} do
      activities_ids =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:local_only, false)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_visibility, "following")
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:user, user)
        |> ActivityPub.fetch_public_activities()
        |> Enum.map(& &1.id)

      assert activities_ids == []
    end

    test "public timeline with default reply_visibility `self`", %{users: %{u1: user}} do
      activities_ids =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:local_only, false)
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_visibility, "self")
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:user, user)
        |> ActivityPub.fetch_public_activities()
        |> Enum.map(& &1.id)

      assert activities_ids == []

      activities_ids =
        %{}
        |> Map.put(:reply_visibility, "self")
        |> Map.put(:reply_filtering_user, nil)
        |> ActivityPub.fetch_public_activities()

      assert activities_ids == []
    end

    test "home timeline", %{users: %{u1: user}} do
      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)

      activities_ids =
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], params)
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 12
    end

    test "home timeline with default reply_visibility `following`", %{users: %{u1: user}} do
      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)
        |> Map.put(:reply_visibility, "following")
        |> Map.put(:reply_filtering_user, user)

      activities_ids =
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], params)
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 12
    end

    test "home timeline with default reply_visibility `self`", %{
      users: %{u1: user},
      activities: activities,
      u1: u1,
      u2: u2,
      u3: u3,
      u4: u4
    } do
      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:user, user)
        |> Map.put(:reply_visibility, "self")
        |> Map.put(:reply_filtering_user, user)

      activities_ids =
        ActivityPub.fetch_activities([user.ap_id | User.following(user)], params)
        |> Enum.map(& &1.id)

      assert length(activities_ids) == 10

      visible_ids =
        Map.values(u1) ++ Map.values(u4) ++ [u2[:r1], u3[:r1]] ++ Map.values(activities)

      assert Enum.all?(visible_ids, &(&1 in activities_ids))
    end
  end

  defp public_messages(_) do
    [u1, u2, u3, u4] = insert_list(4, :user)
    {:ok, u1, u2} = User.follow(u1, u2)
    {:ok, u2, u1} = User.follow(u2, u1)
    {:ok, u1, u4} = User.follow(u1, u4)
    {:ok, u4, u1} = User.follow(u4, u1)

    {:ok, u2, u3} = User.follow(u2, u3)
    {:ok, u3, u2} = User.follow(u3, u2)

    {:ok, a1} = CommonAPI.post(u1, %{status: "Status"})

    {:ok, r1_1} =
      CommonAPI.post(u2, %{
        status: "@#{u1.nickname} reply from u2 to u1",
        in_reply_to_status_id: a1.id
      })

    {:ok, r1_2} =
      CommonAPI.post(u3, %{
        status: "@#{u1.nickname} reply from u3 to u1",
        in_reply_to_status_id: a1.id
      })

    {:ok, r1_3} =
      CommonAPI.post(u4, %{
        status: "@#{u1.nickname} reply from u4 to u1",
        in_reply_to_status_id: a1.id
      })

    {:ok, a2} = CommonAPI.post(u2, %{status: "Status"})

    {:ok, r2_1} =
      CommonAPI.post(u1, %{
        status: "@#{u2.nickname} reply from u1 to u2",
        in_reply_to_status_id: a2.id
      })

    {:ok, r2_2} =
      CommonAPI.post(u3, %{
        status: "@#{u2.nickname} reply from u3 to u2",
        in_reply_to_status_id: a2.id
      })

    {:ok, r2_3} =
      CommonAPI.post(u4, %{
        status: "@#{u2.nickname} reply from u4 to u2",
        in_reply_to_status_id: a2.id
      })

    {:ok, a3} = CommonAPI.post(u3, %{status: "Status"})

    {:ok, r3_1} =
      CommonAPI.post(u1, %{
        status: "@#{u3.nickname} reply from u1 to u3",
        in_reply_to_status_id: a3.id
      })

    {:ok, r3_2} =
      CommonAPI.post(u2, %{
        status: "@#{u3.nickname} reply from u2 to u3",
        in_reply_to_status_id: a3.id
      })

    {:ok, r3_3} =
      CommonAPI.post(u4, %{
        status: "@#{u3.nickname} reply from u4 to u3",
        in_reply_to_status_id: a3.id
      })

    {:ok, a4} = CommonAPI.post(u4, %{status: "Status"})

    {:ok, r4_1} =
      CommonAPI.post(u1, %{
        status: "@#{u4.nickname} reply from u1 to u4",
        in_reply_to_status_id: a4.id
      })

    {:ok, r4_2} =
      CommonAPI.post(u2, %{
        status: "@#{u4.nickname} reply from u2 to u4",
        in_reply_to_status_id: a4.id
      })

    {:ok, r4_3} =
      CommonAPI.post(u3, %{
        status: "@#{u4.nickname} reply from u3 to u4",
        in_reply_to_status_id: a4.id
      })

    {:ok,
     users: %{u1: u1, u2: u2, u3: u3, u4: u4},
     activities: %{a1: a1.id, a2: a2.id, a3: a3.id, a4: a4.id},
     u1: %{r1: r1_1.id, r2: r1_2.id, r3: r1_3.id},
     u2: %{r1: r2_1.id, r2: r2_2.id, r3: r2_3.id},
     u3: %{r1: r3_1.id, r2: r3_2.id, r3: r3_3.id},
     u4: %{r1: r4_1.id, r2: r4_2.id, r3: r4_3.id}}
  end

  defp private_messages(_) do
    [u1, u2, u3, u4] = insert_list(4, :user)
    {:ok, u1, u2} = User.follow(u1, u2)
    {:ok, u2, u1} = User.follow(u2, u1)
    {:ok, u1, u3} = User.follow(u1, u3)
    {:ok, u3, u1} = User.follow(u3, u1)
    {:ok, u1, u4} = User.follow(u1, u4)
    {:ok, u4, u1} = User.follow(u4, u1)

    {:ok, u2, u3} = User.follow(u2, u3)
    {:ok, u3, u2} = User.follow(u3, u2)

    {:ok, a1} = CommonAPI.post(u1, %{status: "Status", visibility: "private"})

    {:ok, r1_1} =
      CommonAPI.post(u2, %{
        status: "@#{u1.nickname} reply from u2 to u1",
        in_reply_to_status_id: a1.id,
        visibility: "private"
      })

    {:ok, r1_2} =
      CommonAPI.post(u3, %{
        status: "@#{u1.nickname} reply from u3 to u1",
        in_reply_to_status_id: a1.id,
        visibility: "private"
      })

    {:ok, r1_3} =
      CommonAPI.post(u4, %{
        status: "@#{u1.nickname} reply from u4 to u1",
        in_reply_to_status_id: a1.id,
        visibility: "private"
      })

    {:ok, a2} = CommonAPI.post(u2, %{status: "Status", visibility: "private"})

    {:ok, r2_1} =
      CommonAPI.post(u1, %{
        status: "@#{u2.nickname} reply from u1 to u2",
        in_reply_to_status_id: a2.id,
        visibility: "private"
      })

    {:ok, r2_2} =
      CommonAPI.post(u3, %{
        status: "@#{u2.nickname} reply from u3 to u2",
        in_reply_to_status_id: a2.id,
        visibility: "private"
      })

    {:ok, a3} = CommonAPI.post(u3, %{status: "Status", visibility: "private"})

    {:ok, r3_1} =
      CommonAPI.post(u1, %{
        status: "@#{u3.nickname} reply from u1 to u3",
        in_reply_to_status_id: a3.id,
        visibility: "private"
      })

    {:ok, r3_2} =
      CommonAPI.post(u2, %{
        status: "@#{u3.nickname} reply from u2 to u3",
        in_reply_to_status_id: a3.id,
        visibility: "private"
      })

    {:ok, a4} = CommonAPI.post(u4, %{status: "Status", visibility: "private"})

    {:ok, r4_1} =
      CommonAPI.post(u1, %{
        status: "@#{u4.nickname} reply from u1 to u4",
        in_reply_to_status_id: a4.id,
        visibility: "private"
      })

    {:ok,
     users: %{u1: u1, u2: u2, u3: u3, u4: u4},
     activities: %{a1: a1.id, a2: a2.id, a3: a3.id, a4: a4.id},
     u1: %{r1: r1_1.id, r2: r1_2.id, r3: r1_3.id},
     u2: %{r1: r2_1.id, r2: r2_2.id},
     u3: %{r1: r3_1.id, r2: r3_2.id},
     u4: %{r1: r4_1.id}}
  end

  describe "maybe_update_follow_information/1" do
    setup do
      clear_config([:instance, :external_user_synchronization], true)

      user = %{
        local: false,
        ap_id: "https://gensokyo.2hu/users/raymoo",
        following_address: "https://gensokyo.2hu/users/following",
        follower_address: "https://gensokyo.2hu/users/followers",
        type: "Person"
      }

      %{user: user}
    end

    test "logs an error when it can't fetch the info", %{user: user} do
      assert capture_log(fn ->
               ActivityPub.maybe_update_follow_information(user)
             end) =~ "Follower/Following counter update for #{user.ap_id} failed"
    end

    test "just returns the input if the user type is Application", %{
      user: user
    } do
      user =
        user
        |> Map.put(:type, "Application")

      refute capture_log(fn ->
               assert ^user = ActivityPub.maybe_update_follow_information(user)
             end) =~ "Follower/Following counter update for #{user.ap_id} failed"
    end

    test "it just returns the input if the user has no following/follower addresses", %{
      user: user
    } do
      user =
        user
        |> Map.put(:following_address, nil)
        |> Map.put(:follower_address, nil)

      refute capture_log(fn ->
               assert ^user = ActivityPub.maybe_update_follow_information(user)
             end) =~ "Follower/Following counter update for #{user.ap_id} failed"
    end
  end

  describe "global activity expiration" do
    test "creates an activity expiration for local Create activities" do
      clear_config([:mrf, :policies], Pleroma.Web.ActivityPub.MRF.ActivityExpirationPolicy)

      {:ok, activity} = ActivityBuilder.insert(%{"type" => "Create", "context" => "3hu"})
      {:ok, follow} = ActivityBuilder.insert(%{"type" => "Follow", "context" => "3hu"})

      assert_enqueued(
        worker: Pleroma.Workers.PurgeExpiredActivity,
        args: %{activity_id: activity.id},
        scheduled_at:
          activity.inserted_at
          |> DateTime.from_naive!("Etc/UTC")
          |> Timex.shift(days: 365)
      )

      refute_enqueued(
        worker: Pleroma.Workers.PurgeExpiredActivity,
        args: %{activity_id: follow.id}
      )
    end
  end

  describe "handling of clashing nicknames" do
    test "renames an existing user with a clashing nickname and a different ap id" do
      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/harinezumigari"
        )

      %{
        nickname: orig_user.nickname,
        ap_id: orig_user.ap_id <> "part_2"
      }
      |> ActivityPub.maybe_handle_clashing_nickname()

      user = User.get_by_id(orig_user.id)

      assert user.nickname == "#{orig_user.id}.admin@mastodon.example.org"
    end

    test "does nothing with a clashing nickname and the same ap id" do
      orig_user =
        insert(
          :user,
          local: false,
          nickname: "admin@mastodon.example.org",
          ap_id: "http://mastodon.example.org/users/harinezumigari"
        )

      %{
        nickname: orig_user.nickname,
        ap_id: orig_user.ap_id
      }
      |> ActivityPub.maybe_handle_clashing_nickname()

      user = User.get_by_id(orig_user.id)

      assert user.nickname == orig_user.nickname
    end
  end

  describe "reply filtering" do
    test "`following` still contains announcements by friends" do
      user = insert(:user)
      followed = insert(:user)
      not_followed = insert(:user)

      User.follow(user, followed)

      {:ok, followed_post} = CommonAPI.post(followed, %{status: "Hello"})

      {:ok, not_followed_to_followed} =
        CommonAPI.post(not_followed, %{
          status: "Also hello",
          in_reply_to_status_id: followed_post.id
        })

      {:ok, retoot} = CommonAPI.repeat(not_followed_to_followed.id, followed)

      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:reply_visibility, "following")
        |> Map.put(:announce_filtering_user, user)
        |> Map.put(:user, user)

      activities =
        [user.ap_id | User.following(user)]
        |> ActivityPub.fetch_activities(params)

      followed_post_id = followed_post.id
      retoot_id = retoot.id

      assert [%{id: ^followed_post_id}, %{id: ^retoot_id}] = activities

      assert length(activities) == 2
    end

    # This test is skipped because, while this is the desired behavior,
    # there seems to be no good way to achieve it with the method that
    # we currently use for detecting to who a reply is directed.
    # This is a TODO and should be fixed by a later rewrite of the code
    # in question.
    @tag skip: true
    test "`following` still contains self-replies by friends" do
      user = insert(:user)
      followed = insert(:user)
      not_followed = insert(:user)

      User.follow(user, followed)

      {:ok, followed_post} = CommonAPI.post(followed, %{status: "Hello"})
      {:ok, not_followed_post} = CommonAPI.post(not_followed, %{status: "Also hello"})

      {:ok, _followed_to_not_followed} =
        CommonAPI.post(followed, %{status: "sup", in_reply_to_status_id: not_followed_post.id})

      {:ok, _followed_self_reply} =
        CommonAPI.post(followed, %{status: "Also cofe", in_reply_to_status_id: followed_post.id})

      params =
        %{}
        |> Map.put(:type, ["Create", "Announce"])
        |> Map.put(:blocking_user, user)
        |> Map.put(:muting_user, user)
        |> Map.put(:reply_filtering_user, user)
        |> Map.put(:reply_visibility, "following")
        |> Map.put(:announce_filtering_user, user)
        |> Map.put(:user, user)

      activities =
        [user.ap_id | User.following(user)]
        |> ActivityPub.fetch_activities(params)

      assert length(activities) == 2
    end
  end

  test "allow fetching of accounts with an empty string name field" do
    Tesla.Mock.mock(fn
      %{method: :get, url: "https://princess.cat/users/mewmew"} ->
        file = File.read!("test/fixtures/mewmew_no_name.json")
        %Tesla.Env{status: 200, body: file, headers: HttpRequestMock.activitypub_object_headers()}
    end)

    {:ok, user} = ActivityPub.make_user_from_ap_id("https://princess.cat/users/mewmew")
    assert user.name == " "
  end
end
