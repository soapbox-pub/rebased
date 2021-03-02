# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.Transmogrifier.LikeHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Activity
  alias Pleroma.Web.ActivityPub.Transmogrifier
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  test "it works for incoming likes" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    data =
      File.read!("test/fixtures/mastodon-like.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])

    _actor = insert(:user, ap_id: data["actor"], local: false)

    {:ok, %Activity{data: data, local: false} = activity} = Transmogrifier.handle_incoming(data)

    refute Enum.empty?(activity.recipients)

    assert data["actor"] == "http://mastodon.example.org/users/admin"
    assert data["type"] == "Like"
    assert data["id"] == "http://mastodon.example.org/users/admin#likes/2"
    assert data["object"] == activity.data["object"]
  end

  test "it works for incoming misskey likes, turning them into EmojiReacts" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    data =
      File.read!("test/fixtures/misskey-like.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])

    _actor = insert(:user, ap_id: data["actor"], local: false)

    {:ok, %Activity{data: activity_data, local: false}} = Transmogrifier.handle_incoming(data)

    assert activity_data["actor"] == data["actor"]
    assert activity_data["type"] == "EmojiReact"
    assert activity_data["id"] == data["id"]
    assert activity_data["object"] == activity.data["object"]
    assert activity_data["content"] == "🍮"
  end

  test "it works for incoming misskey likes that contain unicode emojis, turning them into EmojiReacts" do
    user = insert(:user)

    {:ok, activity} = CommonAPI.post(user, %{status: "hello"})

    data =
      File.read!("test/fixtures/misskey-like.json")
      |> Jason.decode!()
      |> Map.put("object", activity.data["object"])
      |> Map.put("_misskey_reaction", "⭐")

    _actor = insert(:user, ap_id: data["actor"], local: false)

    {:ok, %Activity{data: activity_data, local: false}} = Transmogrifier.handle_incoming(data)

    assert activity_data["actor"] == data["actor"]
    assert activity_data["type"] == "EmojiReact"
    assert activity_data["id"] == data["id"]
    assert activity_data["object"] == activity.data["object"]
    assert activity_data["content"] == "⭐"
  end
end
