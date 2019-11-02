# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.StaticFEPlug do
  def init(options), do: options

  def call(conn, _) do
    case Pleroma.Config.get([:instance, :static_fe], false) do
      true -> Pleroma.Web.StaticFE.StaticFEController.call(conn, :show)
      _ -> conn
    end
  end
end
