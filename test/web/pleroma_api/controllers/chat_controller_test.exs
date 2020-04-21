# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Chat
  alias Pleroma.Web.ApiSpec
  alias Pleroma.Web.ApiSpec.Schemas.ChatResponse
  alias Pleroma.Web.ApiSpec.Schemas.ChatsResponse
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessageResponse
  alias Pleroma.Web.ApiSpec.Schemas.ChatMessagesResponse
  alias Pleroma.Web.CommonAPI

  import OpenApiSpex.TestAssertions
  import Pleroma.Factory

  describe "POST /api/v1/pleroma/chats/:id/messages" do
    setup do: oauth_access(["write:statuses"])

    test "it posts a message to the chat", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages", %{"content" => "Hallo!!"})
        |> json_response(200)

      assert result["content"] == "Hallo!!"
      assert result["chat_id"] == chat.id |> to_string()
      assert_schema(result, "ChatMessageResponse", ApiSpec.spec())
    end
  end

  describe "GET /api/v1/pleroma/chats/:id/messages" do
    setup do: oauth_access(["read:statuses"])

    test "it paginates", %{conn: conn, user: user} do
      recipient = insert(:user)

      Enum.each(1..30, fn _ ->
        {:ok, _} = CommonAPI.post_chat_message(user, recipient, "hey")
      end)

      chat = Chat.get(user.id, recipient.ap_id)

      result =
        conn
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages")
        |> json_response(200)

      assert length(result) == 20
      assert_schema(result, "ChatMessagesResponse", ApiSpec.spec())

      result =
        conn
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages", %{"max_id" => List.last(result)["id"]})
        |> json_response(200)

      assert length(result) == 10
      assert_schema(result, "ChatMessagesResponse", ApiSpec.spec())
    end

    test "it returns the messages for a given chat", %{conn: conn, user: user} do
      other_user = insert(:user)
      third_user = insert(:user)

      {:ok, _} = CommonAPI.post_chat_message(user, other_user, "hey")
      {:ok, _} = CommonAPI.post_chat_message(user, third_user, "hey")
      {:ok, _} = CommonAPI.post_chat_message(user, other_user, "how are you?")
      {:ok, _} = CommonAPI.post_chat_message(other_user, user, "fine, how about you?")

      chat = Chat.get(user.id, other_user.ap_id)

      result =
        conn
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages")
        |> json_response(200)

      result
      |> Enum.each(fn message ->
        assert message["chat_id"] == chat.id |> to_string()
      end)

      assert length(result) == 3
      assert_schema(result, "ChatMessagesResponse", ApiSpec.spec())

      # Trying to get the chat of a different user
      result =
        conn
        |> assign(:user, other_user)
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages")

      assert result |> json_response(404)
    end
  end

  describe "POST /api/v1/pleroma/chats/by-ap-id/:id" do
    setup do: oauth_access(["write:statuses"])

    test "it creates or returns a chat", %{conn: conn} do
      other_user = insert(:user)

      result =
        conn
        |> post("/api/v1/pleroma/chats/by-ap-id/#{URI.encode_www_form(other_user.ap_id)}")
        |> json_response(200)

      assert result["id"]
      assert_schema(result, "ChatResponse", ApiSpec.spec())
    end
  end

  describe "GET /api/v1/pleroma/chats" do
    setup do: oauth_access(["read:statuses"])

    test "it paginates", %{conn: conn, user: user} do
      Enum.each(1..30, fn _ ->
        recipient = insert(:user)
        {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)
      end)

      result =
        conn
        |> get("/api/v1/pleroma/chats")
        |> json_response(200)

      assert length(result) == 20
      assert_schema(result, "ChatsResponse", ApiSpec.spec())

      result =
        conn
        |> get("/api/v1/pleroma/chats", %{max_id: List.last(result)["id"]})
        |> json_response(200)

      assert length(result) == 10

      assert_schema(result, "ChatsResponse", ApiSpec.spec())
    end

    test "it return a list of chats the current user is participating in, in descending order of updates",
         %{conn: conn, user: user} do
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
        |> get("/api/v1/pleroma/chats")
        |> json_response(200)

      ids = Enum.map(result, & &1["id"])

      assert ids == [
               chat_2.id |> to_string(),
               chat_3.id |> to_string(),
               chat_1.id |> to_string()
             ]

      assert_schema(result, "ChatsResponse", ApiSpec.spec())
    end
  end

  describe "schemas" do
    test "Chat example matches schema" do
      api_spec = ApiSpec.spec()
      schema = ChatResponse.schema()
      assert_schema(schema.example, "ChatResponse", api_spec)
    end

    test "Chats example matches schema" do
      api_spec = ApiSpec.spec()
      schema = ChatsResponse.schema()
      assert_schema(schema.example, "ChatsResponse", api_spec)
    end

    test "ChatMessage example matches schema" do
      api_spec = ApiSpec.spec()
      schema = ChatMessageResponse.schema()
      assert_schema(schema.example, "ChatMessageResponse", api_spec)
    end

    test "ChatsMessage example matches schema" do
      api_spec = ApiSpec.spec()
      schema = ChatMessagesResponse.schema()
      assert_schema(schema.example, "ChatMessagesResponse", api_spec)
    end
  end
end
