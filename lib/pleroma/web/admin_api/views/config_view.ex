# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.AdminAPI.ConfigView do
  use Pleroma.Web, :view

  alias Pleroma.ConfigDB

  def render("index.json", %{configs: configs} = params) do
    %{
      configs: render_many(configs, __MODULE__, "show.json", as: :config),
      need_reboot: params[:need_reboot]
    }
  end

  def render("show.json", %{config: config}) do
    map = %{
      key: ConfigDB.to_json_types(config.key),
      group: ConfigDB.to_json_types(config.group),
      value: ConfigDB.to_json_types(config.value)
    }

    if config.db != [] do
      Map.put(map, :db, config.db)
    else
      map
    end
  end
end
