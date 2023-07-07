# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EmojiPolicyTest do
  use Pleroma.DataCase

  require Pleroma.Constants

  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.ActivityPub.MRF.EmojiPolicy

  setup do: clear_config(:mrf_emoji)

  setup do
    clear_config([:mrf_emoji], %{
      remove_url: [],
      remove_shortcode: [],
      federated_timeline_removal_url: [],
      federated_timeline_removal_shortcode: []
    })
  end

  @emoji_tags [
    %{
      "icon" => %{
        "type" => "Image",
        "url" => "https://example.org/emoji/biribiri/mikoto_smile2.png"
      },
      "id" => "https://example.org/emoji/biribiri/mikoto_smile2.png",
      "name" => ":mikoto_smile2:",
      "type" => "Emoji",
      "updated" => "1970-01-01T00:00:00Z"
    },
    %{
      "icon" => %{
        "type" => "Image",
        "url" => "https://example.org/emoji/biribiri/mikoto_smile3.png"
      },
      "id" => "https://example.org/emoji/biribiri/mikoto_smile3.png",
      "name" => ":mikoto_smile3:",
      "type" => "Emoji",
      "updated" => "1970-01-01T00:00:00Z"
    },
    %{
      "icon" => %{
        "type" => "Image",
        "url" => "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      },
      "id" => "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png",
      "name" => ":nekomimi_girl_emoji_007:",
      "type" => "Emoji",
      "updated" => "1970-01-01T00:00:00Z"
    },
    %{
      "icon" => %{
        "type" => "Image",
        "url" => "https://example.org/test.png"
      },
      "id" => "https://example.org/test.png",
      "name" => ":test:",
      "type" => "Emoji",
      "updated" => "1970-01-01T00:00:00Z"
    }
  ]

  @misc_tags [%{"type" => "Placeholder"}]

  @user_data %{
    "type" => "Person",
    "id" => "https://example.org/placeholder",
    "name" => "lol",
    "tag" => @emoji_tags ++ @misc_tags
  }

  @status_data %{
    "type" => "Create",
    "object" => %{
      "type" => "Note",
      "id" => "https://example.org/placeholder",
      "content" => "lol",
      "tag" => @emoji_tags ++ @misc_tags,
      "emoji" => %{
        "mikoto_smile2" => "https://example.org/emoji/biribiri/mikoto_smile2.png",
        "mikoto_smile3" => "https://example.org/emoji/biribiri/mikoto_smile3.png",
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png",
        "test" => "https://example.org/test.png"
      },
      "to" => ["https://example.org/self", Pleroma.Constants.as_public()],
      "cc" => ["https://example.org/someone"]
    },
    "to" => ["https://example.org/self", Pleroma.Constants.as_public()],
    "cc" => ["https://example.org/someone"]
  }

  @status_data_with_history %{
    "type" => "Create",
    "object" =>
      @status_data["object"]
      |> Map.merge(%{
        "formerRepresentations" => %{
          "type" => "OrderedCollection",
          "orderedItems" => [@status_data["object"] |> Map.put("content", "older")],
          "totalItems" => 1
        }
      }),
    "to" => ["https://example.org/self", Pleroma.Constants.as_public()],
    "cc" => ["https://example.org/someone"]
  }

  @emoji_react_data %{
    "type" => "EmojiReact",
    "tag" => [@emoji_tags |> Enum.at(3)],
    "object" => "https://example.org/someobject",
    "to" => ["https://example.org/self"],
    "cc" => ["https://example.org/someone"]
  }

  @emoji_react_data_matching_regex %{
    "type" => "EmojiReact",
    "tag" => [@emoji_tags |> Enum.at(1)],
    "object" => "https://example.org/someobject",
    "to" => ["https://example.org/self"],
    "cc" => ["https://example.org/someone"]
  }

  @emoji_react_data_matching_nothing %{
    "type" => "EmojiReact",
    "tag" => [@emoji_tags |> Enum.at(2)],
    "object" => "https://example.org/someobject",
    "to" => ["https://example.org/self"],
    "cc" => ["https://example.org/someone"]
  }

  @emoji_react_data_unicode %{
    "type" => "EmojiReact",
    "content" => "😍",
    "object" => "https://example.org/someobject",
    "to" => ["https://example.org/self"],
    "cc" => ["https://example.org/someone"]
  }

  describe "remove_url" do
    setup do
      clear_config([:mrf_emoji, :remove_url], [
        "https://example.org/test.png",
        ~r{/biribiri/mikoto_smile[23]\.png},
        "nekomimi_girl_emoji"
      ])

      :ok
    end

    test "processes user" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @user_data)

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      assert %{"tag" => ^expected_tags} = filtered
    end

    test "processes status" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @status_data)

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      expected_emoji = %{
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      }

      assert %{"object" => %{"tag" => ^expected_tags, "emoji" => ^expected_emoji}} = filtered
    end

    test "processes status with history" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @status_data_with_history)

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      expected_emoji = %{
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      }

      assert %{
               "object" => %{
                 "tag" => ^expected_tags,
                 "emoji" => ^expected_emoji,
                 "formerRepresentations" => %{"orderedItems" => [item]}
               }
             } = filtered

      assert %{"tag" => ^expected_tags, "emoji" => ^expected_emoji} = item
    end

    test "processes updates" do
      {:ok, filtered} =
        MRF.filter_one(EmojiPolicy, @status_data_with_history |> Map.put("type", "Update"))

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      expected_emoji = %{
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      }

      assert %{
               "object" => %{
                 "tag" => ^expected_tags,
                 "emoji" => ^expected_emoji,
                 "formerRepresentations" => %{"orderedItems" => [item]}
               }
             } = filtered

      assert %{"tag" => ^expected_tags, "emoji" => ^expected_emoji} = item
    end

    test "processes EmojiReact" do
      assert {:reject, "[EmojiPolicy] Rejected for having disallowed emoji"} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data)

      assert {:reject, "[EmojiPolicy] Rejected for having disallowed emoji"} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data_matching_regex)

      assert {:ok, @emoji_react_data_matching_nothing} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data_matching_nothing)

      assert {:ok, @emoji_react_data_unicode} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data_unicode)
    end
  end

  describe "remove_shortcode" do
    setup do
      clear_config([:mrf_emoji, :remove_shortcode], [
        "test",
        ~r{mikoto_s},
        "nekomimi_girl_emoji"
      ])

      :ok
    end

    test "processes user" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @user_data)

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      assert %{"tag" => ^expected_tags} = filtered
    end

    test "processes status" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @status_data)

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      expected_emoji = %{
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      }

      assert %{"object" => %{"tag" => ^expected_tags, "emoji" => ^expected_emoji}} = filtered
    end

    test "processes status with history" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @status_data_with_history)

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      expected_emoji = %{
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      }

      assert %{
               "object" => %{
                 "tag" => ^expected_tags,
                 "emoji" => ^expected_emoji,
                 "formerRepresentations" => %{"orderedItems" => [item]}
               }
             } = filtered

      assert %{"tag" => ^expected_tags, "emoji" => ^expected_emoji} = item
    end

    test "processes updates" do
      {:ok, filtered} =
        MRF.filter_one(EmojiPolicy, @status_data_with_history |> Map.put("type", "Update"))

      expected_tags = [@emoji_tags |> Enum.at(2)] ++ @misc_tags

      expected_emoji = %{
        "nekomimi_girl_emoji_007" =>
          "https://example.org/emoji/nekomimi_girl_emoji/nekomimi_girl_emoji_007.png"
      }

      assert %{
               "object" => %{
                 "tag" => ^expected_tags,
                 "emoji" => ^expected_emoji,
                 "formerRepresentations" => %{"orderedItems" => [item]}
               }
             } = filtered

      assert %{"tag" => ^expected_tags, "emoji" => ^expected_emoji} = item
    end

    test "processes EmojiReact" do
      assert {:reject, "[EmojiPolicy] Rejected for having disallowed emoji"} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data)

      assert {:reject, "[EmojiPolicy] Rejected for having disallowed emoji"} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data_matching_regex)

      assert {:ok, @emoji_react_data_matching_nothing} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data_matching_nothing)

      assert {:ok, @emoji_react_data_unicode} ==
               MRF.filter_one(EmojiPolicy, @emoji_react_data_unicode)
    end
  end

  describe "federated_timeline_removal_url" do
    setup do
      clear_config([:mrf_emoji, :federated_timeline_removal_url], [
        "https://example.org/test.png",
        ~r{/biribiri/mikoto_smile[23]\.png},
        "nekomimi_girl_emoji"
      ])

      :ok
    end

    test "processes status" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @status_data)

      expected_tags = @status_data["object"]["tag"]
      expected_emoji = @status_data["object"]["emoji"]

      expected_to = ["https://example.org/self"]
      expected_cc = [Pleroma.Constants.as_public(), "https://example.org/someone"]

      assert %{
               "to" => ^expected_to,
               "cc" => ^expected_cc,
               "object" => %{"tag" => ^expected_tags, "emoji" => ^expected_emoji}
             } = filtered
    end

    test "ignore updates" do
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, @status_data |> Map.put("type", "Update"))

      expected_tags = @status_data["object"]["tag"]
      expected_emoji = @status_data["object"]["emoji"]

      expected_to = ["https://example.org/self", Pleroma.Constants.as_public()]
      expected_cc = ["https://example.org/someone"]

      assert %{
               "to" => ^expected_to,
               "cc" => ^expected_cc,
               "object" => %{"tag" => ^expected_tags, "emoji" => ^expected_emoji}
             } = filtered
    end

    test "processes status with history" do
      status =
        @status_data_with_history
        |> put_in(["object", "tag"], @misc_tags)
        |> put_in(["object", "emoji"], %{})

      {:ok, filtered} = MRF.filter_one(EmojiPolicy, status)

      expected_tags = @status_data["object"]["tag"]
      expected_emoji = @status_data["object"]["emoji"]

      expected_to = ["https://example.org/self"]
      expected_cc = [Pleroma.Constants.as_public(), "https://example.org/someone"]

      assert %{
               "to" => ^expected_to,
               "cc" => ^expected_cc,
               "object" => %{
                 "formerRepresentations" => %{
                   "orderedItems" => [%{"tag" => ^expected_tags, "emoji" => ^expected_emoji}]
                 }
               }
             } = filtered
    end
  end

  describe "edge cases" do
    setup do
      clear_config([:mrf_emoji, :remove_url], [
        "https://example.org/test.png",
        ~r{/biribiri/mikoto_smile[23]\.png},
        "nekomimi_girl_emoji"
      ])

      :ok
    end

    test "non-statuses" do
      answer = @status_data |> put_in(["object", "type"], "Answer")
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, answer)

      assert filtered == answer
    end

    test "without tag" do
      status = @status_data |> Map.put("object", Map.drop(@status_data["object"], ["tag"]))
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, status)

      refute Map.has_key?(filtered["object"], "tag")
    end

    test "without emoji" do
      status = @status_data |> Map.put("object", Map.drop(@status_data["object"], ["emoji"]))
      {:ok, filtered} = MRF.filter_one(EmojiPolicy, status)

      refute Map.has_key?(filtered["object"], "emoji")
    end
  end
end
