# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.EctoType.ActivityPub.ObjectValidators.RecipientsTest do
  alias Pleroma.EctoType.ActivityPub.ObjectValidators.Recipients
  use Pleroma.DataCase, async: true

  test "it only keeps elements that are valid object ids" do
    list = ["https://lain.com/users/lain", "invalid"]

    assert {:ok, ["https://lain.com/users/lain"]} == Recipients.cast(list)
  end

  test "it works with a list" do
    list = ["https://lain.com/users/lain"]
    assert {:ok, list} == Recipients.cast(list)
  end

  test "it works with a list with whole objects" do
    list = ["https://lain.com/users/lain", %{"id" => "https://gensokyo.2hu/users/raymoo"}]
    resulting_list = ["https://gensokyo.2hu/users/raymoo", "https://lain.com/users/lain"]
    assert {:ok, resulting_list} == Recipients.cast(list)
  end

  test "it turns a single string into a list" do
    recipient = "https://lain.com/users/lain"

    assert {:ok, [recipient]} == Recipients.cast(recipient)
  end
end
