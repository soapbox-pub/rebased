# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.Chat
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "POST /api/v1/pleroma/chats/:id/read" do
    setup do: oauth_access(["write:statuses"])

    test "it marks all messages in a chat as read", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, chat} = Chat.bump_or_create(user.id, other_user.ap_id)

      assert chat.unread == 1

      result =
        conn
        |> post("/api/v1/pleroma/chats/#{chat.id}/read")
        |> json_response_and_validate_schema(200)

      assert result["unread"] == 0

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      assert chat.unread == 0
    end
  end

  describe "POST /api/v1/pleroma/chats/:id/messages" do
    setup do: oauth_access(["write:statuses"])

    test "it posts a message to the chat", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages", %{"content" => "Hallo!!"})
        |> json_response_and_validate_schema(200)

      assert result["content"] == "Hallo!!"
      assert result["chat_id"] == chat.id |> to_string()
    end

    test "it works with an attachment", %{conn: conn, user: user} do
      file = %Plug.Upload{
        content_type: "image/jpg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, upload} = ActivityPub.upload(file, actor: user.ap_id)

      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages", %{
          "content" => "Hallo!!",
          "media_id" => to_string(upload.id)
        })
        |> json_response_and_validate_schema(200)

      assert result["content"] == "Hallo!!"
      assert result["chat_id"] == chat.id |> to_string()
    end
  end

  describe "DELETE /api/v1/pleroma/chats/:id/messages/:message_id" do
    setup do: oauth_access(["write:statuses"])

    test "it deletes a message for the author of the message", %{conn: conn, user: user} do
      recipient = insert(:user)

      {:ok, message} =
        CommonAPI.post_chat_message(user, recipient, "Hello darkness my old friend")

      {:ok, other_message} = CommonAPI.post_chat_message(recipient, user, "nico nico ni")

      object = Object.normalize(message, false)

      chat = Chat.get(user.id, recipient.ap_id)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/v1/pleroma/chats/#{chat.id}/messages/#{object.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"] == to_string(object.id)

      object = Object.normalize(other_message, false)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/v1/pleroma/chats/#{chat.id}/messages/#{object.id}")
        |> json_response(400)

      assert result == %{"error" => "could_not_delete"}
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
        |> json_response_and_validate_schema(200)

      assert length(result) == 20

      result =
        conn
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages?max_id=#{List.last(result)["id"]}")
        |> json_response_and_validate_schema(200)

      assert length(result) == 10
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
        |> json_response_and_validate_schema(200)

      result
      |> Enum.each(fn message ->
        assert message["chat_id"] == chat.id |> to_string()
      end)

      assert length(result) == 3

      # Trying to get the chat of a different user
      result =
        conn
        |> assign(:user, other_user)
        |> get("/api/v1/pleroma/chats/#{chat.id}/messages")

      assert result |> json_response(404)
    end
  end

  describe "POST /api/v1/pleroma/chats/by-account-id/:id" do
    setup do: oauth_access(["write:statuses"])

    test "it creates or returns a chat", %{conn: conn} do
      other_user = insert(:user)

      result =
        conn
        |> post("/api/v1/pleroma/chats/by-account-id/#{other_user.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"]
    end
  end

  describe "GET /api/v1/pleroma/chats/:id" do
    setup do: oauth_access(["read:statuses"])

    test "it returns a chat", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> get("/api/v1/pleroma/chats/#{chat.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"] == to_string(chat.id)
    end
  end

  describe "GET /api/v1/pleroma/chats" do
    setup do: oauth_access(["read:statuses"])

    test "it does not return chats with users you blocked", %{conn: conn, user: user} do
      recipient = insert(:user)

      {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)

      result =
        conn
        |> get("/api/v1/pleroma/chats")
        |> json_response_and_validate_schema(200)

      assert length(result) == 1

      User.block(user, recipient)

      result =
        conn
        |> get("/api/v1/pleroma/chats")
        |> json_response_and_validate_schema(200)

      assert length(result) == 0
    end

    test "it paginates", %{conn: conn, user: user} do
      Enum.each(1..30, fn _ ->
        recipient = insert(:user)
        {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)
      end)

      result =
        conn
        |> get("/api/v1/pleroma/chats")
        |> json_response_and_validate_schema(200)

      assert length(result) == 20

      result =
        conn
        |> get("/api/v1/pleroma/chats?max_id=#{List.last(result)["id"]}")
        |> json_response_and_validate_schema(200)

      assert length(result) == 10
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
        |> json_response_and_validate_schema(200)

      ids = Enum.map(result, & &1["id"])

      assert ids == [
               chat_2.id |> to_string(),
               chat_3.id |> to_string(),
               chat_1.id |> to_string()
             ]
    end
  end
end
