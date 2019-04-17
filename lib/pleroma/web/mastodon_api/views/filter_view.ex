# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.FilterView do
  use Pleroma.Web, :view
  alias Pleroma.Web.CommonAPI.Utils
  alias Pleroma.Web.MastodonAPI.FilterView

  def render("filters.json", %{filters: filters} = opts) do
    render_many(filters, FilterView, "filter.json", opts)
  end

  def render("filter.json", %{filter: filter}) do
    expires_at =
      if filter.expires_at do
        Utils.to_masto_date(filter.expires_at)
      else
        nil
      end

    %{
      id: to_string(filter.filter_id),
      phrase: filter.phrase,
      context: filter.context,
      expires_at: expires_at,
      irreversible: filter.hide,
      whole_word: false
    }
  end
end
