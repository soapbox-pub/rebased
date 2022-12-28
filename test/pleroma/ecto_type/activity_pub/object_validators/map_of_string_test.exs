# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.MapOfStringTest do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators.MapOfString
  use Pleroma.DataCase, async: true

  test "it validates" do
    data = %{
      "en-US" => "mew mew",
      "en-GB" => "meow meow"
    }

    assert {:ok, ^data} = MapOfString.cast(data)
  end

  test "it validates empty strings" do
    data = %{
      "en-US" => "mew mew",
      "en-GB" => ""
    }

    assert {:ok, ^data} = MapOfString.cast(data)
  end

  test "it ignores non-strings within the map" do
    data = %{
      "en-US" => "mew mew",
      "en-GB" => 123
    }

    assert {:ok, validated_data} = MapOfString.cast(data)

    assert validated_data == %{"en-US" => "mew mew"}
  end

  test "it complains with non-map data" do
    assert :error = MapOfString.cast("mew")
    assert :error = MapOfString.cast(["mew"])
    assert :error = MapOfString.cast([%{"en-US" => "mew"}])
  end
end
