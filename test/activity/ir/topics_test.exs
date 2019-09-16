defmodule Pleroma.Activity.Ir.TopicsTest do
  use Pleroma.DataCase

  alias Pleroma.Activity
  alias Pleroma.Activity.Ir.Topics
  alias Pleroma.Object

  require Pleroma.Constants

  describe "poll answer" do
    test "produce no topics" do
      activity = %Activity{object: %Object{data: %{"type" => "Answer"}}}

      assert [] == Topics.get_activity_topics(activity)
    end
  end

  describe "non poll answer" do
    test "always add user and list topics" do
      activity = %Activity{object: %Object{data: %{"type" => "FooBar"}}}
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "user")
      assert Enum.member?(topics, "list")
    end
  end

  describe "public visibility" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"type" => "Note"}},
        data: %{"to" => [Pleroma.Constants.as_public()]}
      }

      {:ok, activity: activity}
    end

    test "produces public topic", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public")
    end

    test "local action produces public:local topic", %{activity: activity} do
      activity = %{activity | local: true}
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:local")
    end

    test "non-local action does not produce public:local topic", %{activity: activity} do
      activity = %{activity | local: false}
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:local")
    end
  end

  describe "public visibility create events" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"type" => "Create", "attachment" => []}},
        data: %{"to" => [Pleroma.Constants.as_public()]}
      }

      {:ok, activity: activity}
    end

    test "with no attachments doesn't produce public:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:media")
      refute Enum.member?(topics, "public:local:media")
    end

    test "converts tags to hash tags", %{activity: %{object: %{data: data} = object} = activity} do
      tagged_data = Map.put(data, "tag", ["foo", "bar"])
      activity = %{activity | object: %{object | data: tagged_data}}

      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "hashtag:foo")
      assert Enum.member?(topics, "hashtag:bar")
    end

    test "only converts strinngs to hash tags", %{
      activity: %{object: %{data: data} = object} = activity
    } do
      tagged_data = Map.put(data, "tag", [2])
      activity = %{activity | object: %{object | data: tagged_data}}

      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "hashtag:2")
    end
  end

  describe "public visibility create events with attachments" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"type" => "Create", "attachment" => ["foo"]}},
        data: %{"to" => [Pleroma.Constants.as_public()]}
      }

      {:ok, activity: activity}
    end

    test "produce public:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:media")
    end

    test "local produces public:local:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:local:media")
    end

    test "non-local doesn't produce public:local:media topics", %{activity: activity} do
      activity = %{activity | local: false}

      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:local:media")
    end
  end

  describe "non-public visibility" do
    test "produces direct topic" do
      activity = %Activity{object: %Object{data: %{"type" => "Note"}}, data: %{"to" => []}}
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "direct")
      refute Enum.member?(topics, "public")
      refute Enum.member?(topics, "public:local")
      refute Enum.member?(topics, "public:media")
      refute Enum.member?(topics, "public:local:media")
    end
  end
end
