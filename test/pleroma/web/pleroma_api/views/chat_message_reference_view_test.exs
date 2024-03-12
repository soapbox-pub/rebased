# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.ChatMessageReferenceViewTest do
  use Pleroma.DataCase, async: false

  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Object
  alias Pleroma.StaticStubbedConfigMock, as: ConfigMock
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI
  alias Pleroma.Web.PleromaAPI.Chat.MessageReferenceView

  import Mox
  import Pleroma.Factory
  import Tesla.Mock

  test "crawls valid, complete URLs" do
    mock_global(fn env -> apply(HttpRequestMock, :request, [env]) end)

    ConfigMock
    |> stub(:get, fn
      [:rich_media, :enabled] -> true
      path -> Pleroma.Test.StaticConfig.get(path)
    end)

    Pleroma.UnstubbedConfigMock
    |> stub(:get, fn
      [:rich_media, :enabled] -> true
      path -> Pleroma.Test.StaticConfig.get(path)
    end)

    user = insert(:user)
    recipient = insert(:user)

    file = %Plug.Upload{
      content_type: "image/jpeg",
      path: Path.absname("test/fixtures/image.jpg"),
      filename: "an_image.jpg"
    }

    {:ok, upload} = ActivityPub.upload(file, actor: recipient.ap_id)

    {:ok, activity} =
      CommonAPI.post_chat_message(user, recipient, "kippis :firefox:", idempotency_key: "123")

    chat = Chat.get(user.id, recipient.ap_id)

    object = Object.normalize(activity, fetch: false)

    cm_ref = MessageReference.for_chat_and_object(chat, object)

    {:ok, activity} =
      CommonAPI.post(user, %{
        status: "[test](https://example.com/ogp)",
        content_type: "text/markdown"
      })

    assert %{url: "https://example.com/ogp", meta: %{} = _} =
             Pleroma.Web.RichMedia.Helpers.fetch_data_for_activity(activity)

    chat_message = MessageReferenceView.render("show.json", chat_message_reference: cm_ref)

    assert chat_message[:id] == cm_ref.id
    assert chat_message[:content] == "kippis :firefox:"
    assert chat_message[:account_id] == user.id
    assert chat_message[:chat_id]
    assert chat_message[:created_at]
    assert chat_message[:unread] == false
    assert match?([%{shortcode: "firefox"}], chat_message[:emojis])

    {:ok, activity} =
      CommonAPI.post_chat_message(recipient, user, "gkgkgk https://example.com/ogp",
        media_id: upload.id
      )

    object = Object.normalize(activity, fetch: false)

    cm_ref = MessageReference.for_chat_and_object(chat, object)

    chat_message_two = MessageReferenceView.render("show.json", chat_message_reference: cm_ref)

    assert chat_message_two[:id] == cm_ref.id
    assert chat_message_two[:content] == object.data["content"]
    assert chat_message_two[:account_id] == recipient.id
    assert chat_message_two[:chat_id] == chat_message[:chat_id]
    assert chat_message_two[:attachment]
    assert chat_message_two[:unread] == true
    assert chat_message_two[:card]
  end
end
