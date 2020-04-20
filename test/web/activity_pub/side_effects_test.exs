# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.SideEffectsTest do
  use Pleroma.DataCase

  alias Pleroma.Chat
  alias Pleroma.Notification
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "like objects" do
    setup do
      poster = insert(:user)
      user = insert(:user)
      {:ok, post} = CommonAPI.post(poster, %{"status" => "hey"})

      {:ok, like_data, _meta} = Builder.like(user, post.object)
      {:ok, like, _meta} = ActivityPub.persist(like_data, local: true)

      %{like: like, user: user, poster: poster}
    end

    test "add the like to the original object", %{like: like, user: user} do
      {:ok, like, _} = SideEffects.handle(like)
      object = Object.get_by_ap_id(like.data["object"])
      assert object.data["like_count"] == 1
      assert user.ap_id in object.data["likes"]
    end

    test "creates a notification", %{like: like, poster: poster} do
      {:ok, like, _} = SideEffects.handle(like)
      assert Repo.get_by(Notification, user_id: poster.id, activity_id: like.id)
    end
  end

  describe "creation of ChatMessages" do
    test "notifies the recipient" do
      author = insert(:user, local: false)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")
      {:ok, chat_message_object} = Object.create(chat_message_data)

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_object.data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, _meta} = SideEffects.handle(create_activity)

      assert Repo.get_by(Notification, user_id: recipient.id, activity_id: create_activity.id)
    end

    test "it creates a Chat for the local users and bumps the unread count" do
      author = insert(:user, local: false)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")
      {:ok, chat_message_object} = Object.create(chat_message_data)

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_object.data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, _meta} = SideEffects.handle(create_activity)

      # The remote user won't get a chat
      chat = Chat.get(author.id, recipient.ap_id)
      refute chat

      # The local user will get a chat
      chat = Chat.get(recipient.id, author.ap_id)
      assert chat

      author = insert(:user, local: true)
      recipient = insert(:user, local: true)

      {:ok, chat_message_data, _meta} = Builder.chat_message(author, recipient.ap_id, "hey")
      {:ok, chat_message_object} = Object.create(chat_message_data)

      {:ok, create_activity_data, _meta} =
        Builder.create(author, chat_message_object.data["id"], [recipient.ap_id])

      {:ok, create_activity, _meta} = ActivityPub.persist(create_activity_data, local: false)

      {:ok, _create_activity, _meta} = SideEffects.handle(create_activity)

      # Both users are local and get the chat
      chat = Chat.get(author.id, recipient.ap_id)
      assert chat

      chat = Chat.get(recipient.id, author.ap_id)
      assert chat
    end
  end
end
