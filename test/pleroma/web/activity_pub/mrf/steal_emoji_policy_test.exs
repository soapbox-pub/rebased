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

  test "works with unknown extension", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"firedfox", "https://example.org/emoji/firedfox"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    fullpath = Path.join(path, "firedfox.png")

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "firedfox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "firedfox" in installed()
    assert File.exists?(path)
    assert File.exists?(fullpath)
  end

  test "rejects invalid shortcodes with slashes", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fired/fox", "https://example.org/emoji/firedfox"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    fullpath = Path.join(path, "fired/fox.png")

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "firedfox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "fired/fox" in installed()
    refute File.exists?(fullpath)
  end

  test "rejects invalid shortcodes with dots", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fired.fox", "https://example.org/emoji/firedfox"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    fullpath = Path.join(path, "fired.fox.png")

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "fired.fox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "fired.fox" in installed()
    refute File.exists?(fullpath)
  end

  test "rejects invalid shortcodes with special characters", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fired:fox", "https://example.org/emoji/firedfox"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    fullpath = Path.join(path, "fired:fox.png")

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/firedfox"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "fired:fox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    refute "fired:fox" in installed()
    refute File.exists?(fullpath)
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

  test "accepts valid alphanum shortcodes", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fire1fox", "https://example.org/emoji/fire1fox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/fire1fox.png"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "fire1fox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "fire1fox" in installed()
  end

  test "accepts valid shortcodes with underscores", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fire_fox", "https://example.org/emoji/fire_fox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/fire_fox.png"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "fire_fox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "fire_fox" in installed()
  end

  test "accepts valid shortcodes with hyphens", %{path: path} do
    message = %{
      "type" => "Create",
      "object" => %{
        "emoji" => [{"fire-fox", "https://example.org/emoji/fire-fox.png"}],
        "actor" => "https://example.org/users/admin"
      }
    }

    Tesla.Mock.mock(fn %{method: :get, url: "https://example.org/emoji/fire-fox.png"} ->
      %Tesla.Env{status: 200, body: File.read!("test/fixtures/image.jpg")}
    end)

    clear_config(:mrf_steal_emoji, hosts: ["example.org"], size_limit: 284_468)

    refute "fire-fox" in installed()
    refute File.exists?(path)

    assert {:ok, _message} = StealEmojiPolicy.filter(message)

    assert "fire-fox" in installed()
  end

  defp installed, do: Emoji.get_all() |> Enum.map(fn {k, _} -> k end)
end
