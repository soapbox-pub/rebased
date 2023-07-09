# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.LikeValidationTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.LikeValidator
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "likes" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{status: "uguu"})

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

    test "Add object actor from 'to' field if it doesn't owns the like", %{valid_like: valid_like} do
      user = insert(:user)

      object_actor = valid_like["actor"]

      valid_like =
        valid_like
        |> Map.put("actor", user.ap_id)
        |> Map.put("to", [])

      {:ok, object, _meta} = ObjectValidator.validate(valid_like, [])
      assert object_actor in object["to"]
    end

    test "Removes object actor from 'to' field if it owns the like", %{
      valid_like: valid_like,
      user: user
    } do
      valid_like =
        valid_like
        |> Map.put("to", [user.ap_id])

      {:ok, object, _meta} = ObjectValidator.validate(valid_like, [])
      refute user.ap_id in object["to"]
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
