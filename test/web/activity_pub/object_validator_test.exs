defmodule Pleroma.Web.ActivityPub.ObjectValidatorTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

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

      assert object == valid_chat_message
    end

    test "does not validate if the message is longer than the remote_limit", %{
      valid_chat_message: valid_chat_message
    } do
      Pleroma.Config.put([:instance, :remote_limit], 2)
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
