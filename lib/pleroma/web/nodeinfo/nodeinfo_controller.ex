# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.Nodeinfo.NodeinfoController do
  use Pleroma.Web, :controller

  alias Pleroma.Config
  alias Pleroma.Stats
  alias Pleroma.User
  alias Pleroma.Web
  alias Pleroma.Web.ActivityPub.MRF
  alias Pleroma.Web.Federator.Publisher

  def schemas(conn, _params) do
    response = %{
      links: [
        %{
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.0",
          href: Web.base_url() <> "/nodeinfo/2.0.json"
        },
        %{
          rel: "http://nodeinfo.diaspora.software/ns/schema/2.1",
          href: Web.base_url() <> "/nodeinfo/2.1.json"
        }
      ]
    }

    json(conn, response)
  end

  # returns a nodeinfo 2.0 map, since 2.1 just adds a repository field
  # under software.
  def raw_nodeinfo do
    stats = Stats.get_stats()

    quarantined = Config.get([:instance, :quarantined_instances], [])

    staff_accounts =
      User.all_superusers()
      |> Enum.map(fn u -> u.ap_id end)

    federation_response =
      if Config.get([:instance, :mrf_transparency]) do
        {:ok, data} = MRF.describe()

        data
        |> Map.merge(%{quarantined_instances: quarantined})
      else
        %{}
      end

    features =
      [
        "pleroma_api",
        "mastodon_api",
        "mastodon_api_streaming",
        "polls",
        "pleroma_explicit_addressing",
        "shareable_emoji_packs",
        if Config.get([:media_proxy, :enabled]) do
          "media_proxy"
        end,
        if Config.get([:gopher, :enabled]) do
          "gopher"
        end,
        if Config.get([:chat, :enabled]) do
          "chat"
        end,
        if Config.get([:suggestions, :enabled]) do
          "suggestions"
        end,
        if Config.get([:instance, :allow_relay]) do
          "relay"
        end,
        if Config.get([:instance, :safe_dm_mentions]) do
          "safe_dm_mentions"
        end
      ]
      |> Enum.filter(& &1)

    %{
      version: "2.0",
      software: %{
        name: Pleroma.Application.name() |> String.downcase(),
        version: Pleroma.Application.version()
      },
      protocols: Publisher.gather_nodeinfo_protocol_names(),
      services: %{
        inbound: [],
        outbound: []
      },
      openRegistrations: Config.get([:instance, :registrations_open]),
      usage: %{
        users: %{
          total: stats.user_count || 0
        },
        localPosts: stats.status_count || 0
      },
      metadata: %{
        nodeName: Config.get([:instance, :name]),
        nodeDescription: Config.get([:instance, :description]),
        private: !Config.get([:instance, :public], true),
        suggestions: %{
          enabled: Config.get([:suggestions, :enabled], false),
          thirdPartyEngine: Config.get([:suggestions, :third_party_engine], ""),
          timeout: Config.get([:suggestions, :timeout], 5000),
          limit: Config.get([:suggestions, :limit], 23),
          web: Config.get([:suggestions, :web], "")
        },
        staffAccounts: staff_accounts,
        federation: federation_response,
        pollLimits: Config.get([:instance, :poll_limits]),
        postFormats: Config.get([:instance, :allowed_post_formats]),
        uploadLimits: %{
          general: Config.get([:instance, :upload_limit]),
          avatar: Config.get([:instance, :avatar_upload_limit]),
          banner: Config.get([:instance, :banner_upload_limit]),
          background: Config.get([:instance, :background_upload_limit])
        },
        accountActivationRequired: Config.get([:instance, :account_activation_required], false),
        invitesEnabled: Config.get([:instance, :invites_enabled], false),
        mailerEnabled: Config.get([Pleroma.Emails.Mailer, :enabled], false),
        features: features,
        restrictedNicknames: Config.get([Pleroma.User, :restricted_nicknames]),
        skipThreadContainment: Config.get([:instance, :skip_thread_containment], false)
      }
    }
  end

  # Schema definition: https://github.com/jhass/nodeinfo/blob/master/schemas/2.0/schema.json
  # and https://github.com/jhass/nodeinfo/blob/master/schemas/2.1/schema.json
  def nodeinfo(conn, %{"version" => "2.0"}) do
    conn
    |> put_resp_header(
      "content-type",
      "application/json; profile=http://nodeinfo.diaspora.software/ns/schema/2.0#; charset=utf-8"
    )
    |> json(raw_nodeinfo())
  end

  def nodeinfo(conn, %{"version" => "2.1"}) do
    raw_response = raw_nodeinfo()

    updated_software =
      raw_response
      |> Map.get(:software)
      |> Map.put(:repository, Pleroma.Application.repository())

    response =
      raw_response
      |> Map.put(:software, updated_software)
      |> Map.put(:version, "2.1")

    conn
    |> put_resp_header(
      "content-type",
      "application/json; profile=http://nodeinfo.diaspora.software/ns/schema/2.1#; charset=utf-8"
    )
    |> json(response)
  end

  def nodeinfo(conn, _) do
    render_error(conn, :not_found, "Nodeinfo schema version not handled")
  end
end
