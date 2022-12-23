# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatViewTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Object
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.AccountView
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView
  alias Pleroma.Web.PleromaAPI.ChatView

  import Pleroma.Factory

  test "it represents a chat" do
    user = insert(:user)
    recipient = insert(:user)

    {:ok, chat} = Chat.get_or_create(user.id, recipient.ap_id)

    represented_chat = ChatView.render("show.json", chat: chat)

    assert represented_chat == %{
             id: "#{chat.id}",
             account:
               AccountView.render("show.json", user: recipient, skip_visibility_check: true),
             unread: 0,
             last_message: nil,
             updated_at: Utils.to_masto_date(chat.updated_at)
           }

    {:ok, chat_message_creation} = CommonAPI.post_chat_message(user, recipient, "hello")

    chat_message = Object.normalize(chat_message_creation, fetch: false)

    {:ok, chat} = Chat.get_or_create(user.id, recipient.ap_id)

    represented_chat = ChatView.render("show.json", chat: chat)

    cm_ref = MessageReference.for_chat_and_object(chat, chat_message)

    assert represented_chat[:last_message] ==
             MessageReferenceView.render("show.json", chat_message_reference: cm_ref)
  end
end
