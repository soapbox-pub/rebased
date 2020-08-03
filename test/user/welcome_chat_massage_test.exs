# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeChatMessageTest do
  use Pleroma.DataCase

  alias Pleroma.Config
  alias Pleroma.User.WelcomeChatMessage

  import Pleroma.Factory

  setup do: clear_config([:welcome])

  describe "post_message/1" do
    test "send a chat welcome message" do
      welcome_user = insert(:user, name: "mewmew")
      user = insert(:user)

      Config.put([:welcome, :chat_message, :enabled], true)
      Config.put([:welcome, :chat_message, :sender_nickname], welcome_user.nickname)

      Config.put(
        [:welcome, :chat_message, :message],
        "Hello, welcome to Blob/Cat!"
      )

      {:ok, %Pleroma.Activity{} = activity} = WelcomeChatMessage.post_message(user)

      assert user.ap_id in activity.recipients
      assert Pleroma.Object.normalize(activity).data["type"] == "ChatMessage"
      assert Pleroma.Object.normalize(activity).data["content"] == "Hello, welcome to Blob/Cat!"
    end
  end
end
