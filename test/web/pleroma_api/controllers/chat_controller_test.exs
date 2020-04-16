# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Chat
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "POST /api/v1/pleroma/chats/:id/messages" do
    test "it posts a message to the chat", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> assign(:user, user)
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages", %{"content" => "Hallo!!"})
        |> json_response(200)

      assert result["content"] == "Hallo!!"
      assert result["chat_id"] == chat.id |> to_string()
    end
  end

  describe "GET /api/v1/pleroma/chats/:id/messages" do
    test "it paginates", %{conn: conn} do
      user = insert(:user)
      recipient = insert(:user)

      Enum.each(1..30, fn _ ->
        {:ok, _} = CommonAPI.post_chat_message(user, recipient, "hey")
      end)

      chat = Chat.get(user.id, recipient.ap_id)

      result =
        conn
        |> assign(:user, user)
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages")
        |> json_response(200)

      assert length(result) == 20

      result =
        conn
        |> assign(:user, user)
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages", %{"max_id" => List.last(result)["id"]})
        |> json_response(200)

      assert length(result) == 10
    end

    # TODO
    # - Test the case where it's not the user's chat
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
        |> assign(:user, user)
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages")
        |> json_response(200)

      result
      |> Enum.each(fn message ->
        assert message["chat_id"] == chat.id |> to_string()
      end)

      assert length(result) == 3
    end
  end

  describe "POST /api/v1/pleroma/chats/by-ap-id/:id" do
    test "it creates or returns a chat", %{conn: conn} do
      user = insert(:user)
      other_user = insert(:user)

      result =
        conn
        |> assign(:user, user)
        |> post("/api/v1/pleroma/chats/by-ap-id/#{URI.encode_www_form(other_user.ap_id)}")
        |> json_response(200)

      assert result["id"]
    end
  end

  describe "GET /api/v1/pleroma/chats" do
    test "it paginates", %{conn: conn} do
      user = insert(:user)

      Enum.each(1..30, fn _ ->
        recipient = insert(:user)
        {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)
      end)

      result =
        conn
        |> assign(:user, user)
        |> get("/api/v1/pleroma/chats")
        |> json_response(200)

      assert length(result) == 20

      result =
        conn
        |> assign(:user, user)
        |> get("/api/v1/pleroma/chats", %{max_id: List.last(result)["id"]})
        |> json_response(200)

      assert length(result) == 10
    end

    test "it return a list of chats the current user is participating in, in descending order of updates",
         %{conn: conn} do
      user = insert(:user)
      har = insert(:user)
      jafnhar = insert(:user)
      tridi = insert(:user)

      {:ok, chat_1} = Chat.get_or_create(user.id, har.ap_id)
      :timer.sleep(1000)
      {:ok, _chat_2} = Chat.get_or_create(user.id, jafnhar.ap_id)
      :timer.sleep(1000)
      {:ok, chat_3} = Chat.get_or_create(user.id, tridi.ap_id)
      :timer.sleep(1000)

      # bump the second one
      {:ok, chat_2} = Chat.bump_or_create(user.id, jafnhar.ap_id)

      result =
        conn
        |> assign(:user, user)
        |> get("/api/v1/pleroma/chats")
        |> json_response(200)

      ids = Enum.map(result, & &1["id"])

      assert ids == [
               chat_2.id |> to_string(),
               chat_3.id |> to_string(),
               chat_1.id |> to_string()
             ]
    end
  end
end
