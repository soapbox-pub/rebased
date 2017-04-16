defmodule Pleroma.ObjectTest do
  use Pleroma.DataCase
  import Pleroma.Factory

  test "returns an object by it's AP id" do
    object = insert(:note)
    found_object = Pleroma.Object.get_by_ap_id(object.data["id"])

    assert object == found_object
  end
end
