# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.StaticFEPlug do
  def init(options), do: options

  def accepts_html?({"accept", a}), do: String.contains?(a, "text/html")
  def accepts_html?({_, _}), do: false

  def call(conn, _) do
    with true <- Pleroma.Config.get([:instance, :static_fe], false),
         {_, _} <- Enum.find(conn.req_headers, &accepts_html?/1) do
      Pleroma.Web.StaticFE.StaticFEController.call(conn, :show)
    else
      _ -> conn
    end
  end
end
