defmodule Pleroma.Web.ActivityPub.ObjectValidatorTest do
  use Pleroma.DataCase

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "EmojiReacts" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{"status" => "uguu"})

      object = Pleroma.Object.get_by_ap_id(post_activity.data["object"])

      {:ok, valid_emoji_react, []} = Builder.emoji_react(user, object, "👌")

      %{user: user, post_activity: post_activity, valid_emoji_react: valid_emoji_react}
    end

    test "it validates a valid EmojiReact", %{valid_emoji_react: valid_emoji_react} do
      assert {:ok, _, _} = ObjectValidator.validate(valid_emoji_react, [])
    end

    test "it is not valid without a 'content' field", %{valid_emoji_react: valid_emoji_react} do
      without_content =
        valid_emoji_react
        |> Map.delete("content")

      {:error, cng} = ObjectValidator.validate(without_content, [])

      refute cng.valid?
      assert {:content, {"can't be blank", [validation: :required]}} in cng.errors
    end

    test "it is not valid with a non-emoji content field", %{valid_emoji_react: valid_emoji_react} do
      without_emoji_content =
        valid_emoji_react
        |> Map.put("content", "x")

      {:error, cng} = ObjectValidator.validate(without_emoji_content, [])

      refute cng.valid?

      assert {:content, {"must be a single character emoji", []}} in cng.errors
    end
  end

  describe "Undos" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{"status" => "uguu"})
      {:ok, like} = CommonAPI.favorite(user, post_activity.id)
      {:ok, valid_like_undo, []} = Builder.undo(user, like)

      %{user: user, like: like, valid_like_undo: valid_like_undo}
    end

    test "it validates a basic like undo", %{valid_like_undo: valid_like_undo} do
      assert {:ok, _, _} = ObjectValidator.validate(valid_like_undo, [])
    end

    test "it does not validate if the actor of the undo is not the actor of the object", %{
      valid_like_undo: valid_like_undo
    } do
      other_user = insert(:user, ap_id: "https://gensokyo.2hu/users/raymoo")

      bad_actor =
        valid_like_undo
        |> Map.put("actor", other_user.ap_id)

      {:error, cng} = ObjectValidator.validate(bad_actor, [])

      assert {:actor, {"not the same as object actor", []}} in cng.errors
    end

    test "it does not validate if the object is missing", %{valid_like_undo: valid_like_undo} do
      missing_object =
        valid_like_undo
        |> Map.put("object", "https://gensokyo.2hu/objects/1")

      {:error, cng} = ObjectValidator.validate(missing_object, [])

      assert {:object, {"can't find object", []}} in cng.errors
      assert length(cng.errors) == 1
    end
  end

  describe "deletes" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{"status" => "cancel me daddy"})

      {:ok, valid_post_delete, _} = Builder.delete(user, post_activity.data["object"])
      {:ok, valid_user_delete, _} = Builder.delete(user, user.ap_id)

      %{user: user, valid_post_delete: valid_post_delete, valid_user_delete: valid_user_delete}
    end

    test "it is valid for a post deletion", %{valid_post_delete: valid_post_delete} do
      {:ok, valid_post_delete, _} = ObjectValidator.validate(valid_post_delete, [])

      assert valid_post_delete["deleted_activity_id"]
    end

    test "it is invalid if the object isn't in a list of certain types", %{
      valid_post_delete: valid_post_delete
    } do
      object = Object.get_by_ap_id(valid_post_delete["object"])

      data =
        object.data
        |> Map.put("type", "Like")

      {:ok, _object} =
        object
        |> Ecto.Changeset.change(%{data: data})
        |> Object.update_and_set_cache()

      {:error, cng} = ObjectValidator.validate(valid_post_delete, [])
      assert {:object, {"object not in allowed types", []}} in cng.errors
    end

    test "it is valid for a user deletion", %{valid_user_delete: valid_user_delete} do
      assert match?({:ok, _, _}, ObjectValidator.validate(valid_user_delete, []))
    end

    test "it's invalid if the id is missing", %{valid_post_delete: valid_post_delete} do
      no_id =
        valid_post_delete
        |> Map.delete("id")

      {:error, cng} = ObjectValidator.validate(no_id, [])

      assert {:id, {"can't be blank", [validation: :required]}} in cng.errors
    end

    test "it's invalid if the object doesn't exist", %{valid_post_delete: valid_post_delete} do
      missing_object =
        valid_post_delete
        |> Map.put("object", "http://does.not/exist")

      {:error, cng} = ObjectValidator.validate(missing_object, [])

      assert {:object, {"can't find object", []}} in cng.errors
    end

    test "it's invalid if the actor of the object and the actor of delete are from different domains",
         %{valid_post_delete: valid_post_delete} do
      valid_user = insert(:user)

      valid_other_actor =
        valid_post_delete
        |> Map.put("actor", valid_user.ap_id)

      assert match?({:ok, _, _}, ObjectValidator.validate(valid_other_actor, []))

      invalid_other_actor =
        valid_post_delete
        |> Map.put("actor", "https://gensokyo.2hu/users/raymoo")

      {:error, cng} = ObjectValidator.validate(invalid_other_actor, [])

      assert {:actor, {"is not allowed to delete object", []}} in cng.errors
    end

    test "it's valid if the actor of the object is a local superuser",
         %{valid_post_delete: valid_post_delete} do
      user =
        insert(:user, local: true, is_moderator: true, ap_id: "https://gensokyo.2hu/users/raymoo")

      valid_other_actor =
        valid_post_delete
        |> Map.put("actor", user.ap_id)

      {:ok, _, meta} = ObjectValidator.validate(valid_other_actor, [])
      assert meta[:do_not_federate]
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
