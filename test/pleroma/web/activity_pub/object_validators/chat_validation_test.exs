# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.ChatValidationTest do
  use Pleroma.DataCase
  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "chat message create activities" do
    test "it is invalid if the object already exists" do
      user = insert(:user)
      recipient = insert(:user)
      {:ok, activity} = CommonAPI.post_chat_message(user, recipient, "hey")
      object = Object.normalize(activity, fetch: false)

      {:ok, create_data, _} = Builder.create(user, object.data, [recipient.ap_id])

      {:error, cng} = ObjectValidator.validate(create_data, [])

      assert {:object, {"The object to create already exists", []}} in cng.errors
    end

    test "it is invalid if the object data has a different `to` or `actor` field" do
      user = insert(:user)
      recipient = insert(:user)
      {:ok, object_data, _} = Builder.chat_message(recipient, user.ap_id, "Hey")

      {:ok, create_data, _} = Builder.create(user, object_data, [recipient.ap_id])

      {:error, cng} = ObjectValidator.validate(create_data, [])

      assert {:to, {"Recipients don't match with object recipients", []}} in cng.errors
      assert {:actor, {"Actor doesn't match with object actor", []}} in cng.errors
    end
  end

  describe "chat messages" do
    setup do
      clear_config([:instance, :remote_limit])
      user = insert(:user)
      recipient = insert(:user, local: false)

      {:ok, valid_chat_message, _} = Builder.chat_message(user, recipient.ap_id, "hey :firefox:")

      %{user: user, recipient: recipient, valid_chat_message: valid_chat_message}
    end

    test "let's through some basic html", %{user: user, recipient: recipient} do
      {:ok, valid_chat_message, _} =
        Builder.chat_message(
          user,
          recipient.ap_id,
          "hey <a href='https://example.org'>example</a> <script>alert('uguu')</script>"
        )

      assert {:ok, object, _meta} = ObjectValidator.validate(valid_chat_message, [])

      assert object["content"] ==
               "hey <a href=\"https://example.org\">example</a> alert(&#39;uguu&#39;)"
    end

    test "validates for a basic object we build", %{valid_chat_message: valid_chat_message} do
      assert {:ok, object, _meta} = ObjectValidator.validate(valid_chat_message, [])

      assert valid_chat_message == object
      assert match?(%{"firefox" => _}, object["emoji"])
    end

    test "validates for a basic object with an attachment", %{
      valid_chat_message: valid_chat_message,
      user: user
    } do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, attachment} = ActivityPub.upload(file, actor: user.ap_id)

      valid_chat_message =
        valid_chat_message
        |> Map.put("attachment", attachment.data)

      assert {:ok, object, _meta} = ObjectValidator.validate(valid_chat_message, [])

      assert object["attachment"]
    end

    test "validates for a basic object with an attachment in an array", %{
      valid_chat_message: valid_chat_message,
      user: user
    } do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, attachment} = ActivityPub.upload(file, actor: user.ap_id)

      valid_chat_message =
        valid_chat_message
        |> Map.put("attachment", [attachment.data])

      assert {:ok, object, _meta} = ObjectValidator.validate(valid_chat_message, [])

      assert object["attachment"]
    end

    test "validates for a basic object with an attachment but without content", %{
      valid_chat_message: valid_chat_message,
      user: user
    } do
      file = %Plug.Upload{
        content_type: "image/jpeg",
        path: Path.absname("test/fixtures/image.jpg"),
        filename: "an_image.jpg"
      }

      {:ok, attachment} = ActivityPub.upload(file, actor: user.ap_id)

      valid_chat_message =
        valid_chat_message
        |> Map.put("attachment", attachment.data)
        |> Map.delete("content")

      assert {:ok, object, _meta} = ObjectValidator.validate(valid_chat_message, [])

      assert object["attachment"]
    end

    test "does not validate if the message has no content", %{
      valid_chat_message: valid_chat_message
    } do
      contentless =
        valid_chat_message
        |> Map.delete("content")

      refute match?({:ok, _object, _meta}, ObjectValidator.validate(contentless, []))
    end

    test "does not validate if the message is longer than the remote_limit", %{
      valid_chat_message: valid_chat_message
    } do
      clear_config([:instance, :remote_limit], 2)
      refute match?({:ok, _object, _meta}, ObjectValidator.validate(valid_chat_message, []))
    end

    test "does not validate if the recipient is blocking the actor", %{
      valid_chat_message: valid_chat_message,
      user: user,
      recipient: recipient
    } do
      Pleroma.User.block(recipient, user)
      refute match?({:ok, _object, _meta}, ObjectValidator.validate(valid_chat_message, []))
    end

    test "does not validate if the recipient is not accepting chat messages", %{
      valid_chat_message: valid_chat_message,
      recipient: recipient
    } do
      recipient
      |> Ecto.Changeset.change(%{accepts_chat_messages: false})
      |> Pleroma.Repo.update!()

      refute match?({:ok, _object, _meta}, ObjectValidator.validate(valid_chat_message, []))
    end

    test "does not validate if the actor or the recipient is not in our system", %{
      valid_chat_message: valid_chat_message
    } do
      chat_message =
        valid_chat_message
        |> Map.put("actor", "https://raymoo.com/raymoo")

      {:error, _} = ObjectValidator.validate(chat_message, [])

      chat_message =
        valid_chat_message
        |> Map.put("to", ["https://raymoo.com/raymoo"])

      {:error, _} = ObjectValidator.validate(chat_message, [])
    end

    test "does not validate for a message with multiple recipients", %{
      valid_chat_message: valid_chat_message,
      user: user,
      recipient: recipient
    } do
      chat_message =
        valid_chat_message
        |> Map.put("to", [user.ap_id, recipient.ap_id])

      assert {:error, _} = ObjectValidator.validate(chat_message, [])
    end

    test "does not validate if it doesn't concern local users" do
      user = insert(:user, local: false)
      recipient = insert(:user, local: false)

      {:ok, valid_chat_message, _} = Builder.chat_message(user, recipient.ap_id, "hey")
      assert {:error, _} = ObjectValidator.validate(valid_chat_message, [])
    end
  end
end
