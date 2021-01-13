# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Chat.MessageReferenceTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "messages" do
    test "it returns the last message in a chat" do
      user = insert(:user)
      recipient = insert(:user)

      {:ok, _message_1} = CommonAPI.post_chat_message(user, recipient, "hey")
      {:ok, _message_2} = CommonAPI.post_chat_message(recipient, user, "ho")

      {:ok, chat} = Chat.get_or_create(user.id, recipient.ap_id)

      message = MessageReference.last_message_for_chat(chat)

      assert message.object.data["content"] == "ho"
    end
  end
end
