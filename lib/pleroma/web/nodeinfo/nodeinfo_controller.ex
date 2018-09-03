defmodule Pleroma.Web.Nodeinfo.NodeinfoController do
  use Pleroma.Web, :controller

  alias Pleroma.Stats
  alias Pleroma.Web
  alias Pleroma.{User, Repo}

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
    instance = Application.get_env(:pleroma, :instance)
    media_proxy = Application.get_env(:pleroma, :media_proxy)
    suggestions = Application.get_env(:pleroma, :suggestions)
    stats = Stats.get_stats()

    staff_accounts =
      User.moderator_user_query()
      |> Repo.all()
      |> Enum.map(fn u -> u.ap_id end)

    response = %{
      version: "2.0",
      software: %{
        name: "pleroma",
        version: Keyword.get(instance, :version)
      },
      protocols: ["ostatus", "activitypub"],
      services: %{
        inbound: [],
        outbound: []
      },
      openRegistrations: Keyword.get(instance, :registrations_open),
      usage: %{
        users: %{
          total: stats.user_count || 0
        },
        localPosts: stats.status_count || 0
      },
      metadata: %{
        nodeName: Keyword.get(instance, :name),
        nodeDescription: Keyword.get(instance, :description),
        mediaProxy: Keyword.get(media_proxy, :enabled),
        private: !Keyword.get(instance, :public, true),
        suggestions: %{
          enabled: Keyword.get(suggestions, :enabled, false),
          thirdPartyEngine: Keyword.get(suggestions, :third_party_engine, ""),
          timeout: Keyword.get(suggestions, :timeout, 5000),
          web: Keyword.get(suggestions, :web, "")
        },
        staffAccounts: staff_accounts
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
