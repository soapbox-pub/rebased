defmodule Pleroma.Web.Nodeinfo.NodeinfoController do
  use Pleroma.Web, :controller

  alias Pleroma.Stats
  alias Pleroma.Web

  @instance Application.get_env(:pleroma, :instance)

  def schemas(conn, _params) do
    response = %{
      links: [
        %{
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
          href: Web.base_url() <> "/nodeinfo/2.0.json"
        }
      ]
    }

    json(conn, response)
  end

  # Schema definition: https://github.com/jhass/nodeinfo/blob/master/schemas/2.0/schema.json
  def nodeinfo(conn, %{"version" => "2.0"}) do
    stats = Stats.get_stats()

    response = %{
      version: "2.0",
      software: %{
        name: "pleroma",
        version: Keyword.get(@instance, :version)
      },
      protocols: ["ostatus", "activitypub"],
      services: %{
        inbound: [],
        outbound: []
      },
      openRegistrations: Keyword.get(@instance, :registrations_open),
      usage: %{
        users: %{
          total: stats.user_count || 0
        },
        localPosts: stats.status_count || 0
      },
      metadata: %{
        nodeName: Keyword.get(@instance, :name)
      }
    }

    conn
    |> put_resp_header(
      "content-type",
      "application/json; profile=http://nodeinfo.diaspora.software/ns/schema/2.0#; charset=utf-8"
    )
    |> json(response)
  end

  def nodeinfo(conn, _) do
    conn
    |> put_status(404)
    |> json(%{error: "Nodeinfo schema version not handled"})
  end
end
