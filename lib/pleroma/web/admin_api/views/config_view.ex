# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigView do
  use Pleroma.Web, :view

  def render("index.json", %{configs: configs} = params) do
    map = %{
      configs: render_many(configs, __MODULE__, "show.json", as: :config)
    }

    if params[:need_reboot] do
      Map.put(map, :need_reboot, true)
    else
      map
    end
  end

  def render("show.json", %{config: config}) do
    map = %{
      key: config.key,
      group: config.group,
      value: Pleroma.ConfigDB.from_binary_with_convert(config.value)
    }

    if config.db != [] do
      Map.put(map, :db, config.db)
    else
      map
    end
  end
end
