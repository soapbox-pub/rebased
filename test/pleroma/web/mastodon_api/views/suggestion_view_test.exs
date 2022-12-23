# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.SuggestionViewTest do
  use Pleroma.DataCase, async: true
  import Pleroma.Factory
  alias Pleroma.Web.MastodonAPI.SuggestionView, as: View

  test "show.json" do
    user = insert(:user, is_suggested: true)
    json = View.render("show.json", %{user: user, source: :staff, skip_visibility_check: true})

    assert json.source == :staff
    assert json.account.id == user.id
  end

  test "index.json" do
    user1 = insert(:user, is_suggested: true)
    user2 = insert(:user, is_suggested: true)
    user3 = insert(:user, is_suggested: true)

    [suggestion1, suggestion2, suggestion3] =
      View.render("index.json", %{
        users: [user1, user2, user3],
        source: :staff,
        skip_visibility_check: true
      })

    assert suggestion1.source == :staff
    assert suggestion2.account.id == user2.id
    assert suggestion3.account.url == user3.ap_id
  end
end
