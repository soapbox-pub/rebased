defmodule Pleroma.Web.ActivityPub.UtilsTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.Utils

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
end
