# Pleroma: A lightweight social networking server
# Copyright © 2017-2022 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Nodeinfo.NodeinfoController do
  use Pleroma.Web, :controller

  alias Pleroma.Web.Endpoint
  alias Pleroma.Web.Nodeinfo.Nodeinfo

  def schemas(conn, _params) do
    response = %{
      links: [
        %{
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
          href: Endpoint.url() <> "/nodeinfo/2.0.json"
        },
        %{
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.1",
          href: Endpoint.url() <> "/nodeinfo/2.1.json"
        }
      ]
    }

    json(conn, response)
  end

  # Schema definition: https://github.com/jhass/nodeinfo/blob/master/schemas/2.0/schema.json
  # and https://github.com/jhass/nodeinfo/blob/master/schemas/2.1/schema.json
  def nodeinfo(conn, %{"version" => version}) do
    case Nodeinfo.get_nodeinfo(version) do
      {:error, :missing} ->
        render_error(conn, :not_found, "Nodeinfo schema version not handled")

      node_info ->
        conn
        |> put_resp_header(
          "content-type",
          "application/json; profile=http://nodeinfo.diaspora.software/ns/schema/2.0#; charset=utf-8"
        )
        |> json(node_info)
    end
  end
end
