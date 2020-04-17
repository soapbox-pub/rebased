# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatMessageViewTest do
  use Pleroma.DataCase

  alias Pleroma.Chat
  alias Pleroma.Web.PleromaAPI.ChatView
  alias Pleroma.Web.MastodonAPI.AccountView

  import Pleroma.Factory

  test "it represents a chat" do
    user = insert(:user)
    recipient = insert(:user)

    {:ok, chat} = Chat.get_or_create(user.id, recipient.ap_id)

    represented_chat = ChatView.render("show.json", chat: chat)

    assert represented_chat == %{
             id: "#{chat.id}",
             recipient: recipient.ap_id,
             recipient_account: AccountView.render("show.json", user: recipient),
             unread: 0
           }
  end
end
