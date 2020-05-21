# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.StealEmojiPolicyTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy

  setup_all do
    Tesla.Mock.mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

  setup do
    clear_config(:mrf_steal_emoji)

    emoji_path = Path.join(Config.get([:instance, :static_dir]), "emoji/stolen")
    File.rm_rf!(emoji_path)
    File.mkdir!(emoji_path)

    Pleroma.Emoji.reload()
  end

  test "does nothing by default" do
    installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
    refute "firedfox" in installed_emoji

    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"firedfox", "https://example.org/emoji/firedfox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    assert {:ok, message} == StealEmojiPolicy.filter(message)

    installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
    refute "firedfox" in installed_emoji
  end

  test "Steals emoji on unknown shortcode from allowed remote host" do
    installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
    refute "firedfox" in installed_emoji

    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"firedfox", "https://example.org/emoji/firedfox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    Config.put([:mrf_steal_emoji, :hosts], ["example.org"])
    Config.put([:mrf_steal_emoji, :size_limit], 284_468)

    assert {:ok, message} == StealEmojiPolicy.filter(message)

    installed_emoji = Pleroma.Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
    assert "firedfox" in installed_emoji
  end
end
