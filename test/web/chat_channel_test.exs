defmodule Pleroma.Web.ChatChannelTest do
  use Pleroma.Web.ChannelCase
  alias Pleroma.Web.ChatChannel
  alias Pleroma.Web.UserSocket

  import Pleroma.Factory

  setup do
    user = insert(:user)

    {:ok, _, socket} =
      socket(UserSocket, "", %{user_name: user.nickname})
      |> subscribe_and_join(ChatChannel, "chat:public")

    {:ok, socket: socket}
  end

  test "it broadcasts a message", %{socket: socket} do
    push(socket, "new_msg", %{"text" => "why is tenshi eating a corndog so cute?"})
    assert_broadcast("new_msg", %{text: "why is tenshi eating a corndog so cute?"})
  end

  describe "message lengths" do
    clear_config([:instance, :chat_limit])

    test "it ignores messages of length zero", %{socket: socket} do
      push(socket, "new_msg", %{"text" => ""})
      refute_broadcast("new_msg", %{text: ""})
    end

    test "it ignores messages above a certain length", %{socket: socket} do
      Pleroma.Config.put([:instance, :chat_limit], 2)
      push(socket, "new_msg", %{"text" => "123"})
      refute_broadcast("new_msg", %{text: "123"})
    end
  end
end
