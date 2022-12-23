# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AnnounceValidationTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Object
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.ObjectValidator
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "announces" do
    setup do
      user = insert(:user)
      announcer = insert(:user)
      {:ok, post_activity} = CommonAPI.post(user, %{status: "uguu"})

      object = Object.normalize(post_activity, fetch: false)
      {:ok, valid_announce, []} = Builder.announce(announcer, object)

      %{
        valid_announce: valid_announce,
        user: user,
        post_activity: post_activity,
        announcer: announcer
      }
    end

    test "returns ok for a valid announce", %{valid_announce: valid_announce} do
      assert {:ok, _object, _meta} = ObjectValidator.validate(valid_announce, [])
    end

    test "keeps announced object context", %{valid_announce: valid_announce} do
      assert %Object{data: %{"context" => object_context}} =
               Object.get_cached_by_ap_id(valid_announce["object"])

      {:ok, %{"context" => context}, _} =
        valid_announce
        |> Map.put("context", "https://example.org/invalid_context_id")
        |> ObjectValidator.validate([])

      assert context == object_context
    end

    test "returns an error if the object can't be found", %{valid_announce: valid_announce} do
      without_object =
        valid_announce
        |> Map.delete("object")

      {:error, cng} = ObjectValidator.validate(without_object, [])

      assert {:object, {"can't be blank", [validation: :required]}} in cng.errors

      nonexisting_object =
        valid_announce
        |> Map.put("object", "https://gensokyo.2hu/objects/99999999")

      {:error, cng} = ObjectValidator.validate(nonexisting_object, [])

      assert {:object, {"can't find object", []}} in cng.errors
    end

    test "returns an error if the actor already announced the object", %{
      valid_announce: valid_announce,
      announcer: announcer,
      post_activity: post_activity
    } do
      _announce = CommonAPI.repeat(post_activity.id, announcer)

      {:error, cng} = ObjectValidator.validate(valid_announce, [])

      assert {:actor, {"already announced this object", []}} in cng.errors
      assert {:object, {"already announced by this actor", []}} in cng.errors
    end

    test "returns an error if the actor can't announce the object", %{
      announcer: announcer,
      user: user
    } do
      {:ok, post_activity} =
        CommonAPI.post(user, %{status: "a secret post", visibility: "private"})

      object = Object.normalize(post_activity, fetch: false)

      # Another user can't announce it
      {:ok, announce, []} = Builder.announce(announcer, object, public: false)

      {:error, cng} = ObjectValidator.validate(announce, [])

      assert {:actor, {"can not announce this object", []}} in cng.errors

      # The actor of the object can announce it
      {:ok, announce, []} = Builder.announce(user, object, public: false)

      assert {:ok, _, _} = ObjectValidator.validate(announce, [])

      # The actor of the object can not announce it publicly
      {:ok, announce, []} = Builder.announce(user, object, public: true)

      {:error, cng} = ObjectValidator.validate(announce, [])

      assert {:actor, {"can not announce this object publicly", []}} in cng.errors
    end
  end
end
