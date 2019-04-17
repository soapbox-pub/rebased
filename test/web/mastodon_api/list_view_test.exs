# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ListViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.MastodonAPI.ListView

  test "Represent a list" do
    user = insert(:user)
    title = "mortal enemies"
    {:ok, list} = Pleroma.List.create(title, user)

    expected = %{
      id: to_string(list.id),
      title: title
    }

    assert expected == ListView.render("list.json", %{list: list})
  end
end
