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

      assert {:ok, _update, _} = ObjectValidator.validate(update, [])
    end
  end

  describe "update note" do
    test "converts object into Pleroma's format" do
      mastodon_tags = [
        %{
          "icon" => %{
            "mediaType" => "image/png",
            "type" => "Image",
            "url" => "https://somewhere.org/emoji/url/1.png"
          },
          "id" => "https://somewhere.org/emoji/1",
          "name" => ":some_emoji:",
          "type" => "Emoji",
          "updated" => "2021-04-07T11:00:00Z"
        }
      ]

      user = insert(:user)
      note = insert(:note, user: user)

      updated_note =
        note.data
        |> Map.put("content", "edited content")
        |> Map.put("tag", mastodon_tags)

      {:ok, update, _} = Builder.update(user, updated_note)

      assert {:ok, _update, meta} = ObjectValidator.validate(update, [])

      assert %{"emoji" => %{"some_emoji" => "https://somewhere.org/emoji/url/1.png"}} =
               meta[:object_data]
    end

    test "returns no object_data in meta for a local Update" do
      user = insert(:user)
      note = insert(:note, user: user)

      updated_note =
        note.data
        |> Map.put("content", "edited content")

      {:ok, update, _} = Builder.update(user, updated_note)

      assert {:ok, _update, meta} = ObjectValidator.validate(update, local: true)
      assert is_nil(meta[:object_data])
    end

    test "returns object_data in meta for a remote Update" do
      user = insert(:user)
      note = insert(:note, user: user)

      updated_note =
        note.data
        |> Map.put("content", "edited content")

      {:ok, update, _} = Builder.update(user, updated_note)

      assert {:ok, _update, meta} = ObjectValidator.validate(update, local: false)
      assert meta[:object_data]

      assert {:ok, _update, meta} = ObjectValidator.validate(update, [])
      assert meta[:object_data]
    end
  end
end
