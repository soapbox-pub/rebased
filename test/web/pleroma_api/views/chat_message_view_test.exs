# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatMessageViewTest do
  use Pleroma.DataCase

  alias Pleroma.Chat
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.PleromaAPI.ChatMessageView

  import Pleroma.Factory

  test "it displays a chat message" do
    user = insert(:user)
    recipient = insert(:user)
    {:ok, activity} = CommonAPI.post_chat_message(user, recipient, "kippis")

    chat = Chat.get(user.id, recipient.ap_id)

    object = Object.normalize(activity)

    chat_message = ChatMessageView.render("show.json", object: object, for: user, chat: chat)

    assert chat_message[:id] == object.id |> to_string()
    assert chat_message[:content] == "kippis"
    assert chat_message[:actor] == user.ap_id
    assert chat_message[:chat_id]

    {:ok, activity} = CommonAPI.post_chat_message(recipient, user, "gkgkgk")

    object = Object.normalize(activity)

    chat_message_two = ChatMessageView.render("show.json", object: object, for: user, chat: chat)

    assert chat_message_two[:id] == object.id |> to_string()
    assert chat_message_two[:content] == "gkgkgk"
    assert chat_message_two[:actor] == recipient.ap_id
    assert chat_message_two[:chat_id] == chat_message[:chat_id]
  end
end
