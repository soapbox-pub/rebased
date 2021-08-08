# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ShoutChannelTest do
  use Pleroma.Web.ChannelCase
  alias Pleroma.Web.ShoutChannel
  alias Pleroma.Web.UserSocket

  import Pleroma.Factory

  setup do
    user = insert(:user)

    {:ok, _, socket} =
      socket(UserSocket, "", %{user_name: user.nickname})
      |> subscribe_and_join(ShoutChannel, "chat:public")

    {:ok, socket: socket}
  end

  test "it broadcasts a message", %{socket: socket} do
    push(socket, "new_msg", %{"text" => "why is tenshi eating a corndog so cute?"})
    assert_broadcast("new_msg", %{text: "why is tenshi eating a corndog so cute?"})
  end

  describe "message lengths" do
    setup do: clear_config([:shout, :limit])

    test "it ignores messages of length zero", %{socket: socket} do
      push(socket, "new_msg", %{"text" => ""})
      refute_broadcast("new_msg", %{text: ""})
    end

    test "it ignores messages above a certain length", %{socket: socket} do
      clear_config([:shout, :limit], 2)
      push(socket, "new_msg", %{"text" => "123"})
      refute_broadcast("new_msg", %{text: "123"})
    end
  end
end
