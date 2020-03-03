# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.ListView do
  use Pleroma.Web, :view
  alias Pleroma.Web.MastodonAPI.ListView

  def render("index.json", %{lists: lists} = opts) do
    render_many(lists, ListView, "show.json", opts)
  end

  def render("show.json", %{list: list}) do
    %{
      id: to_string(list.id),
      title: list.title
    }
  end
end
