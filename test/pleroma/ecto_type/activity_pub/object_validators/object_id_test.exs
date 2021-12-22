# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.ObjectIDTest do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators.ObjectID
  use Pleroma.DataCase, async: true

  @uris [
    "http://lain.com/users/lain",
    "http://lain.com",
    "https://lain.com/object/1"
  ]

  @non_uris [
    "https://",
    "rin",
    1,
    :x,
    %{"1" => 2}
  ]

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
