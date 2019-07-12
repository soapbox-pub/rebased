# Pleroma: A lightweight social networking server
# Copyright © 2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoPlaceholderTextPolicyTest do
  use Pleroma.DataCase
  alias Pleroma.Web.ActivityPub.MRF.NoPlaceholderTextPolicy

  test "it clears content object" do
    message = %{
      "type" => "Create",
      "object" => %{"content" => ".", "attachment" => "image"}
    }

    assert {:ok, res} = NoPlaceholderTextPolicy.filter(message)
    assert res["object"]["content"] == ""

    message = put_in(message, ["object", "content"], "<p>.</p>")
    assert {:ok, res} = NoPlaceholderTextPolicy.filter(message)
    assert res["object"]["content"] == ""
  end

  @messages [
    %{
      "type" => "Create",
      "object" => %{"content" => "test", "attachment" => "image"}
    },
    %{"type" => "Create", "object" => %{"content" => "."}},
    %{"type" => "Create", "object" => %{"content" => "<p>.</p>"}}
  ]
  test "it skips filter" do
    Enum.each(@messages, fn message ->
      assert {:ok, res} = NoPlaceholderTextPolicy.filter(message)
      assert res == message
    end)
  end
end
