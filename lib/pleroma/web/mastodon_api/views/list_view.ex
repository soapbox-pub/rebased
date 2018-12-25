# Pleroma: A lightweight social networking server
# Copyright © 2017-2018 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ListView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.ListView

  def render("lists.json", %{lists: lists} = opts) do
    render_many(lists, ListView, "list.json", opts)
  end

  def render("list.json", %{list: list}) do
    %{
      id: to_string(list.id),
      title: list.title
    }
  end
end
