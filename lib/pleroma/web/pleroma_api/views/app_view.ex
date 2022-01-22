# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.PleromaAPI.AppView do
  use Pleroma.Web, :view

  def render("index.json", %{apps: apps}) do
    render_many(apps, Pleroma.Web.MastodonAPI.AppView, "show.json")
  end
end
