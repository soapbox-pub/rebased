defmodule Pleroma.Web.ActivityPub.UtilsTest do
  use Pleroma.DataCase
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.ActivityPub.Utils

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
end
