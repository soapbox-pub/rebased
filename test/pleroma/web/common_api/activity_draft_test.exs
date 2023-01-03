# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.CommonAPI.ActivityDraftTest do
  alias Pleroma.Web.CommonAPI.ActivityDraft

  use Pleroma.DataCase

  import Pleroma.Factory

  describe "multilang processing" do
    setup do
      [user: insert(:user)]
    end

    test "content", %{user: user} do
      {:ok, draft} =
        ActivityDraft.create(user, %{
          status_map: %{"a" => "mew mew", "b" => "lol lol"},
          spoiler_text_map: %{"a" => "mew", "b" => "lol"}
        })

      assert %{
               "contentMap" => %{"a" => "mew mew", "b" => "lol lol"},
               "content" => content,
               "summaryMap" => %{"a" => "mew", "b" => "lol"},
               "summary" => summary
             } = draft.object

      assert is_binary(content)
      assert is_binary(summary)
    end
  end
end
