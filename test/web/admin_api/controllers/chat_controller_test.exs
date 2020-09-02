# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.Chat
  alias Pleroma.Config
  alias Pleroma.ModerationLog
  alias Pleroma.Repo
  alias Pleroma.Web.CommonAPI

  setup do
    admin = insert(:user, is_admin: true)
    token = insert(:oauth_admin_token, user: admin)

    conn =
      build_conn()
      |> assign(:user, admin)
      |> assign(:token, token)

    {:ok, %{admin: admin, token: token, conn: conn}}
  end

  describe "DELETE /api/pleroma/admin/chats/:id/messages/:message_id" do
    setup do
      chat = insert(:chat)
      message = insert(:chat_message_activity, chat: chat)
      %{chat: chat, message: message}
    end

    test "deletes chat message", %{conn: conn, chat: chat, message: message, admin: admin} do
      conn
      |> delete("/api/pleroma/admin/chats/#{chat.id}/messages/#{message.id}")
      |> json_response_and_validate_schema(:ok)

      refute Activity.get_by_id(message.id)

      log_entry = Repo.one(ModerationLog)

      assert ModerationLog.get_log_entry_message(log_entry) ==
               "@#{admin.nickname} deleted chat message ##{message.id}"
    end

    test "returns 404 when the chat message does not exist", %{conn: conn} do
      conn = delete(conn, "/api/pleroma/admin/chats/test/messages/test")

      assert json_response_and_validate_schema(conn, :not_found) == %{"error" => "Not found"}
    end
  end

  describe "GET /api/pleroma/admin/chats/:id/messages" do
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
    test "it returns a chat", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> get("/api/pleroma/admin/chats/#{chat.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"] == to_string(chat.id)
    end
  end
end
