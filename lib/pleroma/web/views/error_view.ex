# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ErrorView do
  use Pleroma.Web, :view
  require Logger

  def render("404.json", _assigns) do
    %{errors: %{detail: "Page not found"}}
  end

  def render("500.json", assigns) do
    Logger.error("Internal server error: #{inspect(assigns[:reason])}")

    if Pleroma.Config.get(:env) != :prod do
      %{errors: %{detail: "Internal server error", reason: inspect(assigns[:reason])}}
    else
      %{errors: %{detail: "Internal server error"}}
    end
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.json", assigns)
  end
end
