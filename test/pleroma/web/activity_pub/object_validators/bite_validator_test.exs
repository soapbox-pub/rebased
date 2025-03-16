# Pleroma: A lightweight social networking server
# Copyright © 2017-2024 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.BiteValidationTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.ObjectValidators.BiteValidator
  alias Pleroma.Web.ActivityPub.Utils
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "bites" do
    setup do
      biting = insert(:user)
      bitten = insert(:user)

      valid_bite = %{
        "id" => Utils.generate_activity_id(),
        "type" => "Bite",
        "actor" => biting.ap_id,
        "target" => bitten.ap_id,
        "to" => [bitten.ap_id]
      }

      %{valid_bite: valid_bite, biting: biting, bitten: bitten}
    end

    test "returns ok when called in the ObjectValidator", %{valid_bite: valid_bite} do
      {:ok, object, _meta} = ObjectValidator.validate(valid_bite, [])

      assert "id" in Map.keys(object)
    end

    test "is valid for a valid object", %{valid_bite: valid_bite} do
      assert BiteValidator.cast_and_validate(valid_bite).valid?
    end

    test "is valid when biting an object", %{valid_bite: valid_bite, bitten: bitten} do
      {:ok, activity} = CommonAPI.post(bitten, %{status: "uguu"})

      valid_bite =
        valid_bite
        |> Map.put("target", activity.data["object"])

      assert BiteValidator.cast_and_validate(valid_bite).valid?
    end
  end
end
