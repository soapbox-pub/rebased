# Pleroma: A lightweight social networking server
# Copyright © 2017-2020 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.MastodonAPI.InstanceView do
  use Pleroma.Web, :view

  @mastodon_api_level "2.7.2"

  def render("show.json", _) do
    instance = Pleroma.Config.get(:instance)

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
      banner_upload_limit: Keyword.get(instance, :banner_upload_limit)
    }
  end
end
