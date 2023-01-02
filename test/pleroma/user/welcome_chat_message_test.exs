# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.User.WelcomeChatMessageTest do
  use Pleroma.DataCase

  alias Pleroma.User.WelcomeChatMessage

  import Pleroma.Factory

  setup do: clear_config([:welcome])

  describe "post_message/1" do
    test "send a chat welcome message" do
      welcome_user = insert(:user, name: "mewmew")
      user = insert(:user)

      clear_config([:welcome, :chat_message, :enabled], true)
      clear_config([:welcome, :chat_message, :sender_nickname], welcome_user.nickname)

      clear_config(
        [:welcome, :chat_message, :message],
        "Hello, welcome to Blob/Cat!"
      )

      {:ok, %Pleroma.Activity{} = activity} = WelcomeChatMessage.post_message(user)

      assert user.ap_id in activity.recipients
      assert Pleroma.Object.normalize(activity, fetch: false).data["type"] == "ChatMessage"

      assert Pleroma.Object.normalize(activity, fetch: false).data["content"] ==
               "Hello, welcome to Blob/Cat!"
    end
  end
end
