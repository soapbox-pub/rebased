defmodule Pleroma.Web.ActivityPub.ObjectValidatorTest do
  use Pleroma.DataCase

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.ActivityPub
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.AttachmentValidator
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "attachments" do
    test "it turns mastodon attachments into our attachments" do
      attachment = %{
        "url" =>
          "http://mastodon.example.org/system/media_attachments/files/000/000/002/original/334ce029e7bfb920.jpg",
        "type" => "Document",
        "name" => nil,
        "mediaType" => "image/jpeg"
      }

      {:ok, attachment} =
        AttachmentValidator.cast_and_validate(attachment)
        |> Ecto.Changeset.apply_action(:insert)

      assert [
               %{
                 href:
                   "http://mastodon.example.org/system/media_attachments/files/000/000/002/original/334ce029e7bfb920.jpg",
                 type: "Link",
                 mediaType: "image/jpeg"
               }
             ] = attachment.url
    end
  end

  describe "chat message create activities" do
    test "it is invalid if the object already exists" do
      user = insert(:user)
      recipient = insert(:user)
      {:ok, activity} = CommonAPI.post_chat_message(user, recipient, "hey")
      object = Object.normalize(activity, false)

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

    test "validates for a basic object we build", %{valid_chat_message: valid_chat_message} do
      assert {:ok, object, _meta} = ObjectValidator.validate(valid_chat_message, [])

      assert Map.put(valid_chat_message, "attachment", nil) == object
    end

    test "validates for a basic object with an attachment", %{
      valid_chat_message: valid_chat_message,
      user: user
    } do
      file = %Plug.Upload{
        content_type: "image/jpg",
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

    test "does not validate if the message is longer than the remote_limit", %{
      valid_chat_message: valid_chat_message
    } do
      Pleroma.Config.put([:instance, :remote_limit], 2)
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

  describe "likes" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{"status" => "uguu"})

      valid_like = %{
        "to" => [user.ap_id],
        "cc" => [],
        "type" => "Like",
        "id" => Utils.generate_activity_id(),
        "object" => post_activity.data["object"],
        "actor" => user.ap_id,
        "context" => "a context"
      }

      %{valid_like: valid_like, user: user, post_activity: post_activity}
    end

    test "returns ok when called in the ObjectValidator", %{valid_like: valid_like} do
      {:ok, object, _meta} = ObjectValidator.validate(valid_like, [])

      assert "id" in Map.keys(object)
    end

    test "is valid for a valid object", %{valid_like: valid_like} do
      assert LikeValidator.cast_and_validate(valid_like).valid?
    end

    test "sets the 'to' field to the object actor if no recipients are given", %{
      valid_like: valid_like,
      user: user
    } do
      without_recipients =
        valid_like
        |> Map.delete("to")

      {:ok, object, _meta} = ObjectValidator.validate(without_recipients, [])

      assert object["to"] == [user.ap_id]
    end

    test "sets the context field to the context of the object if no context is given", %{
      valid_like: valid_like,
      post_activity: post_activity
    } do
      without_context =
        valid_like
        |> Map.delete("context")

      {:ok, object, _meta} = ObjectValidator.validate(without_context, [])

      assert object["context"] == post_activity.data["context"]
    end

    test "it errors when the actor is missing or not known", %{valid_like: valid_like} do
      without_actor = Map.delete(valid_like, "actor")

      refute LikeValidator.cast_and_validate(without_actor).valid?

      with_invalid_actor = Map.put(valid_like, "actor", "invalidactor")

      refute LikeValidator.cast_and_validate(with_invalid_actor).valid?
    end

    test "it errors when the object is missing or not known", %{valid_like: valid_like} do
      without_object = Map.delete(valid_like, "object")

      refute LikeValidator.cast_and_validate(without_object).valid?

      with_invalid_object = Map.put(valid_like, "object", "invalidobject")

      refute LikeValidator.cast_and_validate(with_invalid_object).valid?
    end

    test "it errors when the actor has already like the object", %{
      valid_like: valid_like,
      user: user,
      post_activity: post_activity
    } do
      _like = CommonAPI.favorite(user, post_activity.id)

      refute LikeValidator.cast_and_validate(valid_like).valid?
    end

    test "it works when actor or object are wrapped in maps", %{valid_like: valid_like} do
      wrapped_like =
        valid_like
        |> Map.put("actor", %{"id" => valid_like["actor"]})
        |> Map.put("object", %{"id" => valid_like["object"]})

      validated = LikeValidator.cast_and_validate(wrapped_like)

      assert validated.valid?

      assert {:actor, valid_like["actor"]} in validated.changes
      assert {:object, valid_like["object"]} in validated.changes
    end
  end
end
