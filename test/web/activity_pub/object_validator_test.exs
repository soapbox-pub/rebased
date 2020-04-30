defmodule Pleroma.Web.ActivityPub.ObjectValidatorTest do
  use Pleroma.DataCase

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "deletes" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{"status" => "cancel me daddy"})

      {:ok, valid_post_delete, _} = Builder.delete(user, post_activity.data["object"])
      {:ok, valid_user_delete, _} = Builder.delete(user, user.ap_id)

      %{user: user, valid_post_delete: valid_post_delete, valid_user_delete: valid_user_delete}
    end

    test "it is valid for a post deletion", %{valid_post_delete: valid_post_delete} do
      assert match?({:ok, _, _}, ObjectValidator.validate(valid_post_delete, []))
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
      valid_other_actor =
        valid_post_delete
        |> Map.put("actor", valid_post_delete["actor"] <> "1")

      assert match?({:ok, _, _}, ObjectValidator.validate(valid_other_actor, []))

      invalid_other_actor =
        valid_post_delete
        |> Map.put("actor", "https://gensokyo.2hu/users/raymoo")

      {:error, cng} = ObjectValidator.validate(invalid_other_actor, [])

      assert {:actor, {"is not allowed to delete object", []}} in cng.errors
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
