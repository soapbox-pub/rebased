# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.StealEmojiPolicyTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.Emoji
  alias Pleroma.Web.ActivityPub.MRF.StealEmojiPolicy

  setup do
    emoji_path = [:instance, :static_dir] |> Config.get() |> Path.join("emoji/stolen")

    Emoji.reload()

    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"firedfox", "https://example.org/emoji/firedfox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    on_exit(fn ->
      File.rm_rf!(emoji_path)
    end)

    [message: message, path: emoji_path]
  end

  test "does nothing by default", %{message: message} do
    refute "firedfox" in installed()

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "Steals emoji on unknown shortcode from allowed remote host", %{
    message: message,
    path: path
  } do
    refute "firedfox" in installed()
    refute File.exists?(path)

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox.png"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "firedfox" in installed()
    assert File.exists?(path)

    assert path
           |> Path.join("firedfox.png")
           |> File.exists?()
  end

  test "reject regex shortcode", %{message: message} do
    refute "firedfox" in installed()

    clear_config(:mrf_steal_emoji,
      hosts: ["example.org"],
      size_limit: 284_468,
      rejected_shortcodes: [~r/firedfox/]
    )

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "reject string shortcode", %{message: message} do
    refute "firedfox" in installed()

    clear_config(:mrf_steal_emoji,
      hosts: ["example.org"],
      size_limit: 284_468,
      rejected_shortcodes: ["firedfox"]
    )

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "reject if size is above the limit", %{message: message} do
    refute "firedfox" in installed()

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox.png"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 50_000)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "firedfox" in installed()
  end

  test "reject if host returns error", %{message: message} do
    refute "firedfox" in installed()

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox.png"} ->
      {:ok, %Tesla.Env{status: 404, body: "Not found"}}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    ExUnit.CaptureLog.capture_log(fn ->
      assert {:ok, _message} = StealEmojiPolicy.filter(message)
    end) =~ "MRF.StealEmojiPolicy: Failed to fetch https://example.org/emoji/firedfox.png"

    refute "firedfox" in installed()
  end

  defp installed, do: Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
end
