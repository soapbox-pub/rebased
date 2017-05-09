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

      {:error, result} = Repo.insert(cs)
    end
  end
end
