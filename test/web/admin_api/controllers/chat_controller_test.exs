# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase

  import Pleroma.Factory

  alias Pleroma.Activity
  alias Pleroma.Config
  alias Pleroma.ModerationLog
  alias Pleroma.Repo

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
end
