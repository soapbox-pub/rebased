# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatViewTest do
  use Pleroma.DataCase

  alias Pleroma.Chat
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.PleromaAPI.ChatView
  alias Pleroma.Web.PleromaAPI.ChatMessageView

  import Pleroma.Factory

  test "it represents a chat" do
    user = insert(:user)
    recipient = insert(:user)

    {:ok, chat} = Chat.get_or_create(user.id, recipient.ap_id)

    represented_chat = ChatView.render("show.json", chat: chat)

    assert represented_chat == %{
             id: "#{chat.id}",
             account: AccountView.render("show.json", user: recipient),
             unread: 0,
             last_message: nil
           }

    {:ok, chat_message_creation} = CommonAPI.post_chat_message(user, recipient, "hello")

    chat_message = Object.normalize(chat_message_creation, false)

    {:ok, chat} = Chat.get_or_create(user.id, recipient.ap_id)

    represented_chat = ChatView.render("show.json", chat: chat)

    assert represented_chat[:last_message] ==
             ChatMessageView.render("show.json", chat: chat, object: chat_message)
  end
end
