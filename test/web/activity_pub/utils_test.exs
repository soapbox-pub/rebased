defmodule Pleroma.Web.ActivityPub.UtilsTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

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
end
