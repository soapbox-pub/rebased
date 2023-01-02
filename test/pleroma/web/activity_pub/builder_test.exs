# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.BuilderTest do
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.CommonAPI.ActivityDraft
  use Pleroma.DataCase

  import Pleroma.Factory

  describe "note/1" do
    test "returns note data" do
      user = insert(:user)
      note = insert(:note)
      user2 = insert(:user)
      user3 = insert(:user)

      draft = %ActivityDraft{
        user: user,
        to: [user2.ap_id],
        context: "2hu",
        content_html: "<h1>This is :moominmamma: note</h1>",
        in_reply_to: note.id,
        tags: [name: "jimm"],
        summary: "test summary",
        cc: [user3.ap_id],
        extra: %{"custom_tag" => "test"}
      }

      expected = %{
        "actor" => user.ap_id,
        "attachment" => [],
        "cc" => [user3.ap_id],
        "content" => "<h1>This is :moominmamma: note</h1>",
        "context" => "2hu",
        "sensitive" => false,
        "summary" => "test summary",
        "tag" => ["jimm"],
        "to" => [user2.ap_id],
        "type" => "Note",
        "custom_tag" => "test"
      }

      assert {:ok, ^expected, []} = Builder.note(draft)
    end
  end
end
