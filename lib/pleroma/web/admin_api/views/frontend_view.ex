# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.FrontendView do
  use Pleroma.Web, :view

  def render("index.json", %{frontends: frontends}) do
    render_many(frontends, __MODULE__, "show.json")
  end

  def render("show.json", %{frontend: frontend}) do
    %{
      name: frontend["name"],
      git: frontend["git"],
      build_url: frontend["build_url"],
      ref: frontend["ref"],
      installed: frontend["installed"]
    }
  end
end
