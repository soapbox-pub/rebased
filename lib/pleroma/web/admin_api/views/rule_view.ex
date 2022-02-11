# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.RuleView do
  use Pleroma.Web, :view

  require Pleroma.Constants

  def render("index.json", %{rules: rules} = _opts) do
    render_many(rules, __MODULE__, "show.json")
  end

  def render("show.json", %{rule: rule} = _opts) do
    %{
      id: rule.id,
      priority: rule.priority,
      text: rule.text
    }
  end
end
