defmodule Pleroma.Web.Nodeinfo.NodeinfoController do
  use Pleroma.Web, :controller

  alias Pleroma.Stats
  alias Pleroma.Web
  alias Pleroma.{User, Repo}
  alias Pleroma.Web.ActivityPub.MRF

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
    chat = Application.get_env(:pleroma, :chat)
    gopher = Application.get_env(:pleroma, :gopher)
    stats = Stats.get_stats()

    mrf_simple =
      Application.get_env(:pleroma, :mrf_simple)
      |> Enum.into(%{})

    mrf_policies =
      MRF.get_policies()
      |> Enum.map(fn policy -> to_string(policy) |> String.split(".") |> List.last() end)

    quarantined = Keyword.get(instance, :quarantined_instances)

    quarantined =
      if is_list(quarantined) do
        quarantined
      else
        []
      end

    staff_accounts =
      User.moderator_user_query()
      |> Repo.all()
      |> Enum.map(fn u -> u.ap_id end)

    mrf_transparency = Keyword.get(instance, :mrf_transparency)

    federation_response =
      if mrf_transparency do
        %{
          mrf_policies: mrf_policies,
          mrf_simple: mrf_simple,
          quarantined_instances: quarantined
        }
      else
        %{}
      end

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
          limit: Keyword.get(suggestions, :limit, 23),
          web: Keyword.get(suggestions, :web, "")
        },
        staffAccounts: staff_accounts,
        chat: Keyword.get(chat, :enabled),
        gopher: Keyword.get(gopher, :enabled),
        federation: federation_response,
        postFormats: Keyword.get(instance, :allowed_post_formats)
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
