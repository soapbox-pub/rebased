# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceView do
  use Pleroma.Web, :view

  alias Pleroma.Config
  alias Pleroma.Web.ActivityPub.MRF

  @mastodon_api_level "2.7.2"

  def render("show.json", _) do
    instance = Config.get(:instance)

    %{
      uri: Pleroma.Web.base_url(),
      title: Keyword.get(instance, :name),
      description: Keyword.get(instance, :description),
      version: "#{@mastodon_api_level} (compatible; #{Pleroma.Application.named_version()})",
      email: Keyword.get(instance, :email),
      urls: %{
        streaming_api: Pleroma.Web.Endpoint.websocket_url()
      },
      stats: Pleroma.Stats.get_stats(),
      thumbnail: Pleroma.Web.base_url() <> "/instance/thumbnail.jpeg",
      languages: ["en"],
      registrations: Keyword.get(instance, :registrations_open),
      # Extra (not present in Mastodon):
      max_toot_chars: Keyword.get(instance, :limit),
      poll_limits: Keyword.get(instance, :poll_limits),
      upload_limit: Keyword.get(instance, :upload_limit),
      avatar_upload_limit: Keyword.get(instance, :avatar_upload_limit),
      background_upload_limit: Keyword.get(instance, :background_upload_limit),
      banner_upload_limit: Keyword.get(instance, :banner_upload_limit),
      background_image: Keyword.get(instance, :background_image),
      pleroma: %{
        metadata: %{
          features: features(),
          federation: federation()
        },
        vapid_public_key: Keyword.get(Pleroma.Web.Push.vapid_config(), :public_key)
      }
    }
  end

  def features do
    [
      "pleroma_api",
      "mastodon_api",
      "mastodon_api_streaming",
      "polls",
      "pleroma_explicit_addressing",
      "shareable_emoji_packs",
      "multifetch",
      "pleroma:api/v1/notifications:include_types_filter",
      if Config.get([:media_proxy, :enabled]) do
        "media_proxy"
      end,
      if Config.get([:gopher, :enabled]) do
        "gopher"
      end,
      if Config.get([:chat, :enabled]) do
        "chat"
      end,
      if Config.get([:instance, :allow_relay]) do
        "relay"
      end,
      if Config.get([:instance, :safe_dm_mentions]) do
        "safe_dm_mentions"
      end,
      "pleroma_emoji_reactions"
    ]
    |> Enum.filter(& &1)
  end

  def federation do
    quarantined = Config.get([:instance, :quarantined_instances], [])

    if Config.get([:instance, :mrf_transparency]) do
      {:ok, data} = MRF.describe()

      data
      |> Map.merge(%{quarantined_instances: quarantined})
    else
      %{}
    end
    |> Map.put(:enabled, Config.get([:instance, :federating]))
  end
end
