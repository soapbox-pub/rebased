# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.UpdateHandlingTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator

  import Pleroma.Factory

  describe "updates" do
    setup do
      user = insert(:user)

      object = %{
        "id" => user.ap_id,
        "name" => "A new name",
        "summary" => "A new bio"
      }

      {:ok, valid_update, []} = Builder.update(user, object)

      %{user: user, valid_update: valid_update}
    end

    test "validates a basic object", %{valid_update: valid_update} do
      assert {:ok, _update, []} = ObjectValidator.validate(valid_update, [])
    end

    test "returns an error if the object can't be updated by the actor", %{
      valid_update: valid_update
    } do
      other_user = insert(:user, local: false)

      update =
        valid_update
        |> Map.put("actor", other_user.ap_id)

      assert {:error, _cng} = ObjectValidator.validate(update, [])
    end

    test "validates as long as the object is same-origin with the actor", %{
      valid_update: valid_update
    } do
      other_user = insert(:user)

      update =
        valid_update
        |> Map.put("actor", other_user.ap_id)

      assert {:ok, _update, []} = ObjectValidator.validate(update, [])
    end

    test "validates if the object is not of an Actor type" do
      note = insert(:note)
      updated_note = note.data |> Map.put("content", "edited content")
      other_user = insert(:user)

      {:ok, update, _} = Builder.update(other_user, updated_note)

      assert {:ok, _update, []} = ObjectValidator.validate(update, [])
    end
  end
end
