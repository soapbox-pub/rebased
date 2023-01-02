# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only
defmodule Pleroma.Web.PleromaAPI.ChatControllerTest do
  use Pleroma.Web.ConnCase

  alias Pleroma.Chat
  alias Pleroma.Chat.MessageReference
  alias Pleroma.Object
  alias Pleroma.User
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "POST /api/v1/pleroma/chats/:id/messages/:message_id/read" do
    setup do: oauth_access(["write:chats"])

    test "it marks one message as read", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, create} = CommonAPI.post_chat_message(other_user, user, "sup")
      {:ok, _create} = CommonAPI.post_chat_message(other_user, user, "sup part 2")
      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)
      object = Object.normalize(create, fetch: false)
      cm_ref = MessageReference.for_chat_and_object(chat, object)

      assert cm_ref.unread == true

      result =
        conn
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages/#{cm_ref.id}/read")
        |> json_response_and_validate_schema(200)

      assert result["unread"] == false

      cm_ref = MessageReference.for_chat_and_object(chat, object)

      assert cm_ref.unread == false
    end
  end

  describe "POST /api/v1/pleroma/chats/:id/read" do
    setup do: oauth_access(["write:chats"])

    test "given a `last_read_id`, it marks everything until then as read", %{
      conn: conn,
      user: user
    } do
      other_user = insert(:user)

      {:ok, create} = CommonAPI.post_chat_message(other_user, user, "sup")
      {:ok, _create} = CommonAPI.post_chat_message(other_user, user, "sup part 2")
      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)
      object = Object.normalize(create, fetch: false)
      cm_ref = MessageReference.for_chat_and_object(chat, object)

      assert cm_ref.unread == true

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/chats/#{chat.id}/read", %{"last_read_id" => cm_ref.id})
        |> json_response_and_validate_schema(200)

      assert result["unread"] == 1

      cm_ref = MessageReference.for_chat_and_object(chat, object)

      assert cm_ref.unread == false
    end
  end

  describe "POST /api/v1/pleroma/chats/:id/messages" do
    setup do: oauth_access(["write:chats"])

    test "it posts a message to the chat", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> put_req_header("idempotency-key", "123")
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages", %{"content" => "Hallo!!"})
        |> json_response_and_validate_schema(200)

      assert result["content"] == "Hallo!!"
      assert result["chat_id"] == chat.id |> to_string()
      assert result["idempotency_key"] == "123"
    end

    test "it fails if there is no content", %{conn: conn, user: user} do
      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages")
        |> json_response_and_validate_schema(400)

      assert %{"error" => "no_content"} == result
    end

    test "it works with an attachment", %{conn: conn, user: user} do
      file = %Plug.Upload{
        content_type: "image/jpeg",
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
          "media_id" => to_string(upload.id)
        })
        |> json_response_and_validate_schema(200)

      assert result["attachment"]
    end

    test "gets MRF reason when rejected", %{conn: conn, user: user} do
      clear_config([:mrf_keyword, :reject], ["GNO"])
      clear_config([:mrf, :policies], [Pleroma.Web.ActivityPub.MRF.KeywordPolicy])

      other_user = insert(:user)

      {:ok, chat} = Chat.get_or_create(user.id, other_user.ap_id)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/v1/pleroma/chats/#{chat.id}/messages", %{"content" => "GNO/Linux"})
        |> json_response_and_validate_schema(422)

      assert %{"error" => "[KeywordPolicy] Matches with rejected keyword"} == result
    end
  end

  describe "DELETE /api/v1/pleroma/chats/:id/messages/:message_id" do
    setup do: oauth_access(["write:chats"])

    test "it deletes a message from the chat", %{conn: conn, user: user} do
      recipient = insert(:user)

      {:ok, message} =
        CommonAPI.post_chat_message(user, recipient, "Hello darkness my old friend")

      {:ok, other_message} = CommonAPI.post_chat_message(recipient, user, "nico nico ni")

      object = Object.normalize(message, fetch: false)

      chat = Chat.get(user.id, recipient.ap_id)

      cm_ref = MessageReference.for_chat_and_object(chat, object)

      # Deleting your own message removes the message and the reference
      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/v1/pleroma/chats/#{chat.id}/messages/#{cm_ref.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"] == cm_ref.id
      refute MessageReference.get_by_id(cm_ref.id)
      assert %{data: %{"type" => "Tombstone"}} = Object.get_by_id(object.id)

      # Deleting other people's messages just removes the reference
      object = Object.normalize(other_message, fetch: false)
      cm_ref = MessageReference.for_chat_and_object(chat, object)

      result =
        conn
        |> put_req_header("content-type", "application/json")
        |> delete("/api/v1/pleroma/chats/#{chat.id}/messages/#{cm_ref.id}")
        |> json_response_and_validate_schema(200)

      assert result["id"] == cm_ref.id
      refute MessageReference.get_by_id(cm_ref.id)
      assert Object.get_by_id(object.id)
    end
  end

  describe "GET /api/v1/pleroma/chats/:id/messages" do
    setup do: oauth_access(["read:chats"])

    test "it paginates", %{conn: conn, user: user} do
      recipient = insert(:user)

      Enum.each(1..30, fn _ ->
        {:ok, _} = CommonAPI.post_chat_message(user, recipient, "hey")
      end)

      chat = Chat.get(user.id, recipient.ap_id)

      response = get(conn, "/api/v1/pleroma/chats/#{chat.id}/messages")
      result = json_response_and_validate_schema(response, 200)

      [next, prev] = get_resp_header(response, "link") |> hd() |> String.split(", ")
      api_endpoint = "/api/v1/pleroma/chats/"

      assert String.match?(
               next,
               ~r(#{api_endpoint}.*/messages\?limit=\d+&max_id=.*; rel=\"next\"$)
             )

      assert String.match?(
               prev,
               ~r(#{api_endpoint}.*/messages\?limit=\d+&min_id=.*; rel=\"prev\"$)
             )

      assert length(result) == 20

      response =
        get(conn, "/api/v1/pleroma/chats/#{chat.id}/messages?max_id=#{List.last(result)["id"]}")

      result = json_response_and_validate_schema(response, 200)
      [next, prev] = get_resp_header(response, "link") |> hd() |> String.split(", ")

      assert String.match?(
               next,
               ~r(#{api_endpoint}.*/messages\?limit=\d+&max_id=.*; rel=\"next\"$)
             )

      assert String.match?(
               prev,
               ~r(#{api_endpoint}.*/messages\?limit=\d+&max_id=.*&min_id=.*; rel=\"prev\"$)
             )

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
      other_user_chat = Chat.get(other_user.id, user.ap_id)

      conn
      |> get("/api/v1/pleroma/chats/#{other_user_chat.id}/messages")
      |> json_response_and_validate_schema(404)
    end
  end

  describe "POST /api/v1/pleroma/chats/by-account-id/:id" do
    setup do: oauth_access(["write:chats"])

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
    setup do: oauth_access(["read:chats"])

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

  for tested_endpoint <- ["/api/v1/pleroma/chats", "/api/v2/pleroma/chats"] do
    describe "GET #{tested_endpoint}" do
      setup do: oauth_access(["read:chats"])

      test "it does not return chats with deleted users", %{conn: conn, user: user} do
        recipient = insert(:user)
        {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)

        Pleroma.Repo.delete(recipient)
        User.invalidate_cache(recipient)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        assert length(result) == 0
      end

      test "it does not return chats with users you blocked", %{conn: conn, user: user} do
        recipient = insert(:user)

        {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        assert length(result) == 1

        User.block(user, recipient)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        assert length(result) == 0
      end

      test "it does not return chats with users you muted", %{conn: conn, user: user} do
        recipient = insert(:user)

        {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        assert length(result) == 1

        User.mute(user, recipient)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        assert length(result) == 0

        result =
          conn
          |> get("#{unquote(tested_endpoint)}?with_muted=true")
          |> json_response_and_validate_schema(200)

        assert length(result) == 1
      end

      if tested_endpoint == "/api/v1/pleroma/chats" do
        test "it returns all chats", %{conn: conn, user: user} do
          Enum.each(1..30, fn _ ->
            recipient = insert(:user)
            {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)
          end)

          result =
            conn
            |> get(unquote(tested_endpoint))
            |> json_response_and_validate_schema(200)

          assert length(result) == 30
        end
      else
        test "it paginates chats", %{conn: conn, user: user} do
          Enum.each(1..30, fn _ ->
            recipient = insert(:user)
            {:ok, _} = Chat.get_or_create(user.id, recipient.ap_id)
          end)

          result =
            conn
            |> get(unquote(tested_endpoint))
            |> json_response_and_validate_schema(200)

          assert length(result) == 20
          last_id = List.last(result)["id"]

          result =
            conn
            |> get(unquote(tested_endpoint) <> "?max_id=#{last_id}")
            |> json_response_and_validate_schema(200)

          assert length(result) == 10
        end
      end

      test "it return a list of chats the current user is participating in, in descending order of updates",
           %{conn: conn, user: user} do
        har = insert(:user)
        jafnhar = insert(:user)
        tridi = insert(:user)

        {:ok, chat_1} = Chat.get_or_create(user.id, har.ap_id)
        {:ok, chat_1} = time_travel(chat_1, -3)
        {:ok, chat_2} = Chat.get_or_create(user.id, jafnhar.ap_id)
        {:ok, _chat_2} = time_travel(chat_2, -2)
        {:ok, chat_3} = Chat.get_or_create(user.id, tridi.ap_id)
        {:ok, chat_3} = time_travel(chat_3, -1)

        # bump the second one
        {:ok, chat_2} = Chat.bump_or_create(user.id, jafnhar.ap_id)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        ids = Enum.map(result, & &1["id"])

        assert ids == [
                 chat_2.id |> to_string(),
                 chat_3.id |> to_string(),
                 chat_1.id |> to_string()
               ]
      end

      test "it is not affected by :restrict_unauthenticated setting (issue #1973)", %{
        conn: conn,
        user: user
      } do
        clear_config([:restrict_unauthenticated, :profiles, :local], true)
        clear_config([:restrict_unauthenticated, :profiles, :remote], true)

        user2 = insert(:user)
        user3 = insert(:user, local: false)

        {:ok, _chat_12} = Chat.get_or_create(user.id, user2.ap_id)
        {:ok, _chat_13} = Chat.get_or_create(user.id, user3.ap_id)

        result =
          conn
          |> get(unquote(tested_endpoint))
          |> json_response_and_validate_schema(200)

        account_ids = Enum.map(result, &get_in(&1, ["account", "id"]))
        assert Enum.sort(account_ids) == Enum.sort([user2.id, user3.id])
      end
    end
  end
end
