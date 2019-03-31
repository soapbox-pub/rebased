defmodule Pleroma.BBS.HandlerTest do
  use Pleroma.DataCase
  alias Pleroma.BBS.Handler
  alias Pleroma.Web.CommonAPI
  alias Pleroma.User

  import ExUnit.CaptureIO
  import Pleroma.Factory

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
end
