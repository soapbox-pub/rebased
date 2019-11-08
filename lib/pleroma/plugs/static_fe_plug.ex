# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Plugs.StaticFEPlug do
  import Plug.Conn
  alias Pleroma.Web.StaticFE.StaticFEController

  def init(options), do: options

  def call(conn, _) do
    if enabled?() and accepts_html?(conn) do
      conn
      |> StaticFEController.call(:show)
      |> halt()
    else
      conn
    end
  end

  defp enabled?, do: Pleroma.Config.get([:static_fe, :enabled], false)

  defp accepts_html?(conn) do
    conn |> get_req_header("accept") |> List.first() |> String.contains?("text/html")
  end
end
