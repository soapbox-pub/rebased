defmodule Pleroma.BBS.HandlerTest do
  use Pleroma.DataCase
  alias Pleroma.BBS.Handler
  alias Pleroma.Web.CommonAPI
  alias Pleroma.User
  alias Pleroma.Repo
  alias Pleroma.Activity

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
    assert activity.data["object"]["content"] == "this is a test post"
  end

  test "replying" do
    user = insert(:user)
    another_user = insert(:user)

    {:ok, activity} = CommonAPI.post(another_user, %{"status" => "this is a test post"})

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
    assert reply.data["object"]["content"] == "this is a reply"
    assert reply.data["object"]["inReplyTo"] == activity.data["object"]["id"]
  end
end
