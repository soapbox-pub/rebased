# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.RejectValidationTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.ActivityPub.Pipeline

  import Pleroma.Factory

  setup do
    follower = insert(:user)
    followed = insert(:user, local: false)

    {:ok, follow_data, _} = Builder.follow(follower, followed)
    {:ok, follow_activity, _} = Pipeline.common_pipeline(follow_data, local: true)

    {:ok, reject_data, _} = Builder.reject(followed, follow_activity)

    %{reject_data: reject_data, followed: followed}
  end

  test "it validates a basic 'reject'", %{reject_data: reject_data} do
    assert {:ok, _, _} = ObjectValidator.validate(reject_data, [])
  end

  test "it fails when the actor doesn't exist", %{reject_data: reject_data} do
    reject_data =
      reject_data
      |> Map.put("actor", "https://gensokyo.2hu/users/raymoo")

    assert {:error, _} = ObjectValidator.validate(reject_data, [])
  end

  test "it fails when the rejected activity doesn't exist", %{reject_data: reject_data} do
    reject_data =
      reject_data
      |> Map.put("object", "https://gensokyo.2hu/users/raymoo/follows/1")

    assert {:error, _} = ObjectValidator.validate(reject_data, [])
  end

  test "for an rejected follow, it only validates if the actor of the reject is the followed actor",
       %{reject_data: reject_data} do
    stranger = insert(:user)

    reject_data =
      reject_data
      |> Map.put("actor", stranger.ap_id)

    assert {:error, _} = ObjectValidator.validate(reject_data, [])
  end
end
