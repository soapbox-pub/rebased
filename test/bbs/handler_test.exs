# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.BBS.HandlerTest do
  use Pleroma.DataCase
  alias Pleroma.Activity
  alias Pleroma.BBS.Handler
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.CommonAPI

  import ExUnit.CaptureIO
  import Pleroma.Factory
  import Ecto.Query

  test "getting the home timeline" do
    user = insert(:user)
    followed = insert(:user)

    {:ok, user} = User.follow(user, followed)

    {:ok, _first} = CommonAPI.post(user, %{"status" => "hey"})
    {:ok, _second} = CommonAPI.post(followed, %{"status" => "hello"})

    output =
      capture_io(fn ->
        Handler.handle_command(%{user: user}, "home")
      end)

    assert output =~ user.nickname
    assert output =~ followed.nickname

    assert output =~ "hey"
    assert output =~ "hello"
  end

  test "posting" do
    user = insert(:user)

    output =
      capture_io(fn ->
        Handler.handle_command(%{user: user}, "p this is a test post")
      end)

    assert output =~ "Posted"

    activity =
      Repo.one(
        from(a in Activity,
          where: fragment("?->>'type' = ?", a.data, "Create")
        )
      )

    assert activity.actor == user.ap_id
    object = Object.normalize(activity)
    assert object.data["content"] == "this is a test post"
  end

  test "replying" do
    user = insert(:user)
    another_user = insert(:user)

    {:ok, activity} = CommonAPI.post(another_user, %{"status" => "this is a test post"})
    activity_object = Object.normalize(activity)

    output =
      capture_io(fn ->
        Handler.handle_command(%{user: user}, "r #{activity.id} this is a reply")
      end)

    assert output =~ "Replied"

    reply =
      Repo.one(
        from(a in Activity,
          where: fragment("?->>'type' = ?", a.data, "Create"),
          where: a.actor == ^user.ap_id
        )
      )

    assert reply.actor == user.ap_id

    reply_object_data = Object.normalize(reply).data
    assert reply_object_data["content"] == "this is a reply"
    assert reply_object_data["inReplyTo"] == activity_object.data["id"]
  end
end
