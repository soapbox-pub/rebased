# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase, async: true

  import Pleroma.Factory

  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.ModerationLog
  alias Pleroma.Object
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  defp admin_setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "DELETE /api/pleroma/admin/chats/:id/messages/:message_id" do
    setup do: admin_setup()

    test "it deletes a message from the chat", %{conn: conn, admin: admin} do
      user = insert(:user)
      recipient = insert(:user)

      {:ok, message} =
        CommonAPI.post_chat_message(user, recipient, "Hello darkness my old friend")

      object = Object.normalize(message, fetch: false)

      chat = Chat.get(user.id, recipient.ap_id)
      recipient_chat = Chat.get(recipient.id, user.ap_id)

      cm_ref = MessageReference.for_chat_and_object(chat, object)
      recipient_cm_ref = MessageReference.for_chat_and_object(recipient_chat, object)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/pleroma/admin/chats/#{chat.id}/messages/#{cm_ref.id}")
        |> json_response_and_validate_schema(200)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted chat message ##{cm_ref.id}"

      assert result["id"] == cm_ref.id
      refute MessageReference.get_by_id(cm_ref.id)
      refute MessageReference.get_by_id(recipient_cm_ref.id)
      assert %{data: %{"type" => "Tombstone"}} = Object.get_by_id(object.id)
    end
  end

  describe "GET /api/pleroma/admin/chats/:id/messages" do
    setup do: admin_setup()

    test "it paginates", %{conn: conn} do
      user = insert(:user)
      recipient = insert(:user)

      Enum.each(1..30, fn _ ->
        {:ok, _} = CommonAPI.post_chat_message(user, recipient, "hey")
      end)

      chat = Chat.get(user.id, recipient.ap_id)

      result =
        conn
        |> get("/api/pleroma/admin/chats/#{chat.id}/messages")
        |> json_response_and_validate_schema(200)

      assert length(result) == 20

      result =
        conn
        |> get("/api/pleroma/admin/chats/#{chat.id}/messages?max_id=#{List.last(result)["id"]}")
        |> json_response_and_validate_schema(200)

      assert length(result) == 10
    end

    test "it returns the messages for a given chat", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, _} = CommonAPI.post_chat_message(user, other_user, "hey")
      {:ok, _} = CommonAPI.post_chat_message(user, third_user, "hey")
      {:ok, _} = CommonAPI.post_chat_message(user, other_user, "how are you?")
      {:ok, _} = CommonAPI.post_chat_message(other_user, user, "fine, how about you?")

      chat = Chat.get(user.id, other_user.ap_id)

      result =
        conn
        |> get("/api/pleroma/admin/chats/#{chat.id}/messages")
        |> json_response_and_validate_schema(200)

      result
      |> Enum.each(fn message ->
        assert message["chat_id"] == chat.id |> to_string()
      end)

      assert length(result) == 3
    end
  end

  describe "GET /api/pleroma/admin/chats/:id" do
    setup do: admin_setup()

    test "it returns a chat", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> get("/api/pleroma/admin/chats/#{chat.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"] == to_string(chat.id)
      assert %{} = result["sender"]
      assert %{} = result["receiver"]
      refute result["account"]
    end
  end

  describe "unauthorized chat moderation" do
    setup do
      user = insert(:user)
      recipient = insert(:user)

      {:ok, message} = CommonAPI.post_chat_message(user, recipient, "Yo")
      object = Object.normalize(message, fetch: false)
      chat = Chat.get(user.id, recipient.ap_id)
      cm_ref = MessageReference.for_chat_and_object(chat, object)

      %{conn: conn} = oauth_access(["read:chats", "write:chats"])
      %{conn: conn, chat: chat, cm_ref: cm_ref}
    end

    test "DELETE /api/pleroma/admin/chats/:id/messages/:message_id", %{
      conn: conn,
      chat: chat,
      cm_ref: cm_ref
    } do
      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/pleroma/admin/chats/#{chat.id}/messages/#{cm_ref.id}")
      |> json_response(403)

      assert MessageReference.get_by_id(cm_ref.id) == cm_ref
    end

    test "GET /api/pleroma/admin/chats/:id/messages", %{conn: conn, chat: chat} do
      conn
      |> get("/api/pleroma/admin/chats/#{chat.id}/messages")
      |> json_response(403)
    end

    test "GET /api/pleroma/admin/chats/:id", %{conn: conn, chat: chat} do
      conn
      |> get("/api/pleroma/admin/chats/#{chat.id}")
      |> json_response(403)
    end
  end

  describe "unauthenticated chat moderation" do
    setup do
      user = insert(:user)
      recipient = insert(:user)

      {:ok, message} = CommonAPI.post_chat_message(user, recipient, "Yo")
      object = Object.normalize(message, fetch: false)
      chat = Chat.get(user.id, recipient.ap_id)
      cm_ref = MessageReference.for_chat_and_object(chat, object)

      %{conn: build_conn(), chat: chat, cm_ref: cm_ref}
    end

    test "DELETE /api/pleroma/admin/chats/:id/messages/:message_id", %{
      conn: conn,
      chat: chat,
      cm_ref: cm_ref
    } do
      conn
      |> put_req_header("content-type", "application/json")
      |> delete("/api/pleroma/admin/chats/#{chat.id}/messages/#{cm_ref.id}")
      |> json_response(403)

      assert MessageReference.get_by_id(cm_ref.id) == cm_ref
    end

    test "GET /api/pleroma/admin/chats/:id/messages", %{conn: conn, chat: chat} do
      conn
      |> get("/api/pleroma/admin/chats/#{chat.id}/messages")
      |> json_response(403)
    end

    test "GET /api/pleroma/admin/chats/:id", %{conn: conn, chat: chat} do
      conn
      |> get("/api/pleroma/admin/chats/#{chat.id}")
      |> json_response(403)
    end
  end
end
