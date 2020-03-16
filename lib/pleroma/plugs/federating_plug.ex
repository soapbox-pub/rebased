# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.FederatingPlug do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    if federating?() do
      conn
    else
      fail(conn)
    end
  end

  def federating?, do: Pleroma.Config.get([:instance, :federating])

  defp fail(conn) do
    conn
    |> put_status(404)
    |> Phoenix.Controller.put_view(Pleroma.Web.ErrorView)
    |> Phoenix.Controller.render("404.json")
    |> halt()
  end
end
