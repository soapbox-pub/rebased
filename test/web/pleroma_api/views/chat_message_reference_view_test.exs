# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatMessageReferenceViewTest do
  use Pleroma.DataCase

  alias Pleroma.Chat
  alias Pleroma.ChatMessageReference
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.PleromaAPI.ChatMessageReferenceView

  import Pleroma.Factory

  test "it displays a chat message" do
    user = insert(:user)
    recipient = insert(:user)

    file = %Plug.Upload{
      content_type: "image/jpg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)
    {:ok, activity} = CommonAPI.post_chat_message(user, recipient, "kippis :firefox:")

    chat = Chat.get(user.id, recipient.ap_id)

    object = Object.normalize(activity)

    cm_ref = ChatMessageReference.for_chat_and_object(chat, object)

    chat_message = ChatMessageReferenceView.render("show.json", chat_message_reference: cm_ref)

    assert chat_message[:id] == cm_ref.id
    assert chat_message[:content] == "kippis :firefox:"
    assert chat_message[:account_id] == user.id
    assert chat_message[:chat_id]
    assert chat_message[:created_at]
    assert chat_message[:seen] == true
    assert match?([%{shortcode: "firefox"}], chat_message[:emojis])

    {:ok, activity} = CommonAPI.post_chat_message(recipient, user, "gkgkgk", media_id: upload.id)

    object = Object.normalize(activity)

    cm_ref = ChatMessageReference.for_chat_and_object(chat, object)

    chat_message_two =
      ChatMessageReferenceView.render("show.json", chat_message_reference: cm_ref)

    assert chat_message_two[:id] == cm_ref.id
    assert chat_message_two[:content] == "gkgkgk"
    assert chat_message_two[:account_id] == recipient.id
    assert chat_message_two[:chat_id] == chat_message[:chat_id]
    assert chat_message_two[:attachment]
    assert chat_message_two[:seen] == false
  end
end
