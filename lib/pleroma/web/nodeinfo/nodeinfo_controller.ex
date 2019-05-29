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
    instance = Application.get_env(:pleroma, :instance)
    media_proxy = Application.get_env(:pleroma, :media_proxy)
    suggestions = Application.get_env(:pleroma, :suggestions)
    chat = Application.get_env(:pleroma, :chat)
    gopher = Application.get_env(:pleroma, :gopher)
    stats = Stats.get_stats()

    mrf_simple =
      Application.get_env(:pleroma, :mrf_simple)
      |> Enum.into(%{})

    # This horror is needed to convert regex sigils to strings
    mrf_keyword =
      Application.get_env(:pleroma, :mrf_keyword, [])
      |> Enum.map(fn {key, value} ->
        {key,
         Enum.map(value, fn
           {pattern, replacement} ->
             %{
               "pattern" =>
                 if not is_binary(pattern) do
                   inspect(pattern)
                 else
                   pattern
                 end,
               "replacement" => replacement
             }

           pattern ->
             if not is_binary(pattern) do
               inspect(pattern)
             else
               pattern
             end
         end)}
      end)
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
      User.all_superusers()
      |> Enum.map(fn u -> u.ap_id end)

    mrf_user_allowlist =
      Config.get([:mrf_user_allowlist], [])
      |> Enum.into(%{}, fn {k, v} -> {k, length(v)} end)

    federation_response =
      if Keyword.get(instance, :mrf_transparency) do
        %{
          mrf_policies: mrf_policies,
          mrf_simple: mrf_simple,
          mrf_keyword: mrf_keyword,
          mrf_user_allowlist: mrf_user_allowlist,
          quarantined_instances: quarantined
        }
      else
        %{}
      end

    features =
      [
        "pleroma_api",
        "mastodon_api",
        "mastodon_api_streaming",
        if Keyword.get(media_proxy, :enabled) do
          "media_proxy"
        end,
        if Keyword.get(gopher, :enabled) do
          "gopher"
        end,
        if Keyword.get(chat, :enabled) do
          "chat"
        end,
        if Keyword.get(suggestions, :enabled) do
          "suggestions"
        end,
        if Keyword.get(instance, :allow_relay) do
          "relay"
        end,
        if Keyword.get(instance, :safe_dm_mentions) do
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
        private: !Keyword.get(instance, :public, true),
        suggestions: %{
          enabled: Keyword.get(suggestions, :enabled, false),
          thirdPartyEngine: Keyword.get(suggestions, :third_party_engine, ""),
          timeout: Keyword.get(suggestions, :timeout, 5000),
          limit: Keyword.get(suggestions, :limit, 23),
          web: Keyword.get(suggestions, :web, "")
        },
        staffAccounts: staff_accounts,
        federation: federation_response,
        postFormats: Keyword.get(instance, :allowed_post_formats),
        uploadLimits: %{
          general: Keyword.get(instance, :upload_limit),
          avatar: Keyword.get(instance, :avatar_upload_limit),
          banner: Keyword.get(instance, :banner_upload_limit),
          background: Keyword.get(instance, :background_upload_limit)
        },
        accountActivationRequired: Keyword.get(instance, :account_activation_required, false),
        invitesEnabled: Keyword.get(instance, :invites_enabled, false),
        features: features,
        restrictedNicknames: Pleroma.Config.get([Pleroma.User, :restricted_nicknames])
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
    conn
    |> put_status(404)
    |> json(%{error: "Nodeinfo schema version not handled"})
  end
end
