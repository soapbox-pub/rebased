defmodule Pleroma.Web.ObjectValidators.Types.ObjectIDTest do
  alias Pleroma.Web.ActivityPub.ObjectValidators.Types.ObjectID
  use Pleroma.DataCase

  @uris [
    "http://lain.com/users/lain",
    "http://lain.com",
    "https://lain.com/object/1"
  ]

  @non_uris [
    "https://",
    "rin"
  ]

  test "it rejects integers" do
    assert :error == ObjectID.cast(1)
  end

  test "it accepts http uris" do
    Enum.each(@uris, fn uri ->
      assert {:ok, uri} == ObjectID.cast(uri)
    end)
  end

  test "it accepts an object with a nested uri id" do
    Enum.each(@uris, fn uri ->
      assert {:ok, uri} == ObjectID.cast(%{"id" => uri})
    end)
  end

  test "it rejects non-uri strings" do
    Enum.each(@non_uris, fn non_uri ->
      assert :error == ObjectID.cast(non_uri)
      assert :error == ObjectID.cast(%{"id" => non_uri})
    end)
  end
end
