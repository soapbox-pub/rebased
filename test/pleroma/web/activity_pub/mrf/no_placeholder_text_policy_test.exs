# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.MRF.NoPlaceholderTextPolicyTest do
  use Pleroma.DataCase, async: true
  alias Pleroma.Web.ActivityPub.MRF
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

  test "history-aware" do
    message = %{
      "type" => "Create",
      "object" => %{
        "content" => ".",
        "attachment" => "image",
        "formerRepresentations" => %{
          "orderedItems" => [%{"content" => ".", "attachment" => "image"}]
        }
      }
    }

    assert {:ok, res} = MRF.filter_one(NoPlaceholderTextPolicy, message)

    assert %{
             "content" => "",
             "formerRepresentations" => %{"orderedItems" => [%{"content" => ""}]}
           } = res["object"]
  end

  test "works with Updates" do
    message = %{
      "type" => "Update",
      "object" => %{
        "content" => ".",
        "attachment" => "image",
        "formerRepresentations" => %{
          "orderedItems" => [%{"content" => ".", "attachment" => "image"}]
        }
      }
    }

    assert {:ok, res} = MRF.filter_one(NoPlaceholderTextPolicy, message)

    assert %{
             "content" => "",
             "formerRepresentations" => %{"orderedItems" => [%{"content" => ""}]}
           } = res["object"]
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
