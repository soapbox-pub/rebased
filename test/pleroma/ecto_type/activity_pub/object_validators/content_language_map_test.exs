# Pleroma: A lightweight social networking server
# Copyright © 2017-2023 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.ContentLanguageMapTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.EctoType.ActivityPub.ObjectValidators.ContentLanguageMap

  test "it validates" do
    data = %{
      "en-US" => "mew mew",
      "en-GB" => "meow meow"
    }

    assert {:ok, ^data} = ContentLanguageMap.cast(data)
  end

  test "it validates empty strings" do
    data = %{
      "en-US" => "mew mew",
      "en-GB" => ""
    }

    assert {:ok, ^data} = ContentLanguageMap.cast(data)
  end

  test "it ignores non-strings within the map" do
    data = %{
      "en-US" => "mew mew",
      "en-GB" => 123
    }

    assert {:ok, validated_data} = ContentLanguageMap.cast(data)

    assert validated_data == %{"en-US" => "mew mew"}
  end

  test "it ignores bad locale codes" do
    data = %{
      "en-US" => "mew mew",
      "en_GB" => "meow meow",
      "en<<#@!$#!@%!GB" => "meow meow"
    }

    assert {:ok, validated_data} = ContentLanguageMap.cast(data)

    assert validated_data == %{"en-US" => "mew mew"}
  end

  test "it complains with non-map data" do
    assert :error = ContentLanguageMap.cast("mew")
    assert :error = ContentLanguageMap.cast(["mew"])
    assert :error = ContentLanguageMap.cast([%{"en-US" => "mew"}])
  end
end
