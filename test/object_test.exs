# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ObjectTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.{Repo, Object}

  test "returns an object by it's AP id" do
    object = insert(:note)
    found_object = Object.get_by_ap_id(object.data["id"])

    assert object == found_object
  end

  describe "generic changeset" do
    test "it ensures uniqueness of the id" do
      object = insert(:note)
      cs = Object.change(%Object{}, %{data: %{id: object.data["id"]}})
      assert cs.valid?

      {:error, _result} = Repo.insert(cs)
    end
  end

  describe "deletion function" do
    test "deletes an object" do
      object = insert(:note)
      found_object = Object.get_by_ap_id(object.data["id"])

      assert object == found_object

      Object.delete(found_object)

      found_object = Object.get_by_ap_id(object.data["id"])

      refute object == found_object

      assert found_object.data["type"] == "Tombstone"
    end

    test "ensures cache is cleared for the object" do
      object = insert(:note)
      cached_object = Object.get_cached_by_ap_id(object.data["id"])

      assert object == cached_object

      Object.delete(cached_object)

      {:ok, nil} = Cachex.get(:object_cache, "object:#{object.data["id"]}")

      cached_object = Object.get_cached_by_ap_id(object.data["id"])

      refute object == cached_object

      assert cached_object.data["type"] == "Tombstone"
    end
  end

  describe "insert_or_get" do
    test "inserting the same object twice (by id) just returns the original object" do
      data = %{data: %{"id" => Ecto.UUID.generate()}}
      cng = Object.change(%Object{}, data)
      {:ok, object} = Object.insert_or_get(cng)
      {:ok, second_object} = Object.insert_or_get(cng)

      Cachex.clear(:object_cache)
      {:ok, third_object} = Object.insert_or_get(cng)

      assert object == second_object
      assert object == third_object
    end
  end

  describe "create" do
    test "inserts an object for a given data set" do
      data = %{"id" => Ecto.UUID.generate()}

      {:ok, object} = Object.create(data)
      assert object.data["id"] == data["id"]

      # Works when doing it twice.
      {:ok, object} = Object.create(data)
      assert object.data["id"] == data["id"]
    end
  end
end
