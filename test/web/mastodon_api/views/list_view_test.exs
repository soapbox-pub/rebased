# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ListViewTest do
  use Pleroma.DataCase
  import Pleroma.Factory
  alias Pleroma.Web.MastodonAPI.ListView

  test "show" do
    user = insert(:user)
    title = "mortal enemies"
    {:ok, list} = Pleroma.List.create(title, user)

    expected = %{
      id: to_string(list.id),
      title: title
    }

    assert expected == ListView.render("show.json", %{list: list})
  end

  test "index" do
    user = insert(:user)

    {:ok, list} = Pleroma.List.create("my list", user)
    {:ok, list2} = Pleroma.List.create("cofe", user)

    assert [%{id: _, title: "my list"}, %{id: _, title: "cofe"}] =
             ListView.render("index.json", lists: [list, list2])
  end
end
