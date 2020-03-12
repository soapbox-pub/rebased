# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.WebFinger.WebFingerController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.WebFinger

  plug(Pleroma.Plugs.SetFormatPlug)
  plug(Pleroma.Web.FederatingPlug)

  def host_meta(conn, _params) do
    xml = WebFinger.host_meta()

    conn
    |> put_resp_content_type("application/xrd+xml")
    |> send_resp(200, xml)
  end

  def webfinger(%{assigns: %{format: format}} = conn, %{"resource" => resource})
      when format in ["xml", "xrd+xml"] do
    with {:ok, response} <- WebFinger.webfinger(resource, "XML") do
      conn
      |> put_resp_content_type("application/xrd+xml")
      |> send_resp(200, response)
    else
      _e -> send_resp(conn, 404, "Couldn't find user")
    end
  end

  def webfinger(%{assigns: %{format: format}} = conn, %{"resource" => resource})
      when format in ["json", "jrd+json"] do
    with {:ok, response} <- WebFinger.webfinger(resource, "JSON") do
      json(conn, response)
    else
      _e ->
        conn
        |> put_status(404)
        |> json("Couldn't find user")
    end
  end

  def webfinger(conn, _params), do: send_resp(conn, 400, "Bad Request")
end
