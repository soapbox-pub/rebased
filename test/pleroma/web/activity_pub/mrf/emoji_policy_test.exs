# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.EmojiPolicyTest do
  use Pleroma.DataCase

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
      }
    }
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
  end
end
