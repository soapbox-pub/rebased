# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Activity.Ir.TopicsTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Activity.Ir.Topics
  alias Pleroma.Object

  require Pleroma.Constants

  import Mock

  describe "chat message" do
    test "Create produces no topics" do
      activity = %Activity{
        object: %Object{data: %{"type" => "ChatMessage"}},
        data: %{"type" => "Create"}
      }

      assert [] == Topics.get_activity_topics(activity)
    end

    test "Delete produces user and user:pleroma_chat" do
      activity = %Activity{
        object: %Object{data: %{"type" => "ChatMessage"}},
        data: %{"type" => "Delete"}
      }

      topics = Topics.get_activity_topics(activity)
      assert [_, _] = topics
      assert "user" in topics
      assert "user:pleroma_chat" in topics
    end
  end

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
        data: %{"to" => [Pleroma.Constants.as_public()], "type" => "Create"}
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
        object: %Object{data: %{"attachment" => []}},
        data: %{"type" => "Create", "to" => [Pleroma.Constants.as_public()]}
      }

      {:ok, activity: activity}
    end

    test "with no attachments doesn't produce public:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:media")
      refute Enum.member?(topics, "public:local:media")
    end

    test "converts tags to hash tags", %{activity: activity} do
      with_mock(Object, [:passthrough], hashtags: fn _ -> ["foo", "bar"] end) do
        topics = Topics.get_activity_topics(activity)

        assert Enum.member?(topics, "hashtag:foo")
        assert Enum.member?(topics, "hashtag:bar")
      end
    end

    test "only converts strings to hash tags", %{
      activity: %{object: %{data: data} = object} = activity
    } do
      tagged_data = Map.put(data, "tag", [2])
      activity = %{activity | object: %{object | data: tagged_data}}

      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "hashtag:2")
    end

    test "non-local action produces public:remote topic", %{activity: activity} do
      activity = %{activity | local: false, actor: "https://lain.com/users/lain"}
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:remote:lain.com")
    end

    test "local action doesn't produce public:remote topic", %{activity: activity} do
      activity = %{activity | local: true, actor: "https://lain.com/users/lain"}
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:remote:lain.com")
    end
  end

  describe "public visibility Announces" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"attachment" => []}},
        data: %{"type" => "Announce", "to" => [Pleroma.Constants.as_public()]}
      }

      {:ok, activity: activity}
    end

    test "does not generate public topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      refute "public" in topics
      refute "public:remote" in topics
      refute "public:local" in topics
    end
  end

  describe "local-public visibility create events" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"attachment" => []}},
        data: %{"type" => "Create", "to" => [Pleroma.Web.ActivityPub.Utils.as_local_public()]}
      }

      {:ok, activity: activity}
    end

    test "doesn't produce public topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public")
    end

    test "produces public:local topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:local")
    end

    test "with no attachments doesn't produce public:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:media")
      refute Enum.member?(topics, "public:local:media")
    end
  end

  describe "public visibility create events with attachments" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"attachment" => ["foo"]}},
        data: %{"type" => "Create", "to" => [Pleroma.Constants.as_public()]}
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

    test "non-local action produces public:remote:media topic", %{activity: activity} do
      activity = %{activity | local: false, actor: "https://lain.com/users/lain"}
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:remote:media:lain.com")
    end
  end

  describe "local-public visibility create events with attachments" do
    setup do
      activity = %Activity{
        object: %Object{data: %{"attachment" => ["foo"]}},
        data: %{"type" => "Create", "to" => [Pleroma.Web.ActivityPub.Utils.as_local_public()]}
      }

      {:ok, activity: activity}
    end

    test "do not produce public:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      refute Enum.member?(topics, "public:media")
    end

    test "produces public:local:media topics", %{activity: activity} do
      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "public:local:media")
    end
  end

  describe "non-public visibility" do
    test "produces direct topic" do
      activity = %Activity{
        object: %Object{data: %{"type" => "Note"}},
        data: %{"to" => [], "type" => "Create"}
      }

      topics = Topics.get_activity_topics(activity)

      assert Enum.member?(topics, "direct")
      refute Enum.member?(topics, "public")
      refute Enum.member?(topics, "public:local")
      refute Enum.member?(topics, "public:media")
      refute Enum.member?(topics, "public:local:media")
    end
  end
end
