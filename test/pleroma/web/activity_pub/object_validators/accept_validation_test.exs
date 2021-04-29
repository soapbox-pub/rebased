# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AcceptValidationTest do
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

    {:ok, accept_data, _} = Builder.accept(followed, follow_activity)

    %{accept_data: accept_data, followed: followed}
  end

  test "it validates a basic 'accept'", %{accept_data: accept_data} do
    assert {:ok, _, _} = ObjectValidator.validate(accept_data, [])
  end

  test "it fails when the actor doesn't exist", %{accept_data: accept_data} do
    accept_data =
      accept_data
      |> Map.put("actor", "https://gensokyo.2hu/users/raymoo")

    assert {:error, _} = ObjectValidator.validate(accept_data, [])
  end

  test "it fails when the accepted activity doesn't exist", %{accept_data: accept_data} do
    accept_data =
      accept_data
      |> Map.put("object", "https://gensokyo.2hu/users/raymoo/follows/1")

    assert {:error, _} = ObjectValidator.validate(accept_data, [])
  end

  test "for an accepted follow, it only validates if the actor of the accept is the followed actor",
       %{accept_data: accept_data} do
    stranger = insert(:user)

    accept_data =
      accept_data
      |> Map.put("actor", stranger.ap_id)

    assert {:error, _} = ObjectValidator.validate(accept_data, [])
  end
end
