defmodule Pleroma.Web.ActivityPub.UtilsTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "fetch the latest Follow" do
    test "fetches the latest Follow activity" do
      %Activity{data: %{"type" => "Follow"}} = activity = insert(:follow_activity)
      follower = User.get_cached_by_ap_id(activity.data["actor"])
      followed = User.get_cached_by_ap_id(activity.data["object"])

      assert activity == Utils.fetch_latest_follow(follower, followed)
    end
  end

  describe "fetch the latest Block" do
    test "fetches the latest Block activity" do
      blocker = insert(:user)
      blocked = insert(:user)
      {:ok, activity} = ActivityPub.block(blocker, blocked)

      assert activity == Utils.fetch_latest_block(blocker, blocked)
    end
  end

  describe "determine_explicit_mentions()" do
    test "works with an object that has mentions" do
      object = %{
        "tag" => [
          %{
            "type" => "Mention",
            "href" => "https://example.com/~alyssa",
            "name" => "Alyssa P. Hacker"
          }
        ]
      }

      assert Utils.determine_explicit_mentions(object) == ["https://example.com/~alyssa"]
    end

    test "works with an object that does not have mentions" do
      object = %{
        "tag" => [
          %{"type" => "Hashtag", "href" => "https://example.com/tag/2hu", "name" => "2hu"}
        ]
      }

      assert Utils.determine_explicit_mentions(object) == []
    end

    test "works with an object that has mentions and other tags" do
      object = %{
        "tag" => [
          %{
            "type" => "Mention",
            "href" => "https://example.com/~alyssa",
            "name" => "Alyssa P. Hacker"
          },
          %{"type" => "Hashtag", "href" => "https://example.com/tag/2hu", "name" => "2hu"}
        ]
      }

      assert Utils.determine_explicit_mentions(object) == ["https://example.com/~alyssa"]
    end

    test "works with an object that has no tags" do
      object = %{}

      assert Utils.determine_explicit_mentions(object) == []
    end

    test "works with an object that has only IR tags" do
      object = %{"tag" => ["2hu"]}

      assert Utils.determine_explicit_mentions(object) == []
    end
  end

  describe "make_like_data" do
    setup do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)
      [user: user, other_user: other_user, third_user: third_user]
    end

    test "addresses actor's follower address if the activity is public", %{
      user: user,
      other_user: other_user,
      third_user: third_user
    } do
      expected_to = Enum.sort([user.ap_id, other_user.follower_address])
      expected_cc = Enum.sort(["https://www.w3.org/ns/activitystreams#Public", third_user.ap_id])

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" =>
            "hey @#{other_user.nickname}, @#{third_user.nickname} how about beering together this weekend?"
        })

      %{"to" => to, "cc" => cc} = Utils.make_like_data(other_user, activity, nil)
      assert Enum.sort(to) == expected_to
      assert Enum.sort(cc) == expected_cc
    end

    test "does not adress actor's follower address if the activity is not public", %{
      user: user,
      other_user: other_user,
      third_user: third_user
    } do
      expected_to = Enum.sort([user.ap_id])
      expected_cc = [third_user.ap_id]

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "@#{other_user.nickname} @#{third_user.nickname} bought a new swimsuit!",
          "visibility" => "private"
        })

      %{"to" => to, "cc" => cc} = Utils.make_like_data(other_user, activity, nil)
      assert Enum.sort(to) == expected_to
      assert Enum.sort(cc) == expected_cc
    end
  end

  describe "fetch_ordered_collection" do
    import Tesla.Mock

    test "fetches the first OrderedCollectionPage when an OrderedCollection is encountered" do
      mock(fn
        %{method: :get, url: "http://mastodon.com/outbox"} ->
          json(%{"type" => "OrderedCollection", "first" => "http://mastodon.com/outbox?page=true"})

        %{method: :get, url: "http://mastodon.com/outbox?page=true"} ->
          json(%{"type" => "OrderedCollectionPage", "orderedItems" => ["ok"]})
      end)

      assert Utils.fetch_ordered_collection("http://mastodon.com/outbox", 1) == ["ok"]
    end

    test "fetches several pages in the right order one after another, but only the specified amount" do
      mock(fn
        %{method: :get, url: "http://example.com/outbox"} ->
          json(%{
            "type" => "OrderedCollectionPage",
            "orderedItems" => [0],
            "next" => "http://example.com/outbox?page=1"
          })

        %{method: :get, url: "http://example.com/outbox?page=1"} ->
          json(%{
            "type" => "OrderedCollectionPage",
            "orderedItems" => [1],
            "next" => "http://example.com/outbox?page=2"
          })

        %{method: :get, url: "http://example.com/outbox?page=2"} ->
          json(%{"type" => "OrderedCollectionPage", "orderedItems" => [2]})
      end)

      assert Utils.fetch_ordered_collection("http://example.com/outbox", 0) == [0]
      assert Utils.fetch_ordered_collection("http://example.com/outbox", 1) == [0, 1]
    end

    test "returns an error if the url doesn't have an OrderedCollection/Page" do
      mock(fn
        %{method: :get, url: "http://example.com/not-an-outbox"} ->
          json(%{"type" => "NotAnOutbox"})
      end)

      assert {:error, _} = Utils.fetch_ordered_collection("http://example.com/not-an-outbox", 1)
    end

    test "returns the what was collected if there are less pages than specified" do
      mock(fn
        %{method: :get, url: "http://example.com/outbox"} ->
          json(%{
            "type" => "OrderedCollectionPage",
            "orderedItems" => [0],
            "next" => "http://example.com/outbox?page=1"
          })

        %{method: :get, url: "http://example.com/outbox?page=1"} ->
          json(%{"type" => "OrderedCollectionPage", "orderedItems" => [1]})
      end)

      assert Utils.fetch_ordered_collection("http://example.com/outbox", 5) == [0, 1]
    end
  end

  test "make_json_ld_header/0" do
    assert Utils.make_json_ld_header() == %{
             "@context" => [
               "https://www.w3.org/ns/activitystreams",
               "http://localhost:4001/schemas/litepub-0.1.jsonld",
               %{
                 "@language" => "und"
               }
             ]
           }
  end

  describe "get_existing_votes" do
    test "fetches existing votes" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "How do I pronounce LaTeX?",
          "poll" => %{
            "options" => ["laytekh", "lahtekh", "latex"],
            "expires_in" => 20,
            "multiple" => true
          }
        })

      object = Object.normalize(activity)
      {:ok, votes, object} = CommonAPI.vote(other_user, object, [0, 1])
      assert Enum.sort(Utils.get_existing_votes(other_user.ap_id, object)) == Enum.sort(votes)
    end

    test "fetches only Create activities" do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, activity} =
        CommonAPI.post(user, %{
          "status" => "Are we living in a society?",
          "poll" => %{
            "options" => ["yes", "no"],
            "expires_in" => 20
          }
        })

      object = Object.normalize(activity)
      {:ok, [vote], object} = CommonAPI.vote(other_user, object, [0])
      vote_object = Object.normalize(vote)
      {:ok, _activity, _object} = ActivityPub.like(user, vote_object)
      [fetched_vote] = Utils.get_existing_votes(other_user.ap_id, object)
      assert fetched_vote.id == vote.id
    end
  end

  describe "update_follow_state_for_all/2" do
    test "updates the state of all Follow activities with the same actor and object" do
      user = insert(:user, info: %{locked: true})
      follower = insert(:user)

      {:ok, follow_activity} = ActivityPub.follow(follower, user)
      {:ok, follow_activity_two} = ActivityPub.follow(follower, user)

      data =
        follow_activity_two.data
        |> Map.put("state", "accept")

      cng = Ecto.Changeset.change(follow_activity_two, data: data)

      {:ok, follow_activity_two} = Repo.update(cng)

      {:ok, follow_activity_two} =
        Utils.update_follow_state_for_all(follow_activity_two, "accept")

      assert Repo.get(Activity, follow_activity.id).data["state"] == "accept"
      assert Repo.get(Activity, follow_activity_two.id).data["state"] == "accept"
    end
  end

  describe "update_follow_state/2" do
    test "updates the state of the given follow activity" do
      user = insert(:user, info: %{locked: true})
      follower = insert(:user)

      {:ok, follow_activity} = ActivityPub.follow(follower, user)
      {:ok, follow_activity_two} = ActivityPub.follow(follower, user)

      data =
        follow_activity_two.data
        |> Map.put("state", "accept")

      cng = Ecto.Changeset.change(follow_activity_two, data: data)

      {:ok, follow_activity_two} = Repo.update(cng)

      {:ok, follow_activity_two} = Utils.update_follow_state(follow_activity_two, "reject")

      assert Repo.get(Activity, follow_activity.id).data["state"] == "pending"
      assert Repo.get(Activity, follow_activity_two.id).data["state"] == "reject"
    end
  end
end
