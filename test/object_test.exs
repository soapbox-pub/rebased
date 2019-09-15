# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.ObjectTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  import Tesla.Mock
  alias Pleroma.Object
  alias Pleroma.Repo

  setup do
    mock(fn env -> apply(HttpRequestMock, :request, [env]) end)
    :ok
  end

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

      Cachex.put(:web_resp_cache, URI.parse(object.data["id"]).path, "cofe")

      Object.delete(cached_object)

      {:ok, nil} = Cachex.get(:object_cache, "object:#{object.data["id"]}")
      {:ok, nil} = Cachex.get(:web_resp_cache, URI.parse(object.data["id"]).path)

      cached_object = Object.get_cached_by_ap_id(object.data["id"])

      refute object == cached_object

      assert cached_object.data["type"] == "Tombstone"
    end
  end

  describe "normalizer" do
    test "fetches unknown objects by default" do
      %Object{} =
        object = Object.normalize("http://mastodon.example.org/@admin/99541947525187367")

      assert object.data["url"] == "http://mastodon.example.org/@admin/99541947525187367"
    end

    test "fetches unknown objects when fetch_remote is explicitly true" do
      %Object{} =
        object = Object.normalize("http://mastodon.example.org/@admin/99541947525187367", true)

      assert object.data["url"] == "http://mastodon.example.org/@admin/99541947525187367"
    end

    test "does not fetch unknown objects when fetch_remote is false" do
      assert is_nil(
               Object.normalize("http://mastodon.example.org/@admin/99541947525187367", false)
             )
    end
  end
end
