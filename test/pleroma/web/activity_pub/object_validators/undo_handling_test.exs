# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UndoHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "Undos" do
    setup do
      user = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{status: "uguu"})
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
end
