# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigView do
  use Pleroma.Web, :view

  def render("index.json", %{configs: configs}) do
    %{
      configs: render_many(configs, __MODULE__, "show.json", as: :config)
    }
  end

  def render("show.json", %{config: config}) do
    %{
      key: config.key,
      group: config.group,
      value: Pleroma.Web.AdminAPI.Config.from_binary_with_convert(config.value)
    }
  end
end
